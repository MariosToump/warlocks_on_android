# Spell pair sim data (2026-11-27)

Saved for later (the user's request). Made with the sim sandbox in `tools/sim/` (game code at commit 46557dc).

- `ffa/` — 2240 rounds, 4 wizards, random loadouts (none / 1 / 2 of the 7 shop spells). Report + charts.
- `duel/` — 4352 rounds, 1v1. Report + charts.
- `raw_rounds.zip` — every round record (JSON lines, one per round, per worker): `ffa/w*.jsonl`,
  `duel/w*.jsonl`, `scenario/*.jsonl` (the Gravity Well at the lava edge test).
  Re-analyse: unzip into `tools/sim/out/` and run `python -I tools/sim/analyze.py tools/sim/out/ffa`.

Headlines: no pair synergy beyond noise (+-10 pp, bots don't plan combos); Homing Orb far ahead (duel 61% alone
vs 38% with nothing, 76% with Gravity Well); Gravity Well second (55%); Time Stop / Rock Wall / Swap / Meteor /
Boomerang alone no better than nothing for bots. Numbers change once spells are rebalanced — re-run then.
