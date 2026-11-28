# Staff: a button over the enemy instead of a fixed button (2026-11-28)

Android only. The touch controls change; the staff itself does not.

## Why
- The staff is one of the least-used skills, but its button is the biggest one, in the best thumb spot (bottom
  right, r 64).
- The user wants it to be situational: hidden until another warlock is close enough, then shown as a button above
  that warlock's head. The corner is freed for later use.
- **Not now:** choosing your loadout in round 1. That stays in todo 14 (swappable starters), to be decided in the
  todo 13/14 brainstorm.

## Approaches considered
1. **Double the staff's reach** (30 → 60 px) so the button would show more often.
   - Rejected: it is a balance change. The shove lands from twice as far, and Blink → staff gets much easier.
2. **A loadout choice in round 1** (the staff becomes optional).
   - Postponed to todo 14. Whoever takes the staff would still need a button that doesn't hold the corner.
3. **Chosen:** a wide range for when the button shows, and the staff's hit left exactly as it is.
   - Tapping the button walks you the short gap and swings, using the existing `Wizard.attack()` chase.

## Design
- **The fixed A button is gone** from the right-hand cluster while you're alive.
- **Head marker:**
  - A staff icon floats above every living enemy warlock within **85 px** of the player, centre to centre. (85 px
    is near the old 70 px aim-assist distance; the swing reach is 30 px.)
  - It only shows while the player is alive, not locked (no countdown or results), and has the staff.
  - It's drawn in the touch layer at the enemy's screen position.
  - Its touch area is generous: about 44 screen px radius, like the other buttons, even if the icon is smaller.
- **Tap:**
  - A tap on a marker means `wizard.attack(that_enemy, once = true)`: walk in if needed, then one swing.
  - Holding the marker keeps swinging at that warlock, the same as the old hold-to-swing.
  - The chase stops when the joystick moves or the warlock leaves the 85 px range.
- **Touch priority:** a touch that starts on a marker is the staff, even on the left (joystick) half. Every other
  touch works as before.
- **Feedback:**
  - While the staff recovers (0.5 s), the marker shows the same small cooldown pie the buttons use.
  - My call: while the Blink → staff combo is open (1.5 s after your Blink), the marker glows. That's cheap, and it
    teaches the combo.
- **Ghost (dead player):** the haunt still needs a button. My call: the corner button comes back only while you're a
  ghost, as the haunt button, exactly as now.
- **The freed corner** (the user, 2026-11-28: "another spell takes its place, it can be Fireball or something
  else"):
  - **Fireball (Q)** moves into the corner at the big size (r 64). It's the spell cast most often, so it gets the
    best spot.
  - My call: **D** (the first shop slot) moves into Fireball's old place (-170, 0), so the arc stays closed.
  - W, E, R and F stay where they are.
  - While you're a ghost the corner is the haunt button, as before. Q can't be cast while dead anyway.
- **Unchanged:** the staff's numbers (reach 30, damage 2-4, push 300-390, 0.5 s), the Blink → staff combo, the bots
  (they don't use buttons), and the PC controls.

## Done when
- `tools/test_touch.gd` covers:
  - No A button while alive.
  - A marker shows within 85 px and hides beyond it.
  - Tapping a marker swings at that warlock.
  - A marker tap on the left half doesn't start the joystick.
  - The ghost still haunts from the corner.
- `tools/test_touch.gd` also checks that Fireball is in the corner and D is at the old Q spot.
- `tools/test_shop_layout.gd` still passes.
- Playtest: the bots aren't affected. Check on the phone how the marker feels in a fight.
- Docs: README controls, and the GAME_DESIGN Progress section in both copies.
