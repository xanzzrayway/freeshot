extends Control

const DUR := 3.6
var t := 0.0
var logo: TextureRect
var fade: ColorRect
var embers: CPUParticles2D
var going := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	embers = CPUParticles2D.new()
	embers.amount = 70
	embers.lifetime = 4.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(700, 4)
	embers.direction = Vector2(0, -1)
	embers.spread = 18.0
	embers.gravity = Vector2.ZERO
	embers.initial_velocity_min = 60.0
	embers.initial_velocity_max = 170.0
	embers.scale_amount_min = 2.0
	embers.scale_amount_max = 5.0
	embers.color = Color(1.0, 0.15, 0.1, 0.9)
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.3, 0.2, 1.0))
	g.set_color(1, Color(1, 0.05, 0.05, 0.0))
	embers.color_ramp = g
	add_child(embers)
	logo = TextureRect.new()
	logo.texture = Global.logo_tex()
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.modulate.a = 0.0
	logo.scale = Vector2(0.8, 0.8)
	add_child(logo)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(logo, "modulate:a", 1.0, 0.9)
	tw.tween_property(logo, "scale", Vector2.ONE, 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(d: float) -> void:
	t += d
	var vs := get_viewport_rect().size
	var s := minf(vs.y * 0.8, 620.0)
	logo.size = Vector2(s, s)
	logo.pivot_offset = Vector2(s, s) / 2.0
	logo.position = (vs - Vector2(s, s)) / 2.0 + Vector2(0, -vs.y * 0.04)
	embers.position = Vector2(vs.x / 2.0, vs.y + 10.0)
	embers.emission_rect_extents = Vector2(vs.x / 2.0, 4.0)
	if t > 1.3:
		var k := 1.0 + sin(t * 2.4) * 0.012
		logo.scale = Vector2(k, k)
	queue_redraw()
	if t > DUR:
		_go()

func _draw() -> void:
	var vs := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	var c := vs / 2.0 + Vector2(0, -vs.y * 0.04)
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	var a := clampf(t / 0.8, 0.0, 1.0)
	for i in 7:
		draw_circle(c, vs.y * (0.18 + i * 0.07), Color(1.0, 0.05, 0.05, 0.05 * a * (0.6 + 0.4 * pulse) * (1.0 - float(i) / 7.0)))
	var y := fposmod(t * 260.0, vs.y + 80.0) - 40.0
	draw_rect(Rect2(0, y, vs.x, 3), Color(1, 0.1, 0.1, 0.2 * a))
	for i in 5:
		var x := fposmod(t * 90.0 + i * 340.0, vs.x + 400.0) - 200.0
		draw_line(Vector2(x, vs.y), Vector2(x + 220.0, 0.0), Color(1, 0.1, 0.1, 0.05), 26.0)
	if logo.texture == null:
		draw_string(font, c + Vector2(-vs.x / 2.0, 20.0), "FREESHOT", HORIZONTAL_ALIGNMENT_CENTER, vs.x, 90, Color(1, 0.1, 0.14, a))
	var bw := minf(vs.x * 0.5, 420.0)
	var bx := (vs.x - bw) / 2.0
	var by := vs.y - 64.0
	draw_rect(Rect2(bx, by, bw, 6), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(bx, by, bw * clampf(t / DUR, 0.0, 1.0), 6), Color(1, 0.1, 0.14))
	draw_string(font, Vector2(0, by - 14.0), "MEMUAT", HORIZONTAL_ALIGNMENT_CENTER, vs.x, 18, Color(1, 0.6, 0.6, 0.8))
	draw_string(font, Vector2(0, vs.y - 22.0), "ABID STUDIO", HORIZONTAL_ALIGNMENT_CENTER, vs.x, 16, Color(1, 1, 1, 0.35))

func _input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		_go()

func _go() -> void:
	if going:
		return
	going = true
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.35)
	await tw.finished
	get_tree().change_scene_to_file("res://menu.tscn")
