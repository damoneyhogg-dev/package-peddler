extends SceneTree

const GameplayState = preload("res://src/gameplay_state.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	var state := GameplayState.new()
	_expect(not state.scan_package(GameplayState.PACKAGE_TRACKING).accepted, "Scan succeeded without a route")
	_expect(state.accept_route().accepted and state.route_phase == "ROUTE_ACCEPTED", "Route acceptance failed")
	_expect(not state.accept_route().accepted, "Duplicate route acceptance succeeded")
	_expect(not state.scan_package("WRONG-TRACKING").accepted and state.package_status == "ASSIGNED", "Wrong package scan changed state")
	_expect(state.scan_package(GameplayState.PACKAGE_TRACKING).accepted and state.package_status == "SCANNED", "Correct package did not scan")
	_expect(not state.scan_package(GameplayState.PACKAGE_TRACKING).accepted, "Duplicate package scan succeeded")
	_expect(state.load_package().accepted and state.route_phase == "LOADED", "Scanned package did not load")
	_expect(state.depart_route().accepted and state.route_phase == "DRIVING", "Loaded route could not depart")
	_expect(state.arrive_at_stop().accepted and state.stop_status == "ARRIVED", "Active stop did not activate")
	_expect(state.retrieve_package().accepted and state.package_status == "RETRIEVED", "Assigned package could not be retrieved")
	_expect(state.place_package().accepted and state.package_status == "PLACED", "Valid placement failed")
	var confirmation := state.confirm_delivery()
	_expect(confirmation.accepted and confirmation.reward == 85, "Confirmed delivery did not award the route payout")
	_expect(state.route_phase == "ROUTE_COMPLETE" and state.package_status == "DELIVERED" and state.stop_status == "DELIVERED", "Confirmation was not atomic")
	var duplicate := state.confirm_delivery()
	_expect(not duplicate.accepted and duplicate.reward == 0 and state.credits == 85, "Repeated confirmation duplicated payout")
	if failures.is_empty():
		print("ROUTE_PACKAGE_CONTRACT_PASS guards=true scan_once=true load=true retrieve=true placement=true confirmation_atomic=true payout_once=true")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

