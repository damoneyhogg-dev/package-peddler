extends SceneTree

const PlayerController = preload("res://src/player_controller.gd")
const VehicleController = preload("res://src/vehicle_controller.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var player := PlayerController.new() as PackagePeddlerPlayer
	stage.add_child(player)
	var vehicle := VehicleController.new() as PackagePeddlerVehicle
	vehicle.configure("Animation Contract Van", Color("315f7c"))
	vehicle.position = Vector3(4.0, 0.0, 0.0)
	stage.add_child(vehicle)
	await process_frame

	_expect(player.courier_skeleton is Skeleton3D, "Rigged courier skeleton is unavailable to authored poses")
	_expect(player.scanner_prop is MeshInstance3D and player.presentation_parcel is MeshInstance3D, "Authored scanner or parcel prop is missing")
	_expect(player.play_interaction_presentation("scan"), "Scan presentation did not start")
	player._update_authored_presentation(0.20)
	_expect(player.presentation_kind == "scan" and player.scanner_prop.visible, "Scan presentation did not retain visible scanner pose")
	player._update_authored_presentation(0.60)
	_expect(player.presentation_kind == "" and not player.scanner_prop.visible, "Scan presentation did not finish cleanly")

	_expect(player.play_interaction_presentation("carry"), "Carry presentation did not start")
	player._update_authored_presentation(0.24)
	_expect(player.presentation_kind == "carry", "Carry pose ended before its authored transition")
	player._update_authored_presentation(0.30)
	_expect(player.presentation_kind == "", "Carry pose did not return to locomotion")

	_expect(player.play_interaction_presentation("place"), "Placement presentation did not start")
	player._update_authored_presentation(0.46)
	_expect(player.presentation_parcel.visible and player.presentation_parcel.position.y < 1.05, "Placement parcel did not lower toward the delivery surface")
	player._update_authored_presentation(0.50)
	_expect(player.presentation_kind == "" and not player.presentation_parcel.visible, "Placement presentation did not clean up")

	player.global_position = Vector3.ZERO
	_expect(player.begin_vehicle_transition("vehicle_enter", vehicle, true), "Vehicle entry transition did not start")
	var entry_start := player.global_position
	player._update_authored_presentation(0.68)
	_expect(player.presentation_kind == "vehicle_enter" and player.global_position.distance_to(entry_start) > 0.1, "Entry did not move the full-body courier toward the open door/seat")
	player.cancel_authored_presentation()
	_expect(player.presentation_kind == "" and player.visible and player.controls_enabled, "Cancelled entry did not restore on-foot control")

	_expect(player.begin_vehicle_transition("vehicle_exit", vehicle, true), "Vehicle exit transition did not start")
	player._update_authored_presentation(1.40)
	_expect(player.presentation_kind == "" and player.visible and player.controls_enabled, "Vehicle exit did not finish beside the driver door")
	_expect(player.global_position.distance_to(vehicle.exit_position()) < 0.05, "Vehicle exit did not end at the authored pavement clearance point")

	if failures.is_empty():
		print("ANIMATION_PRESENTATION_CONTRACT_PASS scan=true carry=true place=true enter=true exit=true cancel=true authored_props=true")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("ANIMATION_PRESENTATION_CONTRACT_FAIL count=%d" % failures.size())
		quit(1)
