extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	for frame in range(8):
		await process_frame
	game._close_modal("Seated-driving GPU capture")
	var vehicle: PackagePeddlerVehicle = game.current_vehicle
	game.player.set_player_active(false)
	vehicle.set_driving_active(true)
	vehicle.toggle_park()
	vehicle._update_driving_presentation(vehicle.driving_presentation_duration)
	vehicle._apply_seated_driver_pose(0.0, -0.35)
	for shell_name in ["Body", "Cabin", "Windshield", "DriverDoorPivot/DriverDoor"]:
		var shell := vehicle.get_node_or_null(shell_name) as MeshInstance3D
		if shell:
			shell.visible = false

	var inspection_camera := Camera3D.new()
	inspection_camera.name = "PassengerInspectionCamera"
	vehicle.add_child(inspection_camera)
	var camera_position := vehicle.to_global(Vector3(1.25, 1.72, -0.22))
	var camera_target := vehicle.to_global(Vector3(-0.48, 1.18, -0.72))
	inspection_camera.look_at_from_position(camera_position, camera_target, Vector3.UP)
	inspection_camera.fov = 63.0
	inspection_camera.current = true
	await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var error := image.save_png("user://seated_driving_preview.png")
	if error != OK:
		push_error("Could not save seated-driving preview: %s" % error)
		quit(1)
	print("SEATED_DRIVING_CAPTURE_PASS size=%s wheel_hands=true" % root.get_texture().get_size())
	quit(0)
