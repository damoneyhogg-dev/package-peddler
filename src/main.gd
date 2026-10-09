extends Node3D

const PlayerController = preload("res://src/player_controller.gd")

var status_label: Label

func _ready() -> void:
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
	_add_static_box("Home", Vector3(-11.0, 2.0, -8.0), Vector3(8.0, 4.0, 7.0), Color("c8b49a"))
	_add_static_box("Warehouse", Vector3(13.0, 3.0, -15.0), Vector3(18.0, 6.0, 10.0), Color("87939c"))
	_add_static_box("LoadingDock", Vector3(13.0, 0.45, -8.8), Vector3(12.0, 0.9, 2.0), Color("4d555b"))
	_add_static_box("ParkedVehicle", Vector3(-5.0, 0.65, -2.0), Vector3(2.1, 1.3, 4.5), Color("254e70"))

	for x in range(-2, 3):
		_add_static_box("TrafficBarrier_%s" % x, Vector3(float(x) * 3.0, 0.5, 8.0), Vector3(1.4, 1.0, 1.4), Color("d78935"))

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
	var player := PlayerController.new()
	player.name = "CourierPlayer"
	player.position = Vector3(-11.0, 1.0, -1.0)
	add_child(player)
	player.interaction_requested.connect(_on_interaction_requested)

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
	status_label.text = "WASD / left stick: move   Shift: sprint   Mouse / right stick: camera\nV / Y: camera view   E / A: interact   Esc: release mouse"
	status_label.add_theme_font_size_override("font_size", 15)
	layer.add_child(status_label)

func _on_interaction_requested() -> void:
	status_label.text = "Interaction input received. Warehouse, vehicle and package actions are next."
	get_tree().create_timer(2.2).timeout.connect(func() -> void:
		status_label.text = "WASD / left stick: move   Shift: sprint   Mouse / right stick: camera\nV / Y: camera view   E / A: interact   Esc: release mouse"
	)

