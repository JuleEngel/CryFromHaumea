class_name Credits
extends Control

const bold = preload("res://ui_scenes/fonts/NovaSquare-Regular.ttf")
const light = preload("res://ui_scenes/fonts/NovaSquare-Regular.ttf")
const regular = preload("res://ui_scenes/fonts/NovaSquare-Regular.ttf")

const GAME_TITLE = "Cry from Haumea"
const THANKS: String = "Danke fürs Spielen!"

var music_credit_entries: Array[LicensedCreditEntry] = [
	LicensedCreditEntry.new(
		"Welcome to Haumea",
		["Justin Kreikemeyer"],
		"CC-BY-NC-SA 4.0"
	),
	LicensedCreditEntry.new(
		"Epic Synthwave Combat Music",
		["NickPanekAiAssets"],
		"Pixabay License"
	),
	LicensedCreditEntry.new(
		"Cyberpunk Synthwave",
		["FidelFortune"],
		"Pixabay License"
	),
]

var sound_effect_credit_entries: Array[LicensedCreditEntry] = [
	LicensedCreditEntry.new("Old Internet Modem Dialing", ["Liecio"], "Pixabay License"),
	LicensedCreditEntry.new("Rocket Landing", ["Freesound Community"], "Pixabay License"),
	LicensedCreditEntry.new("Glass Cracking", ["Dragon Studio"], "Pixabay License"),
	LicensedCreditEntry.new("Shattering Ice", ["Dragon Studio"], "Pixabay License"),
	LicensedCreditEntry.new("Rocket Launch", ["49053354"], "Pixabay License"),
	LicensedCreditEntry.new("Demon Growl", ["Freesound Community"], "Pixabay License"),
	LicensedCreditEntry.new("Monster Sound 2", ["Freesound Community"], "Pixabay License"),
	LicensedCreditEntry.new("Impactful Damage", ["BannyTheCoolio"], "Pixabay License"),
	LicensedCreditEntry.new("Futuristic Alien Oscillation", ["FNX Sound"], "Pixabay License"),
	LicensedCreditEntry.new("Alien Alert Noise", ["FNX Sound"], "Pixabay License"),
	LicensedCreditEntry.new("Alien Underworld Sound", ["FNX Sound"], "Pixabay License"),
	LicensedCreditEntry.new("Alien Sounds", ["Dragon Studio"], "Pixabay License"),
	LicensedCreditEntry.new("Cinematic Dive Underwater", ["Dragon Studio"], "Pixabay License"),
	LicensedCreditEntry.new("Engine Rumble", ["Dragon Studio"], "Pixabay License"),
	LicensedCreditEntry.new("Deep Sea Underwater Ambience", ["Dragon Studio"], "Pixabay License"),
	LicensedCreditEntry.new("Duoi Mat Bien", ["Freesound Community"], "Pixabay License"),
	LicensedCreditEntry.new("Water Splash Effect", ["Dragon Studio"], "Pixabay License"),
	LicensedCreditEntry.new("Deep Sea Ambience", ["Freesound Community"], "Pixabay License"),
	LicensedCreditEntry.new("Attack Release", ["CrunchPixStudio"], "Pixabay License"),
	LicensedCreditEntry.new("Large Underwater Explosion", ["Dragon Studio"], "Pixabay License"),
	LicensedCreditEntry.new("Swim", ["Freesound Community"], "Pixabay License"),
	LicensedCreditEntry.new("Coin Pickup", ["sfxr.me"], ""),
]

var addon_credit_entries: Array[LicensedCreditEntry] = [
	LicensedCreditEntry.new("SmartShape2D", ["SirRamEsq"], "MIT"),
]

var font_credit_entries: Array[LicensedCreditEntry] = [
	LicensedCreditEntry.new("Orbitron", ["Matt McInerney"], "SIL Open Font License"),
]


var sound_design_credit_entries: Array[AuthorCreditEntry] = [
	AuthorCreditEntry.new("Justin Kreikemeyer"),
	AuthorCreditEntry.new("Jule Engel"),
	AuthorCreditEntry.new("Brutenis Gliwa"),
]


var artist_credit_entries: Array[AuthorCreditEntry] = [
	AuthorCreditEntry.new("Jule Engel"),
	AuthorCreditEntry.new("Brutenis Gliwa"),
]


var programing_credit_entries: Array[AuthorCreditEntry] = [
	AuthorCreditEntry.new("Jule Engel"),
	AuthorCreditEntry.new("Brutenis Gliwa"),
]


var game_design_credit_entries: Array[AuthorCreditEntry] = [
	AuthorCreditEntry.new("Jule Engel"),
	AuthorCreditEntry.new("Brutenis Gliwa"),
]

var licensing: GameLicenseCreditEntry = GameLicenseCreditEntry.new("MIT_LICENSE", "2026", "Hephaistos' Forge")


func _ready() -> void:
	create_credits()


func create_credits():
	self.add_child(_create_programers_section())
	self.add_child(_create_game_design_section())
	self.add_child(_create_artists_section())
	self.add_child(_create_sound_design_section())
	self.add_child(_create_music_section())
	self.add_child(_create_sound_effects_section())
	self.add_child(_create_addons_section())
	self.add_child(_create_fonts_section())
	self.add_child(_create_end_section())


func _create_game_design_section():
	return _create_simple_author_section("Spieldesign", game_design_credit_entries)


func _create_programers_section():
	return _create_simple_author_section("Programmierung", programing_credit_entries)


func _create_artists_section():
	return _create_simple_author_section("Grafik", artist_credit_entries)


func _create_sound_design_section():
	return _create_simple_author_section("Sounddesign", sound_design_credit_entries)


func _create_music_section():
	return _create_licensed_section("Musik", music_credit_entries)


func _create_sound_effects_section():
	return _create_licensed_section("Soundeffekte", sound_effect_credit_entries)


func _create_addons_section():
	return _create_licensed_section("Addons", addon_credit_entries)


func _create_fonts_section():
	return _create_licensed_section("Schriftarten", font_credit_entries)


func _create_end_section():
	var section_container = _create_credit_section_container(THANKS)
	section_container.add_child(_create_title_label(GAME_TITLE))
	section_container.add_child(_create_author_label(licensing.studio_name))
	section_container.add_child(_create_author_label(licensing.year))
	section_container.add_child(_create_license_label(licensing.license))
	return section_container
	

func _create_simple_author_section(section_title: String, author_credit_entries: Array[AuthorCreditEntry]):
	var section_container = _create_credit_section_container(section_title)
	
	for entry: AuthorCreditEntry in author_credit_entries:
		var item_container = _create_credit_item_container()
		section_container.add_child(item_container)

		var title_label = _create_title_label(entry.author)
		section_container.add_child(title_label)
	return section_container


func _create_licensed_section(section_title: String, licensed_credit_entries: Array[LicensedCreditEntry]):
	var section_container = _create_credit_section_container(section_title)
	
	for entry: LicensedCreditEntry in licensed_credit_entries:

		var item_container = _create_credit_item_container()
		section_container.add_child(item_container)

		var title_label = _create_title_label(entry.title)
		section_container.add_child(title_label)

		for author in entry.authors:
			var author_label = _create_author_label(author)
			section_container.add_child(author_label)

		if entry.license != "":
			var license_label = _create_license_label(entry.license)
			section_container.add_child(license_label)
	return section_container
	
	
func _create_credit_section_container(section_header_text: String) -> VBoxContainer:
	var section_container = VBoxContainer.new()
	section_container.add_theme_constant_override("separation", 0)
	var section_header = _create_section_header(section_header_text)
	section_container.add_child(section_header)
	return section_container


func _create_credit_item_container() -> VBoxContainer:
	var item_container = VBoxContainer.new()
	item_container.add_theme_constant_override("separation", 2)
	return item_container


func _create_section_header(header_text: String) -> Label:
	var label = Label.new()
	_format_label(label, bold, 50)
	label.text = header_text
	return label


func _create_title_label(title_text: String) -> Label:
	var label = Label.new()
	_format_label(label, regular, 20)
	label.text = title_text
	return label


func _create_author_label(author_text: String) -> Label:
	var label = Label.new()
	_format_label(label, regular, 15)
	label.text = author_text
	return label


func _create_license_label(license_text: String) -> Label:
	var label = Label.new()
	_format_label(label, light, 10)
	label.text = "Lizenziert unter: " + license_text
	return label


func _format_label(label, font, font_size, alignment = HORIZONTAL_ALIGNMENT_CENTER):
	label.horizontal_alignment = alignment
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
