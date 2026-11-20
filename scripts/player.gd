extends CharacterBody3D

const SPEED := 7.0
const BULLET := preload("res://scripts/bullet.gd")

# 무기 목록: 1~4 키 또는 마우스 휠로 교체
const WEAPONS := [
	{"name": "권총", "delay": 0.30, "mag": 12, "reload": 0.8, "damage": 1,
		"pellets": 1, "spread": 1.0, "speed": 45.0, "range": 1.5, "pierce": 0,
		"color": Color(1, 0.9, 0.3), "gun": Vector3(0.12, 0.12, 0.5), "gun_color": Color(0.15, 0.15, 0.15)},
	{"name": "기관단총", "delay": 0.09, "mag": 30, "reload": 1.2, "damage": 1,
		"pellets": 1, "spread": 3.0, "speed": 50.0, "range": 1.5, "pierce": 0,
		"color": Color(1, 0.7, 0.2), "gun": Vector3(0.15, 0.18, 0.8), "gun_color": Color(0.1, 0.1, 0.1)},
	{"name": "샷건", "delay": 0.80, "mag": 6, "reload": 1.8, "damage": 1,
		"pellets": 7, "spread": 9.0, "speed": 35.0, "range": 0.45, "pierce": 0,
		"color": Color(1, 0.4, 0.2), "gun": Vector3(0.2, 0.2, 1.0), "gun_color": Color(0.35, 0.2, 0.1)},
	{"name": "저격총", "delay": 1.00, "mag": 5, "reload": 2.0, "damage": 4,
		"pellets": 1, "spread": 0.0, "speed": 90.0, "range": 0.8, "pierce": 3,
		"color": Color(0.5, 0.9, 1), "gun": Vector3(0.12, 0.15, 1.4), "gun_color": Color(0.2, 0.25, 0.3)},
]

var main: Node3D
var hp := 100.0
var weapon_idx := 0
var ammo: Array = []
var reloading := false
var reload_left := 0.0
var fire_cd := 0.0
var aim_dir := Vector3(0, 0, -1)
var dead := false
var gun_mesh: MeshInstance3D
var gun_box: BoxMesh
var gun_mat: StandardMaterial3D


func _ready() -> void:
	for w in WEAPONS:
		ammo.append(w["mag"])

	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, true)   # 플레이어
	set_collision_mask_value(1, false)
	set_collision_mask_value(4, true)    # 벽

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 2.0
	shape.shape = cap
	add_child(shape)

	var body := MeshInstance3D.new()
	body.mesh = CapsuleMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.45, 0.9)
	body.material_override = mat
	add_child(body)

	gun_mesh = MeshInstance3D.new()
	gun_box = BoxMesh.new()
	gun_mesh.mesh = gun_box
	gun_mat = StandardMaterial3D.new()
	gun_mesh.material_override = gun_mat
	add_child(gun_mesh)
	_apply_weapon_look()


func weapon() -> Dictionary:
	return WEAPONS[weapon_idx]


func _apply_weapon_look() -> void:
	var w := weapon()
	gun_box.size = w["gun"]
	gun_mat.albedo_color = w["gun_color"]
	gun_mesh.position = Vector3(0.3, 0.2, -0.3 - w["gun"].z * 0.5)


func switch_weapon(idx: int) -> void:
	idx = posmod(idx, WEAPONS.size())
	if idx == weapon_idx:
		return
	weapon_idx = idx
	reloading = false      # 교체하면 재장전 취소
	fire_cd = 0.2
	_apply_weapon_look()


func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			switch_weapon(weapon_idx - 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			switch_weapon(weapon_idx + 1)


func _physics_process(delta: float) -> void:
	if dead:
		return

	# --- 무기 선택 (숫자키) ---
	for i in WEAPONS.size():
		if Input.is_physical_key_pressed(KEY_1 + i):
			switch_weapon(i)

	# --- 이동: WASD / 방향키 (화면 기준) ---
	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.z -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.z += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1
	velocity = dir.normalized() * SPEED
	move_and_slide()
	global_position.y = 1.0

	# --- 조준: 마우스 위치를 향해 회전 ---
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var mouse := get_viewport().get_mouse_position()
		var origin := cam.project_ray_origin(mouse)
		var ray := cam.project_ray_normal(mouse)
		var hit = Plane(Vector3.UP, 1.2).intersects_ray(origin, ray)
		if hit != null:
			var v: Vector3 = hit - global_position
			v.y = 0.0
			if v.length() > 0.1:
				aim_dir = v.normalized()
	rotation.y = atan2(-aim_dir.x, -aim_dir.z)

	var w := weapon()

	# --- 재장전 ---
	if reloading:
		reload_left -= delta
		if reload_left <= 0.0:
			reloading = false
			ammo[weapon_idx] = w["mag"]
	elif Input.is_physical_key_pressed(KEY_R) and ammo[weapon_idx] < w["mag"]:
		_start_reload()

	# --- 사격: 마우스 왼쪽 버튼(누르고 있으면 연사) 또는 스페이스 ---
	fire_cd -= delta
	var firing := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_SPACE)
	if firing and fire_cd <= 0.0 and not reloading:
		if ammo[weapon_idx] > 0:
			_shoot()
		else:
			_start_reload()


func _start_reload() -> void:
	reloading = true
	reload_left = weapon()["reload"]


func _shoot() -> void:
	var w := weapon()
	ammo[weapon_idx] -= 1
	fire_cd = w["delay"]
	for i in w["pellets"]:
		var angle := deg_to_rad(randf_range(-w["spread"], w["spread"]))
		var b := BULLET.new()
		b.direction = aim_dir.rotated(Vector3.UP, angle)
		b.speed = w["speed"]
		b.life = w["range"]
		b.damage = w["damage"]
		b.pierce = w["pierce"]
		b.color = w["color"]
		main.add_child(b)
		b.global_position = global_position + aim_dir * 1.2 + Vector3(0, 0.2, 0)


func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	if hp <= 0.0:
		hp = 0.0
		dead = true
		main.on_player_died()
