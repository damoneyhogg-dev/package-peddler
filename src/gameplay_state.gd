class_name PackagePeddlerGameplayState
extends RefCounted

const SAVE_PATH := "user://package_peddler_save.json"
const VEHICLES := ["Parcel Finch", "Cargo Comet"]

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

func select_vehicle(index: int) -> bool:
	if index < 0 or index >= VEHICLES.size():
		return false
	selected_vehicle = VEHICLES[index]
	return true

func begin_fight() -> bool:
	if encounter_resolved or not combat_enabled:
		return false
	player_health = 100
	rival_health = 100
	stamina = 100
	return true

func combat_turn(action: String) -> Dictionary:
	if encounter_resolved:
		return {"accepted": false, "message": "This encounter is already resolved."}
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
	if encounter_resolved:
		return {"reward": 0, "message": "Encounter already resolved; no duplicate reward."}
	encounter_resolved = true
	encounter_outcome = outcome
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
	return {"reward": reward, "message": "Encounter resolved: %s." % outcome}

func to_dictionary() -> Dictionary:
	return {
		"selected_vehicle": selected_vehicle,
		"combat_enabled": combat_enabled,
		"encounter_resolved": encounter_resolved,
		"encounter_outcome": encounter_outcome,
		"encounter_reward_claimed": encounter_reward_claimed,
		"credits": credits,
		"reputation": reputation,
		"route_minutes": route_minutes
	}

func apply_dictionary(data: Dictionary) -> void:
	var vehicle := String(data.get("selected_vehicle", VEHICLES[0]))
	selected_vehicle = vehicle if vehicle in VEHICLES else VEHICLES[0]
	combat_enabled = bool(data.get("combat_enabled", true))
	encounter_resolved = bool(data.get("encounter_resolved", false))
	encounter_outcome = String(data.get("encounter_outcome", ""))
	encounter_reward_claimed = bool(data.get("encounter_reward_claimed", false))
	credits = int(data.get("credits", 0))
	reputation = int(data.get("reputation", 0))
	route_minutes = int(data.get("route_minutes", 0))

func save_game(path := SAVE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dictionary()))
	return true

func load_game(path := SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		return false
	apply_dictionary(parsed)
	return true
