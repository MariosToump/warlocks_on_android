# Spell sim sandbox + pair synergy (todo 13, step 1)

## Intent
The user wants to know how well each pair of spells works together. This is data first, and the results become
"recommended" tips in the shop ("goes well with Gravity Well"). Players can still buy anything they like, and
combos stay natural: there are no special spell-on-spell interactions for now. To get the data fast, the user
asked for a sandbox that only Claude uses. It sits outside the APK, sets up any scenario at once, and doesn't
play through the menus, countdowns or shops it doesn't need.

## Goals
- `tools/sim/` is a sandbox that loads the real game code, so it never drifts from the game.
  - It skips the title screen, countdown and shop.
  - It forces the spells each wizard has.
  - It resets instantly between rounds.
  - It runs uncapped in headless mode and writes the results to files.
- A runner starts N copies in parallel (the PC has 24 threads; the default is 16), each with its own seed, then
  merges the results.
- **Pair study on the 7 current shop spells (21 pairs in slots D and F):**
  - **FFA:** 4 wizards. Each round, every wizard gets a random pair, or a random single spell, or no spell (the
    baseline).
  - **1v1:** a pair against a random other pair.
  - Per loadout: rounds won, kills, lava kills, deaths, and each spell's casts and hits.
- **Synergy, not just strength:** synergy(A, B) = win rate(A+B) − win rate(A alone) − win rate(B alone) + baseline.
  A pair of two strong spells isn't a combo unless together they do better than the two separately. Every
  number is reported with a 95% confidence interval, and the report says which differences are real and which
  are noise.
- A short report (`tools/sim/out/report.md`, plus a chart) ranks raw pair strength and synergy. These are the
  candidate shop tips.

## Non-goals
- No shop tips in the game yet. They come after the user has seen the data.
- No new spells, no combo planning in the bot brain, no changes to the spells themselves.
- Nothing in the APK. `tools/*` is already excluded by `export_presets.cfg`.

## Anti-goals
- A sim that behaves differently from the real game (different physics step, removed lava, etc.).
- Tips based on noise.

## Constraints and decisions
- **Same rules as the real game:**
  - The physics step stays at 60 Hz (`--fixed-fps 60`, uncapped headless). No `time_scale` tricks.
  - The lava shrinks as normal, and the rocks and pillars spawn as normal.
  - All spells are at level 0 and nobody has items, so only the spell choice differs.
- **Bots:**
  - Every wizard is a bot with the neutral personality, normal difficulty and the normal per-round moods. Same
    brain as the game.
  - The player's PlayerController is replaced by an AIController, as `tools/playtest.gd` does.
- **Known bias (to be stated in the report):** the bots choose each spell on its own merits and don't plan
  combos, so the numbers show natural synergy as these bots play. Combos that need planning will look weaker
  than they really are.
- **Hooks on the game:** use the existing exports (`title_screen`, `countdown_time`, `shop_time`, `feel_effects`,
  `apply_settings`, `spawn_bots`). The sandbox starts the next round itself instead of opening the shop. If a small
  hook is needed in `game.gd` (e.g. a `sandbox` flag that skips the shop), it must change nothing when off.
- **Scenario mode** for small questions: a JSON / command-line config sets the wizards, their spells, their
  positions and a time limit. For example: the enemy at the lava's edge, cast Gravity Well, run 50 times. Runs
  end on a condition or a timeout. No full rounds.
- **Outputs:** JSON lines per worker in `tools/sim/out/` (git-ignored). The merge and stats are done in Python.

## Approaches
- **A. Sandbox in the project, in `tools/sim/`** — chosen by the user. Always the current code, parallel, fast.
- B. A separate copy of the project. Rejected: it drifts out of date with every change.
- C. Only speed up `tools/playtest.gd`. Rejected: it still plays full matches with shops, which is slow for small
  questions.

## Left to the builder
- The file split inside `tools/sim/`, the config format, and whether to reset by reloading the scene or by calling
  `start_round` directly. Prefer direct, but reload if state leaks.
- The number of rounds per loadout. Aim for a CI half-width of about ±5 percentage points on pair win rates.
  The report gives the sample sizes.
