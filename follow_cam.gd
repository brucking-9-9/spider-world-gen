extends Camera3D
## Smoothly trails a target from a fixed world-space offset.

@export var offset := Vector3(0, 6, 8)

var target: Node3D


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var blend := 1.0 - exp(-4.0 * delta)
	global_position = global_position.lerp(target.global_position + offset, blend)
	look_at(target.global_position + Vector3.UP * 0.5)
