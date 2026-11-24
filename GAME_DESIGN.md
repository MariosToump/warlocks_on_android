# Lava Warlocks — Game Design

An original top-down pixel-art arena game inspired by the Warcraft III "Warlock" genre.
Do not copy names, art, text or data from any existing map. Everything here is our own.

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
