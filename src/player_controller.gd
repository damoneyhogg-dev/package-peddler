class_name PackagePeddlerPlayer
extends CharacterBody3D

const COURIER_SCENE: PackedScene = preload("res://assets/characters/courier.glb")

signal interaction_requested(target: Node3D)
signal interaction_target_changed(target: Node3D)
signal presentation_finished(kind: String)

@export var walk_speed := 4.2
@export var sprint_speed := 7.0
@export var acceleration := 18.0
@export var braking := 24.0
@export var turn_speed := 12.0
@export var mouse_sensitivity := 0.0025
@export var stick_look_speed := 2.2
@export var interaction_distance := 2.75
@export var fall_recovery_height := -5.0

var gravity := 18.0
var camera_yaw := 0.0
var camera_pitch := -0.22
var first_person := false
var visual_root: Node3D
var animation_player: AnimationPlayer
var current_animation := ""
var camera_pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var current_interaction_target: Node3D
var recovery_position := Vector3.ZERO
var controls_enabled := true
var suppress_camera_toggle_until_release := false
var driver_variant := 0
var driver_badge: MeshInstance3D
var courier_skeleton: Skeleton3D
var scanner_prop: MeshInstance3D
var presentation_parcel: MeshInstance3D
var presentation_kind := ""
var presentation_elapsed := 0.0
var presentation_duration := 0.0
var transition_vehicle: PackagePeddlerVehicle
var transition_start := Vector3.ZERO
var transition_door := Vector3.ZERO
var transition_seat := Vector3.ZERO
var saved_bone_rotations: Dictionary = {}

func _ready() -> void:
	recovery_position = global_position
	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
	_build_collision()
	_build_rigged_courier()
	_build_driver_badge()
	_build_interaction_props()
	_build_camera()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "PlayerCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)

func _build_rigged_courier() -> void:
	visual_root = COURIER_SCENE.instantiate() as Node3D
	visual_root.name = "RiggedCourier"
	add_child(visual_root)
	animation_player = _find_animation_player(visual_root)
	courier_skeleton = _find_skeleton(visual_root)
	if animation_player == null:
		push_error("Rigged courier is missing its AnimationPlayer")
		return
	for animation_name in [&"Idle", &"Walk", &"Run"]:
		var animation := animation_player.get_animation(animation_name)
		if animation:
			animation.loop_mode = Animation.LOOP_LINEAR
	_play_animation("Idle")
	_cache_authored_pose_bones()

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null

func _cache_authored_pose_bones() -> void:
	if courier_skeleton == null:
		return
	for bone_name in ["spine_01", "spine_02", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r"]:
		var index := courier_skeleton.find_bone(bone_name)
		if index >= 0:
			saved_bone_rotations[bone_name] = courier_skeleton.get_bone_pose_rotation(index)

func _build_interaction_props() -> void:
	scanner_prop = MeshInstance3D.new()
	scanner_prop.name = "ScannerPresentationProp"
	var scanner_mesh := BoxMesh.new()
	scanner_mesh.size = Vector3(0.12, 0.22, 0.045)
	var scanner_material := StandardMaterial3D.new()
	scanner_material.albedo_color = Color("253a49")
	scanner_material.metallic = 0.25
	scanner_mesh.material = scanner_material
	scanner_prop.mesh = scanner_mesh
	scanner_prop.visible = false
	visual_root.add_child(scanner_prop)

	presentation_parcel = MeshInstance3D.new()
	presentation_parcel.name = "PlacementPresentationParcel"
	var parcel_mesh := BoxMesh.new()
	parcel_mesh.size = Vector3(0.62, 0.48, 0.42)
	var parcel_material := StandardMaterial3D.new()
	parcel_material.albedo_color = Color("9b6b3f")
	parcel_material.roughness = 0.8
	parcel_mesh.material = parcel_material
	presentation_parcel.mesh = parcel_mesh
	presentation_parcel.visible = false
	visual_root.add_child(presentation_parcel)

func _build_driver_badge() -> void:
	driver_badge = MeshInstance3D.new()
	driver_badge.name = "DriverVariantBadge"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.46, 0.52, 0.045)
	driver_badge.mesh = mesh
	driver_badge.position = Vector3(0.0, 1.28, -0.26)
	visual_root.add_child(driver_badge)
	set_driver_variant(0)

func set_driver_variant(index: int) -> void:
	driver_variant = clampi(index, 0, 3)
	if driver_badge == null:
		return
	var colors := [Color("d8e539"), Color("d94b62"), Color("3d91d4"), Color("e18a35")]
	var material := StandardMaterial3D.new()
	material.albedo_color = colors[driver_variant]
	material.roughness = 0.7
	driver_badge.material_override = material
	set_meta("driver_variant", driver_variant)

func set_player_active(active: bool) -> void:
	set_controls_enabled(active)
	visible = active
	if camera:
		camera.current = active

func _build_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0.0, 1.55, 0.0)
	add_child(camera_pivot)

	spring_arm = SpringArm3D.new()
	spring_arm.name = "CameraCollisionArm"
	spring_arm.spring_length = 3.6
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

func _physics_process(delta: float) -> void:
	_update_authored_presentation(delta)
	if not controls_enabled:
		velocity = Vector3.ZERO
		if presentation_kind not in ["vehicle_enter", "vehicle_exit"]:
			_update_gait(delta)
		return
	_update_gamepad_look(delta)
	_update_camera_mode()
	_update_interaction_target()
	_update_interaction()
	_update_movement(delta)
	_update_gait(delta)
	_apply_carry_pose_if_needed()

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
	if suppress_camera_toggle_until_release:
		if not Input.is_action_pressed("camera_toggle"):
			suppress_camera_toggle_until_release = false
		return
	if Input.is_action_just_pressed("camera_toggle"):
		first_person = not first_person
		spring_arm.spring_length = 0.08 if first_person else 3.6
		visual_root.visible = not first_person

func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not enabled:
		velocity = Vector3.ZERO

func suppress_modal_camera_leak() -> void:
	suppress_camera_toggle_until_release = true

func _update_interaction() -> void:
	if Input.is_action_just_pressed("interact") and is_instance_valid(current_interaction_target):
		interaction_requested.emit(current_interaction_target)

func _update_interaction_target() -> void:
	var nearest: Node3D
	var nearest_distance := interaction_distance
	for candidate in get_tree().get_nodes_in_group("interactable"):
		if candidate is not Node3D:
			continue
		var candidate_3d := candidate as Node3D
		var distance := global_position.distance_to(candidate_3d.global_position)
		if distance <= nearest_distance:
			nearest = candidate_3d
			nearest_distance = distance
	if nearest != current_interaction_target:
		current_interaction_target = nearest
		interaction_target_changed.emit(current_interaction_target)

func _update_movement(delta: float) -> void:
	var input_2d := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camera_forward := -camera.global_transform.basis.z
	var camera_right := camera.global_transform.basis.x
	camera_forward.y = 0.0
	camera_right.y = 0.0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()
	var direction := camera_right * input_2d.x + camera_forward * -input_2d.y
	if direction.length() > 1.0:
		direction = direction.normalized()
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
	_recover_if_out_of_bounds()

func _recover_if_out_of_bounds() -> void:
	if global_position.y >= fall_recovery_height:
		return
	global_position = recovery_position
	velocity = Vector3.ZERO

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		velocity.x = 0.0
		velocity.z = 0.0

func _update_gait(_delta: float) -> void:
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	if planar_speed > walk_speed + 0.45:
		_play_animation("Run")
	elif planar_speed > 0.2:
		_play_animation("Walk")
	else:
		_play_animation("Idle")

func _play_animation(animation_name: String) -> void:
	if animation_player == null or current_animation == animation_name:
		return
	if not animation_player.has_animation(animation_name):
		push_error("Courier animation is missing: %s" % animation_name)
		return
	animation_player.play(animation_name, 0.18)
	current_animation = animation_name

func play_interaction_presentation(kind: String) -> bool:
	if kind not in ["scan", "carry", "place"]:
		return false
	_cancel_presentation(false)
	presentation_kind = kind
	presentation_elapsed = 0.0
	presentation_duration = 0.72 if kind == "scan" else (0.92 if kind == "place" else 0.48)
	if kind == "scan":
		scanner_prop.visible = true
	elif kind == "place":
		presentation_parcel.visible = true
	set_meta("presentation_kind", presentation_kind)
	return true

func begin_vehicle_transition(kind: String, vehicle: PackagePeddlerVehicle, force_visual := false) -> bool:
	if kind not in ["vehicle_enter", "vehicle_exit"] or vehicle == null:
		return false
	_cancel_presentation(false)
	presentation_kind = kind
	presentation_elapsed = 0.0
	presentation_duration = 1.35
	transition_vehicle = vehicle
	transition_vehicle.set_door_open(true)
	transition_door = vehicle.exit_position()
	transition_seat = vehicle.global_position + vehicle.global_transform.basis.x * -0.48 + vehicle.global_transform.basis.z * -0.52 + Vector3.UP * 0.05
	if kind == "vehicle_enter":
		transition_start = global_position
	else:
		transition_start = transition_seat
		global_position = transition_seat
	visible = true
	set_controls_enabled(false)
	if camera:
		camera.current = true
	if vehicle.vehicle_camera:
		vehicle.vehicle_camera.current = false
	set_meta("presentation_kind", presentation_kind)
	if DisplayServer.get_name() == "headless" and not force_visual:
		_complete_vehicle_transition()
	return true

func cancel_authored_presentation() -> void:
	_cancel_presentation(true)

func _update_authored_presentation(delta: float) -> void:
	if presentation_kind == "":
		return
	presentation_elapsed += delta
	var progress := clampf(presentation_elapsed / maxf(presentation_duration, 0.001), 0.0, 1.0)
	if presentation_kind in ["vehicle_enter", "vehicle_exit"]:
		_update_vehicle_transition(progress)
	else:
		_update_interaction_pose(progress)
	if progress >= 1.0:
		if presentation_kind in ["vehicle_enter", "vehicle_exit"]:
			_complete_vehicle_transition()
		else:
			_cancel_presentation(true)

func _update_vehicle_transition(progress: float) -> void:
	var entering := presentation_kind == "vehicle_enter"
	if entering and progress >= 0.78 and transition_vehicle.door_open:
		transition_vehicle.set_door_open(false)
	var path_progress := progress if entering else 1.0 - progress
	if path_progress < 0.48:
		global_position = transition_start.lerp(transition_door, path_progress / 0.48)
		_play_animation("Walk")
	else:
		global_position = transition_door.lerp(transition_seat, (path_progress - 0.48) / 0.52)
		_play_animation("Idle")
	var vehicle_forward := -transition_vehicle.global_transform.basis.z
	visual_root.rotation.y = atan2(vehicle_forward.x, vehicle_forward.z)
	visual_root.rotation.x = deg_to_rad(-24.0) * sin(PI * progress)

func _complete_vehicle_transition() -> void:
	var finished_kind := presentation_kind
	if finished_kind == "vehicle_enter":
		if transition_vehicle:
			transition_vehicle.set_door_open(false)
		visible = false
		if camera:
			camera.current = false
	else:
		global_position = transition_door
		visible = true
		set_controls_enabled(true)
	visual_root.rotation.x = 0.0
	transition_vehicle = null
	presentation_kind = ""
	set_meta("presentation_kind", "")
	presentation_finished.emit(finished_kind)

func _update_interaction_pose(progress: float) -> void:
	var pose_weight := sin(PI * progress)
	if presentation_kind == "scan":
		scanner_prop.position = Vector3(0.28, 1.45, -0.36)
		scanner_prop.rotation_degrees = Vector3(-18.0, 4.0, -8.0)
		_apply_arm_pose(pose_weight, -48.0, -72.0, 62.0, 78.0, -4.0)
	elif presentation_kind == "carry":
		_apply_arm_pose(pose_weight, -35.0, -35.0, 70.0, 70.0, -6.0)
	elif presentation_kind == "place":
		presentation_parcel.position = Vector3(0.0, lerpf(1.05, 0.28, smoothstep(0.15, 0.82, progress)), -0.48)
		_apply_arm_pose(pose_weight, -42.0, -42.0, 74.0, 74.0, -28.0 * pose_weight)

func _apply_carry_pose_if_needed() -> void:
	var package := get_node_or_null("CarriedPackage") as MeshInstance3D
	if presentation_kind == "" and package != null and package.visible:
		_apply_arm_pose(1.0, -35.0, -35.0, 70.0, 70.0, -5.0)

func _apply_arm_pose(weight: float, left_upper: float, right_upper: float, left_lower: float, right_lower: float, spine_pitch: float) -> void:
	if courier_skeleton == null:
		return
	_set_bone_rotation("upperarm_l", Vector3(deg_to_rad(left_upper), 0.0, deg_to_rad(-12.0)) * weight)
	_set_bone_rotation("upperarm_r", Vector3(deg_to_rad(right_upper), 0.0, deg_to_rad(12.0)) * weight)
	_set_bone_rotation("lowerarm_l", Vector3(deg_to_rad(left_lower), 0.0, 0.0) * weight)
	_set_bone_rotation("lowerarm_r", Vector3(deg_to_rad(right_lower), 0.0, 0.0) * weight)
	_set_bone_rotation("spine_02", Vector3(deg_to_rad(spine_pitch), 0.0, 0.0) * weight)

func _set_bone_rotation(bone_name: String, authored_euler: Vector3) -> void:
	var index := courier_skeleton.find_bone(bone_name)
	if index < 0:
		return
	var base: Quaternion = saved_bone_rotations.get(bone_name, Quaternion.IDENTITY)
	courier_skeleton.set_bone_pose_rotation(index, base * Quaternion.from_euler(authored_euler))

func _cancel_presentation(emit_finished: bool) -> void:
	var finished_kind := presentation_kind
	if finished_kind in ["vehicle_enter", "vehicle_exit"]:
		if transition_vehicle:
			global_position = transition_door
			if transition_vehicle.vehicle_camera:
				transition_vehicle.vehicle_camera.current = false
		visible = true
		set_controls_enabled(true)
		if camera:
			camera.current = true
	if scanner_prop:
		scanner_prop.visible = false
	if presentation_parcel:
		presentation_parcel.visible = false
	_reset_authored_pose()
	visual_root.rotation.x = 0.0
	presentation_kind = ""
	presentation_elapsed = 0.0
	presentation_duration = 0.0
	transition_vehicle = null
	set_meta("presentation_kind", "")
	if emit_finished and finished_kind != "":
		presentation_finished.emit(finished_kind)

func _reset_authored_pose() -> void:
	if courier_skeleton == null:
		return
	for bone_name in saved_bone_rotations:
		var index := courier_skeleton.find_bone(String(bone_name))
		if index >= 0:
			courier_skeleton.set_bone_pose_rotation(index, saved_bone_rotations[bone_name])
