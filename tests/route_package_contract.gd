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
	_expect(state.accept_route().accepted and state.route_order.size() == 5, "Five-stop route acceptance failed")
	_expect(String(state.stops["WB-01"].archetype) == "RESIDENTIAL_PORCH", "Residential porch archetype missing")
	_expect(String(state.stops["WB-02"].placement_rule) == "CORRECT_UNIT_204", "Apartment stairs/correct-unit contract missing")
	_expect(String(state.stops["WB-03"].confirmation) == "STAFF_SIGNATURE", "Restaurant signature contract missing")
	_expect(bool(state.packages["PP-0008-OVERLOOK"].heavy_handling_required), "Oversized heavy-handling flag missing")
	_expect(state.route_order == state.optimized_route_order(), "Optimized suggestion was not deterministic")
	var manual := ["WB-05", "WB-04", "WB-03", "WB-02", "WB-01"]
	_expect(state.reorder_stops(manual).accepted and state.gps_target_id == "WB-05", "Manual reorder did not update GPS")
	_expect(bool(state.route_plan().backtracking_warning), "Manual backtracking warning was not raised")
	_expect(not state.reorder_stops(["WB-01", "WB-01"]).accepted, "Duplicate/incomplete manual order was accepted")
	_expect(not state.scan_package("WRONG-TRACKING").accepted, "Wrong package scan succeeded")
	for stop_id in state.route_order:
		var tracking_id := String(state.stops[stop_id].tracking_id)
		_expect(state.scan_package(tracking_id).accepted, "Assigned package failed to scan")
		_expect(not state.scan_package(tracking_id).accepted, "Duplicate scan succeeded")
	_expect(state.load_package().accepted and state.route_phase == "LOADED", "Five scanned packages did not load")
	_expect(state.depart_route().accepted and state.route_phase == "DRIVING", "Loaded route could not depart")
	_expect(not state.reorder_stops(state.optimized_route_order()).accepted, "Order changed after departure")
	_expect(not state.arrive_at_stop("WB-01").accepted, "Wrong GPS stop activated")
	_expect(state.arrive_at_stop("WB-05").accepted, "Current GPS stop did not activate")
	_expect(not state.retrieve_package(String(state.stops["WB-05"].tracking_id)).accepted, "Unsafe animal did not block retrieval")
	_expect(state.resolve_stop_complication("contact_customer").accepted, "Customer-contact animal path failed")
	_expect(not state.retrieve_package(GameplayState.PACKAGE_TRACKING).accepted, "Wrong package retrieved")
	var expected_tracking := String(state.stops[state.current_stop_id].tracking_id)
	_expect(state.retrieve_package(expected_tracking).accepted, "Correct package could not be retrieved")
	_expect(state.place_package().accepted, "Valid placement failed")
	var confirmation := state.confirm_delivery()
	_expect(confirmation.accepted and confirmation.reward == 94 and state.route_phase == "DRIVING", "First stop confirmation or reward failed")
	_expect(not state.confirm_delivery().accepted, "Repeated confirmation duplicated payout")
	_expect(state.gps_target_id == "WB-04" and state.credits == 94, "GPS did not advance or payout changed")
	var return_path := GameplayState.new()
	return_path.accept_route()
	return_path.reorder_stops(manual)
	for definition in GameplayState.STOP_DEFINITIONS:
		return_path.scan_package(String(definition.tracking_id))
	return_path.load_package()
	return_path.depart_route()
	return_path.arrive_at_stop("WB-05")
	_expect(return_path.resolve_stop_complication("undeliverable").accepted and return_path.route_phase == "RETURN_PENDING", "Animal undeliverable path failed")
	_expect(return_path.return_package().accepted and return_path.gps_target_id == "WB-04" and return_path.credits == 0, "Safe package return did not advance without stop payout")
	if failures.is_empty():
		print("ROUTE_PACKAGE_CONTRACT_PASS stops=5 archetypes=5 optimized=true reorder=true gps=true guards=true scan_once=true correct_package=true animal_paths=true payout_once=true")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
