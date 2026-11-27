# Balance pass 1 (2026-11-27)

Duel sim, 2,240 rounds, after the review-fix balance changes. Compare with the baseline in
[`../2026-11-27-pair-synergy/`](../2026-11-27-pair-synergy/). Raw rounds were not kept (re-run:
`python -I tools/sim/run.py --mode duel --rounds-per-worker 140 --workers 16`).

## Changes
| Spell | Change |
|---|---|
| Homing Orb | knockback 480-570 -> 410-500, damage 8-14 -> 7-11.5, turn 2.5 -> 1.9 rad/s, cooldown 6-4.5 -> 7.5-6 |
| Meteor | radius 75 -> 85, lands in 0.85 s (was 1.0), knockback 650-800 -> 740-890 |
| Boomerang | damage 6-8 -> 7-9, knockback 360-450 -> 410-500, cooldown 5-3.5 -> 4.5-3 |
| Swap | cooldown 9-7.5 -> 7-5.5 |
| Time Stop | cooldown 12-10.5 -> 9-7.5; bots use it when they can't sidestep |
| Rock Wall | cooldown 10-7 -> 8-5; bots raise it when they can't sidestep, or with the shield ready |

## Duel win rate of any loadout holding the spell (n ~1,050-1,130 each; none = no shop spell, n 150)
| Spell | Baseline | After |
|---|---|---|
| Homing Orb | 64.1% | 56.9% |
| Gravity Well | 59.5% | 62.0% (unchanged spell) |
| Boomerang | 47.8% | 49.4% |
| Time Stop | 46.1% | 48.4% |
| Swap | 46.5% | 48.0% |
| Rock Wall | 46.5% | 47.2% |
| Meteor | 47.3% | 45.8% |
| No shop spell | 38.3% | 42.0% |

## Still open (the user's call)
- Gravity Well is now the strongest shop spell.
- Meteor is still weak for bots, even with the bigger, faster blast.
- Bots still almost never raise a Rock Wall (0.08 casts a minute) or Time Stop (0.5): they dodge instead. Making
  bots wall more would need a design choice (e.g. wall to block a lane on purpose), not just numbers.
