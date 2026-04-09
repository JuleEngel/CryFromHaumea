extends Control

const TUTORIAL_ITEM_PREFAB = preload("res://ui_scenes/main_menu/how_to_play/how_to_play_item.tscn")

var tutorial_items = [
	[
		preload("res://icon.svg"), 
		"Headline", 
		"Body"
	],	
	[
		preload("res://icon.svg"), 
		"Headline", 
		"Body"
	],
	[
		preload("res://icon.svg"), 
		"Headline", 
		"Body"
	],
	[
		preload("res://icon.svg"), 
		"Headline", 
		"Body"
	],
	[
		preload("res://icon.svg"), 
		"Headline", 
		"Body"
	]
	
]


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for item in tutorial_items:
		var tut_item = TUTORIAL_ITEM_PREFAB.instantiate()
		$MarginContainer/ScrollContainer/CenterContainer/GridContainer.add_child(tut_item)
		tut_item.init(item[0], item[1], item[2])
		
