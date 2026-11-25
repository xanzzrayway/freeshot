extends Control

var sub := ""
var progress := 0.0
var count := -1
var total := 50
var mode := 0
var t := 0.0
var logo: Texture2D

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	logo = Global.logo_tex()

func _process(d: float) -> void:
	t += d
	queue_redraw()

func _draw() -> void:
	var s := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	var gold := Color(1.0, 0.75, 0.15)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.04, 0.07))
	for i in 8:
		var y := fposmod(t * 40.0 + i * 120.0, s.y + 120.0) - 60.0
		draw_line(Vector2(0, y), Vector2(s.x, y - 80.0), Color(1, 0.75, 0.15, 0.05), 40.0)
	if logo:
		draw_texture_rect(logo, Rect2(s.x / 2.0 - 75.0, 14.0, 150.0, 150.0), false)
	var c := Vector2(s.x / 2.0, s.y * 0.46)
	for i in 3:
		var sp := 2.2 - i * 0.7
		var a0 := t * sp + i * 2.1
		draw_arc(c, 54.0 + i * 18.0, a0, a0 + 2.4, 28, Color(1.0, 0.75, 0.15, 1.0 - i * 0.25), 7.0)
	draw_circle(c, 9.0 + sin(t * 4.0) * 2.5, gold)
	var title := "MENCARI MATCH" if count < 0 else "LOBI PERTANDINGAN"
	draw_string(font, Vector2(0, c.y + 135), title, HORIZONTAL_ALIGNMENT_CENTER, s.x, 46, gold)
	var line := ""
	if count >= 0:
		line = "%s %d/%d" % [sub, count, total]
	else:
		line = sub + ".".repeat(int(t * 2.0) % 4)
	draw_string(font, Vector2(0, c.y + 185), line, HORIZONTAL_ALIGNMENT_CENTER, s.x, 34, Color(0.9, 0.93, 1.0))
	var bw := minf(s.x * 0.6, 640.0)
	var bx := (s.x - bw) / 2.0
	var by := c.y + 220.0
	draw_rect(Rect2(bx, by, bw, 14), Color(1, 1, 1, 0.12))
	var p := progress
	if count >= 0:
		p = float(count) / float(total)
	draw_rect(Rect2(bx, by, bw * clampf(p, 0.0, 1.0), 14), gold)
