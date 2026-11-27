# Remaining spells (milestone 9) + a two-slot shop — design

## Why
The user (2026-11-27) wants the rest of the spells now, before the v1.0 camera. The art is drawn in Godot code,
as close as possible to the current PixelLab effects. They'll test on the phone and may redesign the spells later.
Shop: "go with A for now but we will rework that". A = two shop slots.

## Goals
- **Two shop slots, D and F:**
  - A bought spell takes the first free slot.
  - With both slots full you sell one, for half its price, before buying another.
  - Each bot personality has a wish list of at most 2 spells.
- **5 new shop spells** (numbers by level 0 → 3):

| Spell | Price | Behaviour | Numbers |
|---|---|---|---|
| Boomerang | 15 | A spinning blade flies 420 px, then homes back to the caster. It passes through wizards and hits each one at most once going out and once coming back. The return hit pushes in the blade's direction of travel. Rocks end it. A shield reflects it, and it then belongs to the shielder. | dmg 6/6.5/7/8, kb 360/390/420/450, cd 5/4.5/4/3.5, speed 520 |
| Meteor | 20 | Aimed at a point up to 600 px away. A warning ring shows for 1.0 s, then a 75 px blast pushes outward from the centre and leaves a crater. No projectile, so shields don't reflect it, but a shielded wizard takes no damage or push. | dmg 14/15/16/18, kb 650/700/750/800, cd 8/7.5/7/6.5 |
| Gravity Well | 20 | A vortex at a point up to 500 px away. For 2.5 s it pulls enemies within 160 px toward its centre (not the caster). Shields don't block it. | pull 220/245/270/300 px/s, cd 10/9.5/9/8.5 |
| Swap | 15 | An orb (650 px/s, range 650/700/750/800). On a hit, the caster and the target trade places, and both lose their knockback. No damage. A shield reflects it. | cd 9/8.5/8/7.5 |
| Time Stop | 20 | Aimed at a point up to 450 px away. For its duration, every projectile inside a 120 px circle freezes, then carries on. Wizards aren't affected. | duration 2.0/2.2/2.4/2.6, cd 12/11.5/11/10.5 |

- **Bots:** every spell gets `_score_X` / `_do_X` in `scripts/ai/ai_controller.gd`. Bots also counter:
  - they walk out of a Meteor ring
  - they walk against a well's pull (a recover-like urgency when it's near lava)
  - they don't throw into a Time Stop
- **Art:** `tools/build_effects.gd` draws every frame pixel by pixel and saves PNG sheets + `SpriteFrames .tres` in
  `assets/sprites/effects/`.
  - The frames match the current effects: 30-70 px, a dark outline, the warm lava palette plus one accent per spell,
    hard pixels (no anti-aliasing), 8-12 frames.
  - The Meteor blast reuses `fireball_impact`, scaled up.
  - Icons come from a frame of each sheet.
- **Sound:** new recipes in `tools/build_audio.gd` (boomerang whirr, meteor fall + boom, well hum, swap zip, time
  stop chime).

## Non-goals
- No spell redesign beyond this (the user may change them later).
- No new HUD buttons.
- No PC port.

## Approaches
1. **Each spell as a `Spell` subclass, like the Homing Orb and Rock Wall** (chosen):
   - a scene / script for each world object (`boomerang.gd`, `meteor.gd`, `gravity_well.gd`, `time_stop.gd`)
   - the Swap orb is a `Projectile` with an on-hit callback
   - This reuses the shield, rock, crater and cooldown code.
2. A generic data-driven spell system. Not worth it for 5 spells that the user may redesign.
3. Art from PixelLab. Ruled out: the user asked for art drawn in Godot.

## Checks
- `tools/test_shop.gd` covers:
  - the two-slot fill
  - the "sell first" rule
  - selling a spell refunds half and frees its slot
  - the bots' wish lists
- `tools/test_new_spells.gd` covers each spell's core behaviour:
  - the boomerang returns and hits twice
  - the Meteor hits after its delay, inside its radius only
  - the well pulls enemies, not the caster
  - Swap trades places
  - Time Stop freezes a fireball, then releases it
  - a shield reflects the boomerang and the Swap orb
  - each bot score is above 0 in a fitting situation
- Harness (Normal, 40 matches): nobody above 40% of round wins, lava deaths at least 50%, fights 35-60 s.
- Godot MCP run, no errors. APK on the phone, then the v0.12 release.
