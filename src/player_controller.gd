class_name PackagePeddlerPlayer
extends CharacterBody3D

signal interaction_requested

@export var walk_speed := 4.2
@export var sprint_speed := 7.0
@export var acceleration := 18.0
@export var braking := 24.0
@export var turn_speed := 12.0
@export var mouse_sensitivity := 0.0025
@export var stick_look_speed := 2.2

var gravity := 18.0
var camera_yaw := 0.0
var camera_pitch := -0.22
var first_person := false
var gait_time := 0.0

var visual_root: Node3D
var left_arm: MeshInstance3D
var right_arm: MeshInstance3D
var left_leg: MeshInstance3D
var right_leg: MeshInstance3D
var camera_pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D

func _ready() -> void:
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
	_build_collision()
	_build_provisional_human()
	_build_camera()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)

func _build_provisional_human() -> void:
	visual_root = Node3D.new()
	visual_root.name = "ProvisionalHumanRig"
	add_child(visual_root)

	var uniform := StandardMaterial3D.new()
	uniform.albedo_color = Color("243d5a")
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("b87956")

	var torso := _make_capsule(Vector3(0.0, 1.25, 0.0), Vector3(0.78, 0.95, 0.48), uniform)
	torso.name = "Torso"
	visual_root.add_child(torso)
	var head := _make_sphere(Vector3(0.0, 1.95, 0.0), Vector3.ONE * 0.33, skin)
	head.name = "Head"
	visual_root.add_child(head)

	left_arm = _make_capsule(Vector3(-0.5, 1.25, 0.0), Vector3(0.20, 0.72, 0.20), uniform)
	right_arm = _make_capsule(Vector3(0.5, 1.25, 0.0), Vector3(0.20, 0.72, 0.20), uniform)
	left_leg = _make_capsule(Vector3(-0.22, 0.48, 0.0), Vector3(0.24, 0.88, 0.24), uniform)
	right_leg = _make_capsule(Vector3(0.22, 0.48, 0.0), Vector3(0.24, 0.88, 0.24), uniform)
	visual_root.add_child(left_arm)
	visual_root.add_child(right_arm)
	visual_root.add_child(left_leg)
	visual_root.add_child(right_leg)

func _make_capsule(pos: Vector3, scale_value: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.material = material
	instance.mesh = mesh
	instance.position = pos
	instance.scale = scale_value
	return instance

func _make_sphere(pos: Vector3, scale_value: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.material = material
	instance.mesh = mesh
	instance.position = pos
	instance.scale = scale_value
	return instance

func _build_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0.0, 1.55, 0.0)
	add_child(camera_pivot)

	spring_arm = SpringArm3D.new()
	spring_arm.name = "CameraCollisionArm"
	spring_arm.spring_length = 4.8
	spring_arm.margin = 0.12
	camera_pivot.add_child(spring_arm)

	camera = Camera3D.new()
	camera.name = "GameplayCamera"
	camera.fov = 72.0
	camera.current = true
	spring_arm.add_child(camera)
	_apply_camera_rotation()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_yaw -= event.relative.x * mouse_sensitivity
		camera_pitch = clamp(camera_pitch - event.relative.y * mouse_sensitivity, -1.05, 0.55)
		_apply_camera_rotation()
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	_update_gamepad_look(delta)
	_update_camera_mode()
	_update_interaction()
	_update_movement(delta)
	_update_gait(delta)

func _update_gamepad_look(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.length_squared() > 0.001:
		camera_yaw -= look.x * stick_look_speed * delta
		camera_pitch = clamp(camera_pitch - look.y * stick_look_speed * delta, -1.05, 0.55)
		_apply_camera_rotation()

func _apply_camera_rotation() -> void:
	if camera_pivot:
		camera_pivot.rotation = Vector3(camera_pitch, camera_yaw, 0.0)

func _update_camera_mode() -> void:
	if Input.is_action_just_pressed("camera_toggle"):
		first_person = not first_person
		spring_arm.spring_length = 0.08 if first_person else 4.8
		visual_root.visible = not first_person

func _update_interaction() -> void:
	if Input.is_action_just_pressed("interact"):
		interaction_requested.emit()

func _update_movement(delta: float) -> void:
	var input_2d := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camera_forward := -camera.global_transform.basis.z
	var camera_right := camera.global_transform.basis.x
	camera_forward.y = 0.0
	camera_right.y = 0.0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()
	var direction := (camera_right * input_2d.x + camera_forward * -input_2d.y).normalized()
	var target_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target_velocity := direction * target_speed
	var rate := acceleration if direction.length_squared() > 0.0 else braking
	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5

	if direction.length_squared() > 0.001:
		var desired_yaw := atan2(direction.x, direction.z)
		visual_root.rotation.y = lerp_angle(visual_root.rotation.y, desired_yaw, 1.0 - exp(-turn_speed * delta))

	move_and_slide()

func _update_gait(delta: float) -> void:
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	if planar_speed > 0.2 and is_on_floor():
		gait_time += delta * (6.0 if planar_speed < 5.0 else 9.0)
		var swing := sin(gait_time) * (0.42 if planar_speed < 5.0 else 0.62)
		left_arm.rotation.x = swing
		right_arm.rotation.x = -swing
		left_leg.rotation.x = -swing
		right_leg.rotation.x = swing
		visual_root.position.y = abs(sin(gait_time * 2.0)) * 0.025
	else:
		left_arm.rotation.x = move_toward(left_arm.rotation.x, 0.0, delta * 5.0)
		right_arm.rotation.x = move_toward(right_arm.rotation.x, 0.0, delta * 5.0)
		left_leg.rotation.x = move_toward(left_leg.rotation.x, 0.0, delta * 5.0)
		right_leg.rotation.x = move_toward(right_leg.rotation.x, 0.0, delta * 5.0)
		visual_root.position.y = move_toward(visual_root.position.y, 0.0, delta * 0.2)

