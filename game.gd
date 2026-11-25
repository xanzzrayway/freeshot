extends Node3D

const SIZE := 1024.0
const N := 128
const CELL := 8.0
const HALF := 512.0
const CH := 16
const TOTAL := 50
const SHOP_ITEMS := [
	["SMG", 300, "weapon", "smg"],
	["RIFLE", 600, "weapon", "rifle"],
	["SHOTGUN", 500, "weapon", "shotgun"],
	["SNIPER", 1000, "weapon", "sniper"],
	["LMG", 1100, "weapon", "lmg"],
	["ARMOR LV1", 250, "armor", 1],
	["ARMOR LV2", 500, "armor", 2],
	["ARMOR LV3", 850, "armor", 3],
	["SCOPE LV1 (2x)", 150, "scope", 1],
	["SCOPE LV2 (3x)", 300, "scope", 2],
	["SCOPE LV3 (4x)", 500, "scope", 3],
	["SCOPE LV4 (6x)", 800, "scope", 4],
	["SCOPE LV8 (8x)", 1500, "scope", 8],
	["MEDKIT", 150, "medkit", 1],
	["MEDKIT x3", 400, "medkit", 3],
]
const HUB_CLEAR := {"village": 12.0, "city": 14.0, "base": 12.0, "factory": 32.0, "nuclear": 45.0, "fuel": 28.0, "tower": 6.0}

var noise: FastNoiseLite
var coast: FastNoiseLite
var mnoise: FastNoiseLite
var coast_ph := 0.0
var heights := PackedFloat32Array()
var player: CharacterBody3D
var hud: Control
var loading: Control
var plane: Node3D
var plane_vel := Vector3(42, 0, 0)
var started := false
var cs := false
var round_no := 0
var score_ally := 0
var score_enemy := 0
var freeze := false
var round_over := false
var spawn_a := Vector2.ZERO
var spawn_b := Vector2.ZERO
const ZONE_APPEAR := 180.0
const ZONE_RADII := [520.0, 350.0, 230.0, 140.0, 70.0, 15.0]
const ZONE_WAIT := [40.0, 35.0, 30.0, 25.0, 20.0]
const ZONE_SHRINK := [35.0, 30.0, 25.0, 20.0, 20.0]
const ZONE_DPS := [2.0, 4.0, 7.0, 11.0, 16.0]
var zone_appear := ZONE_APPEAR
var match_time := 0.0
var zone_active := false
var zone_stage := 0
var zone_phase := ""
var zone_t := 0.0
var zone_dur := 1.0
var zone_center := Vector2.ZERO
var zone_radius := 520.0
var zone_from_c := Vector2.ZERO
var zone_from_r := 520.0
var zone_next_c := Vector2.ZERO
var zone_next_r := 350.0
var zone_wall: MeshInstance3D
var zone_out_t := 0.0
var zone_tick := 1.0
var zone_dps_now := 0.0
var zone_outside := false
var total := TOTAL
var kills := 0
var enemies_alive := 0
var over := false
var obstacles: Array = []
var road_pts: Array = []
var shops: Array = []
var loots: Array = []
var hubs: Array = []
var hub_kinds: Array = []
var hub_r: Array = []
var water_mat: StandardMaterial3D
var road_mat: StandardMaterial3D
var floor_wood: StandardMaterial3D
var near_loot: Node3D
var shop_layer: CanvasLayer
var coin_label: Label
var shop_msg: Label

func _ready() -> void:
	randomize()
	Global.reset_fx()
	cs = Global.mode == 1
	total = 4 if cs else TOTAL
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.0045
	noise.fractal_octaves = 4
	coast = FastNoiseLite.new()
	coast.seed = randi()
	coast.frequency = 0.01
	mnoise = FastNoiseLite.new()
	mnoise.seed = randi()
	mnoise.frequency = 0.007
	coast_ph = randf() * TAU
	floor_wood = _cm(Color(0.45, 0.32, 0.2))
	loading = preload("res://loading.gd").new()
	var ll := CanvasLayer.new()
	ll.layer = 50
	ll.add_child(loading)
	add_child(ll)
	await _stage("Menyiapkan tekstur dan suara", 0.02)
	await _warmup()
	await _stage("Membentuk pulau", 0.25)
	_gen_heights()
	_build_env()
	_build_water()
	await _stage("Merencanakan kota dan struktur", 0.35)
	_pick_hubs()
	_make_roads()
	await _stage("Membuat daratan", 0.5)
	_build_terrain()
	await _stage("Mendirikan bangunan", 0.6)
	_build_structures()
	await _stage("Menanam pohon", 0.8)
	_make_forest()
	_make_rocks()
	await _stage("Menyebar loot", 0.9)
	_scatter_loot()
	var mt := _make_minimap()
	var start_pos := Vector3.ZERO
	if cs:
		_setup_cs()
		start_pos = Vector3(spawn_a.x, ground_y(spawn_a.x, spawn_a.y) + 1.1, spawn_a.y)
	else:
		_build_plane()
		start_pos = plane.position
	player = preload("res://player.gd").new()
	player.limit = HALF - 15.0
	player.position = start_pos
	if not cs:
		player.plane_vel = plane_vel
		player.rotation.y = -PI / 2.0
	player.died.connect(_on_died)
	player.landed.connect(_on_landed)
	player.interact.connect(_on_interact)
	add_child(player)
	player.set_process_input(false)
	var layer := CanvasLayer.new()
	hud = preload("res://hud.gd").new()
	hud.player = player
	hud.game = self
	hud.map_tex = mt
	hud.map_half = HALF
	layer.add_child(hud)
	add_child(layer)
	await _stage("Menyiapkan pasukan", 0.97)
	if not cs:
		_spawn_bots()
	await _matchmaking()
	ll.queue_free()
	player.set_process_input(true)
	started = true
	if cs:
		player.start_on_ground()
		_start_round()
	else:
		hud.banner("LOMPAT DARI PESAWAT!")

func _stage(text: String, p: float) -> void:
	loading.sub = text
	loading.progress = p
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _warmup() -> void:
	var names := ["detail", "water", "road", "house_wall", "building", "roof", "concrete", "crate", "cont_blue", "cont_red", "bark", "leaves", "sandbag", "rock"]
	for i in names.size():
		Global.tex(names[i])
		loading.progress = 0.02 + 0.2 * float(i) / names.size()
		await get_tree().process_frame
	var sounds := ["shot_pi", "shot_smg", "shot_ar", "shot_sg", "shot_sn", "shot_lmg", "reload", "hit", "hurt", "step", "wind", "heal", "pick", "buy", "empty", "chute", "impact"]
	for s in sounds:
		Global.snd(s)
		await get_tree().process_frame

func _matchmaking() -> void:
	var mt := 8 if cs else TOTAL
	loading.count = 0
	loading.total = mt
	loading.sub = "Menunggu Pemain" if cs else "Menunggu Musuh"
	while loading.count < mt:
		var dl := randf_range(0.3, 0.6) if cs else randf_range(0.12, 0.32)
		await get_tree().create_timer(dl).timeout
		var inc := 1 if cs else randi_range(1, 3)
		loading.count = mini(mt, loading.count + inc)
	loading.sub = "Match ditemukan!"
	await get_tree().create_timer(1.0).timeout

func _process(delta: float) -> void:
	if water_mat:
		water_mat.uv1_offset.x += delta * 0.01
	if not started:
		return
	var pp := player.global_position
	for l in loots:
		if is_instance_valid(l) and l.global_position.distance_squared_to(pp) < 6400.0:
			l.get_child(0).rotation.y += delta * 1.5

func _physics_process(delta: float) -> void:
	if not started:
		return
	if not cs and not over:
		match_time += delta
		_zone_process(delta)
	if is_instance_valid(plane):
		plane.position += plane_vel * delta
		if player.state == 0:
			player.global_position = plane.position + Vector3(0, 0.3, 0)
			if plane.position.x > HALF - 70.0:
				player.jump()
		elif plane.position.x > HALF + 250.0:
			plane.queue_free()
	if player.state == 3 and not over:
		var pp := player.global_position
		var kind := ""
		var nm := ""
		for s in shops:
			var sd := pp.distance_to(s.global_position)
			s.get_meta("light").visible = sd < 60.0
			if sd < 4.0 and kind == "":
				kind = "shop"
				nm = "TOKO"
		if kind == "":
			var best := 2.6
			near_loot = null
			for l in loots:
				var d := pp.distance_to(l.global_position)
				if d < best:
					best = d
					near_loot = l
					kind = "loot"
					nm = l.get_meta("name")
		if cs and freeze:
			kind = "shop"
			nm = "TOKO"
		player.interact_kind = kind
		player.interact_name = nm
		Global.use_active = kind != ""
	else:
		Global.use_active = false
		player.interact_kind = ""

# ---------------- TERRAIN PULAU ----------------

func _hgt(x: float, z: float) -> float:
	var d := sqrt(x * x + z * z)
	var ang := atan2(z, x)
	var r0 := 320.0 + coast.get_noise_2d(cos(ang) * 250.0, sin(ang) * 250.0) * 110.0 + sin(ang * 3.0 + coast_ph) * 30.0
	var m := (r0 - d) / 90.0
	if m <= 0.0:
		return maxf(m * 8.0, -8.0)
	var mm := minf(m, 1.0)
	var s := mm * mm * (3.0 - 2.0 * mm)
	var hills := (noise.get_noise_2d(x, z) * 0.5 + 0.5) * 26.0
	var ridge := maxf(0.0, mnoise.get_noise_2d(x, z))
	ridge = ridge * ridge * 90.0
	return mm * 2.5 + (hills + ridge) * s

func _gen_heights() -> void:
	var W := N + 1
	heights.resize(W * W)
	for zi in W:
		for xi in W:
			heights[zi * W + xi] = _hgt((xi - N / 2) * CELL, (zi - N / 2) * CELL)

func ground_y(x: float, z: float) -> float:
	var W := N + 1
	var fx := x / CELL + N * 0.5
	var fz := z / CELL + N * 0.5
	var xi := clampi(int(floor(fx)), 0, N - 1)
	var zi := clampi(int(floor(fz)), 0, N - 1)
	var tx := clampf(fx - xi, 0.0, 1.0)
	var tz := clampf(fz - zi, 0.0, 1.0)
	var h00 := heights[zi * W + xi]
	var h10 := heights[zi * W + xi + 1]
	var h01 := heights[(zi + 1) * W + xi]
	var h11 := heights[(zi + 1) * W + xi + 1]
	if tx + tz <= 1.0:
		return h00 + tx * (h10 - h00) + tz * (h01 - h00)
	return h11 + (1.0 - tx) * (h01 - h11) + (1.0 - tz) * (h10 - h11)

func _slope(x: float, z: float) -> float:
	var h0 := ground_y(x, z)
	var d := maxf(maxf(absf(ground_y(x + 8.0, z) - h0), absf(ground_y(x - 8.0, z) - h0)), maxf(absf(ground_y(x, z + 8.0) - h0), absf(ground_y(x, z - 8.0) - h0)))
	return d / 8.0

func _flatten(c: Vector2, hard: float, blend: float, level: float) -> void:
	var W := N + 1
	var rad := hard + blend
	var x0 := maxi(int(floor((c.x - rad) / CELL + N * 0.5)), 0)
	var x1 := mini(int(ceil((c.x + rad) / CELL + N * 0.5)), N)
	var z0 := maxi(int(floor((c.y - rad) / CELL + N * 0.5)), 0)
	var z1 := mini(int(ceil((c.y + rad) / CELL + N * 0.5)), N)
	for zi in range(z0, z1 + 1):
		for xi in range(x0, x1 + 1):
			var x := (xi - N / 2) * CELL
			var z := (zi - N / 2) * CELL
			var d := Vector2(x, z).distance_to(c)
			if d >= rad:
				continue
			var t := 1.0
			if d > hard:
				t = 1.0 - smoothstep(hard, rad, d)
			heights[zi * W + xi] = lerpf(heights[zi * W + xi], level, t)

func _vcol(xi: int, zi: int, h: float) -> Color:
	var W := N + 1
	var xm := heights[zi * W + maxi(xi - 1, 0)]
	var xp := heights[zi * W + mini(xi + 1, N)]
	var zm := heights[maxi(zi - 1, 0) * W + xi]
	var zp := heights[mini(zi + 1, N) * W + xi]
	var slope := sqrt((xp - xm) * (xp - xm) + (zp - zm) * (zp - zm)) / (2.0 * CELL)
	var x := (xi - N / 2) * CELL
	var z := (zi - N / 2) * CELL
	var t := noise.get_noise_2d(x * 3.0, z * 3.0) * 0.5
	var grass := Color(0.3 + t * 0.12, 0.5 + t * 0.14, 0.2 + t * 0.05)
	var sand := Color(0.86, 0.78, 0.55)
	var col := grass.lerp(sand, clampf((2.4 - h) / 1.2, 0.0, 1.0))
	if h < -0.2:
		col = Color(0.5, 0.45, 0.32)
	col = col.lerp(Color(0.5, 0.48, 0.45), clampf((slope - 0.35) / 0.3, 0.0, 1.0))
	col = col.lerp(Color(0.5, 0.48, 0.45), clampf((h - 26.0) / 12.0, 0.0, 1.0))
	col = col.lerp(Color(0.93, 0.95, 0.97), clampf((h - 52.0) / 8.0, 0.0, 1.0))
	return col

func _vnorm(xi: int, zi: int) -> Vector3:
	var W := N + 1
	var hl := heights[zi * W + maxi(xi - 1, 0)]
	var hr := heights[zi * W + mini(xi + 1, N)]
	var hu := heights[maxi(zi - 1, 0) * W + xi]
	var hd := heights[mini(zi + 1, N) * W + xi]
	return Vector3(hl - hr, 2.0 * CELL, hu - hd).normalized()

func _build_terrain() -> void:
	var tm := StandardMaterial3D.new()
	tm.vertex_color_use_as_albedo = true
	tm.vertex_color_is_srgb = true
	tm.albedo_texture = Global.tex("detail")
	tm.uv1_triplanar = true
	tm.uv1_world_triplanar = true
	tm.uv1_scale = Vector3.ONE / 5.0
	tm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tm.roughness = 1.0
	for cz in range(0, N, CH):
		for cx in range(0, N, CH):
			_terrain_chunk(cx, cz, tm)

func _terrain_chunk(cx: int, cz: int, tm: Material) -> void:
	var W := N + 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zi in range(cz, cz + CH + 1):
		for xi in range(cx, cx + CH + 1):
			var h := heights[zi * W + xi]
			st.set_color(_vcol(xi, zi, h))
			st.set_normal(_vnorm(xi, zi))
			st.add_vertex(Vector3((xi - N / 2) * CELL, h, (zi - N / 2) * CELL))
	var row := CH + 1
	for lz in CH:
		for lx in CH:
			var i00 := lz * row + lx
			var i10 := i00 + 1
			var i01 := i00 + row
			var i11 := i01 + 1
			st.add_index(i00)
			st.add_index(i10)
			st.add_index(i01)
			st.add_index(i10)
			st.add_index(i11)
			st.add_index(i01)
	var mesh := st.commit()
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = tm
	body.add_child(mi)
	add_child(body)

func _build_water() -> void:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000, 6000)
	water_mat = StandardMaterial3D.new()
	water_mat.albedo_texture = Global.tex("water")
	water_mat.uv1_scale = Vector3(300, 300, 1)
	water_mat.roughness = 0.2
	water_mat.metallic = 0.25
	pm.material = water_mat
	m.mesh = pm
	add_child(m)

func _make_minimap() -> ImageTexture:
	var S := 128
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	for py in S:
		for px in S:
			var x := ((px + 0.5) / S - 0.5) * SIZE
			var z := ((py + 0.5) / S - 0.5) * SIZE
			var h := ground_y(x, z)
			var c: Color
			if h < -0.3:
				c = Color(0.1, 0.28, 0.5)
			elif h < 0.4:
				c = Color(0.2, 0.45, 0.65)
			elif h < 2.2:
				c = Color(0.85, 0.78, 0.55)
			elif h < 28.0:
				c = Color(0.3, 0.55, 0.25)
			elif h < 45.0:
				c = Color(0.5, 0.48, 0.45)
			else:
				c = Color(0.95, 0.95, 0.97)
			img.set_pixel(px, py, c)
	return ImageTexture.create_from_image(img)

func _build_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var skym := ProceduralSkyMaterial.new()
	skym.sky_top_color = Color(0.22, 0.42, 0.82)
	skym.sky_horizon_color = Color(0.68, 0.8, 0.92)
	skym.ground_horizon_color = Color(0.3, 0.5, 0.65)
	skym.ground_bottom_color = Color(0.2, 0.4, 0.55)
	var sky := Sky.new()
	sky.sky_material = skym
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.fog_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)

# ---------------- UTIL BANGUNAN ----------------

func _cm(color: Color, glow: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.2
	return m

func _vr() -> float:
	return Global.view_dist() + 30.0

func _boxc(parent: Node3D, size: Vector3, pos: Vector3, material: Material, collide: bool = true) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = material
	m.mesh = bm
	m.position = pos
	m.visibility_range_end = _vr()
	parent.add_child(m)
	if collide:
		var c := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = size
		c.shape = s
		c.position = pos
		parent.add_child(c)
	return m

func _solid(size: Vector3, pos: Vector3, rot: float, material: Material) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos
	b.rotation.y = rot
	_boxc(b, size, Vector3.ZERO, material)
	add_child(b)
	return b

func _part(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	return _boxc(parent, size, pos, material, false)

func _cyl(pos: Vector3, r_top: float, r_bot: float, h: float, material: Material, seg: int = 16) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos + Vector3(0, h / 2.0, 0)
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	cm.material = material
	m.mesh = cm
	m.visibility_range_end = _vr()
	b.add_child(m)
	var c := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = maxf(r_top, r_bot) * 0.92
	s.height = h
	c.shape = s
	b.add_child(c)
	add_child(b)
	return b

func _wp(c: Vector2, rot: float, local: Vector3, fy: float) -> Vector3:
	return Vector3(c.x, fy, c.y) + local.rotated(Vector3.UP, rot)

func _label3d(pos: Vector3, text: String, color: Color, vr: float) -> void:
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = 96
	lab.pixel_size = 0.02
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = color
	lab.outline_size = 14
	lab.position = pos
	lab.visibility_range_end = vr
	add_child(lab)

func _steam(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = 14
	p.lifetime = 7.0
	p.direction = Vector3(0, 1, 0)
	p.spread = 12.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0.6, 0.2, 0)
	p.local_coords = false
	p.scale_amount_min = 4.0
	p.scale_amount_max = 9.0
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.vertex_color_use_as_albedo = true
	mm.albedo_color = Color(1, 1, 1, 1)
	sm.material = mm
	p.mesh = sm
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.45))
	g.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = g
	p.visibility_range_end = 450.0
	add_child(p)

func _wseg(b: Node3D, material: Material, along_x: bool, a0: float, a1: float, y0: float, y1: float, t: float, perp: float) -> void:
	if a1 - a0 < 0.01 or y1 - y0 < 0.01:
		return
	var seg := a1 - a0
	var hgt := y1 - y0
	var center := (a0 + a1) / 2.0
	var size := Vector3(seg, hgt, t) if along_x else Vector3(t, hgt, seg)
	var pos := Vector3(center, y0 + hgt / 2.0, perp) if along_x else Vector3(perp, y0 + hgt / 2.0, center)
	_boxc(b, size, pos, material, true)

func _wall(b: Node3D, material: Material, along_x: bool, length: float, H: float, t: float, perp: float, gaps: Array) -> void:
	var gs := gaps.duplicate()
	gs.sort_custom(func(p, q): return p[0] < q[0])
	var cursor := -length / 2.0
	for g in gs:
		var g0: float = float(g[0]) - float(g[1]) / 2.0
		var g1: float = float(g[0]) + float(g[1]) / 2.0
		if g0 > cursor:
			_wseg(b, material, along_x, cursor, g0, 0.0, H, t, perp)
		_wseg(b, material, along_x, g0, g1, float(g[2]), H, t, perp)
		cursor = g1
	if cursor < length / 2.0:
		_wseg(b, material, along_x, cursor, length / 2.0, 0.0, H, t, perp)

# bangunan berongga: dinding + pintu, lantai, plafon
func _hall(c: Vector2, rot: float, fy: float, w: float, d: float, H: float, wall_mat: Material, floor_mat: Material, gf: Array, gb: Array, gs: Array) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = Vector3(c.x, fy, c.y)
	b.rotation.y = rot
	var t := 0.4
	_boxc(b, Vector3(w, 3.0, d), Vector3(0, -1.48, 0), floor_mat)
	_wall(b, wall_mat, true, w, H, t, d / 2.0 - t / 2.0, gf)
	_wall(b, wall_mat, true, w, H, t, -d / 2.0 + t / 2.0, gb)
	_wall(b, wall_mat, false, d, H, t, w / 2.0 - t / 2.0, gs)
	_wall(b, wall_mat, false, d, H, t, -w / 2.0 + t / 2.0, gs)
	_boxc(b, Vector3(w, 0.3, d), Vector3(0, H + 0.15, 0), wall_mat)
	add_child(b)
	return b

func _beam(parent: Node3D, color: Color, height: float) -> void:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.08
	cm.bottom_radius = 0.08
	cm.height = height
	cm.radial_segments = 8
	cm.rings = 1
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color = Color(color.r, color.g, color.b, 0.35)
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	cm.material = bm
	m.mesh = cm
	m.visibility_range_end = minf(_vr(), 220.0)
	m.position.y = height / 2.0
	parent.add_child(m)

func _base_y(p: Vector2, r: float) -> float:
	var h := ground_y(p.x, p.y)
	for k in 8:
		var a := float(k) * TAU / 8.0
		h = maxf(h, ground_y(p.x + cos(a) * r, p.y + sin(a) * r))
	return h

func _road_dist(p: Vector2) -> float:
	var best := 1e9
	for q in road_pts:
		var d := p.distance_squared_to(q)
		if d < best:
			best = d
	return sqrt(best)

func _can_build(p: Vector2, radius: float) -> bool:
	var h := ground_y(p.x, p.y)
	if h < 2.0 or h > 40.0:
		return false
	if _slope(p.x, p.y) > 0.3:
		return false
	if _road_dist(p) < radius * 0.5 + 5.0:
		return false
	for o in obstacles:
		if p.distance_to(o[0]) < o[1] + radius * 0.6:
			return false
	return true

func _find_site(r_new: float, min_h: float, max_h: float, slope_max: float) -> Vector2:
	for i in 300:
		var x := randf_range(-HALF * 0.8, HALF * 0.8)
		var z := randf_range(-HALF * 0.8, HALF * 0.8)
		var h := ground_y(x, z)
		if h < min_h or h > max_h:
			continue
		if _slope(x, z) > slope_max:
			continue
		var p := Vector2(x, z)
		var ok := true
		for k in hubs.size():
			if p.distance_to(hubs[k]) < r_new + float(hub_r[k]) + 15.0:
				ok = false
				break
		if not ok:
			continue
		for k in 8:
			var a := float(k) * TAU / 8.0
			var q := p + Vector2(cos(a), sin(a)) * r_new * 0.8
			if ground_y(q.x, q.y) < 1.2:
				ok = false
				break
		if ok:
			return p
	return Vector2(INF, INF)

func _rand_land() -> Vector2:
	for i in 40:
		var x := randf_range(-HALF * 0.8, HALF * 0.8)
		var z := randf_range(-HALF * 0.8, HALF * 0.8)
		if ground_y(x, z) >= 1.8:
			return Vector2(x, z)
	return Vector2.ZERO

func land_near(o: Vector2, r: float) -> Vector2:
	for i in 40:
		var p := o + Vector2(randf_range(-r, r), randf_range(-r, r))
		if absf(p.x) > HALF - 30.0 or absf(p.y) > HALF - 30.0:
			continue
		if ground_y(p.x, p.y) >= 2.0:
			return p
	return _rand_land()

func _spot_near(c: Vector2, rmin: float, rmax: float, clear: float) -> Vector2:
	for i in 40:
		var ang := randf() * TAU
		var r := randf_range(rmin, rmax)
		var p := c + Vector2(cos(ang), sin(ang)) * r
		if ground_y(p.x, p.y) < 1.5:
			continue
		if _road_dist(p) < 5.0:
			continue
		var ok := true
		for o in obstacles:
			if p.distance_to(o[0]) < o[1] + clear * 0.3:
				ok = false
				break
		if ok:
			return p
	return c

# ---------------- LOKASI & JALAN ----------------

func _add_hub(kind: String, r: float, min_h: float, max_h: float, slope: float) -> void:
	var p := _find_site(r, min_h, max_h, slope)
	if is_inf(p.x):
		return
	hubs.append(p)
	hub_kinds.append(kind)
	hub_r.append(r)
	if kind != "tower":
		_flatten(p, r, r * 0.5, ground_y(p.x, p.y))

func _pick_hubs() -> void:
	_add_hub("nuclear", 80.0, 3.0, 25.0, 0.3)
	_add_hub("city", 98.0, 3.0, 22.0, 0.3)
	_add_hub("factory", 55.0, 3.0, 25.0, 0.3)
	_add_hub("base", 62.0, 3.0, 28.0, 0.3)
	for i in 5:
		_add_hub("village", 62.0, 2.5, 25.0, 0.3)
	_add_hub("fuel", 40.0, 3.0, 25.0, 0.3)
	_add_hub("tower", 15.0, 20.0, 60.0, 0.4)

func _cr(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

func _make_roads() -> void:
	if hubs.size() < 2:
		return
	road_mat = StandardMaterial3D.new()
	road_mat.albedo_texture = Global.tex("road")
	road_mat.roughness = 0.95
	road_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var connected: Array = [0]
	var edges: Array = []
	while connected.size() < hubs.size():
		var best := 1e9
		var bi := -1
		var bj := -1
		for i in connected:
			for j in hubs.size():
				if j in connected:
					continue
				var d: float = hubs[i].distance_to(hubs[j])
				if d < best:
					best = d
					bi = i
					bj = j
		edges.append([bi, bj])
		connected.append(bj)
	for k in 2:
		var a := randi() % hubs.size()
		var b := randi() % hubs.size()
		if a != b:
			edges.append([a, b])
	for e in edges:
		var ca: float = HUB_CLEAR[hub_kinds[e[0]]]
		var cb: float = HUB_CLEAR[hub_kinds[e[1]]]
		var pa: Vector2 = hubs[e[0]]
		var pb: Vector2 = hubs[e[1]]
		var dir := (pb - pa).normalized()
		_road(pa + dir * ca, pb - dir * cb)

func _road(a: Vector2, b: Vector2) -> void:
	var perp := (b - a).normalized().rotated(PI / 2.0)
	var ctrl: Array = [a, a.lerp(b, 0.33) + perp * randf_range(-35.0, 35.0), a.lerp(b, 0.66) + perp * randf_range(-35.0, 35.0), b]
	var ext: Array = [ctrl[0] * 2.0 - ctrl[1]] + ctrl + [ctrl[3] * 2.0 - ctrl[2]]
	var pts: Array = []
	for i in range(1, ext.size() - 2):
		var seg_len: float = ext[i].distance_to(ext[i + 1])
		var steps := maxi(2, int(seg_len / 5.0))
		for s in steps:
			pts.append(_cr(ext[i - 1], ext[i], ext[i + 1], ext[i + 2], float(s) / steps))
	pts.append(b)
	var run: Array = []
	for p in pts:
		road_pts.append(p)
		if ground_y(p.x, p.y) < 0.5:
			_ribbon(run)
			run = []
		else:
			run.append(p)
	_ribbon(run)

func _ribbon(run: Array) -> void:
	if run.size() < 2:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dist := 0.0
	for i in run.size():
		var p: Vector2 = run[i]
		var a: Vector2 = run[maxi(i - 1, 0)]
		var b: Vector2 = run[mini(i + 1, run.size() - 1)]
		var t := (b - a).normalized()
		var s := Vector2(-t.y, t.x)
		if i > 0:
			dist += p.distance_to(run[i - 1])
		var pl := p - s * 3.0
		var pr := p + s * 3.0
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(dist / 8.0, 0.0))
		st.add_vertex(Vector3(pl.x, ground_y(pl.x, pl.y) + 0.2, pl.y))
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(dist / 8.0, 1.0))
		st.add_vertex(Vector3(pr.x, ground_y(pr.x, pr.y) + 0.2, pr.y))
	for i in run.size() - 1:
		var i0 := i * 2
		st.add_index(i0)
		st.add_index(i0 + 2)
		st.add_index(i0 + 1)
		st.add_index(i0 + 2)
		st.add_index(i0 + 3)
		st.add_index(i0 + 1)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = road_mat
	add_child(mi)

# ---------------- STRUKTUR ----------------

func _build_structures() -> void:
	for i in hubs.size():
		match hub_kinds[i]:
			"village": _village(hubs[i])
			"city": _city(hubs[i])
			"base": _base(hubs[i])
			"factory": _factory(hubs[i])
			"nuclear": _nuclear(hubs[i])
			"fuel": _fuel(hubs[i])
			"tower": _tower(hubs[i])

func _village(c: Vector2) -> void:
	var n := randi_range(6, 9)
	var placed := 0
	for i in 80:
		if placed >= n:
			break
		var ang := randf() * TAU
		var r := randf_range(16.0, 50.0)
		var p := c + Vector2(cos(ang), sin(ang)) * r
		if not _can_build(p, 12.0):
			continue
		_house(p, randf() * TAU)
		placed += 1
	_spawn_shop(_spot_near(c, 7.0, 15.0, 5.0))

func _house(p: Vector2, rot: float) -> void:
	var w := randf_range(8.0, 11.0)
	var d := randf_range(8.0, 11.0)
	var H := 3.2
	var fy := ground_y(p.x, p.y)
	var gb: Array = []
	if randf() < 0.4:
		gb = [[randf_range(-2.0, 2.0), 1.6, 2.4]]
	var b := _hall(p, rot, fy, w, d, H, Global.mat("house_wall", 4.0), floor_wood, [[0.0, 1.8, 2.5]], gb, [])
	var pm := PrismMesh.new()
	pm.size = Vector3(w + 1.0, 2.5, d + 1.0)
	pm.material = Global.mat("roof", 3.0)
	var rm := MeshInstance3D.new()
	rm.mesh = pm
	rm.position = Vector3(0, H + 0.3 + 1.25, 0)
	rm.visibility_range_end = _vr()
	b.add_child(rm)
	for k in randi_range(2, 3):
		var rx := randf_range(-w / 2.0 + 1.6, w / 2.0 - 1.6)
		var rz := randf_range(-d / 2.0 + 1.6, -0.8)
		match randi() % 3:
			0: _boxc(b, Vector3(1.4, 0.8, 0.9), Vector3(rx, 0.42, rz), floor_wood)
			1: _boxc(b, Vector3(1.0, 0.5, 2.0), Vector3(rx, 0.27, rz), _cm(Color(0.7, 0.7, 0.85)))
			2: _boxc(b, Vector3(0.6, 1.8, 1.6), Vector3(rx, 0.92, rz), floor_wood)
	obstacles.append([p, maxf(w, d) * 0.75 + 1.5])
	for k in randi_range(1, 2):
		var lx := randf_range(-w / 2.0 + 1.6, w / 2.0 - 1.6)
		var lz := randf_range(-d / 2.0 + 1.6, -0.8)
		var tier := 1 if randf() < 0.35 else 0
		_spawn_loot(_wp(p, rot, Vector3(lx, 0.02, lz), fy), tier)

func _city(c: Vector2) -> void:
	var n := 0
	for i in 60:
		if n >= 9:
			break
		var ang := randf() * TAU
		var r := randf_range(14.0, 85.0)
		var p := c + Vector2(cos(ang), sin(ang)) * r
		if not _can_build(p, 24.0):
			continue
		_apartment(p, randf() * TAU)
		n += 1
	_spawn_shop(_spot_near(c, 8.0, 18.0, 6.0))

func _apartment(p: Vector2, rot: float) -> void:
	var w := randf_range(14.0, 20.0)
	var d := randf_range(14.0, 20.0)
	var H := randf_range(12.0, 30.0)
	var base := _base_y(p, maxf(w, d) * 0.55)
	_solid(Vector3(w, H + 3.0, d), Vector3(p.x, base + (H - 3.0) / 2.0, p.y), rot, Global.mat("building", 4.0))
	obstacles.append([p, maxf(w, d) * 0.75 + 2.0])
	if randf() < 0.7:
		_spawn_loot(Vector3(p.x, base + H, p.y), 1)
	if randf() < 0.5:
		var q := p + Vector2(maxf(w, d) * 0.7 + 2.0, 0.0).rotated(randf() * TAU)
		_spawn_loot(Vector3(q.x, ground_y(q.x, q.y), q.y), 0)

func _base(c: Vector2) -> void:
	for i in 5:
		var p := _spot_near(c, 8.0, 45.0, 10.0)
		var by := _base_y(p, 3.0)
		var cname := "cont_blue" if randf() < 0.5 else "cont_red"
		_solid(Vector3(6, 3.6, 2.4), Vector3(p.x, by + 0.8, p.y), randf() * PI, Global.mat(cname, 3.0))
		obstacles.append([p, 5.0])
	for i in 10:
		var p2 := _spot_near(c, 6.0, 45.0, 4.0)
		var s := randf_range(1.5, 2.2)
		var by2 := _base_y(p2, s)
		_solid(Vector3(s, s + 1.0, s), Vector3(p2.x, by2 + (s - 1.0) / 2.0, p2.y), randf() * PI, Global.mat("crate", 2.0))
		obstacles.append([p2, s])
	for i in 6:
		var p3 := _spot_near(c, 6.0, 45.0, 4.0)
		var by3 := _base_y(p3, 2.5)
		_solid(Vector3(5, 1.5, 1), Vector3(p3.x, by3 + 0.25, p3.y), randf() * PI, Global.mat("sandbag", 2.0))
		obstacles.append([p3, 3.0])
	# bunker yang bisa dimasuki
	var bp := _spot_near(c, 10.0, 35.0, 14.0)
	var brot := randf() * TAU
	var bfy := ground_y(bp.x, bp.y)
	_hall(bp, brot, bfy, 12.0, 8.0, 3.5, Global.mat("concrete", 4.0), Global.mat("concrete", 4.0), [[0.0, 2.4, 2.6]], [], [])
	obstacles.append([bp, 9.0])
	for k in 2:
		_spawn_loot(_wp(bp, brot, Vector3(randf_range(-4.0, 4.0), 0.02, randf_range(-2.5, 0.0)), bfy), 1)
	_spawn_shop(_spot_near(c, 5.0, 14.0, 5.0))
	for i in 6:
		var p4 := _spot_near(c, 5.0, 40.0, 3.0)
		_spawn_loot(Vector3(p4.x, ground_y(p4.x, p4.y), p4.y), 1)

func _factory(c: Vector2) -> void:
	var rot := randf() * TAU
	var fy := ground_y(c.x, c.y)
	var w := 44.0
	var d := 26.0
	var H := 11.0
	var wm := Global.mat("concrete", 6.0)
	var b := _hall(c, rot, fy, w, d, H, wm, Global.mat("concrete", 4.0), [[-10.0, 5.0, 5.0], [10.0, 5.0, 5.0]], [[0.0, 5.0, 5.0]], [[0.0, 3.0, 3.0]])
	var metal := Global.mat("cont_blue", 3.0)
	for k in 5:
		_boxc(b, Vector3(4.0, 3.0, 3.0), Vector3(-17.0 + k * 8.5, 1.5, -9.0), metal)
	_boxc(b, Vector3(14.0, 0.8, 1.2), Vector3(-12.0, 0.4, 0.0), floor_wood)
	_boxc(b, Vector3(14.0, 0.8, 1.2), Vector3(12.0, 0.4, 0.0), floor_wood)
	for k in 3:
		_boxc(b, Vector3(0.5, 0.5, d - 1.0), Vector3(-12.0 + k * 12.0, 9.0, 0.0), _cm(Color(0.6, 0.6, 0.65)), false)
	for k in 4:
		_spawn_loot(_wp(c, rot, Vector3(randf_range(-18.0, 18.0), 0.02, randf_range(3.0, 10.0)), fy), 1)
	for k in 3:
		var cp := _wp(c, rot, Vector3(-12.0 + k * 10.0, 0, -d / 2.0 - 7.0), fy)
		_cyl(Vector3(cp.x, ground_y(cp.x, cp.z), cp.z), 1.2, 1.7, 34.0, wm, 12)
		obstacles.append([Vector2(cp.x, cp.z), 3.0])
	for k in 2:
		var tp := _wp(c, rot, Vector3(-30.0, 0, -4.0 + k * 14.0), fy)
		_cyl(Vector3(tp.x, ground_y(tp.x, tp.z), tp.z), 5.0, 5.0, 8.0, metal, 16)
		obstacles.append([Vector2(tp.x, tp.z), 6.0])
	obstacles.append([c, 30.0])
	_label3d(Vector3(c.x, fy + 16.0, c.y), "PABRIK", Color(1, 0.7, 0.2), 350.0)
	var sp := _wp(c, rot, Vector3(0, 0, d / 2.0 + 8.0), fy)
	_spawn_shop(Vector2(sp.x, sp.z))

func _nuclear(c: Vector2) -> void:
	var rot := randf() * TAU
	var fy := ground_y(c.x, c.y)
	var cm := Global.mat("concrete", 6.0)
	var b := _hall(c, rot, fy, 34.0, 34.0, 14.0, cm, Global.mat("concrete", 4.0), [[0.0, 6.0, 6.0]], [[0.0, 6.0, 6.0]], [])
	var dm := SphereMesh.new()
	dm.radius = 15.0
	dm.height = 15.0
	dm.is_hemisphere = true
	dm.radial_segments = 20
	dm.rings = 8
	dm.material = cm
	var dmi := MeshInstance3D.new()
	dmi.mesh = dm
	dmi.position = Vector3(0, 14.3, 0)
	dmi.visibility_range_end = _vr()
	b.add_child(dmi)
	var core := MeshInstance3D.new()
	var cmesh := CylinderMesh.new()
	cmesh.top_radius = 4.0
	cmesh.bottom_radius = 4.0
	cmesh.height = 7.0
	cmesh.radial_segments = 16
	cmesh.material = _cm(Color(0.2, 1.0, 0.4), true)
	core.mesh = cmesh
	core.position = Vector3(0, 3.5, 0)
	core.visibility_range_end = _vr()
	b.add_child(core)
	var cc := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 4.0
	cs.height = 7.0
	cc.shape = cs
	cc.position = Vector3(0, 3.5, 0)
	b.add_child(cc)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_boxc(b, Vector3(1.2, 8.0, 1.2), Vector3(sx * 9.0, 4.0, sz * 9.0), cm)
	for k in 3:
		var a := randf() * TAU
		_spawn_loot(_wp(c, rot, Vector3(cos(a) * 12.0, 0.02, sin(a) * 12.0), fy), 1)
	for k in 2:
		var lp := _wp(c, rot, Vector3(-56.0, 0, -22.0 + 44.0 * k), fy)
		var gy := ground_y(lp.x, lp.z)
		_cyl(Vector3(lp.x, gy, lp.z), 9.0, 13.0, 38.0, cm, 24)
		_steam(Vector3(lp.x, gy + 38.0, lp.z))
		obstacles.append([Vector2(lp.x, lp.z), 15.0])
	var cp := _wp(c, rot, Vector3(46.0, 0, -14.0), fy)
	var cb := _hall(Vector2(cp.x, cp.z), rot, ground_y(cp.x, cp.z), 20.0, 14.0, 7.0, cm, Global.mat("concrete", 4.0), [[0.0, 2.4, 2.6]], [], [])
	for k in 3:
		_boxc(cb, Vector3(3.0, 1.0, 1.0), Vector3(-5.0 + k * 5.0, 0.5, -4.0), floor_wood)
		_boxc(cb, Vector3(1.8, 0.8, 0.1), Vector3(-5.0 + k * 5.0, 1.5, -4.5), _cm(Color(0.2, 0.9, 1.0), true), false)
	for k in 2:
		_spawn_loot(_wp(Vector2(cp.x, cp.z), rot, Vector3(randf_range(-6.0, 6.0), 0.02, randf_range(-1.0, 3.0)), ground_y(cp.x, cp.z)), 1)
	obstacles.append([Vector2(cp.x, cp.z), 14.0])
	obstacles.append([c, 24.0])
	_label3d(Vector3(c.x, fy + 24.0, c.y), "REAKTOR NUKLIR", Color(1.0, 0.9, 0.1), 400.0)
	var sp := _wp(c, rot, Vector3(0, 0, 25.0), fy)
	_spawn_shop(Vector2(sp.x, sp.z))

func _fuel(c: Vector2) -> void:
	var fy := ground_y(c.x, c.y)
	var tk := [Global.mat("cont_red", 4.0), Global.mat("concrete", 4.0)]
	for k in 4:
		var p := c + Vector2(-12.0 + (k % 2) * 24.0, -12.0 + (k / 2) * 24.0)
		_cyl(Vector3(p.x, ground_y(p.x, p.y), p.y), 7.0, 7.0, 9.0, tk[k % 2], 20)
		obstacles.append([p, 9.0])
	var hp := c + Vector2(0, 30.0)
	_hall(hp, 0.0, ground_y(hp.x, hp.y), 8.0, 6.0, 3.2, Global.mat("concrete", 4.0), Global.mat("concrete", 4.0), [[0.0, 1.8, 2.5]], [], [])
	obstacles.append([hp, 6.0])
	for k in 2:
		var lp := c + Vector2(randf_range(-3.0, 3.0), 0.0)
		_spawn_loot(Vector3(hp.x + randf_range(-2.0, 2.0), fy + 0.02, hp.y + randf_range(-1.5, 0.0)), 1)
	_label3d(Vector3(c.x, fy + 16.0, c.y), "DEPOT BBM", Color(1.0, 0.4, 0.2), 300.0)

func _tower(c: Vector2) -> void:
	var by := _base_y(c, 4.0)
	var metal := Global.mat("cont_red", 3.0)
	var b := StaticBody3D.new()
	b.position = Vector3(c.x, by - 1.0, c.y)
	add_child(b)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_boxc(b, Vector3(0.6, 62.0, 0.6), Vector3(sx * 3.0, 31.0, sz * 3.0), metal)
	for k in range(1, 7):
		var y := float(k) * 9.0
		_boxc(b, Vector3(6.6, 0.35, 0.35), Vector3(0, y, 3.0), metal, false)
		_boxc(b, Vector3(6.6, 0.35, 0.35), Vector3(0, y, -3.0), metal, false)
		_boxc(b, Vector3(0.35, 0.35, 6.6), Vector3(3.0, y, 0), metal, false)
		_boxc(b, Vector3(0.35, 0.35, 6.6), Vector3(-3.0, y, 0), metal, false)
	var lamp := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.8
	sm.height = 1.6
	sm.radial_segments = 8
	sm.rings = 4
	sm.material = _cm(Color(1, 0.1, 0.1), true)
	lamp.mesh = sm
	lamp.position = Vector3(0, 63.0, 0)
	b.add_child(lamp)
	_set_vr(b, 600.0)
	obstacles.append([c, 8.0])
	_spawn_loot(Vector3(c.x + 6.0, ground_y(c.x + 6.0, c.y), c.y), 1)

func _make_forest() -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.25
	trunk_mesh.bottom_radius = 0.35
	trunk_mesh.height = 4.0
	trunk_mesh.radial_segments = 6
	trunk_mesh.rings = 1
	trunk_mesh.material = Global.mat("bark", 2.0)
	var leaf_mesh := SphereMesh.new()
	leaf_mesh.radius = 2.2
	leaf_mesh.height = 4.4
	leaf_mesh.radial_segments = 8
	leaf_mesh.rings = 4
	leaf_mesh.material = Global.mat("leaves", 2.0)
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = 4.0
	var body := StaticBody3D.new()
	var chunks := {}
	var count := 0
	for i in 3000:
		if count >= 420:
			break
		var x := randf_range(-HALF * 0.9, HALF * 0.9)
		var z := randf_range(-HALF * 0.9, HALF * 0.9)
		var h := ground_y(x, z)
		if h < 2.0 or h > 30.0:
			continue
		if noise.get_noise_2d(x * 1.3 + 700.0, z * 1.3) < 0.0:
			continue
		if _slope(x, z) > 0.5:
			continue
		var p := Vector2(x, z)
		if _road_dist(p) < 7.0:
			continue
		var ok := true
		for o in obstacles:
			if p.distance_to(o[0]) < o[1] + 3.0:
				ok = false
				break
		if not ok:
			continue
		var s := randf_range(0.8, 1.5)
		var bs := Basis(Vector3.UP, randf() * TAU).scaled(Vector3(s, s, s))
		var key := Vector2i(int(floor(x / 128.0)), int(floor(z / 128.0)))
		if not chunks.has(key):
			chunks[key] = [[], []]
		chunks[key][0].append(Transform3D(bs, Vector3(x, h + 2.0 * s, z)))
		chunks[key][1].append(Transform3D(bs, Vector3(x, h + 5.4 * s, z)))
		count += 1
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = Vector3(x, h + 2.0, z)
		body.add_child(cs)
	add_child(body)
	for key in chunks:
		var tt: Array = chunks[key][0]
		var lt: Array = chunks[key][1]
		var mm1 := MultiMesh.new()
		mm1.transform_format = MultiMesh.TRANSFORM_3D
		mm1.mesh = trunk_mesh
		mm1.instance_count = tt.size()
		var mm2 := MultiMesh.new()
		mm2.transform_format = MultiMesh.TRANSFORM_3D
		mm2.mesh = leaf_mesh
		mm2.instance_count = lt.size()
		for i in tt.size():
			mm1.set_instance_transform(i, tt[i])
			mm2.set_instance_transform(i, lt[i])
		var mi1 := MultiMeshInstance3D.new()
		mi1.multimesh = mm1
		mi1.visibility_range_end = _vr()
		add_child(mi1)
		var mi2 := MultiMeshInstance3D.new()
		mi2.multimesh = mm2
		mi2.visibility_range_end = _vr()
		add_child(mi2)

func _make_rocks() -> void:
	for i in 60:
		var x := randf_range(-HALF * 0.85, HALF * 0.85)
		var z := randf_range(-HALF * 0.85, HALF * 0.85)
		var h := ground_y(x, z)
		if h < 0.8:
			continue
		var p := Vector2(x, z)
		if _road_dist(p) < 8.0:
			continue
		var ok := true
		for o in obstacles:
			if p.distance_to(o[0]) < o[1] + 4.0:
				ok = false
				break
		if not ok:
			continue
		var s := randf_range(1.5, 4.0)
		var rb := StaticBody3D.new()
		rb.position = Vector3(x, h + s * 0.3, z)
		rb.rotation = Vector3(randf() * PI, randf() * TAU, 0)
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = s
		sm.height = s * 2.0
		sm.radial_segments = 12
		sm.rings = 6
		sm.material = Global.mat("rock", 3.0)
		mi.mesh = sm
		mi.visibility_range_end = _vr()
		rb.add_child(mi)
		var cs := CollisionShape3D.new()
		var ss := SphereShape3D.new()
		ss.radius = s
		cs.shape = ss
		rb.add_child(cs)
		add_child(rb)

func _scatter_loot() -> void:
	for i in 45:
		var p := _rand_land()
		_spawn_loot(Vector3(p.x, ground_y(p.x, p.y), p.y), 0)

# ---------------- TOKO KULKAS ----------------

func _spawn_shop(p: Vector2) -> void:
	var base := ground_y(p.x, p.y)
	var b := StaticBody3D.new()
	b.position = Vector3(p.x, base, p.y)
	b.rotation.y = randf() * TAU
	var wmat := _cm(Color(0.93, 0.95, 0.97))
	wmat.metallic = 0.3
	wmat.roughness = 0.35
	_boxc(b, Vector3(1.1, 2.1, 0.9), Vector3(0, 1.05, 0), wmat)
	_part(b, Vector3(0.85, 1.55, 0.03), Vector3(0, 1.1, 0.46), _cm(Color(0.3, 0.8, 1.0), true))
	_part(b, Vector3(0.05, 0.55, 0.05), Vector3(0.45, 1.1, 0.5), _cm(Color(0.15, 0.15, 0.17)))
	var lab := Label3D.new()
	lab.text = "TOKO"
	lab.font_size = 96
	lab.pixel_size = 0.01
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(1, 0.85, 0.2)
	lab.outline_size = 12
	lab.position = Vector3(0, 2.7, 0)
	lab.visibility_range_end = 200.0
	b.add_child(lab)
	var lt := OmniLight3D.new()
	lt.light_color = Color(0.4, 0.9, 1.0)
	lt.omni_range = 8.0
	lt.position = Vector3(0, 1.5, 1.0)
	lt.visible = false
	b.set_meta("light", lt)
	b.add_child(lt)
	_beam(b, Color(1.0, 0.85, 0.1), 40.0)
	add_child(b)
	shops.append(b)
	obstacles.append([p, 3.0])

# ---------------- LOOT ----------------

func _set_vr(n: Node, d: float) -> void:
	if n is GeometryInstance3D:
		n.visibility_range_end = d
	for c in n.get_children():
		_set_vr(c, d)

func _pick(wt: Array) -> int:
	var tot := 0.0
	for w in wt:
		tot += float(w)
	var r := randf() * tot
	for i in wt.size():
		r -= float(wt[i])
		if r <= 0.0:
			return i
	return wt.size() - 1

func _rand_item(tier: int) -> Array:
	var r := randf()
	var ww := 0.32 if tier == 0 else 0.45
	if r < ww:
		var wt: Array = [0.22, 0.2, 0.24, 0.16, 0.09, 0.09] if tier == 0 else [0.05, 0.15, 0.3, 0.15, 0.18, 0.17]
		return ["weapon", Global.ORDER[_pick(wt)]]
	elif r < ww + 0.22:
		return ["medkit", 1]
	elif r < ww + 0.4:
		var sw: Array = [0.5, 0.3, 0.15, 0.05] if tier == 0 else [0.2, 0.3, 0.3, 0.2]
		return ["scope", _pick(sw) + 1]
	elif r < ww + 0.55:
		var aw: Array = [0.7, 0.3, 0.0] if tier == 0 else [0.3, 0.5, 0.2]
		return ["armor", _pick(aw) + 1]
	return ["coin", randi_range(50, 150)]

func _spawn_loot(pos: Vector3, tier: int) -> void:
	var it := _rand_item(tier)
	_spawn_item(pos, it[0], it[1])

func _spawn_item(pos: Vector3, kind: String, val: Variant) -> void:
	var l := Node3D.new()
	l.position = pos + Vector3(0, 0.2, 0)
	var vis := Node3D.new()
	vis.position.y = 0.7
	l.add_child(vis)
	var col := Color(1, 0.6, 0.1)
	var nm := ""
	match kind:
		"weapon":
			var wm := Global.build_weapon(str(val), 0)
			wm.scale = Vector3.ONE * 1.4
			vis.add_child(wm)
			nm = str(Global.WEAPONS[str(val)]["name"])
		"medkit":
			col = Color(0.2, 0.9, 0.4)
			_part(vis, Vector3(0.4, 0.28, 0.28), Vector3.ZERO, _cm(Color(0.95, 0.95, 0.95)))
			_part(vis, Vector3(0.22, 0.06, 0.3), Vector3(0, 0.15, 0), _cm(Color(0.9, 0.1, 0.1)))
			_part(vis, Vector3(0.06, 0.06, 0.3), Vector3(0, 0.15, 0), _cm(Color(0.9, 0.1, 0.1)))
			nm = "MEDKIT"
		"scope":
			col = Color(0.2, 0.9, 1.0)
			_part(vis, Vector3(0.35, 0.1, 0.1), Vector3.ZERO, _cm(Color(0.08, 0.08, 0.1)))
			_part(vis, Vector3(0.05, 0.14, 0.14), Vector3(0.18, 0, 0), _cm(Color(0.2, 0.9, 1.0), true))
			nm = "SCOPE LV%d" % int(val)
		"armor":
			col = Color(0.3, 0.55, 1.0)
			_part(vis, Vector3(0.5, 0.55, 0.22), Vector3.ZERO, _cm(Color(0.2, 0.35, 0.75)))
			nm = "ARMOR LV%d" % int(val)
		_:
			col = Color(1.0, 0.85, 0.1)
			_part(vis, Vector3(0.3, 0.3, 0.06), Vector3.ZERO, _cm(Color(1.0, 0.85, 0.1), true))
			nm = "%d KOIN" % int(val)
	_set_vr(vis, 70.0)
	_beam(l, col, 16.0)
	var lab := Label3D.new()
	lab.text = nm
	lab.font_size = 48
	lab.pixel_size = 0.006
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.outline_size = 10
	lab.position = Vector3(0, 1.6, 0)
	lab.visibility_range_end = 45.0
	l.add_child(lab)
	l.set_meta("kind", kind)
	l.set_meta("val", val)
	l.set_meta("name", nm)
	add_child(l)
	loots.append(l)

func _pickup(l: Node3D) -> void:
	var kind: String = l.get_meta("kind")
	var val = l.get_meta("val")
	var nm: String = l.get_meta("name")
	match kind:
		"weapon": player.give_weapon(str(val))
		"medkit": player.medkits += 1
		"scope": player.give_scope(int(val))
		"armor": player.give_armor(int(val))
		_: player.coins += int(val)
	Global.sfx("pick", -4.0)
	hud.toast("Dapat: " + nm)
	loots.erase(l)
	l.queue_free()
	near_loot = null

func _on_interact() -> void:
	if player.interact_kind == "shop":
		_open_shop()
	elif player.interact_kind == "loot" and is_instance_valid(near_loot):
		_pickup(near_loot)

# ---------------- UI TOKO ----------------

func _shop_style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c.darkened(0.55)
	s.border_color = c
	s.set_border_width_all(2)
	s.border_width_left = 8
	s.set_corner_radius_all(10)
	s.content_margin_left = 20
	s.content_margin_right = 12
	return s

func _open_shop() -> void:
	if shop_layer != null:
		return
	get_tree().paused = true
	shop_layer = CanvasLayer.new()
	shop_layer.layer = 20
	shop_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(shop_layer)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.07, 0.93)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_layer.add_child(bg)
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, 30)
	shop_layer.add_child(mc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	mc.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var title := Label.new()
	title.text = "TOKO"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	coin_label = Label.new()
	coin_label.add_theme_font_size_override("font_size", 34)
	head.add_child(coin_label)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	sc.add_child(grid)
	for it in SHOP_ITEMS:
		var c := Color(0.9, 0.5, 0.1)
		match String(it[2]):
			"armor": c = Color(0.25, 0.5, 0.95)
			"scope": c = Color(0.1, 0.75, 0.85)
			"medkit": c = Color(0.25, 0.75, 0.4)
		var b := Button.new()
		b.text = "%s\n%d KOIN" % [it[0], it[1]]
		b.custom_minimum_size = Vector2(0, 92)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 26)
		b.add_theme_stylebox_override("normal", _shop_style(c))
		b.add_theme_stylebox_override("hover", _shop_style(c.lightened(0.15)))
		b.add_theme_stylebox_override("pressed", _shop_style(c.lightened(0.3)))
		b.pressed.connect(_buy.bind(it))
		grid.add_child(b)
	shop_msg = Label.new()
	shop_msg.add_theme_font_size_override("font_size", 26)
	vb.add_child(shop_msg)
	var close := Button.new()
	close.text = "TUTUP"
	close.custom_minimum_size = Vector2(0, 76)
	close.add_theme_font_size_override("font_size", 30)
	close.pressed.connect(_close_shop)
	vb.add_child(close)
	_refresh_coins()

func _refresh_coins() -> void:
	coin_label.text = "KOIN: %d" % player.coins

func _buy(it: Array) -> void:
	var price: int = it[1]
	if player.coins < price:
		shop_msg.text = "Koin tidak cukup!"
		return
	player.coins -= price
	match String(it[2]):
		"weapon": player.give_weapon(str(it[3]))
		"armor": player.give_armor(int(it[3]))
		"scope": player.give_scope(int(it[3]))
		"medkit": player.medkits += int(it[3])
	Global.sfx("buy")
	shop_msg.text = "Dibeli: " + str(it[0])
	_refresh_coins()

func _close_shop() -> void:
	get_tree().paused = false
	if shop_layer:
		shop_layer.queue_free()
		shop_layer = null
	player.touches.clear()
	player.firing = false
	player.move_vec = Vector2.ZERO

# ---------------- PESAWAT, BOT & PERTANDINGAN ----------------

func _build_plane() -> void:
	plane = Node3D.new()
	plane.position = Vector3(-HALF - 150.0, 220.0, randf_range(-150.0, 150.0))
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.78, 0.8, 0.84)
	var fus := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.8
	cm.bottom_radius = 1.8
	cm.height = 30.0
	cm.radial_segments = 16
	cm.rings = 1
	cm.material = pmat
	fus.mesh = cm
	fus.rotation_degrees = Vector3(0, 0, 90)
	plane.add_child(fus)
	_part(plane, Vector3(6, 0.4, 40), Vector3(0, -0.5, 0), pmat)
	_part(plane, Vector3(3, 5, 0.4), Vector3(-13, 3, 0), pmat)
	_part(plane, Vector3(3, 0.3, 10), Vector3(-13, 0.5, 0), pmat)
	_part(plane, Vector3(4, 1.2, 2.6), Vector3(11, 0.9, 0), _cm(Color(0.3, 0.5, 0.7)))
	_set_vr(plane, 1500.0)
	add_child(plane)

func _spawn_bots() -> void:
	for i in TOTAL:
		var e: CharacterBody3D = preload("res://enemy.gd").new()
		e.target = player
		e.player_ref = player
		e.game = self
		e.plane = plane
		e.plane_vel = plane_vel
		e.jump_x = randf_range(-HALF + 60.0, HALF - 40.0)
		e.dmg = Global.DIFF_DMG[Global.difficulty]
		e.acc = Global.DIFF_ACC[Global.difficulty]
		e.killed.connect(_on_enemy_killed.bind(e))
		e.position = plane.position
		add_child(e)
		enemies_alive += 1

func _on_landed() -> void:
	hud.banner("HABISI SEMUA MUSUH!")

# ---------------- ZONA ----------------

func outside_zone(p: Vector2) -> bool:
	return zone_active and p.distance_to(zone_center) > zone_radius

func _zone_pick_next() -> void:
	zone_next_r = ZONE_RADII[zone_stage]
	var maxo := maxf(0.0, zone_radius - zone_next_r) * 0.8
	var a := randf() * TAU
	var r := sqrt(randf()) * maxo
	zone_next_c = zone_center + Vector2(cos(a), sin(a)) * r

func _zone_visual() -> void:
	if zone_wall:
		zone_wall.position = Vector3(zone_center.x, 200.0, zone_center.y)
		zone_wall.scale = Vector3(zone_radius, 1.0, zone_radius)

func _zone_start() -> void:
	zone_active = true
	zone_stage = 1
	zone_center = Vector2.ZERO
	zone_radius = ZONE_RADII[0]
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 600.0
	cm.radial_segments = 64
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.albedo_color = Color(0.2, 0.5, 1.0, 0.3)
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	cm.material = mt
	zone_wall = MeshInstance3D.new()
	zone_wall.mesh = cm
	add_child(zone_wall)
	_zone_pick_next()
	zone_phase = "wait"
	zone_t = ZONE_WAIT[0]
	_zone_visual()
	hud.banner("ZONA MUNCUL!")
	Global.sfx("pick", -2.0, 0.6)

func _zone_process(delta: float) -> void:
	if not zone_active:
		if match_time >= ZONE_APPEAR:
			_zone_start()
		return
	if zone_phase == "wait":
		zone_t -= delta
		if zone_t <= 0.0:
			zone_phase = "shrink"
			zone_dur = ZONE_SHRINK[zone_stage - 1]
			zone_t = zone_dur
			zone_from_c = zone_center
			zone_from_r = zone_radius
			hud.banner("ZONA %d MENYUSUT!" % zone_stage)
	elif zone_phase == "shrink":
		zone_t -= delta
		var k := 1.0 - clampf(zone_t / zone_dur, 0.0, 1.0)
		zone_center = zone_from_c.lerp(zone_next_c, k)
		zone_radius = lerpf(zone_from_r, zone_next_r, k)
		if zone_t <= 0.0:
			zone_center = zone_next_c
			zone_radius = zone_next_r
			if zone_stage >= 5:
				zone_phase = "final"
			else:
				zone_stage += 1
				_zone_pick_next()
				zone_phase = "wait"
				zone_t = ZONE_WAIT[zone_stage - 1]
	_zone_visual()
	var pp := Vector2(player.global_position.x, player.global_position.z)
	zone_outside = player.state == 3 and not player.dead and pp.distance_to(zone_center) > zone_radius
	if zone_outside:
		zone_out_t += delta
	else:
		zone_out_t = maxf(0.0, zone_out_t - delta * 2.0)
	var base: float = ZONE_DPS[zone_stage - 1]
	zone_dps_now = base * (1.0 + zone_out_t * 0.12)
	zone_tick -= delta
	if zone_tick <= 0.0:
		zone_tick = 1.0
		if zone_outside:
			player.zone_hurt(int(ceil(zone_dps_now)))
		for e in get_tree().get_nodes_in_group("enemy"):
			if e.phase == 3 and e.hp > 0 and outside_zone(Vector2(e.global_position.x, e.global_position.z)):
				e.take_damage(int(ceil(base * 1.5)), null)

# ---------------- CLASH SQUAD ----------------

func _setup_cs() -> void:
	var cands: Array = []
	for i in hubs.size():
		if hub_kinds[i] != "tower":
			cands.append(i)
	var best_pair := Vector2i(-1, -1)
	for tries in 40:
		if cands.size() < 2:
			break
		var a: int = cands[randi() % cands.size()]
		var b: int = cands[randi() % cands.size()]
		if a == b:
			continue
		var d: float = hubs[a].distance_to(hubs[b])
		if d > 130.0 and d < 320.0:
			best_pair = Vector2i(a, b)
			break
	if best_pair.x >= 0:
		spawn_a = _spot_near(hubs[best_pair.x], 8.0, 28.0, 3.0)
		spawn_b = _spot_near(hubs[best_pair.y], 8.0, 28.0, 3.0)
	else:
		spawn_a = _rand_land()
		spawn_b = land_near(spawn_a, 200.0)

func _make_bot(team: int, p: Vector2, advance: Vector2) -> void:
	var e: CharacterBody3D = preload("res://enemy.gd").new()
	e.team = team
	e.fight_bots = true
	e.use_lod = false
	e.start_ground = true
	e.game = self
	e.player_ref = player
	e.advance_to = Vector3(advance.x, 0.0, advance.y)
	e.dmg = Global.DIFF_DMG[Global.difficulty]
	e.acc = Global.DIFF_ACC[Global.difficulty]
	if team == 0:
		e.base_color = Color(0.2, 0.4, 0.75)
	else:
		e.base_color = Color(0.6, 0.2, 0.18)
	e.killed.connect(_on_enemy_killed.bind(e))
	e.position = Vector3(p.x, ground_y(p.x, p.y) + 1.1, p.y)
	add_child(e)

func _start_round() -> void:
	round_no += 1
	round_over = false
	freeze = true
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	for i in 3:
		_make_bot(0, spawn_a + Vector2(randf_range(-9.0, 9.0), randf_range(-9.0, 9.0)), spawn_b)
	for i in 4:
		_make_bot(1, spawn_b + Vector2(randf_range(-9.0, 9.0), randf_range(-9.0, 9.0)), spawn_a)
	enemies_alive = 4
	var pp := spawn_a + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
	var d := spawn_b - spawn_a
	player.revive(Vector3(pp.x, ground_y(pp.x, pp.y) + 1.1, pp.y), atan2(-d.x, -d.y))
	player.coins += 800 if round_no == 1 else 500
	hud.banner("RONDE %d" % round_no)
	hud.toast("Beli senjata di toko (ikon keranjang) sebelum ronde mulai")
	await get_tree().create_timer(6.0).timeout
	freeze = false
	hud.banner("MULAI!")

func team_counts() -> Vector2i:
	var a := 0
	var b := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.hp > 0 and not e.is_queued_for_deletion():
			if e.team == 0:
				a += 1
			else:
				b += 1
	if not player.dead:
		a += 1
	return Vector2i(a, b)

func _check_round() -> void:
	if not cs or round_over or over:
		return
	var tc := team_counts()
	if tc.y == 0:
		_end_round(true)
	elif tc.x == 0:
		_end_round(false)

func _end_round(win: bool) -> void:
	round_over = true
	if win:
		score_ally += 1
		player.coins += 300
	else:
		score_enemy += 1
	hud.banner("RONDE MENANG!" if win else "RONDE KALAH")
	await get_tree().create_timer(3.0).timeout
	if over:
		return
	if score_ally >= 4 or score_enemy >= 4:
		over = true
		var won := score_ally >= 4
		if won:
			Global.best_wave += 1
		Global.best_kills = maxi(Global.best_kills, kills)
		Global.save_all()
		_end_screen("MENANG!" if won else "KALAH")
	else:
		_start_round()

func _on_enemy_killed(pos: Vector3, bot: Node) -> void:
	var by_player: bool = is_instance_valid(bot.last_src) and bot.last_src == player
	if bot.team == 1:
		enemies_alive -= 1
		if by_player:
			kills += 1
			player.coins += 100 if cs else 60
		if not cs and randf() < 0.45:
			var it := _rand_item(0)
			_spawn_item(Vector3(pos.x, ground_y(pos.x, pos.z), pos.z), it[0], it[1])
	if cs:
		_check_round()
		return
	if enemies_alive <= 0 and not over:
		over = true
		Global.best_wave += 1
		Global.best_kills = maxi(Global.best_kills, kills)
		Global.save_all()
		_end_screen("MENANG!\nJUARA 1")

func _on_died() -> void:
	if cs:
		_check_round()
		return
	if over:
		return
	over = true
	Global.best_kills = maxi(Global.best_kills, kills)
	Global.save_all()
	for e in get_tree().get_nodes_in_group("enemy"):
		e.set_physics_process(false)
	_end_screen("GAME OVER")

func _end_screen(title: String) -> void:
	Global.use_active = false
	player.set_process_input(false)
	player.firing = false
	player.move_vec = Vector2.ZERO
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	var l := Label.new()
	if cs:
		l.text = "%s\nSkor %d - %d   |   Kill %d" % [title, score_ally, score_enemy, kills]
	else:
		l.text = "%s\nKill %d   |   Sisa musuh %d" % [title, kills, enemies_alive]
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 48)
	box.add_child(l)
	var b1 := Button.new()
	b1.text = "MAIN LAGI"
	b1.custom_minimum_size = Vector2(480, 80)
	b1.add_theme_font_size_override("font_size", 32)
	b1.pressed.connect(func(): get_tree().reload_current_scene())
	box.add_child(b1)
	var b2 := Button.new()
	b2.text = "KE LOBBY"
	b2.custom_minimum_size = Vector2(480, 80)
	b2.add_theme_font_size_override("font_size", 32)
	b2.pressed.connect(func(): get_tree().change_scene_to_file("res://menu.tscn"))
	box.add_child(b2)
