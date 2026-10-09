extends SceneTree

const CourierAppearance = preload("res://src/courier_appearance.gd")

func _initialize() -> void:
	var original := CourierAppearance.new()
	original.skin_tone_index = 4
	original.shirt_color = Color("24364b")
	original.pants_color = Color("715238")
	original.vest_color = Color("ff7a18")
	original.vest_style_index = 2

	var restored := CourierAppearance.from_save_data(original.to_save_data())
	var passed := (
		restored.skin_tone_index == 4
		and restored.shirt_color.is_equal_approx(original.shirt_color)
		and restored.pants_color.is_equal_approx(original.pants_color)
		and restored.vest_color.is_equal_approx(original.vest_color)
		and restored.vest_style() == "lightweight_crossback"
	)

	if passed:
		print("APPEARANCE_CONTRACT_PASS skin_tones=%d vest_styles=%d" % [CourierAppearance.SKIN_TONES.size(), CourierAppearance.VEST_STYLES.size()])
		quit(0)
	else:
		push_error("Appearance profile did not round-trip through save data")
		quit(1)

