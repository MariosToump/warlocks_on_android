# Lava Warlocks — Game Design

An original top-down pixel-art arena game inspired by the Warcraft III "Warlock" genre.
Do not copy names, art, text or data from any existing map. Everything here is our own.

## Progress (keep this up to date — read it before starting work)

_Last updated: 2026-11-25 (Android v0.8: shop = milestone 7, Homing Orb, sound + music, title menu)_

Each project has a `README.md` (how to play, controls, layout, tests).
Two projects share this design:
- **PC**: `D:\Godot\Projects\claude_mcp\lava-warlocks` (keyboard + mouse, Forward+ renderer). Local git only.
- **Android**: `D:\Godot\Projects\claude_mcp\lava-warlocks-mobile` (touch controls, Compatibility renderer).
  GitHub (public): https://github.com/MariosToump/warlocks_on_android — app name "Warlocks on Android", v0.8.1 (2026-11-25).
  Build + install on the phone: `bash tools/deploy_android.sh`. APK: `build/warlocks_on_android.apk`.
  Releases (APK download): https://github.com/MariosToump/warlocks_on_android/releases — v0.6 (2026-11-24), v0.7, v0.8, v0.8.1 (2026-11-25)
  (`gh release create vX.Y build/warlocks_on_android.apk`; bump `version/code` + `version/name` in export_presets.cfg first).
  Gameplay changes are made in PC first, then ported (`git cherry-pick` from the `pc` remote).
  **Exception — Android-only (v0.7 + v0.8, by choice):** fireball range 850 (PC: 700), the v0.7 HUD, pause menu and
  settings; v0.8 shop, Homing Orb, sound/music, title menu. PC is still at milestone 6. Expect a conflict in `fireball.gd` / `game.gd` / `round_hud.gd` / `touch_controls.gd` when cherry-picking.

### Milestones
- [x] 1. Project setup, arena with stone and lava tiles, camera.
- [x] 2. Player wizard: movement, animations, lava damage.
- [x] 3. Fireball + knockback physics.
- [x] 4. Blink, Lightning, Shield (+ hurt and death animations).
- [x] 5. AI bots (move, dodge, aim, avoid lava). _Done 2026-11-24 (PC and Android)._
- [x] 6. Rounds, score, shrinking arena, win screen. _Done 2026-11-24 (PC and Android)._
- [x] 7. Shop between rounds, gold, upgrades, items. _Done 2026-11-25 (Android only)._
- [ ] 8. Polish: screen shake, hit flash, particles, sounds, menu. **← next** (sounds + title menu done on Android in v0.8)
- [ ] 9. Remaining spells. (Homing Orb done on Android in v0.8)

Right now it's a match of rounds against three AI bots (they fight you and each other). Last wizard standing
wins the round; first to 5 round wins takes the match, then a results screen with "Play again".
Android v0.8: between rounds a 15 s shop (gold, upgrades, items, the Homing Orb); the game opens on a title menu.

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

- **Rounds** (`game.gd`, `scripts/round_hud.gd`, 2026-11-24; design record `docs/superpowers/specs/2026-11-24-rounds-design.md`):
  - Each round: everyone placed on a flat ellipse around the middle (260 x 130 px, random rotation, facing in),
    3 s countdown with the camera showing the whole field and controls off, then "Fight!" and the camera glides to the player.
  - The dead stay dead. Round ends the frame only one is left (all dead on the same tick = draw, nobody scores).
    3 s banner ("You win the round!" / "Blue wins the round!" / "Draw!"), then the next round: platform back to full,
    full health, cooldowns reset, leftover projectiles cleared, bot brains reset.
  - Kills: a death counts for whoever last hit the victim within 10 s (so knocking someone into lava counts).
    Tracked per match for the shop's gold (milestone 7). Kill feed top-right ("Blue took out Green").
  - Scoreboard top-left: colour, name, round-win pips, kills; the dead are dimmed during a fight.
  - When the player dies, after 1.5 s the camera follows their killer (or anyone alive).
  - Sudden death: in rounds the platform no longer regrows; after holding at the minimum for 25 s the edge keeps
    creeping in (0.6 tiles/s) until nothing is left. Bots-only rounds take 60-100 s.
  - `game.rounds = false` = the old endless free-for-all with respawns (all tests except test_rounds, and the AI sim).
  - Android: `TouchControls.locked` between rounds (no moving/casting; new touches pass through to the Play again button).

- **Android v0.7** (2026-11-25, Android only). Prompted by friends' feedback ("enemies come out of nowhere",
  "fireballs fly too short"). Findings: the phone view is only 800 x 360 world px (180 px above/below you) while bots
  fire from up to 630 px; the fireball aim guide drew 320 px though it flew 700; tap-aim fired at enemies out of range
  and didn't lead walkers. Built:
  - Off-screen enemy arrows on the screen edge (`scripts/enemy_arrows.gd`): team colour, smaller when far, pulse while casting.
  - Minimap top-right (`scripts/minimap.gd`): platform, coming edge, wizard dots, fireballs. Kill feed moved below it.
  - Fireball range 700 -> 850; aim guide shows the true range; tap-aim = nearest enemy *in range*, on-screen ones first
    (off-screen counts +400 px), leads walking targets; nobody in range -> nearest anyway (`touch_controls.gd`).
  - Floating damage numbers in screen space (`scripts/damage_numbers.gd`; yours red; lava ticks none).
    `Wizard.damaged(amount, source)` signal (source null = lava).
  - Scoreboard: health bar per wizard; "Knockback +N%" line for you.
  - Red edge glow (`scripts/danger_vignette.gd`): strong while burning, faint next to lava / where the edge is coming.
  - Vibration (`game.gd` `_on_player_damaged`): 40 ms per hit, 25 ms at most every 0.5 s in lava. `permissions/vibrate`.
  - Pause button + Android back button (`config/quit_on_go_back=false`) -> pause menu (`scripts/pause_menu.gd`):
    Resume, Restart match, Zoom Close/Far (3 or 2 screen px per art px), Bots Easy/Normal/Hard (applies at once),
    First to 3/5/7 wins (next match), Vibration on/off. Saved in `user://settings.cfg` (`scripts/game_settings.gd`,
    static). `game.apply_settings = false` in every test so saved settings can't change results.
- **Android v0.8** (2026-11-25, Android only):
  - **Shop** (milestone 7; `scripts/shop.gd` rules, `scripts/shop_panel.gd` UI, `game.gd` `State.SHOP`). After every
    round except the match-winning one: gold to everyone = 10 + 5 per kill that round + 5 for the round win; bots buy
    instantly from a per-personality wish list (`Shop.BOT_PRIORITY`); the player gets 15 s (`shop_time`) or Ready.
    Upgrades lv 1/2/3 cost 10/15/20 (the spells' `*_by_level` arrays). Items (max 2, sell for half): Boots 15 (+15%
    speed), Stone Cloak 20 (-20% knockback), Fire Ring 10 (-50% lava), Focus Gem 20 (-10% cooldowns) — Wizard
    `speed_multiplier` / `knockback_taken_multiplier` / `lava_multiplier` / `cooldown_multiplier`. Icons drawn in code.
    A new match clears gold, levels, items and bought spells (`Shop.clear`).
  - **Homing Orb** (slot D, 15 gold): `scripts/spells/homing_orb.gd`; `Projectile.homing_turn` (2.5 rad/s, 520 px
    radius) steers toward the nearest enemy of its *current* owner, so a shield reflection sends it back. 300 px/s,
    1100 range, dmg 8-14, knockback 420-510, cd 6-4.5 s. Fireball art tinted purple (`Spell.icon_tint`). Touch button D
    left of Q, only when owned. Bots: `homing` action (140-700 px).
  - **Sound + music, synthesized** (PixelLab audio needs a paid tier): `tools/build_audio.gd` renders 16 effects and two
    chiptune loops into `assets/audio/` (re-run it after changing a recipe); `scripts/sfx.gd` plays them (world sounds
    fade with distance from the camera; lava sizzle loop while you burn); buses SFX/Music (`default_bus_layout.tres`);
    silent in headless runs (records `Sfx.played` for tests). Settings: Sound, Music.
    Music (v0.8.1, redone on request): dark and heavy in the spirit of 90s shooter metal, but an original riff —
    fight loop 92 BPM E minor, 42 s: distorted palm-muted chugs + power chords, half-time drums, dark pad, a slow
    breakdown with a mournful lead; title loop 32 s dark ambient: breathing E drone, minor pads, distant bells, low booms.
  - **Title menu** (`scripts/title_menu.gd`, `game.gd` `State.TITLE`): over a bots-only brawl (player parked: hidden,
    no collision, out of the `wizards` group; camera hops between bots every 8 s). Play, Settings (pause panel in
    settings-only mode), version. Back on the title quits the app. Pause menu: Quit to menu; results screen: Menu.
    `game.title_screen = false` in tests.
  - Pause menu re-laid out: actions in one row, settings in a 2-column grid.
- **Balance findings (not acted on yet)**: AI sims (180 s x 3 difficulties) — only 16% of deaths are lava deaths; the
  Caster almost never dies (1 death in 9 bot-minutes vs Brawler 12). Pushes are small for the arena (fireball ~127 px,
  lightning ~187 px vs 1216 px platform radius) and lava is mild (8 HP/s). Candidates: smaller starting platform or
  faster first shrink, stronger lava, bigger knockback.

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
- No pillars/obstacles yet.
- **Shrinking** (2026-11-24): every 25 s the edge creeps in 9 tiles (4 s pulsing warning line, HUD "Lava rises in N"), down to 11 tiles, holds 25 s, then regrows. Tiles update incrementally. Dead wizards respawn at a random safe stone point far from others.
- `Wizard.take_damage(amount, source)` remembers `last_attacker` (for kill credit in rounds); bots turn on whoever just hit them.

### Tests
`godot --path . -s tools/<test>.gd`: test_wizard, test_fireball, test_spells, test_staff, test_ai, test_arena, test_rounds (+ on Android: test_hud_v07, test_shop, test_homing, test_title, and test_touch, which needs a window: no `--headless`). All passing.
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
