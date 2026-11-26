# Smarter Bots Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make bots less predictable and more human: weighted-random choice, noise, a mood each round, an opening
watch, a fair memory of seen casts, opportunity-driven risk, and distinct personalities.

**Architecture:** A layer on top of the existing utility AI in `scripts/ai/ai_controller.gd`. Two small new helper
classes, `AIMood` and `AIMemory`, plus new exported fields on `AIProfile` and `AIPersonality`. The per-spell
`_score_X` / `_do_X` pairs stay.

**Tech Stack:** Godot 4.7.2, GDScript. Tests are headless SceneTree scripts in `tools/`.

**Spec:** `docs/superpowers/specs/2026-11-26-smarter-bots-design.md`

## Global Constraints
- No cheating: never read another wizard's `Spell.cooldown_left` or its spell nodes. Use only positions, HP, seen
  casts, and the bot's own base cooldowns.
- `recover` is never randomized, held or watched away.
- A controller that is never `reset()` behaves like today, apart from the noise (neutral mood, no watch), so the
  existing `tools/test_ai.gd` tests stay valid.
- Run tests with: `"D:/Godot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe" --headless --path . -s tools/test_X.gd`
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus
1. Sudden death with 2 wizards, both bots in a cautious watch: the fight must still happen. The watch is capped at
   5 s and broken by being hit or by an opportunity of 0.6 or more. Test: `_test_watch_ends`.
2. A bot on lava while "hesitating": it still recovers. Test: `_test_recover_never_random`.
3. An enemy freed mid-round (a death or a ghost): the memory handles freed instances. Test: `_test_memory_freed_enemy`.
4. The harness player has a personality with no `mood_odds`: it falls back to 1/3 each. Covered by the playtest run.
5. A target that shields **again** before the estimate expires: the memory refreshes the time. Test:
   `_test_memory_shield_window`.

---

### Task 1: Weighted choice + human noise

**Files:** Modify `scripts/ai/ai_profile.gd`, `ai/profiles/{easy,normal,hard}.tres` and `scripts/ai/ai_controller.gd`
(`_think`, `_roll`, `_visible_projectiles`, `_aim_at`). Tests go in `tools/test_ai.gd`.

**Interfaces:**
- Produces these profile fields:
  - `choice_spread: float`
  - `reaction_jitter: float`
  - `lead_jitter: float`
  - `hesitate_chance: float`
- Produces `AIController._choose(scores: Dictionary) -> String` (pure, testable).
- `_roll(p)` returns `[dodge: bool, shield: bool, react: float]`.
- Produces `const ATTACKS := ["fireball", "lightning", "staff", "blink_in", "homing"]`.

- [ ] **Test** `_test_weighted_choice`:
  - `_choose({"a": 1.0, "b": 0.9, "c": 0.5})` over 400 draws with spread 0.2: picks both "a" and "b", "a" more
    often, never "c".
  - `{"recover": 2.5, "dodge": 2.4}` always gives "recover".
- [ ] **Test** `_test_reaction_jitter`:
  - 200 rolls with the Normal profile: every `react` lies in [0.25 × 0.65, 0.25 × 1.7].
  - The min and max differ by more than 0.1.
- [ ] **Test** `_test_aim_noise`: 300 `_aim_at` calls on a still target 300 px away: the angle error stays within
  ±2 × `aim_error_deg`, and more than half are within ±0.6 × `aim_error_deg`.
- [ ] Run the tests and confirm the new ones fail.
- [ ] **Implement:**
  - Add the fields with these values:

    | Field | Easy | Normal | Hard |
    |---|---|---|---|
    | `choice_spread` | 0.30 | 0.20 | 0.12 |
    | `reaction_jitter` | 0.4 | 0.35 | 0.25 |
    | `hesitate_chance` | 0.12 | 0.07 | 0.03 |
    | `lead_jitter` | 0.35 | 0.35 | 0.35 |

  - Add `_choose`.
  - Change `_think` to collect scores, then call `_choose`. Hesitation only applies to `ATTACKS`: it holds the
    previous movement goal, so the bot doesn't attack.
  - `_visible_projectiles` uses the rolled `react`.
  - `_aim_at` uses `randfn` for the aim error and a jittered lead.
- [ ] Run `test_ai` and confirm everything passes, old tests included.
- [ ] Commit "AI: weighted-random choice, reaction / aim / lead noise, hesitation".

### Task 2: Mood + opening watch

**Files:** Create `scripts/ai/ai_mood.gd`. Modify `scripts/ai/ai_personality.gd` (`mood_odds`, `risk_appetite`)
and `ai_controller.gd` (`reset`, `_think`, `_do_reposition`, `_pick_target`). Tests go in `tools/test_ai.gd`.

**Interfaces:**
- Produces `class_name AIMood extends RefCounted` with these fields:
  - `name: String`
  - `attack_mult: float`
  - `defend_mult: float`
  - `distance_mult: float`
  - `risk_mult: float`
  - `watch_min: float`
  - `watch_max: float`

  Plus `static func roll(odds: Dictionary) -> AIMood` and `static func neutral() -> AIMood`.
- Controller additions:
  - `var mood: AIMood`
  - `var _watch_until := 0.0`
  - `func watching() -> bool`
  - `func preferred_distance() -> float`, which replaces direct reads of `personality.preferred_distance`
- Personality fields:
  - `mood_odds := {"aggressive": 1/3., "cautious": 1/3., "opportunist": 1/3.}`
  - `risk_appetite := 0.8`
- Mood values are as in the spec table.

- [ ] **Test** `_test_mood_roll`: 600 rolls with the Trickster odds give an opportunist share of 0.6 ± 0.08, and all
  3 moods appear.
- [ ] **Test** `_test_watch_blocks_attacks`:
  - The Caster, after `reset()` with mood forced to cautious and `_watch_until` = now + 2, against an enemy at
    300 px: no projectile is cast in 1.5 s.
- [ ] **Test** `_test_watch_ends`:
  - Same setup, but the bot is hit by a fireball: `watching()` becomes false.
  - With no hit, the watch is false after 5.1 s.
- [ ] **Test** `_test_recover_never_random`: a bot placed on lava with `hesitate_chance` 1.0 picks `recover` on
  every think for 1 s.
- [ ] Run the tests and confirm the new ones fail.
- [ ] **Implement:**
  - `reset()` rolls the mood and sets `_watch_until = _now + randf_range(watch_min, watch_max)`.
  - `_think` applies `attack_mult` and `defend_mult`, plus ×0.15 on attacks while watching.
  - The watch breaks when `wizard.last_hit_at` changes during the watch, or when any enemy's opportunity is 0.6 or
    more (stub opportunity as 0 until Task 3).
  - While watching, reposition keeps at least 260 px.
- [ ] Run `test_ai` and confirm it passes.
- [ ] Commit "AI: per-round mood and wait-and-see opening".

### Task 3: Memory of seen casts + opportunity + risk

**Files:** Create `scripts/ai/ai_memory.gd`. Modify `ai_controller.gd`. Tests go in `tools/test_ai.gd`.

**Interfaces:**
- Produces `class_name AIMemory extends RefCounted` with:
  - `func watch(w: Wizard)`, which connects `cast_started`
  - `func seen(w: Wizard, slot: String) -> float`, which returns the seconds since the bot saw it, or INF
  - `func clear()`
  - an internal Dictionary keyed by instance id, with `is_instance_id_valid` pruning
- Controller additions:
  - `var memory: AIMemory`
  - `func shield_probably_down(w) -> bool`
  - `func blink_probably_down(w) -> bool`
  - `func opportunity(w: Wizard) -> float`, using the spec's terms
  - `func risk() -> float`, which returns `personality.risk_appetite * mood.risk_mult`
  - `var hit_by_other_at` per enemy, from that enemy's `damaged(amount, source)` where the source isn't us
- The estimate is `wizard.get_spell(slot).cooldown` (the base value on our own spell, not the multiplied one) × 0.9.

- [ ] **Test** `_test_memory_shield_window`:
  - The enemy casts R: `shield_probably_down` is true at once.
  - It is false after the estimate passes.
  - A second cast refreshes the window.
- [ ] **Test** `_test_memory_no_cheat`: an enemy whose cooldown is set by code (`cooldown_left` = 5, no cast):
  `shield_probably_down` is false.
- [ ] **Test** `_test_memory_freed_enemy`: free a watched wizard mid-test, then `seen()` and opportunity work without
  errors.
- [ ] **Test** `_test_opportunity`:
  - A healthy target in the middle of the island scores below 0.1.
  - The same target at 20% HP next to lava after shielding scores at least 0.8.
- [ ] **Test** `_test_risk_prefers_exposed_target`: of two enemies at equal distance, the one with opportunity ≥ 0.6
  is picked.
- [ ] Run the tests and confirm the new ones fail.
- [ ] **Implement:**
  - Connect the memory in `_ready` / `reset` for every wizard in the `wizards` group except ourselves.
  - Apply attack × (1 + risk × opp).
  - Target cost − opp × 220 × risk.
  - `blink_in` reaches up to 300 px when opp ≥ 0.5.
  - The watch breaks at opp ≥ 0.6.
- [ ] Run `test_ai` and confirm it passes.
- [ ] Commit "AI: fair memory of seen casts, opportunity, risk-taking".

### Task 4: Personalities

**Files:** Modify `ai/personalities/{brawler,caster,trickster}.tres`, `scripts/ai/ai_personality.gd` (add
`zigzag := false`, `patient_charge := false`, `opportunist_targeting := 1.0`) and `ai_controller.gd`
(`_do_reposition`, `preferred_distance`, `_pick_target`).

- [ ] **Test** `_test_brawler_dodges`:
  - The Brawler (Normal) with its shield on cooldown, against 10 fireballs aimed at him from 300 px.
  - Over 10 trials he dodges (isn't hit) at least 3 times.
- [ ] **Test** `_test_brawler_zigzags`: while closing from 400 px, the sideways offset from the straight line goes
  past 15 px on both sides.
- [ ] **Test** `_test_brawler_waits_for_opening`:
  - Against a healthy target in the middle with no casts seen: his preferred distance is about 130.
  - After the target casts Q: it's 50.
- [ ] **Test** `_test_trickster_third_party`:
  - Enemy A is busy, hit by C a moment ago, at 300 px. Enemy B is idle at 250 px.
  - The Trickster targets A.
- [ ] Run the tests and confirm the new ones fail.
- [ ] **Implement** with the spec values.
- [ ] Run all tests and confirm everything passes.
- [ ] Commit "AI: smarter charger, sniper moods, opportunist Trickster".

### Task 5: Measure, tune, document

**Files:** Modify `tools/playtest.gd` (mood stats), the tuning constants and `.tres` values, both copies of
`GAME_DESIGN.md`, and the README if bot docs exist there.

- [ ] Add per-mood round-win share and per-bot mood counts to the playtest totals.
- [ ] Run `--headless --fixed-fps 60 --path . -s tools/playtest.gd -- 20 normal` and check against these targets:
  - no bot > 40% of round wins
  - Brawler ≥ 15%
  - lava deaths ≥ 50%
  - fights 35-60 s
  - matches 5-8 min
- [ ] Tune and repeat. Use `data:statistical-analysis` to judge whether a change is real or noise (±6 points).
- [ ] Run Easy and Hard once each to check that they're sane.
- [ ] Run the game with the Godot MCP and check there are no errors.
- [ ] Run every `tools/test_*.gd`. `test_touch` needs a window.
- [ ] Update Progress in both GAME_DESIGN copies: tick v0.10 item 1, record the results, and add the "terrain stone
  walls brainstorm" todo.
- [ ] Commit both repos, then push Android. No APK, no release.
