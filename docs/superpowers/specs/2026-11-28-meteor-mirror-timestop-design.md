# Meteor buff, Dark Mirror, Time Stop rework (2026-11-28)

The user's request (2026-11-28), with no extra spec round because the request itself was the design:

> buff meteor both in damage and knockback, it should feel like a meteor; rework its visuals to look a bit bigger;
> don't change the hitbox for now. Transform Rock Wall into the spell Dark Mirror: it reflects back any spell (sends it
> back to the original caster, without changing the projectile's speed, a pure reflect), and with each level more
> mirror appears around you like a barrier: lvl 1 covers 1/3 of the player, lvl 2 2/3, lvl 3 3/3. Add a slight
> rotation effect without altering the character's area of effect. Time Stop now stops the characters instead of
> the spells, and any character hit inside it gets an extra 20% knockback for 2-3 s after walking out of it (and
> of course while in it). Retest.

## Meteor (`scripts/spells/meteor.gd`, `scripts/meteor_strike.gd`)
- **Damage:** 14/15/16/18 → 20/22/24/26.
- **Knockback:** 740-890 → 980/1040/1100/1160.
- **Unchanged:** blast radius 85, 0.85 s warning, cooldown, 600 px range.
- **Visuals:**
  - The rock art is now 56 px (was 32), with a long flame tail. It falls from further away and is never upscaled.
  - The blast art is now 232x156 (was 168x112): a thick fire ring out to about 104 px, 20 flame tongues, big debris
    thrown high, and a smoke ring at the end.
  - The screen shake is 9 (was 6).
- **Bots:** Meteor scores +0.8 on a target frozen by Time Stop, and the bot aims where that target stands, with no
  lead.

## Dark Mirror (replaces Rock Wall; id `mirror`, slot F, price 15)
- **Code:** `scripts/spells/dark_mirror.gd` (the spell) and `scripts/dark_mirror.gd` (the barrier, a child of the
  wizard, in group `mirrors`).
- **Shape:** dark glass panes on a ring of radius 30 round the wizard (the shield is 22), centred on the aim.
- **Rotation:** the panes sway ±0.17 rad, and each pane tilts on its own. The reflect check uses the swayed angle, so
  what you see is what reflects. The wizard's collision body is unchanged.
- **Coverage by level** (bought = level 0 in code, so the user's "lvl 1" is level 0):

  | Level | Coverage | Panes |
  |---|---|---|
  | 0 | 1/3 | 5 |
  | 1 | 2/3 | 10 |
  | 2 | the whole ring | 15 |
  | 3 | the whole ring, lasting 3.0 s (others 2.5 s) | 15 |

  - Cooldown 9 / 8.5 / 8 / 7.5.
- **Reflect:**
  - Any projectile (Fireball, Homing Orb, Boomerang, Swap orb) flying into the panes turns straight toward its
    caster's current position.
  - It keeps its speed and range, and its range count restarts. It now belongs to the mirror's wizard, for kill
    credit.
  - If the caster is dead, it just reverses.
  - The shield's 2x speed rule is unaffected.
- **Lightning:** the bolt stops on the glass and hits its caster down the same line, with the same damage and push,
  unless the caster is shielded. A second bolt is drawn going back.
- **Not reflected:** placed spells (Meteor, Gravity Well, Time Stop) and the staff, because they don't fly.
- **Sound:** `mirror` on cast and `mirror_reflect` on a bounce.
- **Bots:**
  - `_score_mirror` is 2.2 (2.05 if a dodge is possible), against a spell they've seen coming. That beats a dodge
    (2.0).
  - Bots don't fire Fireball, Homing, Boomerang, Swap or Lightning into a mirror that faces them (`_mirrored()`).

## Time Stop (reworked; id `timestop`)
- **Freeze:** every wizard inside the 120 px circle except the caster is frozen. It can't walk or cast, its cast and
  animation pause, and it gets an icy tint.
- **Still moving:** knockback still moves a frozen wizard, so a hit can knock it out of the circle, or into the lava.
- **Projectiles** fly through as normal.
- **Mark:**
  - Hits taken inside push ×1.2.
  - A wizard hit inside keeps the ×1.2 for **2.5 s** after it gets out. This shows as a ticking icy ring at its feet.
  - A wizard frozen but never hit gets no mark.
- **Duration:** 1.5 / 1.7 / 1.9 / 2.1 s (was 2.0-2.6 s for spells). My call: a frozen wizard is far stronger than a
  frozen fireball. Cooldown unchanged (9-7.5).
- **Bots:**
  - `_score_timestop` is now an attack on the target: 0.6 base, +0.4 near the lava, +0.4 with Meteor ready, +0.2 with
    Lightning in range.
  - Bots never freeze an already frozen target.
  - Shots are no longer "blocked" by a Time Stop.
- **Code:** `scripts/time_stop_field.gd` (`holds(w)`) and `Wizard._update_time_stop` / `time_knockback()`.

## Tests
- `tools/test_dark_mirror.gd` (was `test_rock_wall.gd`).
- `tools/test_time_stop.gd` (new; the old Time Stop part of `test_new_spells.gd` moved here).
- The Meteor numbers are in `test_new_spells.gd`.
- `test_spell_edges.gd` covers the caster dying, lava and a shield for the new rules.
