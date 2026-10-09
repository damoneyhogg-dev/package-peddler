extends SceneTree

const PlayerController = preload("res://src/player_controller.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	var required_actions := [
		"move_left", "move_right", "move_forward", "move_back",
		"look_left", "look_right", "look_up", "look_down",
		"sprint", "interact", "camera_toggle", "pause"
	]
	for action in required_actions:
		_expect(InputMap.has_action(action), "Missing input action: %s" % action)

	var player := PlayerController.new()
	root.add_child(player)
	await process_frame

	_expect(player.get_node_or_null("PlayerCollision") is CollisionShape3D, "Player collider was not created")
	_expect(player.get_node_or_null("CameraPivot/CameraCollisionArm") is SpringArm3D, "SpringArm3D camera collision was not created")
	_expect(player.get_node_or_null("CameraPivot/CameraCollisionArm/GameplayCamera") is Camera3D, "Gameplay camera was not created")
	_expect(player.camera.current, "Gameplay camera is not current")
	_expect(is_equal_approx(player.spring_arm.spring_length, 4.8), "Third-person camera distance is incorrect")

	Input.action_press("move_forward")
	for frame in range(12):
		player._physics_process(1.0 / 60.0)
	Input.action_release("move_forward")
	var planar_speed := Vector2(player.velocity.x, player.velocity.z).length()
	_expect(planar_speed > 0.5, "Forward input did not accelerate the player")
	_expect(planar_speed <= player.walk_speed + 0.05, "Walk acceleration exceeded configured walk speed")

	if failures.is_empty():
		print("CONTROLLER_CONTRACT_PASS actions=%d planar_speed=%.3f" % [required_actions.size(), planar_speed])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("CONTROLLER_CONTRACT_FAIL count=%d" % failures.size())
		quit(1)
