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

	var interaction_point := Marker3D.new()
	interaction_point.name = "TestInteractionPoint"
	interaction_point.position = Vector3(0.0, 0.0, 2.0)
	interaction_point.add_to_group("interactable")
	root.add_child(interaction_point)
	player._update_interaction_target()
	_expect(player.current_interaction_target == interaction_point, "Nearby contextual interaction target was not selected")
	player.position = Vector3(10.0, 0.0, 0.0)
	player._update_interaction_target()
	_expect(player.current_interaction_target == null, "Out-of-range interaction target remained selected")
	player.position = Vector3.ZERO

	Input.action_press("move_forward", 0.5)
	for frame in range(12):
		player._physics_process(1.0 / 60.0)
	Input.action_release("move_forward")
	var partial_speed := Vector2(player.velocity.x, player.velocity.z).length()
	_expect(partial_speed > 1.0 and partial_speed <= player.walk_speed * 0.55, "Partial analog input did not preserve stick magnitude")

	player.velocity = Vector3.ZERO
	Input.action_press("move_forward")
	for frame in range(12):
		player._physics_process(1.0 / 60.0)
	Input.action_release("move_forward")
	var planar_speed := Vector2(player.velocity.x, player.velocity.z).length()
	_expect(planar_speed > 0.5, "Forward input did not accelerate the player")
	_expect(planar_speed <= player.walk_speed + 0.05, "Walk acceleration exceeded configured walk speed")

	player.velocity = Vector3.ZERO
	Input.action_press("move_forward")
	Input.action_press("move_right")
	for frame in range(30):
		player._physics_process(1.0 / 60.0)
	Input.action_release("move_forward")
	Input.action_release("move_right")
	var diagonal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	_expect(diagonal_speed <= player.walk_speed + 0.05, "Diagonal movement exceeded configured walk speed")

	for frame in range(30):
		player._physics_process(1.0 / 60.0)
	var stopped_speed := Vector2(player.velocity.x, player.velocity.z).length()
	_expect(stopped_speed < 0.05, "Released movement input did not brake to rest")

	player.velocity = Vector3.ZERO
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for frame in range(40):
		player._physics_process(1.0 / 60.0)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var measured_sprint_speed := Vector2(player.velocity.x, player.velocity.z).length()
	_expect(measured_sprint_speed > player.walk_speed and measured_sprint_speed <= player.sprint_speed + 0.05, "Sprint did not reach its configured speed band")

	if failures.is_empty():
		print("CONTROLLER_CONTRACT_PASS actions=%d partial=%.3f planar=%.3f diagonal=%.3f stopped=%.3f sprint=%.3f" % [required_actions.size(), partial_speed, planar_speed, diagonal_speed, stopped_speed, measured_sprint_speed])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("CONTROLLER_CONTRACT_FAIL count=%d" % failures.size())
		quit(1)
