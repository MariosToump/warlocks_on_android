# Smarter, less predictable bots — design (v0.10)

_2026-11-26. Approved in conversation (the user picked every option marked "Recommended")._

## Why
The bots feel dumb because their patterns are easy to read, not because they play badly. The user's notes from playing against them:
- **Blue (Brawler)** always charges straight at you. He never dodges and only ever shields. The cause is his
  weights: shield 1.4 × 1.8 beats dodge 1.0 × 2.0 every time.
- **Green (Caster)** always snipes from range. That's close to the best strategy, so he is the strongest bot and
  you have to out-wait him.
- **Purple (Trickster)** mixes the two but has no defining character.
- Everyone goes fully aggressive from the very first second. Nobody ever waits and watches.

The cause in the code: each think (every 0.3 s) takes the top-scored action, and the score noise is only ±0.05. So
the same situation almost always gets the same answer. Aim always leads by the same amount, and the reaction delay
never changes.

## Goals
- Bots feel like players: they make small mistakes, play differently from round to round, and jump on an opening.
- Each bot has a clear character: a smarter charger (blue), a sniper (green), an opportunist (purple).
- The "wait and see" opening exists: some rounds, a bot watches first and punishes whoever commits.
- Balance stays healthy. Measured with `tools/playtest.gd` (Normal, 20+ matches):
  - no bot wins more than 40% of rounds
  - the Brawler wins at least 15% of rounds
  - at least 50% of deaths are in lava
  - fights last 35-60 s on average
  - matches last 5-8 min

## Non-goals
- No rewrite to a behavior tree. The per-spell `_score_X` / `_do_X` pairs stay.
- No new spells, and no changes to the Lightning rework (that's a separate item).
- No bait or feint behavior for the Brawler. The user chose "smarter charger" only.

## Anti-goals (a failure even if it works)
- **Cheating.** A bot must never read an enemy's cooldown timer, HP it couldn't see, or the future. Everything it
  knows has to be something a human watching the screen would know: positions, HP bars, spells it saw being cast,
  and the base cooldowns any player learns.
- Bots that freeze or dither. The opening watch is capped and broken early when someone attacks.
- Bots that walk into lava "randomly". Getting off lava (`recover`) is never randomized.

## Approaches considered
1. **Add a human layer on top of the existing scoring (chosen).** Keep the scorers. Add:
   - weighted-random choice among the near-best actions
   - human noise (reaction time, aim, hesitation)
   - a mood rolled each round
   - a memory of seen casts
   - an "opportunity" score that drives risk-taking

   This is the smallest change and keeps all of today's tuning and tests. New spells plug in by adding their scorers.
2. **Behavior-tree rewrite.** Easier to read per personality, but every number would have to be tuned again from zero
   and every AI test rewritten. Rejected: far more sim time for the same result.
3. **One separate script per personality.** Clear characters, but the shared logic gets duplicated three times, and
   each future spell needs three versions. Rejected.

## Design

### 1. Weighted-random choice (`ai_controller.gd::_think`)
- Score every action as today.
- If the best action is `recover`, take it.
- Otherwise, every action scoring at least `best × (1 − profile.choice_spread)` is a candidate. One is drawn with
  probability ∝ (score − cutoff + small epsilon), so the top action is still the most likely.
- `choice_spread`: Easy 0.30, Normal 0.20, Hard 0.12.

### 2. Human noise (new `AIProfile` fields)
- **Reaction time per projectile:** `reaction_delay × randf_range(1 − reaction_jitter, 1 + 2 × reaction_jitter)`,
  rolled once per projectile with the existing dodge and shield rolls. `reaction_jitter`: Easy 0.4, Normal 0.35,
  Hard 0.25.
- **Aim:** the error is drawn from a bell curve (`randfn(0, aim_error_deg × 0.6)`, clamped to ±2× `aim_error_deg`)
  instead of a flat spread.
- **Lead:** rolled each cast as `lead_amount ± lead_jitter`, clamped to 0..1.2. Sometimes the bot leads too much,
  sometimes too little. `lead_jitter`: 0.35 on every profile.
- **Hesitation:** each think, with `hesitate_chance`, an attack action is held for one think. The bot keeps moving
  and doesn't attack. Defensive actions are never held. `hesitate_chance`: Easy 0.12, Normal 0.07, Hard 0.03.

### 3. Mood per round (new `scripts/ai/ai_mood.gd`)
`reset()` rolls one of three moods from the personality's `mood_odds`:

| Mood | Attack actions | Dodge / shield | Preferred distance | Opening watch | Risk appetite |
|---|---|---|---|---|---|
| aggressive | ×1.1 (was ×1.2) | ×1.0 | ×0.9 (was ×0.8) | 0 s | ×1.15 (was ×1.3) |
| cautious | ×0.85 | ×1.15 | ×1.25 | 2-4 s | ×0.6 |
| opportunist | ×1.0 | ×1.0 | ×1.15 | 3-5 s | ×1.5 |

- Attack actions are fireball, lightning, staff, blink_in and homing.
- A controller that was never `reset()` (unit tests) has a neutral mood: every multiplier 1, no watch.

### 4. Opening watch ("wait and see")
- While `_now < _watch_until`, attack scores are ×0.15, so the bot only attacks a target with a very high
  opportunity score.
- It keeps at least 260 px from its target, circling. Dodge, shield and recover work as normal.
- The watch ends early when the bot is hit, or when any enemy's opportunity score reaches 0.6.
- `_now` only advances while the bot's brain is on, so the countdown doesn't use up the watch.

### 5. Memory of seen casts (new `scripts/ai/ai_memory.gd`)
- It connects to every other wizard's `cast_started(slot)`, which the bot "sees" on screen, and stores the time of
  the last shield (R) and blink (W) per enemy.
- `shield_probably_down(w)` and `blink_probably_down(w)` are true while `now − seen < estimate`. The estimate is the
  base cooldown of the bot's **own** spell in that slot (public knowledge), × 0.9 to stay on the safe side.
- It never reads `w`'s spell nodes or their `cooldown_left`.

### 6. Opportunity and risk-taking
`opportunity(w)` returns 0..1, the sum of these, capped at 1:

| Condition | Adds |
|---|---|
| HP < 35% | 0.35 |
| near lava | 0.25 |
| shield probably down | 0.25 |
| blink probably down | 0.15 |
| being knocked back (> 200 px/s) | 0.3 |
| mid-cast | 0.15 |
| hit by someone else in the last 1.5 s (busy fighting) | 0.2 |

It's used in three places:
- Attack scores are × (1 + `risk` × opportunity), where `risk` = personality `risk_appetite` × the mood's
  multiplier.
- `_pick_target` cost is − opportunity × 220 × `risk`.
- ~~The `blink_in` maximum distance grows to 300 px when opportunity ≥ 0.5~~ — dropped after review: Blink's own
  range (200 px) already caps it, so it could never fire.
- An urgent `recover` (score ≥ 2.5: on lava, lava arriving, or flying toward it) is taken before any multiplier or
  random pick (review finding: boosted attacks could outrank it).

### 7. Personalities (`.tres`, new fields `risk_appetite`, `mood_odds`, and Brawler-only behavior)
- **Brawler (blue), the smarter charger.**
  - Weights: dodge 1.0 → 1.4, shield 1.4 → 1.1, so he can dodge now.
  - While closing in from beyond 120 px, he zig-zags. The goal is offset ±40 px across his approach line, and the
    side flips every 0.4-0.7 s.
  - He waits for an opening, holding just **outside lightning range** (his own Lightning's `max_range` + 20 px, so
    250 px today; first tried at 130 px, but that left him standing inside zap range). He charges to 50 px when the
    target's opportunity is ≥ 0.4, when the target threw a fireball or orb in the last 1.2 s, or when the target used
    Lightning recently enough that it is probably still recharging.
  - Fireball weight 0.5 → 0.8, so he pokes while he waits.
  - `risk_appetite` 1.0. Mood odds: aggressive 0.45, cautious 0.15, opportunist 0.4 (tuned from 0.6 / 0.15 / 0.25).
- **Caster (green), the sniper.** He keeps his style. Mood variety and the noise make him beatable.
  `risk_appetite` 0.5. Mood odds: aggressive 0.3, cautious 0.45, opportunist 0.25.
- **Trickster (purple), the opportunist.** He hangs back and goes after enemies that are busy fighting or hurt.
  - Target cost uses opportunity × 1.5.
  - `blink_in` weight stays high, at 1.6.
  - `risk_appetite` 1.2. Mood odds: aggressive 0.2, cautious 0.2, opportunist 0.6.
- **Player stand-in in the harness.** It uses a default personality: neutral, odds 1/3 each, `risk_appetite` 0.8.

### 8. Measurement
- `tools/playtest.gd` prints the round-win share per mood, next to the per-bot share.
- Tuning loop: change → run 20 matches → read the result with the `data:statistical-analysis` skill. With about 200
  rounds, the standard error of a share is about 3%, so only differences over about 6 points count as real.

## Tuning log (Normal, `tools/playtest.gd`)
| Run | Rounds | Brawler | Caster | Trickster | Stand-in | Lava deaths | Match | Notes |
|---|---|---|---|---|---|---|---|---|
| v0.9 before | ~120 | 6% | 44% | 20% | 30% | 59% | 5:28 | |
| 1 | 137 | 12% | 38% | 23% | 28% | 62% | 6:39 | first build |
| 2 | 269 | 7% | 39% | 27% | 27% | 64% | 6:25 | 40 matches; aggressive mood loses for every bot |
| 3 | 279 | 10% | 39% | 25% | 26% | 64% | 6:40 | hold outside lightning range; softer aggressive |

## Left to the builder
- Exact constant values beyond the ones above (tune by sims).
- How the zig-zag offset is computed.
- Where the helpers live inside `ai_controller.gd`.
