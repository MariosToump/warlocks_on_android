# AI Bots — Design (Milestone 5)

_2026-11-24_

## Intent
Replace the two training dummies with bots that fight back, so the arena is an
actual fight before rounds and scoring arrive in milestone 6. Bots should feel
different from each other (personalities) and be tunable for skill
(difficulty), so the same code serves a beginner and a practised player.

## Goals
- Bots move, aim, cast all their spells (fireball, blink, lightning, shield,
  staff), dodge projectiles and avoid lava.
- **Difficulty: Easy / Normal / Hard**, independent of personality.
- **Personalities: Brawler, Caster, Trickster**, independent of difficulty.
  Any personality can run at any difficulty.
- Free-for-all: bots attack the player *and* each other.
- Adding a spell (milestone 9) or a personality later = add one action or one
  weight set, no rewiring.

## Non-goals
- Rounds, score, win screen, shrinking arena (milestone 6). Bots still respawn
  2 s after dying, as dummies do now.
- A difficulty / personality menu. Values are exported on `game.gd` for now.
- Pathfinding. The arena is an open disc with no obstacles.
- New art or animations.

## Anti-goals (would make this a failure even if it "works")
- Bots that cheat: no reading the player's input, no seeing a projectile
  before it exists, no casting faster than the cooldowns allow.
- Perfect bots on Hard: reaction time and aim error never reach zero.
- Bots that walk into lava by themselves, or stand still.
- All three personalities playing the same way.

## Constraints
- Godot 4.7.2, GDScript only.
- `Wizard` reads no input; a controller child node sets `move_target` /
  `move_dir` and calls `cast(slot, point)` / `attack(enemy)`.
  `PlayerController` is the model to follow.
- Spells as they are: Fireball 560 px/s, 700 range, 2 s cd; Lightning 230
  range instant line, 5 s cd; Blink 200 px, cancels knockback, 6 s cd; Shield
  1.5 s, reflects projectiles / blocks lightning, 10 s cd; Staff 30 px range,
  0.5 s swing.
- Lava check: `arena.is_lava_at(pos)`. Wizards are in group `wizards`.

## Approaches considered
1. **Utility scoring (chosen).** A few times a second the bot scores every
   possible action for the current situation and does the best one.
   Personality = weights on those scores; difficulty = perception and
   execution limits. Easy to extend; needs a tuning pass because weights
   interact.
2. **State machine with personality thresholds** (approach / fight / flee /
   dodge). Easier to debug, but personalities collapse into "same bot,
   different numbers" and new spells mean rewiring states. Rejected.
3. **Behaviour tree.** Too heavy for six spells. Rejected.

## Design

### Parts
- `scripts/ai/ai_controller.gd` (`class_name AIController`): child of a
  Wizard, like `PlayerController`. Owns perception, the think loop and
  execution.
- `scripts/ai/ai_profile.gd` (`class_name AIProfile`, Resource): one
  difficulty's numbers. Three `.tres` files in `ai/profiles/`.
- `scripts/ai/ai_personality.gd` (`class_name AIPersonality`, Resource):
  weights per action plus preferred fighting distance. Three `.tres`.
- Actions live inside `AIController` as `_score_<action>()` /
  `_do_<action>()` function pairs, listed in one array. (Builder's call to
  split into classes if it gets long.)
- Projectile joins group `projectiles` in `_ready` so bots can see them.

### Think loop
- Every `think_interval` (profile) the bot picks a target, scores all
  actions, multiplies each by its personality weight, and runs the best one.
- A small bonus for keeping the current action (hysteresis) stops jitter.
- Movement is continuous between thinks: the chosen action sets a
  `move_target` that `_physics_process` keeps updating.
- **Safety runs every physics frame, not on the think tick**: if the next
  ~0.3 s of the bot's own walk would end on lava, the walk is redirected
  toward the arena centre.

### Target choice
Nearest living enemy, weighted toward low health and toward enemies close to
lava (an easy push). Re-evaluated each think; the bonus for keeping the
current target avoids flip-flopping.

### Actions
| Action | Scores high when | Does |
|---|---|---|
| Dodge | an enemy projectile will pass within ~20 px of the bot within ~0.6 s | sidestep perpendicular to its path, toward the safer side (away from lava) |
| Recover | on lava, or knocked toward lava, or standing near the edge | walk toward the centre; blink toward the centre if on lava / flying fast toward it and blink is ready |
| Shield | projectile about to hit and dodge would fail, or an enemy is mid-cast at close range | cast R |
| Fireball | target within range, clear line, cooldown ready | cast Q at the predicted position (lead) |
| Lightning | target within ~220 px, ideally with lava behind it | cast E |
| Staff | target close, especially with lava behind it | `attack(target)` |
| Blink-in | Trickster-ish: target near lava and out of reach | blink next to the target on the far side from the lava, then hit |
| Reposition | default | move toward the personality's preferred distance from the target, strafing, staying on the side of the target away from lava |

### Personalities (weights, starting points)
- **Brawler**: preferred distance ~40 px; staff and lightning high, fireball
  low; shields often; rarely retreats.
- **Caster**: preferred distance ~350 px; fireball high; backs off when
  approached (blinks away if cornered); dodges a lot.
- **Trickster**: preferred distance ~180 px; blink-in and "push toward lava"
  setups high; tries to stand so the target is between itself and the lava.

### Difficulty profiles (starting points)
| | Easy | Normal | Hard |
|---|---|---|---|
| think_interval | 0.5 s | 0.3 s | 0.15 s |
| reaction delay (sees projectiles late) | 0.45 s | 0.25 s | 0.12 s |
| aim error (degrees, random) | 18 | 8 | 3 |
| leads moving targets | no | partly (50%) | yes |
| dodge chance | 30% | 65% | 90% |
| uses shield to reflect | rarely | sometimes | yes |
| extra pause between casts | 1.0 s | 0.4 s | 0.1 s |

"Reaction delay" = the bot only learns about a projectile once it has existed
for that long. "Dodge chance" is rolled once per projectile.

### Game setup
- `game.gd`: the dummies are replaced by three bots, Blue = Brawler,
  Green = Caster, Purple = Trickster, all on `bot_difficulty` (exported,
  default Normal). `spawn_dummies` becomes `spawn_bots`.
- Spawn positions spread around the centre, ~250 px from the player.

### Debug
An exported `debug_draw` on `AIController` draws the bot's current action
name and target line above its head. Off by default.

## Tests
- `tools/test_ai.gd` (headless, like the other tests):
  - a bot placed next to lava, with nothing else happening, never ends up on
    lava over 10 s;
  - a bot facing an incoming fireball on Hard dodges or shields it in most
    trials;
  - a bot with an enemy in range casts a fireball within 2 s;
  - Brawler ends up closer to its target on average than Caster.
- Existing tests still pass.
- Manual playtest at each difficulty.

## Left to the builder
- Exact weights and thresholds (expected to be tuned in playtests).
- Whether actions stay as functions or become small classes.
- Exact sidestep and lead maths.
- Any further debug display.
