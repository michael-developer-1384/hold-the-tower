# UI Architecture — HODL THE TOWER (v0.13 Command Center)

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

```
AppShell
├── Background
├── SidebarNavigation
├── TopStatusBar
├── ContentHost (page root)
├── ToastLayer
├── TooltipLayer
└── Modal / BootIntro
```

Gameplay remains `scenes/main.tscn`. Returning from a run remounts the shell and opens Main Menu or After Action Report.

## Navigation model

[`scripts/app/app_router.gd`](../scripts/app/app_router.gd):

- `go_to(route)` / `back()` / history stack
- ESC: close modal → back → on Main Menu open quit confirm (never silent quit)
- Pending transfer state: tower/enemy ids, gallery mode, resume session, boot route

Routes: `main`, `play`, `progression`, `database`, `tower_detail`, `enemy_detail`, `settings`, `after_action`, plus full-scene `game`.

## Design tokens

[`scripts/app/ui_tokens.gd`](../scripts/app/ui_tokens.gd) + [`scripts/app/ui_style.gd`](../scripts/app/ui_style.gd) + [`ui/theme/hodl_theme.tres`](../ui/theme/hodl_theme.tres)

- Colors: dark navy/anthracite, muted metal, mint accent, danger red, warning orange
- Spacing: 2/4/8/12/16/24/32
- Radius: 2–6px
- Typography roles: display / page / section / body / label / data / caption
- Focus ring is mandatory and visible

## Reusable pieces

- Shell: AppShell, BootIntro, ToastHost, TooltipHost
- Pages under `ui/pages/`
- Components: EntityPreview3D, TowerCard, ResearchStatRow, MenuDiorama3D
- Prefer scene structure + bind scripts; avoid rebuilding entire screens from `Button.new()` where a page scene exists

## Motion

[`scripts/app/ui_motion.gd`](../scripts/app/ui_motion.gd) (autoload `UiMotion`)

- Micro ~110ms, page ~220ms, modal ~180ms
- Reduced Motion: fades only, no slides, diorama camera static, number counts snap

## Audio

- Buses: Master / Music / SFX / UI (`default_bus_layout.tres`)
- [`scripts/app/ui_audio.gd`](../scripts/app/ui_audio.gd) (autoload `UiAudio`)
- Placeholder WAVs in `audio/ui/` — replaceable without call-site changes
- Optional quiet meta ambient on Music bus

## Input

[`scripts/app/input_mode_controller.gd`](../scripts/app/input_mode_controller.gd) (autoload `InputMode`)

- Actions: `ui_*`, `hodl_tab_next` / `hodl_tab_prev`
- Mouse and gamepad both remain active (mixed input)
- Neutral InputHints (`[ESC] BACK` / generic controller labels)
- No hover-only essential actions

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

## Steam Deck considerations

- Test 1280×800 readability and focus traversal
- Compact sidebar / denser tables OK; no touch-first redesign
- Gamepad must complete all meta flows

## Rules for future screens

1. Add a page under `ui/pages/` and register it in `AppRouter.PAGE_SCENES`
2. Bind domain APIs; do not invent stats the domain does not provide
3. Use tokens/theme; keep radius and accent usage restrained
4. Wire focus + InputHints; add tooltips for dense jargon
5. Respect Reduced Motion via `UiMotion`
6. Play UI sounds only through `UiAudio`
7. Do not change research/progression/economy math from UI work
