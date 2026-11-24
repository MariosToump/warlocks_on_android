# Rounds, Score, Shrinking Arena, Win Screen — Design (Milestone 6)

_2026-11-24 — written after the build, records what was made and why._

## Intent
Turn the endless free-for-all into a match with an ending: last wizard
standing wins the round, first to 5 round wins takes the match. The platform
shrinks so no round can stall, and kills are tracked because the shop
(milestone 7) pays gold for them.

## Rules as built
- **Match:** first to `wins_to_take_match` (5) round wins. Then a results
  screen ranked by wins, then kills, with **Play again** (new match, scores
  back to zero).
- **Round start:** everyone is placed on a flat ellipse around the middle
  (`spawn_distance` 260 px wide, half as tall, random rotation and order,
  facing in). 3 s countdown (`countdown_time`): controls off, camera centred
  on the arena so all four wizards are on screen, banner "Round N" + 3-2-1.
- **Fight:** "Fight!" banner, controls on, camera glides back to the player,
  the lava timer starts.
- **Dead stay dead.** Every frame of the fight the game counts the living;
  at 1 or fewer the round ends. Checking every frame (not only on a death
  signal) means same-tick deaths all count and nothing slips by.
  0 alive = **draw**, nobody scores.
- **Round over:** 3 s banner (`round_over_time`) — "You win the round!",
  "Blue wins the round!" + "2 / 5", or "Draw!". Controls off, lava frozen.
- **Next round resets:** full platform, full health, cooldowns to 0,
  leftover projectiles / bolts / effects freed, bot brains `reset()`.
- **Kills:** a death counts for `victim.last_attacker` if they hit within
  `kill_credit_window` (10 s), so knocking someone into lava is a kill.
  Lava alone with no recent hit = no kill. Kills only count during a fight.
- **Spectating:** `spectate_delay` (1.5 s) after the player dies, the camera
  follows their killer (or the first wizard alive), switching if that one
  dies too.

## Shrinking arena
`scripts/arena.gd`, phases `WAIT → SHRINK → … → HOLD → FINAL`:
- Every `shrink_delay` (25 s) the edge creeps in `shrink_step_tiles` (9) at
  `shrink_speed` (3 tiles/s). A pulsing line marks the coming edge for
  `shrink_warning` (4 s) first; HUD says "Lava rises in N".
- 38 → 29 → 20 → 11 tiles (`min_radius_tiles`), held for `min_hold` (25 s).
- Then, in rounds (`regrows = false`): **sudden death** — the edge keeps
  creeping in at `final_shrink_speed` (0.6 tiles/s) until nothing is left
  ("Sudden death in N", then "Sudden death!"). In endless mode
  (`regrows = true`) the platform regrows instead.
- Tiles update incrementally (only cells around changed vertices are
  repainted); cracked stone near the new edge turns plain, since the two
  tile sheets can't meet in one cell.
- Measured: bots-only rounds (player idle) end in 60–100 s.

## HUD (`scripts/round_hud.gd`, all built in code)
- **Scoreboard**, top-left: colour swatch, name ("You", "Blue", …),
  one pip per round win needed (filled = won), kills. Dead wizards dimmed
  during a fight.
- **Banner + sub-line**, upper centre (kept above the player's head).
- **Kill feed**, top-right: "Purple took out Green" in team colours, fades
  after 4 s.
- **Match panel**, centre: title in the winner's colour, standings, Play
  again button (grabs focus; works with touch).

## Code map
| What | Where |
|---|---|
| State machine `FREE / COUNTDOWN / FIGHT / ROUND_OVER / MATCH_OVER` | `game.gd` `_process` |
| `start_match()`, `start_round()`, `_begin_fight()`, `_end_round()` | `game.gd` |
| Signals `round_started`, `fight_started`, `round_ended`, `match_ended`, `kill_scored` | `game.gd` → `RoundHud` |
| Controls on/off | `game.gd` `_set_controls()` — disables `PlayerController` / `AIController`; Android also sets `TouchControls.locked` |
| Who hit whom | `Wizard.take_damage(amount, source)` → `last_attacker`, `last_hit_at` |
| Bot memory wipe | `AIController.reset()` |
| Endless mode | `game.rounds = false` (dead respawn after `respawn_delay` on a safe point far from others) |

## Tests
- `tools/test_rounds.gd` — countdown lock, spawn ellipse, kill credit (with
  and without attacker), last-standing win, round reset (health, cooldowns,
  projectiles, platform), draw, spectate the killer, match win, standings
  order, Play again. Android adds touch-lock checks.
- `tools/test_arena.gd` — warning, step shrink, incremental tiles match a full
  rebuild, minimum, regrow, sudden death to radius 0 (whole map lava).
- All older tests run with `game.rounds = false`.

## Not done / later
- No menu: difficulty and wins-to-match are exports on `game.gd`.
- No sounds, screen shake or particles for round events (milestone 8).
- Gold from kills and wins is not paid out yet (milestone 7 shop).
- Caster (Green) bot wins most bots-only rounds; balance pass later.
