# Lava Warlocks: road to the stores (go-to-market plan, 2026-11-28)

The user, 2026-11-28: build early popularity with the freest options first, do our own advertising (Reddit, X and
other social media), and move to the mainstream stores (Steam, Google Play) once the game is a "little bit of a
finished product". This file is for revisiting: tick the boxes, note dates, and check the "ready for the next stage"
line before moving on. It belongs with `2026-11-28-roadmap.md` (topics E, F, I) and todo 17.

Order of the mainstream stores (proposal, agreed in principle): **Steam first, then Google Play.**
- The game's core audience (fans of the Warcraft III Warlock map, PC arena players) lives on PC.
- Steam's wishlists, festivals (Next Fest) and Playtest feature are the best free promotion an indie game gets.
- Google Play's closed test needs 12+ testers for 14 days in a row. The community built in stage 1 can supply them,
  so that step becomes easy later, not a blocker now.
- The Steam page should go up **early** ("Coming Soon" collects wishlists for months). Two weeks is only Valve's
  minimum.

---

## Stage 0: friends (now)
- [x] APK + Windows zip on GitHub releases (v0.14, 2026-11-28)
- [ ] Friends play and report. The user collects notes (the playtest-notes skill can sort them).
- [ ] Decide the public name. Run a trademark check on "Lava Warlocks" in EUIPO / TMview and USPTO. The Android app
      is still called "Warlocks on Android".

**Ready for stage 1 when:** the name is settled; there's a credits screen (Godot MIT notice, music / SFX / PixelLab
credits); licences are checked for public use; todo 11 (private code + rights notice) is done.

## Stage 1: free and public (popularity + feedback), costs 0
- [ ] **itch.io page** (free; set your own revenue share): Windows zip, APK, maybe a browser build later (check
      browser performance first). GIF / screenshots, short description. Upload with butler (`tools/publish_itch.sh`).
- [ ] **In-game feedback link** (roadmap F): a Google Form or Tally (free), plus the version and platform.
- [ ] **Privacy policy page** (free, e.g. GitHub Pages): needed later for Google Play anyway. Say what feedback
      collects.
- [ ] **Discord server** for testers. It becomes the pool for the Google Play 12-tester test and Steam Playtest.
- [ ] **Game Jolt** page (free) as a second home.
- [ ] **Social media, our own advertising:**
  - Reddit:
    - r/playmygame;
    - r/IndieDev;
    - r/godot (Godot showcases);
    - r/indiegaming;
    - r/WC3 and custom-map communities, if their rules allow; say "inspired by", and use no Blizzard art or names in
      the game.
  - X and Bluesky: #screenshotsaturday, #indiedev, #godotengine, #pixelart, with short clips of knockbacks into the
    lava.
  - TikTok, YouTube Shorts and Instagram Reels: 10-20 s clips. The record_demo tool and Movie Maker can make them.
  - A devlog on itch.io every week or two.
  - Rhythm: post often, show progress, answer comments. Each post links the itch.io page and the Discord.
- [ ] Track numbers in this file each month: itch.io views and downloads, Discord members, feedback count, and the
      top three complaints.

**Ready for stage 2 when:** people outside friends play and come back, e.g. around 50+ Discord members and steady
feedback (proposal; the user sets the real bar). Online multiplayer is playable.

## Stage 2: free multiplayer beta
- [ ] Online play (room codes + quick match) on the cheap server (see roadmap A, "Servers").
- [ ] Beta weekends announced on Discord / Reddit / X (a fixed time, so enough people are online at once).
- [ ] Feedback and balance passes from real matches. Performance checks on the low-end phone and PC (standing rule).

**Ready for stage 3 when:** online matches are stable, there's enough content for a store page, and the trailer and
capsule art are made.

## Stage 3: mainstream, starting with Steam
- [ ] Steamworks: $100 per game (paid back after $1,000 in sales). Onboarding takes 1-5 days: ID, bank, tax form
      (W-8BEN for non-US developers).
- [ ] "Coming Soon" store page **as early as possible** (months before release) for wishlists. Add a trailer, GIFs
      and tags.
- [ ] Steam Playtest (a free separate app) for open tests. A demo for Steam Next Fest.
- [ ] Release on Steam (Early Access or full). Ranked mode uses Steam login on PC (to be decided).

## Stage 4: Google Play
- [ ] Play Console: $25 once, identity check. Declare trader status (EU Digital Services Act; deadline reported as
      Feb 2027). If a trader, the contact address and phone number are public to EU users, so consider a business
      address.
- [ ] Closed test: **12+ testers from the Discord, opted in 14 days in a row** (recruit 15-25 for a buffer).
- [ ] Privacy policy URL, Data safety form, IARC content rating, current target API level.
- [ ] Open test or production release.

## Before money changes hands (any stage that sells)
- Register for tax where the user lives (self-employed or a business). Ask a local accountant. The stores handle
  VAT on customer sales in most countries.
- A legal review: terms, privacy (GDPR for accounts / IP addresses), age ratings, and no free-text chat (moderation).

## Log
- 2026-11-28: plan written. Stage 0.
