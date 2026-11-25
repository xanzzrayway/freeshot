extends Control

signal pressed

var text := ""
var sub := ""
var icon := ""           # "gear", "mode", "play"
var accent := Color(1.0, 0.1, 0.14)
var font_size := 34
var skew := 16.0
var primary := false
var selected := false
var circle := false
var hover := false
var down := false
var t := 0.0
var rot := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	pivot_offset = size / 2.0
	resized.connect(_on_resized)
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)

func _on_resized() -> void:
	pivot_offset = size / 2.0

func _on_enter() -> void:
	hover = true

func _on_exit() -> void:
	hover = false
	down = false

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			down = true
			_punch(0.94)
		else:
			var was := down
			down = false
			_punch(1.0)
			if was and Rect2(Vector2.ZERO, size).has_point(e.position):
				pressed.emit()

func _punch(s: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(s, s), 0.08)

func _process(d: float) -> void:
	t += d
	rot += d * (2.5 if (hover or down) else 0.5)
	queue_redraw()

func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var c := pts.duplicate()
	c.append(pts[0])
	return c

func _draw() -> void:
	var w := size.x
	var h := size.y
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	var lit := hover or down or selected
	if circle:
		var cc := size / 2.0
		var r := minf(w, h) / 2.0 - 8.0
		for i in 4:
			draw_arc(cc, r + 3.0 + i * 4.0, 0.0, TAU, 40, Color(accent.r, accent.g, accent.b, (0.2 + 0.12 * pulse) * (1.0 - i * 0.22)), 4.0)
		draw_circle(cc, r, Color(0.06, 0.01, 0.02, 0.92))
		draw_arc(cc, r, 0.0, TAU, 48, accent.lightened(0.15 if lit else 0.0), 3.0)
		_ic_gear(cc, r * 0.58, Color(1, 1, 1, 0.95), rot)
		return
	var sk := skew
	var pts := PackedVector2Array([Vector2(sk, 0), Vector2(w, 0), Vector2(w - sk, h), Vector2(0, h)])
	var ga := (0.16 + 0.12 * pulse) if primary else 0.1
	if lit:
		ga += 0.12
	for i in 4:
		draw_polyline(_closed(pts), Color(accent.r, accent.g, accent.b, ga * (1.0 - i * 0.22)), 4.0 + i * 5.0)
	var dark := Color(0.05, 0.01, 0.02, 0.92)
	var c1 := accent.darkened(0.1) if primary else Color(0.14, 0.02, 0.05, 0.92)
	var c2 := accent.darkened(0.6) if primary else dark
	if selected and not primary:
		c1 = accent.darkened(0.45)
	draw_polygon(pts, PackedColorArray([c1, c2, c2, c1]))
	var bc := accent.lightened(0.25) if lit else accent
	draw_polyline(_closed(pts), bc, 3.5 if (selected or primary) else 2.0)
	# kilau bergerak
	var sx := fposmod(t * 140.0, w + 220.0) - 110.0
	var x0 := clampf(sx, sk, w - sk)
	var x1 := clampf(sx + 34.0, sk, w - sk)
	if x1 - x0 > 3.0:
		draw_colored_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1 - sk, h), Vector2(x0 - sk, h)]), Color(1, 1, 1, 0.2 if primary else 0.09))
	# teks
	var font := ThemeDB.fallback_font
	var left := sk + 20.0
	var has_icon := icon == "mode"
	var tx := left + (46.0 if has_icon else 0.0)
	var tw := w - tx - sk - (74.0 if icon == "play" else (36.0 if icon == "mode" else 12.0))
	var al := HORIZONTAL_ALIGNMENT_LEFT
	if primary:
		tx = sk
		al = HORIZONTAL_ALIGNMENT_CENTER
		tw = w - sk * 2.0 - 70.0
	var by := h * 0.5 + font_size * 0.35
	if sub != "":
		by = h * 0.44 + font_size * 0.3
		draw_string(font, Vector2(tx, h - 14.0), sub, al, tw, maxi(16, int(font_size * 0.5)), Color(1.0, 0.75, 0.75, 0.85))
	draw_string_outline(font, Vector2(tx, by), text, al, tw, font_size, 6, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(tx, by), text, al, tw, font_size, Color(1, 1, 1, 1))
	if has_icon:
		_ic_cross(Vector2(left + 16.0, h / 2.0), 15.0, Color(1, 1, 1, 0.95))
		draw_colored_polygon(PackedVector2Array([Vector2(w - sk - 38.0, h / 2.0 - 5.0), Vector2(w - sk - 22.0, h / 2.0 - 5.0), Vector2(w - sk - 30.0, h / 2.0 + 6.0)]), Color(1, 1, 1, 0.9))
	if icon == "play":
		for i in 3:
			var a := 0.3 + 0.7 * maxf(0.0, sin(t * 4.0 - i * 0.8))
			var px := w - sk - 62.0 + i * 18.0
			draw_polyline(PackedVector2Array([Vector2(px, h / 2.0 - 16.0), Vector2(px + 14.0, h / 2.0), Vector2(px, h / 2.0 + 16.0)]), Color(1, 1, 1, a), 5.0)

func _ic_gear(c: Vector2, r: float, col: Color, a: float) -> void:
	draw_circle(c, r * 0.74, col)
	for i in 8:
		draw_set_transform(c, a + float(i) * TAU / 8.0, Vector2.ONE)
		draw_rect(Rect2(-r * 0.15, -r, r * 0.3, r * 0.32), col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(c, r * 0.34, Color(0.06, 0.01, 0.02))

func _ic_cross(c: Vector2, r: float, col: Color) -> void:
	draw_arc(c, r * 0.7, 0.0, TAU, 24, col, 2.5)
	draw_line(c + Vector2(-r, 0), c + Vector2(-r * 0.35, 0), col, 2.5)
	draw_line(c + Vector2(r, 0), c + Vector2(r * 0.35, 0), col, 2.5)
	draw_line(c + Vector2(0, -r), c + Vector2(0, -r * 0.35), col, 2.5)
	draw_line(c + Vector2(0, r), c + Vector2(0, r * 0.35), col, 2.5)
