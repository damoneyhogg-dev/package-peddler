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
	_cleanup_test_save()
	if failures.is_empty():
		print("GAMEPLAY_STATE_CONTRACT_PASS vehicles=2 phases=true peaceful=2 combat_actions=4 win_loss_retreat=true persistence=true validation=true idempotent_reward=true")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("GAMEPLAY_STATE_CONTRACT_FAIL count=%d" % failures.size())
		quit(1)

func _test_vehicle_and_phase_guards() -> void:
	var state := GameplayState.new()
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
	state.combat_enabled = false
	state.resolve_encounter("deescalated")
	_expect(state.save_game(TEST_SAVE), "State could not be saved")
	_expect(not FileAccess.file_exists(TEST_SAVE + ".tmp") and not FileAccess.file_exists(TEST_SAVE + ".bak"), "Save left temporary replacement files")
	var loaded := GameplayState.new()
	_expect(loaded.load_game(TEST_SAVE), "State could not be reloaded")
	_expect(loaded.selected_vehicle == "Cargo Comet" and not loaded.combat_enabled, "Vehicle or accessibility option did not persist")
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
	_write_json(TEST_SAVE, {
		"schema_version": GameplayState.SCHEMA_VERSION,
		"selected_vehicle": "Unknown Vehicle", "combat_enabled": true,
		"encounter_resolved": false, "encounter_outcome": "win", "encounter_reward_claimed": true,
		"credits": -50, "reputation": 99999, "route_minutes": -8
	})
	var repaired := GameplayState.new()
	_expect(repaired.load_game(TEST_SAVE), "Repairable semantic save was rejected")
	_expect(repaired.selected_vehicle == "Parcel Finch" and repaired.credits == 0, "Vehicle/credit repair failed")
	_expect(repaired.reputation == 1000 and repaired.route_minutes == 0, "Numeric clamping failed")
	_expect(not repaired.encounter_resolved and repaired.encounter_outcome == "" and not repaired.encounter_reward_claimed, "Unresolved encounter invariants were not repaired")
	_write_json(TEST_SAVE, {
		"schema_version": GameplayState.SCHEMA_VERSION,
		"selected_vehicle": "Parcel Finch", "combat_enabled": true,
		"encounter_resolved": true, "encounter_outcome": "invalid", "encounter_reward_claimed": false,
		"credits": 50, "reputation": 0, "route_minutes": 0
	})
	var invalid_semantics := GameplayState.new()
	_expect(not invalid_semantics.load_game(TEST_SAVE) and not invalid_semantics.encounter_resolved and invalid_semantics.credits == 0, "Invalid resolved outcome did not reset safely")
	var repaired_claim := GameplayState.new()
	var settled := repaired.to_dictionary()
	settled.encounter_resolved = true
	settled.encounter_outcome = "left"
	settled.encounter_reward_claimed = false
	_expect(repaired_claim.apply_dictionary(settled) and repaired_claim.encounter_reward_claimed, "Resolved reward claim invariant was not repaired")

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
