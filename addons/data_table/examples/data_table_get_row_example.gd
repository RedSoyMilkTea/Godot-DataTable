extends Control

const DT_CHARACTER = preload("uid://dryg3duiwlaln")

@onready var label: Label = $VBoxContainer/Label

func _ready() -> void:
	find_children("", "Button").map(func(button: Button):
		button.pressed.connect(func():
			label.text = DT_CHARACTER.get_data(button.text).to_json()
		)
	)
