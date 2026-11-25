extends CharacterBody3D

signal killed(pos: Vector3)

const PH_PLANE := 0
const PH_FALL := 1
const PH_CHUTE := 2
const PH_GROUND := 3

var phase := PH_PLANE
var team := 1
var fight_bots := false
var use_lod := true
var start_ground := false
var hp := 60
var target: Node3D
var player_ref: Node3D
var game: Node3D
var plane: Node3D
var plane_vel := Vector3.ZERO
var jump_x := 0.0
var land_target := Vector2.ZERO
var advance_to := Vector3.ZERO
var last_src: Node
var tgt_t := 0.0
var dmg := 7
var acc := 0.35
var shoot_cd := 1.0
var wander := Vector3.ZERO
var wander_t := 0.0
var mat: StandardMaterial3D
var base_color := Color(0.35, 0.42, 0.25)
var los_t := 0.0
var sees := false
var gun_node: MeshInstance3D
var cs: CollisionShape3D
var canopy: MeshInstance3D

func _bx(size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = m
	mi.mesh = bm
	mi.position = pos
	mi.visibility_range_end = Global.view_dist() + 30.0
	add_child(mi)
	return mi

func _ready() -> void:
	add_to_group("enemy")
	floor_snap_length = 0.6
	shoot_cd = randf_range(0.5, 1.5)
	los_t = randf() * 0.15
	cs = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	add_child(cs)
	mat = StandardMaterial3D.new()
	mat.albedo_color = base_color
	mat.roughness = 0.9
	var pants := StandardMaterial3D.new()
	pants.albedo_color = Color(0.22, 0.25, 0.18)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.1, 0.1)
	_bx(Vector3(0.55, 0.7, 0.3), Vector3(0, 0.25, 0), mat)
	_bx(Vector3(0.2, 0.8, 0.22), Vector3(-0.14, -0.5, 0), pants)
	_bx(Vector3(0.2, 0.8, 0.22), Vector3(0.14, -0.5, 0), pants)
	_bx(Vector3(0.14, 0.55, 0.14), Vector3(-0.36, 0.28, -0.08), mat)
	_bx(Vector3(0.14, 0.55, 0.14), Vector3(0.36, 0.28, -0.08), mat)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.36
	sm.radial_segments = 10
	sm.rings = 5
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.85, 0.65, 0.5)
	sm.material = skin
	head.mesh = sm
	head.position = Vector3(0, 0.78, 0)
	head.visibility_range_end = Global.view_dist() + 30.0
	add_child(head)
	var helm := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.22
	hm.height = 0.22
	hm.is_hemisphere = true
	hm.radial_segments = 10
	hm.rings = 5
	hm.material = pants
	helm.mesh = hm
	helm.position = Vector3(0, 0.8, 0)
	helm.visibility_range_end = Global.view_dist() + 30.0
	add_child(helm)
	gun_node = _bx(Vector3(0.07, 0.09, 0.6), Vector3(0.2, 0.3, -0.5), dark)
	# mode BR: mulai di dalam pesawat (tak terlihat, tanpa tabrakan)
	visible = false
	cs.disabled = true
	if start_ground:
		phase = PH_GROUND
		visible = true
		cs.disabled = false

func _jump() -> void:
	phase = PH_FALL
	visible = true
	cs.disabled = false
	velocity = Vector3(plane_vel.x * 0.7, 0.0, plane_vel.z * 0.7)
	land_target = game.land_near(Vector2(global_position.x, global_position.z), 200.0)

func _open_chute() -> void:
	phase = PH_CHUTE
	canopy = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 3.0
	sm.height = 3.0
	sm.is_hemisphere = true
	sm.radial_segments = 12
	sm.rings = 6
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color.from_hsv(randf(), 0.8, 0.9)
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.material = cm
	canopy.mesh = sm
	canopy.position = Vector3(0, 3.5, 0)
	canopy.visibility_range_end = Global.view_dist() + 200.0
	add_child(canopy)

func _land() -> void:
	phase = PH_GROUND
	if canopy:
		canopy.queue_free()
		canopy = null
	velocity = Vector3.ZERO
	wander_t = 0.0

func _air(delta: float) -> void:
	var to := land_target - Vector2(global_position.x, global_position.z)
	var dist := to.length()
	var dirv := Vector3(to.x, 0, to.y).normalized()
	if phase == PH_FALL:
		var sp := minf(28.0, dist * 0.8)
		velocity.x = lerpf(velocity.x, dirv.x * sp, 2.0 * delta)
		velocity.z = lerpf(velocity.z, dirv.z * sp, 2.0 * delta)
		velocity.y = maxf(velocity.y - 25.0 * delta, -55.0)
		move_and_slide()
		if is_on_floor():
			_land()
		elif global_position.y < 110.0:
			_open_chute()
	else:
		var sp2 := minf(12.0, dist)
		velocity.x = lerpf(velocity.x, dirv.x * sp2, 2.0 * delta)
		velocity.z = lerpf(velocity.z, dirv.z * sp2, 2.0 * delta)
		velocity.y = lerpf(velocity.y, -6.0, 3.0 * delta)
		move_and_slide()
		if is_on_floor():
			_land()

func _zone_vec() -> Vector3:
	if game.zone_active:
		var p := Vector2(global_position.x, global_position.z)
		if p.distance_to(game.zone_center) > game.zone_radius * 0.95:
			var d: Vector2 = game.zone_center - p
			return Vector3(d.x, 0, d.y).normalized()
	return Vector3.ZERO

func _far_step(delta: float) -> void:
	wander_t -= delta
	if wander_t <= 0.0:
		wander_t = randf_range(3.0, 7.0)
		var a := randf() * TAU
		wander = Vector3(cos(a), 0, sin(a)) * 2.5
	var zv := _zone_vec()
	if zv != Vector3.ZERO:
		wander = zv * 2.5
	var nx := global_position.x + wander.x * delta
	var nz := global_position.z + wander.z * delta
	var gy: float = game.ground_y(nx, nz)
	if gy < 1.0 or absf(nx) > 480.0 or absf(nz) > 480.0:
		wander = -wander
		wander_t = 2.0
		return
	global_position = Vector3(nx, gy + 0.95, nz)

func _idle(delta: float) -> void:
	wander_t -= delta
	if wander_t <= 0.0:
		wander_t = randf_range(1.5, 3.5)
		var dv := advance_to - global_position
		dv.y = 0.0
		if dv.length() > 5.0 and randf() < 0.7:
			wander = dv.normalized() * 3.0
		else:
			var a := randf() * TAU
			wander = Vector3(cos(a), 0, sin(a)) * 2.0
	velocity.x = wander.x
	velocity.z = wander.z
	if is_on_floor():
		velocity.y = 0
	else:
		velocity.y -= 20.0 * delta
	move_and_slide()
	if get_slide_collision_count() > 0:
		wander_t = 0.0
	if wander.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-wander.x, -wander.z), 5.0 * delta)

func _pick_target() -> void:
	var best: Node3D = null
	var bd := 1e9
	if team == 1 and is_instance_valid(player_ref) and not player_ref.dead:
		best = player_ref
		bd = global_position.distance_to(player_ref.global_position)
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or e.team == team or e.hp <= 0 or e.phase != PH_GROUND or e.is_queued_for_deletion():
			continue
		var d := global_position.distance_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	target = best

func _los() -> bool:
	var from := global_position + Vector3(0, 0.6, 0)
	var to := target.global_position + Vector3(0, 0.6, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return r and r["collider"] == target

func _physics_process(delta: float) -> void:
	if hp <= 0:
		return
	match phase:
		PH_PLANE:
			if is_instance_valid(plane):
				global_position = plane.global_position
				if plane.global_position.x >= jump_x:
					_jump()
			else:
				_jump()
			return
		PH_FALL, PH_CHUTE:
			_air(delta)
			return
	if game.freeze:
		return
	if fight_bots:
		tgt_t -= delta
		if tgt_t <= 0.0:
			tgt_t = 0.5
			_pick_target()
	if not is_instance_valid(target):
		_idle(delta)
		return
	var to := target.global_position - global_position
	var dist := to.length()
	if use_lod and dist > 260.0:
		_far_step(delta)
		return
	var flat := Vector3(to.x, 0, to.z).normalized()
	los_t -= delta
	if los_t <= 0.0:
		los_t = 0.15
		sees = dist < 80.0 and _los()
	var v := Vector3.ZERO
	if global_position.y < -0.5:
		v = -Vector3(global_position.x, 0, global_position.z).normalized() * 3.0
	elif sees:
		look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP)
		if dist > 20.0:
			v = flat * 3.5
		elif dist < 8.0:
			v = -flat * 3.0
		else:
			v = flat.cross(Vector3.UP) * sin(Time.get_ticks_msec() / 700.0 + float(get_instance_id() % 7)) * 2.5
		shoot_cd -= delta
		if shoot_cd <= 0.0:
			shoot_cd = randf_range(0.8, 1.6)
			var gp := gun_node.global_position
			Global.sfx_3d("shot_ar", gp, -2.0, 0.85)
			var p := acc * clampf(1.2 - dist / 80.0, 0.25, 1.0)
			var aim := target.global_position + Vector3(0, 0.5, 0)
			if randf() < p:
				target.take_damage(dmg, self)
			else:
				aim += Vector3(randf_range(-1.5, 1.5), randf_range(-0.6, 0.6), randf_range(-1.5, 1.5))
			Global.tracer(gp, aim)
	else:
		wander_t -= delta
		if wander_t <= 0.0:
			wander_t = randf_range(2.0, 5.0)
			if randf() < 0.5:
				wander = flat * 2.8
			else:
				var a := randf() * TAU
				wander = Vector3(cos(a), 0, sin(a)) * 2.0
		v = wander
		var zv2 := _zone_vec()
		if zv2 != Vector3.ZERO:
			v = zv2 * 3.8
	velocity.x = v.x
	velocity.z = v.z
	if is_on_floor():
		velocity.y = 0
	else:
		velocity.y -= 20.0 * delta
	move_and_slide()
	if get_slide_collision_count() > 0 and not sees:
		wander_t = 0.0

func take_damage(n: int, src: Node = null) -> void:
	if hp <= 0 or phase == PH_PLANE:
		return
	last_src = src
	hp -= n
	mat.albedo_color = Color(1, 0.2, 0.2)
	create_tween().tween_property(mat, "albedo_color", base_color, 0.15)
	if hp <= 0:
		killed.emit(global_position)
		queue_free()
