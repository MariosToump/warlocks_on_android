"""Measure every assets/audio/*.wav: loudness, peak, bass share, DC, clipping, loop seam.

    python tools/audio_check.py            (needs numpy, scipy, pyloudnorm: pip install --user)

Exits 1 if any file clips, peaks over -1 dBFS, or is more than 2 LU off its role target
(the targets mirror ROLE_LUFS in tools/build_audio.gd). Made for the 2026-11-27 audio fixes.
"""
import glob, os, sys
import numpy as np
from scipy.io import wavfile
import pyloudnorm as pyln

ROLES = {"cast": -18, "impact": -17, "death": -15, "jingle": -18, "warning": -20, "soft": -21, "hum": -26,
         "ui": -21, "ambience": -24, "music": -16}
ROLE_OF = {**{k: "cast" for k in "fireball homing lightning shield blink boomerang meteor_fall well swap timestop staff mirror".split()},
           **{k: "impact" for k in "hit meteor_boom fight hurt reflect mirror_reflect".split()},
           "death": "death", "kill": "death", "win": "jingle", "lose": "jingle", "match_win": "jingle",
           "match_lose": "jingle", "lava_warn": "warning", "heartbeat": "warning", "boomerang_return": "soft",
           "ghost": "soft", "homing_hum": "hum", "beep": "ui", "coin": "ui", "click": "ui", "denied": "ui",
           "lava": "ambience", "music_fight": "music", "music_title": "music"}


def main(folder):
    bad = 0
    print(f"{'sound':17} {'len':>6} {'LUFS':>6} {'target':>6} {'peak':>6} {'<200Hz':>6} {'DC%':>5} {'seam':>5}  problems")
    for f in sorted(glob.glob(os.path.join(folder, "*.wav"))):
        name = os.path.splitext(os.path.basename(f))[0]
        rate, d = wavfile.read(f)
        x = d.astype(np.float64) / 32768.0
        block = min(0.4, len(x) / rate * 0.999)
        lufs = pyln.Meter(rate, block_size=block).integrated_loudness(x)
        peak = 20 * np.log10(max(np.abs(x).max(), 1e-9))
        spec = np.abs(np.fft.rfft(x)) ** 2
        fr = np.fft.rfftfreq(len(x), 1 / rate)
        bass = spec[fr < 200].sum() / max(spec.sum(), 1e-12)
        dc = abs(x.mean()) / max(np.abs(x).max(), 1e-9) * 100
        clipped = int((np.abs(d) >= 32767).sum())
        steps = np.abs(np.diff(x))
        seam = abs(x[0] - x[-1]) / max(np.percentile(steps, 99.9), 1e-9)
        role = ROLE_OF.get(name)
        target = ROLES.get(role)
        probs = []
        if clipped:
            probs.append(f"{clipped} clipped")
        if peak > -0.9:
            probs.append("peak over -1 dBFS")
        if target is not None and abs(lufs - target) > 2:
            probs.append(f"{lufs - target:+.1f} LU off target")
        if target is None:
            probs.append("no role")
        is_loop = name in ("lava", "homing_hum", "music_fight", "music_title")
        if is_loop and seam > 1.5:
            probs.append("loop seam step")
        bad += bool(probs)
        print(f"{name:17} {len(x) / rate:6.2f} {lufs:6.1f} {target if target is not None else '-':>6} {peak:6.1f} "
              f"{bass:6.0%} {dc:5.1f} {seam if is_loop else 0:5.2f}  {', '.join(probs)}")
    print("all ok" if not bad else f"{bad} files with problems")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "assets/audio"))
