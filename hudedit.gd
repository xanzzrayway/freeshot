extends Control

const FxBtn := preload("res://fxbtn.gd")
signal finished

var sel := ""
var dragging := false
var slider: HSlider

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var top := HBoxContainer.new()
	top.anchor_left = 0.5
	top.anchor_right = 0.5
	top.anchor_top = 0.0
	top.anchor_bottom = 0.0
	top.offset_left = -400.0
	top.offset_right = 400.0
	top.offset_top = 8.0
	top.offset_bottom = 72.0
	top.add_theme_constant_override("separation", 14)
	add_child(top)
	var l := Label.new()
	l.text = "UKURAN"
	l.add_theme_font_size_override("font_size", 22)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(l)
	slider = HSlider.new()
	slider.min_value = 0.7
	slider.max_value = 1.5
	slider.step = 0.05
	slider.value = Global.hud_scale
	slider.custom_minimum_size = Vector2(260, 40)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(_on_scale)
	top.add_child(slider)
	var reset := FxBtn.new()
	reset.text = "RESET"
	reset.font_size = 26
	reset.custom_minimum_size = Vector2(170, 56)
	reset.pressed.connect(_reset)
	top.add_child(reset)
	var ok := FxBtn.new()
	ok.text = "SELESAI"
	ok.font_size = 26
	ok.primary = true
	ok.custom_minimum_size = Vector2(210, 56)
	ok.pressed.connect(_done)
	top.add_child(ok)

func _on_scale(v: float) -> void:
	Global.hud_scale = v
	queue_redraw()

func _reset() -> void:
	Global.hud_custom.clear()
	Global.hud_scale = 1.0
	slider.value = 1.0
	Global.save_all()
	queue_redraw()

func _done() -> void:
	Global.save_all()
	finished.emit()

func _pick(p: Vector2) -> String:
	var names := Global.HUD_NAMES
	for i in range(names.size() - 1, -1, -1):
		var nm: String = names[i]
		var c := Global.hud_pos(nm, size)
		var h := Global.hud_half(nm)
		if absf(p.x - c.x) <= h.x and absf(p.y - c.y) <= h.y:
			return nm
	return ""

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			sel = _pick(e.position)
			dragging = sel != ""
		else:
			dragging = false
			if sel != "":
				Global.save_all()
		queue_redraw()
	elif e is InputEventMouseMotion and dragging and sel != "":
		var p: Vector2 = e.position
		p = p.clamp(Vector2(30, 90), size - Vector2(30, 30))
		Global.hud_custom[sel] = Vector2(p.x / size.x, p.y / size.y)
		queue_redraw()

func _draw() -> void:
	var s := size
	var k := Global.hud_scale
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.0, 0.03, 0.92))
	for x in range(0, int(s.x), 80):
		draw_line(Vector2(x, 0), Vector2(x, s.y), Color(1, 1, 1, 0.04), 1.0)
	for y in range(0, int(s.y), 80):
		draw_line(Vector2(0, y), Vector2(s.x, y), Color(1, 1, 1, 0.04), 1.0)
	draw_rect(Rect2(Vector2(2, 2), s - Vector2(4, 4)), Color(1, 0.1, 0.14, 0.5), false, 3.0)
	for nm in Global.HUD_NAMES:
		var p := Global.hud_pos(nm, s)
		var h := Global.hud_half(nm)
		var col := Color(1, 0.1, 0.14, 0.35)
		if nm == sel:
			col = Color(1, 0.8, 0.2, 0.55)
		match nm:
			"fire", "reload", "scope", "heal", "use":
				draw_circle(p, h.x, col)
				draw_arc(p, h.x, 0.0, TAU, 32, Color(1, 1, 1, 0.8), 2.0)
			"slots":
				for i in 3:
					var sp := p + Vector2((i - 1) * 90.0 * k, 0.0)
					draw_circle(sp, 36.0 * k, col)
					draw_arc(sp, 36.0 * k, 0.0, TAU, 24, Color(1, 1, 1, 0.8), 2.0)
			_:
				draw_rect(Rect2(p - h, h * 2.0), col)
				draw_rect(Rect2(p - h, h * 2.0), Color(1, 1, 1, 0.8), false, 2.0)
		draw_string(font, p + Vector2(-h.x, 7.0), Global.HUD_LABELS[nm], HORIZONTAL_ALIGNMENT_CENTER, h.x * 2.0, 18)
	draw_string(font, Vector2(0, s.y - 16.0), "Seret elemen untuk memindahkan. Tekan SELESAI untuk menyimpan.", HORIZONTAL_ALIGNMENT_CENTER, s.x, 20, Color(1, 0.7, 0.7))
