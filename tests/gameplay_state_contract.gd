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
	var state := GameplayState.new()
	_expect(state.select_vehicle(1), "Second fictional vehicle cannot be selected")
	_expect(state.selected_vehicle == "Cargo Comet", "Vehicle selection did not update")
	state.combat_enabled = false
	_expect(not state.begin_fight(), "Fight started while combat was disabled")
	var peaceful := state.resolve_encounter("deescalated")
	_expect(peaceful.reward == 35 and state.credits == 35, "De-escalation reward or consequence is wrong")
	var duplicate := state.resolve_encounter("deescalated")
	_expect(duplicate.reward == 0 and state.credits == 35, "Resolved encounter paid twice")
	_expect(state.save_game(TEST_SAVE), "State could not be saved")

	var loaded := GameplayState.new()
	_expect(loaded.load_game(TEST_SAVE), "State could not be reloaded")
	_expect(loaded.selected_vehicle == "Cargo Comet", "Vehicle did not persist")
	_expect(not loaded.combat_enabled, "Combat accessibility option did not persist")
	_expect(loaded.encounter_resolved and loaded.encounter_reward_claimed, "Encounter completion did not persist")
	var reload_duplicate := loaded.resolve_encounter("deescalated")
	_expect(reload_duplicate.reward == 0 and loaded.credits == 35, "Reload allowed duplicate reward")

	var fight := GameplayState.new()
	_expect(fight.begin_fight(), "Enabled fight could not start")
	var turns := 0
	while not fight.encounter_resolved and turns < 8:
		fight.combat_turn("heavy")
		turns += 1
	_expect(fight.encounter_outcome == "win", "Combat did not reach a knockdown win")
	_expect(fight.player_health > 0 and fight.rival_health == 0, "Combat stop condition is wrong")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))

	if failures.is_empty():
		print("GAMEPLAY_STATE_CONTRACT_PASS vehicles=2 combat_toggle=true knockdown=true persistence=true idempotent_reward=true")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("GAMEPLAY_STATE_CONTRACT_FAIL count=%d" % failures.size())
		quit(1)
