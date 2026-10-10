extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _run() -> void:
	var packed := load("res://assets/characters/courier.glb") as PackedScene
	_expect(packed != null, "Courier GLB did not import as a PackedScene")
	if packed:
		var character := packed.instantiate()
		root.add_child(character)
		var animation_player := _find_animation_player(character)
		_expect(animation_player != null, "Courier asset has no AnimationPlayer")
		if animation_player:
			var clips := animation_player.get_animation_list()
			for required_clip in [&"Idle", &"Walk", &"Run"]:
				_expect(clips.has(required_clip), "Courier asset is missing animation: %s" % required_clip)
			print("COURIER_ASSET animations=%s" % [clips])

	if failures.is_empty():
		print("CHARACTER_ASSET_CONTRACT_PASS rigged=true clips=3")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("CHARACTER_ASSET_CONTRACT_FAIL count=%d" % failures.size())
		quit(1)
