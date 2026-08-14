extends SceneTree
## Genera los placeholders procedurales del paisaje sonoro (GDD §11.1) en
## assets/audio/ambience/: loops perfectos (viento, lluvia, hoguera, grillos,
## pájaros, olas, drone) y salpicaduras one-shot (trueno, búho, lobo).
## Se reemplazan 1:1 por assets reales (assets-list.md).
##
## Correr (no necesita autoloads):
##   godot --path . --headless -s res://scripts/tools/gen_ambience.gd
##
## Los loops son exactamente loopeables: los LFO usan períodos que dividen la
## duración y la cola extra se funde (crossfade) sobre el arranque. Todo sale
## de RNG con semilla fija: regenerar produce bytes idénticos.

const OUT_DIR := "res://assets/audio/ambience/"
const RATE := 22050
const CROSSFADE := 0.4  # s fundidos de cola→cabeza en los loops

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_save("viento", _gen_viento(8.0), true)
	_save("lluvia", _gen_lluvia(6.0), true)
	_save("hoguera", _gen_hoguera(6.0), true)
	_save("grillos", _gen_grillos(6.0), true)
	_save("pajaros", _gen_pajaros(8.0), true)
	_save("olas", _gen_olas(10.0), true)
	_save("drone", _gen_drone(10.0), true)
	_save("trueno", _gen_trueno(), false)
	_save("buho", _gen_buho(), false)
	_save("lobo", _gen_lobo(), false)
	print("GEN_AMBIENCE=OK -> ", OUT_DIR)
	quit()


# ------------------------------------------------------------------ loops

## Viento: ruido blanco con pasabajos cuyo corte respira (2 LFO armónicos del loop).
func _gen_viento(dur: float) -> PackedFloat32Array:
	_rng.seed = 101
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n + _fade_samples())
	var lp := 0.0
	for i in buf.size():
		var phase := TAU * float(i) / float(n)
		var cutoff := 0.045 + 0.03 * sin(phase) + 0.018 * sin(3.0 * phase + 1.7)
		lp += maxf(cutoff, 0.008) * (_white() - lp)
		var swell := 0.62 + 0.28 * sin(phase + 0.6) + 0.1 * sin(2.0 * phase + 2.9)
		buf[i] = lp * swell * 2.4
	return buf


## Lluvia: siseo (blanco menos su pasabajos) + gotitas aleatorias por encima.
func _gen_lluvia(dur: float) -> PackedFloat32Array:
	_rng.seed = 202
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n + _fade_samples())
	var lp := 0.0
	for i in buf.size():
		var w := _white()
		lp += 0.12 * (w - lp)
		buf[i] = (w - lp) * 0.32
	for d in int(dur * 22.0):  # ~22 gotas/s
		var start := _rng.randi_range(0, n - 1)
		var freq := _rng.randf_range(1800.0, 5200.0)
		var amp := _rng.randf_range(0.08, 0.3)
		for j in mini(160, buf.size() - start):
			buf[start + j] += amp * exp(-float(j) * 0.06) \
				* sin(TAU * freq * float(j) / RATE)
	return buf


## Hoguera: rumor grave (ruido marrón) + crackles secos a intervalos aleatorios.
func _gen_hoguera(dur: float) -> PackedFloat32Array:
	_rng.seed = 303
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n + _fade_samples())
	var brown := 0.0
	for i in buf.size():
		brown = clampf((brown + 0.03 * _white()) * 0.997, -1.0, 1.0)
		buf[i] = brown * 1.4
	for c in int(dur * 5.5):  # ~5 crackles/s
		var start := _rng.randi_range(0, n - 1)
		var length := _rng.randi_range(120, 500)
		var amp := _rng.randf_range(0.15, 0.55)
		var decay := _rng.randf_range(0.015, 0.045)
		for j in mini(length, buf.size() - start):
			buf[start + j] += amp * exp(-float(j) * decay) * _white()
	return buf


## Grillos: dos "individuos" — portadora aguda pulsada en ráfagas rítmicas.
## Todos los períodos dividen el loop: costura inaudible.
func _gen_grillos(dur: float) -> PackedFloat32Array:
	_rng.seed = 404
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n + _fade_samples())
	# [freq portadora, Hz de pulso, período del canto s, fracción activa, amp]
	var voices := [
		[4000.0, 24.0, 0.75, 0.55, 0.30],
		[4400.0, 30.0, 1.00, 0.42, 0.22],
	]
	for i in buf.size():
		var t := float(i) / RATE
		var s := 0.0
		for v: Array in voices:
			var song_phase: float = fposmod(t, v[2]) / v[2]
			var active: float = v[3]
			if song_phase > active:
				continue
			var group := sin(PI * song_phase / active)  # envolvente de la ráfaga
			var pulse: float = maxf(sin(TAU * v[1] * t), 0.0)
			s += v[4] * group * pulse * pulse * sin(TAU * v[0] * t)
		buf[i] = s
	return buf


## Pájaros: chirps dispersos con barrido de frecuencia (semi-aleatorios, sembrados).
func _gen_pajaros(dur: float) -> PackedFloat32Array:
	_rng.seed = 505
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n + _fade_samples())
	for c in 9:
		var start := _rng.randi_range(0, n - 1)
		var notes := _rng.randi_range(1, 3)  # trinos de 1 a 3 notas
		for note in notes:
			var note_start := start + note * _rng.randi_range(2500, 4500)
			var length := _rng.randi_range(int(0.06 * RATE), int(0.18 * RATE))
			var f0 := _rng.randf_range(2200.0, 4200.0)
			var f1 := f0 * _rng.randf_range(0.75, 1.35)
			var amp := _rng.randf_range(0.14, 0.3)
			var phase := 0.0
			for j in mini(length, buf.size() - note_start):
				var k := float(j) / float(length)
				phase += TAU * lerpf(f0, f1, k) / RATE
				var env := sin(PI * k)
				buf[note_start + j] += amp * env * env * sin(phase)
	return buf


## Olas: ruido muy filtrado con envolvente de respiración lenta (rompiente).
func _gen_olas(dur: float) -> PackedFloat32Array:
	_rng.seed = 606
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n + _fade_samples())
	var lp := 0.0
	var lp2 := 0.0
	for i in buf.size():
		var phase := TAU * float(i) / float(n)
		lp += 0.06 * (_white() - lp)
		lp2 += 0.015 * (lp - lp2)
		var breath := pow(0.5 + 0.5 * sin(phase - PI * 0.5), 1.8)
		var breath2 := 0.25 * pow(0.5 + 0.5 * sin(2.0 * phase + 1.2), 2.0)
		buf[i] = (lp * 0.7 + lp2 * 1.6) * (0.18 + breath + breath2) * 2.0
	return buf


## Drone: cluster grave con batido lento (bruma roja). Frecuencias con ciclos
## enteros en el loop; el par 55/55.2 Hz late a 0.2 Hz.
func _gen_drone(dur: float) -> PackedFloat32Array:
	_rng.seed = 707
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n + _fade_samples())
	var lp := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		var s := 0.30 * sin(TAU * 55.0 * t) + 0.30 * sin(TAU * 55.2 * t) \
			+ 0.18 * sin(TAU * 82.5 * t) + 0.12 * sin(TAU * 110.0 * t)
		lp += 0.02 * (_white() - lp)
		buf[i] = tanh(s + lp * 0.5)
	return buf


# ------------------------------------------------------------------ salpicaduras

## Trueno: crack inicial + retumbe grave que se apaga y se oscurece.
func _gen_trueno() -> PackedFloat32Array:
	_rng.seed = 808
	var n := int(4.0 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var brown := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		brown = clampf((brown + 0.05 * _white()) * 0.996, -1.0, 1.0)
		var cutoff := lerpf(0.3, 0.025, minf(t / 2.5, 1.0))
		lp += cutoff * (brown * 2.2 - lp)
		var rumble := lp * exp(-t * 0.85) * (1.0 + 0.35 * sin(TAU * 1.7 * t))
		var crack := _white() * exp(-t * 38.0) * 0.9
		buf[i] = (rumble + crack) * minf(t * 60.0, 1.0)  # ataque de ~16 ms
	_fade_out(buf, 0.3)
	return buf


## Búho: dos "hu-huú" con vibrato, el segundo más grave y largo.
func _gen_buho() -> PackedFloat32Array:
	_rng.seed = 909
	var n := int(2.2 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	# [inicio s, duración s, freq inicial, freq final]
	for note: Array in [[0.1, 0.35, 335.0, 305.0], [0.75, 0.95, 315.0, 275.0]]:
		var start := int(note[0] * RATE)
		var length := int(note[1] * RATE)
		var phase := 0.0
		for j in mini(length, n - start):
			var k := float(j) / float(length)
			var f: float = lerpf(note[2], note[3], k) \
				* (1.0 + 0.02 * sin(TAU * 5.0 * float(j) / RATE))
			phase += TAU * f / RATE
			var env := pow(sin(PI * k), 0.7)
			buf[start + j] += env * (sin(phase) + 0.3 * sin(2.0 * phase)) * 0.5
	return buf


## Lobo lejano: aullido con glide subida→meseta con vibrato→caída, más aliento.
func _gen_lobo() -> PackedFloat32Array:
	_rng.seed = 1010
	var n := int(3.0 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 0.0
		if t < 0.8:
			f = lerpf(250.0, 430.0, smoothstep(0.0, 1.0, t / 0.8))
		elif t < 2.3:
			f = 430.0 * (1.0 + 0.02 * sin(TAU * 4.0 * t))
		else:
			f = lerpf(430.0, 320.0, (t - 2.3) / 0.7)
		phase += TAU * f / RATE
		var env := minf(t / 0.5, 1.0) * minf((3.0 - t) / 0.6, 1.0)
		lp += 0.04 * (_white() - lp)
		buf[i] = env * (sin(phase) + 0.4 * sin(2.0 * phase) \
			+ 0.15 * sin(3.0 * phase) + lp * 0.6) * 0.42
	return buf


# ------------------------------------------------------------------ plomería

func _white() -> float:
	return _rng.randf_range(-1.0, 1.0)


func _fade_samples() -> int:
	return int(CROSSFADE * RATE)


## Cola extra fundida sobre la cabeza → el loop cierra sin click.
func _loop_blend(buf: PackedFloat32Array) -> PackedFloat32Array:
	var fade := _fade_samples()
	var n := buf.size() - fade
	var out := buf.slice(0, n)
	for i in fade:
		var t := float(i) / float(fade)
		out[i] = out[i] * t + buf[n + i] * (1.0 - t)
	return out


func _fade_out(buf: PackedFloat32Array, seconds: float) -> void:
	var fade := mini(int(seconds * RATE), buf.size())
	for i in fade:
		buf[buf.size() - fade + i] *= 1.0 - float(i) / float(fade)


func _save(sound_name: String, buf: PackedFloat32Array, is_loop: bool) -> void:
	if is_loop:
		buf = _loop_blend(buf)
	var peak := 0.0
	for s in buf:
		peak = maxf(peak, absf(s))
	var gain := (0.82 if is_loop else 0.9) / maxf(peak, 0.001)
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	var path := OUT_DIR + sound_name + ".wav"
	var err := wav.save_to_wav(path)
	print("%s -> %s (%.1f s, %s)" % [error_string(err), path,
		buf.size() / float(RATE), "loop" if is_loop else "one-shot"])
