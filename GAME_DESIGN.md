# Lava Warlocks — Game Design

An original top-down pixel-art arena game inspired by the Warcraft III "Warlock" genre.
Do not copy names, art, text or data from any existing map. Everything here is our own.

## Progress (keep this up to date — read it before starting work)

_Last updated: 2026-11-24_

Two projects share this design:
- **PC**: `D:\Godot\Projects\claude_mcp\lava-warlocks` (keyboard + mouse, Forward+ renderer). Local git only.
- **Android**: `D:\Godot\Projects\claude_mcp\lava-warlocks-mobile` (touch controls, Compatibility renderer).
  GitHub (public): https://github.com/MariosToump/warlocks_on_android — app name "Warlocks on Android", v0.5.
  Build + install on the phone: `bash tools/deploy_android.sh`. APK: `build/warlocks_on_android.apk`.
  Gameplay changes are made in PC first, then ported (`git cherry-pick` from the `pc` remote).

### Milestones
- [x] 1. Project setup, arena with stone and lava tiles, camera.
- [x] 2. Player wizard: movement, animations, lava damage.
- [x] 3. Fireball + knockback physics.
- [x] 4. Blink, Lightning, Shield (+ hurt and death animations).
- [x] 5. AI bots (move, dodge, aim, avoid lava). _PC done 2026-11-24; Android port pending._
- [ ] 6. Rounds, score, shrinking arena, win screen. **← next**
- [ ] 7. Shop between rounds, gold, upgrades, items.
- [ ] 8. Polish: screen shake, hit flash, particles, sounds, menu.
- [ ] 9. Remaining spells.

Right now it's a free-for-all against three AI bots that fight you and each other, and respawn 2 s after dying.
There are no rounds or winner yet.

### Added beyond the original plan
- **Staff attack (slot A)**: auto-attack melee swing, 4 damage, shove 300, 0.5 s cooldown = swing animation.
  - PC: right-click an enemy = walk up and keep attacking; A key = one swing.
  - Android: big attack button swings on the spot (aims at an enemy within 70 px), hold to repeat, cooldown timer on the button.
- **Android version**: floating joystick on the left; spell buttons on the right (drag to aim, tap to auto-aim, drag back to cancel); landscape, immersive.
- **Feel**: physics interpolation (smooth on 90/120 Hz screens); camera zoom snapped so one art pixel = a whole number of screen pixels.
- Demo video recorder: `tools/record_demo.gd` (Movie Maker).
- **AI bots** (`scripts/ai/`, 2026-11-24): `AIController` on each bot scores actions every think tick
  (dodge, recover, shield, reposition, fireball, lightning, staff, blink-in) × personality weight.
  Lava check runs every physics frame. Design: `docs/superpowers/specs/2026-11-24-ai-bots-design.md`.
  - Personalities (`ai/personalities/`): Blue = Brawler (close, staff + lightning, reflects with shield),
    Green = Caster (keeps ~350 px, fireballs, zaps anyone who closes in), Purple = Trickster (mid range, blink-in to shove into lava).
  - Difficulty (`ai/profiles/`, `game.gd` `bot_difficulty`, default Normal): think rate, reaction delay, aim error, leading, dodge and shield chance.
  - `game.gd` `bot_debug` draws each bot's current action. `tools/sim_ai.gd -- <easy|normal|hard> [s]` runs a bots-only fight and prints stats.
  - Known: Caster tends to survive longest; few lava deaths because the arena is huge (shrinking in M6 will fix).

### Changed from the plan above
- Move speed is **165** (not 140). Fireball flies 560 px/s.
- Stretch mode is **canvas_items** (not "viewport"), to keep pixels sharp on phone screens.
- Characters are 48 px PixelLab sprites (not 32 px). Diagonal staff-swing directions reuse the side/front/back swings.
- Android zoom is closer than PC (3 vs 2 screen px per art pixel on a 1080p screen).

### Arena as built
- `scripts/arena.gd` builds the map in code every run, from PixelLab Wang tiles (32 px): `lava_stone` and `stone_cracked`.
- Map: 108 x 108 tiles. Stone platform radius 38 tiles (~2400 px across), edge wobbled so it isn't a perfect circle, 16-tile lava ring around it.
- Cracked-stone patches (glowing outlines) are placed with noise, decoration only.
- Random layout every run (`seed_value = 0`).
- No pillars/obstacles yet. Shrinking (milestone 6) will change vertices to lava and call `rebuild()`.

### Tests
`godot --path . -s tools/<test>.gd`: test_wizard, test_fireball, test_spells, test_staff, test_ai (+ test_touch on Android). All passing.
Tests set `game.bot_ai = false` so bots are passive dummies (`BotBlue`, `BotGreen`, `BotPurple`).

### PixelLab
Trial: 3 generations left (out of 40). Character id `2c9f98f0-5a77-4c63-aca5-e01bf03bf62d` (Red Warlock; team colours are a hue shader).

## Core idea
- 2–4 wizards fight on a round stone platform surrounded by lava.
- Spells mostly **knock back** instead of just doing damage. Being pushed into lava burns you.
- The platform **shrinks** over time, so rounds end even if nobody plays aggressively.
- Last wizard standing wins the round. First to 5 round wins takes the match.
- Between rounds there is a short **shop**: spend gold on new spells, spell upgrades and items.

## Players
- Version 1: you (keyboard + mouse) vs 1–3 AI bots.
- Later: local multiplayer, then online.

## Controls
- Right-click: move to point (like WC3), or WASD (setting).
- Q / W / E / R / D / F: cast spell in that slot, aimed at the mouse.
- Esc: pause.

## Wizard stats
- Health 100. Move speed ~140 px/s.
- Knockback is physics-like: velocity that decays with friction.
- Standing on lava: 8 damage/sec, wizard glows and smokes.
- Damage taken increases knockback received (more damaged = flies further).

## Spells (version 1 = first 4, the rest later)
| Slot | Spell | What it does |
|---|---|---|
| Q | Fireball | Fast projectile, small damage, medium knockback. Starts unlocked. |
| W | Blink | Short teleport toward the mouse. Starts unlocked. |
| E | Lightning | Instant short-range line, high knockback. |
| R | Shield | 1.5 s bubble that reflects projectiles. |
| — | Homing orb | Slow projectile that follows the nearest enemy. |
| — | Boomerang | Goes out and comes back, hits twice. |
| — | Meteor | Delayed area blast at a point, big knockback. |
| — | Gravity well | Pulls nearby enemies toward a point. |
| — | Swap | Projectile; on hit, you and the target swap places. |
| — | Time stop | Freezes projectiles in an area for 2 s. |
Every spell has a cooldown and 3 upgrade levels (more damage, knockback or shorter cooldown).

## Shop & economy
- Gold per round: 10 base, +5 for each kill, +5 for winning the round.
- Spells cost 10–20 gold. Upgrade levels cost 10 / 15 / 20.
- Items (max 2): Boots (+15% speed), Stone Cloak (-20% knockback taken), Fire Ring (lava damage -50%), Focus Gem (-10% cooldowns).

## Arena
- Round stone platform in the middle of a lava field, about 2 screens wide.
- Starts big, shrinks in 3 steps during a round (tiles crumble into lava with a warning flash).
- Optional obstacles: pillars that block projectiles.

## Art (PixelLab)
- Style: 32x32 characters, top-down 3/4 view, dark fantasy, warm lava palette.
- Wizards: 4 color variants (red, blue, green, purple). Idle + walk in 8 directions, cast animation.
- Tiles: stone floor, cracked stone, lava (animated), lava edge.
- Effects: fireball, lightning, shield bubble, blink puff, meteor, lava burn.
- UI: health bars, spell slot icons, gold icon, shop panel, pixel font.
- Import settings: Nearest filter, no mipmaps. Window 1280x720, viewport stretch.

## Build order (one milestone at a time; run and test after each)
1. Project setup, arena with stone and lava tiles, camera.
2. Player wizard: movement, animations, lava damage.
3. Fireball + knockback physics.
4. Blink, Lightning, Shield.
5. AI bots (move, dodge, aim, avoid lava).
6. Rounds, score, shrinking arena, win screen.
7. Shop between rounds, gold, upgrades, items.
8. Polish: screen shake, hit flash, particles, sounds, menu.
9. Remaining spells.
