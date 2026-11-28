# PC catch-up: one game, two builds (2026-11-28, todo 16)

## Intent
- The user (2026-11-28): the PC version should be "the same game, playable on PC with mouse and keyboard, for now".
- It must catch up with everything Android has, and must not fall behind again.

## Where things stand
- **PC** (`lava-warlocks`) stopped at milestone ~6: the 4 starter spells, the staff, the bots, early rounds and a
  spell bar. Its last code commit is the Movie Maker demo (a884c44), shared with Android.
- **Android** (`lava-warlocks-mobile`) has 59 code commits since then:
  - the shop and 7 extra spells, terrain and boulders, sound and music;
  - rounds and gold, the title and settings menus, the ghost;
  - visual pass 1, the spell rework, the performance pass, the staff marker.
- **Android already has PC controls.** It contains the same keyboard-and-mouse `PlayerController` as PC: right-click
  to walk, right-click an enemy to auto-attack, A to swing, Q W E R D F for spells. The touch layer sits on top.

## Approaches
1. **Chosen: one project, two builds.**
   - `lava-warlocks-mobile` becomes the single codebase, with a Windows export next to the Android one.
   - Platform differences are switched at runtime (touch screen or not). Every future change lands on both at once.
   - Cost: the PC folder stops being where the code lives. It is kept, with its git history, as an archive.
2. **Copy the Android code into the PC folder and adapt it.** Rejected: it's two copies again, and they drift the
   same way.
3. **Cherry-pick the 59 commits.** Rejected: slow and conflict-heavy, for the same end result as 2.

## Goals
- Same gameplay, numbers, art, sound, bots, shop and menus on both.
- **PC differences, only where the input or the screen needs them:**
  - **Controls:** the existing `PlayerController` (WC3 style: right-click to walk or attack, A to swing, Q W E R D F
    for spells).
  - **HUD:** no touch buttons, joystick or staff markers. The user (2026-11-28): no Android-style round buttons on
    PC; it should feel like classic Warcraft III. So, a WC3-style bottom bar in our own art:
    - Square spell icons in a framed row (Q W E R D F, plus A for the staff), each with its hotkey letter in the
      corner, a dark clockwise cooldown sweep and the seconds left.
    - Health, gold and the round info in the bar's centre panel; the minimap in its bottom-left frame.
    - Hovering an icon shows a tooltip (name, what it does, cooldown).
    - The old PC `SpellBar` is the starting point. The shop slots show once something is bought, as on Android.
    - Inspiration only: no Warcraft art, frames or icons are copied.
  - **Ghost:** A haunts. Clicking the minimap teleports, the same rule as tapping it on Android.
  - **Pause:** Esc opens and closes the pause menu, as well as the on-screen pause button.
  - **Window:**
    - 1280x720, resizable, with the same stretch as Android.
    - Alt+Enter toggles fullscreen.
    - A "Fullscreen: On/Off" line goes in Settings on PC only (saved).
  - **Mouse vs touch:**
    - On PC the mouse must not act as a touch, so the touch controls are off.
    - Android keeps `emulate_touch_from_mouse` working for desktop testing of the touch layer.
  - **The phone-only bits** (vibration, the touchpad/joystick setting) are skipped or hidden on PC.
- **Renderer:** Compatibility for both (my call). It gives the same picture everywhere and was just optimised. PC
  could move to Forward+ later if a PC-only effect ever needs it.
- **How PC is detected** (my call): `DisplayServer.is_touchscreen_available()` is false, or `OS.has_feature("pc")`.
  This sits in one helper (`Platform.touch()`) so tests can force either mode.
- **Export:** a "Windows Desktop" preset in `export_presets.cfg`, plus `tools/build_pc.sh`, which writes
  `build/pc/LavaWarlocks.exe`. No installer.
  - Only the Android export templates are installed. The Windows `.exe` needs Godot's 4.7.2 export templates
    (one official download from godotengine.org / GitHub, about 1 GB, installed into Godot's templates folder).
  - Until then the PC build runs straight from the project with the Godot executable.

## Non-goals (for now)
- PC-only features and a different balance.
- Steam, achievements and controller support.
- WASD movement (W and D are spell keys; that's still open from before).

## Anti-goals
- PC and Android drifting apart again.
- Android players noticing any change.

## Folders and docs
- The PC folder (`lava-warlocks`) gets a README note pointing to the shared project, and its GAME_DESIGN keeps the
  synced Progress section. My call: no code is deleted there; it's simply no longer developed.
- GAME_DESIGN and README in the shared project describe both builds. "Android" in names, like the repo name
  `warlocks_on_android`, stays as it is for now; renaming is the user's call later.

## Done when
- The whole test suite passes in both modes. The touch tests run with touch forced on, and new `tools/test_pc.gd`
  runs with it forced off:
  - no touch controls;
  - the spell bar shows the owned spells and cooldowns;
  - A swings;
  - right-click walks;
  - Esc pauses;
  - the ghost's A haunts.
- The Godot MCP run on the PC is clean, and the Windows build starts.
- The Android build on the phone looks and plays exactly as before.
- A short playtest by the user on PC.
