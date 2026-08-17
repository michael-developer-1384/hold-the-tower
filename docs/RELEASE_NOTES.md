# HODL THE TOWER — Release Notes

## 0.16.0 — HODL Index

- Live **HODL Index** (0–100 defensive stability) with one real OHLC candle per wave on a right-side market panel. Combat writes the chart; cash/USD language from v0.15 is unchanged.
- Candles open after a successful next-wave start and freeze at spawn-complete. PRE-MARKET ticker can still move; late leaks show up as a gap on the next open.
- Camera and build UI compose into the leftover left playfield (no SubViewport). Wheel/MMB do not orbit through the chart.
- Debug **Pause / Resume** uses real `SceneTree.paused`. Session, timeline, SIM clone, and replay persist `hodl_market`. Telemetry records one candle-close per wave.

## 0.15.0 — Spawn Gate & Editor Map

- Next wave can start only after the previous wave has **finished spawning**. Early call while leftovers are still on the map still pays remaining bonus gold.
- Spawn gate: 3D clock (wave remaining, then next-wave timer) and a pickable start plate. Kill gold and early-call gold use the same world popup.
- Procedural map preview in the Godot 3D editor (`@tool` on TowerLevel); generated nodes are not saved into the scene.
- Floor fade-above-focus is optional (Settings → Fade floors above focus). Default: all floors fully visible.
- Build pads stay under placed towers. Opening camera: ~30° pitch, spawn visible, first path toward the bottom of the screen, zoomed to the whole map.

## 0.14.1 — Lava Lifetime Research

- Meltdown `lava_lifetime` research is finite: base **8s**, best **24s**. More RP lengthens puddle persistence.
- Engine sentinel `0` still means no decay; research no longer starts there (investing RP no longer makes lava worse).
- Research, pour rate, and combat identity otherwise unchanged.

## 0.14.0 — Meltdown & Simulation Lab

- Third tower archetype **Meltdown** (`lava_tower`): area DCA field that spreads on plates, slips off edges, and contagions lower floors.
- Feature chips: **LIQUIDATION**, **CONTAGION**, **DCA**. Catalog/research/progression/profile wired; display name Meltdown.
- PLAY and SIM share the same gameplay graph, `SimActions`, and fixed **1/60** step. Fast-sim adds ticks, never a fatter gameplay delta.
- Agents: `random` / `basic` / `smart` plus player profiles (Beginner → Optimizer). Mechanical utility is scored separately from human bias; high pickrate is not an automatic nerf.
- Simulation Observatory: replay packages, keyframes, seek via snapshot + forward replay, decision rank/regret, first-decision divergence, compare, watch at 0.25–40×.
- Meltdown is sim-safe: seeded `SimContext.rng`, emit phase in snapshots, burn only enemies in the owning `TowerLevel`. Scripted fidelity policy still does not place Meltdown.
- Headless `validate_lava` covers surface index, landing, flow/drip, damage, airborne, catalog, snapshot, seeded determinism, and a short GameSimulation smoke.

## 0.13.1 — Command Center Hardening & Gameplay Audio

- Meta pages migrated toward real scene-based layouts with reusable data-driven components instead of script-built screen trees.
- Central presentation formatting removes raw domain keys, internal IDs and unbounded float precision from player-facing UI.
- Progression, Main Menu Diorama and Play Setup previews receive targeted desktop presentation improvements.
- Added first spatial gameplay SFX language for Sentry fire, projectile impacts, melee combat, deaths and tower placement.
- Added global wave/core/result audio cues with concurrency-safe gameplay audio playback.
- Timeline preview/restore never replays historical SFX; Time Machine V2 Resume Here remains unchanged.
- Research, progression, economy, difficulty, blueprints and combat balance remain unchanged.

## 0.13 — COMMAND CENTER

- PC-first meta UI rebuilt around a persistent AppShell, desktop navigation rail, and stacked meta routes.
- Responsive layouts target 1080p+, 16:10 and ultrawide while remaining usable at 1280×720/800.
- Main Menu redesigned with clear run/session hierarchy, typographic brand lockup, and animated in-engine MenuDiorama3D.
- Play Setup, Progression, Database, entity details, Research and After Action Report redesigned for dense PC information layouts.
- New reusable UI design tokens/theme, page transitions, focus states, tooltips, modals and toast notifications.
- First UI sound language, audio buses (Master/Music/SFX/UI), and optional quiet meta ambient.
- Functional Display, Audio, Controls and Accessibility settings with separate `user://settings.json` persistence.
- Keyboard/gamepad navigation foundation for future Steam Deck support (mixed input, visible focus).
- Time Machine V2 (in-match): HUD scrubber with preview restore, Resume Here (overwrite future) or Return to Live; post-game timeline remains inspect-only.
- Research, progression, blueprints, economy, sessions and gameplay balance remain unchanged.

## 0.12 — Progression, Landscape UX, Session & Time Machine

- Slower Player Level XP curve and tighter research unlock fractions; new **tower research capacity** so builds cannot max every stat at once.
- Dedicated **Progression** screen with XP bar, unlock roadmap, and capacity roadmap.
- Research UI landscape redesign: max-width content shell, two-column layout, sticky summary with capacity, denser cards, clearer lower-is-better copy.
- Persistent **active session** (wave/pause-safe): Continue / Restart / Delete from Main Menu; in-game pause with Resume, Restart, Save & Exit, Exit without saving.
- **Time Machine V1**: 5 Hz timeline recorder + inspect-only scrubber in post-game and debug pause (no live resume from rewind yet).
- Profile v12 migration keeps XP, reconstructs XP from run history when missing, refunds over-cap/capacity RP.
- Bot kill reward remains **10** gold; combat/difficulty rewards unchanged.

## 0.11 — Player Progression & Research UX V2

- Research is now integer **RP allocations** per stat (not float config edits); values resolve via a diminishing-returns curve (`progress^0.70`).
- **Player Level** (max 10) from lifetime Research XP; level caps investment depth per stat. Gameplay rewards grant RP+XP; refunds never grant XP.
- Research UI redesigned: stat cards, 1-RP sliders with locked regions, live draft preview, sticky apply/refund.
- Global `LV / RP` chrome; post-game shows XP progress and level-up cap increase.
- Blueprints store allocations; active only on exact match. Profiles/blueprints migrate from old params with level-cap refunds.
- Telemetry includes allocation + resolved snapshots and level/XP start/end fields.
- Bot kill reward remains **10** gold; combat/build/difficulty rewards unchanged.

## 0.10.1 — Research / blueprint / telemetry bugfixes

- Blueprint is `active` only when its saved params exactly match current tower research; research drift clears sticky active flags.
- Built towers stamp correct `blueprint_id` / `blueprint_name` (`research` / `Research` when no exact match).
- Research RP spend/refund uses integer totals (`roundi` of the existing `pow(1.7)` curve) so A→B→A is RP-exact.
- `last_run_summary.json` includes root-level `research_snapshot` from run start.
- Bot kill reward remains **10** gold (unchanged).

## 0.10 — Domain model, shared visuals, galleries & research UI

- Shared `visual_scene` / `runtime_scene` architecture for Sentry, Guard Post, Guard unit, and Bot.
- `EntityPreview3D` powers gallery, detail, and build previews from the same visual scenes.
- Feature catalog (`PAPER HANDS`, `DIAMOND HANDS`, etc.) drives UI chips from data.
- Tower research is the match source of truth; named blueprints are optional saves.
- Tower Detail tabs: Overview | Statistics | Research (blueprints demoted).
- Gallery supports TOWERS | ENEMIES; enemy Bot has overview + lifetime stats.
- Waves are data-driven bot groups preserving prior 5-wave counts/HP.
- Theme (`hodl_theme`) + product rename to **HODL THE TOWER**.

## 0.9 — Game shell / research / post-game

- App shell with main menu, play setup, tower gallery/detail, post-game stats.
- Profile persistence (`user://profile.json`), research points, blueprint resolve at build.
- Difficulty multipliers; in-match HUD redesign with build gallery and options/debug.

## 0.8 — Melee blocking

- Guard Post slow aura removed; 1:1 Guard↔Enemy engage with mutual melee.
- Guards block path progress while engaged; respawn + out-of-combat heal.
- Combat feedback: HP bars, floating damage text, hit/death tweens.

## 0.7 — Guard Post

- Second tower archetype: Guard Post with local melee blockers.
- Floor-disc range visualization and path coverage for disc towers.

## 0.6 / 0.6.1 — Interaction + telemetry

- Tower selection, hover, range visualization, upgrade flow.
- Telemetry events + last-run JSONL/summary dumps for balance debugging.
- Actual-damage accounting and kill attribution cleanup.

## 0.5 — Build loop

- Gold economy, build spots, Basic Tower placement and in-run range upgrade.

## 0.4 — Combat loop

- Waves, enemy pathing, projectiles, core HP, kill rewards.

## 0.3 — Vertical map

- Multi-floor tower layout with ramps and path continuity between floors.

## 0.2 — Orbit / ramps foundation

- Orbit camera, prototype vertical platforms, ramp mesh/path scaffolding.
