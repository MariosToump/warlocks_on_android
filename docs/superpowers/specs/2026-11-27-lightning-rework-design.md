# Lightning rework + slower lava (v0.11) — short design

## Why
The user: Lightning's reach is much shorter than the other two attacks. It should be a bit longer, with a hitbox
that matches the bolt you see on screen. The very end of the bolt should get a slightly bigger hitbox and a small
knockback bonus, which rewards players who can land it at max range.
The user also asked (2026-11-27) for the lava to shrink every 18 s instead of 12.

## Goals
- Lightning reach goes from 230 to **450 px**, about twice today's. My call: an instant, unblockable-except-by-shield
  bolt at Fireball reach (850) would take over the game, and the user handed me the choice.
- **Hitbox = the drawn bolt:** a capsule from the caster to the end of the bolt. Its radius is 16 px, which covers
  the drawn bolt (±6 px jitter plus a 4 px line) and a wizard's body.
- **Tip zone:** the last 70 px of the bolt (380-450 px).
  - Hit radius 28 px, so tip hits are easier to land and the zone is wider than the shaft.
  - Knockback ×1.25.
  - A bigger hit spark, so a tip hit is visible.
- **Bots:**
  - They use Lightning up to its new reach (93% of `max_range`, from the spell itself, not a constant).
  - Every bot scores a target standing in the tip zone a bit higher, so bots go for tip hits too.
- **Brawler:** keeps waiting just outside the enemy's Lightning reach (`max_range` + 20). Sims will tell whether that
  is now too far. If it is, the hold distance gets decoupled from the reach.
- **Lava:** shrink every **18 s** (was 12). The hold at the smallest size goes from 8 to **12 s**. My pick, offered with
  the 18 s.

## Non-goals
- No change to damage, cooldown or cast time.
- No new art. The tip spark is the existing hit effect, scaled up.

## Approaches
1. **Longer line + tip zone on the existing check** (chosen): `release()` already finds the first wizard along the
   line. Widen the radius by the distance along the bolt, and scale the knockback in the tip zone. A small change,
   and the existing tests keep working.
2. A real physics `CollisionShape2D` capsule in an `Area2D`. It's instant, so an area query needs a physics frame,
   which complicates the timing for no gain.
3. A multi-segment hitbox following the jagged drawn points. The jitter is random each frame, so the hitbox would be
   random too. Unfair.

## Checks
- New `tools/test_lightning.gd`:
  - hits at 420 px, misses at 520
  - a tip hit pushes about ×1.25 harder than a shaft hit
  - 24 px off the line: hit at the tip, miss at mid-range
  - rocks and shields still stop it
  - bots score it at 400 px
- `test_spells` "out of range (300 px)" becomes 520 px.
- Harness batch (Normal, 40 matches): matches 5-8 min (they will get longer with the slower lava), fights 35-60 s,
  nobody > 40% of round wins, lava deaths ≥ 50%.
