# PC Feel Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zoomed-out start, League-style smart cast with indicators, a smaller PC HUD, and a staff that locks on
(everyone).

**Architecture:**
- **Zoom:** `game.gd` picks the camera minimum on PC.
- **Smart cast:** in `PlayerController`, with a new `CastIndicator` (Node2D, world space).
- **HUD:** `PcBar` constants plus a per-instance minimap diameter.
- **Lock-on:** in `Wizard` (`_swing_target`, chase boost) and `StaffStrikeSpell.release`.

**Tech Stack:** Godot 4.7.2, GDScript.

**Spec:** `docs/superpowers/specs/2026-11-28-pc-feel-pass-design.md`

## Global Constraints
- Phones unchanged, except the staff lock-on (everyone, by the user's choice).
- `LOCK_REACH` 45, `LOCK_RANGE` 85, chase multiplier 1.3. Staff damage and knockback unchanged.
- Bar strip 84, icons 44, minimap 110, scoreboard scale 0.75 (PC only).
- `GameSettings.cast_mode` is "indicator" or "instant", default "indicator", saved.

## Review Focus
1. **Key released while the game pauses or the round ends mid-aim.** No cast, and the indicator is hidden. Test:
   `locked`/paused releases clear the aim (test_pc).
2. **Holding a spell key while dead or as a ghost.** No indicator. Test in test_pc's ghost block.
3. **The locked target dies or gets shielded during the wind-up.** A dead target isn't hit. A shielded one bounces,
   as today. Test in test_staff_lock.
4. **A bot's staff swing at a point (no attack target).** Unchanged. Test in test_staff_lock (free swing).
5. **A spell key pressed while another spell is mid-cast.** `wizard.cast` refuses, as today. No new risk.

---

### Task 1: Staff lock-on + chase boost (everyone)
- **Files:** `scripts/spells/staff_strike.gd`, `scripts/wizard.gd`; test `tools/test_staff_lock.gd` (headless).
- **Produces:**
  - `StaffStrikeSpell.LOCK_REACH := 45.0`, `LOCK_RANGE := 85.0`, `CHASE_BOOST := 1.3`
  - `Wizard._swing_target: Wizard`, set when `_update_auto_attack` starts a swing and cleared after the release or a
    cancel.
  - In `_walk_velocity`, the speed gets `CHASE_BOOST` while `attack_target` is valid and within `LOCK_RANGE`.
- **Steps:**
  - [ ] Write the tests and see them fail:
    - Locked hit at 40 px after a step during the wind-up.
    - No hit at 60 px.
    - Boost at 80 px, none at 120 px.
    - A free `cast("A", point)` with a wizard at 40 px doesn't hit (as before).
    - A dead locked target isn't hit.
  - [ ] Implement, then run the test and test_brawler.
  - [ ] Run `playtest.gd -- 20 normal` and compare with the before run. Report the round-win shares, Brawler and
    the lava-death share.
  - [ ] Commit.

### Task 2: PC start zoom + smaller HUD
- **Files:**
  - `scripts/game.gd`: on PC, `follow_zoom = arena.camera.min_zoom`, and `apply_live_settings` keeps the camera
    zoom.
  - `scripts/minimap.gd`: `var diameter := DIAMETER`, used everywhere inside it.
  - `scripts/pc_bar.gd`: new sizes and fonts.
  - `scripts/round_hud.gd`: scoreboard scale 0.75 on PC.
  - `scripts/pause_menu.gd`: Zoom row hidden on PC.
- **Steps:**
  - [ ] Tests in test_pc:
    - `arena.camera.zoom.x <= 1.01` at the start.
    - The bar strip is 84 high and an icon is 44.
    - `minimap.size.x == 110`.
    - The Zoom row is hidden.
  - [ ] Implement, then run test_pc and test_touch (the phone minimap is still 150).
  - [ ] Commit.

### Task 3: Smart cast with indicators (PC)
- **Files:** `scripts/cast_indicator.gd` (new), `scripts/player_controller.gd`, `scripts/game_settings.gd`,
  `scripts/pause_menu.gd` (Casting row, PC only).
- **Produces:**
  - `class_name CastIndicator extends Node2D`, with `func show_for(spell: Spell, caster: Wizard, mouse: Vector2)` and
    `func hide_now()`.
  - Static `func instant(spell: Spell) -> bool` (Shield, Dark Mirror).
  - `PlayerController.aiming_slot: String` ("" when not aiming).
- **Steps:**
  - [ ] Tests in test_pc:
    - Q press: `aiming_slot == "Q"`, the indicator is visible and Q's cooldown is 0.
    - Q release: Q is on cooldown and the indicator is hidden.
    - W press, then right-click: no cast, no walk target, and the aim is cleared.
    - R press: the shield is up at once.
    - With `cast_mode = "instant"`, Q press casts at once.
    - While a ghost, a spell press shows no indicator.
  - [ ] Implement. The indicator draws the range ring, and the lane, area or landing shape per the spec. It's grey
    while the spell cools down. Then run test_pc.
  - [ ] Take a screenshot (`tools/shots/pc_bar.gd` holding Q) and check the look.
  - [ ] Commit.

### Task 4: Docs, suite, MCP run, exe
- [ ] README PC controls (hold-and-release casting, the Casting setting, zoom).
- [ ] GAME_DESIGN details block "PC feel pass 2026-11-28" in both copies, with the harness numbers.
- [ ] Full suite, the MCP run, `bash tools/build_pc.sh` (the shortcut opens the new exe), then commit.
