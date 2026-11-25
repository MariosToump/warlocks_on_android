# Warlocks on Android

A top-down pixel-art arena brawler for Android. Four wizards fight on a stone
platform in a sea of lava. Spells mostly **knock back** rather than kill, so
the real danger is being blasted into the lava. The platform shrinks during
each round, so every fight ends.

**Version 0.8.1** — you against three AI bots in matches of rounds, with a shop between rounds, sound and music, and a title menu.

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

### The shop
After every round you get gold — 10, plus 5 per kill, plus 5 if you won the round — and 15 seconds to spend it
(tap **Ready** to start sooner). The bots shop too.
- **Upgrade a spell** (10 / 15 / 20 gold for levels 1-3): more damage and knockback, or shorter cooldowns.
- **Homing Orb** (15 gold): a new spell in a new button left of the fireball. A slow purple orb that curves
  toward the nearest enemy. A shield sends it back at you!
- **Items** (2 at most, sell for half price): Boots +15% speed, Stone Cloak -20% knockback taken,
  Fire Ring -50% lava damage, Focus Gem -10% cooldowns.
- A new match starts everyone from scratch.

### Controls (touch)
| Control | Action |
|---|---|
| Left half of the screen | Floating joystick — walk |
| Big button (bottom right) | Staff swing on the spot; hold to keep swinging |
| Fireball | Tap = auto-aim (nearest enemy in range, ones you can see first, aimed ahead of a walker); drag to aim (the guide shows the full range); drag back onto the button to cancel |
| Blink | Short teleport (tap = forward, or drag to aim) |
| Lightning | Short-range bolt with big knockback |
| Shield | 1.5 s bubble that reflects projectiles |
| Homing Orb (once bought) | Tap = toward the nearest enemy in range; drag to aim |
| II button (top right) or Back | Pause: resume, restart, quit to the menu, settings |

### On screen
- **Scoreboard** (top left): health, round wins and kills for everyone; below it, how much further you fly when hit.
- **Minimap** (top right): the platform, where the lava is about to rise, and everyone's position.
- **Arrows** on the screen edge point at enemies you can't see. Bigger = closer; they flash while that enemy casts.
- Damage numbers over whoever gets hit (red ones are yours); the screen edges glow red when you're in or next to lava;
  the phone vibrates when you're hit.

### Settings (pause menu or title menu)
Zoom (Close / Far), bot difficulty (Easy / Normal / Hard), first to 3 / 5 / 7 round wins, vibration, sound, music.
They are saved on the phone.

The game opens on a title menu with the bots already fighting behind it. Back on the title menu leaves the game.

### The bots
| Colour | Personality | Plays like |
|---|---|---|
| Blue | Brawler | Gets close: staff and lightning, reflects your fireballs with the shield |
| Green | Caster | Keeps its distance, spams fireballs, zaps anyone who gets close |
| Purple | Trickster | Mid range, blinks in to shove you into the lava |

## Install
**Download:** grab the latest APK from [Releases](https://github.com/MariosToump/warlocks_on_android/releases) and open it on your phone.

Or build a debug APK and install it on a USB-connected phone (USB debugging on):
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
  (AI bots, rounds). v0.7 changes are described in GAME_DESIGN.md → Progress.

### Project layout
| Path | What |
|---|---|
| `scenes/game.tscn`, `scripts/game.gd` | Match flow: rounds, score, spawning, camera |
| `scripts/round_hud.gd` | Scoreboard, banners, kill feed, results screen |
| `scripts/arena.gd` | Lava map built in code from Wang tiles; shrinking + sudden death |
| `scripts/wizard.gd` | A wizard: movement, health, knockback, lava, animations |
| `scripts/spells/` | Fireball, Blink, Lightning, Shield, Staff strike |
| `scripts/touch_controls.gd` | Joystick, spell buttons, tap auto-aim |
| `scripts/minimap.gd`, `scripts/enemy_arrows.gd` | Minimap, off-screen enemy arrows |
| `scripts/damage_numbers.gd`, `scripts/danger_vignette.gd` | Damage numbers, lava glow |
| `scripts/pause_menu.gd`, `scripts/game_settings.gd` | Pause menu, saved settings |
| `scripts/shop.gd`, `scripts/shop_panel.gd` | Shop rules (gold, prices, bots' shopping), shop screen |
| `scripts/title_menu.gd` | Title menu |
| `scripts/sfx.gd`, `tools/build_audio.gd`, `assets/audio/` | Sound player; the synth that makes every sound and both music loops |
| `scripts/ai/`, `ai/` | Bot brain, personalities and difficulty profiles |
| `tools/` | Tests, AI simulation, demo recorder, deploy script |

### Tests
```bash
GODOT=/d/Godot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe
for t in wizard fireball spells staff ai arena rounds hud_v07 shop homing title; do
  "$GODOT" --headless --path . -s tools/test_$t.gd
done
"$GODOT" --path . -s tools/test_touch.gd   # needs a window (no --headless)
```
Each prints `ok` / `FAIL` lines and exits non-zero on failure.
`tools/sim_ai.gd -- <easy|normal|hard> [seconds]` runs a bots-only fight and
prints stats.
`tools/build_audio.gd` rebuilds all sounds and music (they are made in code, no recordings).

## Roadmap
1. ~~Arena~~ 2. ~~Wizard~~ 3. ~~Fireball + knockback~~ 4. ~~Blink, Lightning, Shield~~
5. ~~AI bots~~ 6. ~~Rounds, score, shrinking arena, win screen~~
7. ~~Shop between rounds~~
8. **Polish** — screen shake, hit flash, particles (sounds and menu done)
9. More spells — boomerang, meteor, gravity well, swap, time stop (homing orb done)
