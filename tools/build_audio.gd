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
	_save("fight", _mix([
		voice({"wave": "square", "f0": 990.0, "dur": 0.35, "vol": 0.22}),
		voice({"wave": "square", "f0": 1320.0, "dur": 0.35, "vol": 0.15, "delay": 0.04}),
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
## = darker), lowpass_end, crackle (0-1: random dropouts), delay.
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
	var phase := 0.0
	var lp := 0.0
	var hold := 1.0
	var start := int(delay * RATE)
	for i in range(start, n):
		var t := float(i - start) / RATE
		var k := t / dur
		var f := f0 * pow(f1 / f0, k)
		if vib > 0.0:
			f *= 1.0 + vib_depth * sin(TAU * vib * t)
		phase = fmod(phase + f / RATE, 1.0)
		var s := 0.0
		match wave:
			"square":
				s = 1.0 if phase < duty else -1.0
			"saw":
				s = phase * 2.0 - 1.0
			"tri":
				s = 1.0 - 4.0 * absf(phase - 0.5)
			"sine":
				s = sin(TAU * phase)
			"noise":
				s = randf_range(-1.0, 1.0)
		if crackle > 0.0:
			if randf() < 0.004:
				hold = 0.0 if randf() < crackle else 1.0
			s *= hold
		var a := lerpf(lp0, lp1, k)
		lp += (s - lp) * a
		s = lp
		var env := minf(t / attack, 1.0) * pow(1.0 - k, 1.6)
		out[i] = s * env * vol
	return out


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


## ~17 s fight loop, 112 BPM, A minor: Am F C G (2 bars each).
## Triangle bass in eighths, square lead, kick / snare / hats from noise+sine.
func _music_fight() -> PackedFloat32Array:
	var bpm := 112.0
	var beat := 60.0 / bpm
	var bars := 8
	var n := int(bars * 4 * beat * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var roots := ["A2", "A2", "F2", "F2", "C3", "C3", "G2", "G2"]
	var lead := [
		["A4", "C5", "E5", "D5", "C5", "B4", "C5", "E5"], ["A4", "-", "E4", "A4", "B4", "C5", "B4", "-"],
		["F4", "A4", "C5", "A4", "D5", "C5", "A4", "-"], ["F4", "-", "C5", "-", "A4", "G4", "A4", "C5"],
		["E4", "G4", "C5", "E5", "D5", "C5", "G4", "-"], ["C5", "-", "E5", "-", "G5", "E5", "C5", "-"],
		["D5", "B4", "G4", "B4", "D5", "-", "B4", "D5"], ["E5", "D5", "B4", "G4", "B4", "-", "E5", "-"],
	]
	var eighth := beat / 2.0
	for bar in bars:
		var bar_t := bar * 4 * beat
		var root := _note(roots[bar])
		for e in 8:
			var t := bar_t + e * eighth
			var at := int(t * RATE)
			# Bass: root, octave on the off-beats.
			var f := root * (2.0 if e % 2 == 1 else 1.0)
			_add(out, voice({"wave": "tri", "f0": f, "dur": eighth * 0.95, "vol": 0.32}), at)
			# Lead.
			var name: String = lead[bar][e]
			if name != "-":
				_add(out, voice({"wave": "square", "f0": _note(name), "dur": eighth * 0.9, "vol": 0.09,
						"duty": 0.25, "vib": 6.0, "vib_depth": 0.004}), at)
			# Drums: kick on 1 and 3, snare on 2 and 4, hats on every eighth.
			if e == 0 or e == 4:
				_add(out, voice({"wave": "sine", "f0": 130.0, "f1": 40.0, "dur": 0.16, "vol": 0.55}), at)
			if e == 2 or e == 6:
				_add(out, voice({"wave": "noise", "dur": 0.14, "lowpass": 0.5, "vol": 0.22}), at)
			_add(out, voice({"wave": "noise", "dur": 0.03, "lowpass": 0.95, "vol": 0.06}), at)
	return _soft_clip(out)


## ~21 s calm title loop, 90 BPM: slow arpeggios over Am F C E.
func _music_title() -> PackedFloat32Array:
	var bpm := 90.0
	var beat := 60.0 / bpm
	var bars := 8
	var n := int(bars * 4 * beat * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var chords := [["A3", "C4", "E4"], ["A3", "C4", "E4"], ["F3", "A3", "C4"], ["F3", "A3", "C4"],
			["C4", "E4", "G4"], ["C4", "E4", "G4"], ["E3", "G#3", "B3"], ["E3", "G#3", "B3"]]
	var eighth := beat / 2.0
	for bar in bars:
		var notes: Array = chords[bar]
		var bar_t := bar * 4 * beat
		_add(out, voice({"wave": "tri", "f0": _note(notes[0]) / 2.0, "dur": 4 * beat * 0.98, "attack": 0.2, "vol": 0.25}), int(bar_t * RATE))
		var pattern := [0, 1, 2, 1, 0, 2, 1, 2]
		for e in 8:
			var f := _note(notes[pattern[e]]) * (2.0 if e >= 4 else 1.0)
			_add(out, voice({"wave": "square", "f0": f, "dur": eighth * 1.8, "attack": 0.01, "vol": 0.06, "duty": 0.125}),
					int((bar_t + e * eighth) * RATE))
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
