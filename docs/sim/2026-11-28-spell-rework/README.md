# Sim after the Meteor / Dark Mirror / Time Stop rework (2026-11-28)

- **Run:** `python -I tools/sim/run.py --mode duel --rounds-per-worker 140 --workers 16` (2240 rounds). The full
  pair tables are in [report.md](report.md).
- **Before:** the numbers come from `docs/sim/2026-11-27-balance-pass/`.
- **Spec:** `docs/superpowers/specs/2026-11-28-meteor-mirror-timestop-design.md`.

Duel win rate of every loadout that holds the spell, and how often bots cast it:

| Spell | Win rate before | Win rate now | Casts/min before | Casts/min now |
|---|---|---|---|---|
| Meteor (buffed) | 45.8% | **50.3%** | 6.9 | 6.9 |
| Time Stop (freezes wizards) | 48.4% | **61.4%** | 0.5 | 6.2 |
| Dark Mirror (was Rock Wall) | 47.2% | **44.7%** | 0.08 | 0.9 |
| Gravity Well | 62.0% | 61.1% | 5.6 | 5.6 |
| Homing Orb | 56.9% | 49.9% | 7.5 | 7.4 |
| Boomerang | 49.4% | 47.9% | 11.2 | 11.0 |
| Swap | 48.0% | 46.0% | 3.7 | 3.7 |

- **First real combo the sim has found:** Meteor + Time Stop, +16 pp synergy (CI +1.7 to +30.6), 76% win rate. Bots
  freeze, then drop the meteor.
- **Time Stop is now as strong as Gravity Well** (both about 61%).
- **Dark Mirror** is used 12x more than Rock Wall but is still below average. Bots only raise it against a spell
  they've seen coming, and they often dodge instead.
- **Playtest (8 matches, 4 bots):** every target is met.
  - Round-win share: Caster 34%, Player 25%, Brawler 21%, Trickster 20%.
  - Lava deaths 69%.
  - Fights average 49 s.
  - Matches average 7:49.
