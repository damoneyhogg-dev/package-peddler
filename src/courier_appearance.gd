class_name CourierAppearance
extends Resource

const VEST_STYLES := [
	"classic_reflective",
	"utility_pocket",
	"lightweight_crossback",
	"longline_mesh_orange_stripe",
	"blue_gray_zip_courier"
]
const BODY_BUILDS := ["slim", "average", "athletic", "dad_bod", "plus_size"]
const SKIN_TONES := [
	Color("4a2618"), Color("6b3d25"), Color("8b5a3c"),
	Color("b87956"), Color("d6a17b"), Color("edc4a5")
]

@export_range(0, 5, 1) var skin_tone_index := 1
@export var shirt_color := Color("111315")
@export var pants_color := Color("52728c")
@export var vest_color := Color("d9ff2f")
@export_range(0, 4, 1) var vest_style_index := 0
@export_range(21, 65, 1) var age := 30
@export_range(0, 4, 1) var body_build_index := 1

func skin_color() -> Color:
	return SKIN_TONES[clampi(skin_tone_index, 0, SKIN_TONES.size() - 1)]

func vest_style() -> String:
	return VEST_STYLES[clampi(vest_style_index, 0, VEST_STYLES.size() - 1)]

func body_build() -> String:
	return BODY_BUILDS[clampi(body_build_index, 0, BODY_BUILDS.size() - 1)]

func to_save_data() -> Dictionary:
	return {
		"skin_tone_index": skin_tone_index,
		"shirt_color": shirt_color.to_html(),
		"pants_color": pants_color.to_html(),
		"vest_color": vest_color.to_html(),
		"vest_style_index": vest_style_index,
		"age": age,
		"body_build_index": body_build_index
	}

static func from_save_data(data: Dictionary) -> CourierAppearance:
	var appearance := CourierAppearance.new()
	appearance.skin_tone_index = clampi(int(data.get("skin_tone_index", 1)), 0, SKIN_TONES.size() - 1)
	appearance.shirt_color = Color.from_string(str(data.get("shirt_color", "111315")), Color("111315"))
	appearance.pants_color = Color.from_string(str(data.get("pants_color", "52728c")), Color("52728c"))
	appearance.vest_color = Color.from_string(str(data.get("vest_color", "d9ff2f")), Color("d9ff2f"))
	appearance.vest_style_index = clampi(int(data.get("vest_style_index", 0)), 0, VEST_STYLES.size() - 1)
	appearance.age = clampi(int(data.get("age", 30)), 21, 65)
	appearance.body_build_index = clampi(int(data.get("body_build_index", 1)), 0, BODY_BUILDS.size() - 1)
	return appearance
