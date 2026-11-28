# Staff Head Marker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the fixed staff button with a tappable marker over enemies within 85 px, and move Fireball into the
freed corner.

**Architecture:** All changes are in `scripts/touch_controls.gd`, which already owns the buttons, the hold-to-swing and
the drawing.
- The markers are computed each frame from the wizards group.
- They're drawn in screen space with the viewport canvas transform (the same one `_auto_target` uses).
- They trigger the existing `Wizard.attack(target, once)` chase.

**Tech Stack:** Godot 4.7.2, GDScript.

**Spec:** `docs/superpowers/specs/2026-11-28-staff-context-button-design.md`

## Global Constraints
- Android project only. The staff's numbers, the bots and the PC controls are unchanged.
- Marker range is 85 px (world, centre to centre). Marker touch radius is 44 screen px.
- Corner (offset 0, r 64): Q while alive, A (Haunt) only while a ghost. D moves to (-170, 0). W, E, R and F don't move.

## Review Focus
1. **An enemy dies or respawns while its marker is held.** The swing stops, with no error on a freed wizard. Covered
   in Task 1 (a dead target clears the hold).
2. **A marker sitting over the joystick half.** The touch is the staff, not the stick. Covered in Task 1.
3. **A marker overlapping a spell button.** Buttons win, so the cluster keeps working. Covered in Task 1 (a button
   tap still casts).
4. **Locked (countdown or results), or the player is dead.** No markers. Covered in Task 1.
5. **Two enemies in range.** Each gets its own marker, and a tap goes to the one touched. Covered in Task 1.

---

### Task 1: Head markers + corner swap

**Files:**
- Modify: `scripts/touch_controls.gd` (the LAYOUT, `_shown`, `_touch_down`, `_touch_up`, `_process`, `_hold_attack`
  and `_draw` changes).
- Test: `tools/test_touch.gd` (replace the "Attack button" block). `tools/test_ghost.gd` stays as it is: A is still the
  haunt button.

**Interfaces:**
- Produces:
  - `const MARKER_RANGE := 85.0`
  - `const MARKER_TOUCH_R := 44.0`
  - `func marker_targets() -> Array[Wizard]`: living enemies within MARKER_RANGE. Empty if the player is dead, locked,
    a ghost or has no staff.
  - `func marker_center(w: Wizard) -> Vector2`: screen position, 44 world px above the feet.
  - `func _marker_at(pos: Vector2) -> Wizard`
  - `var _attack_target: Wizard`
- Corner layout: LAYOUT "Q" `{offset ZERO, r 64}`, "A" `{offset ZERO, r 64}`, "D" `{offset (-170, 0), r 44}`.
  `_shown("A")` is true only for a ghost. `_shown(slot)` is false for every other slot while a ghost.

- [ ] **Step 1: Write the failing tests** (in test_touch, in place of the old attack block):
  - `touch._button_center("Q") == corner` and `touch._button_at(corner) == "Q"`.
  - `touch._button_center("D")` equals `base + (-170, 0)`.
  - Alive: `not touch._shown("A")`.
  - Enemy at 110 px: `marker_targets()` is empty.
  - Enemy at 60 px: it's in `marker_targets()`.
  - Touching `marker_center(enemy)` swings: after 0.4 s the enemy's health drops and `player.attack_target` was set.
  - Holding keeps swinging (casting again after 0.5 s).
  - A marker on the left half doesn't grab the stick (`touch._stick_index == -1`).
  - Dragging the stick clears `player.attack_target`.
  - `touch.locked = true` makes `marker_targets()` empty.
  - Two enemies at 60 px give 2 markers.
  - A tap on the Q button at the corner casts a fireball.
- [ ] **Step 2: Run** `"$GODOT" --path . -s tools/test_touch.gd` (with a window). Expected: FAIL on the new checks.
- [ ] **Step 3: Implement.**
  - **Tap:** `_touch_down` checks `_marker_at` after the buttons and before the stick. On a hit it sets
    `_attack_index` and `_attack_target`, and calls `wizard.attack(t, true)`.
  - **Hold:** `_hold_attack` re-issues `wizard.attack(_attack_target, true)` whenever `wizard.attack_target == null`.
    It stops (calling `attack(null)`) when the target is dead or invalid, beyond MARKER_RANGE, or the stick vector is
    non-zero.
  - **Draw:** each marker gets a dark disc (r 22), the staff icon, the cooldown ring like the old A button, and an
    orange glow ring when `StaffStrikeSpell.combo_open(wizard)` is true.
- [ ] **Step 4: Run** test_touch, test_ghost and test_shop_layout. Expected: all PASSED.
- [ ] **Step 5: Commit** "Touch: staff marker over nearby enemies, Fireball in the corner".

### Task 2: Docs, MCP run, suite
- [ ] Update the README controls and the GAME_DESIGN Progress section in both copies.
- [ ] Run the full suite (`bash tools/run_tests.sh`) and the Godot MCP run. No errors.
- [ ] Commit "Docs: staff marker".
