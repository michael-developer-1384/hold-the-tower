# Level Architecture

HoldTheTower levels are free vertical arena layouts, not a fixed square tower grid.

## Runtime flow

```text
TestLevelFactory.create_level()
        ↓
LevelDefinition
        ↓
TowerLevel (runtime host)
 ├── FloorRenderer      → platform + path meshes per floor
 ├── BuildSpotRenderer  → fixed build spots
 ├── ConnectorRenderer  → ramps (and later other connectors)
 └── EnemyPathBuilder  → linear world-space enemy route
```

## LevelDefinition

Top-level data resource:

- `level_id`
- `floors: Array[FloorDefinition]`
- `connectors: Array[ConnectorDefinition]`
- `core_transform`
- `spawn_transform`

Levels are authored in code today (`TestLevelFactory`). Later they can become `.tres` / editor data without changing runtime.

## Floors

A floor is a horizontal gameplay layer:

- `floor_id`, `floor_index`
- `elevation`, `origin`, `focus_point`
- `path_points` (world-space enemy waypoints on this floor)
- `platforms` (explicit visible patches)
- `build_spots`

Floors do **not** share a global grid size. They do not require rectangular outer bounds. Missing ground is simply “no platform”.

Camera focus uses `focus_point` (not `index * constant`).

## Platform surfaces

`PlatformDefinition`:

- `transform`, `size`
- `walkable`, `visible`

Current prototype surfaces are walkable path platforms only. Buildability comes from BuildSpots (and later BuildZones), not from platform kind.

## Paths

Enemy movement truth is the concatenated world path:

1. Floor N `path_points`
2. Connector N→N+1 waypoints
3. Floor N+1 `path_points`
4. …

Built by `EnemyPathBuilder`. Path points are independent of platform meshes.

## BuildSpots

`BuildSpotDefinition`:

- `id`, `floor_id`
- `transform` (full 3D; supports future wall / mid-air mounts)
- `size`, `allowed_types`, `occupied`

All spots are hand-authored. No auto-generation from path neighbors.

`BuildZoneDefinition` exists as a stub for future free placement; unused now.

## Connectors

`ConnectorDefinition` links `from_floor_id` → `to_floor_id` with:

- `start_transform`, `end_transform`
- `path_points`

`RampDefinition` extends it with `width` / `thickness`. Mesh and enemy waypoints both come from those path points (no grid cells).

## Interaction & telemetry

See [interaction_and_telemetry.md](interaction_and_telemetry.md) for cross-floor hover/focus, tower selection, range coverage, upgrades, and last-run telemetry under `res://telemetry/`.

## Future Extensions

- Free build zones (`BuildZoneDefinition`)
- Build spots between floors / on walls / under bridges
- Lift, ladder, drop, teleporter, moving platform, shaft, bridge connectors
- Branching enemy paths
- `.tres` / level-editor authoring
