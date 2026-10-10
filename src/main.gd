extends Node3D

const PlayerController = preload("res://src/player_controller.gd")

var status_label: Label
var interaction_label: Label
var pause_label: Label
var player: PackagePeddlerPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_lighting()
	_build_graybox_neighborhood()
	_build_player()
	_build_hud()
	print("PACKAGE_PEDDLER_READY controller_milestone=1")

func _build_lighting() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("8bb7d5")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c6d8e4")
	env.ambient_light_energy = 0.75
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

func _build_graybox_neighborhood() -> void:
	_add_static_box("Ground", Vector3(0.0, -0.25, 0.0), Vector3(70.0, 0.5, 70.0), Color("65735a"))
	_add_world_boundaries()
	_add_static_box("Home", Vector3(-11.0, 2.0, -8.0), Vector3(8.0, 4.0, 7.0), Color("c8b49a"))
	_add_static_box("Warehouse", Vector3(13.0, 3.0, -15.0), Vector3(18.0, 6.0, 10.0), Color("87939c"))
	_add_static_box("LoadingDock", Vector3(13.0, 0.45, -8.8), Vector3(12.0, 0.9, 2.0), Color("4d555b"))
	_add_static_box("ParkedVehicle", Vector3(-5.0, 0.65, -2.0), Vector3(2.1, 1.3, 4.5), Color("254e70"))
	_add_interaction_point("VehicleDoor", Vector3(-6.4, 1.0, -2.0), "enter the parked vehicle")
	_add_interaction_point("WarehouseEntrance", Vector3(13.0, 1.0, -8.0), "enter the warehouse")

	for x in range(-2, 3):
		_add_static_box("TrafficBarrier_%s" % x, Vector3(float(x) * 3.0, 0.5, 8.0), Vector3(1.4, 1.0, 1.4), Color("d78935"))

func _add_world_boundaries() -> void:
	var boundary_color := Color("44503f")
	_add_static_box("WorldBoundaryNorth", Vector3(0.0, 0.75, -34.5), Vector3(70.0, 2.0, 1.0), boundary_color)
	_add_static_box("WorldBoundarySouth", Vector3(0.0, 0.75, 34.5), Vector3(70.0, 2.0, 1.0), boundary_color)
	_add_static_box("WorldBoundaryWest", Vector3(-34.5, 0.75, 0.0), Vector3(1.0, 2.0, 70.0), boundary_color)
	_add_static_box("WorldBoundaryEast", Vector3(34.5, 0.75, 0.0), Vector3(1.0, 2.0, 70.0), boundary_color)

func _add_interaction_point(point_name: String, position_value: Vector3, action_text: String) -> void:
	var point := Marker3D.new()
	point.name = point_name
	point.position = position_value
	point.set_meta("interaction_text", action_text)
	point.add_to_group("interactable")
	add_child(point)

func _add_static_box(label: String, position_value: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = position_value

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

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
	panel.size = Vector2(520.0, 104.0)
	panel.color = Color(0.03, 0.05, 0.07, 0.82)
	layer.add_child(panel)

	var title := Label.new()
	title.position = Vector2(34.0, 28.0)
	title.text = "PACKAGE PEDDLER — CONTROLLER MILESTONE"
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
	if is_instance_valid(target):
		interaction_label.text = "Press E / A to %s" % String(target.get_meta("interaction_text", "interact"))
	else:
		interaction_label.text = ""

func _on_interaction_requested(target: Node3D) -> void:
	status_label.text = "Context interaction accepted: %s" % String(target.get_meta("interaction_text", "interact"))
	get_tree().create_timer(2.2).timeout.connect(func() -> void:
		status_label.text = "WASD / left stick: move   Shift: sprint   Mouse / right stick: camera\nV / Y: camera view   E / A: interact   Esc / Menu: pause"
	)
