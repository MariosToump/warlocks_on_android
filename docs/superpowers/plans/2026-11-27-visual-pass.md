# Visual pass 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** More life on screen with no new art: hit sparks, cast puffs, death dissolve, lava embers, heat shimmer, squash/stretch and shadows.

**Architecture:** A static `Vfx` helper builds one-shot CPUParticles2D bursts in code; the wizard calls it from `flash_hit`, the cast release and `_die`. Death dissolve lives in the existing team-colour shader. Lava embers and heat shimmer are arena children.

**Tech Stack:** Godot 4.7.2, GDScript, Compatibility renderer.

**Spec:** `docs/superpowers/specs/2026-11-27-visual-pass-design.md`

## Global Constraints
- CPUParticles2D only; particles are untextured squares (pixel look), no GPUParticles2D.
- At most 24 one-shot bursts alive (`Vfx.MAX_LIVE := 24`); ambient embers `amount = 40`.
- No darker arena, no normal maps.
- Hit sparks live under 0.5 s.
- All 20 existing test files keep passing.

## Review Focus
1. Many hits in one frame (meteor on 4 wizards, boomerang twice): cap holds, nothing piles up -> test in Task 1.
2. A wizard dies mid-dissolve and the round resets: the next round shows it whole -> test in Task 3.
3. Heat shimmer off: no screen-reading node runs at all -> test in Task 5.
4. Hits during hit-stop (time_scale 0.1): bursts still free themselves -> bursts free on `finished` (scaled time, fine), test in Task 1 waits it out.
5. Island shrinks to the final size: ember points stay on lava, never empty array crash -> test in Task 4.

---

### Task 1: Vfx helper + coloured hit sparks
**Files:** Create `scripts/vfx.gd`, `tools/test_vfx.gd`. Modify `scripts/wizard.gd` (`flash_hit`), `scripts/projectile.gd`, `scripts/boomerang.gd`, `scripts/prop.gd`, `scripts/meteor_strike.gd`, `scripts/spells/lightning.gd`, `scripts/spells/staff_strike.gd`.
**Interfaces — Produces:**
- `Vfx.burst(parent: Node, pos: Vector2, color: Color, amount := 12, speed := 80.0, dir := Vector2.ZERO, spread := 180.0, life := 0.35) -> CPUParticles2D` (null when the cap is hit), in group `"vfx_burst"`, frees itself on `finished`.
- `Vfx.hit(parent: Node, pos: Vector2, dir: Vector2, kind: String) -> void`; kinds `fire, lightning, push, swap, meteor, lava`; `Vfx.COLORS: Dictionary` kind -> Color.
- `Vfx.live_count(tree: SceneTree) -> int`; `Vfx.MAX_LIVE := 24`.
- `Wizard.flash_hit(from_dir := Vector2.ZERO, kind := "push")`.
- [ ] Test: hit the player with a fireball projectile -> a `vfx_burst` node exists with the fire colour; 40 `Vfx.burst` calls in one frame -> `live_count <= 24`; after 0.6 s -> `live_count == 0`.
- [ ] Run headless, expect FAIL (no `Vfx`).
- [ ] Implement; callers pass kind (fireball/homing -> fire, swap -> swap, boomerang/staff/prop -> push, meteor -> meteor, lightning -> lightning).
- [ ] Run test_vfx + test_spells + test_new_spells + test_staff, expect PASS. Commit.

### Task 2: Cast puff + squash and stretch
**Files:** Modify `scripts/vfx.gd`, `scripts/wizard.gd`, `tools/test_vfx.gd`.
**Interfaces — Produces:** `Vfx.cast_puff(parent: Node, pos: Vector2, spell_id: String)`; `Wizard.squash(to: Vector2, time := 0.12)` tweens `sprite.scale` to `to` and back to `Vector2.ONE`.
- [ ] Test: player casts Q -> after release a burst exists and `sprite.scale != ONE` within the next frames; after 0.4 s `sprite.scale == ONE`. A hit -> `sprite.scale.x > 1`.
- [ ] FAIL, implement (cast: stretch (0.9, 1.12); hit: squash (1.2, 0.85)), PASS, commit.

### Task 3: Death dissolve + death embers
**Files:** Modify `shaders/team_color.gdshader` (uniform `dissolve: float = 0`, per-texel hash noise, orange edge band 0.08), `scripts/wizard.gd` (`_die`, `reset`), `tools/test_vfx.gd`.
- [ ] Test: kill a wizard -> a burst spawns; after 1.6 s `dissolve` param `>= 0.99` and the wizard is hidden; `reset()` -> `dissolve == 0`, visible, `modulate == WHITE`. Existing test_wizard death checks still pass.
- [ ] FAIL, implement (tween dissolve 0 -> 1 over 0.8 s after 0.6 s, keep the shrink), PASS, commit.

### Task 4: Lava embers
**Files:** Modify `scripts/arena.gd` (child `Embers: CPUParticles2D`, `emission_shape = POINTS`, `_update_ember_points()` called from `_set_radius`), `tools/test_vfx.gd`.
**Interfaces — Produces:** `Arena.embers: CPUParticles2D`.
- [ ] Test: embers exist, emitting, `amount == 40`; every emission point is lava (`is_lava_at`) and within 6 tiles of the edge; after shrinking to the final radius the points are still lava and non-empty.
- [ ] FAIL, implement (up to 64 sampled lava cells, rising slowly, orange to dark), PASS, commit.

### Task 5: Heat shimmer + setting
**Files:** Create `shaders/heat_haze.gdshader`. Modify `scripts/arena.gd` (`HeatHaze` ColorRect over the arena bounds, z between tiles and wizards), `scripts/game_settings.gd` (`heat_haze := true`, saved/loaded/reset), `scripts/game.gd` (apply setting), `scripts/pause_menu.gd` (toggle "Heat shimmer"), `tools/test_vfx.gd`.
**Interfaces — Produces:** `Arena.set_heat_haze(on: bool)`; `Arena.heat_haze: ColorRect`.
- [ ] Test: haze node exists and visible by default; `set_heat_haze(false)` -> node hidden and `process_mode == DISABLED`; settings round-trip saves `heat_haze`.
- [ ] FAIL, implement (offset = small sine of TIME and world y, applied only where the screen pixel is lava-coloured, 1 px steps), PASS, commit.

### Task 6: Shadows
**Files:** Modify `scripts/wizard.gd` (`_draw` ellipse under the feet before the trail), `scripts/projectile.gd` (`_draw` ellipse 10 px below), `tools/test_vfx.gd`.
**Interfaces — Produces:** `Wizard.SHADOW := Vector2(9, 3.5)`; `Projectile.draws_shadow := true`.
- [ ] Test: `Wizard.SHADOW` set; a live projectile has `draws_shadow` and its shadow is skipped while dead/invisible.
- [ ] FAIL, implement, PASS, commit.

### Task 7: Check on screen, docs, release
- [ ] Windowed screenshot at 1600x720 of a hit, a death and the lava; tune by eye.
- [ ] Full suite (20 + test_vfx), Godot MCP run, no errors.
- [ ] README test line, GAME_DESIGN Progress (both copies), version 0.13 (code 12), deploy to the phone, push, GitHub release.
