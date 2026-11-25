extends Control

var player
var game
var map_tex: Texture2D
var map_half := 512.0
var hurt_a := 0.0
var hit_a := 0.0
var hit_head := false
var banner_t := 0.0
var banner_txt := ""
var toast_t := 0.0
var toast_txt := ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.hurt.connect(_on_hurt)
	player.hit.connect(_on_hit)

func _on_hurt() -> void:
	hurt_a = 0.5

func _on_hit(head: bool) -> void:
	hit_a = 0.2
	hit_head = head

func banner(t: String) -> void:
	banner_txt = t
	banner_t = 2.5

func toast(t: String) -> void:
	toast_txt = t
	toast_t = 2.0

func _process(d: float) -> void:
	hurt_a = maxf(0.0, hurt_a - d)
	hit_a -= d
	banner_t -= d
	toast_t -= d
	queue_redraw()

# ---------------- IKON ----------------

func _ic_bullet(c: Vector2, k: float, col: Color) -> void:
	draw_rect(Rect2(c + Vector2(-7, -2) * k, Vector2(14, 26) * k), col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -2) * k, c + Vector2(7, -2) * k, c + Vector2(0, -26) * k]), col)
	draw_rect(Rect2(c + Vector2(-9, 25) * k, Vector2(18, 4) * k), col)

func _ic_reload(c: Vector2, k: float, col: Color) -> void:
	var r := 20.0 * k
	draw_arc(c, r, -PI * 0.8, PI * 0.55, 24, col, 5.0 * k)
	var a := PI * 0.55
	var n := Vector2(cos(a), sin(a))
	var t := Vector2(-sin(a), cos(a))
	var p := c + n * r
	draw_colored_polygon(PackedVector2Array([p + t * 12.0 * k, p + n * 9.0 * k, p - n * 9.0 * k]), col)

func _ic_scope(c: Vector2, k: float, col: Color) -> void:
	draw_arc(c, 20.0 * k, 0.0, TAU, 32, col, 3.0 * k)
	draw_line(c + Vector2(-30, 0) * k, c + Vector2(-8, 0) * k, col, 3.0 * k)
	draw_line(c + Vector2(30, 0) * k, c + Vector2(8, 0) * k, col, 3.0 * k)
	draw_line(c + Vector2(0, -30) * k, c + Vector2(0, -8) * k, col, 3.0 * k)
	draw_line(c + Vector2(0, 30) * k, c + Vector2(0, 8) * k, col, 3.0 * k)
	draw_circle(c, 2.5 * k, col)

func _ic_medkit(c: Vector2, k: float) -> void:
	draw_rect(Rect2(c + Vector2(-20, -14) * k, Vector2(40, 30) * k), Color(0.95, 0.95, 0.95))
	draw_rect(Rect2(c + Vector2(-8, -22) * k, Vector2(16, 8) * k), Color(0.95, 0.95, 0.95))
	draw_rect(Rect2(c + Vector2(-4, -10) * k, Vector2(8, 22) * k), Color(0.9, 0.1, 0.1))
	draw_rect(Rect2(c + Vector2(-11, -3) * k, Vector2(22, 8) * k), Color(0.9, 0.1, 0.1))

func _ic_pickup(c: Vector2, k: float, col: Color) -> void:
	draw_line(c + Vector2(0, -20) * k, c + Vector2(0, 4) * k, col, 5.0 * k)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-11, 0) * k, c + Vector2(11, 0) * k, c + Vector2(0, 14) * k]), col)
	draw_polyline(PackedVector2Array([c + Vector2(-18, 6) * k, c + Vector2(-18, 20) * k, c + Vector2(18, 20) * k, c + Vector2(18, 6) * k]), col, 4.0 * k)

func _ic_cart(c: Vector2, k: float, col: Color) -> void:
	draw_polyline(PackedVector2Array([c + Vector2(-24, -16) * k, c + Vector2(-15, -16) * k, c + Vector2(-8, 8) * k, c + Vector2(14, 8) * k, c + Vector2(19, -8) * k, c + Vector2(-13, -8) * k]), col, 4.0 * k)
	draw_circle(c + Vector2(-4, 16) * k, 4.5 * k, col)
	draw_circle(c + Vector2(11, 16) * k, 4.5 * k, col)

func _ic_jump(c: Vector2, k: float, col: Color) -> void:
	for i in 2:
		var y := (-14.0 + i * 16.0) * k
		draw_polyline(PackedVector2Array([c + Vector2(-16 * k, y), c + Vector2(0, y + 14.0 * k), c + Vector2(16 * k, y)]), col, 5.0 * k)

func _ic_chute(c: Vector2, k: float, col: Color) -> void:
	var top := c + Vector2(0, -6) * k
	draw_arc(top, 24.0 * k, PI, TAU, 20, col, 5.0 * k)
	var man := c + Vector2(0, 22) * k
	draw_line(top + Vector2(-24, 0) * k, man, col, 2.0 * k)
	draw_line(top + Vector2(24, 0) * k, man, col, 2.0 * k)
	draw_line(top, man, col, 2.0 * k)
	draw_circle(man + Vector2(0, 3) * k, 4.0 * k, col)

func _ic_weapon(c: Vector2, id: String, k: float, col: Color) -> void:
	match id:
		"pistol":
			draw_rect(Rect2(c + Vector2(-14, -6) * k, Vector2(26, 8) * k), col)
			draw_rect(Rect2(c + Vector2(-8, 2) * k, Vector2(8, 14) * k), col)
		"smg":
			draw_rect(Rect2(c + Vector2(-14, -5) * k, Vector2(28, 8) * k), col)
			draw_rect(Rect2(c + Vector2(-2, 3) * k, Vector2(5, 14) * k), col)
			draw_rect(Rect2(c + Vector2(-20, -3) * k, Vector2(6, 3) * k), col)
		"rifle":
			draw_rect(Rect2(c + Vector2(-20, -4) * k, Vector2(36, 7) * k), col)
			draw_rect(Rect2(c + Vector2(16, -3) * k, Vector2(10, 3) * k), col)
			draw_rect(Rect2(c + Vector2(-27, -5) * k, Vector2(8, 10) * k), col)
			draw_rect(Rect2(c + Vector2(-3, 3) * k, Vector2(5, 12) * k), col)
		"shotgun":
			draw_rect(Rect2(c + Vector2(-4, -4) * k, Vector2(30, 4) * k), col)
			draw_rect(Rect2(c + Vector2(-14, -5) * k, Vector2(14, 8) * k), col)
			draw_rect(Rect2(c + Vector2(-25, -3) * k, Vector2(11, 8) * k), col)
		"sniper":
			draw_rect(Rect2(c + Vector2(-26, -2) * k, Vector2(54, 4) * k), col)
			draw_rect(Rect2(c + Vector2(-8, -9) * k, Vector2(16, 5) * k), col)
			draw_rect(Rect2(c + Vector2(-30, -4) * k, Vector2(8, 9) * k), col)
		"lmg":
			draw_rect(Rect2(c + Vector2(-20, -5) * k, Vector2(36, 8) * k), col)
			draw_rect(Rect2(c + Vector2(16, -3) * k, Vector2(10, 3) * k), col)
			draw_rect(Rect2(c + Vector2(-8, 3) * k, Vector2(12, 11) * k), col)
			draw_line(c + Vector2(14, 3) * k, c + Vector2(20, 16) * k, col, 2.0 * k)

func _draw_scope(s: Vector2, c: Vector2, lv: int) -> void:
	var font := ThemeDB.fallback_font
	var r := s.y * 0.42
	var wdt := s.length() * 2.0
	draw_arc(c, r + wdt * 0.5, 0.0, TAU, 128, Color(0, 0, 0, 1), wdt)
	draw_arc(c, r, 0.0, TAU, 96, Color(0, 0, 0, 1), 5.0)
	draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), Color(0, 0, 0, 0.9), 2.0)
	draw_line(c + Vector2(0, -r), c + Vector2(0, r), Color(0, 0, 0, 0.9), 2.0)
	for i in range(-4, 5):
		if i != 0:
			draw_circle(c + Vector2(i * r * 0.12, 0), 3.0, Color(0, 0, 0, 0.9))
	draw_circle(c, 3.0, Color(1, 0.1, 0.1))
	draw_string(font, c + Vector2(r * 0.5, r * 0.88), "LV%d  x%.0f" % [lv, Global.SCOPE_ZOOM[lv]], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.9))

func _arc_clip(c: Vector2, r: float, rect: Rect2, col: Color, w: float) -> void:
	var n := 48
	var prev := c + Vector2(r, 0.0)
	for i in range(1, n + 1):
		var a := TAU * float(i) / n
		var cur := c + Vector2(cos(a), sin(a)) * r
		if rect.has_point(prev) and rect.has_point(cur):
			draw_line(prev, cur, col, w)
		prev = cur

func _draw_minimap(s: Vector2) -> void:
	var sz := 170.0 * Global.hud_scale
	var pos := Global.hud_pos("minimap", s) - Vector2(sz, sz) / 2.0
	var rect := Rect2(pos, Vector2(sz, sz))
	draw_rect(Rect2(pos - Vector2(3, 3), Vector2(sz + 6, sz + 6)), Color(0, 0, 0, 0.6))
	if map_tex:
		draw_texture_rect(map_tex, rect, false)
	var k := sz / (map_half * 2.0)
	for sh in game.shops:
		if is_instance_valid(sh):
			var q := pos + Vector2(sh.global_position.x + map_half, sh.global_position.z + map_half) * k
			draw_circle(q, 3.5, Color(1, 0.85, 0.1))
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.team == 0:
			var aq := pos + Vector2(e.global_position.x + map_half, e.global_position.z + map_half) * k
			aq = aq.clamp(pos, pos + Vector2(sz, sz))
			draw_circle(aq, 3.0, Color(0.3, 0.6, 1.0))
		elif e.phase == 1 or e.phase == 2:
			var eq := pos + Vector2(e.global_position.x + map_half, e.global_position.z + map_half) * k
			eq = eq.clamp(pos, pos + Vector2(sz, sz))
			draw_circle(eq, 2.5, Color(1, 0.2, 0.2))
	if is_instance_valid(game.plane):
		var pq := pos + Vector2(game.plane.position.x + map_half, game.plane.position.z + map_half) * k
		pq = pq.clamp(pos, pos + Vector2(sz, sz))
		draw_circle(pq, 4.5, Color(1, 1, 1))
	if game.zone_active:
		var zc := pos + Vector2(game.zone_center.x + map_half, game.zone_center.y + map_half) * k
		_arc_clip(zc, game.zone_radius * k, rect, Color(0.3, 0.6, 1.0, 0.95), 2.5)
		var nc := pos + Vector2(game.zone_next_c.x + map_half, game.zone_next_c.y + map_half) * k
		_arc_clip(nc, game.zone_next_r * k, rect, Color(1, 1, 1, 0.9), 1.5)
	var pp := pos + Vector2(player.global_position.x + map_half, player.global_position.z + map_half) * k
	pp = pp.clamp(pos, pos + Vector2(sz, sz))
	var yaw: float = player.rotation.y
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var rgt := Vector2(-fwd.y, fwd.x)
	draw_colored_polygon(PackedVector2Array([pp + fwd * 8.0, pp - fwd * 5.0 + rgt * 5.0, pp - fwd * 5.0 - rgt * 5.0]), Color(0.2, 1.0, 0.3))

func _draw_bot_markers() -> void:
	var font := ThemeDB.fallback_font
	var cam: Camera3D = player.cam
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.phase != 1 and e.phase != 2:
			continue
		var wp: Vector3 = e.global_position + Vector3(0, 2.5, 0)
		if cam.is_position_behind(wp):
			continue
		var dist := cam.global_position.distance_to(wp)
		if dist > 600.0:
			continue
		var sp := cam.unproject_position(wp)
		draw_colored_polygon(PackedVector2Array([sp + Vector2(-9, -24), sp + Vector2(9, -24), sp + Vector2(0, -8)]), Color(1, 0.2, 0.2, 0.9))
		draw_string(font, sp + Vector2(-30, -28), "%dm" % int(dist), HORIZONTAL_ALIGNMENT_CENTER, 60, 16, Color(1, 0.85, 0.85))

func _count_air() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.phase == 1 or e.phase == 2:
			n += 1
	return n

func _fmt(sec: float) -> String:
	var t := int(ceil(sec))
	return "%d:%02d" % [t / 60, t % 60]

func _draw() -> void:
	var s := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	var ks := Global.hud_scale
	var st: int = player.state   # 0 pesawat, 1 terjun bebas, 2 parasut, 3 darat
	var c := s / 2.0
	var sl: int = player.scope_level
	var scoped_view: bool = st == 3 and player.scoped and sl >= 1
	if scoped_view:
		_draw_scope(s, c, sl)
	elif st == 3:
		draw_line(c + Vector2(-14, 0), c + Vector2(-4, 0), Color.WHITE, 2)
		draw_line(c + Vector2(14, 0), c + Vector2(4, 0), Color.WHITE, 2)
		draw_line(c + Vector2(0, -14), c + Vector2(0, -4), Color.WHITE, 2)
		draw_line(c + Vector2(0, 14), c + Vector2(0, 4), Color.WHITE, 2)
	if hit_a > 0:
		var hc := Color.RED if hit_head else Color.WHITE
		draw_line(c + Vector2(-9, -9), c + Vector2(9, 9), hc, 3)
		draw_line(c + Vector2(-9, 9), c + Vector2(9, -9), hc, 3)
	if hurt_a > 0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(1, 0, 0, hurt_a * 0.5))
	_draw_bot_markers()
	# nyawa dan armor (bisa dipindah di Pengaturan > Atur HUD)
	var hp_c := Global.hud_pos("hp", s)
	var bw := 420.0 * ks
	var bh := 26.0 * ks
	var bx := hp_c.x - bw / 2.0
	var by := hp_c.y - bh / 2.0
	draw_rect(Rect2(bx, by, bw, bh), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(bx, by, bw * clampf(float(player.hp) / float(player.max_hp), 0.0, 1.0), bh), Color(0.2, 0.9, 0.3))
	draw_rect(Rect2(bx, by, bw, bh), Color(1, 1, 1, 0.35), false, 2.0)
	if player.armor_max > 0.0:
		var ay := by - 16.0 * ks
		draw_rect(Rect2(bx, ay, bw, 12.0 * ks), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(bx, ay, bw * clampf(player.armor / player.armor_max, 0.0, 1.0), 12.0 * ks), Color(0.3, 0.55, 1.0))
	draw_string(font, Vector2(bx, by + bh * 0.78), "%d" % player.hp, HORIZONTAL_ALIGNMENT_CENTER, bw, int(20.0 * ks))
	var cc := Global.hud_pos("coins", s)
	draw_string(font, cc + Vector2(-80, 8) * ks, "KOIN %d" % player.coins, HORIZONTAL_ALIGNMENT_CENTER, 160.0 * ks, int(26.0 * ks), Color(1, 0.85, 0.2))
	# info atas
	var alt := int(player.global_position.y)
	var info := "MUSUH %d/%d" % [game.enemies_alive, game.total]
	if game.cs:
		var tc: Vector2i = game.team_counts()
		info = "RONDE %d   KAMI %d - %d MUSUH   |   %d vs %d" % [game.round_no, game.score_ally, game.score_enemy, tc.x, tc.y]
		if game.freeze:
			info += "   |   BELI DI TOKO"
	else:
		match st:
			0: info += "   |   Tombol hijau = LOMPAT"
			1: info += "   |   %d m   |   DI UDARA %d" % [alt, _count_air()]
			2: info += "   |   PARASUT %d m   |   DI UDARA %d" % [alt, _count_air()]
			3: info += "   |   KILL %d" % game.kills
	draw_string(font, Vector2(0, 50), info, HORIZONTAL_ALIGNMENT_CENTER, s.x - 400.0, 28)
	# zona
	if not game.cs:
		var zt := ""
		if not game.zone_active:
			zt = "ZONA MUNCUL DALAM %s" % _fmt(maxf(0.0, game.zone_appear - game.match_time))
		else:
			match game.zone_phase:
				"wait": zt = "ZONA %d/5   MENYUSUT DALAM %s" % [game.zone_stage, _fmt(game.zone_t)]
				"shrink": zt = "ZONA %d/5   MENYUSUT  %s" % [game.zone_stage, _fmt(game.zone_t)]
				_: zt = "ZONA TERAKHIR"
		draw_string(font, Vector2(0, 84), zt, HORIZONTAL_ALIGNMENT_CENTER, s.x - 400.0, 24, Color(0.5, 0.75, 1.0))
		if game.zone_outside:
			var pa := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
			draw_rect(Rect2(Vector2.ZERO, s), Color(0.6, 0.0, 0.1, 0.1 + 0.1 * pa))
			draw_string(font, Vector2(0, s.y * 0.2), "DI LUAR ZONA!  -%d HP/DETIK" % int(ceil(game.zone_dps_now)), HORIZONTAL_ALIGNMENT_CENTER, s.x, 36, Color(1, 0.2 + 0.4 * pa, 0.2))
	_draw_minimap(s)
	# jumlah peluru
	if st == 3:
		var ac := Global.hud_pos("ammo", s)
		var wid: String = player.slots[player.cur]
		var atxt := "RELOAD..." if player.reloading else "%d / INF" % player.ammo[wid]
		draw_string(font, ac + Vector2(-110, 8) * ks, atxt, HORIZONTAL_ALIGNMENT_CENTER, 220.0 * ks, int(28.0 * ks))
		if sl > 0:
			draw_string(font, ac + Vector2(-110, -18) * ks, "SCOPE LV%d" % sl, HORIZONTAL_ALIGNMENT_CENTER, 220.0 * ks, int(20.0 * ks), Color(0.3, 0.9, 1.0))
	# joystick
	var base := Vector2(200, s.y - 170)
	var knob := base
	for t in player.touches.values():
		if t["role"] == "move":
			base = t["start"]
			knob = base + player.move_vec * 110.0
	draw_arc(base, 110.0, 0, TAU, 40, Color(1, 1, 1, 0.35), 3)
	draw_circle(knob, 40, Color(1, 1, 1, 0.35))
	# tombol (ikon)
	var white := Color(1, 1, 1, 0.95)
	for d in Global.btn_defs():
		var nm: String = d[0]
		var bc: Vector2 = d[1]
		var rr: float = d[2]
		if nm == "fire":
			var fr := rr * 0.84
			match st:
				0:
					draw_circle(bc, fr, Color(0.2, 0.8, 0.3, 0.55))
					_ic_jump(bc, 1.5 * ks, white)
				1:
					draw_circle(bc, fr, Color(0.2, 0.5, 1.0, 0.55))
					_ic_chute(bc, 1.5 * ks, white)
				2:
					draw_circle(bc, fr, Color(0.5, 0.5, 0.5, 0.25))
					_ic_chute(bc, 1.5 * ks, Color(1, 1, 1, 0.4))
				_:
					draw_circle(bc, fr, Color(1, 0.2, 0.2, 0.5))
					_ic_bullet(bc, 1.6 * ks, white)
		elif st != 3:
			continue
		elif nm == "reload":
			draw_circle(bc, rr, Color(0.9, 0.8, 0.2, 0.5))
			_ic_reload(bc, 1.2 * ks, white)
		elif nm == "scope":
			var sc := Color(0.1, 0.75, 0.9, 0.65) if player.scoped else Color(0.1, 0.75, 0.9, 0.35)
			draw_circle(bc, rr, sc)
			_ic_scope(bc, 1.0 * ks, white)
		elif nm == "heal":
			draw_circle(bc, rr, Color(0.2, 0.8, 0.4, 0.45))
			_ic_medkit(bc, 1.0 * ks)
			draw_string(font, bc + Vector2(14, 34) * ks, "x%d" % player.medkits, HORIZONTAL_ALIGNMENT_LEFT, -1, int(22.0 * ks))
		elif nm == "use":
			if Global.use_active:
				draw_circle(bc, rr, Color(1, 0.85, 0.1, 0.65))
				if player.interact_kind == "shop":
					_ic_cart(bc, 1.2 * ks, Color(0, 0, 0))
				else:
					_ic_pickup(bc, 1.2 * ks, Color(0, 0, 0))
				draw_string(font, bc + Vector2(-340, -70) * ks, player.interact_name, HORIZONTAL_ALIGNMENT_RIGHT, 340.0 * ks, int(26.0 * ks), Color(1, 0.9, 0.4))
		elif nm.begins_with("slot"):
			var i := int(nm.substr(4))
			if i < player.slots.size():
				var sid: String = player.slots[i]
				var sc2 := Color(1, 0.7, 0.1, 0.75) if i == player.cur else Color(0, 0, 0, 0.5)
				draw_circle(bc, rr, sc2)
				_ic_weapon(bc, sid, 0.95 * ks, white)
	if banner_t > 0:
		draw_string(font, Vector2(0, s.y * 0.3), banner_txt, HORIZONTAL_ALIGNMENT_CENTER, s.x, 64, Color(1, 0.9, 0.3, clampf(banner_t, 0, 1)))
	if toast_t > 0:
		draw_string(font, Vector2(0, s.y * 0.72), toast_txt, HORIZONTAL_ALIGNMENT_CENTER, s.x, 32, Color(1, 1, 1, clampf(toast_t, 0, 1)))
