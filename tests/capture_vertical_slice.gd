extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	for frame in range(8):
		await process_frame
	game._close_modal("GPU capture")
	game.player.set_physics_process(false)
	for animation_name in ["Idle", "Walk", "Run"]:
		game.player.animation_player.play(animation_name)
		game.player.animation_player.seek(0.32, true)
		await process_frame
		RenderingServer.force_draw(false)
		var image := root.get_texture().get_image()
		var output := "res://tests/vertical_slice_%s.png" % animation_name.to_lower()
		var error := image.save_png(output)
		if error != OK:
			push_error("Could not save vertical-slice preview: %s" % error)
			quit(1)
	print("VERTICAL_SLICE_CAPTURE_PASS poses=3 size=%s" % root.get_texture().get_size())
	quit(0)
