# Warlocks on Android

A top-down pixel-art arena brawler for Android. Four wizards fight on a stone
platform in a sea of lava. Spells mostly **knock back** rather than kill, so
the real danger is being blasted into the lava. The platform shrinks during
each round, so every fight ends.

**Version 0.6** — you against three AI bots, rounds and matches.

Made with Godot 4.7.2 (GDScript); pixel art made with PixelLab.

## How to play
- **Last wizard standing wins the round. First to 5 round wins takes the match.**
- Standing on lava burns you. The more damage you've taken, the further hits
  push you.
- Every 25 s the lava rises and the platform gets smaller. A glowing line
  shows where the new edge will be. At its smallest the platform holds for
  25 s, then sudden death: the edge keeps creeping in until nobody is left
  standing.
- Knocking someone into the lava counts as your kill.

### Controls (touch)
| Control | Action |
|---|---|
| Left half of the screen | Floating joystick — walk |
| Big button (bottom right) | Staff swing on the spot; hold to keep swinging |
| Fireball | Tap = auto-aim at the nearest enemy; drag to aim; drag back onto the button to cancel |
| Blink | Short teleport (tap = forward, or drag to aim) |
| Lightning | Short-range bolt with big knockback |
| Shield | 1.5 s bubble that reflects projectiles |

### The bots
| Colour | Personality | Plays like |
|---|---|---|
| Blue | Brawler | Gets close: staff and lightning, reflects your fireballs with the shield |
| Green | Caster | Keeps its distance, spams fireballs, zaps anyone who gets close |
| Purple | Trickster | Mid range, blinks in to shove you into the lava |

## Install
Build a debug APK and install it on a USB-connected phone (USB debugging on):
```bash
bash tools/deploy_android.sh
```
The APK ends up in `build/warlocks_on_android.apk` (not committed).

## Development
- Engine: Godot 4.7.2, Compatibility renderer, landscape, immersive.
- This is the Android version of a PC project (keyboard + mouse). Gameplay is
  written in the PC project first and brought over with `git cherry-pick`.
- **Read [`GAME_DESIGN.md`](GAME_DESIGN.md) first** — the full design plus a
  *Progress* section with what is built, what changed from the plan, and
  what is next.
- Design records: [`docs/superpowers/specs/`](docs/superpowers/specs/)
  (AI bots, rounds).

### Project layout
| Path | What |
|---|---|
| `scenes/game.tscn`, `scripts/game.gd` | Match flow: rounds, score, spawning, camera |
| `scripts/round_hud.gd` | Scoreboard, banners, kill feed, results screen |
| `scripts/arena.gd` | Lava map built in code from Wang tiles; shrinking + sudden death |
| `scripts/wizard.gd` | A wizard: movement, health, knockback, lava, animations |
| `scripts/spells/` | Fireball, Blink, Lightning, Shield, Staff strike |
| `scripts/touch_controls.gd` | Joystick and spell buttons |
| `scripts/ai/`, `ai/` | Bot brain, personalities and difficulty profiles |
| `tools/` | Tests, AI simulation, demo recorder, deploy script |

### Tests
```bash
GODOT=/d/Godot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe
for t in wizard fireball spells staff ai arena rounds; do
  "$GODOT" --headless --path . -s tools/test_$t.gd
done
"$GODOT" --path . -s tools/test_touch.gd   # needs a window (no --headless)
```
Each prints `ok` / `FAIL` lines and exits non-zero on failure.
`tools/sim_ai.gd -- <easy|normal|hard> [seconds]` runs a bots-only fight and
prints stats.

## Roadmap
1. ~~Arena~~ 2. ~~Wizard~~ 3. ~~Fireball + knockback~~ 4. ~~Blink, Lightning, Shield~~
5. ~~AI bots~~ 6. ~~Rounds, score, shrinking arena, win screen~~
7. **Shop between rounds** — gold, spell upgrades, items
8. Polish — screen shake, hit flash, particles, sounds, menu
9. More spells — homing orb, boomerang, meteor, gravity well, swap, time stop
