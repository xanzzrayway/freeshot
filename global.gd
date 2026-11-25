extends Node

var difficulty := 1
var start_enemies := 8
var best_wave := 0
var best_kills := 0
var sens := 1.0
var volume := 1.0
var use_active := false
var on_ground := false
var slot_count := 1
var quality := 0
var mode := 0            # 0 Battle Royale, 1 Clash Squad
var hud_custom := {}
var hud_scale := 1.0

const DIFF_NAMES := ["MUDAH", "NORMAL", "SUSAH"]
const DIFF_DMG := [4, 7, 11]
const DIFF_ACC := [0.2, 0.35, 0.5]
const ORDER := ["pistol", "smg", "rifle", "shotgun", "sniper", "lmg"]
const SCOPE_ZOOM := {0: 1.25, 1: 2.0, 2: 3.0, 3: 4.0, 4: 6.0, 8: 8.0}
const SCOPE_ORDER := [0, 1, 2, 3, 4, 8]
const VIEW := [250.0, 380.0, 550.0]
const VIEW_NAMES := ["RENDAH", "SEDANG", "TINGGI"]
const MODE_NAMES := ["BATTLE ROYALE", "CLASH SQUAD"]
const MODE_DESC := ["50 pemain, terjun dari pesawat", "4 vs 4, menang 4 ronde"]
const WEAPONS := {
	"pistol": {"name": "PISTOL", "dmg": 22, "cd": 0.22, "mag": 12, "auto": false, "pellets": 1, "spread": 0.006, "recoil": 0.02, "reload": 1.2, "price": 0, "snd": "shot_pi", "base": Vector3(0.17, -0.16, -0.34)},
	"smg": {"name": "SMG", "dmg": 16, "cd": 0.075, "mag": 35, "auto": true, "pellets": 1, "spread": 0.02, "recoil": 0.01, "reload": 1.5, "price": 300, "snd": "shot_smg", "base": Vector3(0.21, -0.2, -0.42)},
	"rifle": {"name": "RIFLE", "dmg": 25, "cd": 0.1, "mag": 30, "auto": true, "pellets": 1, "spread": 0.012, "recoil": 0.016, "reload": 1.7, "price": 600, "snd": "shot_ar", "base": Vector3(0.22, -0.22, -0.45)},
	"shotgun": {"name": "SHOTGUN", "dmg": 12, "cd": 0.9, "mag": 6, "auto": false, "pellets": 9, "spread": 0.055, "recoil": 0.09, "reload": 2.2, "price": 500, "snd": "shot_sg", "base": Vector3(0.22, -0.22, -0.45)},
	"sniper": {"name": "SNIPER", "dmg": 110, "cd": 1.2, "mag": 5, "auto": false, "pellets": 1, "spread": 0.0015, "recoil": 0.07, "reload": 2.4, "price": 1000, "snd": "shot_sn", "base": Vector3(0.22, -0.22, -0.5)},
	"lmg": {"name": "LMG", "dmg": 24, "cd": 0.085, "mag": 60, "auto": true, "pellets": 1, "spread": 0.025, "recoil": 0.012, "reload": 3.2, "price": 1100, "snd": "shot_lmg", "base": Vector3(0.22, -0.22, -0.45)},
}
# [durasi, frekuensi dentuman, peluruh dentuman, kecerahan noise, peluruh noise, retakan, ekor, peluruh ekor]
const SHOTP := {
	"shot_pi": [0.35, 140.0, 32.0, 0.6, 28.0, 0.9, 0.12, 9.0],
	"shot_smg": [0.3, 110.0, 36.0, 0.5, 30.0, 0.8, 0.1, 10.0],
	"shot_ar": [0.45, 80.0, 24.0, 0.45, 20.0, 1.0, 0.2, 7.0],
	"shot_sg": [0.7, 55.0, 12.0, 0.35, 10.0, 1.0, 0.3, 4.5],
	"shot_sn": [1.2, 45.0, 9.0, 0.3, 8.0, 1.2, 0.45, 2.8],
	"shot_lmg": [0.45, 60.0, 20.0, 0.4, 18.0, 1.0, 0.2, 7.0],
}

var _tex := {}
var _mat := {}
var _snd := {}
var _tracer_mat: StandardMaterial3D
var _logo_tex: ImageTexture
var _bg_tex: ImageTexture
var _flash_tex: ImageTexture
var _holes: Array = []
var _hole_mesh: QuadMesh
var _fxm := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load("user://save.cfg") == OK:
		best_wave = cfg.get_value("score", "wave", 0)
		best_kills = cfg.get_value("score", "kills", 0)
		difficulty = cfg.get_value("opsi", "difficulty", 1)
		sens = cfg.get_value("opsi", "sens", 1.0)
		volume = cfg.get_value("opsi", "volume", 1.0)
		quality = cfg.get_value("opsi", "quality", 0)
		mode = cfg.get_value("opsi", "mode", 0)
		hud_scale = cfg.get_value("hud", "scale", 1.0)
		for nm in HUD_NAMES:
			if cfg.has_section_key("hud", nm + "_x"):
				hud_custom[nm] = Vector2(cfg.get_value("hud", nm + "_x", 0.5), cfg.get_value("hud", nm + "_y", 0.5))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))

func _decode_img(parts: Array) -> ImageTexture:
	var raw := Marshalls.base64_to_raw("".join(PackedStringArray(parts)))
	var img := Image.new()
	if img.load_webp_from_buffer(raw) != OK:
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func logo_tex() -> ImageTexture:
	if _logo_tex == null:
		_logo_tex = _decode_img(preload("res://assets_data.gd").LOGO)
	return _logo_tex

func bg_tex() -> ImageTexture:
	if _bg_tex == null:
		_bg_tex = _decode_img(preload("res://assets_data.gd").BG)
	return _bg_tex

func view_dist() -> float:
	return VIEW[quality]

func save_all() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "wave", best_wave)
	cfg.set_value("score", "kills", best_kills)
	cfg.set_value("opsi", "difficulty", difficulty)
	cfg.set_value("opsi", "sens", sens)
	cfg.set_value("opsi", "volume", volume)
	cfg.set_value("opsi", "quality", quality)
	cfg.set_value("opsi", "mode", mode)
	cfg.set_value("hud", "scale", hud_scale)
	for nm in hud_custom:
		var v: Vector2 = hud_custom[nm]
		cfg.set_value("hud", nm + "_x", v.x)
		cfg.set_value("hud", nm + "_y", v.y)
	cfg.save("user://save.cfg")

# ---------------- TOMBOL LAYAR ----------------

const HUD_NAMES := ["fire", "reload", "scope", "heal", "use", "slots", "hp", "minimap", "ammo", "coins"]
const HUD_LABELS := {"fire": "TEMBAK", "reload": "RELOAD", "scope": "ZOOM", "heal": "MEDKIT", "use": "AMBIL / TOKO", "slots": "SLOT SENJATA", "hp": "NYAWA", "minimap": "PETA", "ammo": "PELURU", "coins": "KOIN"}

func hud_default(nm: String, s: Vector2) -> Vector2:
	match nm:
		"fire": return Vector2(s.x - 150, s.y - 150)
		"reload": return Vector2(s.x - 310, s.y - 90)
		"scope": return Vector2(s.x - 290, s.y - 215)
		"heal": return Vector2(s.x - 420, s.y - 90)
		"use": return Vector2(s.x - 150, s.y - 300)
		"slots": return Vector2(s.x * 0.5, 135.0)
		"hp": return Vector2(s.x * 0.5, s.y - 44.0)
		"minimap": return Vector2(s.x - 109.0, 155.0)
		"ammo": return Vector2(s.x - 250.0, s.y - 24.0)
		"coins": return Vector2(130.0, 52.0)
	return s / 2.0

func hud_pos(nm: String, s: Vector2) -> Vector2:
	if hud_custom.has(nm):
		var c: Vector2 = hud_custom[nm]
		return Vector2(s.x * c.x, s.y * c.y)
	return hud_default(nm, s)

func hud_half(nm: String) -> Vector2:
	var k := hud_scale
	match nm:
		"fire": return Vector2(95, 95) * k
		"reload": return Vector2(52, 52) * k
		"scope": return Vector2(55, 55) * k
		"heal": return Vector2(46, 46) * k
		"use": return Vector2(58, 58) * k
		"slots": return Vector2(126, 36) * k
		"hp": return Vector2(210, 34) * k
		"minimap": return Vector2(85, 85) * k
		"ammo": return Vector2(110, 22) * k
		"coins": return Vector2(80, 18) * k
	return Vector2(40, 40)

func btn_defs() -> Array:
	var s := get_viewport().get_visible_rect().size
	var arr: Array = []
	for nm in ["fire", "reload", "scope", "heal", "use"]:
		arr.append([nm, hud_pos(nm, s), hud_half(nm).x])
	var sp := hud_pos("slots", s)
	for i in 3:
		arr.append(["slot%d" % i, sp + Vector2((i - 1) * 90.0 * hud_scale, 0.0), 36.0 * hud_scale])
	return arr

func hit_button(p: Vector2) -> String:
	for d in btn_defs():
		var nm: String = d[0]
		var c: Vector2 = d[1]
		var r: float = d[2]
		if p.distance_to(c) >= r:
			continue
		if nm == "fire":
			return nm
		if not on_ground:
			continue
		if nm == "use" and not use_active:
			continue
		if nm.begins_with("slot") and int(nm.substr(4)) >= slot_count:
			continue
		return nm
	return ""

# ---------------- TEKSTUR (dibuat lewat kode) ----------------

func _c(r: float, g: float, b: float, k: float) -> Color:
	return Color(r * k, g * k, b * k)

func tex(tname: String) -> ImageTexture:
	if _tex.has(tname):
		return _tex[tname]
	var size := 64
	if tname in ["house_wall", "building", "road", "roof"]:
		size = 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tname)
	for y in size:
		for x in size:
			img.set_pixel(x, y, _px(tname, float(x) / size, float(y) / size, rng.randf()))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[tname] = t
	return t

func _px(tname: String, u: float, v: float, n: float) -> Color:
	match tname:
		"detail":
			var g0 := 0.8 + n * 0.25
			return Color(g0, g0, g0)
		"rock":
			var g1 := 0.45 + n * 0.25
			return Color(g1, g1 * 0.97, g1 * 0.92)
		"water":
			var w := 0.5 + 0.5 * sin(TAU * (u * 3.0 + sin(v * TAU * 2.0) * 0.3))
			return _c(0.08, 0.3, 0.5, 0.85 + 0.3 * (w * 0.6 + n * 0.4))
		"grass":
			return _c(0.28, 0.45, 0.18, 0.85 + n * 0.3)
		"road":
			var g := 0.85 + n * 0.3
			if v < 0.04 or v > 0.96:
				return _c(0.85, 0.85, 0.8, g)
			if absf(v - 0.5) < 0.025 and u < 0.5:
				return _c(0.9, 0.75, 0.1, 1.0)
			return _c(0.2, 0.2, 0.22, g)
		"house_wall":
			var base := _c(0.86, 0.8, 0.68, 0.97 + n * 0.06)
			if u > 0.3 and u < 0.7 and v > 0.28 and v < 0.72:
				if u < 0.33 or u > 0.67 or v < 0.31 or v > 0.69 or absf(u - 0.5) < 0.015 or absf(v - 0.5) < 0.015:
					return Color(0.95, 0.95, 0.95)
				return Color(0.25, 0.4, 0.55).lerp(Color(0.5, 0.65, 0.8), (u - 0.33 + v - 0.31))
			return base
		"building":
			var base2 := _c(0.55, 0.56, 0.58, 0.95 + n * 0.1)
			var inu := (u > 0.08 and u < 0.42) or (u > 0.58 and u < 0.92)
			if inu and v > 0.3 and v < 0.75:
				var edge := (u < 0.1 or (u > 0.4 and u < 0.44) or (u > 0.56 and u < 0.6) or u > 0.9 or v < 0.33 or v > 0.72)
				if edge:
					return Color(0.8, 0.8, 0.8)
				return Color(0.12, 0.2, 0.3).lerp(Color(0.35, 0.5, 0.65), v - 0.3)
			return base2
		"roof":
			var row := int(v * 8.0)
			var fx := fposmod(u * 8.0 + float(row % 2) * 0.5, 1.0)
			var fy := fposmod(v * 8.0, 1.0)
			var k := (0.85 + n * 0.2) * (1.0 - fy * 0.15)
			if fy > 0.85 or fx < 0.06:
				k *= 0.7
			return _c(0.6, 0.27, 0.17, k)
		"crate":
			var k2 := 0.9 + n * 0.2
			var frame := u < 0.08 or u > 0.92 or v < 0.08 or v > 0.92 or absf(u - v) < 0.04 or absf(u + v - 1.0) < 0.04
			if frame:
				return _c(0.4, 0.27, 0.13, k2)
			if fposmod(v * 4.0, 1.0) < 0.05:
				return _c(0.55, 0.38, 0.2, k2 * 0.6)
			return _c(0.55, 0.38, 0.2, k2)
		"concrete":
			var g2 := 0.5 * (0.9 + n * 0.2)
			if fposmod(u * 3.0 + sin(v * 9.0) * 0.3, 1.0) < 0.08:
				g2 *= 0.85
			return Color(g2, g2, g2 * 1.02)
		"cont_blue", "cont_red":
			var rib := 0.8
			if fposmod(u * 16.0, 1.0) > 0.3:
				rib = 1.0
			if v < 0.03 or v > 0.97:
				rib = 0.6
			var k3 := rib * (0.95 + n * 0.1)
			if tname == "cont_blue":
				return _c(0.15, 0.3, 0.55, k3)
			return _c(0.6, 0.15, 0.12, k3)
		"bark":
			var s := 0.7 + 0.3 * absf(sin(u * 40.0 + n * 1.5))
			return _c(0.32, 0.2, 0.1, s)
		"leaves":
			return _c(0.12, 0.35, 0.1, 0.7 + n * 0.6)
		"sandbag":
			var fy2 := fposmod(v * 4.0, 1.0)
			var fx2 := fposmod(u * 4.0 + float(int(v * 4.0) % 2) * 0.5, 1.0)
			var k4 := 0.9 + n * 0.2
			if fy2 < 0.08 or fx2 < 0.05:
				k4 *= 0.7
			return _c(0.62, 0.54, 0.36, k4)
	return Color(0.5, 0.5, 0.5)

func mat(tname: String, tile: float = 4.0) -> StandardMaterial3D:
	var key := tname + str(tile)
	if _mat.has(key):
		return _mat[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(tname)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / tile
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.roughness = 0.9
	_mat[key] = m
	return m

func flash_tex() -> ImageTexture:
	if _flash_tex:
		return _flash_tex
	var S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var dx := (float(x) + 0.5) / S - 0.5
			var dy := (float(y) + 0.5) / S - 0.5
			var r := sqrt(dx * dx + dy * dy) * 2.0
			var core := clampf(1.0 - r * 1.5, 0.0, 1.0)
			var ray_h := clampf(1.0 - absf(dy) * 14.0, 0.0, 1.0) * clampf(1.0 - absf(dx) * 2.0, 0.0, 1.0)
			var ray_v := clampf(1.0 - absf(dx) * 14.0, 0.0, 1.0) * clampf(1.0 - absf(dy) * 2.0, 0.0, 1.0)
			var a := maxf(core, maxf(ray_h, ray_v))
			img.set_pixel(x, y, Color(1.0, 0.85 + core * 0.15, 0.4 + core * 0.6, a))
	_flash_tex = ImageTexture.create_from_image(img)
	return _flash_tex

# ---------------- SUARA (dibuat lewat kode) ----------------

func snd(sname: String) -> AudioStreamWAV:
	if _snd.has(sname):
		return _snd[sname]
	var rate := 22050
	var dur := 0.4
	var is_shot := sname.begins_with("shot_")
	var bf := 80.0
	var bd := 20.0
	var lpc := 0.5
	var nd := 20.0
	var cg := 1.0
	var tg := 0.2
	var td := 7.0
	if is_shot:
		var P: Array = SHOTP[sname]
		dur = P[0]
		bf = P[1]
		bd = P[2]
		lpc = P[3]
		nd = P[4]
		cg = P[5]
		tg = P[6]
		td = P[7]
	else:
		match sname:
			"reload": dur = 0.9
			"empty": dur = 0.08
			"hit": dur = 0.07
			"hurt": dur = 0.25
			"wind": dur = 1.0
			"chute": dur = 0.5
			"step": dur = 0.12
			"heal": dur = 0.5
			"pick": dur = 0.18
			"buy": dur = 0.4
			"impact": dur = 0.1
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sname)
	var lp := 0.0
	var lp2 := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / rate
		var a := 0.0
		if is_shot:
			var raw := rng.randf_range(-1.0, 1.0)
			lp = lerpf(lp, raw, lpc)
			lp2 = lerpf(lp2, rng.randf_range(-1.0, 1.0), 0.08)
			phase += TAU * (bf * exp(-t * 18.0) + 28.0) / rate
			var boom := sin(phase) * exp(-t * bd) * 0.9
			var body := lp * exp(-t * nd)
			var crack := (raw - lp) * exp(-t * 220.0) * cg
			var tail := lp2 * tg * exp(-t * td) * clampf((t - 0.01) * 60.0, 0.0, 1.0) * 3.0
			a = (boom + body * 0.8 + crack * 0.7 + tail) * 1.1
		else:
			match sname:
				"reload":
					for c in [0.05, 0.5, 0.72]:
						var cc: float = c
						if t > cc:
							var dt: float = t - cc
							a += sin(TAU * (1300.0 + cc * 900.0) * dt) * exp(-dt * 70.0) * 0.5 + rng.randf_range(-1.0, 1.0) * exp(-dt * 150.0) * 0.35
				"empty":
					a = sin(TAU * 1100.0 * t) * exp(-t * 70.0) * 0.6 + rng.randf_range(-1.0, 1.0) * exp(-t * 200.0) * 0.3
				"hit":
					a = sin(TAU * 1500.0 * t) * exp(-t * 45.0) * 0.4
				"hurt":
					a = sin(TAU * 110.0 * t) * exp(-t * 14.0) * 0.8 + rng.randf_range(-1.0, 1.0) * exp(-t * 40.0) * 0.3
				"wind":
					lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.12)
					a = lp * 0.9
				"chute":
					lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.2)
					a = lp * exp(-t * 6.0) * (1.0 - exp(-t * 40.0))
				"step":
					lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.2)
					a = lp * exp(-t * 35.0) * 0.9
				"heal":
					a = sin(TAU * (600.0 + 900.0 * t) * t) * exp(-t * 5.0) * 0.5
				"pick":
					a = sin(TAU * (900.0 + 1500.0 * t) * t) * exp(-t * 18.0) * 0.5
				"buy":
					a = sin(TAU * 1300.0 * t) * exp(-t * 14.0) * 0.4
					if t > 0.1:
						a += sin(TAU * 1950.0 * (t - 0.1)) * exp(-(t - 0.1) * 14.0) * 0.4
				"impact":
					lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.3)
					a = lp * exp(-t * 45.0) * 0.6
		data.encode_s16(i * 2, int(clampf(a, -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	if sname == "wind":
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = n
	_snd[sname] = s
	return s

func sfx(sname: String, db: float = 0.0, pitch: float = 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = snd(sname)
	p.volume_db = db
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func sfx_3d(sname: String, pos: Vector3, db: float = 0.0, pitch: float = 1.0) -> void:
	var sc := get_tree().current_scene
	if sc == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = snd(sname)
	p.volume_db = db
	p.pitch_scale = pitch
	p.unit_size = 20.0
	p.max_distance = 400.0
	sc.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()

# ---------------- EFEK ----------------

func reset_fx() -> void:
	_holes.clear()

func tracer(a: Vector3, b: Vector3) -> void:
	var d := a.distance_to(b)
	var sc := get_tree().current_scene
	if d < 1.0 or sc == null:
		return
	if _tracer_mat == null:
		_tracer_mat = StandardMaterial3D.new()
		_tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tracer_mat.albedo_color = Color(1.0, 0.9, 0.4)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.02, 0.02, minf(d, 60.0))
	bm.material = _tracer_mat
	m.mesh = bm
	sc.add_child(m)
	var dirv := (b - a).normalized()
	m.global_position = a + dirv * minf(d, 60.0) * 0.5
	var up := Vector3.UP
	if absf(dirv.y) > 0.99:
		up = Vector3.RIGHT
	m.look_at(m.global_position + dirv, up)
	get_tree().create_timer(0.05).timeout.connect(m.queue_free)

func _fxmesh(kind: String) -> Mesh:
	if _fxm.has(kind):
		return _fxm[kind]
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh: Mesh
	match kind:
		"spark":
			mm.albedo_color = Color(1.0, 0.85, 0.4)
			var b := BoxMesh.new()
			b.size = Vector3(0.04, 0.04, 0.04)
			b.material = mm
			mesh = b
		"blood":
			mm.albedo_color = Color(0.7, 0.02, 0.02)
			var b2 := BoxMesh.new()
			b2.size = Vector3(0.05, 0.05, 0.05)
			b2.material = mm
			mesh = b2
		_:
			mm.albedo_color = Color(0.72, 0.68, 0.6, 0.5)
			mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var s := SphereMesh.new()
			s.radius = 0.12
			s.height = 0.24
			s.radial_segments = 6
			s.rings = 3
			s.material = mm
			mesh = s
	_fxm[kind] = mesh
	return mesh

func fx(pos: Vector3, kind: String, normal: Vector3 = Vector3.UP) -> void:
	var sc := get_tree().current_scene
	if sc == null:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.direction = normal
	p.spread = 55.0
	match kind:
		"spark":
			p.amount = 8
			p.lifetime = 0.3
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 6.0
			p.gravity = Vector3(0, -10, 0)
		"blood":
			p.amount = 10
			p.lifetime = 0.45
			p.initial_velocity_min = 1.5
			p.initial_velocity_max = 4.0
			p.gravity = Vector3(0, -9, 0)
		_:
			p.amount = 5
			p.lifetime = 0.6
			p.initial_velocity_min = 0.4
			p.initial_velocity_max = 1.4
			p.gravity = Vector3(0, 0.3, 0)
			p.scale_amount_min = 0.8
			p.scale_amount_max = 1.8
	p.mesh = _fxmesh(kind)
	sc.add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

func hole(pos: Vector3, normal: Vector3) -> void:
	var sc := get_tree().current_scene
	if sc == null:
		return
	if _hole_mesh == null:
		_hole_mesh = QuadMesh.new()
		_hole_mesh.size = Vector2(0.16, 0.16)
		var hm := StandardMaterial3D.new()
		hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hm.albedo_color = Color(0.05, 0.04, 0.03, 0.85)
		hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_hole_mesh.material = hm
	var m := MeshInstance3D.new()
	m.mesh = _hole_mesh
	sc.add_child(m)
	m.global_position = pos + normal * 0.02
	var up := Vector3.UP
	if absf(normal.y) > 0.99:
		up = Vector3.RIGHT
	m.look_at(m.global_position - normal, up)
	_holes.append(m)
	if _holes.size() > 40:
		var old = _holes.pop_front()
		if is_instance_valid(old):
			old.queue_free()

func make_flash() -> Node3D:
	var f := Node3D.new()
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	fm.albedo_texture = flash_tex()
	for i in 2:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.5, 0.5)
		qm.material = fm
		q.mesh = qm
		q.rotation.z = float(i) * PI / 4.0
		f.add_child(q)
	var side := MeshInstance3D.new()
	var sm := QuadMesh.new()
	sm.size = Vector2(0.14, 0.55)
	sm.material = fm
	side.mesh = sm
	side.rotation.y = PI / 2.0
	side.position.z = -0.22
	f.add_child(side)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.3)
	l.light_energy = 3.0
	l.omni_range = 10.0
	f.add_child(l)
	f.visible = false
	return f

func make_smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 6
	p.lifetime = 0.8
	p.explosiveness = 0.7
	p.direction = Vector3(0, 0.3, -1)
	p.spread = 18.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.5
	p.gravity = Vector3(0, 0.5, 0)
	p.local_coords = false
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	sm.radial_segments = 6
	sm.rings = 3
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.vertex_color_use_as_albedo = true
	mm.albedo_color = Color(0.8, 0.8, 0.8, 1.0)
	sm.material = mm
	p.mesh = sm
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.55))
	g.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = g
	var cv := Curve.new()
	cv.add_point(Vector2(0, 0.5))
	cv.add_point(Vector2(1, 3.0))
	p.scale_amount_curve = cv
	return p

func make_shell() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 1
	p.lifetime = 0.9
	p.direction = Vector3(1, 1, 0.3)
	p.spread = 20.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, -9.8, 0)
	p.local_coords = false
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.012, 0.04)
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.85, 0.65, 0.2)
	mm.metallic = 0.8
	bm.material = mm
	p.mesh = bm
	return p

# ---------------- MODEL SENJATA ----------------

func _wm(color: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	return m

func _wbox(parent: Node3D, size: Vector3, pos: Vector3, color: Color, metal: float = 0.0, rot_x: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _wm(color, metal, 0.5)
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees.x = rot_x
	parent.add_child(mi)
	return mi

func _wcyl(parent: Node3D, radius: float, length: float, pos: Vector3, color: Color, metal: float = 0.6) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = length
	cm.radial_segments = 12
	cm.rings = 1
	cm.material = _wm(color, metal, 0.4)
	mi.mesh = cm
	mi.rotation_degrees.x = 90.0
	mi.position = pos
	parent.add_child(mi)
	return mi

func build_weapon(id: String, scope_level: int = 0) -> Node3D:
	var w := Node3D.new()
	var M := Color(0.1, 0.1, 0.12)
	var WD := Color(0.35, 0.2, 0.1)
	var D := Color(0.05, 0.05, 0.05)
	var G := Color(0.22, 0.22, 0.25)
	var mz := Vector3(0, 0.01, -0.8)
	var ej := Vector3(0.04, 0.03, -0.05)
	match id:
		"pistol":
			_wbox(w, Vector3(0.045, 0.06, 0.2), Vector3(0, 0.03, -0.04), M, 0.7)
			_wbox(w, Vector3(0.04, 0.04, 0.16), Vector3(0, -0.01, 0.0), G, 0.4)
			_wbox(w, Vector3(0.04, 0.11, 0.05), Vector3(0, -0.07, 0.06), D, 0.0, 15.0)
			_wcyl(w, 0.012, 0.06, Vector3(0, 0.03, -0.16), M)
			mz = Vector3(0, 0.03, -0.2)
			ej = Vector3(0.025, 0.05, -0.04)
		"smg":
			_wbox(w, Vector3(0.06, 0.09, 0.3), Vector3(0, 0, 0), M, 0.7)
			_wcyl(w, 0.012, 0.18, Vector3(0, 0.01, -0.24), M)
			_wbox(w, Vector3(0.04, 0.2, 0.06), Vector3(0, -0.14, -0.03), D)
			_wbox(w, Vector3(0.045, 0.1, 0.05), Vector3(0, -0.09, 0.1), D)
			_wbox(w, Vector3(0.02, 0.03, 0.2), Vector3(0, 0.0, 0.24), G)
			_wbox(w, Vector3(0.02, 0.03, 0.03), Vector3(0, 0.065, -0.12), M)
			mz = Vector3(0, 0.01, -0.36)
		"rifle":
			_wbox(w, Vector3(0.07, 0.1, 0.42), Vector3(0, 0, 0), M, 0.7)
			_wbox(w, Vector3(0.062, 0.07, 0.28), Vector3(0, -0.005, -0.32), WD)
			_wbox(w, Vector3(0.06, 0.11, 0.3), Vector3(0, -0.02, 0.35), WD)
			_wbox(w, Vector3(0.05, 0.2, 0.09), Vector3(0, -0.15, -0.05), M, 0.7, -12.0)
			_wbox(w, Vector3(0.05, 0.11, 0.05), Vector3(0, -0.09, 0.12), M, 0.7)
			_wbox(w, Vector3(0.02, 0.05, 0.02), Vector3(0, 0.075, -0.55), M, 0.7)
			_wbox(w, Vector3(0.03, 0.04, 0.02), Vector3(0, 0.07, -0.12), M, 0.7)
			_wcyl(w, 0.015, 0.35, Vector3(0, 0.01, -0.62), M)
			mz = Vector3(0, 0.01, -0.82)
		"shotgun":
			_wbox(w, Vector3(0.06, 0.09, 0.36), Vector3(0, 0, 0), M, 0.7)
			_wcyl(w, 0.02, 0.6, Vector3(0, 0.015, -0.5), M)
			_wcyl(w, 0.016, 0.45, Vector3(0, -0.025, -0.43), G)
			_wbox(w, Vector3(0.07, 0.06, 0.2), Vector3(0, -0.02, -0.38), WD)
			_wbox(w, Vector3(0.06, 0.11, 0.32), Vector3(0, -0.03, 0.33), WD)
			_wbox(w, Vector3(0.045, 0.1, 0.05), Vector3(0, -0.09, 0.1), D)
			mz = Vector3(0, 0.015, -0.82)
		"sniper":
			_wbox(w, Vector3(0.06, 0.1, 0.5), Vector3(0, 0, 0.02), M, 0.7)
			_wcyl(w, 0.016, 0.75, Vector3(0, 0.01, -0.62), M)
			_wbox(w, Vector3(0.06, 0.12, 0.36), Vector3(0, -0.03, 0.42), WD)
			_wbox(w, Vector3(0.03, 0.03, 0.07), Vector3(0.05, 0.03, 0.05), G)
			_wbox(w, Vector3(0.04, 0.1, 0.06), Vector3(0, -0.09, 0.1), D)
			mz = Vector3(0, 0.01, -1.0)
		"lmg":
			_wbox(w, Vector3(0.07, 0.1, 0.45), Vector3(0, 0, 0), M, 0.7)
			_wcyl(w, 0.02, 0.55, Vector3(0, 0.015, -0.5), M)
			_wbox(w, Vector3(0.12, 0.14, 0.14), Vector3(0, -0.14, 0.0), D)
			_wbox(w, Vector3(0.06, 0.11, 0.3), Vector3(0, -0.02, 0.35), WD)
			_wbox(w, Vector3(0.02, 0.18, 0.02), Vector3(-0.04, -0.1, -0.5), G, 0.0, 20.0)
			_wbox(w, Vector3(0.02, 0.18, 0.02), Vector3(0.04, -0.1, -0.5), G, 0.0, 20.0)
			_wbox(w, Vector3(0.045, 0.1, 0.05), Vector3(0, -0.09, 0.12), D)
			mz = Vector3(0, 0.015, -0.78)
	if scope_level > 0:
		var L := 0.1 + 0.03 * float(scope_level)
		_wbox(w, Vector3(0.03, 0.05, 0.06), Vector3(0, 0.075, -0.03), M, 0.7)
		_wcyl(w, 0.026, L, Vector3(0, 0.115, -0.03), D, 0.5)
		_wcyl(w, 0.034, 0.03, Vector3(0, 0.115, -0.03 - L * 0.5), D, 0.5)
		_wcyl(w, 0.03, 0.025, Vector3(0, 0.115, -0.03 + L * 0.5), D, 0.5)
	var m := Marker3D.new()
	m.name = "Muzzle"
	m.position = mz
	w.add_child(m)
	var e := Marker3D.new()
	e.name = "Eject"
	e.position = ej
	w.add_child(e)
	return w
