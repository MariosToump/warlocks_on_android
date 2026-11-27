# Spell Sim Sandbox Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A headless sandbox in `tools/sim/` that runs many forced-loadout rounds in parallel and reports the
strength and synergy of spell pairs.

**Architecture:**
- `SimRunner` (a Node) drives a real `game.tscn`. It turns off the title screen, countdown, shop and gold, gives
  each wizard its loadout on `round_started`, and logs one JSON line per round. Kill credit uses game time.
- An entry script (`tools/sim/sandbox.gd`) parses the arguments.
- A Python runner starts the workers in parallel. A Python analyser computes Wilson CIs and synergy, and writes
  `report.md` plus an SVG chart.

**Tech Stack:** Godot 4.7.2 GDScript (headless, `--fixed-fps 60`), Python 3 (stdlib only: no matplotlib or scipy installed).

**Spec:** `docs/superpowers/specs/2026-11-27-spell-sim-sandbox-design.md`

## Global Constraints
- Physics stays at 60 Hz. Lava shrink and props work as normal.
- All spells are at level 0, nobody has items, and there is no gold.
- Every wizard is a bot: neutral personality, normal difficulty, normal moods.
- Nothing from the sandbox goes in the APK. `tools/*` is excluded, and the outputs go to `tools/sim/out/` (git-ignored).
- Any hook in game code must not change the game when it's off.
- Godot: `D:/Godot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe`.

## Review Focus
- A round that never ends (two wizards hiding): a 180 s game-time timeout logs the round as a draw.
- Loadout leaks: last round's D/F spells must be gone before the new ones are added.
- Bots shopping or getting gold must not happen (they would change the loadouts).
- Gameplay timers on the real clock (`Time.get_ticks_msec`) would stretch kill credit, retaliation and blink-combo
  windows when the sim runs uncapped. They must use game time.
- Two workers with the same seed would duplicate the data, so each worker gets a distinct seed.

---

### Task 1: Game clock for gameplay timers
**Files:**
- Create: `scripts/game_clock.gd`
- Modify: `scripts/wizard.gd:308`, `scripts/game.gd:520,665`, `scripts/ai/ai_controller.gd:347`,
  `scripts/spells/blink.gd:29`, `scripts/spells/staff_strike.gd:37`, `tools/test_brawler.gd`
- Test: `tools/test_clock.gd`

**Interfaces:**
- Produces: `class_name GameClock`, `static func now() -> float`. It returns
  `Engine.get_physics_frames() / float(Engine.physics_ticks_per_second)`. In the real game this matches real time
  (physics frames keep ticking during hit stop, as the real clock does).

- [ ] Write `tools/test_clock.gd`: wait 30 physics frames and check that `GameClock.now()` advanced by 0.5 ± 0.001.
  Run it: it fails (no GameClock).
- [ ] Add GameClock. Swap the 6 gameplay uses of `Time.get_ticks_msec() / 1000.0`, and the 2 in test_brawler.
  Cosmetic pulses stay on the real clock.
- [ ] Run test_clock, test_brawler and the full suite. Everything passes. Commit "GameClock: gameplay timers on game time".

### Task 2: SimRunner (FFA and duel)
**Files:**
- Create: `tools/sim/sim_runner.gd`, `tools/sim/sandbox.gd`
- Modify: `.gitignore` (add `tools/sim/out/`)
- Test: `tools/test_sim.gd`

**Interfaces:**
- Produces: `class_name SimRunner extends Node`. It has:
  - `var mode := "ffa"` ("ffa" | "duel")
  - `var rounds := 10`
  - `var pool: Array[String] = Shop.SPELLS.keys()`
  - `var out_path := ""`
  - `var records: Array[Dictionary]`
  - `signal finished`
  - `static func loadouts(pool) -> Array` returns `[]`, each `[a]` and each `[a, b]` with a < b (29 for 7 spells).
- Each record is a Dictionary with:
  - `round`, `secs`, `timeout` (bool)
  - `wizards: [{name, loadout: Array, won: bool, kills: int, died: bool, lava_death: bool, casts: {slot_or_id: n}}]`
- Sandbox CLI: `godot --headless --fixed-fps 60 --path . -s tools/sim/sandbox.gd -- mode=ffa rounds=500 seed=7 out=tools/sim/out/w7.jsonl`

- [ ] Write `tools/test_sim.gd`. It runs SimRunner in-process (duel, 3 rounds, then ffa, 3 rounds) and checks:
  - `loadouts(7 ids).size() == 29`
  - 3 records per mode; duel has 2 wizards and ffa has 4
  - each wizard's D/F spells equal its logged loadout at fight start, with no extra spells
  - `game.gold` is 0 for everyone and `items` are empty
  - a winner record has `won` and the others don't (or every one is false on a draw / timeout)
  - every record has all its keys
  - a kill is credited using GameClock. Rig a lava death 2 s after a hit and check it's credited.

  Run it: it fails.
- [ ] Implement SimRunner. Setup:
  - On the game: `title_screen = false`, `apply_settings = false`, `feel_effects = false`, `countdown_time = 0.05`,
    `round_over_time = 0.05`, `gold_per_round = 0`, `gold_per_kill = 0`, `gold_for_win = 0`, `wins_to_take_match`
    very large. With no gold, `can_shop` is false, so `open_shop` goes straight to `start_round`.
  - The player gets an AIController with a neutral personality (as `tools/playtest.gd` does).
  - Duel: free BotGreen and BotPurple and erase them from `all_wizards`.
  - On `round_started`: remove the D/F spells, then give each wizard a random loadout (via `free_slot`, then add
    the spell node as `Shop.buy_spell` does, without paying).
  - Kill credit is your own: the last damage source and its `GameClock` time from `damaged`, credited on `died`
    within 10 s.
  - Casts are counted from `cast_started` (the slot maps to the spell id for D/F).
  - A 180 s game-time timeout ends the round with `timeout = true` (force `_end_round(null)`).
  - It writes JSON lines and emits `finished` after `rounds`.
- [ ] Run test_sim and the full suite. Both pass. Commit "Sim sandbox: SimRunner (ffa / duel) + entry script".

### Task 3: Parallel runner + analysis
**Files:**
- Create: `tools/sim/run.py`, `tools/sim/analyze.py`
- Test: `tools/sim/test_analyze.py`

**Interfaces:**
- `run.py --mode ffa --rounds-per-worker R --workers 16` starts the workers with seeds 1..N, writes
  `tools/sim/out/<mode>/w<seed>.jsonl`, then calls analyze.
- `analyze.py <dir>` writes `<dir>/report.md` and `<dir>/synergy.svg`. Functions:
  - `wilson(wins, n) -> (p, lo, hi)`
  - `rates(records) -> {loadout_key: (wins, n)}`
  - `synergy(rates, a, b) -> (s, lo, hi)`, where s = p(a+b) − p(a) − p(b) + p(none) and the CI is ±1.96·√Σvar
- The report has:
  - a table of every loadout with its win rate, CI and n
  - pairs ranked by synergy, flagging "real" when the CI excludes 0
  - the bias note from the spec
  - lava-kill share and the average round length

- [ ] Write `test_analyze.py` (unittest):
  - `wilson(25, 100)` gives about (0.25, 0.175, 0.343)
  - synergy on hand-made rates: p(ab)=.5, p(a)=.3, p(b)=.3, p(none)=.2 gives 0.1
  - `rates` on 3 fake records counts wins per loadout

  Run it: it fails.
- [ ] Implement analyze.py and run.py. The tests pass.
- [ ] Smoke run: 4 workers × 5 rounds of duel. A report appears. Commit "Sim sandbox: parallel runner + synergy report".

### Task 4: Scenario mode
**Files:** Modify `tools/sim/sim_runner.gd`, `tools/sim/sandbox.gd`. Test: extend `tools/test_sim.gd`.

**Interfaces:**
- `mode=scenario file=tools/sim/scenarios/<name>.json`. The JSON has:
  - `wizards: [{loadout, pos: [dx, dy] from centre, ai: bool}]`
  - `cast: {who, slot_or_id, at: [dx, dy]}`
  - `until: "death"|"secs"`
  - `secs`
  - `repeats`
- Each repeat logs a record with `deaths: [names]`, `lava_deaths`, and the final positions.
- Example file: `tools/sim/scenarios/well_lava_edge.json`. The enemy stands just inside the lava edge, the caster
  has no AI, and it casts Gravity Well beyond the enemy, 3 s, 20 repeats.

- [ ] Write the test: the example scenario with 3 repeats gives 3 records with a `deaths` key. Run it: it fails.
- [ ] Implement it. The test and the full suite pass. Commit "Sim sandbox: scenario mode".

### Task 5: The real run + docs
- [ ] Run FFA (16 workers, enough rounds for about 300 appearances per loadout, ~2200 rounds) and duel (~4400
  rounds), in the background. Read the reports with `data:statistical-analysis`.
- [ ] Copy `report.md` for both modes to `docs/sim/2026-11-27-pair-synergy.md` (committed).
- [ ] Update the GAME_DESIGN Progress in both copies: todo 13 gets step 1 (sandbox + data) done. Commit and push Android.
