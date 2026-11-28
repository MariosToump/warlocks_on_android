# PC feel pass: zoom, smart cast, smaller HUD, staff lock-on (2026-11-28)

The user, after the first PC build:
- Start zoomed out, at the furthest the game allows.
- League-style smart cast with an indicator: hold the key to see the range and hitbox, cast on release. This applies
  to every spell where it makes sense; Shield and Dark Mirror are not included.
- The minimap, the HP HUD and the HUD in general are too big and take a lot of the screen.
- The staff should always connect. Tapping the marker (or attacking an enemy) walks up with a little extra speed and
  hits, with no whiff, but only when the target is within range. "Keep it fair, the same for everyone", so the
  bots get it too, then run the bot simulations.

## Approaches
- **Smart cast:**
  - **Chosen:** release-to-cast with an indicator, plus a Settings choice "Casting: Indicator / Instant". Instant is
    the old press-to-cast, for players who want it.
  - Rejected: indicator only, with no instant option. Some players find release-casting slow, and the option is
    cheap.
- **Staff lock-on:**
  - **Chosen:** the swing remembers the warlock it was started on. When the staff comes down, that warlock is hit if
    they're within the lock reach, wherever they stepped during the wind-up.
  - Rejected: a bigger hit circle. That changes every swing, including ones not aimed at anyone.
- **Fairness (the user's call):** the lock-on and the chase boost apply to everyone, bots included. Checked with the
  playtest harness before and after.

## Design
1. **Zoom (PC):**
   - Start at the camera's minimum zoom (`min_zoom`, which snaps to 1 screen px per art px at 1280x720).
   - The wheel still zooms, and settings changes don't reset it. The Zoom row is hidden on PC.
2. **Smart cast (PC):**
   - Spell key down shows the indicator. Key up casts at the mouse.
   - Right-click while holding cancels the cast; it doesn't walk.
   - Another spell key while holding switches to that spell.
   - Shield and Dark Mirror cast on key down.
   - The indicator, by spell:
     - a faint range ring around the caster;
     - projectiles (Fireball, Homing Orb, Boomerang, Swap): a lane of the projectile's width plus a body, from the
       hand to the spell's reach;
     - Lightning: a lane with the 70 px tip highlighted;
     - Blink: a landing circle at the mouse, clamped to 200;
     - placed spells (Meteor, Gravity Well, Time Stop): the area at the mouse, clamped to reach.
   - While a spell is cooling down, the indicator is grey and release does nothing.
   - The setting `GameSettings.cast_mode` is "indicator" (the default) or "instant", saved. Its Settings row only
     shows on PC.
3. **Smaller PC HUD (about 30% smaller):**
   - bar strip 84 px, icons 44 px, minimap 110 px (a per-instance diameter);
   - a smaller centre panel and fonts;
   - the top-left scoreboard at 0.75 scale on PC.
4. **Staff lock-on (everyone):**
   - `Wizard.attack()` swings remember their target.
   - At release, a locked target within `LOCK_REACH` 45 px (centre to centre) is hit and pushed away from the caster,
     even if it's outside the normal hit circle. The shield rules are unchanged.
   - While chasing an attack target within `LOCK_RANGE` 85 px, the chaser moves at 1.3x speed.
   - Free swings (A with nobody near, or a bot's own swing at a point) behave exactly as before.

## Non-goals
- Smart cast on phones (they already have drag-to-aim with a guide).
- Changing staff damage or knockback.

## Done when
- `tools/test_pc.gd` covers:
  - the start zoom is the camera minimum;
  - hold Q shows the indicator with no cast, and release casts;
  - right-click cancels;
  - R casts on press;
  - instant mode casts on press;
  - the smaller bar and minimap.
- The new `tools/test_staff_lock.gd` covers:
  - a target that steps to 40 px during the wind-up is still hit;
  - a target beyond 45 px is missed;
  - the chase is 1.3x within 85 px, and normal speed beyond it;
  - a free swing is unchanged.
- The suite passes. A playtest harness run before and after is compared and the bot results reported (targets in
  GAME_DESIGN).
- A screenshot of the smaller bar and the Fireball indicator.
