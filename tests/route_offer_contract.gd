extends SceneTree

const GameplayState = preload("res://src/gameplay_state.gd")

func _init() -> void:
	var offer: Dictionary = GameplayState.ROUTE_OFFER
	var required := ["area", "stops", "miles", "estimated_minutes", "time_limit_minutes", "difficulty", "package_types", "base_pay", "payout"]
	for key in required:
		assert(offer.has(key), "route offer missing %s" % key)
	assert(int(offer.stops) == 5)
	assert(float(offer.miles) > 0.0)
	assert(int(offer.time_limit_minutes) > int(offer.estimated_minutes))
	assert(String(offer.difficulty) in ["Easy", "Moderate", "Hard"])
	assert(Array(offer.package_types).has("oversized"))
	assert(int(offer.base_pay) == int(offer.payout))
	print("ROUTE_OFFER_CONTRACT_PASS details=true package_types=%d time_limit=%d difficulty=%s" % [offer.package_types.size(), offer.time_limit_minutes, offer.difficulty])
	quit(0)
