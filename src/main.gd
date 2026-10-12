extends Node3D

const PlayerController = preload("res://src/player_controller.gd")
const GameplayState = preload("res://src/gameplay_state.gd")
const VehicleController = preload("res://src/vehicle_controller.gd")

var status_label: Label
var interaction_label: Label
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
var carried_package: MeshInstance3D
var delivery_point: Marker3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	gameplay_state.load_game()
	_build_lighting()
	_build_neighborhood_vertical_slice()
	_build_player()
	_build_hud()
	_apply_saved_driver()
	_select_runtime_vehicle(GameplayState.VEHICLES.find(gameplay_state.selected_vehicle))
	_show_status("Loaded driver: %s | Vehicle: %s | Credits: %d" % [gameplay_state.selected_driver, gameplay_state.selected_vehicle, gameplay_state.credits])
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
	_add_interaction_point("DeliveryStop", Vector3(-12.0, 1.0, -6.1), "check the delivery address")
	delivery_point = get_node("DeliveryStop") as Marker3D
	delivery_point.set_meta("interaction_kind", "delivery_stop")
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
	carried_package = _box_mesh(Vector3(0.62, 0.48, 0.42), Color("9b6b3f"))
	carried_package.name = "CarriedPackage"
	carried_package.position = Vector3(0.0, 1.05, -0.48)
	carried_package.visible = false
	player.add_child(carried_package)

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

func _unhandled_input(event: InputEvent) -> void:
	if active_modal != "" and event.is_pressed() and not event.is_echo():
		_handle_modal_input()
		get_viewport().set_input_as_handled()
		return
	if driving and event.is_pressed() and not event.is_echo():
		if event.is_action_pressed("vehicle_park"):
			current_vehicle.toggle_park()
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
	get_tree().paused = not get_tree().paused
	pause_label.visible = get_tree().paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if get_tree().paused else Input.MOUSE_MODE_CAPTURED

func _on_interaction_target_changed(target: Node3D) -> void:
	interaction_label.text = "Press E / A to %s" % String(target.get_meta("interaction_text", "interact")) if is_instance_valid(target) else ""

func _on_interaction_requested(target: Node3D) -> void:
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
		"delivery_stop":
			_handle_delivery_stop()
		"contested_address":
			_show_status("The rival-courier encounter is disabled during the ordinary first-delivery test route.")
		_:
			_show_status("Context interaction accepted: %s" % String(target.get_meta("interaction_text", "interact")))

func _open_vehicle_menu() -> void:
	active_modal = "vehicle"
	modal_panel.visible = true
	player.set_controls_enabled(false)
	modal_label.text = "VEHICLE SWAP - currently: %s\n\n[1 / X] Parcel Finch - roomy blue delivery van\n[2 / Y] Cargo Comet - nimble orange compact\n\n[Q / B] Cancel and keep current vehicle" % gameplay_state.selected_vehicle

func _open_driver_menu() -> void:
	active_modal = "driver"
	modal_panel.visible = true
	player.set_controls_enabled(false)
	modal_label.text = "CHOOSE YOUR COURIER - currently: %s\n\n[1 / X] Owner Courier - fictionalized likeness profile\n[2 / Y] Maya Brooks\n[3 / A] Jordan Reed\n[4 / B] Alex Rivera\n\n[Q] Keep current driver" % gameplay_state.selected_driver

func _open_route_menu() -> void:
	if gameplay_state.route_phase != "NO_ROUTE":
		_show_status("Active route %s | Phase: %s" % [gameplay_state.route_id, gameplay_state.route_phase])
		return
	active_modal = "route"
	modal_panel.visible = true
	player.set_controls_enabled(false)
	var offer: Dictionary = GameplayState.ROUTE_OFFER
	modal_label.text = "WAREHOUSE ROUTE OFFER\n%s - %d stop / 1 package\n%.1f miles | %d minutes | $%d payout\n\n[1 / X] Accept route\n[Q] Decline with no changes" % [offer.area, offer.stops, offer.miles, offer.estimated_minutes, offer.payout]

func _open_encounter_menu() -> void:
	if gameplay_state.encounter_resolved:
		_show_status("Contested address already resolved: %s. No repeat payout." % gameplay_state.encounter_outcome)
		return
	active_modal = "encounter"
	modal_panel.visible = true
	player.set_controls_enabled(false)
	modal_label.text = "CONTESTED ADDRESS\nAnother fictional courier claims this delivery.\n\n[1 / X] De-escalate (+reputation, small delay)\n[2 / Y] Leave (no fight, route delay)\n[3 / A] Non-lethal fight%s\n[4 / B] Toggle combat accessibility: %s\n[Q] Cancel" % ["" if gameplay_state.combat_enabled else " (DISABLED)", "ON" if gameplay_state.combat_enabled else "OFF"]

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
				var result := gameplay_state.accept_route()
				gameplay_state.save_game()
				_close_modal("%s Go to the package station." % result.message)
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
				gameplay_state.save_game()
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
					gameplay_state.save_game()
					_close_modal("%s Consequences: %d credits, reputation %d, +%d route minutes." % [result.message, gameplay_state.credits, gameplay_state.reputation, gameplay_state.route_minutes])
				else:
					_update_fight_hud(result.message)

func _choose_vehicle(index: int) -> void:
	if not gameplay_state.select_vehicle(index):
		return
	_select_runtime_vehicle(index)
	gameplay_state.save_game()
	_close_modal("Vehicle selected: %s. Accept the route at the warehouse terminal, then scan and load its package." % gameplay_state.selected_vehicle)

func _choose_driver(index: int) -> void:
	if not gameplay_state.select_driver(index):
		return
	player.set_driver_variant(index)
	gameplay_state.save_game()
	_close_modal("Driver selected: %s. Choose Parcel Finch or Cargo Comet at the vehicle selector." % gameplay_state.selected_driver)

func _apply_saved_driver() -> void:
	var index := GameplayState.DRIVERS.find(gameplay_state.selected_driver)
	player.set_driver_variant(maxi(index, 0))

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
	if gameplay_state.vehicle_position.length() > 0.5:
		current_vehicle.global_position = gameplay_state.vehicle_position
		current_vehicle.rotation.y = gameplay_state.vehicle_rotation_y

func _handle_package_station() -> void:
	var result: Dictionary
	if gameplay_state.route_phase == "ROUTE_ACCEPTED":
		result = gameplay_state.scan_package(GameplayState.PACKAGE_TRACKING)
	elif gameplay_state.route_phase == "SCANNING":
		result = gameplay_state.load_package()
	else:
		_show_status("Package station unavailable in phase: %s" % gameplay_state.route_phase)
		return
	gameplay_state.save_game()
	_show_status(result.message + (" Press E / A again to load it." if gameplay_state.route_phase == "SCANNING" else " Enter the selected vehicle and depart."))

func _handle_delivery_stop() -> void:
	var result: Dictionary
	match gameplay_state.route_phase:
		"DRIVING":
			if driving or not current_vehicle.parked or current_vehicle.global_position.distance_to(delivery_point.global_position) > 7.0:
				_show_status("Park the selected vehicle near the delivery marker and exit before checking the address.")
				return
			result = gameplay_state.arrive_at_stop()
		"PACKAGE_RETRIEVED":
			result = gameplay_state.place_package()
			_set_carried_package_visible(false)
		"PLACED":
			result = gameplay_state.confirm_delivery()
		_:
			_show_status("Delivery action unavailable. Current phase: %s" % gameplay_state.route_phase)
			return
	gameplay_state.save_game()
	if gameplay_state.route_phase == "ROUTE_COMPLETE":
		_show_status("%s Payout: $%d | Total credits: $%d. Progress saved." % [result.message, result.reward, gameplay_state.credits])
	else:
		_show_status(result.message)

func _handle_vehicle_access() -> void:
	if current_vehicle == null:
		return
	if door_waiting_for_close:
		if gameplay_state.route_phase == "AT_STOP":
			var retrieval := gameplay_state.retrieve_package()
			if retrieval.accepted:
				_set_carried_package_visible(true)
				gameplay_state.save_game()
				vehicle_door_point.set_meta("interaction_text", "close the %s driver door" % current_vehicle.display_name)
				_show_status(retrieval.message + " Press E / A again to close the door, then take it to the porch.")
				return
		current_vehicle.set_door_open(false)
		door_waiting_for_close = false
		vehicle_door_point.set_meta("interaction_text", "open the %s driver door" % current_vehicle.display_name)
		_show_status("Driver door closed and latched.")
		return
	if not current_vehicle.door_open:
		current_vehicle.set_door_open(true)
		vehicle_door_point.set_meta("interaction_text", "enter %s" % current_vehicle.display_name)
		_show_status("Driver door opened. Press E / A again to enter.")
		return
	_enter_vehicle()

func _enter_vehicle() -> void:
	if current_vehicle == null or not current_vehicle.door_open:
		return
	driving = true
	door_waiting_for_close = false
	player.set_player_active(false)
	current_vehicle.set_driving_active(true)
	current_vehicle.set_door_open(false)
	if gameplay_state.route_phase == "LOADED":
		var departure := gameplay_state.depart_route()
		_show_status(departure.message)
		gameplay_state.save_game()
	vehicle_door_point.remove_from_group("interactable")
	interaction_label.text = ""
	if gameplay_state.route_phase != "DRIVING":
		_show_status("Driving %s | P / X: Park/Drive | W/S: throttle/brake/reverse | A/D: steer | Space: brake | E/A: exit when parked" % current_vehicle.display_name)

func _attempt_vehicle_exit() -> void:
	if current_vehicle == null:
		return
	if not current_vehicle.parked or absf(current_vehicle.speed) > 0.1:
		_show_status("Stop and engage Park before exiting.")
		return
	driving = false
	current_vehicle.set_driving_active(false)
	current_vehicle.set_door_open(true)
	door_waiting_for_close = true
	player.global_position = current_vehicle.exit_position()
	player.set_player_active(true)
	gameplay_state.vehicle_position = current_vehicle.global_position
	gameplay_state.vehicle_rotation_y = current_vehicle.rotation.y
	gameplay_state.save_game()
	vehicle_door_point.global_position = current_vehicle.door_world_position()
	vehicle_door_point.add_to_group("interactable")
	vehicle_door_point.set_meta("interaction_text", "close the %s driver door" % current_vehicle.display_name)
	_show_status("Exited %s. Press E / A at the door to close it." % current_vehicle.display_name)

func _set_carried_package_visible(visible_value: bool) -> void:
	if carried_package:
		carried_package.visible = visible_value

func _finish_encounter(outcome: String) -> void:
	var result := gameplay_state.resolve_encounter(outcome)
	gameplay_state.save_game()
	_close_modal("%s Reward: %d credits. Reputation: %d. Route delay: %d min." % [result.message, result.reward, gameplay_state.reputation, gameplay_state.route_minutes])

func _retreat_fight() -> void:
	var result := gameplay_state.retreat_from_fight()
	gameplay_state.save_game()
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
		status_label.text = message
