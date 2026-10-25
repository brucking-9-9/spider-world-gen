extends Node3D
## Demo arena for the IK spider: ground, scattered obstacle boxes to show
## off foot placement, sky, light, and a follow camera.
## Run with `-- --autoquit` to exit after a few seconds (headless testing).

const SPIDER_SCENE := preload("res://ik_spider.tscn")

var autoquit := "--autoquit" in OS.get_cmdline_user_args()
var quit_timer := 0.0


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_obstacles()

	var spider: IKSpider = SPIDER_SCENE.instantiate()
	spider.position = Vector3(0, 1.0, 0)
	add_child(spider)

	var cam := Camera3D.new()
	cam.set_script(preload("res://follow_cam.gd"))
	cam.position = Vector3(0, 6, 8)
	add_child(cam)
	cam.target = spider

	print("[main] arena ready — arrow keys to drive the spider")


func _physics_process(delta: float) -> void:
	if autoquit:
		quit_timer += delta
		if quit_timer > 4.0:
			print("[main] autoquit after %.1fs" % quit_timer)
			get_tree().quit()


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.4, 0.6)
	sky_mat.sky_horizon_color = Color(0.65, 0.7, 0.75)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, -35, 0)
	light.shadow_enabled = true
	add_child(light)


func _build_ground() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.38, 0.28)
	mat.roughness = 1.0
	add_child(_make_box_body(Vector3(60, 1, 60), Vector3(0, -0.5, 0), mat))


func _build_obstacles() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.42, 0.38)
	mat.roughness = 1.0
	# One box directly in the auto-walk path (spider walks toward -Z),
	# so the height/tilt adaptation is exercised right at startup.
	add_child(_make_box_body(Vector3(5.0, 0.35, 2.2), Vector3(0, 0.175, -4), mat))

	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	for _i in 14:
		var size := Vector3(rng.randf_range(0.8, 2.2), rng.randf_range(0.15, 0.5),
				rng.randf_range(0.8, 2.2))
		var pos := Vector3(rng.randf_range(-12, 12), size.y * 0.5, rng.randf_range(-12, 12))
		if Vector2(pos.x, pos.z).length() < 3.0:
			pos.z -= 6.0  # keep the spawn area clear
		add_child(_make_box_body(size, pos, mat))


func _make_box_body(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)

	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	mesh.material_override = mat
	body.add_child(mesh)
	return body
