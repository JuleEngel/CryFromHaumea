class_name Credits
extends Control

const bold = preload("res://ui_scenes/fonts/NovaSquare-Regular.ttf")
const light = preload("res://ui_scenes/fonts/NovaSquare-Regular.ttf")
const regular = preload("res://ui_scenes/fonts/NovaSquare-Regular.ttf")

const GAME_TITLE = "<GAME_TITLE>"
const THANKS: String = "Thanks for Playing!"

var music_credit_entries: Array[LicensedCreditEntry] = [
	LicensedCreditEntry.new(
		"Track_Title", 
		["Author1", "Author2"], 
		"License"
	)
]

var shader_credit_entries: Array[LicensedCreditEntry] = [
	LicensedCreditEntry.new(
		"Track_Title", 
		["Author1", "Author2"], 
		"License"
	)
]


var sound_design_credit_entries: Array[AuthorCreditEntry] = [
	AuthorCreditEntry.new("Author1")
]


var artist_credit_entries: Array[AuthorCreditEntry] = [
	AuthorCreditEntry.new("Author1"),
	AuthorCreditEntry.new("Author2"),
	AuthorCreditEntry.new("Author3")
]


var programing_credit_entries: Array[AuthorCreditEntry] = [
	AuthorCreditEntry.new("Author1"),
	AuthorCreditEntry.new("Author2"),
	AuthorCreditEntry.new("Author3")
]


var game_design_credit_entries: Array[AuthorCreditEntry] = [
	AuthorCreditEntry.new("Author1"),
	AuthorCreditEntry.new("Author2"),
	AuthorCreditEntry.new("Author3")
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
	self.add_child(_create_end_section())


func _create_game_design_section():
	return _create_simple_author_section("Game Design", game_design_credit_entries)


func _create_programers_section():
	return _create_simple_author_section("Programers", programing_credit_entries)


func _create_artists_section():
	return _create_simple_author_section("Artists", artist_credit_entries)


func _create_sound_design_section():
	return _create_simple_author_section("Sound Design", sound_design_credit_entries)


func _create_music_section():
	return _create_licensed_section("Music", music_credit_entries)


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
	label.text = "licensed under: " + license_text
	return label


func _format_label(label, font, font_size, alignment = HORIZONTAL_ALIGNMENT_CENTER):
	label.horizontal_alignment = alignment
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
