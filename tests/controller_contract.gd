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
		"sprint", "interact", "camera_toggle", "pause", "combat_retreat"
	]
	for action in required_actions:
		_expect(InputMap.has_action(action), "Missing input action: %s" % action)
	var retreat_has_rb := false
	for mapping in InputMap.action_get_events("combat_retreat"):
		if mapping is InputEventJoypadButton and mapping.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			retreat_has_rb = true
	_expect(retreat_has_rb, "Combat retreat is not mapped to a distinct controller RB action: %s" % str(InputMap.action_get_events("combat_retreat")))

	var player := PlayerController.new()
	root.add_child(player)
	await process_frame
	var configured_fall_recovery_height := player.fall_recovery_height
	player.fall_recovery_height = -1000.0

	_expect(player.get_node_or_null("PlayerCollision") is CollisionShape3D, "Player collider was not created")
	_expect(player.get_node_or_null("RiggedCourier") is Node3D, "Rigged courier visual was not created")
	_expect(player.animation_player is AnimationPlayer, "Courier AnimationPlayer was not connected")
	for animation_name in [&"Idle", &"Walk", &"Run"]:
		_expect(player.animation_player != null and player.animation_player.has_animation(animation_name), "Courier controller is missing animation: %s" % animation_name)
	_expect(player.get_node_or_null("CameraPivot/CameraCollisionArm") is SpringArm3D, "SpringArm3D camera collision was not created")
	_expect(player.get_node_or_null("CameraPivot/CameraCollisionArm/GameplayCamera") is Camera3D, "Gameplay camera was not created")
	_expect(player.camera.current, "Gameplay camera is not current")
	_expect(is_equal_approx(player.spring_arm.spring_length, 3.6), "Third-person camera distance is incorrect")
	Input.action_press("camera_toggle")
	player.suppress_modal_camera_leak()
	player._update_camera_mode()
	_expect(not player.first_person, "Modal-closing shared input leaked into camera toggle")
	Input.action_release("camera_toggle")
	player._update_camera_mode()
	Input.action_press("camera_toggle")
	player._update_camera_mode()
	_expect(player.first_person, "Camera toggle did not recover after shared input release")
	Input.action_release("camera_toggle")
	player._update_camera_mode()

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
	player.velocity = Vector3(3.0, 0.0, 2.0)
	var frozen_position := player.global_position
	player.set_controls_enabled(false)
	Input.action_press("move_forward")
	player._physics_process(1.0 / 15.0)
	Input.action_release("move_forward")
	_expect(player.global_position.is_equal_approx(frozen_position), "Disabled modal controls allowed position drift")
	_expect(player.velocity.is_zero_approx(), "Disabled modal controls retained velocity")
	player.set_controls_enabled(true)

	Input.action_press("move_forward", 0.5)
	for frame in range(12):
		player._physics_process(1.0 / 60.0)
	Input.action_release("move_forward")
	var partial_speed := Vector2(player.velocity.x, player.velocity.z).length()
	_expect(partial_speed > 1.0 and partial_speed <= player.walk_speed * 0.55, "Partial analog input did not preserve stick magnitude")
	_expect(player.current_animation == "Walk", "Movement did not select the Walk animation")

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
	_expect(diagonal_speed > 0.5, "Diagonal input did not move the player")
	_expect(diagonal_speed <= player.walk_speed + 0.05, "Diagonal movement exceeded configured walk speed")

	for frame in range(30):
		player._physics_process(1.0 / 60.0)
	var stopped_speed := Vector2(player.velocity.x, player.velocity.z).length()
	_expect(stopped_speed < 0.05, "Released movement input did not brake to rest")
	_expect(player.current_animation == "Idle", "Braking to rest did not restore the Idle animation")

	player.velocity = Vector3.ZERO
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for frame in range(40):
		player._physics_process(1.0 / 60.0)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var measured_sprint_speed := Vector2(player.velocity.x, player.velocity.z).length()
	_expect(measured_sprint_speed > player.walk_speed and measured_sprint_speed <= player.sprint_speed + 0.05, "Sprint did not reach its configured speed band")
	_expect(player.current_animation == "Run", "Sprint did not select the Run animation")

	player.fall_recovery_height = configured_fall_recovery_height
	player.global_position = Vector3(4.0, player.fall_recovery_height - 1.0, 4.0)
	player.velocity = Vector3(2.0, -8.0, 2.0)
	player._recover_if_out_of_bounds()
	_expect(player.global_position.is_equal_approx(player.recovery_position), "Fallen player did not return to the recovery point")
	_expect(player.velocity.is_zero_approx(), "Fall recovery did not clear player velocity")

	if failures.is_empty():
		print("CONTROLLER_CONTRACT_PASS actions=%d modal_freeze=true camera_leak_blocked=true partial=%.3f planar=%.3f diagonal=%.3f stopped=%.3f sprint=%.3f recovery=true rigged=true" % [required_actions.size(), partial_speed, planar_speed, diagonal_speed, stopped_speed, measured_sprint_speed])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("CONTROLLER_CONTRACT_FAIL count=%d" % failures.size())
		quit(1)
