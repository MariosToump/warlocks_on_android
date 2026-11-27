# Warlocks on Android

A top-down pixel-art arena brawler for Android. Four wizards fight on a stone
platform in a sea of lava. Spells mostly **knock back** rather than kill, so
the real danger is being blasted into the lava. The platform shrinks during
each round, so every fight ends.

**Version 0.9** — you against three AI bots in short matches of rounds (5-8 minutes), with a shop between rounds,
rocks to hide behind and shove, a ghost mode when you're out, and a Touchpad movement option.

Made with Godot 4.7.2 (GDScript); pixel art made with PixelLab.

## How to play
- **Last wizard standing wins the round. First to 3 round wins takes the match** (3 / 5 / 7 in the settings).
- Lava burns fast (20 HP a second). The more damage you've taken, the further hits push you, so most
  wizards end up in the lava.
- Every 18 s the lava rises and the platform gets smaller. A glowing line
  shows where the new edge will be. At its smallest the platform holds for
  12 s, then sudden death: the edge keeps creeping in until nobody is left
  standing.
- Knocking someone into the lava counts as your kill.
- **Rocks:** each round a few boulders and pillars stand on the island. They block spells (cover!).
  Hit a boulder with a spell or your staff and it rolls; a rolling boulder hurts and shoves whoever it hits,
  and it sinks in the lava. Pillars don't move.
- **Craters:** a fireball scorches the ground where it bursts; walking through it is slower for a few seconds.
- **Shield:** a spell that bounces off your shield comes back at double speed and double range.
- **Ghost:** when you're out, you float on as a ghost until the round ends. The attack button becomes
  **Haunt**: a small shove to anyone close by (no damage), every 4 s.

### The shop
After every round you get gold — 10, plus 5 per kill, plus 5 if you won the round — and 10 seconds to spend it
(tap **Ready** to start sooner; when you can't afford anything the shop is skipped). The bots shop too.
- **Upgrade a spell** (10 / 15 / 20 gold for levels 1-3): more damage and knockback, or shorter cooldowns.
- **Homing Orb** (15 gold): a new spell in a new button left of the fireball. A slow purple orb that curves
  toward the nearest enemy. A shield sends it back at you!
- **Rock Wall** (15 gold): a new button up-left of Blink. Raises 3 rocks in front of you, across your aim,
  for 4-5.5 s.
- **Items** (2 at most, sell for half price): Boots +15% speed, Stone Cloak -20% knockback taken,
  Fire Ring -50% lava damage, Focus Gem -10% cooldowns.
- A new match starts everyone from scratch.

### Controls (touch)
| Control | Action |
|---|---|
| Left half of the screen | Floating joystick — walk (the ring follows your thumb). Or **Touchpad** (setting): the whole left half is a pad, slide a little to walk at full speed |
| Big button (bottom right) | Staff swing on the spot; hold to keep swinging |
| Fireball | Tap = auto-aim (nearest enemy in range, ones you can see first, aimed ahead of a walker); drag to aim (the guide shows the full range); drag back onto the button to cancel |
| Blink | Short teleport (tap = forward, or drag to aim) |
| Lightning | Instant bolt (450 px) with big knockback. Hit with the tip for an extra push |
| Shield | 1.5 s bubble that reflects projectiles |
| Homing Orb (once bought) | Tap = toward the nearest enemy in range; drag to aim |
| Rock Wall (once bought) | Tap = between you and the nearest enemy; drag to aim |
| II button (top right) or Back | Pause: resume, restart, quit to the menu, settings |

### On screen
- **Scoreboard** (top left): health, round wins and kills for everyone; below it, how much further you fly when hit.
- **Minimap** (top right): the platform, where the lava is about to rise, and everyone's position.
- **Arrows** on the screen edge point at enemies you can't see. Bigger = closer; they flash while that enemy casts.
- Damage numbers over whoever gets hit (red ones are yours); the screen edges glow red when you're in or next to lava;
  the phone vibrates when you're hit. The screen shakes on hits and kills, big hits freeze for a split second,
  and wizards flying from a hit leave a streak.

### Settings (pause menu or title menu)
Zoom (Close / Far), bot difficulty (Easy / Normal / Hard), first to 3 / 5 / 7 round wins, vibration, sound, music,
movement (Joystick / Touchpad).
They are saved on the phone.

The game opens on a title menu with the bots already fighting behind it. Back on the title menu leaves the game.

### The bots
| Colour | Personality | Plays like |
|---|---|---|
| Blue | Brawler | The charger: dodges your spells, weaves in, waits just out of zap range and rushes you when you've used your lightning or left yourself open |
| Green | Caster | The sniper: keeps its distance, fireballs, zaps anyone who gets close; often plays it safe |
| Purple | Trickster | The opportunist: hangs back while others fight, then blinks in to push hurt wizards into the lava |

Each round every bot rolls a mood (aggressive, cautious or opportunist), so the same bot plays differently from
round to round. Cautious and opportunist bots open by watching for a few seconds before they join in. Bots make
human mistakes (slow reactions, shots that miss), remember the spells they *see* you use, and go for the kill when
you're hurt, near the lava or out of shield. They never read your cooldowns.

The bots gang up on whoever has won the most rounds this match, don't waste spells on rocks, and raise a
Rock Wall against a spell they see coming once they own one.

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
| `scripts/spells/` | Fireball, Blink, Lightning, Shield, Staff strike, Homing Orb, Rock Wall |
| `scripts/prop.gd`, `scripts/crater.gd` | Boulders, pillars, wall rocks (art drawn in code); fireball craters |
| `scripts/ghost.gd` | The player's ghost after dying (float, haunt) |
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
for t in wizard fireball spells staff ai arena rounds hud_v07 shop homing title ghost feel terrain; do
  "$GODOT" --headless --path . -s tools/test_$t.gd
done
"$GODOT" --path . -s tools/test_touch.gd   # needs a window (no --headless)
```
Each prints `ok` / `FAIL` lines and exits non-zero on failure.
`tools/sim_ai.gd -- <easy|normal|hard> [seconds]` runs a bots-only fight and
prints stats.
`tools/playtest.gd` plays whole matches (the player is a bot too) as fast as the CPU allows and prints match
length, fight length, deaths in lava and each bot's share of round wins:
`"$GODOT" --headless --fixed-fps 60 --path . -s tools/playtest.gd -- 10 normal`.
`tools/build_audio.gd` rebuilds all sounds and music (they are made in code, no recordings).

## Roadmap
1. ~~Arena~~ 2. ~~Wizard~~ 3. ~~Fireball + knockback~~ 4. ~~Blink, Lightning, Shield~~
5. ~~AI bots~~ 6. ~~Rounds, score, shrinking arena, win screen~~
7. ~~Shop between rounds~~
8. ~~Polish~~ — screen shake, hit-stop, sounds, menu (v0.9: short matches, lava balance, ghost, rocks)
9. More spells — boomerang, meteor, gravity well, swap, time stop (homing orb, rock wall done)
10. **v1.0: a camera that tilts from top-down into a 3D view** (2.5D)
