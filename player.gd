extends CharacterBody3D

signal died
signal hurt
signal hit(head: bool)
signal landed
signal interact

const JOY := 110.0
const ST_PLANE := 0
const ST_FREEFALL := 1
const ST_CHUTE := 2
const ST_GROUND := 3

var state := ST_PLANE
var limit := 497.0
var plane_vel := Vector3.ZERO
var hp := 200
var max_hp := 200
var armor := 0.0
var armor_max := 0.0
var coins := 500
var medkits := 1
var scope_level := 0
var scoped := false
var slots: Array = ["pistol"]
var cur := 0
var ammo := {"pistol": 12}
var pitch := 0.0
var cam: Camera3D
var weapon: Node3D
var wmodel: Node3D
var weapon_base := Vector3(0.17, -0.16, -0.34)
var muzzle: Marker3D
var flash: Node3D
var smoke: CPUParticles3D
var shell: CPUParticles3D
var flash_t := 0.0
var recoil := 0.0
var shake := 0.0
var bob_t := 0.0
var step_t := 0.0
var canopy: MeshInstance3D
var wind: AudioStreamPlayer
var touches := {}
var move_vec := Vector2.ZERO
var firing := false
var fire_edge := false
var cd := 0.0
var reloading := false
var reload_t := 0.0
var dead := false
var drown_acc := 0.0
var interact_kind := ""
var interact_name := ""

func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 0.6
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	add_child(cs)
	cam = Camera3D.new()
	cam.position = Vector3(0, 7.0, 26.0)
	pitch = -0.18
	cam.fov = 75
	cam.near = 0.08
	cam.far = 3000.0
	add_child(cam)
	cam.current = true
	weapon = Node3D.new()
	cam.add_child(weapon)
	_equip()
	weapon.visible = false
	wind = AudioStreamPlayer.new()
	wind.stream = Global.snd("wind")
	wind.volume_db = -80.0
	add_child(wind)
	wind.play()

func _equip() -> void:
	if wmodel:
		wmodel.queue_free()
	var id: String = slots[cur]
	wmodel = Global.build_weapon(id, scope_level)
	weapon.add_child(wmodel)
	muzzle = wmodel.get_node("Muzzle")
	var ejp: Marker3D = wmodel.get_node("Eject")
	flash = Global.make_flash()
	muzzle.add_child(flash)
	smoke = Global.make_smoke()
	muzzle.add_child(smoke)
	shell = Global.make_shell()
	ejp.add_child(shell)
	var W: Dictionary = Global.WEAPONS[id]
	weapon_base = W["base"]
	weapon.position = weapon_base
	Global.slot_count = slots.size()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var s := get_viewport().get_visible_rect().size
			var bn := Global.hit_button(event.position)
			if bn != "":
				_press(bn, event.index)
			elif event.position.x < s.x * 0.5:
				touches[event.index] = {"role": "move", "start": event.position}
			else:
				touches[event.index] = {"role": "look"}
		elif touches.has(event.index):
			var role: String = touches[event.index]["role"]
			if role == "fire":
				firing = false
			elif role == "move":
				move_vec = Vector2.ZERO
			touches.erase(event.index)
	elif event is InputEventScreenDrag and touches.has(event.index):
		var t: Dictionary = touches[event.index]
		if t["role"] == "move":
			move_vec = ((event.position - t["start"]) / JOY).limit_length(1.0)
		elif t["role"] == "look":
			var k := 0.004 * Global.sens
			if scoped:
				k /= float(Global.SCOPE_ZOOM[scope_level])
			rotate_y(-event.relative.x * k)
			pitch = clampf(pitch - event.relative.y * k, -1.5, 1.2)

func _press(bn: String, idx: int) -> void:
	if bn == "fire":
		if state == ST_PLANE:
			jump()
		elif state == ST_FREEFALL:
			open_chute()
		elif state == ST_GROUND:
			touches[idx] = {"role": "fire"}
			firing = true
			fire_edge = true
		return
	if state != ST_GROUND:
		return
	match bn:
		"reload": reload()
		"scope": toggle_scope()
		"heal": use_medkit()
		"use": interact.emit()
		"slot0": switch_to(0)
		"slot1": switch_to(1)
		"slot2": switch_to(2)

func start_on_ground() -> void:
	state = ST_GROUND
	cam.position = Vector3(0, 0.7, 0)
	pitch = 0.0
	weapon.visible = true
	wind.volume_db = -80.0

func revive(pos: Vector3, yaw: float) -> void:
	dead = false
	hp = max_hp
	armor = armor_max
	velocity = Vector3.ZERO
	global_position = pos
	rotation.y = yaw
	pitch = 0.0
	reloading = false
	scoped = false
	firing = false
	touches.clear()
	move_vec = Vector2.ZERO
	for id in slots:
		var W: Dictionary = Global.WEAPONS[id]
		ammo[id] = W["mag"]
	weapon.visible = true

func jump() -> void:
	if state != ST_PLANE:
		return
	state = ST_FREEFALL
	velocity = Vector3(plane_vel.x * 0.7, 0, plane_vel.z * 0.7)
	pitch = -0.7
	cam.position = Vector3(0, 0.7, 0)

func open_chute() -> void:
	if state != ST_FREEFALL:
		return
	state = ST_CHUTE
	Global.sfx("chute", -2.0)
	canopy = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 3.5
	sm.height = 3.5
	sm.is_hemisphere = true
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.9, 0.35, 0.1)
	cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.material = cmat
	canopy.mesh = sm
	canopy.position = Vector3(0, 4.2, 0)
	add_child(canopy)

func _land() -> void:
	state = ST_GROUND
	if canopy:
		canopy.queue_free()
		canopy = null
	weapon.visible = true
	pitch = 0.0
	wind.volume_db = -80.0
	landed.emit()

# ---------------- SENJATA / ITEM ----------------

func switch_to(i: int) -> void:
	if i >= slots.size() or i == cur:
		return
	cur = i
	reloading = false
	scoped = false
	_equip()

func give_weapon(id: String) -> void:
	var W: Dictionary = Global.WEAPONS[id]
	if id in slots:
		ammo[id] = W["mag"]
		return
	if slots.size() < 3:
		slots.append(id)
		cur = slots.size() - 1
	else:
		var old: String = slots[cur]
		ammo.erase(old)
		slots[cur] = id
	ammo[id] = W["mag"]
	reloading = false
	scoped = false
	_equip()

func give_scope(level: int) -> void:
	if Global.SCOPE_ORDER.find(level) > Global.SCOPE_ORDER.find(scope_level):
		scope_level = level
		_equip()

func give_armor(level: int) -> void:
	var vals := [0.0, 40.0, 70.0, 100.0]
	var v: float = vals[clampi(level, 1, 3)]
	if v >= armor_max or armor <= 0.0:
		armor_max = v
	armor = armor_max

func use_medkit() -> void:
	if medkits <= 0 or hp >= max_hp:
		return
	medkits -= 1
	hp = mini(max_hp, hp + 100)
	Global.sfx("heal", -4.0)

func toggle_scope() -> void:
	scoped = not scoped
	weapon.visible = not scoped and state == ST_GROUND

func reload() -> void:
	var id: String = slots[cur]
	var W: Dictionary = Global.WEAPONS[id]
	if reloading or ammo[id] == W["mag"]:
		return
	reloading = true
	reload_t = W["reload"]
	scoped = false
	weapon.visible = state == ST_GROUND
	Global.sfx("reload", -4.0)

func heal(n: int) -> void:
	hp = mini(max_hp, hp + n)

func take_damage(n: int, _src: Node = null) -> void:
	if dead:
		return
	var absorbed := 0.0
	if armor > 0.0:
		absorbed = minf(armor, float(n) * 0.6)
		armor -= absorbed
	hp = maxi(0, hp - int(ceil(float(n) - absorbed)))
	hurt.emit()
	Global.sfx("hurt", -6.0)
	if hp <= 0:
		dead = true
		died.emit()

func zone_hurt(n: int) -> void:
	_raw_hurt(n)

func _raw_hurt(n: int) -> void:
	if dead:
		return
	hp = maxi(0, hp - n)
	hurt.emit()
	if hp <= 0:
		dead = true
		died.emit()

func _mv() -> Vector2:
	var mv := move_vec
	if mv == Vector2.ZERO:
		mv = Vector2(
			int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A)),
			int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W)))
	return mv

func _physics_process(delta: float) -> void:
	Global.on_ground = state == ST_GROUND
	var mv := _mv()
	var dir := transform.basis * Vector3(mv.x, 0, mv.y)
	var id: String = slots[cur]
	var W: Dictionary = Global.WEAPONS[id]
	var zoom: float = Global.SCOPE_ZOOM[scope_level]
	match state:
		ST_PLANE:
			velocity = Vector3.ZERO
			wind.volume_db = -18.0
		ST_FREEFALL:
			velocity.x = lerpf(velocity.x, dir.x * 28.0, 2.0 * delta)
			velocity.z = lerpf(velocity.z, dir.z * 28.0, 2.0 * delta)
			velocity.y = maxf(velocity.y - 25.0 * delta, -55.0)
			move_and_slide()
			wind.volume_db = -3.0
			wind.pitch_scale = 0.8 + absf(velocity.y) / 60.0
			if is_on_floor():
				_land()
			elif global_position.y < 110.0:
				open_chute()
		ST_CHUTE:
			velocity.x = lerpf(velocity.x, dir.x * 12.0, 2.0 * delta)
			velocity.z = lerpf(velocity.z, dir.z * 12.0, 2.0 * delta)
			velocity.y = lerpf(velocity.y, -6.0, 3.0 * delta)
			move_and_slide()
			wind.volume_db = -20.0
			wind.pitch_scale = 0.8
			if is_on_floor():
				_land()
		ST_GROUND:
			var spd := 6.0
			if dead:
				spd = 0.0
			if scoped:
				spd = 3.0
			if global_position.y < -0.4:
				spd *= 0.6
			velocity.x = dir.x * spd
			velocity.z = dir.z * spd
			if is_on_floor():
				velocity.y = 0
			else:
				velocity.y -= 20.0 * delta
			move_and_slide()
			if mv.length() > 0.1 and is_on_floor():
				step_t -= delta * mv.length()
				if step_t <= 0.0:
					step_t = 0.42
					Global.sfx("step", -22.0, randf_range(0.9, 1.1))
			if global_position.y < -1.8:
				drown_acc += 8.0 * delta
				if drown_acc >= 1.0:
					_raw_hurt(int(drown_acc))
					drown_acc -= floorf(drown_acc)
			cd -= delta
			if reloading:
				reload_t -= delta
				if reload_t <= 0:
					reloading = false
					ammo[id] = W["mag"]
					weapon.visible = not scoped
			if firing and cd <= 0 and not reloading and not dead:
				if bool(W["auto"]) or fire_edge:
					shoot()
			fire_edge = false
	if state != ST_GROUND and scoped:
		scoped = false
	if state != ST_PLANE:
		position.x = clampf(position.x, -limit, limit)
		position.z = clampf(position.z, -limit, limit)
	# kamera: zoom scope + guncangan
	var target_fov := 75.0
	if scoped:
		target_fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(75.0) / 2.0) / zoom))
	cam.fov = lerpf(cam.fov, target_fov, 12.0 * delta)
	flash_t -= delta
	if flash_t <= 0.0:
		flash.visible = false
	recoil = lerpf(recoil, 0.0, 12.0 * delta)
	shake = lerpf(shake, 0.0, 10.0 * delta)
	cam.rotation.x = pitch + recoil
	cam.rotation.z = randf_range(-1.0, 1.0) * shake * 0.03
	# animasi senjata
	var moving := state == ST_GROUND and mv.length() > 0.1
	if moving:
		bob_t += delta * 9.0 * mv.length()
	var ty := weapon_base.y - (0.18 if reloading else 0.0)
	weapon.position.x = weapon_base.x + sin(bob_t) * 0.008
	weapon.position.y = lerpf(weapon.position.y, ty + absf(cos(bob_t)) * 0.008, 10.0 * delta)
	weapon.position.z = lerpf(weapon.position.z, weapon_base.z, 14.0 * delta)
	weapon.rotation.x = lerpf(weapon.rotation.x, (-0.5 if reloading else 0.0) + recoil * 3.0, 8.0 * delta)

func shoot() -> void:
	var id: String = slots[cur]
	var W: Dictionary = Global.WEAPONS[id]
	if ammo[id] <= 0:
		Global.sfx("empty", -6.0)
		cd = 0.3
		reload()
		return
	ammo[id] -= 1
	cd = W["cd"]
	var rc: float = W["recoil"]
	recoil += rc
	shake = minf(shake + rc * 20.0, 1.5)
	weapon.position.z = weapon_base.z + 0.05 + rc * 1.5
	flash_t = 0.05
	flash.visible = not scoped
	flash.rotation.z = randf() * TAU
	smoke.restart()
	smoke.emitting = true
	shell.restart()
	shell.emitting = true
	var snd_name: String = W["snd"]
	Global.sfx(snd_name, -2.0, randf_range(0.96, 1.04))
	var b := cam.global_transform.basis
	var from := cam.global_position
	var space := get_world_3d().direct_space_state
	var n_pel: int = W["pellets"]
	var spr: float = W["spread"]
	if scoped:
		spr *= 0.4
	var hit_snd := false
	for p in n_pel:
		var dirv := (-b.z + b.x * randf_range(-spr, spr) + b.y * randf_range(-spr, spr)).normalized()
		var endp := from + dirv * 500.0
		var q := PhysicsRayQueryParameters3D.create(from, endp)
		q.exclude = [get_rid()]
		var r := space.intersect_ray(q)
		if r:
			endp = r["position"]
			var col = r["collider"]
			if col.has_method("take_damage"):
				var head: bool = endp.y > col.global_position.y + 0.6
				var dmg: int = int(float(W["dmg"]) * (2.4 if head else 1.0))
				col.take_damage(dmg, self)
				hit.emit(head)
				if p < 4:
					Global.fx(endp, "blood", r["normal"])
				if not hit_snd:
					hit_snd = true
					Global.sfx("hit", -8.0)
			elif p < 4:
				Global.fx(endp, "spark", r["normal"])
				Global.fx(endp, "dust", r["normal"])
				Global.hole(endp, r["normal"])
		if p == 0:
			Global.tracer(muzzle.global_position, endp)
	if ammo[id] == 0:
		reload()
