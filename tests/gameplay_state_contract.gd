extends SceneTree

const GameplayState = preload("res://src/gameplay_state.gd")
const TEST_SAVE := "user://package_peddler_contract_save.json"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	_cleanup_test_save()
	_test_vehicle_and_phase_guards()
	_test_peaceful_outcomes()
	_test_combat_actions_and_outcomes()
	_test_persistence_and_idempotency()
	_test_save_validation_and_repair()
	_test_route_save_guards_and_migration()
	_cleanup_test_save()
	if failures.is_empty():
		print("GAMEPLAY_STATE_CONTRACT_PASS drivers=4 vehicles=2 phases=true peaceful=2 combat_actions=4 win_loss_retreat=true persistence=true migration=true nested_tamper_rejected=true economy_tamper_rejected=true idempotent_reward=true")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("GAMEPLAY_STATE_CONTRACT_FAIL count=%d" % failures.size())
		quit(1)

func _test_vehicle_and_phase_guards() -> void:
	var state := GameplayState.new()
	_expect(state.select_driver(3) and state.selected_driver == "Alex Rivera", "Fourth driver cannot be selected")
	_expect(not state.select_driver(4), "Out-of-range driver selection was accepted")
	_expect(state.select_vehicle(1) and state.selected_vehicle == "Cargo Comet", "Second fictional vehicle cannot be selected")
	_expect(not state.combat_turn("light").accepted, "Combat action was accepted without an active fight")
	state.combat_enabled = false
	_expect(not state.begin_fight(), "Fight started while combat was disabled")
	state.combat_enabled = true
	_expect(state.begin_fight() and state.fight_active, "Enabled fight did not enter active phase")
	state.combat_enabled = false
	_expect(not state.combat_turn("light").accepted, "Combat action was accepted after combat was disabled")
	var invalid := GameplayState.new()
	_expect(not invalid.resolve_encounter("weapon_win").accepted and not invalid.encounter_resolved, "Invalid outcome resolved the encounter")
	_expect(not invalid.resolve_encounter("win").accepted and not invalid.encounter_resolved, "Win resolved without an active fight")

func _test_peaceful_outcomes() -> void:
	var deescalated := GameplayState.new()
	var peaceful := deescalated.resolve_encounter("deescalated")
	_expect(peaceful.accepted and peaceful.reward == 35, "De-escalation did not resolve with its reward")
	_expect(deescalated.credits == 35 and deescalated.reputation == 2 and deescalated.route_minutes == 4, "De-escalation consequences are wrong")
	var left := GameplayState.new()
	var leave_result := left.resolve_encounter("left")
	_expect(leave_result.accepted and leave_result.reward == 0, "Leave path was not accepted")
	_expect(left.reputation == -1 and left.route_minutes == 8, "Leave consequences are wrong")

func _test_combat_actions_and_outcomes() -> void:
	var light := GameplayState.new()
	light.begin_fight()
	var light_result := light.combat_turn("light")
	_expect(light_result.accepted and light.rival_health == 78 and light.stamina == 93, "Light action did not spend stamina and damage the rival")
	var block := GameplayState.new()
	block.begin_fight()
	var block_result := block.combat_turn("block")
	_expect(block_result.accepted and block.player_health == 97 and block.fight_active, "Block action did not mitigate the counter")
	var dodge := GameplayState.new()
	dodge.begin_fight()
	var dodge_result := dodge.combat_turn("dodge")
	_expect(dodge_result.accepted and dodge.player_health == 100 and dodge.stamina == 88, "Dodge did not spend stamina and avoid damage")
	var exhausted := GameplayState.new()
	exhausted.begin_fight()
	exhausted.stamina = 0
	var exhaustion_result := exhausted.combat_turn("heavy")
	_expect(exhaustion_result.accepted and exhausted.stamina == 20 and exhausted.rival_health == 100, "Stamina exhaustion did not force recovery")
	var win := GameplayState.new()
	win.begin_fight()
	var turns := 0
	while not win.encounter_resolved and turns < 8:
		win.combat_turn("heavy")
		turns += 1
	_expect(win.encounter_outcome == "win" and not win.fight_active, "Combat did not reach a stopped knockdown win")
	_expect(win.player_health > 0 and win.rival_health == 0, "Win stop condition is wrong")
	var loss := GameplayState.new()
	loss.begin_fight()
	loss.player_health = 3
	loss.combat_turn("block")
	_expect(loss.encounter_outcome == "loss" and loss.player_health == 0 and not loss.fight_active, "Combat did not reach a stopped knockdown loss")
	var retreat := GameplayState.new()
	retreat.begin_fight()
	var retreat_result := retreat.retreat_from_fight()
	_expect(retreat_result.accepted and retreat.encounter_outcome == "left" and not retreat.fight_active, "Active-fight retreat did not resolve through leave")

func _test_persistence_and_idempotency() -> void:
	var state := GameplayState.new()
	state.select_vehicle(1)
	state.select_driver(2)
	state.combat_enabled = false
	state.resolve_encounter("deescalated")
	_expect(state.save_game(TEST_SAVE), "State could not be saved")
	_expect(not FileAccess.file_exists(TEST_SAVE + ".tmp") and not FileAccess.file_exists(TEST_SAVE + ".bak"), "Save left temporary replacement files")
	var loaded := GameplayState.new()
	_expect(loaded.load_game(TEST_SAVE), "State could not be reloaded")
	_expect(loaded.selected_vehicle == "Cargo Comet" and loaded.selected_driver == "Jordan Reed" and not loaded.combat_enabled, "Driver, vehicle, or accessibility option did not persist")
	_expect(loaded.encounter_resolved and loaded.encounter_reward_claimed, "Encounter settlement did not persist")
	var duplicate := loaded.resolve_encounter("deescalated")
	_expect(not duplicate.accepted and duplicate.reward == 0 and loaded.credits == 35, "Reload allowed duplicate reward")

func _test_save_validation_and_repair() -> void:
	_write_text(TEST_SAVE, "{ definitely not json")
	var malformed := GameplayState.new()
	malformed.credits = 999
	_expect(not malformed.load_game(TEST_SAVE) and malformed.credits == 0, "Malformed JSON did not fall back safely")
	_write_json(TEST_SAVE, {"schema_version": 99})
	var wrong_schema := GameplayState.new()
	_expect(not wrong_schema.load_game(TEST_SAVE) and wrong_schema.selected_vehicle == "Parcel Finch", "Wrong schema did not fall back safely")
	var repair_data := GameplayState.new().to_dictionary()
	repair_data.selected_driver = "Unknown Driver"
	repair_data.selected_vehicle = "Unknown Vehicle"
	repair_data.encounter_outcome = "win"
	repair_data.encounter_reward_claimed = true
	repair_data.credits = -50
	repair_data.reputation = 99999
	repair_data.route_minutes = -8
	_write_json(TEST_SAVE, repair_data)
	var repaired := GameplayState.new()
	_expect(repaired.load_game(TEST_SAVE), "Repairable semantic save was rejected")
	_expect(repaired.selected_driver == "Owner Courier" and repaired.selected_vehicle == "Parcel Finch" and repaired.credits == 0, "Driver/vehicle/credit repair failed")
	_expect(repaired.reputation == 1000 and repaired.route_minutes == 0, "Numeric clamping failed")
	_expect(not repaired.encounter_resolved and repaired.encounter_outcome == "" and not repaired.encounter_reward_claimed, "Unresolved encounter invariants were not repaired")
	var invalid_data := GameplayState.new().to_dictionary()
	invalid_data.encounter_resolved = true
	invalid_data.encounter_outcome = "invalid"
	invalid_data.credits = 50
	_write_json(TEST_SAVE, invalid_data)
	var invalid_semantics := GameplayState.new()
	_expect(not invalid_semantics.load_game(TEST_SAVE) and not invalid_semantics.encounter_resolved and invalid_semantics.credits == 0, "Invalid resolved outcome did not reset safely")
	var repaired_claim := GameplayState.new()
	var settled := repaired.to_dictionary()
	settled.encounter_resolved = true
	settled.encounter_outcome = "left"
	settled.encounter_reward_claimed = false
	_expect(repaired_claim.apply_dictionary(settled) and repaired_claim.encounter_reward_claimed, "Resolved reward claim invariant was not repaired")

func _test_route_save_guards_and_migration() -> void:
	var active := GameplayState.new()
	active.accept_route()
	for definition in GameplayState.STOP_DEFINITIONS:
		active.scan_package(String(definition.tracking_id))
	active.load_package()
	active.depart_route()
	var corrupt := active.to_dictionary()
	corrupt.packages[GameplayState.PACKAGE_TRACKING].stop_id = "WB-05"
	var rejected := GameplayState.new()
	_expect(not rejected.apply_dictionary(corrupt) and rejected.route_phase == "NO_ROUTE", "Corrupt nested package ownership was accepted")
	for field in ["payout", "address", "archetype", "confirmation", "placement_rule"]:
		var tampered := active.to_dictionary()
		var stop: Dictionary = tampered.stops["WB-01"]
		stop[field] = 999 if field == "payout" else "TAMPERED"
		tampered.stops["WB-01"] = stop
		var stop_rejected := GameplayState.new()
		_expect(not stop_rejected.apply_dictionary(tampered), "Tampered canonical stop field was accepted: %s" % field)
	var package_tamper := active.to_dictionary()
	package_tamper.packages[GameplayState.PACKAGE_TRACKING].weight_lb = 999.0
	_expect(not GameplayState.new().apply_dictionary(package_tamper), "Tampered package definition was accepted")
	var credit_tamper := active.to_dictionary()
	credit_tamper.credits = int(credit_tamper.credits) + 500
	_expect(not GameplayState.new().apply_dictionary(credit_tamper), "Tampered credits were accepted")
	var expense_tamper := active.to_dictionary()
	expense_tamper.fuel_expense = 999
	_expect(not GameplayState.new().apply_dictionary(expense_tamper), "Tampered active-route expenses were accepted")
	var legacy := GameplayState.new().to_dictionary()
	legacy.schema_version = 3
	legacy.erase("route_order")
	legacy.erase("stops")
	legacy.erase("packages")
	legacy.erase("active_stop_index")
	legacy.erase("current_stop_id")
	legacy.erase("gps_target_id")
	legacy.erase("gps_target_address")
	legacy.erase("route_bonus_claimed")
	legacy.erase("expenses_claimed")
	legacy.erase("fuel_expense")
	legacy.erase("maintenance_expense")
	legacy.erase("penalty_expense")
	legacy.erase("gross_earnings")
	legacy.erase("net_earnings")
	legacy.selected_driver = "Maya Brooks"
	legacy.credits = 123
	_write_json(TEST_SAVE, legacy)
	var migrated := GameplayState.new()
	_expect(migrated.load_game(TEST_SAVE), "Schema-3 save did not migrate")
	_expect(migrated.selected_driver == "Maya Brooks" and migrated.credits == 123 and migrated.route_phase == "NO_ROUTE", "Schema migration did not preserve profile/economy safely")

	var schema_five := active.to_dictionary()
	schema_five.schema_version = 5
	for runtime_field in ["player_position", "runtime_location", "vehicle_parked", "vehicle_door_open", "door_waiting_for_close"]:
		schema_five.erase(runtime_field)
	_write_json(TEST_SAVE, schema_five)
	var migrated_active := GameplayState.new()
	_expect(migrated_active.load_game(TEST_SAVE), "Active schema-5 route did not migrate")
	_expect(migrated_active.route_phase == active.route_phase, "Schema-5 migration lost the active route phase")
	_expect(migrated_active.route_order == active.route_order and migrated_active.stops.size() == active.stops.size() and migrated_active.packages.size() == active.packages.size(), "Schema-5 migration changed route record membership")
	for definition in GameplayState.STOP_DEFINITIONS:
		var stop_id := String(definition.stop_id)
		var tracking_id := String(definition.tracking_id)
		_expect(String(migrated_active.stops[stop_id].status) == String(active.stops[stop_id].status) and bool(migrated_active.stops[stop_id].reward_claimed) == bool(active.stops[stop_id].reward_claimed), "Schema-5 migration changed stop progress: %s" % stop_id)
		_expect(String(migrated_active.packages[tracking_id].status) == String(active.packages[tracking_id].status), "Schema-5 migration changed package progress: %s" % tracking_id)
	_expect(migrated_active.current_stop_id == active.current_stop_id and migrated_active.gps_target_id == active.gps_target_id, "Schema-5 migration changed GPS progress")
	_expect(migrated_active.credits == active.credits and migrated_active.gross_earnings == active.gross_earnings and migrated_active.net_earnings == active.net_earnings, "Schema-5 migration changed route economy")
	_expect(migrated_active.runtime_location == "ON_FOOT" and migrated_active.vehicle_parked, "Schema-5 migration did not supply safe runtime defaults")

func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

func _write_json(path: String, content: Dictionary) -> void:
	_write_text(path, JSON.stringify(content))

func _cleanup_test_save() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = TEST_SAVE + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
