class_name PackagePeddlerVehicle
extends CharacterBody3D

signal driving_status_changed(message: String)

@export var display_name := "Courier Vehicle"
@export var body_color := Color("315f7c")
@export var maximum_forward_speed := 14.0
@export var maximum_reverse_speed := 5.0
@export var acceleration_rate := 7.5
@export var service_brake_rate := 15.0
@export var rolling_drag := 3.0
@export var steering_rate := 1.65

var speed := 0.0
var driving_active := false
var parked := true
var door_open := false
var door_pivot: Node3D
var vehicle_camera: Camera3D

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
	var camera_rig := Node3D.new()
	camera_rig.name = "VehicleCameraRig"
	camera_rig.position = Vector3(0.0, 2.15, 0.7)
	add_child(camera_rig)
	vehicle_camera = Camera3D.new()
	vehicle_camera.name = "VehicleCamera"
	vehicle_camera.position = Vector3(0.0, 1.25, 5.8)
	vehicle_camera.rotation_degrees.x = -9.0
	vehicle_camera.fov = 70.0
	vehicle_camera.current = false
	camera_rig.add_child(vehicle_camera)

func _physics_process(delta: float) -> void:
	door_pivot.rotation.y = move_toward(door_pivot.rotation.y, deg_to_rad(-68.0) if door_open else 0.0, delta * 4.8)
	if not driving_active:
		velocity = Vector3.ZERO
		return
	var throttle := Input.get_axis("move_back", "move_forward")
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
	velocity = -global_transform.basis.z * speed
	velocity.y = -1.0
	move_and_slide()
	if get_slide_collision_count() > 0:
		speed *= 0.35

func set_door_open(open: bool) -> void:
	door_open = open
	driving_status_changed.emit("%s driver door %s." % [display_name, "opened" if door_open else "closed"])

func set_driving_active(active: bool) -> void:
	driving_active = active
	vehicle_camera.current = active
	if not active:
		speed = 0.0

func toggle_park() -> bool:
	if not parked and absf(speed) > 0.45:
		driving_status_changed.emit("Stop the vehicle before engaging Park.")
		return false
	parked = not parked
	if parked:
		speed = 0.0
	driving_status_changed.emit("%s transmission: %s." % [display_name, "PARK" if parked else "DRIVE"])
	return true

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
