# Lava Warlocks — Game Design

An original top-down pixel-art arena game inspired by the Warcraft III "Warlock" genre.
Do not copy names, art, text or data from any existing map. Everything here is our own.

## Progress (keep this up to date — read it before starting work)

_Last updated: 2026-11-28 (PC feel pass: zoomed-out start, smart cast with indicators, smaller PC HUD, staff lock-on for everyone — see "PC feel pass 2026-11-28"; todo 16 PC build done: one project builds Android + Windows, PC command bar, Esc / Alt+Enter, ghost on mouse — see "PC build 2026-11-28"; NEXT: the user playtests on PC; todo 17 store release prep added; staff marker over enemies, Fireball in the corner — see "Staff marker 2026-11-28"; performance pass: lava shrink stutter fixed, bots cheaper, stress test on the title (5 taps on the version) — see "Performance pass 2026-11-28"; spell rework: Meteor buff, Rock Wall -> Dark Mirror, Time Stop freezes wizards — see "Spell rework 2026-11-28"; 2026-11-27: review fixes done except the PC port — see "Review fixes 2026-11-27"; reviews: visual, audio, spell checklist, port, release, feel — see "Reviews 2026-11-27"; todo 13 step 1: sim sandbox + pair data; todos 12-15: more spells, combos, swappable starters, shop icon grid; todo 11: protect the code, in a couple of days; Android v0.13.1: ghost flies at 3.5x speed and teleports by tapping the minimap; v0.13: visual pass 1 in Godot (sparks, death dissolve, lava embers, heat shimmer, squash/stretch, shadows); v0.12.1: the shop fits phone screens; v0.12 released: Brawler rework + 5 new shop spells drawn in Godot + two shop slots. The user will test them on the phone. 2026-11-27: gameplay todos paused; next is graphics and design (steps a-f under todo 0), then the terrain stones brainstorm)_

Each project has a `README.md` (how to play, controls, layout, tests).
Two projects share this design:
- **PC**: `D:\Godot\Projects\claude_mcp\lava-warlocks` (keyboard + mouse, Forward+ renderer). Local git only.
- **Android**: `D:\Godot\Projects\claude_mcp\lava-warlocks-mobile` (touch controls, Compatibility renderer).
  GitHub (public): https://github.com/MariosToump/warlocks_on_android — app name "Warlocks on Android", v0.13.1 (2026-11-27).
  Build + install on the phone: `bash tools/deploy_android.sh`. APK: `build/warlocks_on_android.apk`.
  Releases (APK download): https://github.com/MariosToump/warlocks_on_android/releases — v0.6 (2026-11-24), v0.7, v0.8, v0.8.1 (2026-11-25), v0.9 (2026-11-26), v0.10, v0.11, v0.12, v0.12.1, v0.13, v0.13.1 (2026-11-27)
  (`gh release create vX.Y build/warlocks_on_android.apk`; bump `version/code` + `version/name` in export_presets.cfg first).
  Gameplay changes are made in PC first, then ported (`git cherry-pick` from the `pc` remote).
  **Exception — Android-only (v0.7 - v0.9, by choice):** fireball range 850 (PC: 700), the v0.7 HUD, pause menu and
  settings; v0.8 shop, Homing Orb, sound/music, title menu; everything in v0.9. PC is still at milestone 6. Expect a conflict in `fireball.gd` / `game.gd` / `round_hud.gd` / `touch_controls.gd` when cherry-picking.

### Next up (todo list, saved 2026-11-26; Android first)
**v0.9** (everything except the camera) — _all done 2026-11-26 and released as v0.9; details under "Android v0.9" below_:
- [x] 0a. Start banner "Fight!" → "Burn!" with a fiery whoosh.
- [x] 0b. Thumbstick fixes: a thumb held through the countdown never registered; a lost touch-up left the stick dead;
  the stick origin follows the thumb past the ring (quick reversals); smooth deadzone.
- [x] 0c. Movement option: Joystick / Touchpad (whole left half is a pad, Vampire Survivors style).
- [x] 1. Playtest harness (`tools/playtest.gd`): full bot matches at 4× speed, match length, deaths by cause, wins per bot.
- [x] 2. Shorter matches (5-8 min): first to 3, 2 s countdown / round-over, 10 s shop (skipped when broke), smaller island that shrinks sooner.
- [x] 3. Lava-first balance: lava 20 HP/s, more knockback, weaker staff, Caster bot toned down.
- [x] 4. Ghost mode: dead player floats as a ghost, can shove (haunt) wizards, no damage.
- [x] 5. Game feel: screen shake, hit-stop, knockback trail.
- [x] 6. Shield buff: a spell reflected by a shield comes back at 2× speed and 2× range (once per spell).
- [x] 7. Stones + pillars: block spells, boulders get shoved by knockback into wizards, sink in lava.
- [x] 8. Earth spell "Rock Wall" (shop) + fireball craters that slow walkers.
- [x] 9. Release v0.9: docs, APK on the phone, push, GitHub release.

**v0.10+** (before the v1.0 camera; planned 2026-11-26). Testing / sim cost, most first: bots > 8 warlocks >
secondary effects > extra rounds > lightning. Build order (user's choice): bots now, with the current spells.
- [x] 1. **Smarter, less predictable bots** — _done 2026-11-26 on Android, released as v0.10 on 2026-11-27. Design:
  `docs/superpowers/specs/2026-11-26-smarter-bots-design.md`; details under "Android v0.10 bots" below._
  A general "brain" that works for any spell; no cheating (same info and reaction limits as now).
  - Reaction time that varies; aim that is sometimes a little off or leads too much; hesitations and fake-outs.
  - A mood rolled each round (aggressive / cautious / opportunist) on top of the personality.
  - Takes risks when the moment is right: an enemy with low HP, near the lava edge, or with shield / blink on cooldown.
  - Weighted-random action choice instead of always the top score.
  - Measure with `tools/playtest.gd`: nobody > 40% of round wins, Brawler >= 15%, >= 50% lava deaths, fights 35-60 s.
    Then a feel check on the phone.
  - **Rule from now on:** every new spell gets its own bot `_score_X` / `_do_X` (`scripts/ai/ai_controller.gd`)
    plus a short harness check, as part of that spell's task.
- [x] 2. **Lightning rework** — _done 2026-11-27 on Android (v0.11). Design:
  `docs/superpowers/specs/2026-11-27-lightning-rework-design.md`; details under "Android v0.11" below._
  Reach 230 -> 450 (not the fireball's 850: an instant bolt that far would take over); hitbox = a capsule around
  the drawn bolt (16 px); tip zone = last 70 px, 28 px wide, knockback x1.25, bigger spark. Bots use it up to 93%
  of the reach and favour tip hits. Lava (user, 2026-11-27): shrink every 12 -> 18 s, hold 8 -> 12 s.
**Paused 2026-11-27 (the user):** todos 3, 4, 5 and 8 wait while we work on graphics and design (more animation,
a more "real" feel; research: a bigger PixelLab plan vs doing more in Godot). Order after the pause: terrain stones
brainstorm (6), then secondary effects (3), extra rounds (4); 8 warlocks (5) stays last.
- **PC feel pass 2026-11-28** (the user, after the first PC build; spec
  `docs/superpowers/specs/2026-11-28-pc-feel-pass-design.md`):
  - PC starts fully zoomed out (camera `min_zoom`, 1 screen px per art px at 1280x720); the wheel still zooms; Zoom
    row hidden on PC.
  - Smart cast (PC): hold a spell key -> `CastIndicator` (range ring + lane / Lightning tip / Blink landing / placed
    area, grey while cooling down); release casts at the mouse; right-click cancels. Shield and Dark Mirror cast on
    key down. Settings "Casting: Indicator / Instant" (`GameSettings.cast_mode`, saved).
  - Smaller PC HUD (~30%): bar strip 84, icons 44, minimap 110 (`Minimap.diameter`), scoreboard x0.75.
  - Staff lock-on, everyone incl. bots (the user: "keep it fair"): a swing started with `Wizard.attack()` lands on
    its warlock if they're within 45 px when the staff comes down; chasing within 85 px is 1.3x speed
    (`StaffStrikeSpell.LOCK_REACH / LOCK_RANGE / CHASE_BOOST`). Free swings unchanged. Test `tools/test_staff_lock.gd`.
  - Harness, 20 matches normal, before -> after: round wins Player 25 -> 26%, Brawler 24 -> 21%, Caster 29 -> 31%,
    Trickster 22 -> 22%; lava deaths 62 -> 64%; fights 49 -> 50 s; match 8:13 -> 7:58. All targets met; the
    shifts are within noise (~160 rounds per bot).
- **PC build 2026-11-28** (todo 16; the user: "the same game, playable on PC with mouse and keyboard"; spec
  `docs/superpowers/specs/2026-11-28-pc-catch-up-design.md`, plan `docs/superpowers/plans/2026-11-28-pc-catch-up.md`):
  - One project, two builds: `lava-warlocks-mobile` is the only codebase. `Platform.touch()` (`scripts/platform.gd`):
    touch on phones (`OS.has_feature("mobile")`) or with `-- --touch`; PC otherwise (a touchscreen laptop is PC).
    Tests force a mode with `Platform.forced`. The old `lava-warlocks` folder is an archive (README note).
  - PC: no touch layer (`TouchControls.enabled = false`, mouse doesn't emulate touch); the existing `PlayerController`
    (right-click walk / attack, A swing, Q W E R D F at the mouse). Ghost: hold right-click to float, A haunts,
    left-click the minimap teleports. Esc pauses (`pause` action), Alt+Enter / Settings "Fullscreen" (saved);
    Vibration and Move are hidden on PC; the II button moves to the top-right corner.
  - `PcBar` (`scripts/pc_bar.gd`): classic-RTS-style command bar in our own look (the user: no round buttons on PC):
    120 px stone strip, minimap in a bottom-left frame, centre panel (HP, gold, round), 4x2 spell card bottom right
    (Q W E R / D F _ A) with hotkey letters, a dark clockwise cooldown sweep + seconds, hover tooltips. Display only.
    Right-clicks over the bar don't walk you.
  - Windows export preset "Windows Desktop" + `tools/build_pc.sh` -> `build/pc/LavaWarlocks.exe` (one exe, data
    embedded); the 4.7.2 Windows export templates are installed. Tests: `tools/test_pc.gd` (windowed), suite 29/29.
    Screenshot shot: `tools/shots/pc_bar.gd`. Still to do: the user's PC playtest.
- **Staff marker 2026-11-28** (the user: the staff is one of the least used skills but held the best button;
  spec `docs/superpowers/specs/2026-11-28-staff-context-button-design.md`; Android only):
  - No fixed staff button. A marker floats over every enemy within 85 px (the swing still reaches 30); tap = step in
    and swing (`Wizard.attack`), hold = keep swinging, the stick or the enemy leaving stops it; glows while the
    Blink -> staff combo is open. Staff numbers, bots and PC controls unchanged.
  - Fireball takes the big corner button; shop slot D moves to Fireball's old spot; the corner is Haunt while a ghost.
  - Postponed: a loadout choice in round 1 (todo 14).
- **Performance pass 2026-11-28** (the user: steady FPS without visual changes, a player on an Android 8 phone
  stutters "when the lava moves", headroom for 8 warlocks; report `docs/perf/2026-11-28-v0.13.1.md`):
  - Cause found: while the lava crept in, every physics frame re-tested ~4,000 tile corners (1.3 ms on a desktop,
    ~10-20 ms on an old phone) and the regrow at round start repainted all 7,744 tiles.
  - Fixes (pixel-checked identical): corners melt from a pre-sorted list (`Arena._melt_order`), regrow repaints only
    touched cells, TileMapLayer chunks 16 -> 8 (half the tile rebuild, tile draw calls 102 -> 32), bots use one
    merged `Arena.is_unsafe()` and score each target once per think (~2x cheaper thinks), lava / shimmer shaders skip
    stone pixels.
  - User's phone (DN2103, Mali-G77), 4 wizards, lava creeping in: 1% low 26 -> 39 FPS, p99 38 -> 26 ms.
  - Stress test on the phone: tap the version label on the title 5 times (2 x 90 s, 4 then 8 wizards; results on
    screen + `PERF` lines in logcat). PC: `tools/perf_stress.gd`. Ask the Android 8 player to run it.
  - Next (not done): warm up effects behind the countdown (100-200 ms first-use hitches), spread bot thinks for 8
    warlocks.
- **Spell rework 2026-11-28** (the user; spec `docs/superpowers/specs/2026-11-28-meteor-mirror-timestop-design.md`,
  sim `docs/sim/2026-11-28-spell-rework/`; Android only, not released yet):
  - Meteor buffed: 20-26 damage (was 14-18), push 980-1160 (was 740-890), same 85 px hitbox; bigger rock (56 px,
    long flame tail) and blast art (232x156, ring to ~104 px), shake 6 -> 9. Duel win rate 46% -> 50%.
  - **Rock Wall replaced by Dark Mirror** (id `mirror`, F, 15 g): glass panes round you for 2.5 s (3 s at level 3)
    send any projectile straight back to its caster at the same speed, and Lightning back down its line. Covers
    1/3 of the ring when bought, 2/3 at level 1, all of it at level 2+ (the user's lvl 1/2/3; bought = level 0 in
    code). Panes sway a little; the wizard's hitbox is unchanged. Placed spells and the staff aren't reflected.
    Bots raise it against a seen spell (beats a dodge) and don't shoot into one. Duel 45%, cast 0.9/min (Rock Wall 0.08).
  - **Time Stop now freezes wizards** (not spells): enemies in the 120 px circle can't walk or cast for 1.5-2.1 s
    (was 2-2.6 s); knockback still moves them; hits inside push x1.2 and a wizard hit inside keeps x1.2 for 2.5 s
    after it gets out. Bots use it as an attack and follow up with Meteor. Duel 48% -> 61%.
  - Meteor + Time Stop is the first real combo the sim finds (+16 pp, 76% win rate). Open for the user: Time Stop and
    Gravity Well are both ~61%; Dark Mirror still below average.
  - Tests: `test_dark_mirror` (was `test_rock_wall`), `test_time_stop` (new); suite 28/28. Playtest: all targets met.
- **Review fixes 2026-11-27** (the user: do all of them except the PC port; checklist `docs/fixes-2026-11-27.md`):
  - Audio: Master limiter (-1 dB), every sound high-passed at 80 Hz and set to its role's loudness
    (`ROLE_LUFS` in `tools/build_audio.gd`), mid-range layers so phones hear hits and music, 7 s seamless lava loop,
    11 new sounds (shield reflect, kill, lava warning, heartbeat under 25% HP, match win / lose, not enough gold,
    rock wall, boomerang return, ghost, homing hum), at most 3 of one sound at once with priority sounds never cut,
    the music muffles in the shop. Fight mix: peak +0.3 -> -0.83 dBTP, 202 -> 0 clipped samples, bass 75% -> 42%.
    Check: `python tools/audio_check.py`.
  - Feel: every feel number in `scripts/feel.gd` (unchanged values); pause menu "Screen shake: Full / Reduced" (x0.35).
  - Visual: Homing Orb has its own violet orb + burst; Meteor blast and Time Stop ring redrawn at the wizards' pixel
    scale; Blink after-images, Swap beam; meteor warning shadow + pulsing ring; scoreboard 1.3x, big countdown digit,
    damage numbers white / yellow (yours) / red; Far zoom 1.35 -> 1.6; reflected shots tinted in the reflector's team
    colour; no lava-only first frame; rocks with flat shading and rough edges, 3 different wall rocks; far lava
    tiles flipped + crust patches; our own pixel font (`tools/build_font.gd`, project theme) with the smooth font
    kept for shop descriptions; north / north-east walk redone in PixelLab (2 generations; 1 trial generation left).
  - Spells: balance pass 1 (`docs/sim/2026-11-27-balance-pass/`): Homing Orb nerfed (duel 64% -> 57%), Meteor,
    Boomerang, Swap, Time Stop, Rock Wall buffed; bots raise walls / Time Stop when they can't sidestep;
    personality weights for the 6 shop spells. Still open: Gravity Well now strongest (62%), Meteor still weak,
    bots barely use Rock Wall. New tests `test_spell_edges`, `test_rock_wall`, `test_audio`; whole suite
    `bash tools/run_tests.sh`.
- **Reviews 2026-11-27** (Android v0.13.1; the findings that the fixes above answer):
  visual `docs/visual-reviews/2026-11-27-full.md` (top: Homing Orb looks like a fireball; Meteor / Time Stop drawn
  with bigger pixels; back-facing walk sprites don't match), audio `docs/audio-reviews/2026-11-27.md` (top: the
  fight mix clips — no limiter on Master; most energy is bass phones can't play; SFX levels 12 dB apart),
  spell checklist `docs/spell-audit-2026-11-27.md` (balance + edge-case tests missing for shop spells).
  Port check: PC has nothing Android lacks; Android is ~70 commits ahead (v0.7-v0.13), too far for one-by-one
  cherry-picks. Release check: tests 23/23, no debug flags, no keystore in git (APK is signed with
  `~/.android/debug.keystore` — keep a backup, or updates break). Feel numbers are spread over ~8 files
  (game.gd shake / hit-stop / vibration, meteor_strike.gd, arena_camera.gd smoothing 8, wizard.gd squash, vfx.gd,
  arena.gd embers, heat_haze shader); no "reduce screen shake" option yet. Not run: phone performance (phone not
  connected), playtest notes (no tester feedback yet).
- [x] 16. **PC catch-up** (done 2026-11-28 except the user's PC playtest; see "PC build 2026-11-28") (the user, 2026-11-28: "change our focus completely to the PC version and bring
  it up to date with our Android version"; "the same game, playable on PC with mouse and keyboard for now").
  Decided 2026-11-28: one project, two builds. `lava-warlocks-mobile` becomes the shared codebase with a Windows
  export; touch vs PC is switched at runtime; the old `lava-warlocks` folder becomes an archive. PC HUD: a classic
  WC3-style bottom bar in our own art (square spell icons with hotkeys and cooldown sweep, tooltips, centre panel,
  minimap frame), no round buttons (the user). Windows export templates (~1 GB) download approved if needed. Spec:
  `docs/superpowers/specs/2026-11-28-pc-catch-up-design.md`.
- [ ] 17. **Store release prep** (the user, 2026-11-28; later, not now). itch.io first (free page, Windows zip +
  APK, optional browser build, `tools/publish_itch.sh` with butler). Steam when nearly finished (Steamworks ~$100
  per game, store page "Coming Soon" 2+ weeks for wishlists, build review; optional GodotSteam for achievements /
  lobbies; players expect fullscreen, key remapping, controller / Steam Deck support). Before selling anywhere:
  check PixelLab / music / SFX licenses allow commercial use, Godot license notice in the credits, todo 11 (code
  private + rights notice). Google Play is a separate one-time $25.
- [ ] 11. **Protect the code** (user, 2026-11-27; do in a couple of days): make `warlocks_on_android` private
  (`gh repo edit --visibility private`; then only the user + invited GitHub accounts can see code or releases), add
  an "All rights reserved" notice (LICENSE + README), and a separate public repo with only the APK (e.g.
  `warlocks_on_android-releases`) so download links still work; each release gets published there. Later, before
  a store release: Godot PCK encryption (custom export templates). Optional: an itch.io page for testers.
- [ ] 12. **More spells (the original map's set, our own versions)** (user, 2026-11-27): Thrust (dash + shove),
  Link (tether that pulls), Drain (life steal over time), Bouncer (bounces between enemies), Splitter (breaks into
  pieces), Rush / Windwalk (speed burst, maybe brief invisibility). Own names / art / numbers. Each gets bot
  `_score_X` / `_do_X`, a test and a harness check. After todo 13 settles the design.
- [ ] 13. **Spell interactions and combos (planning)** — a matrix of which spells combine (e.g. Gravity Well + Meteor,
  Time Stop + Meteor, Link / Swap + lava, Bouncer off Rock Walls, Thrust into Gravity Well) and which counter which;
  bots learn the main combos. Brainstorm first, before todo 12.
  - [x] Step 1 (2026-11-27, Android): sim sandbox `tools/sim/` (not in the APK; Claude only): forced loadouts,
    no menus / shop, 16 parallel workers ~21x real time, FFA / duel / scenario modes, `python -I tools/sim/run.py`.
    Gameplay timers now run on game time (`GameClock`). Data: `docs/sim/2026-11-27-pair-synergy/` (2240 FFA +
    4352 duel rounds). Result: no pair shows synergy beyond noise (CIs +-10 pp; bots don't plan combos). Strength
    is real: Homing Orb is far ahead (duel 61% alone vs 38% with no shop spell; with Gravity Well 76%), Gravity
    Well next (55%); Time Stop, Rock Wall, Swap, Meteor, Boomerang alone are no better than nothing for bots.
    Scenario: a lone Gravity Well at the lava edge pulls a still target in 5/5, a bot walks out 20/20.
  - [ ] Step 2: the user decides — balance first (Homing Orb), bots that play combos, or longer runs for synergy.
- [ ] 14. **Swappable starters** — sell Fireball / Lightning / Blink / Shield in the shop to buy others. To settle in
  the todo 13 brainstorm: Q-R become normal slots; a minimum loadout (e.g. keep one projectile or one escape)?;
  refund rule; bots must play any loadout; button icons follow the spell.
- [ ] 15. **Shop redesign: icon grid + info box** (the user's choice, 2026-11-27) — with ~17 spells the row list in
  `scripts/shop_panel.gd` is too long for a 10 s shop. Your spells + upgrades as a tile row at the top (tap:
  upgrade / sell); new spells as an icon grid (~6 per row, price on each tile), tap one for name, description,
  combo hint and Buy in an info box on the right; items as a tile row. Fits 1280x720 with no scrolling; update
  `tools/test_shop_layout.gd`. Before or with todo 12.
- [ ] 0. **Graphics and design** — _visual pass 1 (Godot) done 2026-11-27, Android v0.13. Design:
  `docs/superpowers/specs/2026-11-27-visual-pass-design.md`. The user: don't darken the arena for now (so no
  normal maps yet). Next: the PixelLab finish (below), then more Godot polish after the user's phone check._
  - Visual pass 1: `scripts/vfx.gd` builds square-pixel CPUParticles2D bursts in code (max 24 alive): sparks on
    every hit coloured by kind (fire / lightning / push / swap / meteor), a puff when a spell is let go, embers on
    death. Death = the sprite dissolves texel by texel with a hot orange rim (`dissolve` in team_color.gdshader).
    Lava embers (40) rise from lava on screen near the island edge. Heat shimmer (`shaders/heat_haze.gdshader`)
    over lava only; "Heat shimmer: On/Off" in the pause menu (saved). Squash on hits, stretch on casts. Soft
    shadows under wizards and projectiles. Test: `tools/test_vfx.gd`.
  - [x] a. Visual pass 1 in Godot (v0.13, above).
  - [ ] b. The user's phone check of v0.13: too much / too little (sparks, shimmer), still smooth?
  - [ ] c. PixelLab finish (~9 generations, fits the free daily bonus): death E + NE, attack SE + NE, import
    `hurt_east_v2`, a breathing idle in 5 directions (S, SE, E, NE, N; the west side is mirrored in code).
  - [ ] d. More Godot polish (after b): light flashes on impacts and fireballs, staff bob / robe sway.
  - [ ] e. Later (the user said not now): a darker arena lit by the lava, then normal maps so robes catch the
    lava light.
  - [ ] f. Later: hit-type hurt / death animations (todo 10).
  - Research: research Godot (lights, shaders, particles, juice) vs a paid PixelLab
  plan (the account is on the free trial), then brainstorm and plan. The user's choice (2026-11-27): do as much
  as we can in Godot first (lights, particles, shaders, juice), then finish with PixelLab: the missing directions
  (death E/NE, attack SE/NE, hurt E is made but not imported; the west side is mirrored in code) and an idle.
- [ ] 10. **Hit-type hurt / death animations** (later) — 2-3 hurt and death variants picked by what hit you (e.g.
  fire, lightning, a heavy push, lava). Best case, later still: a unique hurt and death for every spell.
- [ ] 3. **Secondary spell effects** (paused, later) — the user's direction: an "enchanted" version of each spell
  that adds a secondary effect, with its own visuals. Details to discuss later. Bots learn each effect as it's added.
- [ ] 4. **Extra / bonus rounds with trigger conditions** — details to discuss. Sim how often triggers fire.
- [ ] 5. **8-warlock mode** — details to discuss (bigger island, 7 bots, spawns, HUD / score for 8, harness for
  N wizards, phone performance).
- [ ] 6. **Terrain stone walls brainstorm** — the user meant stones / stone walls as part of the island terrain, not a
  spell. Separate brainstorm session. The Rock Wall shop spell stays for now.
- [x] 7. **Brawler balance** — _done 2026-11-27 on Android. Design + sim log:
  `docs/superpowers/specs/2026-11-27-brawler-midrange-design.md`; details under "Android v0.12 Brawler" below._
  The user: a mid-range fighter who rushes in only on a chance, with a reward for it, as a rule for every wizard
  (option A). Holds 300 px; rushes only when the target is wide open (opportunity >= 0.7), or below 35% HP with its
  Lightning down. A staff hit within 1.5 s of your own Blink pushes x1.4. Round wins 6% -> 19-20%.
- [ ] 8. **Match length** — v0.12 matches average 8:12 in the harness (target 5-8 min), because the four wizards
  are now closer in strength. Wait for the user's phone test; if it feels long, try a faster lava shrink or
  first to 3 with a shorter fight timer, and re-run `tools/playtest.gd`.
- [ ] 9. **Test quirk** — in headless tests the player wizard creeps up about 12 px on its own (not in the game);
  find the cause. (The flaky `test_hud_v07` "lava sizzles" check is fixed, 2026-11-27: it waited 3 frames, and
  headless frames can pass with no physics tick; it now waits 0.2 s.)

**v1.0:** camera that tilts from top-down into a 3D perspective (2.5D hybrid, inspired by storm.game; our own code):
gameplay stays 2D, a 3D render layer mirrors it (heightmap island, billboard sprites, lava plane), Camera3D blends
orthographic top-down ↔ tilted perspective; then real hills/heights. Prototype on a branch, check phone performance.

**Discuss later:** medals (First Blood, Double Kill, Revenge, Lava Bath), kill-streak powers, levels + daily
challenges, cosmetic unlocks, a step-by-step tutorial.

### Milestones
- [x] 1. Project setup, arena with stone and lava tiles, camera.
- [x] 2. Player wizard: movement, animations, lava damage.
- [x] 3. Fireball + knockback physics.
- [x] 4. Blink, Lightning, Shield (+ hurt and death animations).
- [x] 5. AI bots (move, dodge, aim, avoid lava). _Done 2026-11-24 (PC and Android)._
- [x] 6. Rounds, score, shrinking arena, win screen. _Done 2026-11-24 (PC and Android)._
- [x] 7. Shop between rounds, gold, upgrades, items. _Done 2026-11-25 (Android only)._
- [x] 8. Polish: screen shake, hit flash, particles, sounds, menu. _Done on Android in v0.8 + v0.9 (2026-11-26)._
- [x] 9. Remaining spells — _done 2026-11-27 on Android (v0.12), before the v1.0 camera (the user's choice).
  Homing Orb v0.8, Rock Wall v0.9, then Boomerang, Swap, Meteor, Gravity Well and Time Stop in v0.12. Effect art
  is drawn in Godot code (`tools/build_effects.gd`), in the PixelLab effects' style. The user may redesign the
  spells after testing. Details under "Android v0.12 spells" below._

Right now it's a match of rounds against three AI bots (they fight you and each other). Last wizard standing
wins the round; first to 5 round wins takes the match, then a results screen with "Play again".
Android v0.8: between rounds a 15 s shop (gold, upgrades, items, the Homing Orb); the game opens on a title menu.
Android v0.9: first to 3 (~6 min matches), a 10 s shop, rocks on the island, a ghost when you're out.
Android v0.10: smarter bots (a mood each round, a wait-and-see opening, human-like aim and reactions).
Android v0.11: a longer Lightning with a stronger tip; the lava shrinks every 18 s.

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

- **Android v0.9** (2026-11-26, Android only). Prompted by a review + sims (matches 12-18 min, ~10% lava deaths,
  the Caster winning most rounds, long spectating) and friends' reports of the thumbstick "stopping".
  - **Playtest harness** `tools/playtest.gd` (with `--fixed-fps 60` it runs as fast as the CPU allows; the player is
    a neutral bot that shops): match / fight length, player dead-time, deaths in lava, kills and round-win share per
    bot; `noshop` arg. Targets: match 5-8 min, fights 35-60 s, >= 50% lava deaths, no bot > 40% of round wins.
    Before -> after (Normal): match 7:29 (first to 5) -> ~5:50 (first to 3), fight 62 -> 44 s, lava deaths
    6% -> ~55%, top round-win share Caster 89% -> ~40%. The Brawler is still the weakest bot (~3% of round wins:
    melee is risky when everything pushes you into lava) — keep an eye on it.
  - **Pacing:** first to 3 (default + setting), countdown 3 -> 2 s, round-over 3 -> 2 s, shop 15 -> 10 s and skipped
    when you can't buy anything ("No gold to spend" on the countdown). Island radius 38 -> 28 tiles; shrink every
    25 -> 12 s by 9 -> 6 tiles down to 10; hold 25 -> 8 s; sudden death 0.6 -> 1.2 tiles/s.
  - **Balance:** lava 8 -> 20 HP/s; knockback per damage 0.01 -> 0.015; knockback fireball 520-640, lightning 700-820,
    homing 480-570; staff damage 4-7 -> 2-4 (cooldown stays 0.5 s = the swing animation). Bots gang up on the
    round-wins leader (`AIController.LEADER_BONUS`, 180 px per win; `Wizard.match_wins`). Personalities retuned
    (Caster 220 px, retreat 0.5, near-neutral weights; Brawler 50 px, fireball 0.5, reposition 1.25).
  - **"Burn!"** replaces "Fight!" at the start of a fight, with a fiery whoosh (`build_audio.gd` "fight" recipe).
  - **Thumbstick fixes** (`touch_controls.gd`): a thumb put down during the countdown / between rounds used to be
    dropped (controls locked) — now it's kept and walks the moment the fight starts; a new left-half touch always
    takes the stick (a lost touch-up left it dead); canceled touches and app focus loss release it; the ring follows
    the thumb past its edge (instant reversals); speed ramps up from the deadzone. **Touchpad** movement setting:
    the whole left half is a pad, a short slide (8 px) = full speed, the origin trails 24 px behind the thumb.
  - **Ghost mode** (`scripts/ghost.gd`): 1.5 s after dying in a fight you float as a glowing ghost until the round
    ends (577.5 px/s = 3.5x walking since v0.13.1, over lava, not in `wizards`, camera follows; tap the minimap to
    teleport there, v0.13.1). Attack button = Haunt: shove 220 to wizards within
    60 px, no damage / kill credit, 4 s cooldown; spell buttons hidden. Replaces "camera follows your killer".
  - **Game feel:** `ArenaCamera.shake()` (hits on you, deaths on screen, the lava starting to creep); hit-stop
    (`game.hit_stop`: time x0.1 for 60-100 ms of real time, always restored) on big hits you take or land and on kills
    involving you; a fading streak behind wizards flying > 250 px/s. `game.feel_effects` (off in the harness).
  - **Shield buff:** a reflected projectile flies at 2x speed and 2x range, once per projectile (`Projectile.reflected`).
  - **Rocks** (`scripts/prop.gd`, art drawn in code; physics layer 4 = props; wizards and projectiles collide with it):
    3 boulders + 2 pillars per round (`game.props_per_round`) on stone, clear of the wizards. They block wizards,
    projectiles and lightning. Spells / the staff shove boulders (x0.7); a boulder rolling >= 140 px/s into a wizard
    does 6 damage + a push, credited to whoever shoved it; boulders sink in lava (pillars too, when the lava reaches
    them). Bots don't fire fireball / lightning when a rock is in the line (`Prop.blocks`).
  - **Rock Wall** (shop spell, slot F, 15 g; `scripts/spells/rock_wall.gd`): 3 rocks 60 px ahead across the aim for
    4-5.5 s, cd 10-7 s; bumps aside anyone standing there. Touch button up-left of Blink. Bots buy it and raise it
    against a spell they've seen coming while their shield is down.
  - **Craters** (`scripts/crater.gd`): fireballs leave a scorched patch (6 s, radius 22) that slows walkers to 60%.
  - Real hills / heights wait for the v1.0 camera.

- **Android v0.10 bots** (2026-11-26, Android only). The user: bots are too predictable (blue always charges and only
  shields, green always snipes and is the best, purple has no character, everyone is full-aggressive from second 1).
  - **Weighted-random choice** (`AIController._choose`): any action within `profile.choice_spread` (Easy 0.30,
    Normal 0.20, Hard 0.12) of the best can be picked; an urgent `recover` (>= 2.5) always wins outright.
  - **Human noise** (`AIProfile`): reaction time rolled per projectile (`reaction_jitter`), bell-curve aim error,
    lead rolled per cast (`lead_jitter`, sometimes too much), `hesitate_chance` to hold an attack for one think.
  - **Mood per round** (`scripts/ai/ai_mood.gd`; odds per personality): aggressive / cautious / opportunist scale
    attack, defence, distance and risk. Cautious and opportunist open with a 2-5 s **watch** (attacks x0.15, keeps
    260 px), broken early by being hit or a wide-open target.
  - **Fair memory** (`scripts/ai/ai_memory.gd`): remembers casts it *saw* (`cast_started`) and who got hit by someone
    else; "shield / blink / lightning probably down" is judged by the bot's own base cooldown x0.9. Never reads
    another wizard's cooldown.
  - **Opportunity** 0-1 (low HP, near lava, shield / blink seen used, knocked back, mid-cast, busy fighting someone
    else) boosts attacks and targeting by `risk` = personality `risk_appetite` x mood.
  - **Brawler:** dodges instead of shielding everything, weaves in, waits just outside lightning range until the
    target is open, threw a spell, or used its lightning (then charges and commits), gets impatient after 3-5 s.
    **Caster:** cautious-leaning, low risk. **Trickster:** opportunist, goes after wizards busy fighting others.
  - Harness (`tools/playtest.gd`) now prints win rate per mood and per bot per mood. Normal, 40 matches:
    match 6:16, fights 44 s, lava deaths 65%, round wins Caster 40%, stand-in 28%, Trickster 25%, Brawler 7-10%
    (v0.9: Caster 44%, Brawler 6%). Easy / Hard sane (Caster 41% / 31%). Aggressive mood still wins least.
  - Tests: `tools/test_ai_human.gd` (new) + `test_ai` updated (its Brawler tests give the target an opening; the
    distance tests use a knockback-proof dummy).

- **Android v0.11** (2026-11-27, Android only). The user: Lightning's reach is much shorter than the other two
  attacks; make it longer, with a hitbox matching the bolt and a slightly bigger tip that pushes harder. Also: the
  lava shrinks too fast.
  - `LightningSpell`: `max_range` 230 -> 450, `hit_width` 14 -> 16 (covers the drawn bolt), `tip_length` 70,
    `tip_width` 28, `tip_knockback` 1.25; `is_tip(t)` / `width_at(t)`; tip hits get a 1.6x spark.
  - AI: `LIGHTNING_REACH` is now 0.93 x the spell's range (was a fixed 215); +0.35 score for a target in the tip
    zone. The Brawler still waits just outside the enemy's reach (now ~470 px). Capping that at 300 px was tried
    and made no difference in the sims, so it was reverted.
  - Arena: `shrink_delay` 12 -> 18 s, `min_hold` 8 -> 12 s (island gone ~80 s into a fight instead of ~58).
  - Harness, Normal, 40 matches: match 6:41, fights 49 s (max 75), lava deaths 56%, round wins Caster 41%,
    stand-in 27%, Trickster 27%, Brawler 6% (v0.10: 6:16, 44 s, 65%, 40 / 28 / 25 / 7-10%).
  - Tests: `tools/test_lightning.gd` (new: reach, tip knockback, tip width, shield, bots); `test_spells` (out-of-range
    now 520 px), `test_ai_human` (weave test starts further out).

- **Android v0.12 Brawler** (2026-11-27, Android only).
  - **Behaviour:**
    - `brawler.tres`: `preferred_distance` 50 -> 300, and a new `charge_distance` of 50.
    - `AIController._opening_to_charge` is true when `opportunity` >= 0.7, or when the target is below 35% HP
      **and** its Lightning is probably down.
    - The impatient charge and the "threw a spell 1.2 s ago" trigger are gone.
  - **Blink-staff combo (every wizard):**
    - `Wizard.last_blink_at` is set by Blink.
    - `StaffStrikeSpell.combo_open(w)`: within `COMBO_WINDOW` (1.5 s), knockback x`COMBO_KNOCKBACK` (1.4) and a
      1.5x arc.
    - Bots score the staff +0.6 while the combo is open.
    - When rushing, they Blink in (26 px short, on their side) even with no lava near.
  - **Debugging (project copies, 40 matches each):**
    - With the default personality he wins 21-25% of rounds, and with mid range and no rush 32%.
    - Any rush that's frequent or goes deep drops him to 5-11%. Walking into melee was what killed him all along.
  - **Harness (Normal, 2 x 40 matches):**
    - round wins: Brawler 19 / 20%, Caster 32 / 31%, Player stand-in 26 / 25%, Trickster 23 / 24%
    - lava deaths 64 / 62%
    - fights 50 s
    - Matches are **8:16 / 8:19** (target 5-8): with more even bots it takes about 8 rounds to reach 3 wins.
  - **Tests:**
    - `tools/test_brawler.gd` is new: combo ratio and window, the 300 px hold, rush triggers, no impatience,
      Blink-in without lava.
    - `test_ai_human`: the old wait and impatience tests were removed.
    - `test_ai`: the open-target tests spend the target's Lightning first; "holds mid range" replaces "melee".

- **Android v0.12 spells** (2026-11-27, Android only). Design:
  `docs/superpowers/specs/2026-11-27-remaining-spells-design.md`; plan: `docs/superpowers/plans/2026-11-27-remaining-spells.md`.
  - **Two shop slots** (the user picked A, "for now, we will rework that"): `Shop.SHOP_SLOTS` D and F.
    - A bought spell takes its `home` slot, else the other free one. Both full: buying is refused.
    - `Shop.sell_spell` gives back half the price; the panel has Sell buttons and "Slots full".
    - Code finds bought spells with `Wizard.slot_of(id)`, never by a fixed slot.
  - **Spells** (`scripts/spells/`; their objects in the arena are in `scripts/`: `boomerang.gd`,
    `meteor_strike.gd`, `gravity_well.gd`, `time_stop_field.gd`):
    - Boomerang: 6-8 dmg, kb 360-450, cd 5-3.5.
    - Swap: orb 650 px/s, range 650-800, cd 9-7.5 (`Projectile.on_hit`).
    - Meteor: 1 s delay, 75 px, 14-18 dmg, kb 650-800, crater, cd 8-6.5.
    - Gravity Well: 160 px, 2.5 s, 220-300 px/s at the centre, x0.4 at the rim (my call: at a flat 220 a walker,
      165 px/s, could never escape, so a well at the edge was a certain kill), cd 10-8.5 (`Wizard.pull`).
    - Time Stop: 120 px, 2-2.6 s, cd 12-10.5 (`Projectile._frozen`).
    - Placed spells: `Spell.placed` (a touch drag also aims the distance) and `area_radius` (a ring while aiming).
  - **Art:** `tools/build_effects.gd` draws every frame pixel by pixel.
    - It uses the palette sampled from the PixelLab fireball, blink and lightning effects, plus one accent per
      spell, with a 1 px dark outline. Loose sparks are drawn after the outline.
    - The Meteor blast reuses the fireball impact, scaled up. 6 new synth sounds.
  - **Bots:**
    - `_score_X` / `_do_X` for each spell.
    - `evade`: walk out of Meteor rings and wells, and Blink when short of time. A well's pull triggers a re-think,
      like being knocked toward lava.
    - `_shot_blocked`: no projectile through a Time Stop.
    - Wish lists: Caster meteor / homing, Brawler swap / well, Trickster boomerang / timestop.
    - A spell-use count (8 matches) showed all 7 spells cast by bots. Time Stop is rare: it's only a reaction
      to an incoming spell.
  - **Harness, Normal, 40 matches:**
    - round wins: Caster 32%, Player stand-in 29%, Brawler 21%, Trickster 19%
    - lava deaths 61%
    - fights 51 s
    - **matches 8:12** (target 5-8)
  - **Tests:** `tools/test_new_spells.gd` (new); `test_shop` (the two slots).
  - **v0.12.1 shop fix** (the user, on the phone: the shop ran off the screen). With 7 new spells listed in one
    column the panel was 968 px tall on a 720 px screen (the phone, 2400x1080, is 1600x720 in game), so Ready, the
    timer and the last spells were cut off. Now the panel fills the screen with a 12 px margin, three columns
    (Your spells | New spells | Items) inside a ScrollContainer; nothing needs scrolling at 1280x720 or wider.
    The pause button hides while the shop is open (it covered the timer). New windowed test
    `tools/test_shop_layout.gd` (1600x720 and 1280x720; headless Godot measures text as zero size).
    - Known test quirk: in headless tests the player wizard creeps up about 12 px on its own (not in the game).
      `test_hud_v07` "lava sizzles" failed once, then passed 3 times in a row (timing).

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
- Android v0.9: boulders + pillars each round (see "Android v0.9"); radius 28 tiles, faster shrinking.
- **Shrinking** (2026-11-24): every 25 s the edge creeps in 9 tiles (4 s pulsing warning line, HUD "Lava rises in N"), down to 11 tiles, holds 25 s, then regrows. Tiles update incrementally. Dead wizards respawn at a random safe stone point far from others.
- `Wizard.take_damage(amount, source)` remembers `last_attacker` (for kill credit in rounds); bots turn on whoever just hit them.

### Tests
`godot --path . -s tools/<test>.gd`: test_wizard, test_fireball, test_spells, test_staff, test_ai, test_arena, test_rounds (+ on Android: test_hud_v07, test_shop, test_homing, test_title, test_ghost, test_feel, test_terrain, test_new_spells, test_vfx, and test_touch + test_shop_layout, which need a window: no `--headless`). All passing (2026-11-27).
test_ai and test_homing use the old 38-tile island (they place wizards ~900 px out).
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
| E | Lightning | Instant line (450 px on Android), high knockback; the tip pushes harder. |
| R | Shield | 1.5 s bubble that reflects projectiles. |
| D/F | Homing orb | Slow projectile that follows the nearest enemy (shop, 15). |
| D/F | Dark mirror | Glass panes round you for 2.5 s send spells back to their caster; 1/3, 2/3, full ring by level (shop, 15; replaced Rock Wall 2026-11-28). |
| D/F | Boomerang | Out 420 px and back, hits each wizard up to twice (shop, 15). |
| D/F | Meteor | 0.85 s warning ring, then an 85 px blast, 20-26 damage, push 980-1160, a crater (shop, 20). |
| D/F | Gravity well | Pulls enemies within 160 px to a point for 2.5 s; weaker at the rim (shop, 20). |
| D/F | Swap | Fast orb; on a hit, you and the target trade places (shop, 15). |
| D/F | Time stop | Freezes enemy wizards in a 120 px circle for 1.5-2.1 s; hits push +20%, and 2.5 s after for those hit inside (shop, 20). |
Shop spells (v0.12, Android only; the PC copy has Q-R): at most two at a time, in slots D and F; sell one for half its price to buy another.
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
