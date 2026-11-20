extends Node3D

var direction := Vector3.FORWARD
var speed := 45.0
var life := 1.5


func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.9, 0.3)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	add_child(mesh)


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var from := global_position
	var to := from + direction * speed * delta
	for z in get_tree().get_nodes_in_group("zombies"):
		var p: Vector3 = z.global_position
		var closest := Geometry3D.get_closest_point_to_segment(p, from, to)
		if closest.distance_to(p) < 0.8:
			z.take_damage(1)
			queue_free()
			return
	global_position = to
