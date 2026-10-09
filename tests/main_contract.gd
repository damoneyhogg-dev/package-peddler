extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame

	_expect(game.pause_label is Label, "Pause notice was not created")
	_expect(not game.pause_label.visible, "Pause notice starts visible")
	game._toggle_pause()
	_expect(paused, "Pause action did not pause the scene tree")
	_expect(game.pause_label.visible, "Pause action did not show the pause notice")
	game._toggle_pause()
	_expect(not paused, "Second pause action did not resume the scene tree")
	_expect(not game.pause_label.visible, "Resume did not hide the pause notice")

	var vehicle_point := game.get_node_or_null("VehicleDoor")
	var warehouse_point := game.get_node_or_null("WarehouseEntrance")
	_expect(vehicle_point is Marker3D and vehicle_point.is_in_group("interactable"), "Vehicle interaction anchor is missing")
	_expect(warehouse_point is Marker3D and warehouse_point.is_in_group("interactable"), "Warehouse interaction anchor is missing")

	if failures.is_empty():
		print("MAIN_CONTRACT_PASS pause=true contextual_anchors=2")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("MAIN_CONTRACT_FAIL count=%d" % failures.size())
		quit(1)
