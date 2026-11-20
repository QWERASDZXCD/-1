extends Node3D

const PlayerScript := preload("res://scripts/player.gd")
const ZombieScript := preload("res://scripts/zombie.gd")
const ARENA := 20.0
const CAM_OFFSET := Vector3(0, 16, 9)

var player: CharacterBody3D
var camera: Camera3D
var stats_label: Label
var msg_label: Label

var score := 0
var wave := 0
var to_spawn := 0
var alive := 0
var spawn_cd := 0.0
var next_wave_cd := 2.0
var game_over := false


func _ready() -> void:
	randomize()
	_build_world()

	player = PlayerScript.new()
	player.main = self
	add_child(player)
	player.global_position = Vector3(0, 1, 0)

	camera = Camera3D.new()
	camera.fov = 55
	camera.rotation_degrees = Vector3(-60, 0, 0)
	add_child(camera)
	camera.global_position = player.global_position + CAM_OFFSET
	camera.make_current()

	_build_hud()
	msg_label.text = "좀비가 몰려온다!\nWASD 이동 / 마우스 조준 / 좌클릭 발사 / R 재장전"


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.05, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.8)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -30, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)

	# 바닥
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(ARENA * 2, ARENA * 2)
	floor_mi.mesh = plane
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.22, 0.22, 0.24)
	floor_mi.material_override = fmat
	add_child(floor_mi)

	# 벽 4개
	var t := 1.0
	var h := 3.0
	_add_wall(Vector3(0, h / 2, -ARENA - t / 2), Vector3(ARENA * 2 + t * 2, h, t))
	_add_wall(Vector3(0, h / 2, ARENA + t / 2), Vector3(ARENA * 2 + t * 2, h, t))
	_add_wall(Vector3(-ARENA - t / 2, h / 2, 0), Vector3(t, h, ARENA * 2))
	_add_wall(Vector3(ARENA + t / 2, h / 2, 0), Vector3(t, h, ARENA * 2))


func _add_wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.set_collision_layer_value(1, false)
	body.set_collision_layer_value(4, true)  # 벽
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.25, 0.2)
	mi.material_override = mat
	body.add_child(mi)
	add_child(body)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	stats_label = Label.new()
	stats_label.position = Vector2(20, 16)
	stats_label.add_theme_font_size_override("font_size", 24)
	layer.add_child(stats_label)

	msg_label = Label.new()
	msg_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg_label.add_theme_font_size_override("font_size", 40)
	msg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(msg_label)


func _process(delta: float) -> void:
	# 카메라 부드럽게 따라가기
	var target := player.global_position + CAM_OFFSET
	camera.global_position = camera.global_position.lerp(target, clampf(8.0 * delta, 0.0, 1.0))

	# HUD
	var ammo_text := "재장전 중..." if player.reloading else "%d / %d" % [player.ammo, player.MAG_SIZE]
	stats_label.text = "HP %d   탄약 %s\n웨이브 %d   점수 %d" % [int(player.hp), ammo_text, wave, score]

	if game_over:
		if Input.is_physical_key_pressed(KEY_ENTER):
			get_tree().reload_current_scene()
		return

	# 웨이브 진행
	if to_spawn > 0:
		spawn_cd -= delta
		if spawn_cd <= 0.0:
			_spawn_zombie()
			spawn_cd = 0.8
	elif alive == 0:
		next_wave_cd -= delta
		if next_wave_cd <= 0.0:
			_start_wave()


func _start_wave() -> void:
	wave += 1
	to_spawn = 5 + wave * 3
	spawn_cd = 0.0
	next_wave_cd = 3.0
	player.hp = minf(player.hp + 20.0, 100.0)  # 웨이브 시작마다 체력 조금 회복
	msg_label.text = "웨이브 %d" % wave
	await get_tree().create_timer(1.5).timeout
	if not game_over:
		msg_label.text = ""


func _spawn_zombie() -> void:
	# 플레이어에서 충분히 먼 곳, 아레나 안쪽에서 생성
	var pos := Vector3.ZERO
	for i in 10:
		pos = Vector3(randf_range(-ARENA + 1, ARENA - 1), 1.0, randf_range(-ARENA + 1, ARENA - 1))
		if pos.distance_to(player.global_position) > 14.0:
			break
	var z: CharacterBody3D = ZombieScript.new()
	z.main = self
	z.speed = minf(2.5 + wave * 0.25, 6.0)
	add_child(z)
	z.global_position = pos
	to_spawn -= 1
	alive += 1


func on_zombie_killed() -> void:
	alive -= 1
	score += 10


func on_player_died() -> void:
	game_over = true
	msg_label.text = "게임 오버\n점수 %d  (웨이브 %d)\nEnter 키로 다시 시작" % [score, wave]
