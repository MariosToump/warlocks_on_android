class_name Feel
extends RefCounted
## Every game-feel number in one place (game-feel-tuner, 2026-11-27): shake,
## hit-stop, vibration, squash, flashes, particles, camera follow. Balance
## numbers (damage, cooldowns, prices) are NOT here. Changes go in
## docs/feel-log.md with old -> new values. Ranges are sensible limits.

# --- screen shake (world px, seconds) ------------------------------------------
const HIT_SHAKE_PER_DAMAGE := 0.4 ## the player is hit: strength = damage x this ... (0.2-0.6)
const HIT_SHAKE_MIN := 2.0 ## ... clamped to this range (1-4)
const HIT_SHAKE_MAX := 6.0 ## (4-10)
const HIT_SHAKE_TIME := 0.25 ## (0.15-0.4)
const DEATH_SHAKE := 5.0 ## a wizard dies on screen (3-8)
const DEATH_SHAKE_TIME := 0.35 ## (0.2-0.5)
const LAVA_SHAKE := 2.5 ## the lava starts closing in (1-4)
const LAVA_SHAKE_TIME := 0.6 ## (0.3-1.0)
const METEOR_SHAKE := 6.0 ## a meteor lands near the camera (4-10)
const METEOR_SHAKE_TIME := 0.3 ## (0.2-0.5)
## "Reduce screen shake" (pause menu): every shake is scaled by this.
const REDUCED_SHAKE_SCALE := 0.35 ## (0-0.5)

# --- hit-stop (real seconds at time scale HIT_STOP_SCALE) -----------------------
const HIT_STOP_SCALE := 0.1 ## how slow time gets (0.05-0.3)
const HIT_STOP_DAMAGE := 10.0 ## hits this big (to or by the player) freeze (6-15)
const HIT_STOP_HIT := 0.06 ## (0.03-0.1)
const HIT_STOP_DEATH := 0.1 ## the player died or got the kill (0.06-0.15)

# --- vibration (ms) ---------------------------------------------------------------
const BUZZ_HIT := 40 ## (20-60)
const BUZZ_LAVA := 25 ## (15-40)

# --- the wizard sprite ------------------------------------------------------------
const SQUASH_HIT := Vector2(1.2, 0.85) ## squash when hit (1.1-1.3 / 0.75-0.9)
const SQUASH_CAST := Vector2(0.9, 1.12) ## stretch when a spell is let go
const SQUASH_TIME := 0.12 ## spring back (0.08-0.2)
const HIT_FLASH := Color(4, 4, 4) ## white flash brightness (2-5)
const HIT_FLASH_TIME := 0.15 ## (0.08-0.25)

# --- particles (Vfx) -------------------------------------------------------------
const VFX_MAX_LIVE := 24 ## bursts alive at once: the phone's budget (16-40)
const SPARKS_HIT := 16 ## sparks per normal hit (8-24)
const SPARKS_HIT_SPEED := 110.0
const SPARKS_HIT_LIFE := 0.4
const SPARKS_LIGHTNING := 14
const SPARKS_LIGHTNING_SPEED := 140.0
const SPARKS_LIGHTNING_LIFE := 0.25
const SPARKS_METEOR := 22 ## (12-30)
const SPARKS_METEOR_SPEED := 150.0
const SPARKS_METEOR_LIFE := 0.45
const CAST_PUFF := 8 ## particles when a spell is let go (4-12)
const DEATH_EMBERS := 26 ## (12-40)
const ARENA_EMBERS := 40 ## embers drifting over the lava (20-60)
const ARENA_EMBER_LIFE := 2.2

# --- camera -------------------------------------------------------------------------
const CAMERA_FOLLOW := 8.0 ## position smoothing speed: higher = snappier (5-12)
