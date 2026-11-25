extends Node3D

const FxBtn := preload("res://fxbtn.gd")
const RED := Color(1.0, 0.1, 0.14)

var cam: Camera3D
var bg_quad: MeshInstance3D
var bg_aspect := 16.0 / 9.0
var char_root: Node3D
var torso: Node3D
var head: Node3D
var cape: Node3D
var ring: MeshInstance3D
var t := 0.0
var drag_yaw := 0.0
var drag_idle := 0.0
var ui: Control
var overlay: Control
var play_btn
var mode_btn
var gear_btn
var logo_rect: TextureRect
var stat_label: Label
var starting := false

func _ready() -> void:
	_build_3d()
	_build_character()
	_build_ui()
	_refresh()

# ---------------- 3D: LATAR + KARAKTER ----------------

func _build_3d() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.0, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.12, 0.14)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.current = true
	var bgq := QuadMesh.new()
	bgq.size = Vector2(1, 1)
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tex := Global.bg_tex()
	if tex:
		bm.albedo_texture = tex
	else:
		bm.albedo_color = Color(0.25, 0.02, 0.04)
	bgq.material = bm
	bg_quad = MeshInstance3D.new()
	bg_quad.mesh = bgq
	bg_quad.position = Vector3(0, 0, -30)
	add_child(bg_quad)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -25, 0)
	key.light_color = Color(1.0, 0.4, 0.35)
	key.light_energy = 1.3
	add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(2.2, 1.5, -7.0)
	rim.light_color = Color(0.85, 0.9, 1.0)
	rim.light_energy = 3.0
	rim.omni_range = 12.0
	add_child(rim)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.0, 0.5, -2.5)
	fill.light_color = Color(1.0, 0.15, 0.15)
	fill.light_energy = 2.0
	fill.omni_range = 8.0
	add_child(fill)
	var parts := CPUParticles3D.new()
	parts.amount = 60
	parts.lifetime = 5.0
	parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	parts.emission_box_extents = Vector3(5, 1, 3)
	parts.direction = Vector3(0, 1, 0)
	parts.spread = 25.0
	parts.initial_velocity_min = 0.4
	parts.initial_velocity_max = 1.2
	parts.gravity = Vector3.ZERO
	parts.position = Vector3(0, -2.2, -5)
	var sm := SphereMesh.new()
	sm.radius = 0.02
	sm.height = 0.04
	sm.radial_segments = 6
	sm.rings = 3
	var spm := StandardMaterial3D.new()
	spm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spm.vertex_color_use_as_albedo = true
	spm.albedo_color = Color(1, 1, 1, 1)
	sm.material = spm
	parts.mesh = sm
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.35, 0.2, 1.0))
	g.set_color(1, Color(1.0, 0.05, 0.05, 0.0))
	parts.color_ramp = g
	add_child(parts)

func _cb(parent: Node3D, size: Vector3, pos: Vector3, color: Color, metal: float = 0.3, rough: float = 0.6, rot: Vector3 = Vector3.ZERO, glow: bool = false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mt := StandardMaterial3D.new()
	mt.albedo_color = color
	mt.metallic = metal
	mt.roughness = rough
	if glow:
		mt.emission_enabled = true
		mt.emission = color
		mt.emission_energy_multiplier = 1.6
	bm.material = mt
	m.mesh = bm
	m.position = pos
	m.rotation_degrees = rot
	parent.add_child(m)
	return m

func _build_character() -> void:
	char_root = Node3D.new()
	char_root.position = Vector3(0, -1.15, -4.5)
	add_child(char_root)
	var olive := Color(0.17, 0.19, 0.15)
	var armor := Color(0.12, 0.12, 0.15)
	var dark := Color(0.06, 0.06, 0.08)
	var red := Color(0.95, 0.05, 0.08)
	var skin := Color(0.85, 0.65, 0.5)
	for sx in [-1.0, 1.0]:
		_cb(char_root, Vector3(0.24, 0.14, 0.38), Vector3(sx * 0.13, 0.07, 0.05), dark)
		_cb(char_root, Vector3(0.22, 0.78, 0.26), Vector3(sx * 0.13, 0.53, 0.0), olive)
		_cb(char_root, Vector3(0.2, 0.14, 0.08), Vector3(sx * 0.13, 0.55, 0.15), armor, 0.5)
	_cb(char_root, Vector3(0.5, 0.18, 0.3), Vector3(0, 0.98, 0), dark)
	_cb(char_root, Vector3(0.52, 0.04, 0.32), Vector3(0, 1.06, 0), red, 0.0, 0.5, Vector3.ZERO, true)
	torso = Node3D.new()
	torso.position = Vector3(0, 1.32, 0)
	char_root.add_child(torso)
	_cb(torso, Vector3(0.54, 0.55, 0.32), Vector3.ZERO, olive)
	_cb(torso, Vector3(0.6, 0.5, 0.38), Vector3(0, 0.03, 0.02), armor, 0.5)
	_cb(torso, Vector3(0.2, 0.26, 0.03), Vector3(0, 0.06, 0.22), red, 0.0, 0.5, Vector3.ZERO, true)
	_cb(torso, Vector3(0.42, 0.5, 0.22), Vector3(0, 0.0, -0.3), dark)
	_cb(torso, Vector3(0.1, 0.08, 0.1), Vector3(0, 0.34, 0), skin)
	for sx in [-1.0, 1.0]:
		_cb(torso, Vector3(0.2, 0.12, 0.28), Vector3(sx * 0.36, 0.26, 0), armor, 0.5)
		_cb(torso, Vector3(0.13, 0.34, 0.15), Vector3(sx * 0.38, 0.06, 0.06), olive, 0.1, 0.7, Vector3(-25, 0, sx * 6.0))
		_cb(torso, Vector3(0.12, 0.3, 0.14), Vector3(sx * 0.26, -0.12, 0.28), dark, 0.2, 0.6, Vector3(-75, 0, 0))
	head = Node3D.new()
	head.position = Vector3(0, 1.86, 0)
	char_root.add_child(head)
	var hs := MeshInstance3D.new()
	var hsm := SphereMesh.new()
	hsm.radius = 0.15
	hsm.height = 0.3
	hsm.radial_segments = 16
	hsm.rings = 8
	var skm := StandardMaterial3D.new()
	skm.albedo_color = skin
	hsm.material = skm
	hs.mesh = hsm
	head.add_child(hs)
	var hl := MeshInstance3D.new()
	var hlm := SphereMesh.new()
	hlm.radius = 0.19
	hlm.height = 0.19
	hlm.is_hemisphere = true
	hlm.radial_segments = 16
	hlm.rings = 8
	var hmt := StandardMaterial3D.new()
	hmt.albedo_color = dark
	hmt.metallic = 0.6
	hmt.roughness = 0.35
	hlm.material = hmt
	hl.mesh = hlm
	hl.position = Vector3(0, 0.02, 0)
	head.add_child(hl)
	var band := MeshInstance3D.new()
	var bnd := CylinderMesh.new()
	bnd.top_radius = 0.195
	bnd.bottom_radius = 0.195
	bnd.height = 0.03
	bnd.radial_segments = 16
	bnd.rings = 1
	var bmt := StandardMaterial3D.new()
	bmt.albedo_color = red
	bmt.emission_enabled = true
	bmt.emission = red
	bnd.material = bmt
	band.mesh = bnd
	band.position = Vector3(0, 0.02, 0)
	head.add_child(band)
	_cb(head, Vector3(0.3, 0.07, 0.05), Vector3(0, -0.01, 0.15), red, 0.0, 0.5, Vector3.ZERO, true)
	_cb(head, Vector3(0.2, 0.1, 0.08), Vector3(0, -0.09, 0.13), dark)
	var rifle := Global.build_weapon("rifle", 3)
	rifle.scale = Vector3.ONE * 1.5
	rifle.position = Vector3(0.02, 1.28, 0.32)
	rifle.rotation_degrees = Vector3(8, 72, 6)
	char_root.add_child(rifle)
	cape = Node3D.new()
	cape.position = Vector3(0, 1.66, -0.48)
	char_root.add_child(cape)
	_cb(cape, Vector3(0.5, 0.85, 0.03), Vector3(0, -0.42, 0), red.darkened(0.25), 0.0, 0.8)
	# cincin cahaya di kaki
	ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.66
	tm.outer_radius = 0.74
	var rmt := StandardMaterial3D.new()
	rmt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmt.albedo_color = Color(1.0, 0.1, 0.14)
	tm.material = rmt
	ring.mesh = tm
	ring.position = Vector3(0, 0.03, 0)
	char_root.add_child(ring)
	var disc := MeshInstance3D.new()
	var dc := CylinderMesh.new()
	dc.top_radius = 0.66
	dc.bottom_radius = 0.66
	dc.height = 0.01
	dc.radial_segments = 24
	dc.rings = 1
	var dmt := StandardMaterial3D.new()
	dmt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmt.albedo_color = Color(1.0, 0.1, 0.14, 0.28)
	dc.material = dmt
	disc.mesh = dc
	disc.position = Vector3(0, 0.02, 0)
	char_root.add_child(disc)

func _fit_bg() -> void:
	var vs := get_viewport().get_visible_rect().size
	var asp := vs.x / vs.y
	var vis_h := 2.0 * 30.0 * tan(deg_to_rad(cam.fov) / 2.0)
	var vis_w := vis_h * asp
	var qh := maxf(vis_h, vis_w / bg_aspect) * 1.08 * (1.0 + sin(t * 0.4) * 0.01)
	bg_quad.scale = Vector3(qh * bg_aspect, qh, 1.0)
	bg_quad.position.x = sin(t * 0.3) * 0.5

func _process(delta: float) -> void:
	t += delta
	_fit_bg()
	drag_idle += delta
	if drag_idle > 2.0:
		drag_yaw = lerpf(drag_yaw, 0.0, 2.0 * delta)
	char_root.rotation.y = sin(t * 0.5) * 0.3 + drag_yaw
	torso.scale.y = 1.0 + sin(t * 1.8) * 0.012
	head.position.y = 1.86 + sin(t * 1.8 + 0.4) * 0.006
	cape.rotation.x = sin(t * 1.6) * 0.08
	cape.rotation.z = sin(t * 1.1) * 0.05
	ring.scale = Vector3.ONE * (1.0 + sin(t * 3.0) * 0.04)
	if logo_rect:
		var k := 1.0 + sin(t * 2.0) * 0.015
		logo_rect.scale = Vector2(k, k)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		var vs := get_viewport().get_visible_rect().size
		var p: Vector2 = event.position
		if p.x > vs.x * 0.28 and p.x < vs.x * 0.72 and p.y > vs.y * 0.15:
			drag_yaw += event.relative.x * 0.012
			drag_idle = 0.0

# ---------------- UI ----------------

func _sbox(bg: Color, border: Color, bw: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(8)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func _anchor(c: Control, right: bool, bottom: bool, w: float, h: float, mx: float, my: float) -> void:
	c.anchor_left = 1.0 if right else 0.0
	c.anchor_right = c.anchor_left
	c.anchor_top = 1.0 if bottom else 0.0
	c.anchor_bottom = c.anchor_top
	if right:
		c.offset_left = -mx - w
		c.offset_right = -mx
	else:
		c.offset_left = mx
		c.offset_right = mx + w
	if bottom:
		c.offset_top = -my - h
		c.offset_bottom = -my
	else:
		c.offset_top = my
		c.offset_bottom = my + h

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	# vinyet gelap di tepi layar
	var vg := TextureRect.new()
	var gt := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.5, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.85)])
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	vg.texture = gt
	vg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vg.stretch_mode = TextureRect.STRETCH_SCALE
	vg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(vg)
	# logo kiri atas
	logo_rect = TextureRect.new()
	logo_rect.texture = Global.logo_tex()
	logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_rect.position = Vector2(18, 6)
	logo_rect.size = Vector2(190, 190)
	logo_rect.pivot_offset = Vector2(95, 95)
	logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(logo_rect)
	# kartu pemain kiri bawah
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _sbox(Color(0.05, 0.01, 0.02, 0.8), RED, 2))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(card, false, true, 340.0, 92.0, 28.0, 28.0)
	ui.add_child(card)
	var cv := VBoxContainer.new()
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(cv)
	var nm := Label.new()
	nm.text = "PEMAIN FREESHOT"
	nm.add_theme_font_size_override("font_size", 26)
	nm.add_theme_color_override("font_color", Color(1, 1, 1))
	cv.add_child(nm)
	stat_label = Label.new()
	stat_label.add_theme_font_size_override("font_size", 20)
	stat_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
	cv.add_child(stat_label)
	# gear kanan atas
	gear_btn = FxBtn.new()
	gear_btn.circle = true
	_anchor(gear_btn, true, false, 84.0, 84.0, 20.0, 16.0)
	gear_btn.pressed.connect(_open_settings)
	ui.add_child(gear_btn)
	# tombol main + mode kanan bawah
	play_btn = FxBtn.new()
	play_btn.text = "MAIN"
	play_btn.icon = "play"
	play_btn.primary = true
	play_btn.font_size = 60
	_anchor(play_btn, true, true, 440.0, 128.0, 28.0, 28.0)
	play_btn.pressed.connect(_start_game)
	ui.add_child(play_btn)
	mode_btn = FxBtn.new()
	mode_btn.icon = "mode"
	mode_btn.font_size = 32
	_anchor(mode_btn, true, true, 440.0, 76.0, 28.0, 28.0 + 128.0 + 14.0)
	mode_btn.pressed.connect(_open_modes)
	ui.add_child(mode_btn)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	ui.add_child(overlay)

func _refresh() -> void:
	mode_btn.text = Global.MODE_NAMES[Global.mode]
	stat_label.text = "MENANG %d   |   KILL %d" % [Global.best_wave, Global.best_kills]

func _start_game() -> void:
	if starting:
		return
	starting = true
	Global.save_all()
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.5)
	await tw.finished
	get_tree().change_scene_to_file("res://game.tscn")

# ---------------- POPUP ----------------

func _clear_overlay() -> void:
	for c in overlay.get_children():
		c.queue_free()

func _close_overlay() -> void:
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_overlay()

func _show_overlay() -> void:
	_clear_overlay()
	overlay.visible = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.18)

func _dim() -> ColorRect:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	return dim

func _dim_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		_close_overlay()

func _open_modes() -> void:
	_show_overlay()
	var dim := _dim()
	dim.gui_input.connect(_dim_input)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.anchor_left = 1.0
	box.anchor_right = 1.0
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -520.0
	box.offset_right = -28.0
	box.offset_top = -130.0
	box.offset_bottom = 130.0
	overlay.add_child(box)
	for i in 2:
		var b := FxBtn.new()
		b.text = Global.MODE_NAMES[i]
		b.sub = Global.MODE_DESC[i]
		b.font_size = 38
		b.selected = Global.mode == i
		b.custom_minimum_size = Vector2(0, 118)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_pick_mode.bind(i))
		box.add_child(b)

func _pick_mode(i: int) -> void:
	Global.mode = i
	Global.save_all()
	_refresh()
	_close_overlay()

# ---------------- SETTINGS ----------------

func _fbtn(parent: Node, text: String, cb: Callable, h: float = 64.0, accent: Color = RED) -> Control:
	var b := FxBtn.new()
	b.text = text
	b.font_size = 28
	b.accent = accent
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if cb.is_valid():
		b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _slider(parent: Node, label_text: String, minv: float, maxv: float, val: float, cb: Callable) -> void:
	var l := Label.new()
	l.text = label_text
	l.add_theme_font_size_override("font_size", 24)
	parent.add_child(l)
	var s := HSlider.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = 0.05
	s.value = val
	s.custom_minimum_size = Vector2(0, 40)
	s.add_theme_stylebox_override("slider", _sbox(Color(0.15, 0.03, 0.05), Color(0.4, 0.1, 0.12), 1))
	s.add_theme_stylebox_override("grabber_area", _sbox(RED.darkened(0.3), RED, 1))
	s.add_theme_stylebox_override("grabber_area_highlight", _sbox(RED, RED.lightened(0.3), 1))
	s.value_changed.connect(cb)
	parent.add_child(s)

func _open_settings() -> void:
	_show_overlay()
	var dim := _dim()
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cc)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _sbox(Color(0.06, 0.01, 0.02, 0.97), RED, 3))
	cc.add_child(pc)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(820, 0)
	v.add_theme_constant_override("separation", 12)
	pc.add_child(v)
	var title := Label.new()
	title.text = "PENGATURAN"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.add_theme_color_override("font_outline_color", RED)
	title.add_theme_constant_override("outline_size", 6)
	v.add_child(title)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 400)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var iv := VBoxContainer.new()
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	iv.add_theme_constant_override("separation", 12)
	sc.add_child(iv)
	var diff := _fbtn(iv, "", Callable())
	diff.text = _diff_text()
	diff.pressed.connect(_cycle_diff.bind(diff))
	_slider(iv, "Sensitivitas bidik", 0.3, 2.5, Global.sens, _on_sens)
	_slider(iv, "Volume", 0.0, 1.0, Global.volume, _on_volume)
	var q := _fbtn(iv, "", Callable())
	q.text = _qtext()
	q.pressed.connect(_cycle_quality.bind(q))
	_fbtn(iv, "ATUR HUD  (POSISI & UKURAN)", _open_hud_editor, 64, Color(0.3, 0.6, 1.0))
	var note := Label.new()
	note.text = "Jarak objek membatasi render rumah, pohon, dll. Tanah dan laut tetap tampil penuh. Berlaku di permainan berikutnya."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(760, 0)
	note.add_theme_font_size_override("font_size", 18)
	note.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
	iv.add_child(note)
	var help := Label.new()
	help.text = "CARA MAIN\nBattle Royale: terjun dari pesawat bersama 49 bot (tombol hijau lompat, biru parasut). Setelah 3 menit zona biru muncul dan menyusut 5 tahap, di luar zona nyawa berkurang makin cepat.\nClash Squad: 4 vs 4, menang 4 ronde. Beli senjata di toko sebelum ronde mulai.\nGeser kiri: jalan. Geser kanan: bidik. Tombol peluru: tembak. Panah melingkar: reload. Teropong: zoom. Tambah: medkit.\nCahaya tinggi = loot (dekati lalu tekan tombol tangan). Kulkas cahaya emas = toko (ikon keranjang).\nRumah bisa dimasuki. Ada pabrik, reaktor nuklir, depot BBM, dan menara radio."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(760, 0)
	help.add_theme_font_size_override("font_size", 20)
	iv.add_child(help)
	_fbtn(iv, "KELUAR GAME", _quit, 60, Color(0.6, 0.6, 0.65))
	var close := _fbtn(v, "TUTUP", _close_overlay, 70)
	close.primary = true
	dim.gui_input.connect(_dim_input)

func _open_hud_editor() -> void:
	_show_overlay()
	var ed := preload("res://hudedit.gd").new()
	ed.finished.connect(_close_overlay)
	overlay.add_child(ed)

func _diff_text() -> String:
	return "KESULITAN: " + Global.DIFF_NAMES[Global.difficulty]

func _cycle_diff(b: Control) -> void:
	Global.difficulty = (Global.difficulty + 1) % 3
	Global.save_all()
	b.text = _diff_text()

func _qtext() -> String:
	return "JARAK OBJEK: %s (%d m)" % [Global.VIEW_NAMES[Global.quality], int(Global.view_dist())]

func _cycle_quality(b: Control) -> void:
	Global.quality = (Global.quality + 1) % 3
	Global.save_all()
	b.text = _qtext()

func _on_sens(x: float) -> void:
	Global.sens = x
	Global.save_all()

func _on_volume(x: float) -> void:
	Global.volume = x
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(x, 0.001)))
	Global.save_all()

func _quit() -> void:
	get_tree().quit()
