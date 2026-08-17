# UI Architecture — HODL THE TOWER (v0.16 Command Center)

## PC-first target

Primary platform: Windows PC / Steam (mouse + keyboard).  
Secondary: Gamepad and Steam Deck (1280×800).  
Mobile is not a design target.

Tone: dense, serious systems/strategy UI with restrained mint accent. Not neon cyberpunk, not finance-meme chrome, not mobile card stacks.

## Supported resolutions / aspects

Baseline viewport: **1920×1080** (`canvas_items` + `expand`).

Explicitly supported:

- 1280×720
- 1280×800 (Steam Deck / 16:10)
- 1920×1080
- 2560×1440
- 2560×1080 (21:9)
- 3440×1440 (21:9)
- 3840×2160

Layouts use adaptive columns, sidebars, and a soft content max width (~1600–1800px). Full-bleed backgrounds always fill the display.

## AppShell

Meta UI lives in a persistent shell: [`scenes/app.tscn`](../scenes/app.tscn) → [`ui/shell/app_shell.gd`](../ui/shell/app_shell.gd).

Chrome (sidebar, status, content host, footer, quit dialog) is authored in the scene tree. Scripts bind `%` unique nodes, navigation, and status.

Gameplay remains `scenes/main.tscn`. Returning from a run remounts the shell and opens Main Menu or After Action Report.

## In-match HODL Index panel

Right-side market panel (~45% width at ≥1600px, ~40% at 1200–1599, compact min-width below 1200) sits below the top bar: ticker, PRE-MARKET / MARKET OPEN, and a `_draw()` candlestick chart. It is `MOUSE_FILTER_STOP`. Core HP, USD, phase, wave, enemies, Opening Bell, and Options stay in the top bar. Build dock / Time Machine inset to the left gameplay region. Camera framing uses a gameplay safe-area fraction (no SubViewport split).

Debug Pause/Resume lives next to Options and uses real `SceneTree.paused` (`PROCESS_MODE_ALWAYS` HUD only). Disabled in SIM / replay / timeline preview.

## Scene-based page rule

**Static screen structure belongs in `.tscn`.**  
GDScript binds data, fills dynamic lists, wires events, and formats values.

Allowed runtime generation:

- Tower / enemy cards
- Research stat rows
- Progression roadmap nodes
- Stat table rows
- Level / difficulty selection rows

Prefer reusable component scenes under `ui/components/` (`stat_table_row`, `progression_level_node`, `session_summary`, `level_preview_3d`, `menu_diorama_3d`, `entity_preview_3d`, `research_stat_row`, `tower_card`).

`UiStyle` is for tokens, StyleBoxes, semantic buttons, and small atomic helpers — **not** full page layouts.

## Navigation model

[`scripts/app/app_router.gd`](../scripts/app/app_router.gd):

- `go_to(route)` / `back()` / history stack
- ESC: close modal → back → on Main Menu open quit confirm (never silent quit)
- Detail BACK uses `AppRouter.back()` (history pop), not `go_database(push)`
- Sidebar switches replace (`push=false`)
- Pending transfer state: tower/enemy ids, gallery mode, resume session, boot route

Routes: `main`, `play`, `progression`, `database`, `tower_detail`, `enemy_detail`, `settings`, `after_action`, plus full-scene `game`.

## Presentation formatting layer

[`scripts/app/stat_presentation.gd`](../scripts/app/stat_presentation.gd) (`StatPresentation`):

- User-facing **labels**, **units**, **precision**, **lower-is-better**, descriptions
- `format_value` / `format_delta` / `format_delta_label`
- Catalog display names: `display_level`, `display_tower`, `display_enemy`, `display_difficulty`

### Rules

1. **No raw domain keys** in player UI (`fire_interval` → `Fire Interval`).
2. **No unbounded floats** (`4.547565…` → `4.55 m`).
3. **No internal IDs** when a display name exists (`vertical_test` → `Vertical Test Level`).
4. Internal calculations stay precise; only presentation rounds.
5. Debug HUD may still show internal ids.

Research investment math stays in `ResearchConfig` / `ResearchResolver`. `ResearchResolver.format_value` delegates to `StatPresentation`.

## Design tokens

[`scripts/app/ui_tokens.gd`](../scripts/app/ui_tokens.gd) + [`scripts/app/ui_style.gd`](../scripts/app/ui_style.gd) + [`ui/theme/hodl_theme.tres`](../ui/theme/hodl_theme.tres)

- Colors: dark navy/anthracite, muted metal, mint accent, danger red, warning orange
- Spacing: 2/4/8/12/16/24/32
- Radius: 2–6px
- Typography roles: display / page / section / body / label / data / caption
- Focus ring is mandatory and visible
- Active tabs stay focusable (not `disabled`)

## Motion

[`scripts/app/ui_motion.gd`](../scripts/app/ui_motion.gd) (autoload `UiMotion`)

- Micro ~110ms, page ~220ms, modal ~180ms
- Reduced Motion: fades only, no slides, diorama/preview camera static, number counts snap

## Audio

See [`docs/audio_architecture.md`](audio_architecture.md).

- Buses: Master / Music / SFX / UI
- UI: `UiAudio` — Gameplay: `GameplayAudio`

## Input

[`scripts/app/input_mode_controller.gd`](../scripts/app/input_mode_controller.gd) (autoload `InputMode`)

- Mouse and gamepad both remain active (mixed input)
- Pages should `grab_focus()` the primary CTA on enter
- Neutral InputHints (`[ESC] BACK` / generic controller labels)

## Settings persistence

[`scripts/app/settings_manager.gd`](../scripts/app/settings_manager.gd) → `user://settings.json`

Sections: display, audio, controls, accessibility, gameplay (`time_machine`).  
Progression stays in `ProfileManager` / `user://profile.json`. Debug HUD flag remains on the profile.

## Time Machine (in-match V2)

- Scrubber lives on the HUD (usable with pause menu closed) when enabled
- Scrub = preview restore (paused)
- **Resume Here** truncates future and continues
- **Return to Live** restores the tip snapshot
- After Action Report timeline remains inspect-only
- Preview/restore never replays historical gameplay SFX

## Steam Deck considerations

- Test 1280×800 readability and focus traversal
- Progression may horizontal-scroll below Full HD; at 1920×1080 all 10 level nodes should fit
- Gamepad must complete all meta flows

## Rules for future screens

1. Author layout in `ui/pages/*.tscn`; register in `AppRouter.PAGE_SCENES`
2. Bind domain APIs; do not invent stats the domain does not provide
3. Format every player-facing value through `StatPresentation`
4. Use tokens/theme; keep radius and accent usage restrained
5. Wire focus + InputHints; tooltips may use presentation descriptions
6. Respect Reduced Motion via `UiMotion`
7. Play UI sounds only through `UiAudio`; gameplay through `GameplayAudio`
8. Do not change research/progression/economy math from UI work
