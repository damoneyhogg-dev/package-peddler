extends SceneTree

const CourierAppearance = preload("res://src/courier_appearance.gd")

func _initialize() -> void:
	var original := CourierAppearance.new()
	original.skin_tone_index = 4
	original.shirt_color = Color("24364b")
	original.pants_color = Color("715238")
	original.vest_color = Color("ff7a18")
	original.vest_style_index = 4
	original.age = 65
	original.body_build_index = 3

	var restored := CourierAppearance.from_save_data(original.to_save_data())
	var passed := (
		restored.skin_tone_index == 4
		and restored.shirt_color.is_equal_approx(original.shirt_color)
		and restored.pants_color.is_equal_approx(original.pants_color)
		and restored.vest_color.is_equal_approx(original.vest_color)
		and restored.vest_style() == "blue_gray_zip_courier"
		and restored.age == 65
		and restored.body_build() == "dad_bod"
	)
	var repaired := CourierAppearance.from_save_data({"age": 99, "body_build_index": 99, "vest_style_index": 99})
	passed = passed and repaired.age == 65 and repaired.body_build() == "plus_size" and repaired.vest_style() == "blue_gray_zip_courier"

	if passed:
		print("APPEARANCE_CONTRACT_PASS skin_tones=%d vest_styles=%d body_builds=%d ages=21-65" % [CourierAppearance.SKIN_TONES.size(), CourierAppearance.VEST_STYLES.size(), CourierAppearance.BODY_BUILDS.size()])
		quit(0)
	else:
		push_error("Appearance profile did not round-trip through save data")
		quit(1)
