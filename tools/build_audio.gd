extends SceneTree
## Builds every sound effect and the two music loops with a tiny retro synth
## (sfxr-style: square / saw / triangle / sine / noise voices, pitch slides,
## envelopes, a one-pole low-pass) and writes them to assets/audio/*.wav.
## No samples or downloads: everything is made from maths, so it's ours.
##   godot --headless --path . -s tools/build_audio.gd
## Re-run after changing a recipe; the game loads the .wav files.

const RATE := 22050
const OUT := "res://assets/audio"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var t0 := Time.get_ticks_msec()
	# --- spells -------------------------------------------------------------
	_save("fireball", _mix([
		voice({"wave": "noise", "dur": 0.35, "attack": 0.03, "lowpass": 0.18, "vol": 0.55}),
		voice({"wave": "saw", "f0": 320.0, "f1": 110.0, "dur": 0.3, "vol": 0.22, "lowpass": 0.3}),
	]))
	_save("homing", _mix([
		voice({"wave": "sine", "f0": 520.0, "f1": 880.0, "dur": 0.35, "vib": 18.0, "vib_depth": 0.06, "vol": 0.4}),
		voice({"wave": "tri", "f0": 1040.0, "f1": 1760.0, "dur": 0.3, "vol": 0.18}),
	]))
	_save("hit", _mix([
		voice({"wave": "noise", "dur": 0.32, "lowpass": 0.35, "lowpass_end": 0.05, "vol": 0.5}),
		voice({"wave": "sine", "f0": 150.0, "f1": 45.0, "dur": 0.25, "vol": 0.45}),
	]))
	_save("lightning", _mix([
		voice({"wave": "noise", "dur": 0.4, "lowpass": 0.9, "vol": 0.45, "crackle": 0.35}),
		voice({"wave": "square", "f0": 1800.0, "f1": 400.0, "dur": 0.25, "vol": 0.15, "duty": 0.3}),
		voice({"wave": "sine", "f0": 90.0, "f1": 40.0, "dur": 0.3, "vol": 0.35}),
	]))
	_save("shield", _mix([
		voice({"wave": "sine", "f0": 380.0, "f1": 760.0, "dur": 0.55, "attack": 0.05, "vib": 22.0, "vib_depth": 0.05, "vol": 0.35}),
		voice({"wave": "tri", "f0": 760.0, "f1": 1520.0, "dur": 0.5, "attack": 0.08, "vol": 0.2}),
	]))
	_save("blink", _mix([
		voice({"wave": "sine", "f0": 1400.0, "f1": 260.0, "dur": 0.2, "vol": 0.4}),
		voice({"wave": "noise", "dur": 0.12, "lowpass": 0.5, "vol": 0.25}),
	]))
	# v0.12 shop spells
	_save("boomerang", _mix([ # a whirring blade
		voice({"wave": "saw", "f0": 300.0, "f1": 420.0, "dur": 0.4, "vib": 28.0, "vib_depth": 0.25, "vol": 0.22, "lowpass": 0.35}),
		voice({"wave": "noise", "dur": 0.35, "lowpass": 0.3, "vol": 0.2, "crackle": 0.5}),
	]))
	_save("meteor_fall", _mix([ # a falling whistle with a roar under it
		voice({"wave": "sine", "f0": 1600.0, "f1": 300.0, "dur": 0.95, "attack": 0.1, "vol": 0.25}),
		voice({"wave": "noise", "dur": 0.95, "attack": 0.5, "lowpass": 0.08, "lowpass_end": 0.3, "vol": 0.35}),
	]))
	_save("meteor_boom", _mix([
		voice({"wave": "noise", "dur": 0.7, "lowpass": 0.5, "lowpass_end": 0.04, "vol": 0.6}),
		voice({"wave": "sine", "f0": 110.0, "f1": 30.0, "dur": 0.6, "vol": 0.6}),
		voice({"wave": "saw", "f0": 90.0, "f1": 35.0, "dur": 0.5, "vol": 0.2, "drive": 5.0, "lowpass": 0.2}),
	]))
	_save("well", _mix([ # a deep rising hum
		voice({"wave": "saw", "f0": 70.0, "f1": 140.0, "dur": 0.9, "attack": 0.2, "detune": 0.02, "vol": 0.3, "lowpass": 0.15}),
		voice({"wave": "sine", "f0": 400.0, "f1": 200.0, "dur": 0.8, "vib": 9.0, "vib_depth": 0.1, "vol": 0.15}),
	]))
	_save("swap", _mix([ # zip there and back
		voice({"wave": "square", "f0": 400.0, "f1": 1600.0, "dur": 0.12, "vol": 0.2, "duty": 0.3}),
		voice({"wave": "square", "f0": 1600.0, "f1": 400.0, "dur": 0.14, "vol": 0.2, "duty": 0.3, "delay": 0.12}),
	]))
	_save("timestop", _mix([ # a bright chime that hangs in the air
		voice({"wave": "tri", "f0": 1568.0, "dur": 0.9, "vol": 0.22, "vib": 6.0, "vib_depth": 0.01}),
		voice({"wave": "sine", "f0": 2349.0, "dur": 0.8, "vol": 0.14, "delay": 0.05}),
		voice({"wave": "sine", "f0": 784.0, "dur": 0.9, "vol": 0.18}),
	]))
	_save("staff", voice({"wave": "noise", "dur": 0.16, "attack": 0.04, "lowpass": 0.25, "lowpass_end": 0.6, "vol": 0.4}))
	# --- wizards ------------------------------------------------------------
	_save("hurt", voice({"wave": "square", "f0": 260.0, "f1": 120.0, "dur": 0.14, "vol": 0.3, "duty": 0.4}))
	_save("death", _mix([
		voice({"wave": "saw", "f0": 320.0, "f1": 55.0, "dur": 0.7, "vol": 0.3, "lowpass": 0.25}),
		voice({"wave": "noise", "dur": 0.6, "lowpass": 0.12, "vol": 0.35}),
	]))
	_save("lava", _lava_loop(2.0), true)
	# --- round / UI ---------------------------------------------------------
	_save("beep", voice({"wave": "square", "f0": 660.0, "dur": 0.12, "vol": 0.25}))
	# "Burn!": a fiery whoosh (rising roar of flame + a low growl that drops).
	_save("fight", _mix([
		voice({"wave": "noise", "dur": 0.75, "attack": 0.12, "lowpass": 0.05, "lowpass_end": 0.55, "vol": 0.55, "crackle": 0.15}),
		voice({"wave": "saw", "f0": 140.0, "f1": 55.0, "dur": 0.7, "attack": 0.05, "vol": 0.3, "drive": 4.0, "lowpass": 0.2}),
		voice({"wave": "square", "f0": 660.0, "f1": 990.0, "dur": 0.25, "vol": 0.12, "delay": 0.05}),
	]))
	_save("win", _arpeggio([523.25, 659.25, 783.99, 1046.5], 0.1, 0.5, "square"))
	_save("lose", _arpeggio([392.0, 329.63, 261.63], 0.16, 0.45, "tri"))
	_save("coin", _mix([
		voice({"wave": "square", "f0": 988.0, "dur": 0.07, "vol": 0.22}),
		voice({"wave": "square", "f0": 1318.5, "dur": 0.22, "vol": 0.22, "delay": 0.07}),
	]))
	_save("click", voice({"wave": "square", "f0": 1500.0, "dur": 0.035, "vol": 0.18}))
	# --- music ----------------------------------------------------------------
	_save("music_fight", _music_fight(), true)
	_save("music_title", _music_title(), true)
	print("audio built in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit()


# --- synth --------------------------------------------------------------------

## One voice. Keys: wave (square/saw/tri/sine/noise), f0, f1 (pitch slide,
## exponential), dur, attack, vol, duty, vib, vib_depth, lowpass (0-1, lower
## = darker), lowpass_end, crackle (0-1: random dropouts), delay;
## detune (a second oscillator this fraction sharper: thick, beating),
## drive (distortion: 0 = clean, 4-10 = crunchy guitar), poles (1 or 2:
## steeper low-pass), release (> 0: pad envelope = attack, hold, then fade
## over the last `release` seconds instead of a plucked decay).
func voice(p: Dictionary) -> PackedFloat32Array:
	var dur: float = p.get("dur", 0.3)
	var delay: float = p.get("delay", 0.0)
	var n := int((dur + delay) * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var wave: String = p.get("wave", "square")
	var f0: float = p.get("f0", 440.0)
	var f1: float = p.get("f1", f0)
	var attack: float = maxf(p.get("attack", 0.005), 0.001)
	var vol: float = p.get("vol", 0.3)
	var duty: float = p.get("duty", 0.5)
	var vib: float = p.get("vib", 0.0)
	var vib_depth: float = p.get("vib_depth", 0.0)
	var lp0: float = p.get("lowpass", 1.0)
	var lp1: float = p.get("lowpass_end", lp0)
	var crackle: float = p.get("crackle", 0.0)
	var detune: float = p.get("detune", 0.0)
	var drive: float = p.get("drive", 0.0)
	var poles: int = p.get("poles", 1)
	var release: float = p.get("release", 0.0)
	var phase := 0.0
	var phase2 := randf()
	var lp := 0.0
	var lp2 := 0.0
	var hold := 1.0
	var start := int(delay * RATE)
	for i in range(start, n):
		var t := float(i - start) / RATE
		var k := t / dur
		var f := f0 * pow(f1 / f0, k)
		if vib > 0.0:
			f *= 1.0 + vib_depth * sin(TAU * vib * t)
		phase = fmod(phase + f / RATE, 1.0)
		var s := _osc(wave, phase, duty)
		if detune > 0.0:
			phase2 = fmod(phase2 + f * (1.0 + detune) / RATE, 1.0)
			s = (s + _osc(wave, phase2, duty)) * 0.6
		if drive > 0.0:
			s = tanh(s * drive) / tanh(drive)
		if crackle > 0.0:
			if randf() < 0.004:
				hold = 0.0 if randf() < crackle else 1.0
			s *= hold
		var a := lerpf(lp0, lp1, k)
		lp += (s - lp) * a
		s = lp
		if poles > 1:
			lp2 += (s - lp2) * a
			s = lp2
		var env: float
		if release > 0.0:
			env = minf(t / attack, 1.0) * clampf((dur - t) / release, 0.0, 1.0)
		else:
			env = minf(t / attack, 1.0) * pow(1.0 - k, 1.6)
		out[i] = s * env * vol
	return out


func _osc(wave: String, ph: float, duty: float) -> float:
	match wave:
		"square":
			return 1.0 if ph < duty else -1.0
		"saw":
			return ph * 2.0 - 1.0
		"tri":
			return 1.0 - 4.0 * absf(ph - 0.5)
		"sine":
			return sin(TAU * ph)
		"noise":
			return randf_range(-1.0, 1.0)
	return 0.0


func _mix(parts: Array) -> PackedFloat32Array:
	var n := 0
	for p in parts:
		n = maxi(n, p.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for p in parts:
		for i in p.size():
			out[i] += p[i]
	return out


## Add `src` into `dst` starting at sample `at` (grows nothing; clips at end).
func _add(dst: PackedFloat32Array, src: PackedFloat32Array, at: int) -> void:
	for i in src.size():
		var j := at + i
		if j >= dst.size():
			return
		dst[j] += src[i]


func _arpeggio(freqs: Array, step: float, tail: float, wave: String) -> PackedFloat32Array:
	var parts := []
	for i in freqs.size():
		var last := i == freqs.size() - 1
		parts.append(voice({"wave": wave, "f0": freqs[i], "dur": tail if last else step * 1.6,
				"delay": step * i, "vol": 0.22, "duty": 0.5}))
	return _mix(parts)


## Bubbling lava: dark rumble + random pops, seamless (fades handled by
## keeping the rumble steady; pops never cross the loop point).
func _lava_loop(seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		lp += (randf_range(-1.0, 1.0) - lp) * 0.04
		out[i] = lp * 0.5
	for k in 9:
		var pop := voice({"wave": "sine", "f0": randf_range(180.0, 320.0), "f1": randf_range(60.0, 110.0),
				"dur": randf_range(0.05, 0.1), "vol": 0.25})
		_add(out, pop, randi_range(0, n - pop.size() - 1))
	return out


func _note(name: String) -> float:
	# A4 = 440; names like "A3", "C#4", "F5".
	var names := {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
	var octave := int(name.right(1))
	var semis: int = names[name.left(name.length() - 1)] + (octave - 4) * 12
	return 440.0 * pow(2.0, semis / 12.0)


## Fight loop: dark, heavy and mid-tempo (92 BPM, E minor), 16 bars ~42 s.
## An original riff on a distorted "guitar" (detuned saws through drive and a
## steep low-pass): palm-muted chugs on low E answered by power chords, half-
## time drums, a dark pad underneath. Bars 9-12 drop into a slow breakdown
## with a mournful lead; 13-16 bring the riff back under a high lead.
const FIGHT_BPM := 92.0
## One riff bar = 16 sixteenths: [step, note or "x" (muted chug on low E),
## length in sixteenths]. Power chords = note + fifth.
const RIFF_A := [[0, "x", 1], [1, "x", 1], [2, "x", 1], [4, "G2", 2], [6, "x", 1], [7, "x", 1],
		[8, "F#2", 2], [10, "x", 1], [12, "A#2", 1], [13, "A2", 1], [14, "x", 1], [15, "x", 1]]
const RIFF_B := [[0, "x", 1], [1, "x", 1], [2, "x", 1], [3, "x", 1], [4, "C3", 3], [7, "x", 1],
		[8, "B2", 2], [10, "x", 1], [11, "x", 1], [12, "G2", 4]]


func _music_fight() -> PackedFloat32Array:
	var beat := 60.0 / FIGHT_BPM
	var sx := beat / 4.0 # a sixteenth
	var bars := 16
	var n := int(bars * 16 * sx * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var riffs := [RIFF_A, RIFF_B, RIFF_A, RIFF_B, RIFF_A, RIFF_B, RIFF_A, "turn",
			"break", "break", "break", "break_fill", RIFF_A, RIFF_B, RIFF_A, "turn"]
	var pads := ["E3", "E3", "E3", "E3", "E3", "E3", "C3", "B2",
			"E3", "C3", "A2", "B2", "E3", "E3", "C3", "B2"]
	var break_chords := ["E2", "C3", "A2", "B2"]
	var break_lead := [["B4", 0, 6], ["A#4", 6, 2], ["A4", 8, 8], ["G4", 16, 4], ["F#4", 20, 4], ["E4", 24, 8],
			["C5", 32, 6], ["B4", 38, 2], ["A4", 40, 8], ["F#4", 48, 4], ["G4", 52, 4], ["D#4", 56, 8]]
	var high_lead := [["E5", 0, 8], ["D#5", 8, 8], ["E5", 16, 6], ["G5", 22, 2], ["F#5", 24, 8],
			["E5", 32, 8], ["C5", 40, 8], ["B4", 48, 16]]
	for bar in bars:
		var t0 := bar * 16 * sx
		var at0 := int(t0 * RATE)
		var kind = riffs[bar]
		# Dark pad: root + third + fifth, very muffled, whole bar.
		var root := _note(pads[bar])
		var third := 1.2 if pads[bar] in ["E3", "A2"] else 1.26
		for mult in [1.0, third, 1.5]:
			_add(out, voice({"wave": "saw", "f0": root * mult, "dur": 16 * sx, "attack": 0.4, "release": 0.6,
					"detune": 0.004, "lowpass": 0.025, "poles": 2, "vol": 0.11}), at0)
		if kind is Array:
			for ev in kind:
				_guitar(out, int((t0 + ev[0] * sx) * RATE), ev[1], ev[2] * sx)
			_drums_heavy(out, t0, sx, bar % 4 == 0)
		elif kind == "turn":
			# Bars 8 / 16: a slow chromatic climb back to E.
			var steps := [["C3", 0, 4], ["C#3", 4, 4], ["D3", 8, 4], ["D#3", 12, 4]]
			for ev in steps:
				_guitar(out, int((t0 + ev[1] * sx) * RATE), ev[0], ev[2] * sx * 0.95)
			_drums_heavy(out, t0, sx, false)
			for k in 4: # toms down into the next bar
				_add(out, voice({"wave": "sine", "f0": 220.0 - k * 40.0, "f1": 70.0, "dur": 0.25, "vol": 0.4}),
						int((t0 + (12 + k) * sx) * RATE))
		else:
			# Breakdown: one ringing power chord per bar, sparse drums, slow lead.
			var b := bar - 8
			_guitar(out, at0, break_chords[b], 16 * sx * 0.98, true)
			_add(out, voice({"wave": "sine", "f0": 120.0, "f1": 38.0, "dur": 0.45, "vol": 0.6}), at0)
			_add(out, voice({"wave": "noise", "dur": 0.3, "lowpass": 0.4, "vol": 0.2}), int((t0 + 8 * sx) * RATE))
			if kind == "break_fill":
				for k in 6:
					_add(out, voice({"wave": "sine", "f0": 200.0 - k * 22.0, "f1": 60.0, "dur": 0.22, "vol": 0.35}),
							int((t0 + (10 + k) * sx) * RATE))
		# Leads.
		if bar >= 8 and bar < 12:
			_lead(out, t0 - (bar - 8) * 16 * sx, sx, break_lead, (bar - 8) * 16, 0.07)
		if bar >= 12:
			_lead(out, t0 - (bar - 12) * 16 * sx, sx, high_lead, (bar - 12) * 16, 0.05)
	return _soft_clip(out)


## Distorted guitar: "x" = palm-muted low E chug, else a power chord.
func _guitar(out: PackedFloat32Array, at: int, note: String, dur: float, ring := false) -> void:
	if note == "x":
		for f in [_note("E2"), _note("B2")]:
			_add(out, voice({"wave": "saw", "f0": f, "dur": 0.11, "detune": 0.006, "drive": 7.0,
					"lowpass": 0.09, "poles": 2, "vol": 0.17}), at)
		_add(out, voice({"wave": "sine", "f0": _note("E1"), "dur": 0.12, "vol": 0.22}), at)
		return
	var f := _note(note)
	for mult in [1.0, 1.5, 2.0]:
		_add(out, voice({"wave": "saw", "f0": f * mult, "dur": dur, "detune": 0.006, "drive": 6.0,
				"lowpass": 0.16 if not ring else 0.12, "lowpass_end": 0.07, "poles": 2,
				"release": 0.08 if not ring else dur * 0.5, "vol": 0.12}), at)
	_add(out, voice({"wave": "sine", "f0": f / 2.0, "dur": dur, "release": 0.05, "vol": 0.2}), at)


## Half-time heavy beat: kick on 1, the "a" of 2 and the "and" of 3; snare
## on 3; quiet ride on eighths; a crash on section starts.
func _drums_heavy(out: PackedFloat32Array, t0: float, sx: float, crash: bool) -> void:
	for step in [0, 7, 10]:
		_add(out, voice({"wave": "sine", "f0": 115.0, "f1": 38.0, "dur": 0.22, "vol": 0.6}), int((t0 + step * sx) * RATE))
	_add(out, voice({"wave": "noise", "dur": 0.22, "lowpass": 0.45, "lowpass_end": 0.15, "vol": 0.32}), int((t0 + 8 * sx) * RATE))
	_add(out, voice({"wave": "sine", "f0": 190.0, "f1": 140.0, "dur": 0.12, "vol": 0.18}), int((t0 + 8 * sx) * RATE))
	for step in range(0, 16, 2):
		_add(out, voice({"wave": "noise", "dur": 0.05, "lowpass": 0.9, "vol": 0.04}), int((t0 + step * sx) * RATE))
	if crash:
		_add(out, voice({"wave": "noise", "dur": 1.4, "lowpass": 0.7, "lowpass_end": 0.2, "vol": 0.12}), int(t0 * RATE))


## Mournful lead: square through a soft low-pass with slow vibrato.
## `notes` = [[note, start sixteenth, length]]; draws those inside this bar.
func _lead(out: PackedFloat32Array, phrase_t0: float, sx: float, notes: Array, from: int, vol: float) -> void:
	for ev in notes:
		if ev[1] < from or ev[1] >= from + 16:
			continue
		var dur: float = ev[2] * sx
		_add(out, voice({"wave": "square", "f0": _note(ev[0]), "dur": dur, "attack": 0.03, "release": dur * 0.4,
				"duty": 0.3, "vib": 5.0, "vib_depth": 0.008, "lowpass": 0.12, "poles": 2, "detune": 0.003, "vol": vol}),
				int((phrase_t0 + ev[1] * sx) * RATE))


## Title loop: dark ambient, 32 s. A deep drone whose filter slowly breathes,
## minor pads, distant bells with an echo, a low boom every 8 s, wind.
## Drone pitches fit a whole number of cycles in the loop, so it repeats
## without a click.
func _music_title() -> PackedFloat32Array:
	var seconds := 32.0
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	# Drone (E1, two detuned saws + E2) and wind.
	var fa := roundf(41.2 * seconds) / seconds
	var fb := roundf(41.45 * seconds) / seconds
	var fc := roundf(82.4 * seconds) / seconds
	var lp := 0.0
	var lp2 := 0.0
	var wind := 0.0
	# Two passes: the first only settles the filters, so the loop's start
	# matches its end (no click at the seam).
	for j in 2 * n:
		var i := j % n
		var t := float(i) / RATE
		var s := (fmod(t * fa, 1.0) * 2.0 - 1.0) + (fmod(t * fb, 1.0) * 2.0 - 1.0) + 0.5 * (fmod(t * fc, 1.0) * 2.0 - 1.0)
		var a := 0.006 + 0.012 * (0.5 + 0.5 * sin(TAU * t / 16.0))
		lp += (s - lp) * a
		lp2 += (lp - lp2) * a
		wind += (randf_range(-1.0, 1.0) - wind) * 0.01
		if j >= n:
			out[i] = lp2 * 0.32 + wind * (0.25 + 0.15 * sin(TAU * t / 8.0))
	# Pads, two bars each: Em, C, Am, B.
	var chords := [["E3", "G3", "B3"], ["C3", "E3", "G3"], ["A2", "C3", "E3"], ["B2", "D#3", "F#3"]]
	for c in 4:
		for note_name in chords[c]:
			_add(out, voice({"wave": "saw", "f0": _note(note_name), "dur": 9.0, "attack": 2.5, "release": 3.0,
					"detune": 0.005, "lowpass": 0.02, "poles": 2, "vol": 0.12}), int(c * 8.0 * RATE))
	# Distant bells with an echo.
	var bells := [[1.5, "B4"], [5.0, "G4"], [10.5, "E5"], [14.0, "F#4"], [18.5, "D5"], [22.0, "B4"], [26.5, "C5"], [29.5, "B4"]]
	for b in bells:
		var bell := _mix([voice({"wave": "tri", "f0": _note(b[1]), "dur": 3.0, "vol": 0.09}),
				voice({"wave": "sine", "f0": _note(b[1]) * 2.76, "dur": 1.2, "vol": 0.03})])
		_add(out, bell, int(b[0] * RATE))
		var echo := bell.duplicate()
		for i in echo.size():
			echo[i] *= 0.35
		_add(out, echo, int((b[0] + 0.48) * RATE))
	# A low boom every 8 s.
	for k in 4:
		_add(out, voice({"wave": "sine", "f0": 58.0, "f1": 28.0, "dur": 2.6, "vol": 0.4}), int(k * 8.0 * RATE))
		_add(out, voice({"wave": "noise", "dur": 2.5, "lowpass": 0.02, "vol": 0.6}), int(k * 8.0 * RATE))
	return _soft_clip(out)


func _soft_clip(a: PackedFloat32Array) -> PackedFloat32Array:
	for i in a.size():
		a[i] = tanh(a[i] * 1.2)
	return a


func _save(name: String, samples: PackedFloat32Array, loop := false) -> void:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	var path := "%s/%s.wav" % [OUT, name]
	var err := wav.save_to_wav(path)
	print("  %-12s %5.2f s %s" % [name, samples.size() / float(RATE), "ok" if err == OK else "ERROR %d" % err])
