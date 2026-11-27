# Brawler: mid range by default, rushes in on a real chance, Blink-staff combo — short design

## Why
The Brawler wins about 6% of rounds (target: at least 15%). He has the most deaths (247) and the fewest kills (132)
in 40 matches. He wants a 50 px fight against wizards who hit from 450-850 px. His triggers ("just threw a spell",
an impatient charge after 3-5 s) fire nearly all the time, so he is almost always running in through fire.
The user (2026-11-27): "make him mid range fighter unless approach brawler mood if there is a chance and reward for
it". They picked **A**: the reward is a game rule for everyone, not a Brawler-only perk.

## Goals
- **Mid range by default:** `preferred_distance` 50 -> **300 px**. He trades Lightning and Fireball like the others.
- **He rushes in only on a real chance:**
  - the target is exposed: `opportunity` of at least 0.4 (low HP, near lava, shield or blink down, flying, ...)
  - or its Lightning is probably recharging
  - Then he walks to staff range (a new personality field, `charge_distance`, 50 px), and his rush still gets
    `CHARGE_COMMIT`.
- **Removed:** the impatient charge (and its timers) and the "threw a spell 1.2 s ago" trigger.
- **Reward, a rule for every wizard:** a staff hit within **1.5 s of your own Blink** pushes **×1.4** harder,
  with a bigger hit arc. `Wizard.last_blink_at` is set by Blink.
- **Bots:**
  - During a charge, any bot with patient charge may Blink in from 80-220 px even when the target isn't near
    lava. It lands 26 px short of the target, on our side.
  - Every bot scores the staff a bit higher while its combo window is open, so it follows a Blink with a swing.

## Non-goals
- No new art and no new spells.
- The Caster and the Trickster keep their own behaviour.

## Approaches (the user picked A)
- **A. The combo is a rule for everyone** (chosen): it's fair, the player can use it too, and bots don't cheat.
- **B. A Brawler-only perk:** simpler to balance, but he would play by different rules.
- **C. A change to the bot's thinking only:** no real reward, so it wouldn't lift his win rate.

## Checks
- New `tools/test_brawler.gd`:
  - the combo pushes 1.35-1.45× harder than a plain staff hit, and no bonus after 1.5 s
  - his hold is about 300 px against a healthy target
  - he rushes in (< 60 px) when the target's HP is low, or 3 s after the target used Lightning
  - no rush within 6 s against a healthy target that does nothing
  - during a charge he Blinks in without lava nearby
- Update the old Brawler tests to the new behaviour: waits for an opening, gets impatient, goes into melee range.
- Harness: Normal, 40 matches.
  - Brawler at least 15% of round wins (or the best reached, reported honestly).
  - Nobody above 40%.
  - Lava deaths at least 50%.
  - Fights 35-60 s.

Plan: small enough that the tasks are the Checks above, in order: test, code, sim.

## Result (2026-11-27)
- **What the sims showed:** the first version (rush on opportunity 0.35 or the target's Lightning down) still gave
  the Brawler only 7%. Experiments in project copies, 40 matches each:
  - Changing the bot's colour made no difference (5%), and neither did neutral spell weights (8%).
  - The default personality got 24%, the default with zig-zag 25%, and the default with his risk/mood values 21%.
  - Mid range plus the rush got 5%.
  - Mid range with no rush at all got 32%.
  - Rushing only to 120 px got 11%.
  - Rushing only on a strong chance got 25%.
  - So walking into melee is what kills him, and the rush has to be rare.
- **Final rule (my call):** he rushes only when
  - `opportunity` is at least **0.7**, or
  - the target is below 35% HP **and** its Lightning is probably recharging.
  - (Low HP alone is not enough, and neither is the Lightning being down alone.)
- **Sims (Normal, 2 × 40 matches, the real Brawler):**
  - round wins: Brawler 19% / 20%, Caster 32 / 31, Player 26 / 25, Trickster 23 / 24
  - lava deaths 64 / 62%
  - fights 50 s
  - **Matches 8:16 / 8:19**, just over the 5-8 min target. The bots are closer in strength now, so it takes about
    8 rounds to reach 3 wins (was 6.5).
