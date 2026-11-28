# PC Catch-up (one project, two builds) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `lava-warlocks-mobile` run as a proper keyboard-and-mouse Windows game with a classic WC3-style bottom
bar, while the Android build stays exactly as it is.

**Architecture:**
- A static `Platform` helper decides touch or PC once at start. Tests and a `--touch` command-line flag can force
  either mode.
- In PC mode the existing `TouchControls` node is switched off, and a new `PcBar` HUD takes its place. The existing
  `PlayerController` already handles walking, attacking and spells; it gains ghost controls.
- Esc / Alt+Enter live in `PauseMenu`, which keeps processing while the game is paused.
- A "Windows Desktop" export preset and `tools/build_pc.sh` make the `.exe`.

**Tech Stack:** Godot 4.7.2, GDScript, Compatibility renderer.

**Spec:** `docs/superpowers/specs/2026-11-28-pc-catch-up-design.md`

## Global Constraints
- Android must look and play exactly as before. Every change is behind `Platform.touch()`.
- Same gameplay numbers, bots, shop and menus on both builds. No PC-only balance.
- PC HUD in a classic WC3 style, in our own art: square icons with the hotkey letter in the corner, a dark clockwise
  cooldown sweep with the seconds left, hover tooltips (name, what it does, cooldown), a centre panel (health, gold,
  round) and the minimap in a bottom-left frame. No round buttons. No Warcraft art copied.
- Renderer: Compatibility for both.
- Window 1280x720, resizable, same stretch (`canvas_items` / `expand`). Alt+Enter toggles fullscreen. Settings gets a
  "Fullscreen: On/Off" line on PC only (saved).
- On PC the mouse must not act as a touch (`Input.emulate_touch_from_mouse = false`). Android keeps
  `emulate_touch_from_mouse=true` in `project.godot`.
- Vibration and Move (joystick/touchpad) settings are hidden on PC.
- Export: preset "Windows Desktop" → `build/pc/LavaWarlocks.exe`, one exe with the game data embedded, no installer.
- Non-goals: Steam, controller support, WASD, clicking bar icons to cast.

## Review Focus
1. **Right mouse held while the cursor is over the bar.** The wizard must not walk to the spot under the bar. Test in
   Task 3: `PlayerController` ignores the held-right-mouse retarget while `PcBar.blocks_mouse(pos)` is true.
2. **Window resized or fullscreen at another aspect ratio.** The bar stays at the bottom over the full width, with the
   card in the bottom-right corner. Test in Task 3: after `root.size = Vector2i(1600, 720)` the card's right edge
   stays 8 px from the right.
3. **Esc on the title screen or with the shop open.** Title: Esc does nothing unless settings are open, in which case
   it closes them. During the shop: Esc opens the pause menu like the II button does today. Test in Task 2.
4. **The player dies while holding right mouse.** The ghost follows the mouse while right mouse is held and stops when
   it is released, with no leftover `move_dir`. Test in Task 2.
5. **A test that needs touch running in PC mode.** Every touch-dependent test forces touch, and the suite stays green.
   Covered by Task 1's suite run.

---

### Task 1: Platform helper, touch layer off on PC

**Files:**
- Create: `scripts/platform.gd`
- Modify: `scripts/touch_controls.gd` (new `enabled` flag), `scripts/game.gd` (`_ready` and the two places that
  set `touch.visible`, lines ~251 and ~264)
- Modify (one line each, `Platform.forced = Platform.Mode.TOUCH` first in `_init`): `tools/test_ai.gd`,
  `test_arena.gd`, `test_dark_mirror.gd`, `test_ghost.gd`, `test_hud_v07.gd`, `test_new_spells.gd`,
  `test_rounds.gd`, `test_title.gd`, `test_touch.gd`, `test_shop_layout.gd`
- Create test: `tools/test_pc.gd`

**Interfaces:**
- Produces:
  - `class_name Platform`
  - `enum Mode { AUTO, TOUCH, PC }`
  - `static var forced := Mode.AUTO`
  - `static func touch() -> bool`: `forced` wins. Otherwise it's true if `OS.has_feature("mobile")` or the user
    args contain `"--touch"`.
  - `static func apply() -> void`: sets `Input.emulate_touch_from_mouse = touch()`.
  - `TouchControls.enabled: bool`: false → `_input` returns at once, `_draw` draws nothing, `visible = false`.
  - `game.touch_mode: bool` (set in `_ready` from `Platform.touch()`)

- [ ] **Step 1: Write `tools/test_pc.gd`** (same style as `test_ghost.gd`: `extends SceneTree`; `_init` sets
  `Platform.forced = Platform.Mode.PC` before instantiating `game.tscn` with `bot_ai=false`, `apply_settings=false`,
  `title_screen=false`, `shrink_arena=false`). First block, "PC mode":
  - `game.touch_mode == false`
  - `game.touch.enabled == false`
  - `game.touch.visible == false`, also after the round starts (wait 1.0 s)
  - `Input.emulate_touch_from_mouse == false`
  - Ends with `print("TEST PASSED")` or `"TEST FAILED"`, like the others.
- [ ] **Step 2: Run** `"$GODOT" --headless --path . -s tools/test_pc.gd`. Expected: a parse error on `Platform`, then
  FAIL.
- [ ] **Step 3: Implement** `Platform`, `TouchControls.enabled`, and in `game._ready`: `Platform.apply()`,
  `touch_mode = Platform.touch()`, `touch.enabled = touch_mode`. Where game.gd sets `touch.visible = true`, make it
  `touch.visible = touch_mode`.
- [ ] **Step 4: Add the force line** to the 10 touch-dependent tests listed above.
- [ ] **Step 5: Run** test_pc, then `bash tools/run_tests.sh > .superpowers/suite1.log 2>&1; tail -3`. Expected:
  test_pc PASSED, and suite 29/29.
- [ ] **Step 6: Commit** "PC: Platform helper, touch layer off on PC".

### Task 2: PC input: ghost, Esc, Alt+Enter, settings

**Files:**
- Modify: `scripts/player_controller.gd`, `scripts/pause_menu.gd`, `scripts/game_settings.gd`, `scripts/game.gd`
  (`_start_ghost` / `_remove_ghost` set `player_ctl.ghost`; `_build_hud_extras` sets `player_ctl.minimap`),
  `project.godot` (new action `pause` = Escape)
- Test: `tools/test_pc.gd`

**Interfaces:**
- Consumes: `Platform.touch()`, `game.touch_mode`
- Produces:
  - `PlayerController.ghost: Ghost` and `PlayerController.minimap: Minimap`
  - Ghost on PC, inside `PlayerController`, only while `ghost != null`:
    - Right mouse held: `wizard.move_dir` = the direction to the mouse, or `ZERO` within 8 px.
    - Right mouse released: `ZERO`.
    - `attack` action: `ghost.haunt()`.
    - Left click where `minimap.world_at(pos) != null`: `ghost.teleport(spot)`.
  - `GameSettings.fullscreen := false` (saved as `fullscreen`)
  - `static func apply_window() -> void`: sets `WINDOW_MODE_FULLSCREEN` or `WINDOW_MODE_WINDOWED`. Does nothing in
    headless mode.
  - `PauseMenu._unhandled_input`, which keeps processing while paused:
    - `pause` action: open, or close if already open. On the title screen it only closes the open settings.
    - Alt+Enter: flip `GameSettings.fullscreen`, then save and `apply_window()`.
  - `PauseMenu` rows:
    - "Fullscreen: On/Off" is added when not touch.
    - "Vibration" and "Move" are hidden when not touch.

- [ ] **Step 1: Add test blocks to test_pc**:
  - **Esc:** `Input.parse_input_event` of an Escape key press gives `pause_menu.is_open()` and `paused`. A second
    press closes it and unpauses.
  - **Esc during the shop:** it opens the pause menu.
  - **Alt+Enter:** `GameSettings.fullscreen` flips. Restore it afterwards and don't save to the user's file: set
    `GameSettings.path = "user://test_pc_settings.cfg"`.
  - **Settings rows:** `pause_menu` has a visible row whose text begins "Fullscreen". The "Vibration" and "Move" rows
    are hidden.
  - **Ghost:**
    - Kill the player (`player.take_damage(999, null)`) and wait past `spectate_delay`.
    - The ghost exists, and the controller's ghost is the game's ghost.
    - The `attack` action makes `ghost.haunt_left > 0`.
    - A left mouse press at `minimap.global_position + Vector2(75, 75)` moves the ghost to within 40 px of the
      platform centre.
    - With no right mouse held, after one frame `player.move_dir == Vector2.ZERO`.
- [ ] **Step 2: Run** test_pc. Expected: FAIL on the new blocks.
- [ ] **Step 3: Implement** the interfaces above. Add the `pause` action (physical keycode 4194305, Escape) to
  `project.godot`. Call `GameSettings.apply_window()` in `game._ready` when not touch.
- [ ] **Step 4: Run** test_pc, test_ghost and test_title. Expected: all PASSED.
- [ ] **Step 5: Commit** "PC: ghost controls, Esc pause, Alt+Enter fullscreen, PC settings rows".

### Task 3: WC3-style bottom bar

**Files:**
- Create: `scripts/pc_bar.gd`
- Modify:
  - `scripts/game.gd` (`_build_hud_extras`: on PC, build `PcBar` and put the minimap in its left frame instead of the
    top right)
  - `scripts/pause_menu.gd` (the II button: on PC, top right where the minimap used to be)
  - `scripts/player_controller.gd` (the held-right-mouse check)
- Test: `tools/test_pc.gd`

**Interfaces:**
- Consumes: `game.touch_mode`, `game.player`, `game.gold`, `game.round_number`, `game.ghost`, `Spell.spell_name`,
  `Spell.spell_id`, `Spell.icon`, `Spell.icon_tint`, `Spell.cooldown_ratio()`, `Spell.cooldown_left`,
  `Shop.SPELLS[id].desc`
- Produces:
  - `class_name PcBar extends Control`, with `var game: Node`
  - `const BAR_H := 120.0`, `const ICON := 56.0`, `const GAP := 6.0`
  - `const CARD := [["Q","W","E","R"], ["D","F","","A"]]`
  - `func slot_rect(slot: String) -> Rect2`: in the bar's local space. The card sits bottom-right, 8 px from the
    right and bottom edges.
  - `func shown(slot: String) -> bool`:
    - The slot's spell exists.
    - While a ghost, only "A" is shown (as Haunt, with the ghost's cooldown).
  - `func slot_at(pos: Vector2) -> String`
  - `func tooltip_text(slot: String) -> String`:
    - Format: `"<name>  [<slot>]\n<desc>\nCooldown <n>s"`.
    - For a bought spell, `<desc>` is the shop `desc`. For a starter it comes from `const STARTER_DESC`:
      - Fireball: "Fire bolt that burns and knocks back."
      - Blink: "Teleport a short way toward the cursor."
      - Lightning: "Fast bolt that hits the first warlock in line."
      - Shield: "Brief barrier that reflects spells."
      - Staff: "Swing your staff at a warlock beside you."
      - Haunt (ghost A): "Shove warlocks near your ghost. No damage."
  - `func blocks_mouse(screen_pos: Vector2) -> bool`: true over the bar strip (the bottom `BAR_H` px), the minimap
    frame and the card.
  - `game.pc_bar: PcBar`, null on touch.
- **Look:**
  - The bar is a dark stone strip (bottom `BAR_H` px, full width) with a 2 px warm bronze top edge.
  - Each part (minimap frame, centre panel, card) has a raised bevel frame: a light top-left edge and a dark
    bottom-right edge.
  - Icons sit in recessed square sockets. An empty D/F socket is drawn dark, with no letter.
  - Hotkey letter in the top-left corner.
  - Cooldown: a dark pie sweeping clockwise from the top, with the seconds left in the middle.
  - Ready: a thin orange inner rim.
  - Centre panel: the HP bar with "62 / 100", "Gold 120" and "Round 3".
  - Colours come from the existing HUD's oranges and browns (`RoundHud` / `ShopPanel`).

- [ ] **Step 1: Add test blocks to test_pc** (this one runs with a window, like test_touch; add test_pc to the
  windowed list in `run_tests.sh`):
  - `game.pc_bar != null`
  - `shown("Q")`, `shown("A")`, and `not shown("D")` before anything is bought.
  - After `Shop.buy_spell(game, player, "homing")`, `shown("D")` is true.
  - Q's `slot_rect` is to the left of W's, at the same y.
  - The card's right edge is 8 px from the bar's right.
  - After `player.cast("Q", player.global_position + Vector2(100, 0))` and 0.5 s, `cooldown_ratio() > 0`.
  - `tooltip_text("Q")` begins with "Fireball" and contains "Cooldown".
  - The minimap is inside the bar's bottom-left frame (its global rect's left < 20).
  - `blocks_mouse(Vector2(640, 715))` is true and `blocks_mouse(Vector2(640, 300))` is false.
  - Resize: `root.size = Vector2i(1600, 720)`, wait 2 frames, and the card's right edge is still 8 px from the
    right.
  - While a ghost: only "A" is shown, and `tooltip_text("A")` begins with "Haunt".
  - Touch mode check: `test_touch` keeps passing and `game.pc_bar == null` there (one line added to test_touch).
- [ ] **Step 2: Run** `"$GODOT" --path . -s tools/test_pc.gd`. Expected: FAIL.
- [ ] **Step 3: Implement** `PcBar` from the interfaces and look above. The old PC `lava-warlocks/scripts/spell_bar.gd`
  is the drawing starting point. The tooltip is a `PanelContainer` + `Label` shown above the card while the mouse is
  over a shown slot. In `PlayerController._process`, the held-right-mouse retarget skips when
  `game.pc_bar and game.pc_bar.blocks_mouse(mouse_screen_pos)`.
- [ ] **Step 4: Run** test_pc, test_touch and test_hud_v07, then the full suite. Expected: all PASSED, suite 29/29.
- [ ] **Step 5: Look at it.** Take a screenshot of a running round at 1280x720 (MCP run, or Movie Maker one frame)
  with a spell cooling down, and check that the bar reads as a WC3-style command bar. Fix any overlaps with the kill
  feed, the scoreboard and the lava timer.
- [ ] **Step 6: Commit** "PC: WC3-style bottom bar with tooltips".

### Task 4: Windows build

**Files:**
- Modify: `export_presets.cfg` (add `[preset.1]`)
- Create: `tools/build_pc.sh`

**Interfaces:**
- Preset settings:
  - `name="Windows Desktop"`, `platform="Windows Desktop"`
  - `export_path="build/pc/LavaWarlocks.exe"`
  - `binary_format/embed_pck=true`
  - `application/product_name="Lava Warlocks"`, file version from the Android `version/name`
- `tools/build_pc.sh`: `"$G" --headless --path . --export-release "Windows Desktop" build/pc/LavaWarlocks.exe`.
  - It creates `build/pc` first.
  - It fails with a clear message if the Windows templates are missing.

- [ ] **Step 1: Download the templates** (approved by the user, 2026-11-28).
  - Get `Godot_v4.7.2-stable_export_templates.tpz` from the official GitHub release
    (`github.com/godotengine/godot/releases/download/4.7.2-stable/`) into a new, empty scratch folder.
  - Unzip it and copy only the `windows_*` files into `%APPDATA%/Godot/export_templates/4.7.2.stable/`. The Android
    files already there stay.
- [ ] **Step 2: Add the preset and the script, then run** `bash tools/build_pc.sh`. Expected: `build/pc/LavaWarlocks.exe`
  exists.
- [ ] **Step 3: Start the exe** for about 8 s in the background and kill it. Expected: no `ERROR` lines in its
  output, and the title menu shows.
- [ ] **Step 4: Check Android is untouched.** Run `bash tools/deploy_android.sh` if the phone is connected. Otherwise
  run an Android export dry run (`--export-release "Android"` into `build/`). Expected: the APK builds.
- [ ] **Step 5: Commit** "PC: Windows export preset and build script".

### Task 5: Docs, archive note, MCP run
- [ ] **README:** a "PC (Windows)" section covering:
  - controls: right-click to walk or attack, A to swing or haunt, Q W E R D F for spells, Esc to pause, Alt+Enter
    for fullscreen, click the minimap as a ghost;
  - how to run from the project and how to build the exe.
- [ ] **GAME_DESIGN, both copies:** a "PC build 2026-11-28" details block and the Progress line. Tick todo 16 except
  for the user's playtest.
- [ ] **`lava-warlocks/README.md`:** a note at the top that development moved to `lava-warlocks-mobile`, which builds
  both PC and Android, and that this folder is an archive.
- [ ] **Run the game with the Godot MCP** (PC mode) and play a round. No errors in the debug output.
- [ ] **Run the full suite.** Expected: all passed.
- [ ] **Commit** "Docs: PC build" in both repos. Push Android only when the user asks.
