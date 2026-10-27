class_name PackagePeddlerVehicle
extends CharacterBody3D

const COURIER_SCENE: PackedScene = preload("res://assets/characters/courier.glb")

signal driving_status_changed(message: String)

@export var display_name := "Courier Vehicle"
@export var body_color := Color("315f7c")
@export var maximum_forward_speed := 14.0
@export var maximum_reverse_speed := 5.0
@export var acceleration_rate := 7.5
@export var service_brake_rate := 15.0
@export var rolling_drag := 3.0
@export var steering_rate := 1.65
@export var camera_mouse_sensitivity := 0.0025
@export var camera_stick_speed := 1.8
@export var camera_return_delay := 1.1
@export var camera_return_speed := 3.2
@export var camera_base_fov := 70.0
@export var camera_speed_fov_gain := 10.0
@export var camera_max_fov := 82.0

var speed := 0.0
var driving_active := false
var parked := true
var door_open := false
var door_pivot: Node3D
var vehicle_camera: Camera3D
var vehicle_camera_rig: Node3D
var vehicle_camera_arm: SpringArm3D
var vehicle_camera_yaw := 0.0
var vehicle_camera_pitch := deg_to_rad(-9.0)
var vehicle_camera_idle_time := 0.0
var steering_wheel: Node3D
var center_selector: MeshInstance3D
var seated_driver: Node3D
var seated_driver_skeleton: Skeleton3D
var seated_driver_animation: AnimationPlayer
var driver_pose_bases: Dictionary = {}
var driving_presentation_kind := ""
var driving_presentation_elapsed := 0.0
var driving_presentation_duration := 0.78
var selector_reach_weight := 0.0
var driver_variant := 0
var seated_driver_badge: MeshInstance3D

func _ready() -> void:
	_build_vehicle()
	set_physics_process(true)

func configure(vehicle_name: String, color: Color, size_scale := 1.0) -> void:
	display_name = vehicle_name
	body_color = color
	scale = Vector3.ONE * size_scale

func _build_vehicle() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "VehicleCollision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.15, 1.45, 4.6)
	collision.shape = shape
	collision.position.y = 0.82
	add_child(collision)
	_add_box("Body", Vector3(0.0, 0.75, 0.0), Vector3(2.1, 1.15, 4.5), body_color)
	_add_box("Cabin", Vector3(0.0, 1.45, -0.45), Vector3(1.92, 0.82, 2.45), body_color.lightened(0.09))
	_add_box("Windshield", Vector3(0.0, 1.54, -1.69), Vector3(1.68, 0.56, 0.07), Color("6d9cac"), Vector3(-13.0, 0.0, 0.0))
	for wheel_z in [-1.5, 1.38]:
		_add_wheel(Vector3(-1.08, 0.44, wheel_z))
		_add_wheel(Vector3(1.08, 0.44, wheel_z))
	door_pivot = Node3D.new()
	door_pivot.name = "DriverDoorPivot"
	door_pivot.position = Vector3(-1.08, 1.22, -0.62)
	add_child(door_pivot)
	var door := _box_mesh(Vector3(0.08, 1.15, 1.25), body_color.darkened(0.04))
	door.name = "DriverDoor"
	door.position = Vector3(0.0, 0.0, 0.48)
	door_pivot.add_child(door)
	vehicle_camera_rig = Node3D.new()
	vehicle_camera_rig.name = "VehicleCameraRig"
	vehicle_camera_rig.position = Vector3(0.0, 2.15, 0.7)
	add_child(vehicle_camera_rig)
	vehicle_camera_arm = SpringArm3D.new()
	vehicle_camera_arm.name = "VehicleCameraCollisionArm"
	vehicle_camera_arm.spring_length = 5.8
	vehicle_camera_arm.margin = 0.16
	vehicle_camera_rig.add_child(vehicle_camera_arm)
	vehicle_camera = Camera3D.new()
	vehicle_camera.name = "VehicleCamera"
	vehicle_camera.fov = 70.0
	vehicle_camera.current = false
	vehicle_camera_arm.add_child(vehicle_camera)
	_apply_vehicle_camera_orbit()
	_build_cockpit_presentation()

func _build_cockpit_presentation() -> void:
	# Provisional cockpit geometry provides stable authored targets for the
	# seated-driving pose. It is intentionally original and unbranded.
	_add_box("DriverSeat", Vector3(-0.48, 0.62, -0.38), Vector3(0.7, 0.7, 0.82), Color("252a2d"))
	steering_wheel = Node3D.new()
	steering_wheel.name = "SteeringWheel"
	steering_wheel.position = Vector3(-0.48, 1.38, -1.43)
	steering_wheel.rotation_degrees.x = 90.0
	add_child(steering_wheel)
	var wheel := MeshInstance3D.new()
	var wheel_mesh := TorusMesh.new()
	wheel_mesh.inner_radius = 0.22
	wheel_mesh.outer_radius = 0.3
	wheel_mesh.rings = 12
	wheel_mesh.ring_segments = 20
	var wheel_material := StandardMaterial3D.new()
	wheel_material.albedo_color = Color("17191b")
	wheel_mesh.material = wheel_material
	wheel.mesh = wheel_mesh
	steering_wheel.add_child(wheel)
	var spoke := _box_mesh(Vector3(0.48, 0.055, 0.055), Color("303438"))
	spoke.name = "WheelSpoke"
	steering_wheel.add_child(spoke)

	center_selector = _box_mesh(Vector3(0.09, 0.23, 0.09), Color("6f777c"))
	center_selector.name = "CenterSelector"
	center_selector.position = Vector3(0.02, 1.02, -0.78)
	center_selector.rotation_degrees.z = -18.0
	add_child(center_selector)

	_add_driver_target("LeftHandWheelTarget", Vector3(-0.69, 1.43, -1.39))
	_add_driver_target("RightHandWheelTarget", Vector3(-0.27, 1.43, -1.39))
	_add_driver_target("SelectorReachTarget", Vector3(0.02, 1.12, -0.78))

	seated_driver = COURIER_SCENE.instantiate() as Node3D
	seated_driver.name = "SeatedDriverPresentation"
	seated_driver.position = Vector3(-0.48, 0.26, -0.33)
	seated_driver.rotation.y = PI
	seated_driver.visible = false
	add_child(seated_driver)
	seated_driver_badge = _box_mesh(Vector3(0.46, 0.52, 0.045), Color("d8e539"))
	seated_driver_badge.name = "SeatedDriverVariantBadge"
	seated_driver_badge.position = Vector3(0.0, 1.28, -0.26)
	seated_driver.add_child(seated_driver_badge)
	seated_driver_skeleton = _find_skeleton(seated_driver)
	seated_driver_animation = _find_animation_player(seated_driver)
	if seated_driver_animation and seated_driver_animation.has_animation("Idle"):
		seated_driver_animation.play("Idle")
		seated_driver_animation.seek(0.08, true)
		seated_driver_animation.pause()
	_cache_driver_pose_bases()
	_apply_seated_driver_pose(0.0, 0.0)
	set_driver_variant(0)

func set_driver_variant(index: int) -> void:
	driver_variant = clampi(index, 0, 3)
	var colors := [Color("d8e539"), Color("d94b62"), Color("3d91d4"), Color("e18a35")]
	if seated_driver_badge:
		var material := StandardMaterial3D.new()
		material.albedo_color = colors[driver_variant]
		material.roughness = 0.7
		seated_driver_badge.material_override = material
	if seated_driver:
		seated_driver.set_meta("driver_variant", driver_variant)
	set_meta("driver_variant", driver_variant)
	_align_cockpit_to_authored_hands()

func _add_driver_target(target_name: String, local_position: Vector3) -> void:
	var target := Marker3D.new()
	target.name = target_name
	target.position = local_position
	add_child(target)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _cache_driver_pose_bases() -> void:
	if seated_driver_skeleton == null:
		return
	for bone_name in ["pelvis", "spine_01", "spine_02", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "thigh_l", "thigh_r", "calf_l", "calf_r"]:
		var index := seated_driver_skeleton.find_bone(bone_name)
		if index >= 0:
			driver_pose_bases[bone_name] = seated_driver_skeleton.get_bone_pose_rotation(index)

func _align_cockpit_to_authored_hands() -> void:
	if seated_driver_skeleton == null:
		return
	_apply_seated_driver_pose(0.0, 0.0)
	var left_hand := _driver_bone_vehicle_position("hand_l")
	var right_hand := _driver_bone_vehicle_position("hand_r")
	if left_hand != Vector3.ZERO and right_hand != Vector3.ZERO:
		var wheel_center := left_hand.lerp(right_hand, 0.5)
		steering_wheel.position = wheel_center
		var hand_span := left_hand.distance_to(right_hand)
		steering_wheel.scale = Vector3.ONE * clampf(hand_span / 0.52, 0.72, 1.35)
		(get_node("LeftHandWheelTarget") as Marker3D).position = left_hand
		(get_node("RightHandWheelTarget") as Marker3D).position = right_hand
	_apply_seated_driver_pose(1.0, 0.0)
	var reach_hand := _driver_bone_vehicle_position("hand_r")
	if reach_hand != Vector3.ZERO:
		center_selector.position = reach_hand + Vector3(0.0, -0.08, 0.0)
		(get_node("SelectorReachTarget") as Marker3D).position = reach_hand
	_apply_seated_driver_pose(0.0, 0.0)

func _driver_bone_vehicle_position(bone_name: String) -> Vector3:
	var index := seated_driver_skeleton.find_bone(bone_name)
	if index < 0:
		return Vector3.ZERO
	var skeleton_local := seated_driver_skeleton.get_bone_global_pose(index).origin
	return to_local(seated_driver_skeleton.to_global(skeleton_local))

func _physics_process(delta: float) -> void:
	door_pivot.rotation.y = move_toward(door_pivot.rotation.y, deg_to_rad(-68.0) if door_open else 0.0, delta * 4.8)
	_update_driving_presentation(delta)
	if not driving_active:
		velocity = Vector3.ZERO
		_update_vehicle_camera_presentation(delta)
		return
	_update_vehicle_camera(delta)
	var keyboard_throttle := Input.get_axis("move_back", "move_forward")
	# Windows DualSense drivers expose triggers differently across USB/DS4Windows:
	# support both the InputMap action and the raw SDL trigger axes.
	var trigger_throttle := _trigger_strength("vehicle_throttle", 5)
	var trigger_brake_reverse := _trigger_strength("vehicle_brake_reverse", 4)
	var throttle := keyboard_throttle
	if trigger_throttle > absf(throttle):
		throttle = trigger_throttle
	if trigger_brake_reverse > 0.05 and trigger_brake_reverse >= trigger_throttle:
		throttle = -trigger_brake_reverse
	var steering := Input.get_axis("move_left", "move_right")
	if parked:
		throttle = 0.0
	if throttle > 0.05:
		speed = move_toward(speed, maximum_forward_speed * throttle, acceleration_rate * delta)
	elif throttle < -0.05:
		if speed > 0.25:
			speed = move_toward(speed, 0.0, service_brake_rate * delta)
		else:
			speed = move_toward(speed, maximum_reverse_speed * throttle, acceleration_rate * 0.72 * delta)
	else:
		speed = move_toward(speed, 0.0, rolling_drag * delta)
	if Input.is_action_pressed("vehicle_brake"):
		speed = move_toward(speed, 0.0, service_brake_rate * delta)
	if absf(speed) > 0.08:
		var direction_sign := signf(speed)
		rotate_y(-steering * steering_rate * delta * clampf(absf(speed) / 5.0, 0.28, 1.0) * direction_sign)
	_apply_seated_driver_pose(selector_reach_weight, steering)
	velocity = -global_transform.basis.z * speed
	velocity.y = -1.0
	move_and_slide()
	if get_slide_collision_count() > 0:
		speed *= 0.35
	_update_vehicle_camera_presentation(delta)

func _trigger_strength(action_name: StringName, axis_index: int) -> float:
	var strength := Input.get_action_strength(action_name)
	for device in Input.get_connected_joypads():
		var raw := Input.get_joy_axis(device, axis_index)
		# SDL normally reports triggers from -1 (released) to 1 (pressed).
		# Some mappings report 0..1, which is already valid.
		var normalized := (raw + 1.0) * 0.5 if raw < 0.0 else raw
		strength = maxf(strength, clampf(normalized, 0.0, 1.0))
	return strength

func _unhandled_input(event: InputEvent) -> void:
	if not driving_active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		vehicle_camera_yaw = clampf(vehicle_camera_yaw - event.relative.x * camera_mouse_sensitivity, -2.35, 2.35)
		vehicle_camera_pitch = clampf(vehicle_camera_pitch - event.relative.y * camera_mouse_sensitivity, -0.75, 0.3)
		vehicle_camera_idle_time = 0.0
		_apply_vehicle_camera_orbit()

func _update_vehicle_camera(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.length_squared() > 0.001:
		vehicle_camera_yaw = clampf(vehicle_camera_yaw - look.x * camera_stick_speed * delta, -2.35, 2.35)
		vehicle_camera_pitch = clampf(vehicle_camera_pitch - look.y * camera_stick_speed * delta, -0.75, 0.3)
		vehicle_camera_idle_time = 0.0
	else:
		vehicle_camera_idle_time += delta
		if vehicle_camera_idle_time >= camera_return_delay:
			vehicle_camera_yaw = lerp_angle(vehicle_camera_yaw, 0.0, 1.0 - exp(-camera_return_speed * delta))
			vehicle_camera_pitch = lerp_angle(vehicle_camera_pitch, deg_to_rad(-9.0), 1.0 - exp(-camera_return_speed * delta))
	_apply_vehicle_camera_orbit()

# Widen the chase-camera view as the delivery van gains speed.
func _update_vehicle_camera_presentation(delta: float) -> void:
	if vehicle_camera == null:
		return
	var speed_ratio := clampf(absf(speed) / maxf(maximum_forward_speed, 0.01), 0.0, 1.0)
	var target_fov := clampf(camera_base_fov + speed_ratio * camera_speed_fov_gain, camera_base_fov, camera_max_fov)
	vehicle_camera.fov = lerpf(vehicle_camera.fov, target_fov, 1.0 - exp(-6.0 * delta))

func _apply_vehicle_camera_orbit() -> void:
	if vehicle_camera_rig:
		vehicle_camera_rig.rotation = Vector3(vehicle_camera_pitch, vehicle_camera_yaw, 0.0)

func set_door_open(open: bool) -> void:
	door_open = open
	driving_status_changed.emit("%s driver door %s." % [display_name, "opened" if door_open else "closed"])

func set_driving_active(active: bool) -> void:
	driving_active = active
	vehicle_camera.current = active
	if seated_driver:
		seated_driver.visible = active
	if not active:
		speed = 0.0
		cancel_driving_presentation()
	else:
		vehicle_camera_idle_time = 0.0
		_apply_seated_driver_pose(0.0, 0.0)

func has_exit_clearance(exclude_rids: Array[RID] = []) -> bool:
	if not is_inside_tree() or get_world_3d() == null:
		return true
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.65
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	# Keep the clearance capsule above road/curb surfaces so only obstacles in
	# the courier's standing volume prevent the exit.
	query.transform = Transform3D(Basis.IDENTITY, exit_position() + Vector3.UP * 0.98)
	query.exclude = [get_rid()]
	query.exclude.append_array(exclude_rids)
	query.collide_with_bodies = true
	query.collide_with_areas = true
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func toggle_park() -> bool:
	if not parked and absf(speed) > 0.45:
		driving_status_changed.emit("Stop the vehicle before engaging Park.")
		return false
	parked = not parked
	if parked:
		speed = 0.0
	driving_status_changed.emit("%s transmission: %s." % [display_name, "PARK" if parked else "DRIVE"])
	_start_selector_reach()
	return true

func _start_selector_reach() -> void:
	driving_presentation_kind = "selector_reach"
	driving_presentation_elapsed = 0.0
	selector_reach_weight = 0.0
	set_meta("driving_presentation_kind", driving_presentation_kind)

func cancel_driving_presentation() -> void:
	driving_presentation_kind = ""
	driving_presentation_elapsed = 0.0
	selector_reach_weight = 0.0
	set_meta("driving_presentation_kind", "")
	if seated_driver_skeleton:
		_apply_seated_driver_pose(0.0, 0.0)

func _update_driving_presentation(delta: float) -> void:
	if not driving_active:
		return
	if driving_presentation_kind == "selector_reach":
		driving_presentation_elapsed += delta
		var progress := clampf(driving_presentation_elapsed / driving_presentation_duration, 0.0, 1.0)
		selector_reach_weight = sin(PI * progress)
		if progress >= 1.0:
			driving_presentation_kind = ""
			driving_presentation_elapsed = 0.0
			selector_reach_weight = 0.0
			set_meta("driving_presentation_kind", "")

func _apply_seated_driver_pose(reach_weight: float, steering_input: float) -> void:
	if seated_driver_skeleton == null:
		return
	var steer := clampf(steering_input, -1.0, 1.0)
	# Both hands rest at authored wheel targets. During Park/Drive selection the
	# right arm briefly reaches toward the center control, then returns.
	_set_driver_bone_rotation("pelvis", Vector3(deg_to_rad(-8.0), 0.0, 0.0))
	_set_driver_bone_rotation("spine_01", Vector3(deg_to_rad(8.0), 0.0, 0.0))
	_set_driver_bone_rotation("spine_02", Vector3(deg_to_rad(5.0), deg_to_rad(-5.0 * reach_weight + steer * 2.0), 0.0))
	_set_driver_bone_rotation("thigh_l", Vector3(deg_to_rad(-72.0), 0.0, deg_to_rad(-4.0)))
	_set_driver_bone_rotation("thigh_r", Vector3(deg_to_rad(-72.0), 0.0, deg_to_rad(4.0)))
	_set_driver_bone_rotation("calf_l", Vector3(deg_to_rad(74.0), 0.0, 0.0))
	_set_driver_bone_rotation("calf_r", Vector3(deg_to_rad(74.0), 0.0, 0.0))
	_set_driver_bone_rotation("upperarm_l", Vector3(deg_to_rad(-52.0 + steer * 4.0), deg_to_rad(-8.0), deg_to_rad(-18.0)))
	_set_driver_bone_rotation("lowerarm_l", Vector3(deg_to_rad(86.0), deg_to_rad(-4.0), deg_to_rad(-6.0)))
	_set_driver_bone_rotation("upperarm_r", Vector3(deg_to_rad(lerpf(-52.0, -38.0, reach_weight) - steer * 4.0), deg_to_rad(lerpf(8.0, -20.0, reach_weight)), deg_to_rad(lerpf(18.0, 7.0, reach_weight))))
	_set_driver_bone_rotation("lowerarm_r", Vector3(deg_to_rad(lerpf(86.0, 58.0, reach_weight)), deg_to_rad(lerpf(4.0, -18.0, reach_weight)), deg_to_rad(lerpf(6.0, -10.0, reach_weight))))
	seated_driver_skeleton.force_update_all_bone_transforms()
	if steering_wheel:
		steering_wheel.rotation.z = deg_to_rad(-steer * 34.0)
	set_meta("selector_reach_weight", reach_weight)
	set_meta("seated_pose_active", driving_active)

func _set_driver_bone_rotation(bone_name: String, authored_euler: Vector3) -> void:
	var index := seated_driver_skeleton.find_bone(bone_name)
	if index < 0:
		return
	var base: Quaternion = driver_pose_bases.get(bone_name, Quaternion.IDENTITY)
	seated_driver_skeleton.set_bone_pose_rotation(index, base * Quaternion.from_euler(authored_euler))

func exit_position() -> Vector3:
	return global_position + global_transform.basis.x * -1.75 + Vector3.UP * 0.1

func door_world_position() -> Vector3:
	return global_position + global_transform.basis.x * -1.32 + global_transform.basis.z * -0.55 + Vector3.UP

func _add_box(node_name: String, local_position: Vector3, size: Vector3, color: Color, rotation_value := Vector3.ZERO) -> void:
	var mesh := _box_mesh(size, color)
	mesh.name = node_name
	mesh.position = local_position
	mesh.rotation_degrees = rotation_value
	add_child(mesh)

func _box_mesh(size: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	mesh.material = material
	instance.mesh = mesh
	return instance

func _add_wheel(local_position: Vector3) -> void:
	var wheel := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.42
	mesh.bottom_radius = 0.42
	mesh.height = 0.22
	mesh.radial_segments = 12
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("17191b")
	mesh.material = material
	wheel.mesh = mesh
	wheel.position = local_position
	wheel.rotation_degrees.z = 90.0
	add_child(wheel)
