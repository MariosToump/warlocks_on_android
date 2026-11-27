# Visual pass 1 (Godot, no new art) — design

_2026-11-27. Android repo. Short design: a small project._

## Intent
The user wants the game to have more animation and feel "a bit more real". Plan agreed with the user: do as much
as we can in Godot first, then finish with PixelLab (missing directions + idle, later hit-type hurt/death).
The user: **don't darken the arena for now**; do the rest.

## Goals
1. **Particles:** a spark burst on every hit, coloured by what hit you; a small burst when a spell is released;
   embers when a wizard dies; embers rising off the lava around the island.
2. **Death dissolve** instead of the current fade: the wizard breaks up pixel by pixel with a glowing orange edge.
3. **Heat shimmer** over the lava (screen-reading shader, lava pixels only), with an on/off setting for slow phones.
4. **Motion:** squash and stretch on casts and hits; a soft shadow under each wizard and each projectile.

## Non-goals / anti-goals
- No darker arena, no normal maps (they only pay off with a darker scene; later).
- No new PixelLab art in this pass.
- Anti-goal: anything that blurs the pixel look (particles are small square pixels, Nearest), or that drops the
  phone's frame rate. Anti-goal: effects that hide the gameplay (hit sparks short, under 0.5 s).

## Constraints
- Compatibility renderer (Android). CPUParticles2D only (GPUParticles2D can hitch on first use on Android).
- Budget: at most 24 one-shot bursts alive at once; ambient embers 40 particles.
- Headless tests must keep passing (no physics or timing changes).

## Approaches
- **A. Code-built CPUParticles2D + shaders (picked, my call).** One static helper `Vfx` builds the bursts in code,
  like the spells drawn in Godot in v0.12. Free, testable headless, easy to tune per spell.
- B. Frame-by-frame sprite effects from PixelLab's free `vfx_workbench`. Crisper, but slower to make for every
  hit type and no randomness; kept for the PixelLab finishing pass.
- C. GPUParticles2D. Same look as A, risk of a shader-compile hitch on Android, no gain at our particle counts.

## How
- `scripts/vfx.gd` (`class_name Vfx`, static): `burst(parent, pos, color, amount, speed, dir, spread, life)`
  and `hit(parent, pos, dir, kind)` with kinds `fire`, `lightning`, `push` (staff, boulder, boomerang), `swap`,
  `meteor`, `lava`. Bursts free themselves; `live_count()` enforces the cap.
- `Wizard.flash_hit(from_dir, kind := "push")` spawns `Vfx.hit` and a squash; every caller passes its kind.
- Spell release: `Vfx.cast_puff` at the staff, colour by `spell_id`, plus a stretch.
- Death: `team_color.gdshader` gets a `dissolve` uniform (hashed per-texel noise, orange edge); `_die` tweens it
  0 -> 1 instead of fading `modulate`; `reset` puts it back to 0. A burst of embers on death.
- Lava embers: an `Embers` CPUParticles2D in the arena with emission points on lava cells near the island
  edge, rebuilt when the island shrinks.
- Heat shimmer: `shaders/heat_haze.gdshader` on a node over the arena, under the wizards; it offsets the screen
  only where the screen pixel is lava-coloured. `GameSettings.heat_haze` (default on) + a pause-menu toggle.
- Shadows: `Wizard._draw` and `Projectile._draw` draw a soft dark ellipse at the feet.

## Left to the builder
Exact colours, counts and timings (tune by eye in screenshots at 1600x720), test structure.
