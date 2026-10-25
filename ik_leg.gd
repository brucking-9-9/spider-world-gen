class_name IKLeg
extends Node3D
## A modular two-segment spider leg driven by analytic two-bone IK.
## The node itself is the hip pivot; segments extend along local -Z.
## Call solve(target_global) every frame to plant the foot at a world position.

@export var upper_length := 0.9
@export var lower_length := 1.1
@export var thickness := 0.14
@export var leg_color := Color(0.13, 0.11, 0.1)

var knee: Node3D
var foot: Node3D


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = leg_color
	mat.roughness = 0.9

	var upper_mesh := MeshInstance3D.new()
	var upper_box := BoxMesh.new()
	upper_box.size = Vector3(thickness, thickness, upper_length)
	upper_mesh.mesh = upper_box
	upper_mesh.material_override = mat
	upper_mesh.position = Vector3(0, 0, -upper_length * 0.5)
	add_child(upper_mesh)

	knee = Node3D.new()
	knee.name = "Knee"
	knee.position = Vector3(0, 0, -upper_length)
	add_child(knee)

	var lower_mesh := MeshInstance3D.new()
	var lower_box := BoxMesh.new()
	lower_box.size = Vector3(thickness * 0.7, thickness * 0.7, lower_length)
	lower_mesh.mesh = lower_box
	lower_mesh.material_override = mat
	lower_mesh.position = Vector3(0, 0, -lower_length * 0.5)
	knee.add_child(lower_mesh)

	foot = Node3D.new()
	foot.name = "Foot"
	foot.position = Vector3(0, 0, -lower_length)
	knee.add_child(foot)


func solve(target: Vector3) -> void:
	var to_target := target - global_position
	if to_target.length() < 0.001:
		return
	# Clamp reach so the triangle stays solvable; the foot lands short
	# along the correct direction when the target is out of range.
	var d := clampf(to_target.length(), 0.01, upper_length + lower_length - 0.001)

	# Aim the hip at the target (-Z points at it), knee plane opens upward.
	look_at(target, Vector3.UP)

	# Law of cosines: lift the upper segment above the hip->target line...
	var cos_hip := (upper_length * upper_length + d * d - lower_length * lower_length) \
			/ (2.0 * upper_length * d)
	rotate_object_local(Vector3.RIGHT, acos(clampf(cos_hip, -1.0, 1.0)))

	# ...and bend the knee back down to reach the target.
	var cos_knee := (upper_length * upper_length + lower_length * lower_length - d * d) \
			/ (2.0 * upper_length * lower_length)
	var knee_bend := PI - acos(clampf(cos_knee, -1.0, 1.0))
	knee.rotation = Vector3(-knee_bend, 0, 0)


func ik_error(target: Vector3) -> float:
	return foot.global_position.distance_to(target)
