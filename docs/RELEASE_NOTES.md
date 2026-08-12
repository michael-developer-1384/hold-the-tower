# HODL THE TOWER — Release Notes

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
