# Remaining Spells + Two-Slot Shop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (the user chose inline). Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** five new shop spells (Boomerang, Meteor, Gravity Well, Swap, Time Stop), with bot support and Godot-drawn
pixel art, on a two-slot shop (D / F).

**Architecture:**
- Each spell is a `Spell` subclass in `scripts/spells/`.
- World objects are their own scripts (`boomerang.gd` extends `Projectile`, `meteor_strike.gd`, `gravity_well.gd`,
  `time_stop_field.gd`). The Swap orb is a `Projectile` with an `on_hit` Callable.
- The art comes from `tools/build_effects.gd` (frames drawn on `Image`, saved as PNG + `SpriteFrames`).

**Tech Stack:** Godot 4.7.2, GDScript, headless test scripts in `tools/`.

**Spec:** `docs/superpowers/specs/2026-11-27-remaining-spells-design.md`

## Global Constraints
- The spell numbers are exactly the spec's table.
- Buttons: only slots D and F (no new HUD buttons). A spell takes its home slot when it's free, otherwise the other
  free one.
  - Home slots: homing D, rockwall F, boomerang D, swap D, meteor F, well F, timestop F.
- Every spell gets `_score_X` / `_do_X` in `ai_controller.gd`, and the AI finds the slot through
  `wizard.slot_of(id)`, never a hard-coded "D" / "F".
- Art: hard pixels, a dark outline (`#1a0f0f`), the lava palette plus one accent per spell, 8-12 frames.
- Commit after each task, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus
1. Buying with both slots full must fail with no gold taken. Selling frees the slot, and the touch button
   disappears.
2. A new match clears both slots (`Shop.clear` must cover every `SPELLS` id, wherever it sits).
3. A boomerang whose caster died or left must not crash: it frees itself.
4. Time Stop over a reflected projectile: it freezes, then carries on with its doubled speed.
5. Swap onto a target standing on lava puts the caster on lava (by design). Swap orb or Meteor with no target
   in range: no errors.

---

### Task 1: Two-slot shop + spell ids
**Files:**
- Modify: `scripts/shop.gd`, `scripts/wizard.gd`, `scripts/spells/spell.gd`, `scripts/shop_panel.gd`,
  `scripts/touch_controls.gd`, `scripts/ai/ai_controller.gd` (homing / rockwall use `slot_of`)
- Test: `tools/test_shop.gd`

**Interfaces:**
- Produces:
  - `Spell.spell_id: String`
  - `Spell.reach() -> float` (touch tap / aim reach; default 100)
  - `Spell.placed := false` (the aim scales with drag length, like Blink)
  - `Wizard.slot_of(id: String) -> String` ("" if not owned)
  - `Shop.SHOP_SLOTS := ["D", "F"]`
  - `Shop.free_slot(w, id) -> String`
  - `Shop.can_buy_spell` is false when both slots are full
  - `Shop.sell_spell(game, w, id) -> bool` (refunds `int(price / 2)`)
  - `Shop.spell_sell_price(id) -> int`
  - In `SPELLS` entries, the `"slot"` key becomes `"home"`.

- [ ] Test (RED), in test_shop:
  - "Homing Orb lands in slot D"
  - buying rockwall → F
  - a third spell (boomerang) → refused with no gold taken
  - `sell_spell` homing → +7 gold and D is free
  - boomerang → D
  - new match → both empty
  - Sanity: `player.slot_of("boomerang") == "D"`.
- [ ] Implement:
  - shop panel: an owned bought spell gets a "Sell +Ng" button next to its upgrade; "New:" rows are disabled when
    both slots are full ("Slots full" label)
  - touch `_reach` falls back to `spell.reach()`, and `placed` spells scale the aim like W
- [ ] All tests green, commit.

### Task 2: Effect art builder
**Files:** Create `tools/build_effects.gd`, `assets/sprites/effects/{boomerang,meteor_rock,gravity_well,swap_orb,swap_puff,time_stop}.png` + `_frames.tres`

**Interfaces:**
- Produces `SpriteFrames` resources with animation "default" and meta `pivot_px`, for each name above.
- Frame sizes:
  - boomerang 24×24 ×8 (spin, loop)
  - meteor_rock 28×28 ×6 (loop)
  - gravity_well 64×40 ×12 (loop, flattened ellipse for the top-down 3/4 view)
  - swap_orb 20×20 ×6 (loop)
  - swap_puff 48×48 ×10 (one shot)
  - time_stop 72×44 ×10 (loop)

- [ ] Write the builder: `_px(img, x, y, col)` hard pixels, `_outline(img)`, palette constants.
  - Run it: `godot --headless --path . -s tools/build_effects.gd`
  - Expected: the files exist and `load()` gives SpriteFrames with the frame counts above.
- [ ] Add the new sound recipes to `tools/build_audio.gd` (boomerang, meteor_fall, meteor_boom, well, swap,
  timestop). Rebuild, and register them in `scripts/sfx.gd`.
- [ ] Commit.

### Tasks 3-7: one spell each (Boomerang, Swap, Meteor, Gravity Well, Time Stop)
**Files:**
- Create `scripts/spells/<spell>.gd` (+ world object script)
- Modify `scripts/shop.gd` (SPELLS + BOT_PRIORITY), `scripts/ai/ai_controller.gd` (score/do + counters),
  `scripts/wizard.gd` (Gravity Well only: `pull` velocity term), `scripts/projectile.gd` (Time Stop only:
  `frozen()` check)
- Test: `tools/test_new_spells.gd` (one `_test_<spell>()` per task, added RED first)

The behaviour and numbers come from the spec table. Assertions per spell:
- **Boomerang:**
  - reaches about 420 px, then comes back within 40 px of the caster and frees itself
  - a dummy on the path is hit twice (hp drops twice)
  - a shield turns it, and it then belongs to the shielder
- **Swap:**
  - after a hit, the positions are exchanged (±2 px) and both knockbacks are zero
  - out of range: nothing happens
  - a shield reflects it
- **Meteor:**
  - no damage before 1.0 s; after it, a dummy 50 px from the centre is hurt and pushed outward, and one at 120 px
    isn't touched
  - a crater spawns
  - a shielded dummy isn't hurt
- **Gravity Well:**
  - a dummy 120 px away moves toward the centre over 1 s; the caster at 100 px doesn't
  - gone after 2.5 s
- **Time Stop:**
  - a fireball entering the circle stops moving for the duration, then carries on with the same direction
  - wizards inside walk normally
- **Bots (each):** the score is > 0 in a fitting setup.
  - Bot counters: a bot inside a Meteor ring walks out before impact; a bot near a well walks against the pull.

Each task: RED → GREEN, run the full suite, commit.

### Task 8: Balance + release
- [ ] Harness, Normal, 40 matches (bots buy the new spells through BOT_PRIORITY). Targets: nobody > 40%, lava ≥ 50%,
  fights 35-60 s. Tune only the numbers that break a target, and ledger the change in the spec.
- [ ] Godot MCP run: no errors.
- [ ] Bump to 0.12 / code 10, then deploy to the phone (`bash tools/deploy_android.sh`).
- [ ] Docs:
  - README: spells table and shop
  - GAME_DESIGN: Progress in both copies, plus the spells table
- [ ] Commit, push, and create the `gh release v0.12`.
