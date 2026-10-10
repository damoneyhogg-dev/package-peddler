class_name PackagePeddlerGameplayState
extends RefCounted

const SAVE_PATH := "user://package_peddler_save.json"
const VEHICLES := ["Parcel Finch", "Cargo Comet"]
const SCHEMA_VERSION := 1
const VALID_OUTCOMES := ["deescalated", "left", "win", "loss"]

var selected_vehicle := VEHICLES[0]
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

func reset_defaults() -> void:
	selected_vehicle = VEHICLES[0]
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

func select_vehicle(index: int) -> bool:
	if index < 0 or index >= VEHICLES.size():
		return false
	selected_vehicle = VEHICLES[index]
	return true

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
		"selected_vehicle": selected_vehicle,
		"combat_enabled": combat_enabled,
		"encounter_resolved": encounter_resolved,
		"encounter_outcome": encounter_outcome,
		"encounter_reward_claimed": encounter_reward_claimed,
		"credits": credits,
		"reputation": reputation,
		"route_minutes": route_minutes
	}

func apply_dictionary(data: Dictionary) -> bool:
	reset_defaults()
	var required_types := {
		"selected_vehicle": TYPE_STRING,
		"combat_enabled": TYPE_BOOL,
		"encounter_resolved": TYPE_BOOL,
		"encounter_outcome": TYPE_STRING,
		"encounter_reward_claimed": TYPE_BOOL
	}
	for key in required_types:
		if not data.has(key) or typeof(data[key]) != required_types[key]:
			return false
	for numeric_key in ["schema_version", "credits", "reputation", "route_minutes"]:
		if not data.has(numeric_key) or not _is_integer_number(data[numeric_key]):
			return false
	if int(data["schema_version"]) != SCHEMA_VERSION:
		return false
	var vehicle := String(data.selected_vehicle)
	selected_vehicle = vehicle if vehicle in VEHICLES else VEHICLES[0]
	combat_enabled = bool(data.combat_enabled)
	encounter_resolved = bool(data.encounter_resolved)
	encounter_outcome = String(data.encounter_outcome)
	encounter_reward_claimed = bool(data.encounter_reward_claimed)
	credits = clampi(int(data.credits), 0, 1000000000)
	reputation = clampi(int(data.reputation), -1000, 1000)
	route_minutes = clampi(int(data.route_minutes), 0, 1000000)
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
	return apply_dictionary(parsed)
