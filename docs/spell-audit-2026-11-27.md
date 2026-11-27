# Spell audit against the warlocks-spell-author checklist (2026-11-27)

This audit changed nothing; it only checks the 12 existing spells against the skill's 11 steps.
✅ = done, ⚠️ = partly done, ❌ = missing.

| Spell | Design spec | Code | Effect art | Sound (cast / impact) | Bot score + do | In a bot wish list | Shop / icon | Own tests | Edge-case tests | Harness | Docs |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Fireball | ⚠️ none (built before specs) | ✅ | ✅ | ✅ / ✅ hit | ✅ | starter | starter | ✅ test_fireball | ✅ shield, lava | ✅ | ✅ |
| Lightning | ✅ lightning-rework | ✅ | ✅ | ✅ / ⚠️ hurt only | ✅ | starter | starter | ✅ test_lightning | ✅ shield | ✅ v0.11 | ✅ |
| Blink | ⚠️ none | ✅ | ⚠️ tiny (visual review #4) | ✅ / – | ✅ blink_in, evade | starter | starter | ⚠️ in test_spells | ⚠️ | ✅ | ✅ |
| Shield | ⚠️ none | ✅ | ✅ | ✅ / ❌ **no reflect sound** | ✅ | starter | starter | ⚠️ in test_spells | ✅ | ✅ | ✅ |
| Staff | ✅ brawler-midrange | ✅ | ✅ | ✅ / ⚠️ hurt only | ✅ | starter | starter | ✅ test_staff | ✅ | ✅ v0.12 | ✅ |
| Homing Orb | ⚠️ in GAME_DESIGN only | ✅ | ⚠️ **looks like a fireball** | ✅ / ⚠️ shared hit | ✅ | ✅ Caster, Bot | ✅ | ✅ test_homing | ⚠️ shield yes, lava / caster-dies no | ⚠️ **too strong** (sim: duel 61%) | ✅ |
| Rock Wall | ⚠️ in GAME_DESIGN only | ✅ | ⚠️ style (visual review #7) | ⚠️ **reuses hit** | ✅ | ✅ Bot only | ✅ | ⚠️ inside test_terrain | ❌ | ⚠️ no gain for bots (sim) | ✅ |
| Boomerang | ✅ remaining-spells | ✅ | ✅ | ✅ / ⚠️ shared hit, no return sound | ✅ | ✅ Trickster | ✅ | ⚠️ in test_new_spells | ⚠️ shield only | ⚠️ no gain for bots (sim) | ✅ |
| Swap | ✅ remaining-spells | ✅ | ⚠️ weak (visual review #4) | ✅ | ✅ | ✅ Brawler | ✅ | ⚠️ in test_new_spells | ⚠️ shield only | ⚠️ no gain for bots (sim) | ✅ |
| Meteor | ✅ remaining-spells | ✅ | ⚠️ pixel scale, faint warning | ✅ / ⚠️ **clips** (audio review #1) | ✅ | ✅ Caster | ✅ | ⚠️ in test_new_spells | ⚠️ | ⚠️ no gain for bots (sim) | ✅ |
| Gravity Well | ✅ remaining-spells | ✅ | ✅ | ✅ | ✅ | ✅ Brawler | ✅ | ⚠️ in test_new_spells | ⚠️ | ✅ second best (55%) | ✅ |
| Time Stop | ✅ remaining-spells | ✅ | ⚠️ pixel scale, too big | ✅ | ✅ | ✅ Trickster | ✅ | ⚠️ in test_new_spells | ⚠️ | ⚠️ no gain for bots (sim) | ✅ |

## Gaps that matter most
1. **Balance (step 8).** The sim shows Homing Orb far too strong, and Rock Wall, Boomerang, Swap, Meteor and Time
   Stop don't help a bot win. By the skill's rule, those six aren't finished. They need tuning, and re-running
   `tools/sim/run.py` is the check.
2. **Edge-case tests (step 7)** for the 7 shop spells, each with a case for:
   - hits lava
   - hits a shield
   - hits a stone
   - the caster dies mid-cast

   Most have only the main behaviour and a shield case. Rock Wall has no test file of its own.
3. **Sound (step 4):** no sound for a shield reflect, a Rock Wall rising, a boomerang return, or a homing flight.
   The impacts all share `hit`.
4. **Bot personality weights (step 5):** only Homing Orb has a personality weight in `ai/personalities/`. The
   other 6 shop spells use the default weight. That's fine for now, but tuning a bot's style toward its spells
   is missing.
5. **Specs (step 1):** the 4 starters and Homing Orb / Rock Wall have no spec file of their own. Their numbers
   live in GAME_DESIGN.md. This is fine historically, but todo 13 (combos) should cover them when the specs are
   written.
6. **Port (step 10):** all shop spells exist only on Android. Porting to PC hasn't been decided.
