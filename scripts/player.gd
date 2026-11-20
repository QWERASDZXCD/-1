extends CharacterBody3D

const SPEED := 7.0
const FIRE_DELAY := 0.12
const MAG_SIZE := 30
const RELOAD_TIME := 1.2
const BULLET := preload("res://scripts/bullet.gd")

var main: Node3D
var hp := 100.0
var ammo := MAG_SIZE
var reloading := false
var reload_left := 0.0
var fire_cd := 0.0
var aim_dir := Vector3(0, 0, -1)
var dead := false


func _ready() -> void:
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

	var gun := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.15, 0.15, 0.9)
	gun.mesh = box
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.1, 0.1, 0.1)
	gun.material_override = gmat
	gun.position = Vector3(0.3, 0.2, -0.7)
	add_child(gun)


func _physics_process(delta: float) -> void:
	if dead:
		return

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

	# --- 재장전 ---
	if reloading:
		reload_left -= delta
		if reload_left <= 0.0:
			reloading = false
			ammo = MAG_SIZE
	elif Input.is_physical_key_pressed(KEY_R) and ammo < MAG_SIZE:
		_start_reload()

	# --- 사격: 마우스 왼쪽 버튼(누르고 있으면 연사) 또는 스페이스 ---
	fire_cd -= delta
	var firing := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_SPACE)
	if firing and fire_cd <= 0.0 and not reloading:
		if ammo > 0:
			_shoot()
		else:
			_start_reload()


func _start_reload() -> void:
	reloading = true
	reload_left = RELOAD_TIME


func _shoot() -> void:
	ammo -= 1
	fire_cd = FIRE_DELAY
	var b := BULLET.new()
	b.direction = aim_dir
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
