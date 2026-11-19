class_name PackagePeddlerTrafficVehicle
extends Node3D

var route_points: Array[Vector3] = []
var route_index := 0
var cruise_speed := 3.2

func configure(points: Array, color: Color, speed: float) -> void:
	route_points.clear()
	for point in points:
		if point is Vector3:
			route_points.append(point)
	cruise_speed = speed
	if route_points.size() > 0:
		position = route_points[0]
	_build_visual(color)

func _build_visual(color: Color) -> void:
	var body := MeshInstance3D.new()
	body.name = "TrafficBody"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.25, 0.72, 2.35)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	mesh.material = material
	body.mesh = mesh
	body.position.y = 0.52
	add_child(body)
	for side in [-1.0, 1.0]:
		var wheel := MeshInstance3D.new()
		var wheel_mesh := CylinderMesh.new()
		wheel_mesh.top_radius = 0.18
		wheel_mesh.bottom_radius = 0.18
		wheel_mesh.height = 0.11
		var wheel_material := StandardMaterial3D.new()
		wheel_material.albedo_color = Color("20252a")
		wheel_mesh.material = wheel_material
		wheel.mesh = wheel_mesh
		wheel.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		wheel.position = Vector3(side * 0.63, 0.28, 0.65)
		add_child(wheel)
		var rear_wheel := wheel.duplicate() as MeshInstance3D
		rear_wheel.position.z = -0.65
		add_child(rear_wheel)

func _process(delta: float) -> void:
	if route_points.size() < 2:
		return
	var target := route_points[route_index]
	var offset := target - global_position
	offset.y = 0.0
	if offset.length() < 0.8:
		route_index = (route_index + 1) % route_points.size()
		target = route_points[route_index]
		offset = target - global_position
		offset.y = 0.0
	if offset.length_squared() > 0.001:
		var direction := offset.normalized()
		global_position += direction * cruise_speed * delta
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-6.0 * delta))
