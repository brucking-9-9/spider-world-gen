class_name IKSpider
extends Node3D
## Procedural walking spider: 8 IK legs, alternating diagonal gait,
## body height and tilt driven by foot positions.
## Drive with the arrow keys (ui_up/down/left/right).

@export var body_height := 1.0
@export var step_threshold := 0.5
@export var step_time := 0.16
@export var step_arc := 0.35
@export var move_speed := 2.2
@export var turn_speed := 1.6
@export var auto_walk_time := 3.0  ## walks forward on its own at startup
@export var debug_log := true

const LEG_SCENE := preload("res://ik_leg.tscn")

# Hip z rows, front (-Z) to back (+Z).
const Z_ROWS: Array[float] = [-0.55, -0.2, 0.15, 0.5]

var legs: Array[IKLeg] = []
var rest_offsets: Array[Vector3] = []  # body-space foot rest positions
var feet: Array[Vector3] = []          # planted foot positions, world space
var step_from: Array[Vector3] = []
var step_to: Array[Vector3] = []
var step_progress: Array[float] = []   # < 1.0 while a step is in flight
var groups: Array[int] = []            # 0/1 diagonal gait groups

var torso: Node3D
var first_frame := true
var time_alive := 0.0
var last_log_at := 0.0
var steps_taken := 0
var ray_hits := 0
var ray_casts := 0


func _ready() -> void:
	_build_torso()
	for side in [-1, 1]:
		for row in Z_ROWS.size():
			var leg: IKLeg = LEG_SCENE.instantiate()
			leg.position = Vector3(side * 0.35, 0.0, Z_ROWS[row])
			add_child(leg)
			legs.append(leg)
			rest_offsets.append(Vector3(side * 1.35, 0.0, Z_ROWS[row] * 1.9))
			groups.append((row + (0 if side < 0 else 1)) % 2)
			feet.append(Vector3.ZERO)
			step_from.append(Vector3.ZERO)
			step_to.append(Vector3.ZERO)
			step_progress.append(1.0)


func _build_torso() -> void:
	torso = Node3D.new()
	torso.name = "Torso"
	add_child(torso)

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.16, 0.13, 0.11)
	body_mat.roughness = 0.85

	var abdomen := MeshInstance3D.new()
	var abdomen_box := BoxMesh.new()
	abdomen_box.size = Vector3(0.8, 0.55, 0.9)
	abdomen.mesh = abdomen_box
	abdomen.material_override = body_mat
	abdomen.position = Vector3(0, 0.2, 0.55)
	torso.add_child(abdomen)

	var head := MeshInstance3D.new()
	var head_box := BoxMesh.new()
	head_box.size = Vector3(0.6, 0.42, 0.65)
	head.mesh = head_box
	head.material_override = body_mat
	head.position = Vector3(0, 0.12, -0.3)
	torso.add_child(head)

	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.9, 0.15, 0.1)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(0.6, 0.05, 0.02)
	for ex in [-0.18, -0.07, 0.07, 0.18]:
		var eye := MeshInstance3D.new()
		var eye_box := BoxMesh.new()
		eye_box.size = Vector3(0.07, 0.07, 0.05)
		eye.mesh = eye_box
		eye.material_override = eye_mat
		eye.position = Vector3(ex, 0.2, -0.63)
		torso.add_child(eye)


func _physics_process(delta: float) -> void:
	time_alive += delta

	var forward_in := Input.get_axis("ui_down", "ui_up")
	var turn_in := Input.get_axis("ui_right", "ui_left")
	if time_alive < auto_walk_time and forward_in == 0.0 and turn_in == 0.0:
		forward_in = 1.0

	rotate_y(turn_in * turn_speed * delta)
	var vel := -global_basis.z * forward_in * move_speed
	vel.y = 0.0
	global_position += vel * delta

	var space := get_world_3d().direct_space_state
	var stepping_group := -1
	for i in legs.size():
		if step_progress[i] < 1.0:
			stepping_group = groups[i]

	for i in legs.size():
		var ground := _ground_at(space, to_global(rest_offsets[i]))
		if first_frame:
			feet[i] = ground

		if step_progress[i] >= 1.0:
			var drift := feet[i].distance_to(ground)
			var group_ok := stepping_group == -1 or stepping_group == groups[i]
			# Legs step in diagonal groups; a badly overstretched leg
			# may break formation rather than drag.
			if drift > step_threshold and (group_ok or drift > step_threshold * 2.0):
				step_from[i] = feet[i]
				step_to[i] = _ground_at(space, ground + vel * step_time * 2.0)
				step_progress[i] = 0.0
				stepping_group = groups[i]

		var foot_pos := feet[i]
		if step_progress[i] < 1.0:
			step_progress[i] = minf(step_progress[i] + delta / step_time, 1.0)
			var t := step_progress[i]
			foot_pos = step_from[i].lerp(step_to[i], smoothstep(0.0, 1.0, t))
			foot_pos.y += step_arc * sin(t * PI)
			if step_progress[i] >= 1.0:
				feet[i] = step_to[i]
				foot_pos = feet[i]
				steps_taken += 1
		legs[i].solve(foot_pos)

	_update_body(delta)
	first_frame = false

	if debug_log and time_alive < 4.5 and time_alive - last_log_at >= 0.5:
		last_log_at = time_alive
		var err := 0.0
		for i in legs.size():
			if step_progress[i] >= 1.0:
				err = maxf(err, legs[i].ik_error(feet[i]))
		print("[spider] t=%.1fs steps=%d pos=(%.1f,%.2f,%.1f) ray_hits=%d/%d max_ik_err=%.3f"
				% [time_alive, steps_taken, global_position.x, global_position.y,
				global_position.z, ray_hits, ray_casts, err])
		ray_hits = 0
		ray_casts = 0


func _update_body(delta: float) -> void:
	var avg_y := 0.0
	for f in feet:
		avg_y += f.y
	avg_y /= feet.size()
	var blend := 1.0 - exp(-8.0 * delta)
	global_position.y = lerpf(global_position.y, avg_y + body_height, blend)

	# Tilt only the torso toward the plane of the feet; hips stay level.
	var front_y := (feet[0].y + feet[4].y) * 0.5
	var back_y := (feet[3].y + feet[7].y) * 0.5
	var left_y := (feet[0].y + feet[1].y + feet[2].y + feet[3].y) * 0.25
	var right_y := (feet[4].y + feet[5].y + feet[6].y + feet[7].y) * 0.25
	var pitch := clampf(atan2(front_y - back_y, 2.0), -0.35, 0.35)
	var roll := clampf(atan2(right_y - left_y, 1.4), -0.35, 0.35)
	torso.rotation.x = lerp_angle(torso.rotation.x, pitch, blend)
	torso.rotation.z = lerp_angle(torso.rotation.z, roll, blend)


func _ground_at(space: PhysicsDirectSpaceState3D, near_point: Vector3) -> Vector3:
	var from := Vector3(near_point.x, global_position.y + 2.0, near_point.z)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 8.0)
	ray_casts += 1
	var hit := space.intersect_ray(query)
	if hit:
		ray_hits += 1
		return hit.position
	return Vector3(near_point.x, 0.0, near_point.z)
