extends CharacterBody3D

var main: Node3D
var hp := 3
var speed := 2.5
var attack_cd := 0.0


func _ready() -> void:
	add_to_group("zombies")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	set_collision_layer_value(3, true)   # 좀비
	set_collision_mask_value(4, true)    # 벽
	set_collision_mask_value(3, true)    # 다른 좀비

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 2.0
	shape.shape = cap
	add_child(shape)

	var skin := Color(0.35, 0.55, 0.3)
	_add_mesh(CapsuleMesh.new(), Vector3.ZERO, skin)
	# 앞으로 뻗은 팔 (좀비 느낌)
	for side in [-0.4, 0.4]:
		var arm := BoxMesh.new()
		arm.size = Vector3(0.18, 0.18, 0.8)
		_add_mesh(arm, Vector3(side, 0.3, -0.6), skin.darkened(0.2))


func _add_mesh(mesh: Mesh, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


func _physics_process(delta: float) -> void:
	if main == null or main.player == null or main.player.dead:
		return
	var to_p: Vector3 = main.player.global_position - global_position
	to_p.y = 0.0
	var dist := to_p.length()
	if dist > 0.01:
		var dir := to_p / dist
		rotation.y = atan2(-dir.x, -dir.z)
		velocity = dir * speed if dist > 1.2 else Vector3.ZERO
	move_and_slide()
	global_position.y = 1.0

	attack_cd -= delta
	if dist < 1.5 and attack_cd <= 0.0:
		main.player.take_damage(10.0)
		attack_cd = 0.8


func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		remove_from_group("zombies")
		main.on_zombie_killed()
		queue_free()
