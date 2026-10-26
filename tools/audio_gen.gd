extends RefCounted
## Procedural placeholder sound effects (16-bit mono AudioStreamWAV).
## Replace the generated res://audio/*.tres files with real sounds whenever you like.

const RATE: int = 22050


static func to_wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream


static func _buffer(duration: float) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(int(duration * RATE))
	return buffer


static func _saw(phase: float) -> float:
	return 2.0 * (phase - floorf(phase + 0.5))


static func shoot() -> AudioStreamWAV:
	var b := _buffer(0.12)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.45)
		b[i] = lp * exp(-t * 38.0) * 0.7 + sin(TAU * 130.0 * t) * exp(-t * 28.0) * 0.5
	return to_wav(b)


static func rocket() -> AudioStreamWAV:
	var b := _buffer(0.55)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.18)
		var env := minf(t / 0.03, 1.0) * exp(-t * 5.0)
		var freq := lerpf(320.0, 110.0, t / 0.55)
		b[i] = (lp * 0.8 + sin(TAU * freq * t) * 0.3) * env
	return to_wav(b)


static func explosion() -> AudioStreamWAV:
	var b := _buffer(1.1)
	var lp := 0.0
	var lp2 := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.09)
		lp2 = lerpf(lp2, lp, 0.3)
		b[i] = lp2 * 2.4 * exp(-t * 3.8) + sin(TAU * 48.0 * t) * exp(-t * 6.0) * 0.6
	return to_wav(b)


static func hit() -> AudioStreamWAV:
	var b := _buffer(0.09)
	for i in b.size():
		var t := float(i) / RATE
		var square := 1.0 if fmod(t * 700.0, 1.0) < 0.5 else -1.0
		b[i] = (randf_range(-1.0, 1.0) * 0.6 + square * 0.25) * exp(-t * 55.0)
	return to_wav(b)


static func pickup() -> AudioStreamWAV:
	var b := _buffer(0.16)
	for i in b.size():
		var t := float(i) / RATE
		var freq := 990.0 if t < 0.06 else 1480.0
		b[i] = sin(TAU * freq * t) * 0.45 * exp(-t * 14.0)
	return to_wav(b)


static func boost() -> AudioStreamWAV:
	var b := _buffer(0.65)
	var phase := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		phase += lerpf(180.0, 640.0, t / 0.65) / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.25)
		var env := minf(t / 0.02, 1.0) * exp(-t * 3.5)
		b[i] = (_saw(phase) * 0.35 + lp * 0.5) * env
	return to_wav(b)


static func door() -> AudioStreamWAV:
	var b := _buffer(0.7)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.04)
		var env := minf(t / 0.05, 1.0) * exp(-t * 4.0)
		b[i] = (lp * 2.5 + _saw(t * 52.0) * 0.25) * env
	return to_wav(b)


static func engine_loop() -> AudioStreamWAV:
	# Exactly 1 second with whole cycles of every frequency, so it loops seamlessly.
	var b := _buffer(1.0)
	for i in b.size():
		var t := float(i) / RATE
		var rumble := _saw(t * 42.0) * 0.45 + sin(TAU * 84.0 * t) * 0.25 + sin(TAU * 126.0 * t) * 0.12
		b[i] = rumble * (0.85 + sin(TAU * 7.0 * t) * 0.15) * 0.6
	return to_wav(b, true)


static func purchase() -> AudioStreamWAV:
	var b := _buffer(0.4)
	for i in b.size():
		var t := float(i) / RATE
		var freq := 660.0 if t < 0.12 else 990.0
		var local_t := t if t < 0.12 else t - 0.12
		b[i] = (sin(TAU * freq * t) * 0.4 + sin(TAU * freq * 2.0 * t) * 0.1) * exp(-local_t * 9.0)
	return to_wav(b)


static func error_buzz() -> AudioStreamWAV:
	var b := _buffer(0.25)
	for i in b.size():
		var t := float(i) / RATE
		var square := 1.0 if fmod(t * 140.0, 1.0) < 0.5 else -1.0
		b[i] = square * 0.25 * (1.0 - t / 0.25)
	return to_wav(b)


static func teleport() -> AudioStreamWAV:
	var b := _buffer(0.9)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		phase += lerpf(220.0, 1700.0, pow(t / 0.9, 2.0)) / RATE
		var tremolo := 0.6 + 0.4 * sin(TAU * 18.0 * t)
		b[i] = sin(TAU * phase) * 0.4 * tremolo * minf(t / 0.05, 1.0) * (1.0 - t / 0.9)
	return to_wav(b)


static func spike() -> AudioStreamWAV:
	var b := _buffer(0.3)
	for i in b.size():
		var t := float(i) / RATE
		var ring := sin(TAU * 1250.0 * t) + sin(TAU * 1730.0 * t) * 0.7 + sin(TAU * 2410.0 * t) * 0.5
		b[i] = ring * 0.18 * exp(-t * 14.0) + randf_range(-1.0, 1.0) * 0.4 * exp(-t * 90.0)
	return to_wav(b)


static func crate_break() -> AudioStreamWAV:
	var b := _buffer(0.4)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.3)
		var crackle := 1.0 if randf() < 0.08 else 0.4
		b[i] = lp * crackle * exp(-t * 11.0) * 1.2
	return to_wav(b)


static func fireball() -> AudioStreamWAV:
	var b := _buffer(0.45)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.12)
		var env := sin(PI * minf(t / 0.45, 1.0))
		b[i] = (lp * 1.4 + sin(TAU * 190.0 * t) * 0.15) * env * 0.8
	return to_wav(b)
