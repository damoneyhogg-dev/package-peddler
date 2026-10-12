class_name PackagePeddlerGameplayState
extends RefCounted

const SAVE_PATH := "user://package_peddler_save.json"
const VEHICLES := ["Parcel Finch", "Cargo Comet"]
const DRIVERS := ["Owner Courier", "Maya Brooks", "Jordan Reed", "Alex Rivera"]
const SCHEMA_VERSION := 3
const VALID_OUTCOMES := ["deescalated", "left", "win", "loss"]
const ROUTE_OFFER := {
	"route_id": "WB-ONE-01",
	"area": "Willowbrook Commons",
	"payout": 85,
	"miles": 2.4,
	"estimated_minutes": 18,
	"stops": 1
}
const PACKAGE_TRACKING := "PP-1047-ONE"
const DELIVERY_ADDRESS := "1047 Juniper Lane"
const VALID_ROUTE_PHASES := ["NO_ROUTE", "ROUTE_ACCEPTED", "SCANNING", "LOADED", "DRIVING", "AT_STOP", "PACKAGE_RETRIEVED", "PLACED", "ROUTE_COMPLETE"]
const VALID_PACKAGE_STATUSES := ["ASSIGNED", "SCANNED", "LOADED", "RETRIEVED", "PLACED", "DELIVERED"]

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
var vehicle_position := Vector3.ZERO
var vehicle_rotation_y := 0.0

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
	vehicle_position = Vector3.ZERO
	vehicle_rotation_y = 0.0

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
	route_phase = "ROUTE_ACCEPTED"
	package_status = "ASSIGNED"
	stop_status = "PENDING"
	return {"accepted": true, "message": "Route %s accepted." % route_id}

func scan_package(tracking_id: String) -> Dictionary:
	if route_phase not in ["ROUTE_ACCEPTED", "SCANNING"]:
		return {"accepted": false, "message": "Accept a route before scanning."}
	if tracking_id != PACKAGE_TRACKING:
		return {"accepted": false, "message": "Wrong package for this route."}
	if package_status != "ASSIGNED":
		return {"accepted": false, "message": "Package already scanned."}
	package_status = "SCANNED"
	route_phase = "SCANNING"
	return {"accepted": true, "message": "Package %s scanned." % tracking_id}

func load_package() -> Dictionary:
	if route_phase != "SCANNING" or package_status != "SCANNED":
		return {"accepted": false, "message": "Only the scanned route package can be loaded."}
	package_status = "LOADED"
	route_phase = "LOADED"
	return {"accepted": true, "message": "Package loaded by stop order."}

func depart_route() -> Dictionary:
	if route_phase != "LOADED" or package_status != "LOADED":
		return {"accepted": false, "message": "Scan and load the package before departure."}
	route_phase = "DRIVING"
	return {"accepted": true, "message": "Route departed. Drive to %s." % DELIVERY_ADDRESS}

func arrive_at_stop() -> Dictionary:
	if route_phase != "DRIVING":
		return {"accepted": false, "message": "This is not the active delivery stop."}
	route_phase = "AT_STOP"
	stop_status = "ARRIVED"
	return {"accepted": true, "message": "Arrived at %s. Retrieve the package." % DELIVERY_ADDRESS}

func retrieve_package() -> Dictionary:
	if route_phase != "AT_STOP" or package_status != "LOADED":
		return {"accepted": false, "message": "The assigned loaded package is not ready to retrieve."}
	package_status = "RETRIEVED"
	route_phase = "PACKAGE_RETRIEVED"
	return {"accepted": true, "message": "Correct package retrieved."}

func place_package() -> Dictionary:
	if route_phase != "PACKAGE_RETRIEVED" or package_status != "RETRIEVED":
		return {"accepted": false, "message": "Retrieve the correct package before placement."}
	package_status = "PLACED"
	route_phase = "PLACED"
	return {"accepted": true, "message": "Package placed in the valid delivery zone."}

func confirm_delivery() -> Dictionary:
	if route_phase == "ROUTE_COMPLETE":
		return {"accepted": false, "reward": 0, "message": "Delivery already confirmed; no duplicate payout."}
	if route_phase != "PLACED" or package_status != "PLACED":
		return {"accepted": false, "reward": 0, "message": "Placement is required before confirmation."}
	package_status = "DELIVERED"
	stop_status = "DELIVERED"
	route_phase = "ROUTE_COMPLETE"
	var reward := 0
	if not delivery_reward_claimed:
		reward = int(ROUTE_OFFER.payout)
		delivery_reward_claimed = true
		delivery_earnings += reward
		credits += reward
	return {"accepted": true, "reward": reward, "message": "Delivery confirmed at %s." % DELIVERY_ADDRESS}

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
		"vehicle_position": [vehicle_position.x, vehicle_position.y, vehicle_position.z],
		"vehicle_rotation_y": vehicle_rotation_y
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
		"vehicle_position": TYPE_ARRAY
	}
	for key in required_types:
		if not data.has(key) or typeof(data[key]) != required_types[key]:
			return false
	for numeric_key in ["schema_version", "credits", "reputation", "route_minutes", "delivery_earnings"]:
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
	var saved_position: Array = data.vehicle_position
	if saved_position.size() != 3 or not saved_position.all(func(value): return typeof(value) in [TYPE_INT, TYPE_FLOAT]):
		reset_defaults()
		return false
	vehicle_position = Vector3(float(saved_position[0]), float(saved_position[1]), float(saved_position[2]))
	vehicle_rotation_y = float(data.vehicle_rotation_y)
	if route_phase not in VALID_ROUTE_PHASES or package_status not in VALID_PACKAGE_STATUSES:
		reset_defaults()
		return false
	if route_phase == "NO_ROUTE":
		route_id = ""
		package_status = "ASSIGNED"
		stop_status = "PENDING"
		delivery_reward_claimed = false
	elif route_id != String(ROUTE_OFFER.route_id):
		reset_defaults()
		return false
	var expected_package_by_phase := {
		"ROUTE_ACCEPTED": "ASSIGNED",
		"SCANNING": "SCANNED",
		"LOADED": "LOADED",
		"DRIVING": "LOADED",
		"AT_STOP": "LOADED",
		"PACKAGE_RETRIEVED": "RETRIEVED",
		"PLACED": "PLACED",
		"ROUTE_COMPLETE": "DELIVERED"
	}
	if expected_package_by_phase.has(route_phase) and package_status != expected_package_by_phase[route_phase]:
		reset_defaults()
		return false
	if route_phase != "ROUTE_COMPLETE" and (delivery_reward_claimed or delivery_earnings != 0):
		reset_defaults()
		return false
	if route_phase == "ROUTE_COMPLETE":
		if package_status != "DELIVERED" or stop_status != "DELIVERED":
			reset_defaults()
			return false
		delivery_reward_claimed = true
		delivery_earnings = int(ROUTE_OFFER.payout)
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

func _is_integer_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_equal_approx(float(value), floor(float(value)))

func save_game(path := SAVE_PATH) -> bool:
	var temp_path: String = path + ".tmp"
	var backup_path: String = path + ".bak"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dictionary()))
	file.flush()
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
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return false
	var parsed = json.data
	if parsed is not Dictionary:
		return false
	if int(parsed.get("schema_version", -1)) == 2:
		parsed = _migrate_schema_2(parsed)
	return apply_dictionary(parsed)

func _migrate_schema_2(data: Dictionary) -> Dictionary:
	var migrated := data.duplicate(true)
	migrated.schema_version = SCHEMA_VERSION
	migrated.route_phase = "NO_ROUTE"
	migrated.route_id = ""
	migrated.package_status = "ASSIGNED"
	migrated.stop_status = "PENDING"
	migrated.delivery_reward_claimed = false
	migrated.delivery_earnings = 0
	migrated.vehicle_position = [0.0, 0.0, 0.0]
	migrated.vehicle_rotation_y = 0.0
	return migrated
