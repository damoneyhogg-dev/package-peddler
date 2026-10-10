extends Node3D

const PlayerController = preload("res://src/player_controller.gd")

var status_label: Label
var interaction_label: Label
var pause_label: Label
var player: PackagePeddlerPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_lighting()
	_build_neighborhood_vertical_slice()
	_build_player()
	_build_hud()
	print("PACKAGE_PEDDLER_READY character=rigged environment=vertical_slice")

func _build_lighting() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("4d86b3")
	sky_material.sky_horizon_color = Color("b9d8e7")
	sky_material.ground_bottom_color = Color("33422f")
	sky_material.ground_horizon_color = Color("9eb28b")
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d6e3ea")
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("b9cbd0")
	env.fog_density = 0.0025
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color("ffe4b2")
	sun.light_energy = 0.82
	sun.shadow_enabled = true
	add_child(sun)

func _build_neighborhood_vertical_slice() -> void:
	_add_static_box("Ground", Vector3(0.0, -0.28, 0.0), Vector3(70.0, 0.5, 70.0), Color("56724c"))
	_add_world_boundaries()
	# Fictionalized from private route references; no filmed property, address,
	# brand, or road layout is reproduced.
	_add_static_box("RouteRoad", Vector3(0.0, 0.0, 3.6), Vector3(68.0, 0.08, 10.5), Color("2f3438"))
	_add_mesh_box("CenterLineA", Vector3(-19.0, 0.055, 3.6), Vector3(12.0, 0.02, 0.14), Color("e6c84f"))
	_add_mesh_box("CenterLineB", Vector3(0.0, 0.055, 3.6), Vector3(12.0, 0.02, 0.14), Color("e6c84f"))
	_add_mesh_box("CenterLineC", Vector3(19.0, 0.055, 3.6), Vector3(12.0, 0.02, 0.14), Color("e6c84f"))
	_add_static_box("SidewalkNorth", Vector3(0.0, 0.08, -2.3), Vector3(68.0, 0.16, 1.25), Color("b9b6ac"))
	_add_static_box("SidewalkSouth", Vector3(0.0, 0.08, 9.5), Vector3(68.0, 0.16, 1.25), Color("b9b6ac"))
	_build_house()
	_build_warehouse()
	_build_minivan()
	_build_street_details()
	_add_static_box("LoadingDock", Vector3(13.0, 0.45, -8.8), Vector3(12.0, 0.9, 2.0), Color("4d555b"))
	_add_interaction_point("VehicleDoor", Vector3(-6.4, 1.0, -2.0), "enter the parked vehicle")
	_add_interaction_point("WarehouseEntrance", Vector3(13.0, 1.0, -8.0), "enter the warehouse")
	for x in range(-2, 3):
		_add_static_box("TrafficBarrier_%s" % x, Vector3(float(x) * 2.2 + 16.0, 0.35, 8.0), Vector3(1.4, 0.7, 0.34), Color("dc762c"))

func _build_house() -> void:
	_add_static_box("Home", Vector3(-12.0, 2.0, -10.5), Vector3(9.0, 4.0, 7.0), Color("d8c5a5"))
	_add_mesh_box("HomeFoundation", Vector3(-12.0, 0.35, -10.5), Vector3(9.35, 0.7, 7.35), Color("80756b"))
	_add_mesh_box("HomeRoofLeft", Vector3(-14.0, 4.35, -10.5), Vector3(5.1, 0.35, 7.7), Color("453f3c"), Vector3(0.0, 0.0, 24.0))
	_add_mesh_box("HomeRoofRight", Vector3(-10.0, 4.35, -10.5), Vector3(5.1, 0.35, 7.7), Color("453f3c"), Vector3(0.0, 0.0, -24.0))
	_add_mesh_box("HomeDoor", Vector3(-12.0, 1.25, -6.97), Vector3(1.25, 2.4, 0.12), Color("315248"))
	_add_mesh_box("HomeWindowLeft", Vector3(-15.1, 2.25, -6.96), Vector3(1.65, 1.25, 0.13), Color("8fc5d3"))
	_add_mesh_box("HomeWindowRight", Vector3(-8.9, 2.25, -6.96), Vector3(1.65, 1.25, 0.13), Color("8fc5d3"))
	_add_static_box("FrontSteps", Vector3(-12.0, 0.22, -6.25), Vector3(3.1, 0.44, 1.3), Color("9d9489"))

func _build_warehouse() -> void:
	_add_static_box("Warehouse", Vector3(13.0, 3.0, -15.0), Vector3(18.0, 6.0, 10.0), Color("84939d"))
	_add_mesh_box("WarehouseTrim", Vector3(13.0, 5.65, -9.94), Vector3(18.2, 0.45, 0.14), Color("263640"))
	_add_mesh_box("WarehouseDoor", Vector3(13.0, 2.25, -9.94), Vector3(5.8, 4.5, 0.16), Color("d4d8d6"))
	for stripe in range(1, 5):
		_add_mesh_box("DoorPanel_%s" % stripe, Vector3(13.0, float(stripe) * 0.82, -9.84), Vector3(5.5, 0.08, 0.05), Color("899398"))
	_add_mesh_box("WarehouseSign", Vector3(13.0, 5.1, -9.82), Vector3(6.0, 0.9, 0.18), Color("274d68"))

func _build_minivan() -> void:
	_add_static_box("ParkedVehicle", Vector3(-5.0, 0.65, -2.0), Vector3(2.15, 1.15, 4.6), Color("315f7c"))
	_add_mesh_box("VanCabin", Vector3(-5.0, 1.35, -1.55), Vector3(2.0, 0.85, 2.55), Color("3b7090"))
	_add_mesh_box("VanWindshield", Vector3(-5.0, 1.48, -0.25), Vector3(1.75, 0.58, 0.08), Color("6d9cac"), Vector3(14.0, 0.0, 0.0))
	_add_mesh_box("VanSideWindow", Vector3(-6.02, 1.48, -1.2), Vector3(0.08, 0.55, 1.25), Color("668d99"))
	for wheel_z in [-3.35, -0.7]:
		_add_mesh_cylinder("VanWheelL", Vector3(-6.1, 0.45, wheel_z), 0.42, 0.22, Color("17191b"), Vector3(0.0, 0.0, 90.0))
		_add_mesh_cylinder("VanWheelR", Vector3(-3.9, 0.45, wheel_z), 0.42, 0.22, Color("17191b"), Vector3(0.0, 0.0, 90.0))

func _build_street_details() -> void:
	for tree_data in [
		[Vector3(-24.0, 0.0, -7.0), 1.25], [Vector3(-20.0, 0.0, 13.0), 1.0],
		[Vector3(25.0, 0.0, -5.0), 1.3], [Vector3(29.0, 0.0, 13.0), 1.05]
	]:
		var base := tree_data[0] as Vector3
		var size := float(tree_data[1])
		_add_mesh_cylinder("TreeTrunk", base + Vector3(0.0, 1.4 * size, 0.0), 0.22 * size, 2.8 * size, Color("5c3c26"))
		_add_mesh_sphere("TreeCanopy", base + Vector3(0.0, 3.5 * size, 0.0), 1.5 * size, Color("315f35"))
	for pole_x in [-28.0, -8.0, 12.0, 32.0]:
		_add_mesh_cylinder("UtilityPole", Vector3(pole_x, 3.3, 12.0), 0.14, 6.6, Color("634833"))
		_add_mesh_box("UtilityCrossbar", Vector3(pole_x, 6.0, 12.0), Vector3(1.8, 0.12, 0.12), Color("51402f"))
	_add_mesh_cylinder("Hydrant", Vector3(-18.0, 0.42, -2.0), 0.22, 0.84, Color("b84035"))
	for mailbox_x in [-18.0, -8.0, 4.0, 22.0]:
		_add_mesh_box("MailboxPost", Vector3(mailbox_x, 0.55, -2.0), Vector3(0.12, 1.1, 0.12), Color("564b40"))
		_add_mesh_box("Mailbox", Vector3(mailbox_x, 1.15, -2.0), Vector3(0.65, 0.48, 0.4), Color("30383d"))

func _add_world_boundaries() -> void:
	var transparent := Color(0.0, 0.0, 0.0, 0.0)
	_add_static_box("WorldBoundaryNorth", Vector3(0.0, 0.75, -34.5), Vector3(70.0, 2.0, 1.0), transparent, false)
	_add_static_box("WorldBoundarySouth", Vector3(0.0, 0.75, 34.5), Vector3(70.0, 2.0, 1.0), transparent, false)
	_add_static_box("WorldBoundaryWest", Vector3(-34.5, 0.75, 0.0), Vector3(1.0, 2.0, 70.0), transparent, false)
	_add_static_box("WorldBoundaryEast", Vector3(34.5, 0.75, 0.0), Vector3(1.0, 2.0, 70.0), transparent, false)

func _add_interaction_point(point_name: String, position_value: Vector3, action_text: String) -> void:
	var point := Marker3D.new()
	point.name = point_name
	point.position = position_value
	point.set_meta("interaction_text", action_text)
	point.add_to_group("interactable")
	add_child(point)

func _add_static_box(label: String, position_value: Vector3, size: Vector3, color: Color, visible := true) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = position_value
	if visible:
		body.add_child(_box_mesh(size, color))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _add_mesh_box(label: String, position_value: Vector3, size: Vector3, color: Color, rotation_value := Vector3.ZERO) -> void:
	var mesh_instance := _box_mesh(size, color)
	mesh_instance.name = label
	mesh_instance.position = position_value
	mesh_instance.rotation_degrees = rotation_value
	add_child(mesh_instance)

func _box_mesh(size: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	instance.mesh = mesh
	return instance

func _add_mesh_cylinder(label: String, position_value: Vector3, radius: float, height: float, color: Color, rotation_value := Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.material = _material(color)
	instance.mesh = mesh
	instance.position = position_value
	instance.rotation_degrees = rotation_value
	add_child(instance)

func _add_mesh_sphere(label: String, position_value: Vector3, radius: float, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = _material(color)
	instance.mesh = mesh
	instance.position = position_value
	add_child(instance)

func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.78
	return result

func _build_player() -> void:
	player = PlayerController.new()
	player.name = "CourierPlayer"
	player.position = Vector3(-11.0, 1.0, -1.0)
	add_child(player)
	player.interaction_requested.connect(_on_interaction_requested)
	player.interaction_target_changed.connect(_on_interaction_target_changed)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.position = Vector2(18.0, 18.0)
	panel.size = Vector2(560.0, 104.0)
	panel.color = Color(0.03, 0.05, 0.07, 0.82)
	layer.add_child(panel)
	var title := Label.new()
	title.position = Vector2(34.0, 28.0)
	title.text = "PACKAGE PEDDLER - 3D VERTICAL SLICE"
	title.add_theme_font_size_override("font_size", 22)
	layer.add_child(title)
	status_label = Label.new()
	status_label.position = Vector2(34.0, 62.0)
	status_label.text = "WASD / left stick: move   Shift: sprint   Mouse / right stick: camera\nV / Y: camera view   E / A: interact   Esc / Menu: pause"
	status_label.add_theme_font_size_override("font_size", 15)
	layer.add_child(status_label)
	interaction_label = Label.new()
	interaction_label.position = Vector2(34.0, 132.0)
	interaction_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(interaction_label)
	pause_label = Label.new()
	pause_label.position = Vector2(34.0, 174.0)
	pause_label.text = "PAUSED\nPress Esc / Menu to resume"
	pause_label.add_theme_font_size_override("font_size", 28)
	pause_label.visible = false
	layer.add_child(pause_label)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	pause_label.visible = get_tree().paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if get_tree().paused else Input.MOUSE_MODE_CAPTURED

func _on_interaction_target_changed(target: Node3D) -> void:
	interaction_label.text = "Press E / A to %s" % String(target.get_meta("interaction_text", "interact")) if is_instance_valid(target) else ""

func _on_interaction_requested(target: Node3D) -> void:
	status_label.text = "Context interaction accepted: %s" % String(target.get_meta("interaction_text", "interact"))
	get_tree().create_timer(2.2).timeout.connect(func() -> void:
		status_label.text = "WASD / left stick: move   Shift: sprint   Mouse / right stick: camera\nV / Y: camera view   E / A: interact   Esc / Menu: pause"
	)
