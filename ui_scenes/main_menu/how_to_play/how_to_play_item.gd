extends VBoxContainer

@onready var texture = $PanelContainer/TextureRect
@onready var title = $Label
@onready var description = $RichTextLabel


func init(_texture, _title, _description):
	if _texture:
		texture.texture = _texture
	title.text = _title
	description.text = _description
	
