extends Node3D

const PlayerController = preload("res://src/player_controller.gd")
const GameplayState = preload("res://src/gameplay_state.gd")
const VehicleController = preload("res://src/vehicle_controller.gd")
const MANUAL_STOP_ORDER := ["WB-02", "WB-01", "WB-03", "WB-04", "WB-05"]

var status_label: Label
var interaction_label: Label
var interaction_panel: ColorRect
var pause_label: Label
var player: PackagePeddlerPlayer
var modal_panel: ColorRect
var modal_label: Label
var active_modal := ""
var gameplay_state := GameplayState.new()
var vehicles: Array[PackagePeddlerVehicle] = []
var current_vehicle: PackagePeddlerVehicle
var vehicle_door_point: Marker3D
var driving := false
var door_waiting_for_close := false
var vehicle_transition_active := false
var vehicle_transition_kind := ""
var vehicle_transition_cancel_target := ""
var force_vehicle_transition_visuals := false
var carried_package: MeshInstance3D
var placed_package: MeshInstance3D
var stop_arrivals: Dictionary = {}
var stop_delivery_points: Dictionary = {}
var stop_proof_points: Dictionary = {}
var route_hud: Label
var runtime_save_path := GameplayState.SAVE_PATH
var route_draft_order: Array[String] = []
var save_warning := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	gameplay_state.load_game(runtime_save_path)
	_build_lighting()
	_build_neighborhood_vertical_slice()
	_build_player()
	_build_hud()
	_apply_saved_driver()
	_select_runtime_vehicle(GameplayState.VEHICLES.find(gameplay_state.selected_vehicle))
	_restore_saved_runtime_state()
	_restore_visible_runtime_state()
	_show_status("Loaded driver: %s | Vehicle: %s | Credits: %d" % [gameplay_state.selected_driver, gameplay_state.selected_vehicle, gameplay_state.credits])
	if gameplay_state.route_phase == "NO_ROUTE":
		_open_driver_menu()
	print("PACKAGE_PEDDLER_READY character=rigged drivers=4 vehicle_drive=true doors=true environment=vertical_slice")

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
	_build_second_vehicle()
	_build_rival_courier()
	_build_street_details()
	_build_five_stop_destinations()
	_add_static_box("LoadingDock", Vector3(13.0, 0.45, -8.8), Vector3(12.0, 0.9, 2.0), Color("4d555b"))
	_add_interaction_point("DriverKiosk", Vector3(-11.0, 1.0, -3.2), "choose a courier")
	get_node("DriverKiosk").set_meta("interaction_kind", "driver_select")
	_add_interaction_point("VehicleSelector", Vector3(-7.0, 1.0, -4.2), "choose a delivery vehicle")
	get_node("VehicleSelector").set_meta("interaction_kind", "vehicle_swap")
	_add_interaction_point("VehicleDoor", Vector3(-6.4, 1.0, -2.0), "open the selected vehicle door")
	vehicle_door_point = get_node("VehicleDoor") as Marker3D
	vehicle_door_point.set_meta("interaction_kind", "vehicle_access")
	_add_interaction_point("ContestedAddress", Vector3(-12.0, 1.0, -5.2), "deliver at the contested address")
	get_node("ContestedAddress").set_meta("interaction_kind", "contested_address")
	_add_interaction_point("WarehouseEntrance", Vector3(13.0, 1.0, -8.0), "enter the warehouse")
	get_node("WarehouseEntrance").set_meta("interaction_kind", "route_terminal")
	_add_interaction_point("PackageStation", Vector3(16.0, 1.0, -8.0), "scan the assigned package")
	get_node("PackageStation").set_meta("interaction_kind", "package_station")
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
	var van := VehicleController.new() as PackagePeddlerVehicle
	van.name = "ParkedVehicle"
	van.configure("Parcel Finch", Color("315f7c"), 1.0)
	van.position = Vector3(-5.0, 0.05, -2.0)
	van.driving_status_changed.connect(_show_status)
	add_child(van)
	vehicles.append(van)

func _build_second_vehicle() -> void:
	var comet := VehicleController.new() as PackagePeddlerVehicle
	comet.name = "CargoComet"
	comet.configure("Cargo Comet", Color("bd5c35"), 0.88)
	comet.position = Vector3(-9.0, 0.05, -2.0)
	comet.driving_status_changed.connect(_show_status)
	add_child(comet)
	vehicles.append(comet)

func _build_rival_courier() -> void:
	_add_mesh_cylinder("RivalCourierBody", Vector3(-10.7, 1.05, -5.4), 0.32, 1.35, Color("7b3548"))
	_add_mesh_sphere("RivalCourierHead", Vector3(-10.7, 1.95, -5.4), 0.28, Color("9a684d"))

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

func _build_five_stop_destinations() -> void:
	# Compact fictional route assembled from generalized private-reference cues;
	# no filmed address, property layout, person, brand, or media is shipped.
	_add_static_box("RouteRoadEast", Vector3(20.0, 0.0, 12.0), Vector3(10.5, 0.08, 28.0), Color("2f3438"))
	_add_static_box("RouteRoadSouth", Vector3(0.0, 0.0, 22.0), Vector3(50.0, 0.08, 10.5), Color("2f3438"))
	_add_static_box("RouteRoadWest", Vector3(-23.0, 0.0, 14.0), Vector3(10.5, 0.08, 20.0), Color("2f3438"))
	_build_apartment_stop()
	_build_restaurant_stop()
	_build_oversized_stop()
	_build_animal_stop()
	_add_stop_markers("WB-01", Vector3(-15.0, 1.0, 1.0), Vector3(-12.0, 1.0, -6.1), Vector3(-11.25, 1.0, -6.1), "residential porch")
	_add_stop_markers("WB-02", Vector3(20.0, 1.0, 2.0), Vector3(24.5, 1.0, 3.4), Vector3(23.7, 0.8, 3.4), "apartment unit C-204")
	_add_stop_markers("WB-03", Vector3(20.0, 1.0, 15.0), Vector3(27.2, 1.0, 15.0), Vector3(26.2, 1.0, 15.0), "restaurant public counter")
	_add_stop_markers("WB-04", Vector3(-3.0, 1.0, 22.0), Vector3(-1.4, 1.0, 27.0), Vector3(-0.6, 1.0, 27.0), "oversized safe-placement zone")
	_add_stop_markers("WB-05", Vector3(-23.0, 1.0, 16.0), Vector3(-28.0, 1.0, 16.0), Vector3(-27.2, 1.0, 16.0), "animal-safety porch")

func _build_apartment_stop() -> void:
	_add_static_box("ApartmentBuilding", Vector3(29.0, 3.0, 3.5), Vector3(8.0, 6.0, 8.0), Color("a8927a"))
	_add_mesh_box("ApartmentDoorC204", Vector3(25.0, 2.0, 3.4), Vector3(0.15, 2.2, 1.2), Color("40566b"))
	for step in range(5):
		_add_mesh_box("ApartmentStep_%d" % step, Vector3(24.6 - float(step) * 0.42, 0.075 + float(step) * 0.15, 3.4), Vector3(0.48, 0.15 + float(step) * 0.3, 2.0), Color("99958f"))
	_add_static_ramp("ApartmentStairRamp", Vector3(23.75, 0.38, 3.4), Vector3(2.5, 0.14, 1.8), 17.0)
	_add_mesh_box("ApartmentUnitPlaque", Vector3(24.9, 2.5, 2.8), Vector3(0.12, 0.38, 0.5), Color("e2d4a2"))

func _build_restaurant_stop() -> void:
	_add_static_box("Restaurant", Vector3(28.0, 0.0, 15.0), Vector3(7.0, 0.08, 8.0), Color("756c62"))
	_add_static_box("RestaurantBackWall", Vector3(31.45, 2.2, 15.0), Vector3(0.2, 4.4, 8.0), Color("9f5948"))
	_add_static_box("RestaurantNorthWall", Vector3(28.0, 2.2, 11.05), Vector3(7.0, 4.4, 0.2), Color("9f5948"))
	_add_static_box("RestaurantSouthWall", Vector3(28.0, 2.2, 18.95), Vector3(7.0, 4.4, 0.2), Color("9f5948"))
	_add_static_box("RestaurantFrontLeft", Vector3(24.55, 2.2, 12.0), Vector3(0.2, 4.4, 2.0), Color("9f5948"))
	_add_static_box("RestaurantFrontRight", Vector3(24.55, 2.2, 18.0), Vector3(0.2, 4.4, 2.0), Color("9f5948"))
	_add_mesh_box("RestaurantRoof", Vector3(28.0, 4.45, 15.0), Vector3(7.2, 0.2, 8.2), Color("51413a"))
	_add_mesh_box("RestaurantPublicDoor", Vector3(24.45, 1.2, 15.0), Vector3(0.14, 2.4, 1.4), Color("8fc5d3"))
	_add_mesh_box("RestaurantCounter", Vector3(26.0, 0.65, 15.0), Vector3(0.8, 1.3, 3.0), Color("574033"))
	_add_mesh_box("RestaurantSign", Vector3(24.35, 3.2, 15.0), Vector3(0.15, 0.7, 3.8), Color("d6a747"))

func _build_oversized_stop() -> void:
	_add_static_box("OverlookHome", Vector3(-3.0, 2.0, 30.0), Vector3(9.0, 4.0, 6.0), Color("c6b99c"))
	_add_mesh_box("OverlookOutwardDoor", Vector3(-3.0, 1.25, 26.95), Vector3(1.4, 2.4, 0.14), Color("6b4235"))
	_add_mesh_box("SafePlacementOutline", Vector3(-1.4, 0.04, 27.0), Vector3(1.4, 0.03, 1.4), Color("5fbf75"))
	_add_mesh_box("DeliveryDolly", Vector3(-4.5, 0.65, 26.7), Vector3(0.18, 1.3, 0.75), Color("d29135"), Vector3(0.0, 0.0, -12.0))

func _build_animal_stop() -> void:
	_add_static_box("AnimalYardHome", Vector3(-31.0, 2.0, 16.0), Vector3(6.0, 4.0, 8.0), Color("b7c0a3"))
	for fence in [[Vector3(-27.5, 0.65, 12.0), Vector3(0.15, 1.3, 8.0)], [Vector3(-27.5, 0.65, 20.0), Vector3(0.15, 1.3, 8.0)], [Vector3(-31.0, 0.65, 12.0), Vector3(7.0, 1.3, 0.15)], [Vector3(-31.0, 0.65, 20.0), Vector3(7.0, 1.3, 0.15)]]:
		_add_mesh_box("AnimalYardFence", fence[0], fence[1], Color("6c553d"))
	_add_mesh_cylinder("YardDogBody", Vector3(-29.5, 0.55, 17.2), 0.35, 0.9, Color("8a5b35"), Vector3(90.0, 0.0, 0.0))
	_add_mesh_sphere("YardDogHead", Vector3(-29.0, 0.75, 17.2), 0.3, Color("765034"))

func _add_stop_markers(stop_id: String, arrival_position: Vector3, delivery_position: Vector3, proof_position: Vector3, label: String) -> void:
	var arrival_name := "Stop%sArrival" % stop_id.replace("-", "")
	_add_interaction_point(arrival_name, arrival_position, "check arrival at %s" % label)
	var arrival := get_node(arrival_name) as Marker3D
	arrival.set_meta("interaction_kind", "stop_arrival")
	arrival.set_meta("stop_id", stop_id)
	stop_arrivals[stop_id] = arrival
	var delivery_name := "Stop%sDelivery" % stop_id.replace("-", "")
	_add_interaction_point(delivery_name, delivery_position, "place the package at %s" % label)
	var delivery := get_node(delivery_name) as Marker3D
	delivery.set_meta("interaction_kind", "stop_delivery")
	delivery.set_meta("stop_id", stop_id)
	stop_delivery_points[stop_id] = delivery
	var proof_name := "Stop%sProof" % stop_id.replace("-", "")
	_add_interaction_point(proof_name, proof_position, "capture proof at %s" % label)
	var proof := get_node(proof_name) as Marker3D
	proof.set_meta("interaction_kind", "stop_proof")
	proof.set_meta("stop_id", stop_id)
	stop_proof_points[stop_id] = proof

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
	var label := Label3D.new()
	label.name = "WorldPrompt"
	label.text = action_text.to_upper()
	label.position = Vector3(0.0, 1.25, 0.0)
	label.font_size = 38
	label.outline_size = 8
	label.modulate = Color("f4df91")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	# Prompts are presented in the fixed HUD, not as scattered world text.
	label.visible = false
	point.add_child(label)
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

func _add_static_ramp(label: String, position_value: Vector3, size: Vector3, rotation_z_degrees: float) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = position_value
	body.rotation_degrees.z = rotation_z_degrees
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
	player.presentation_finished.connect(_on_player_presentation_finished)
	carried_package = _box_mesh(Vector3(0.62, 0.48, 0.42), Color("9b6b3f"))
	carried_package.name = "CarriedPackage"
	carried_package.position = Vector3(0.0, 1.05, -0.48)
	carried_package.visible = false
	player.add_child(carried_package)
	placed_package = _box_mesh(Vector3(0.62, 0.48, 0.42), Color("9b6b3f"))
	placed_package.name = "PlacedPackage"
	placed_package.visible = false
	add_child(placed_package)

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
	interaction_panel = ColorRect.new()
	interaction_panel.position = Vector2(18.0, 126.0)
	interaction_panel.size = Vector2(560.0, 54.0)
	interaction_panel.color = Color(0.03, 0.05, 0.07, 0.86)
	layer.add_child(interaction_panel)
	interaction_label = Label.new()
	interaction_label.position = Vector2(34.0, 140.0)
	interaction_label.size = Vector2(528.0, 34.0)
	interaction_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(interaction_label)
	route_hud = Label.new()
	route_hud.position = Vector2(650.0, 24.0)
	route_hud.size = Vector2(590.0, 126.0)
	route_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	route_hud.add_theme_font_size_override("font_size", 17)
	layer.add_child(route_hud)
	pause_label = Label.new()
	pause_label.position = Vector2(34.0, 174.0)
	pause_label.text = "PAUSED\nPress Esc / Menu to resume"
	pause_label.add_theme_font_size_override("font_size", 28)
	pause_label.visible = false
	layer.add_child(pause_label)
	modal_panel = ColorRect.new()
	modal_panel.position = Vector2(340.0, 210.0)
	modal_panel.size = Vector2(600.0, 300.0)
	modal_panel.color = Color(0.025, 0.035, 0.05, 0.96)
	modal_panel.visible = false
	layer.add_child(modal_panel)
	modal_label = Label.new()
	modal_label.position = Vector2(28.0, 24.0)
	modal_label.size = Vector2(544.0, 252.0)
	modal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_label.add_theme_font_size_override("font_size", 19)
	modal_panel.add_child(modal_label)
	_update_route_hud()

func _restore_visible_runtime_state() -> void:
	_set_carried_package_visible(gameplay_state.route_phase == "PACKAGE_RETRIEVED")
	placed_package.visible = gameplay_state.route_phase == "PLACED"
	if placed_package.visible and stop_delivery_points.has(gameplay_state.current_stop_id):
		placed_package.global_position = (stop_delivery_points[gameplay_state.current_stop_id] as Marker3D).global_position + Vector3(0.0, 0.28, 0.0)
	_update_route_hud()

func _restore_saved_runtime_state() -> void:
	if current_vehicle == null or player == null:
		return
	current_vehicle.parked = gameplay_state.vehicle_parked
	current_vehicle.speed = 0.0
	current_vehicle.set_door_open(gameplay_state.vehicle_door_open)
	vehicle_transition_active = false
	vehicle_transition_kind = ""
	vehicle_transition_cancel_target = ""
	if gameplay_state.runtime_location == "IN_VEHICLE":
		# Reloads resume at a deterministic endpoint, never midway through an
		# entry or exit animation.
		driving = true
		door_waiting_for_close = false
		current_vehicle.set_door_open(false)
		player.set_player_active(false)
		current_vehicle.set_driving_active(true)
		vehicle_door_point.remove_from_group("interactable")
		interaction_label.text = ""
	else:
		driving = false
		door_waiting_for_close = gameplay_state.door_waiting_for_close
		player.global_position = gameplay_state.player_position
		player.set_player_active(true)
		current_vehicle.set_driving_active(false)
		vehicle_door_point.add_to_group("interactable")
		var prompt := "open the %s driver door" % current_vehicle.display_name
		if current_vehicle.door_open:
			prompt = ("close the %s driver door" if door_waiting_for_close else "enter %s") % current_vehicle.display_name
		vehicle_door_point.set_meta("interaction_text", prompt)

func _update_route_hud() -> void:
	if route_hud == null:
		return
	if gameplay_state.route_phase == "NO_ROUTE":
		route_hud.text = "NO ACTIVE ROUTE\nVisit the warehouse terminal"
		_refresh_stop_markers()
		return
	var completed := 0
	for stop in gameplay_state.stops.values():
		if String(stop.status) in ["DELIVERED", "RETURNED"]:
			completed += 1
	var target := gameplay_state.gps_target_address
	if gameplay_state.route_phase == "RETURN_PENDING":
		target = "Willowbrook Distribution Warehouse"
	route_hud.text = "ROUTE %s | %d/5 settled\nPHASE: %s\nGPS: %s" % [gameplay_state.route_id, completed, gameplay_state.route_phase, target]
	_refresh_stop_markers()

func _refresh_stop_markers() -> void:
	for stop_id in stop_arrivals:
		_set_stop_marker_enabled(stop_arrivals[stop_id], stop_id == gameplay_state.current_stop_id and gameplay_state.route_phase == "DRIVING")
		_set_stop_marker_enabled(stop_delivery_points[stop_id], stop_id == gameplay_state.current_stop_id and gameplay_state.route_phase in ["AT_STOP", "PACKAGE_RETRIEVED"])
		_set_stop_marker_enabled(stop_proof_points[stop_id], stop_id == gameplay_state.current_stop_id and gameplay_state.route_phase == "PLACED")

func _set_stop_marker_enabled(marker: Marker3D, enabled: bool) -> void:
	if enabled:
		marker.add_to_group("interactable")
	else:
		marker.remove_from_group("interactable")
	var prompt := marker.get_node_or_null("WorldPrompt") as Label3D
	if prompt:
		prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if vehicle_transition_active:
		if event.is_action_pressed("menu_cancel") and not event.is_echo():
			_resolve_vehicle_transition_for_interruption()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("pause") and not event.is_echo():
			_resolve_vehicle_transition_for_interruption()
			_toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	if active_modal != "" and event.is_pressed() and not event.is_echo():
		_handle_modal_input()
		get_viewport().set_input_as_handled()
		return
	if driving and event.is_pressed() and not event.is_echo():
		if event.is_action_pressed("vehicle_park"):
			if current_vehicle.toggle_park():
				_save_game()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("interact"):
			_attempt_vehicle_exit()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause") and not event.is_echo():
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if current_vehicle and vehicle_door_point:
		vehicle_door_point.global_position = current_vehicle.door_world_position()

func _toggle_pause() -> void:
	if vehicle_transition_active:
		_resolve_vehicle_transition_for_interruption()
	get_tree().paused = not get_tree().paused
	pause_label.visible = get_tree().paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if get_tree().paused else Input.MOUSE_MODE_CAPTURED

func _on_interaction_target_changed(target: Node3D) -> void:
	interaction_label.text = "CROSS / E  •  %s" % String(target.get_meta("interaction_text", "interact")) if is_instance_valid(target) else ""

func _on_interaction_requested(target: Node3D) -> void:
	if vehicle_transition_active:
		_show_status("Finish entering or exiting the vehicle before another action.")
		return
	match String(target.get_meta("interaction_kind", "")):
		"driver_select":
			_open_driver_menu()
		"vehicle_swap":
			_open_vehicle_menu()
		"vehicle_access":
			_handle_vehicle_access()
		"route_terminal":
			_open_route_menu()
		"package_station":
			_handle_package_station()
		"stop_arrival":
			_handle_stop_arrival(target)
		"stop_delivery":
			_handle_stop_delivery(target)
		"stop_proof":
			_handle_stop_proof(target)
		"contested_address":
			_show_status("The rival-courier encounter is disabled during the ordinary first-delivery test route.")
		_:
			_show_status("Context interaction accepted: %s" % String(target.get_meta("interaction_text", "interact")))

func _open_vehicle_menu() -> void:
	active_modal = "vehicle"
	modal_panel.visible = true
	player.set_controls_enabled(false)
	modal_label.text = "VEHICLE SWAP - currently: %s\n\n[1 / □] Parcel Finch - roomy blue delivery van\n[2 / △] Cargo Comet - nimble orange compact\n\n[Q / ○ / Back] Cancel and keep current vehicle" % gameplay_state.selected_vehicle

func _open_driver_menu() -> void:
	active_modal = "driver"
	modal_panel.visible = true
	player.set_controls_enabled(false)
	modal_label.text = "CHOOSE YOUR COURIER - currently: %s\n\n[1 / □] Owner Courier - fictionalized likeness profile\n[2 / △] Maya Brooks\n[3 / ✕] Jordan Reed\n[4 / R3] Alex Rivera\n\n[Q / ○] Keep current driver" % gameplay_state.selected_driver

func _open_route_menu() -> void:
	if gameplay_state.route_phase != "NO_ROUTE":
		_show_status("Active route %s | Phase: %s" % [gameplay_state.route_id, gameplay_state.route_phase])
		return
	active_modal = "route"
	modal_panel.visible = true
	player.set_controls_enabled(false)
	route_draft_order.assign(GameplayState.OPTIMIZED_STOP_ORDER)
	_render_route_planner()

func _render_route_planner() -> void:
	var offer: Dictionary = GameplayState.ROUTE_OFFER
	var metrics := gameplay_state.route_metrics(route_draft_order)
	var short_order: Array[String] = []
	for stop_id in route_draft_order:
		short_order.append(stop_id.trim_prefix("WB-"))
	var warning := " | BACKTRACKING WARNING" if bool(metrics.backtracking_warning) else " | OPTIMIZED"
	modal_label.text = "WAREHOUSE ROUTE PLANNER\n%s - %d stops / 5 packages\n%.1f miles | %d minutes | $%d gross%s\nORDER: %s\n\n[1 / □] Accept displayed order\n[2 / △] Reset optimized\n[3 / ✕] Move first stop to end (manual reorder)\n[Q / ○] Decline" % [offer.area, offer.stops, metrics.miles, metrics.estimated_minutes, offer.payout, warning, " > ".join(short_order)]

func _open_animal_menu() -> void:
	active_modal = "animal"
	modal_panel.visible = true
	player.set_controls_enabled(false)
	modal_label.text = "UNSAFE ANIMAL AT ACTIVE STOP\nRemain at the vehicle; never confront the dog.\n\n[1 / □] Wait for customer to secure it\n[2 / △] Contact customer\n[3 / ✕] Mark undeliverable and return package\n[Q / ○ / Back] Cancel"

func _open_encounter_menu() -> void:
	if gameplay_state.encounter_resolved:
		_show_status("Contested address already resolved: %s. No repeat payout." % gameplay_state.encounter_outcome)
		return
	active_modal = "encounter"
	modal_panel.visible = true
	player.set_controls_enabled(false)
	modal_label.text = "CONTESTED ADDRESS\nAnother fictional courier claims this delivery.\n\n[1 / □] De-escalate (+reputation, small delay)\n[2 / △] Leave (no fight, route delay)\n[3 / ✕] Non-lethal fight%s\n[4 / R3] Toggle combat accessibility: %s\n[Q / ○ / Back] Cancel" % ["" if gameplay_state.combat_enabled else " (DISABLED)", "ON" if gameplay_state.combat_enabled else "OFF"]

func _handle_modal_input() -> void:
	if active_modal == "fight" and Input.is_action_just_pressed("combat_retreat"):
		_retreat_fight()
		return
	if Input.is_action_just_pressed("menu_cancel"):
		_close_modal("Choice cancelled; no state changed.")
		return
	match active_modal:
		"route":
			if Input.is_action_just_pressed("choice_one"):
				_accept_planned_route(route_draft_order)
			elif Input.is_action_just_pressed("choice_two"):
				route_draft_order.assign(GameplayState.OPTIMIZED_STOP_ORDER)
				_render_route_planner()
			elif Input.is_action_just_pressed("choice_three"):
				var first_stop: String = route_draft_order.pop_front()
				route_draft_order.append(first_stop)
				_render_route_planner()
		"animal":
			if Input.is_action_just_pressed("choice_one"):
				_finish_animal_choice("wait")
			elif Input.is_action_just_pressed("choice_two"):
				_finish_animal_choice("contact_customer")
			elif Input.is_action_just_pressed("choice_three"):
				_finish_animal_choice("undeliverable")
		"driver":
			if Input.is_action_just_pressed("choice_one"):
				_choose_driver(0)
			elif Input.is_action_just_pressed("choice_two"):
				_choose_driver(1)
			elif Input.is_action_just_pressed("choice_three"):
				_choose_driver(2)
			elif Input.is_action_just_pressed("choice_four"):
				_choose_driver(3)
		"vehicle":
			if Input.is_action_just_pressed("choice_one"):
				_choose_vehicle(0)
			elif Input.is_action_just_pressed("choice_two"):
				_choose_vehicle(1)
			elif Input.is_action_just_pressed("choice_four"):
				_close_modal("Choice cancelled; no state changed.")
		"encounter":
			if Input.is_action_just_pressed("choice_one"):
				_finish_encounter("deescalated")
			elif Input.is_action_just_pressed("choice_two"):
				_finish_encounter("left")
			elif Input.is_action_just_pressed("choice_three"):
				if gameplay_state.begin_fight():
					active_modal = "fight"
					_update_fight_hud("The rival raises their guard. No weapons; fight ends at knockdown.")
				else:
					_show_status("Combat is disabled. Choose de-escalate or leave.")
			elif Input.is_action_just_pressed("choice_four"):
				gameplay_state.combat_enabled = not gameplay_state.combat_enabled
				_save_game()
				_open_encounter_menu()
		"fight":
			var action := ""
			if Input.is_action_just_pressed("combat_light"):
				action = "light"
			elif Input.is_action_just_pressed("combat_heavy"):
				action = "heavy"
			elif Input.is_action_just_pressed("combat_block"):
				action = "block"
			elif Input.is_action_just_pressed("combat_dodge"):
				action = "dodge"
			if action != "":
				var result := gameplay_state.combat_turn(action)
				if gameplay_state.encounter_resolved:
					_save_game()
					_close_modal("%s Consequences: %d credits, reputation %d, +%d route minutes." % [result.message, gameplay_state.credits, gameplay_state.reputation, gameplay_state.route_minutes])
				else:
					_update_fight_hud(result.message)

func _accept_planned_route(chosen_order: Array) -> void:
	var result := gameplay_state.accept_route()
	if result.accepted and chosen_order != GameplayState.OPTIMIZED_STOP_ORDER:
		result = gameplay_state.reorder_stops(chosen_order)
	_save_game()
	_update_route_hud()
	_close_modal("%s Go to the package station and scan all five packages." % result.message)

func _finish_animal_choice(action: String) -> void:
	var result := gameplay_state.resolve_stop_complication(action)
	_save_game()
	_update_route_hud()
	if action == "undeliverable" and result.accepted:
		_close_modal(result.message + " Drive back to the warehouse package station.")
	else:
		_close_modal(result.message + " Return to the vehicle door for the correct package.")

func _choose_vehicle(index: int) -> void:
	if not gameplay_state.select_vehicle(index):
		return
	_select_runtime_vehicle(index)
	_save_game()
	_close_modal("Vehicle selected: %s. Accept the route at the warehouse terminal, then scan and load its package." % gameplay_state.selected_vehicle)

func _choose_driver(index: int) -> void:
	if not gameplay_state.select_driver(index):
		return
	player.set_driver_variant(index)
	_apply_driver_variant_to_vehicles(index)
	_save_game()
	_close_modal("Driver selected: %s. Choose Parcel Finch or Cargo Comet at the vehicle selector." % gameplay_state.selected_driver)

func _apply_saved_driver() -> void:
	var index := GameplayState.DRIVERS.find(gameplay_state.selected_driver)
	player.set_driver_variant(maxi(index, 0))
	_apply_driver_variant_to_vehicles(maxi(index, 0))

func _apply_driver_variant_to_vehicles(index: int) -> void:
	for vehicle in vehicles:
		vehicle.set_driver_variant(index)

func _select_runtime_vehicle(index: int) -> void:
	if vehicles.is_empty():
		return
	var safe_index := clampi(index, 0, vehicles.size() - 1)
	current_vehicle = vehicles[safe_index]
	for vehicle in vehicles:
		vehicle.set_meta("selected", vehicle == current_vehicle)
	if vehicle_door_point:
		vehicle_door_point.global_position = current_vehicle.door_world_position()
		vehicle_door_point.set_meta("interaction_text", "open the %s driver door" % current_vehicle.display_name)
		vehicle_door_point.set_meta("interaction_vehicle", current_vehicle)
	if gameplay_state.vehicle_position.length() > 0.5:
		current_vehicle.global_position = gameplay_state.vehicle_position
		current_vehicle.rotation.y = gameplay_state.vehicle_rotation_y

func _handle_package_station() -> void:
	var result: Dictionary
	if gameplay_state.route_phase == "RETURN_PENDING":
		result = gameplay_state.return_package()
	elif gameplay_state.route_phase in ["ROUTE_ACCEPTED", "SCANNING"] and gameplay_state.next_unscanned_tracking() != "":
		result = gameplay_state.scan_package(gameplay_state.next_unscanned_tracking())
		if bool(result.get("accepted", false)):
			player.play_interaction_presentation("scan")
	elif gameplay_state.route_phase == "SCANNING":
		result = gameplay_state.load_package()
	else:
		_show_status("Package station unavailable in phase: %s" % gameplay_state.route_phase)
		return
	_save_game()
	_update_route_hud()
	var next_action := " Enter the selected vehicle and depart."
	if gameplay_state.route_phase == "SCANNING":
		next_action = " Press CROSS / E again to scan the next package." if gameplay_state.next_unscanned_tracking() != "" else " Press CROSS / E again to load all five packages."
	_show_status(result.message + next_action)

func _target_matches_active_stop(target: Marker3D) -> bool:
	var target_stop := String(target.get_meta("stop_id", ""))
	if target_stop != gameplay_state.current_stop_id:
		_show_status("Wrong stop or door. GPS target is %s." % gameplay_state.gps_target_address)
		return false
	return true

func _handle_stop_arrival(target: Marker3D) -> void:
	if not _target_matches_active_stop(target):
		return
	if gameplay_state.route_phase != "DRIVING":
		_show_status("Arrival cannot advance during phase %s." % gameplay_state.route_phase)
		return
	if driving or not current_vehicle.parked or current_vehicle.global_position.distance_to(target.global_position) > 8.5:
		_show_status("Park the selected vehicle at the active GPS curb marker and exit first.")
		return
	var result := gameplay_state.arrive_at_stop(String(target.get_meta("stop_id")))
	_save_game()
	_update_route_hud()
	var stop: Dictionary = gameplay_state.stops[gameplay_state.current_stop_id]
	if String(stop.archetype) == "UNSAFE_ANIMAL":
		_show_status(result.message + " Stay at the vehicle and choose a safe animal response before retrieving it.")
	else:
		_show_status(result.message + " Open the vehicle door and retrieve the correct package.")

func _handle_stop_delivery(target: Marker3D) -> void:
	if not _target_matches_active_stop(target):
		return
	if gameplay_state.route_phase == "AT_STOP":
		var stop: Dictionary = gameplay_state.stops[gameplay_state.current_stop_id]
		if String(stop.archetype) == "UNSAFE_ANIMAL" and String(stop.animal_hazard) == "ACTIVE":
			_open_animal_menu()
		else:
			_show_status("Retrieve the assigned package from the selected vehicle first.")
		return
	if gameplay_state.route_phase != "PACKAGE_RETRIEVED":
		_show_status("Placement unavailable during phase %s." % gameplay_state.route_phase)
		return
	var active_stop: Dictionary = gameplay_state.stops[gameplay_state.current_stop_id]
	var result := gameplay_state.place_package(String(active_stop.placement_rule))
	if result.accepted:
		player.play_interaction_presentation("place")
		_set_carried_package_visible(false)
		placed_package.visible = true
		placed_package.global_position = target.global_position + Vector3(0.0, 0.28, 0.0)
	_save_game()
	_update_route_hud()
	_show_status(result.message + " Use the nearby proof marker for %s." % String(active_stop.confirmation).replace("_", " ").to_lower())

func _handle_stop_proof(target: Marker3D) -> void:
	if not _target_matches_active_stop(target):
		return
	if gameplay_state.route_phase != "PLACED":
		_show_status("Place the correct package at this stop before proof/confirmation.")
		return
	var active_stop: Dictionary = gameplay_state.stops[gameplay_state.current_stop_id]
	var result := gameplay_state.confirm_delivery(String(active_stop.confirmation))
	placed_package.visible = false
	var saved := _save_game()
	_update_route_hud()
	if gameplay_state.route_phase == "ROUTE_COMPLETE":
		var summary := gameplay_state.earnings_summary()
		var persistence_message := "Progress saved." if saved else "Progress NOT saved; keep the game open and retry."
		_show_status("%s Route complete | Gross $%d - Fuel $%d - Maintenance $%d - Penalties $%d = Net $%d. %s" % [result.message, summary.gross, summary.fuel, summary.maintenance, summary.penalties, summary.net, persistence_message])
	else:
		_show_status("%s Next GPS target: %s" % [result.message, gameplay_state.gps_target_address])

func _handle_vehicle_access() -> void:
	if current_vehicle == null:
		return
	if door_waiting_for_close:
		if gameplay_state.route_phase == "AT_STOP":
			if gameplay_state.stops.has(gameplay_state.current_stop_id):
				var active_stop: Dictionary = gameplay_state.stops[gameplay_state.current_stop_id]
				if String(active_stop.archetype) == "UNSAFE_ANIMAL" and String(active_stop.animal_hazard) == "ACTIVE":
					_open_animal_menu()
					return
			var retrieval := gameplay_state.retrieve_package()
			if retrieval.accepted:
				_set_carried_package_visible(true)
				_save_game()
				vehicle_door_point.set_meta("interaction_text", "close the %s driver door" % current_vehicle.display_name)
				var package: Dictionary = gameplay_state.packages[String(gameplay_state.stops[gameplay_state.current_stop_id].tracking_id)]
				var handling := " Use the dolly/heavy-carry route." if bool(package.heavy_handling_required) else ""
				_show_status(retrieval.message + handling + " Press E / X again to close the door, then follow the delivery marker.")
				return
		current_vehicle.set_door_open(false)
		door_waiting_for_close = false
		vehicle_door_point.set_meta("interaction_text", "open the %s driver door" % current_vehicle.display_name)
		_save_game()
		_show_status("Driver door closed and latched.")
		return
	if not current_vehicle.door_open:
		current_vehicle.set_door_open(true)
		vehicle_door_point.set_meta("interaction_text", "enter %s" % current_vehicle.display_name)
		_show_status("Driver door opened. Press E / X again to enter.")
		return
	_enter_vehicle()

func _enter_vehicle() -> void:
	if vehicle_transition_active or current_vehicle == null or not current_vehicle.door_open:
		return
	door_waiting_for_close = false
	vehicle_transition_active = true
	vehicle_transition_kind = "vehicle_enter"
	vehicle_transition_cancel_target = ""
	current_vehicle.set_driving_active(false)
	vehicle_door_point.remove_from_group("interactable")
	interaction_label.text = ""
	_show_status("Entering %s... vehicle controls are locked until seated." % current_vehicle.display_name)
	if not player.begin_vehicle_transition("vehicle_enter", current_vehicle, force_vehicle_transition_visuals):
		vehicle_transition_active = false
		vehicle_transition_kind = ""
		vehicle_door_point.add_to_group("interactable")
		_show_status("Could not start vehicle entry.")

func _attempt_vehicle_exit() -> void:
	if vehicle_transition_active or current_vehicle == null:
		return
	if not current_vehicle.parked or absf(current_vehicle.speed) > 0.1:
		_show_status("Stop and engage Park before exiting.")
		return
	if not current_vehicle.has_exit_clearance([player.get_rid()]):
		_show_status("The driver-side exit is blocked. Move the vehicle to a clear space before exiting.")
		return
	vehicle_transition_active = true
	vehicle_transition_kind = "vehicle_exit"
	vehicle_transition_cancel_target = ""
	current_vehicle.set_driving_active(false)
	current_vehicle.set_door_open(true)
	vehicle_door_point.remove_from_group("interactable")
	interaction_label.text = ""
	_show_status("Exiting %s... controls are locked until clear of the door." % current_vehicle.display_name)
	if not player.begin_vehicle_transition("vehicle_exit", current_vehicle, force_vehicle_transition_visuals):
		vehicle_transition_active = false
		vehicle_transition_kind = ""
		_settle_inside_vehicle()

func _on_player_presentation_finished(kind: String) -> void:
	if not vehicle_transition_active or kind != vehicle_transition_kind:
		return
	var cancel_target := vehicle_transition_cancel_target
	vehicle_transition_active = false
	vehicle_transition_kind = ""
	vehicle_transition_cancel_target = ""
	if cancel_target == "outside":
		_settle_outside_vehicle(false)
	elif cancel_target == "inside":
		_settle_inside_vehicle()
	elif kind == "vehicle_enter":
		_settle_inside_vehicle()
		if gameplay_state.route_phase == "LOADED":
			var departure := gameplay_state.depart_route()
			_show_status(departure.message)
			_save_game()
		elif gameplay_state.route_phase != "DRIVING":
			_save_game()
			_show_status("Driving %s | P / □: Park/Drive | W/S or R2/L2: throttle/reverse | A/D: steer | Space / ○: brake | E / X: exit when parked" % current_vehicle.display_name)
		else:
			_save_game()
	else:
		_settle_outside_vehicle(true)

func _settle_inside_vehicle() -> void:
	driving = true
	door_waiting_for_close = false
	current_vehicle.set_door_open(false)
	var driver_index := maxi(GameplayState.DRIVERS.find(gameplay_state.selected_driver), 0)
	current_vehicle.set_driver_variant(driver_index)
	player.set_player_active(false)
	current_vehicle.set_driving_active(true)
	vehicle_door_point.remove_from_group("interactable")
	interaction_label.text = ""

func _settle_outside_vehicle(completed_exit: bool) -> void:
	driving = false
	current_vehicle.set_driving_active(false)
	current_vehicle.set_door_open(true)
	player.global_position = current_vehicle.exit_position()
	player.set_player_active(true)
	door_waiting_for_close = completed_exit
	gameplay_state.vehicle_position = current_vehicle.global_position
	gameplay_state.vehicle_rotation_y = current_vehicle.rotation.y
	vehicle_door_point.global_position = current_vehicle.door_world_position()
	vehicle_door_point.add_to_group("interactable")
	vehicle_door_point.set_meta("interaction_text", ("close the %s driver door" if completed_exit else "enter %s") % current_vehicle.display_name)
	if completed_exit:
		_save_game()
		_show_status("Exited %s. Press E / X at the door to close it." % current_vehicle.display_name)
	else:
		_show_status("Vehicle entry cancelled safely. The door remains open.")

func _resolve_vehicle_transition_for_interruption() -> void:
	if not vehicle_transition_active:
		return
	vehicle_transition_cancel_target = "outside" if vehicle_transition_kind == "vehicle_enter" else "inside"
	player.cancel_authored_presentation()

func _set_carried_package_visible(visible_value: bool) -> void:
	if carried_package:
		carried_package.visible = visible_value
	if visible_value and player:
		player.play_interaction_presentation("carry")

func _finish_encounter(outcome: String) -> void:
	var result := gameplay_state.resolve_encounter(outcome)
	_save_game()
	_close_modal("%s Reward: %d credits. Reputation: %d. Route delay: %d min." % [result.message, result.reward, gameplay_state.reputation, gameplay_state.route_minutes])

func _retreat_fight() -> void:
	var result := gameplay_state.retreat_from_fight()
	_save_game()
	_close_modal("%s Reputation: %d. Route delay: %d min." % [result.message, gameplay_state.reputation, gameplay_state.route_minutes])

func _update_fight_hud(message: String) -> void:
	modal_label.text = "NON-LETHAL RIVAL ENCOUNTER\nYou: %d health | Rival: %d health | Stamina: %d\n\n%s\n\n[J / X] Light (15)   [K / Y] Heavy (30)\n[L / LB] Block   [Space / B] Dodge (20)\n[Q / RB] Retreat (leave consequence)" % [gameplay_state.player_health, gameplay_state.rival_health, gameplay_state.stamina, message]

func _close_modal(message: String) -> void:
	active_modal = ""
	modal_panel.visible = false
	player.suppress_modal_camera_leak()
	player.set_controls_enabled(true)
	_show_status(message)

func _show_status(message: String) -> void:
	if status_label:
		status_label.text = message if save_warning == "" else "%s\nSAVE WARNING: %s" % [message, save_warning]
	_update_route_hud()

func _save_game() -> bool:
	if vehicle_transition_active:
		_show_status("Saving is locked while entering or exiting the vehicle.")
		return false
	_sync_runtime_state_for_save()
	var saved := gameplay_state.save_game(runtime_save_path)
	if saved:
		save_warning = ""
	else:
		save_warning = "Progress could not be written. Do not close the game until saving succeeds."
		_show_status("Progress was not saved.")
	return saved

func _sync_runtime_state_for_save() -> void:
	if current_vehicle == null or player == null:
		return
	gameplay_state.vehicle_position = current_vehicle.global_position
	gameplay_state.vehicle_rotation_y = current_vehicle.rotation.y
	gameplay_state.vehicle_parked = current_vehicle.parked
	gameplay_state.vehicle_door_open = current_vehicle.door_open
	gameplay_state.door_waiting_for_close = door_waiting_for_close
	if driving:
		gameplay_state.runtime_location = "IN_VEHICLE"
		# Keep a safe outside fallback beside the same saved vehicle while normal
		# reload resumes in the canonical seated state.
		gameplay_state.player_position = current_vehicle.exit_position()
		gameplay_state.vehicle_door_open = false
		gameplay_state.door_waiting_for_close = false
	else:
		gameplay_state.runtime_location = "ON_FOOT"
		gameplay_state.player_position = player.global_position

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and vehicle_transition_active:
		_resolve_vehicle_transition_for_interruption()
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST] and not vehicle_transition_active:
		_save_game()
