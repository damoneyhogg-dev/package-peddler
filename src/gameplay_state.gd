class_name PackagePeddlerGameplayState
extends RefCounted

const SAVE_PATH := "user://package_peddler_save.json"
const VEHICLES := ["Parcel Finch", "Cargo Comet"]
const DRIVERS := ["Owner Courier", "Maya Brooks", "Jordan Reed", "Alex Rivera"]
const SCHEMA_VERSION := 6
const DEFAULT_PLAYER_POSITION := Vector3(-11.0, 1.0, -1.0)
const VALID_RUNTIME_LOCATIONS := ["ON_FOOT", "IN_VEHICLE"]
const VALID_OUTCOMES := ["deescalated", "left", "win", "loss"]
const ROUTE_OFFER := {
	"route_id": "WB-FIVE-01",
	"area": "Willowbrook Commons",
	"payout": 475,
	"miles": 11.8,
	"estimated_minutes": 74,
	"stops": 5
}
const PACKAGE_TRACKING := "PP-1047-ONE"
const DELIVERY_ADDRESS := "1047 Juniper Lane"
const ROUTE_COMPLETION_BONUS := 50
const BASE_FUEL_EXPENSE := 22
const BASE_MAINTENANCE_EXPENSE := 13
const STOP_DEFINITIONS := [
	{"stop_id": "WB-01", "address": "1047 Juniper Lane", "payout": 85, "miles": 2.4, "minutes": 18, "tracking_id": "PP-1047-ONE", "map_position": [2.0, 7.0], "archetype": "RESIDENTIAL_PORCH", "confirmation": "PHOTO", "placement_rule": "PORCH_CLEAR_OF_DOOR", "package_size": "medium", "weight_lb": 12.0},
	{"stop_id": "WB-02", "address": "22 Lantern Court, Building C, Unit 204", "payout": 72, "miles": 1.6, "minutes": 11, "tracking_id": "PP-0022-LANTERN", "map_position": [4.0, 5.0], "archetype": "APARTMENT_STAIRS", "confirmation": "UNIT_DOOR_PHOTO", "placement_rule": "CORRECT_UNIT_204", "package_size": "small", "weight_lb": 6.0},
	{"stop_id": "WB-03", "address": "315 Market Walk", "payout": 96, "miles": 2.9, "minutes": 17, "tracking_id": "PP-0315-MARKET", "map_position": [8.0, 4.0], "archetype": "RESTAURANT_COUNTER", "confirmation": "STAFF_SIGNATURE", "placement_rule": "PUBLIC_COUNTER_HANDOFF", "package_size": "medium", "weight_lb": 9.0},
	{"stop_id": "WB-04", "address": "8 Overlook Terrace", "payout": 78, "miles": 2.1, "minutes": 13, "tracking_id": "PP-0008-OVERLOOK", "map_position": [7.0, 8.0], "archetype": "OVERSIZED_SAFE_PLACEMENT", "confirmation": "PHOTO", "placement_rule": "DO_NOT_BLOCK_OUTWARD_DOOR_OR_WALKWAY", "package_size": "oversized", "weight_lb": 64.0},
	{"stop_id": "WB-05", "address": "640 Foundry Avenue", "payout": 94, "miles": 2.8, "minutes": 15, "tracking_id": "PP-0640-FOUNDRY", "map_position": [10.0, 7.0], "archetype": "UNSAFE_ANIMAL", "confirmation": "PHOTO", "placement_rule": "PORCH_AFTER_ANIMAL_SECURED", "package_size": "medium", "weight_lb": 14.0}
]
const OPTIMIZED_STOP_ORDER := ["WB-01", "WB-02", "WB-03", "WB-05", "WB-04"]
const VALID_ROUTE_PHASES := ["NO_ROUTE", "ROUTE_ACCEPTED", "SCANNING", "LOADED", "DRIVING", "AT_STOP", "PACKAGE_RETRIEVED", "PLACED", "RETURN_PENDING", "ROUTE_COMPLETE"]
const VALID_PACKAGE_STATUSES := ["ASSIGNED", "SCANNED", "LOADED", "RETRIEVED", "PLACED", "DELIVERED", "RETURN_REQUIRED", "RETURNED"]

var selected_vehicle := VEHICLES[0]
var selected_driver := DRIVERS[0]
var combat_enabled := true
var encounter_resolved := false
var encounter_outcome := ""
var encounter_reward_claimed := false
var credits := 0
var reputation := 0
var route_minutes := 0
var player_health := 100
var rival_health := 100
var stamina := 100
var fight_active := false
var route_phase := "NO_ROUTE"
var route_id := ""
var package_status := "ASSIGNED"
var stop_status := "PENDING"
var delivery_reward_claimed := false
var delivery_earnings := 0
var route_order: Array[String] = []
var stops: Dictionary = {}
var packages: Dictionary = {}
var active_stop_index := 0
var current_stop_id := ""
var gps_target_id := ""
var gps_target_address := ""
var route_bonus_claimed := false
var expenses_claimed := false
var fuel_expense := 0
var maintenance_expense := 0
var penalty_expense := 0
var gross_earnings := 0
var net_earnings := 0
var route_start_credits := 0
var vehicle_position := Vector3.ZERO
var vehicle_rotation_y := 0.0
var player_position := DEFAULT_PLAYER_POSITION
var runtime_location := "ON_FOOT"
var vehicle_parked := true
var vehicle_door_open := false
var door_waiting_for_close := false

func reset_defaults() -> void:
	selected_vehicle = VEHICLES[0]
	selected_driver = DRIVERS[0]
	combat_enabled = true
	encounter_resolved = false
	encounter_outcome = ""
	encounter_reward_claimed = false
	credits = 0
	reputation = 0
	route_minutes = 0
	player_health = 100
	rival_health = 100
	stamina = 100
	fight_active = false
	route_phase = "NO_ROUTE"
	route_id = ""
	package_status = "ASSIGNED"
	stop_status = "PENDING"
	delivery_reward_claimed = false
	delivery_earnings = 0
	route_order.clear()
	stops.clear()
	packages.clear()
	active_stop_index = 0
	current_stop_id = ""
	gps_target_id = ""
	gps_target_address = ""
	route_bonus_claimed = false
	expenses_claimed = false
	fuel_expense = 0
	maintenance_expense = 0
	penalty_expense = 0
	gross_earnings = 0
	net_earnings = 0
	route_start_credits = 0
	vehicle_position = Vector3.ZERO
	vehicle_rotation_y = 0.0
	player_position = DEFAULT_PLAYER_POSITION
	runtime_location = "ON_FOOT"
	vehicle_parked = true
	vehicle_door_open = false
	door_waiting_for_close = false

func select_vehicle(index: int) -> bool:
	if index < 0 or index >= VEHICLES.size():
		return false
	selected_vehicle = VEHICLES[index]
	return true

func select_driver(index: int) -> bool:
	if index < 0 or index >= DRIVERS.size():
		return false
	selected_driver = DRIVERS[index]
	return true

func accept_route() -> Dictionary:
	if route_phase != "NO_ROUTE":
		return {"accepted": false, "message": "A route is already active."}
	route_id = String(ROUTE_OFFER.route_id)
	route_start_credits = credits
	route_phase = "ROUTE_ACCEPTED"
	route_order.assign(OPTIMIZED_STOP_ORDER)
	stops.clear()
	packages.clear()
	for definition in STOP_DEFINITIONS:
		var stop_id := String(definition.stop_id)
		var tracking_id := String(definition.tracking_id)
		stops[stop_id] = {
			"stop_id": stop_id, "address": String(definition.address),
			"payout": int(definition.payout), "miles": float(definition.miles),
			"minutes": int(definition.minutes), "status": "PENDING",
			"reward_claimed": false, "tracking_id": tracking_id,
			"map_position": definition.map_position.duplicate(),
			"archetype": String(definition.archetype), "confirmation": String(definition.confirmation),
			"placement_rule": String(definition.placement_rule),
			"animal_hazard": "ACTIVE" if String(definition.archetype) == "UNSAFE_ANIMAL" else "NONE"
		}
		packages[tracking_id] = {
			"tracking_id": tracking_id, "stop_id": stop_id,
			"dimensions": String(definition.package_size), "weight_lb": float(definition.weight_lb),
			"heavy_handling_required": String(definition.package_size) == "oversized",
			"status": "ASSIGNED"
		}
	active_stop_index = 0
	_set_current_stop(route_order[0])
	_sync_legacy_status()
	return {"accepted": true, "message": "Route %s accepted." % route_id}

func optimized_route_order() -> Array[String]:
	return OPTIMIZED_STOP_ORDER.duplicate()

func reorder_stops(new_order: Array) -> Dictionary:
	if route_phase not in ["ROUTE_ACCEPTED", "SCANNING", "LOADED"]:
		return {"accepted": false, "message": "Stop order can only change before departure."}
	var normalized: Array[String] = []
	for value in new_order:
		normalized.append(String(value))
	var expected: Array[String] = []
	for definition in STOP_DEFINITIONS:
		expected.append(String(definition.stop_id))
	var sorted_order := normalized.duplicate()
	var sorted_expected := expected.duplicate()
	sorted_order.sort()
	sorted_expected.sort()
	if sorted_order != sorted_expected or normalized.size() != expected.size():
		return {"accepted": false, "message": "Manual order must contain every stop exactly once."}
	route_order = normalized
	active_stop_index = 0
	_set_current_stop(route_order[0])
	return {"accepted": true, "message": "Manual stop order saved.", "order": route_order.duplicate()}

func route_plan() -> Dictionary:
	var metrics := route_metrics(route_order)
	return {
		"route_id": route_id, "order": route_order.duplicate(),
		"optimized_order": optimized_route_order(), "current_stop_id": current_stop_id,
		"gps_target_id": gps_target_id, "gps_target_address": gps_target_address,
		"miles": metrics.miles, "estimated_minutes": metrics.estimated_minutes,
		"backtracking_warning": metrics.backtracking_warning
	}

func route_metrics(order: Array) -> Dictionary:
	if order.size() != STOP_DEFINITIONS.size():
		return {"miles": 0.0, "estimated_minutes": 0, "backtracking_warning": true}
	var depot := Vector2.ZERO
	var previous := depot
	var distance := 0.0
	for value in order:
		var stop_id := String(value)
		var position_data := _canonical_map_position(stop_id)
		if position_data.is_empty():
			return {"miles": 0.0, "estimated_minutes": 0, "backtracking_warning": true}
		var position := Vector2(float(position_data[0]), float(position_data[1]))
		distance += previous.distance_to(position)
		previous = position
	var optimized_distance := _order_distance(OPTIMIZED_STOP_ORDER)
	var scaled_miles := distance * float(ROUTE_OFFER.miles) / maxf(optimized_distance, 0.001)
	var minutes := ceili(scaled_miles / float(ROUTE_OFFER.miles) * float(ROUTE_OFFER.estimated_minutes))
	return {"miles": snappedf(scaled_miles, 0.1), "estimated_minutes": minutes, "backtracking_warning": distance > optimized_distance * 1.1}

func _canonical_map_position(stop_id: String) -> Array:
	for definition in STOP_DEFINITIONS:
		if String(definition.stop_id) == stop_id:
			return definition.map_position
	return []

func _order_distance(order: Array) -> float:
	var previous := Vector2.ZERO
	var distance := 0.0
	for value in order:
		var stop_id := String(value)
		var definition: Dictionary = STOP_DEFINITIONS.filter(func(item): return String(item.stop_id) == stop_id)[0]
		var position := Vector2(float(definition.map_position[0]), float(definition.map_position[1]))
		distance += previous.distance_to(position)
		previous = position
	return distance

func next_unscanned_tracking() -> String:
	for stop_id in route_order:
		var tracking_id := String(stops[stop_id].tracking_id)
		if String(packages[tracking_id].status) == "ASSIGNED":
			return tracking_id
	return ""

func scan_package(tracking_id: String) -> Dictionary:
	if route_phase not in ["ROUTE_ACCEPTED", "SCANNING"]:
		return {"accepted": false, "message": "Accept a route before scanning."}
	if not packages.has(tracking_id):
		return {"accepted": false, "message": "Wrong package for this route."}
	var package: Dictionary = packages[tracking_id]
	if String(package.status) != "ASSIGNED":
		return {"accepted": false, "message": "Package already scanned."}
	package.status = "SCANNED"
	packages[tracking_id] = package
	route_phase = "SCANNING"
	_sync_legacy_status()
	return {"accepted": true, "message": "Package %s scanned." % tracking_id}

func load_package(tracking_id := "") -> Dictionary:
	if route_phase != "SCANNING":
		return {"accepted": false, "message": "Only the scanned route package can be loaded."}
	if not _all_packages_have_status("SCANNED"):
		return {"accepted": false, "message": "Scan all five assigned packages before loading."}
	if tracking_id != "" and not packages.has(tracking_id):
		return {"accepted": false, "message": "That package is not assigned to this route."}
	for package_id in packages:
		var package: Dictionary = packages[package_id]
		package.status = "LOADED"
		packages[package_id] = package
	route_phase = "LOADED"
	_sync_legacy_status()
	return {"accepted": true, "message": "All five packages loaded by stop order."}

func depart_route() -> Dictionary:
	if route_phase != "LOADED" or not _all_packages_have_status("LOADED"):
		return {"accepted": false, "message": "Scan and load all five packages before departure."}
	route_phase = "DRIVING"
	return {"accepted": true, "message": "Route departed. GPS target: %s." % gps_target_address}

func arrive_at_stop(stop_id := "") -> Dictionary:
	if route_phase != "DRIVING":
		return {"accepted": false, "message": "This is not the active delivery stop."}
	var requested := current_stop_id if stop_id == "" else String(stop_id)
	if requested != current_stop_id or not stops.has(requested):
		return {"accepted": false, "message": "Wrong stop. Follow the active GPS target."}
	route_phase = "AT_STOP"
	var stop: Dictionary = stops[current_stop_id]
	stop.status = "ARRIVED"
	stops[current_stop_id] = stop
	_sync_legacy_status()
	return {"accepted": true, "message": "Arrived at %s. Retrieve the package." % gps_target_address}

func resolve_stop_complication(action: String) -> Dictionary:
	if route_phase != "AT_STOP" or not stops.has(current_stop_id):
		return {"accepted": false, "message": "No active stop complication."}
	var stop: Dictionary = stops[current_stop_id]
	if String(stop.archetype) != "UNSAFE_ANIMAL" or String(stop.animal_hazard) != "ACTIVE":
		return {"accepted": false, "message": "This stop has no unresolved animal hazard."}
	match action:
		"wait", "contact_customer":
			stop.animal_hazard = "SECURED"
			stops[current_stop_id] = stop
			return {"accepted": true, "message": "Customer secured the animal; delivery may continue."}
		"undeliverable":
			var tracking_id := String(stop.tracking_id)
			var package: Dictionary = packages[tracking_id]
			package.status = "RETURN_REQUIRED"
			stop.status = "UNDELIVERABLE"
			stop.reward_claimed = true
			packages[tracking_id] = package
			stops[current_stop_id] = stop
			penalty_expense += 10
			route_phase = "RETURN_PENDING"
			gps_target_id = "WAREHOUSE_RETURN"
			gps_target_address = "Willowbrook Distribution Warehouse"
			_sync_legacy_status()
			return {"accepted": true, "message": "Stop marked undeliverable. Return the package safely; never confront the animal."}
		_:
			return {"accepted": false, "message": "Choose wait, contact_customer, or undeliverable."}

func return_package() -> Dictionary:
	if route_phase != "RETURN_PENDING" or not stops.has(current_stop_id):
		return {"accepted": false, "message": "No package is awaiting return."}
	var stop: Dictionary = stops[current_stop_id]
	var tracking_id := String(stop.tracking_id)
	var package: Dictionary = packages[tracking_id]
	if String(package.status) != "RETURN_REQUIRED":
		return {"accepted": false, "message": "The active package is not marked for return."}
	package.status = "RETURNED"
	stop.status = "RETURNED"
	packages[tracking_id] = package
	stops[current_stop_id] = stop
	var bonus := _advance_after_settlement()
	_sync_legacy_status()
	return {"accepted": true, "reward": bonus, "message": "Package return recorded; no stop payout awarded."}

func retrieve_package(tracking_id := "") -> Dictionary:
	if route_phase != "AT_STOP":
		return {"accepted": false, "message": "The assigned loaded package is not ready to retrieve."}
	var stop: Dictionary = stops[current_stop_id]
	if String(stop.animal_hazard) == "ACTIVE":
		return {"accepted": false, "message": "Unsafe animal present. Wait, contact the customer, or mark the stop undeliverable."}
	var expected_tracking := String(stop.tracking_id)
	var requested := expected_tracking if tracking_id == "" else String(tracking_id)
	if requested != expected_tracking or not packages.has(requested):
		return {"accepted": false, "message": "Wrong package for the active stop."}
	var package: Dictionary = packages[requested]
	if String(package.status) != "LOADED":
		return {"accepted": false, "message": "The assigned loaded package is not ready to retrieve."}
	package.status = "RETRIEVED"
	packages[requested] = package
	route_phase = "PACKAGE_RETRIEVED"
	_sync_legacy_status()
	return {"accepted": true, "message": "Correct package retrieved."}

func place_package(placement_context := "") -> Dictionary:
	if route_phase != "PACKAGE_RETRIEVED":
		return {"accepted": false, "message": "Retrieve the correct package before placement."}
	var tracking_id := String(stops[current_stop_id].tracking_id)
	var stop: Dictionary = stops[current_stop_id]
	if String(placement_context) != String(stop.placement_rule):
		return {"accepted": false, "message": "Invalid placement for this stop; keep doors, walkways, and resident access clear."}
	var package: Dictionary = packages[tracking_id]
	if String(package.status) != "RETRIEVED":
		return {"accepted": false, "message": "Retrieve the correct package before placement."}
	package.status = "PLACED"
	packages[tracking_id] = package
	route_phase = "PLACED"
	_sync_legacy_status()
	return {"accepted": true, "message": "Package placed in the valid delivery zone."}

func confirm_delivery(proof_type := "") -> Dictionary:
	if route_phase == "ROUTE_COMPLETE":
		return {"accepted": false, "reward": 0, "message": "Delivery already confirmed; no duplicate payout."}
	if route_phase != "PLACED" or not stops.has(current_stop_id):
		return {"accepted": false, "reward": 0, "message": "Placement is required before confirmation."}
	var stop: Dictionary = stops[current_stop_id]
	if String(proof_type) != String(stop.confirmation):
		return {"accepted": false, "reward": 0, "message": "This stop requires %s confirmation." % String(stop.confirmation)}
	var tracking_id := String(stop.tracking_id)
	var package: Dictionary = packages[tracking_id]
	if String(package.status) != "PLACED" or bool(stop.reward_claimed):
		return {"accepted": false, "reward": 0, "message": "Delivery already settled or package is not placed."}
	package.status = "DELIVERED"
	stop.status = "DELIVERED"
	stop.reward_claimed = true
	packages[tracking_id] = package
	stops[current_stop_id] = stop
	var reward := 0
	reward = int(stop.payout)
	gross_earnings += reward
	delivery_earnings = gross_earnings
	credits += reward
	var delivered_address := String(stop.address)
	reward += _advance_after_settlement()
	_sync_legacy_status()
	return {"accepted": true, "reward": reward, "route_complete": route_phase == "ROUTE_COMPLETE", "message": "Delivery confirmed at %s." % delivered_address}

func _advance_after_settlement() -> int:
	if active_stop_index + 1 < route_order.size():
		active_stop_index += 1
		_set_current_stop(route_order[active_stop_index])
		route_phase = "DRIVING"
		return 0
	route_phase = "ROUTE_COMPLETE"
	var bonus := 0
	if not route_bonus_claimed:
		route_bonus_claimed = true
		delivery_reward_claimed = true
		bonus = ROUTE_COMPLETION_BONUS
		gross_earnings += bonus
		delivery_earnings = gross_earnings
		credits += bonus
	if not expenses_claimed:
		expenses_claimed = true
		fuel_expense = BASE_FUEL_EXPENSE
		maintenance_expense = BASE_MAINTENANCE_EXPENSE
		credits -= fuel_expense + maintenance_expense + penalty_expense
	net_earnings = gross_earnings - fuel_expense - maintenance_expense - penalty_expense
	return bonus

func earnings_summary() -> Dictionary:
	return {"gross": gross_earnings, "fuel": fuel_expense, "maintenance": maintenance_expense, "penalties": penalty_expense, "net": net_earnings}

func _set_current_stop(stop_id: String) -> void:
	current_stop_id = stop_id
	gps_target_id = stop_id
	gps_target_address = String(stops[stop_id].address) if stops.has(stop_id) else ""

func _all_packages_have_status(status: String) -> bool:
	if packages.size() != STOP_DEFINITIONS.size():
		return false
	for package in packages.values():
		if String(package.status) != status:
			return false
	return true

func _sync_legacy_status() -> void:
	if current_stop_id == "" or not stops.has(current_stop_id):
		package_status = "ASSIGNED"
		stop_status = "PENDING"
		return
	var stop: Dictionary = stops[current_stop_id]
	stop_status = String(stop.status)
	var tracking_id := String(stop.tracking_id)
	package_status = String(packages[tracking_id].status) if packages.has(tracking_id) else "ASSIGNED"

func begin_fight() -> bool:
	if encounter_resolved or not combat_enabled or fight_active:
		return false
	player_health = 100
	rival_health = 100
	stamina = 100
	fight_active = true
	return true

func combat_turn(action: String) -> Dictionary:
	if encounter_resolved or not fight_active:
		return {"accepted": false, "message": "No active fight can accept that action."}
	if not combat_enabled:
		return {"accepted": false, "message": "Combat is disabled."}
	var message := ""
	var incoming := 12
	match action:
		"light":
			if stamina < 15:
				return _recover_turn("Too tired to strike; you catch your breath.", 18, 10)
			stamina -= 15
			rival_health -= 22
			message = "Quick body shot lands."
		"heavy":
			if stamina < 30:
				return _recover_turn("The heavy swing stalls; you catch your breath.", 20, 12)
			stamina -= 30
			rival_health -= 38
			incoming = 17
			message = "Controlled heavy strike lands."
		"block":
			stamina = min(100, stamina + 10)
			incoming = 3
			message = "You block and hold your ground."
		"dodge":
			if stamina < 20:
				return _recover_turn("Too tired to dodge; the rival clips you.", 14, 8)
			stamina -= 20
			incoming = 0
			message = "You dodge cleanly and create space."
		_:
			return {"accepted": false, "message": "Unknown combat action."}
	if rival_health <= 0:
		rival_health = 0
		resolve_encounter("win")
		return {"accepted": true, "message": "%s Rival knocked down; the fight stops." % message}
	player_health = max(0, player_health - incoming)
	stamina = min(100, stamina + 8)
	if player_health <= 0:
		resolve_encounter("loss")
		message += " You are knocked down; the fight stops."
	else:
		message += " Rival counters for %d." % incoming
	return {"accepted": true, "message": message}

func _recover_turn(message: String, recovery: int, incoming: int) -> Dictionary:
	stamina = min(100, stamina + recovery)
	player_health = max(0, player_health - incoming)
	if player_health <= 0:
		resolve_encounter("loss")
		message += " You are knocked down; the fight stops."
	return {"accepted": true, "message": message}

func resolve_encounter(outcome: String) -> Dictionary:
	if outcome not in VALID_OUTCOMES:
		return {"accepted": false, "reward": 0, "message": "Invalid encounter outcome."}
	if encounter_resolved:
		return {"accepted": false, "reward": 0, "message": "Encounter already resolved; no duplicate reward."}
	if outcome in ["win", "loss"] and not fight_active:
		return {"accepted": false, "reward": 0, "message": "Combat outcome requires an active fight."}
	if outcome == "deescalated" and fight_active:
		return {"accepted": false, "reward": 0, "message": "Cannot de-escalate after the fight has started; retreat instead."}
	encounter_resolved = true
	encounter_outcome = outcome
	fight_active = false
	var reward := 0
	match outcome:
		"deescalated":
			reward = 35
			reputation += 2
			route_minutes += 4
		"left":
			reputation -= 1
			route_minutes += 8
		"win":
			reward = 15
			reputation -= 3
			route_minutes += 12
		"loss":
			reputation -= 4
			route_minutes += 20
	if not encounter_reward_claimed:
		credits += reward
		encounter_reward_claimed = true
	return {"accepted": true, "reward": reward, "message": "Encounter resolved: %s." % outcome}

func retreat_from_fight() -> Dictionary:
	if not fight_active or encounter_resolved:
		return {"accepted": false, "reward": 0, "message": "No active fight to retreat from."}
	return resolve_encounter("left")

func to_dictionary() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"selected_driver": selected_driver,
		"selected_vehicle": selected_vehicle,
		"combat_enabled": combat_enabled,
		"encounter_resolved": encounter_resolved,
		"encounter_outcome": encounter_outcome,
		"encounter_reward_claimed": encounter_reward_claimed,
		"credits": credits,
		"reputation": reputation,
		"route_minutes": route_minutes,
		"route_phase": route_phase,
		"route_id": route_id,
		"package_status": package_status,
		"stop_status": stop_status,
		"delivery_reward_claimed": delivery_reward_claimed,
		"delivery_earnings": delivery_earnings,
		"route_order": route_order.duplicate(),
		"stops": stops.duplicate(true),
		"packages": packages.duplicate(true),
		"active_stop_index": active_stop_index,
		"current_stop_id": current_stop_id,
		"gps_target_id": gps_target_id,
		"gps_target_address": gps_target_address,
		"route_bonus_claimed": route_bonus_claimed,
		"expenses_claimed": expenses_claimed,
		"fuel_expense": fuel_expense,
		"maintenance_expense": maintenance_expense,
		"penalty_expense": penalty_expense,
		"gross_earnings": gross_earnings,
		"net_earnings": net_earnings,
		"route_start_credits": route_start_credits,
		"vehicle_position": [vehicle_position.x, vehicle_position.y, vehicle_position.z],
		"vehicle_rotation_y": vehicle_rotation_y,
		"player_position": [player_position.x, player_position.y, player_position.z],
		"runtime_location": runtime_location,
		"vehicle_parked": vehicle_parked,
		"vehicle_door_open": vehicle_door_open,
		"door_waiting_for_close": door_waiting_for_close
	}

func apply_dictionary(data: Dictionary) -> bool:
	reset_defaults()
	var required_types := {
		"selected_driver": TYPE_STRING,
		"selected_vehicle": TYPE_STRING,
		"combat_enabled": TYPE_BOOL,
		"encounter_resolved": TYPE_BOOL,
		"encounter_outcome": TYPE_STRING,
		"encounter_reward_claimed": TYPE_BOOL,
		"route_phase": TYPE_STRING,
		"route_id": TYPE_STRING,
		"package_status": TYPE_STRING,
		"stop_status": TYPE_STRING,
		"delivery_reward_claimed": TYPE_BOOL,
		"route_order": TYPE_ARRAY,
		"stops": TYPE_DICTIONARY,
		"packages": TYPE_DICTIONARY,
		"current_stop_id": TYPE_STRING,
		"gps_target_id": TYPE_STRING,
		"gps_target_address": TYPE_STRING,
		"route_bonus_claimed": TYPE_BOOL,
		"expenses_claimed": TYPE_BOOL,
		"vehicle_position": TYPE_ARRAY,
		"player_position": TYPE_ARRAY,
		"runtime_location": TYPE_STRING,
		"vehicle_parked": TYPE_BOOL,
		"vehicle_door_open": TYPE_BOOL,
		"door_waiting_for_close": TYPE_BOOL
	}
	for key in required_types:
		if not data.has(key) or typeof(data[key]) != required_types[key]:
			return false
	for numeric_key in ["schema_version", "credits", "reputation", "route_minutes", "delivery_earnings", "active_stop_index", "fuel_expense", "maintenance_expense", "penalty_expense", "gross_earnings", "net_earnings", "route_start_credits"]:
		if not data.has(numeric_key) or not _is_integer_number(data[numeric_key]):
			return false
	if not data.has("vehicle_rotation_y") or typeof(data.vehicle_rotation_y) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	if int(data["schema_version"]) != SCHEMA_VERSION:
		return false
	var vehicle := String(data.selected_vehicle)
	selected_vehicle = vehicle if vehicle in VEHICLES else VEHICLES[0]
	var driver := String(data.selected_driver)
	selected_driver = driver if driver in DRIVERS else DRIVERS[0]
	combat_enabled = bool(data.combat_enabled)
	encounter_resolved = bool(data.encounter_resolved)
	encounter_outcome = String(data.encounter_outcome)
	encounter_reward_claimed = bool(data.encounter_reward_claimed)
	credits = clampi(int(data.credits), 0, 1000000000)
	reputation = clampi(int(data.reputation), -1000, 1000)
	route_minutes = clampi(int(data.route_minutes), 0, 1000000)
	route_phase = String(data.route_phase)
	route_id = String(data.route_id)
	package_status = String(data.package_status)
	stop_status = String(data.stop_status)
	delivery_reward_claimed = bool(data.delivery_reward_claimed)
	delivery_earnings = clampi(int(data.delivery_earnings), 0, 1000000000)
	route_bonus_claimed = bool(data.route_bonus_claimed)
	expenses_claimed = bool(data.expenses_claimed)
	fuel_expense = clampi(int(data.fuel_expense), 0, 1000000000)
	maintenance_expense = clampi(int(data.maintenance_expense), 0, 1000000000)
	penalty_expense = clampi(int(data.penalty_expense), 0, 1000000000)
	gross_earnings = clampi(int(data.gross_earnings), 0, 1000000000)
	net_earnings = clampi(int(data.net_earnings), -1000000000, 1000000000)
	route_start_credits = clampi(int(data.route_start_credits), 0, 1000000000)
	active_stop_index = int(data.active_stop_index)
	current_stop_id = String(data.current_stop_id)
	gps_target_id = String(data.gps_target_id)
	gps_target_address = String(data.gps_target_address)
	for value in data.route_order:
		route_order.append(String(value))
	stops = data.stops.duplicate(true)
	packages = data.packages.duplicate(true)
	var saved_position: Array = data.vehicle_position
	if saved_position.size() != 3 or not saved_position.all(func(value): return typeof(value) in [TYPE_INT, TYPE_FLOAT]):
		reset_defaults()
		return false
	vehicle_position = Vector3(float(saved_position[0]), float(saved_position[1]), float(saved_position[2]))
	vehicle_rotation_y = float(data.vehicle_rotation_y)
	if not is_finite(vehicle_rotation_y) or absf(vehicle_rotation_y) > 1000.0:
		reset_defaults()
		return false
	var saved_player_position: Array = data.player_position
	if not _valid_vector_data(saved_player_position):
		reset_defaults()
		return false
	player_position = Vector3(float(saved_player_position[0]), float(saved_player_position[1]), float(saved_player_position[2]))
	runtime_location = String(data.runtime_location)
	vehicle_parked = bool(data.vehicle_parked)
	vehicle_door_open = bool(data.vehicle_door_open)
	door_waiting_for_close = bool(data.door_waiting_for_close)
	if runtime_location not in VALID_RUNTIME_LOCATIONS or not _valid_world_position(vehicle_position) or not _valid_world_position(player_position):
		reset_defaults()
		return false
	if runtime_location == "IN_VEHICLE":
		# A process-level reload resumes at one deterministic endpoint: fully
		# seated, never midway through an entry/exit animation.
		vehicle_door_open = false
		door_waiting_for_close = false
	elif door_waiting_for_close and not vehicle_door_open:
		reset_defaults()
		return false
	if route_phase not in VALID_ROUTE_PHASES or package_status not in VALID_PACKAGE_STATUSES:
		reset_defaults()
		return false
	if route_phase == "NO_ROUTE":
		route_id = ""
		route_order.clear()
		stops.clear()
		packages.clear()
		active_stop_index = 0
		current_stop_id = ""
		gps_target_id = ""
		gps_target_address = ""
		package_status = "ASSIGNED"
		stop_status = "PENDING"
		delivery_reward_claimed = false
		route_bonus_claimed = false
		expenses_claimed = false
		fuel_expense = 0
		maintenance_expense = 0
		penalty_expense = 0
		gross_earnings = 0
		net_earnings = 0
		route_start_credits = 0
	elif route_id != String(ROUTE_OFFER.route_id):
		reset_defaults()
		return false
	if route_phase != "NO_ROUTE" and not _validate_route_records():
		reset_defaults()
		return false
	if route_phase == "ROUTE_COMPLETE":
		if not route_bonus_claimed or not expenses_claimed or not delivery_reward_claimed:
			reset_defaults()
			return false
		var summary := earnings_summary()
		if int(summary.net) != int(summary.gross) - int(summary.fuel) - int(summary.maintenance) - int(summary.penalties):
			reset_defaults()
			return false
	elif route_bonus_claimed or expenses_claimed or delivery_reward_claimed:
		reset_defaults()
		return false
	delivery_earnings = gross_earnings
	var deducted_expenses := fuel_expense + maintenance_expense + penalty_expense if expenses_claimed else 0
	if route_phase != "NO_ROUTE" and credits != route_start_credits + gross_earnings - deducted_expenses:
		reset_defaults()
		return false
	_sync_legacy_status()
	if encounter_resolved:
		if encounter_outcome not in VALID_OUTCOMES:
			reset_defaults()
			return false
		# A resolved encounter is always settled, even if an older/tampered save
		# omitted its claim flag. Repair toward no duplicate payout.
		encounter_reward_claimed = true
	else:
		encounter_outcome = ""
		encounter_reward_claimed = false
	fight_active = false
	return true

func _validate_route_records() -> bool:
	if route_order.size() != STOP_DEFINITIONS.size() or stops.size() != STOP_DEFINITIONS.size() or packages.size() != STOP_DEFINITIONS.size():
		return false
	var expected_ids: Array[String] = []
	for definition in STOP_DEFINITIONS:
		expected_ids.append(String(definition.stop_id))
	var sorted_order := route_order.duplicate()
	var sorted_expected := expected_ids.duplicate()
	sorted_order.sort()
	sorted_expected.sort()
	if sorted_order != sorted_expected or active_stop_index < 0 or active_stop_index >= route_order.size():
		return false
	if current_stop_id != route_order[active_stop_index] or not stops.has(current_stop_id):
		return false
	if route_phase == "RETURN_PENDING":
		if gps_target_id != "WAREHOUSE_RETURN" or gps_target_address != "Willowbrook Distribution Warehouse": return false
	elif gps_target_id != current_stop_id or gps_target_address != String(stops[current_stop_id].get("address", "")):
		return false
	var settled_count := 0
	var calculated_gross := 0
	for definition in STOP_DEFINITIONS:
		var stop_id := String(definition.stop_id)
		var tracking_id := String(definition.tracking_id)
		if not stops.has(stop_id) or not packages.has(tracking_id):
			return false
		var stop = stops[stop_id]
		var package = packages[tracking_id]
		if stop is not Dictionary or package is not Dictionary:
			return false
		if String(stop.get("tracking_id", "")) != tracking_id or String(package.get("stop_id", "")) != stop_id:
			return false
		if String(stop.get("address", "")) != String(definition.address) or int(stop.get("payout", -1)) != int(definition.payout):
			return false
		if not is_equal_approx(float(stop.get("miles", -1.0)), float(definition.miles)) or int(stop.get("minutes", -1)) != int(definition.minutes):
			return false
		if String(stop.get("archetype", "")) != String(definition.archetype) or String(stop.get("confirmation", "")) != String(definition.confirmation) or String(stop.get("placement_rule", "")) != String(definition.placement_rule):
			return false
		if stop.get("map_position", []) != definition.map_position:
			return false
		if String(package.get("dimensions", "")) != String(definition.package_size) or not is_equal_approx(float(package.get("weight_lb", -1.0)), float(definition.weight_lb)) or bool(package.get("heavy_handling_required", false)) != (String(definition.package_size) == "oversized"):
			return false
		if String(stop.get("status", "")) not in ["PENDING", "ARRIVED", "DELIVERED", "UNDELIVERABLE", "RETURNED"] or String(package.get("status", "")) not in VALID_PACKAGE_STATUSES:
			return false
		var claimed := bool(stop.get("reward_claimed", false))
		if String(stop.status) == "DELIVERED":
			if String(package.status) != "DELIVERED" or not claimed:
				return false
			settled_count += 1
			calculated_gross += int(stop.get("payout", 0))
		elif String(stop.status) == "RETURNED":
			if String(package.status) != "RETURNED" or not claimed:
				return false
			settled_count += 1
		elif String(stop.status) == "UNDELIVERABLE":
			if String(package.status) != "RETURN_REQUIRED" or not claimed:
				return false
		elif claimed or String(package.status) == "DELIVERED":
			return false
	if settled_count != active_stop_index + (1 if route_phase == "ROUTE_COMPLETE" else 0):
		return false
	if route_phase == "ROUTE_COMPLETE":
		calculated_gross += ROUTE_COMPLETION_BONUS
	if gross_earnings != calculated_gross:
		return false
	var animal_status := String(stops["WB-05"].status)
	var expected_penalty := 10 if animal_status in ["UNDELIVERABLE", "RETURNED"] else 0
	if penalty_expense != expected_penalty:
		return false
	if route_phase == "ROUTE_COMPLETE":
		if fuel_expense != BASE_FUEL_EXPENSE or maintenance_expense != BASE_MAINTENANCE_EXPENSE:
			return false
	elif fuel_expense != 0 or maintenance_expense != 0 or expenses_claimed or net_earnings != 0:
		return false
	var active_stop: Dictionary = stops[current_stop_id]
	var active_package: Dictionary = packages[String(active_stop.tracking_id)]
	match route_phase:
		"ROUTE_ACCEPTED":
			if not _all_packages_have_status("ASSIGNED") or String(active_stop.status) != "PENDING": return false
		"SCANNING":
			for package in packages.values():
				if String(package.status) not in ["ASSIGNED", "SCANNED"]: return false
		"LOADED", "DRIVING":
			if String(active_package.status) != "LOADED" or String(active_stop.status) != "PENDING": return false
		"AT_STOP":
			if String(active_package.status) != "LOADED" or String(active_stop.status) != "ARRIVED": return false
		"PACKAGE_RETRIEVED":
			if String(active_package.status) != "RETRIEVED" or String(active_stop.status) != "ARRIVED": return false
		"PLACED":
			if String(active_package.status) != "PLACED" or String(active_stop.status) != "ARRIVED": return false
		"RETURN_PENDING":
			if String(active_package.status) != "RETURN_REQUIRED" or String(active_stop.status) != "UNDELIVERABLE": return false
		"ROUTE_COMPLETE":
			if String(active_package.status) not in ["DELIVERED", "RETURNED"] or String(active_stop.status) not in ["DELIVERED", "RETURNED"]: return false
	return true

func _is_integer_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_equal_approx(float(value), floor(float(value)))

func _valid_vector_data(value: Array) -> bool:
	return value.size() == 3 and value.all(func(component): return typeof(component) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(component)))

func _valid_world_position(value: Vector3) -> bool:
	return value.is_finite() and absf(value.x) <= 10000.0 and absf(value.y) <= 10000.0 and absf(value.z) <= 10000.0

func save_game(path := SAVE_PATH) -> bool:
	var temp_path: String = path + ".tmp"
	var backup_path: String = path + ".bak"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dictionary()))
	file.flush()
	if file.get_error() != OK:
		file.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		return false
	file.close()
	var absolute_path := ProjectSettings.globalize_path(path)
	var absolute_temp := ProjectSettings.globalize_path(temp_path)
	var absolute_backup := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup)
	if FileAccess.file_exists(path) and DirAccess.rename_absolute(absolute_path, absolute_backup) != OK:
		DirAccess.remove_absolute(absolute_temp)
		return false
	if DirAccess.rename_absolute(absolute_temp, absolute_path) != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup, absolute_path)
		return false
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup)
	return true

func load_game(path := SAVE_PATH) -> bool:
	reset_defaults()
	for candidate in [path, path + ".bak", path + ".tmp"]:
		var parsed := _read_save_dictionary(candidate)
		if parsed.is_empty():
			continue
		if int(parsed.get("schema_version", -1)) in [2, 3, 4, 5]:
			parsed = _migrate_legacy_schema(parsed)
		if apply_dictionary(parsed):
			if candidate != path:
				# A valid interrupted-save artifact is promoted back to the primary
				# path. Failure to promote does not discard the recovered session.
				save_game(path)
			return true
	return false

func _read_save_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or json.data is not Dictionary:
		return {}
	return (json.data as Dictionary).duplicate(true)

func _migrate_legacy_schema(data: Dictionary) -> Dictionary:
	var migrated := data.duplicate(true)
	var source_schema := int(migrated.get("schema_version", -1))
	migrated.schema_version = SCHEMA_VERSION
	if source_schema == 5:
		# Schema 5 already contains the complete five-stop route/economy model.
		# Preserve it verbatim and add only the runtime continuity fields introduced
		# by schema 6 so an in-progress route is not silently discarded.
		migrated.player_position = [DEFAULT_PLAYER_POSITION.x, DEFAULT_PLAYER_POSITION.y, DEFAULT_PLAYER_POSITION.z]
		migrated.runtime_location = "ON_FOOT"
		migrated.vehicle_parked = true
		migrated.vehicle_door_open = false
		migrated.door_waiting_for_close = false
		return migrated
	migrated.route_phase = "NO_ROUTE"
	migrated.route_id = ""
	migrated.package_status = "ASSIGNED"
	migrated.stop_status = "PENDING"
	migrated.delivery_reward_claimed = false
	migrated.delivery_earnings = 0
	migrated.route_order = []
	migrated.stops = {}
	migrated.packages = {}
	migrated.active_stop_index = 0
	migrated.current_stop_id = ""
	migrated.gps_target_id = ""
	migrated.gps_target_address = ""
	migrated.route_bonus_claimed = false
	migrated.expenses_claimed = false
	migrated.fuel_expense = 0
	migrated.maintenance_expense = 0
	migrated.penalty_expense = 0
	migrated.gross_earnings = 0
	migrated.net_earnings = 0
	migrated.route_start_credits = 0
	migrated.vehicle_position = [0.0, 0.0, 0.0]
	migrated.vehicle_rotation_y = 0.0
	migrated.player_position = [DEFAULT_PLAYER_POSITION.x, DEFAULT_PLAYER_POSITION.y, DEFAULT_PLAYER_POSITION.z]
	migrated.runtime_location = "ON_FOOT"
	migrated.vehicle_parked = true
	migrated.vehicle_door_open = false
	migrated.door_waiting_for_close = false
	return migrated
