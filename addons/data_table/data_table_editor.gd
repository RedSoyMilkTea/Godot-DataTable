@tool
extends MarginContainer

@onready var button_add_row: Button = $VBoxContainer/HBoxContainer/ButtonAddRow
@onready var h_box_container_heads: HBoxContainer = $VBoxContainer/HBoxContainerHeads
@onready var v_box_container_data_list: VBoxContainer = $VBoxContainer/ScrollContainer/VBoxContainerDataList
const data_path = "res://data.json"

func _ready() -> void:
	button_add_row.icon = get_theme_icon("add_preset", "ColorPicker")
	button_add_row.pressed.connect(func():
		append_row()
		load_data()
	)
	visibility_changed.connect(load_data)

func load_data():
	print("load_data")
	var data_source = load(data_path).data
	var fields: Array = data_source.fields
	var data_list: Array = data_source.dataList

	h_box_container_heads.get_children().map(func(i): i.queue_free())
	
	for field in fields:
		var line_edit := LineEdit.new()
		line_edit.text = field.name
		line_edit.editable = false
		line_edit.size_flags_horizontal = Control.SizeFlags.SIZE_EXPAND_FILL
		h_box_container_heads.add_child(line_edit)
		
	var button_placeholder: Button = Button.new()
	button_placeholder.icon = get_theme_icon("Remove", "EditorIcons")
	button_placeholder.disabled = true
	button_placeholder.modulate = Color.TRANSPARENT
	h_box_container_heads.add_child(button_placeholder)

	v_box_container_data_list.get_children().map(func(i): i.queue_free())
	
	for row_idx: int in data_list.size():
		var data_item = data_list[row_idx]
		var hbox := HBoxContainer.new()
		for col_idx in data_item.size():
			var type: String = fields[col_idx]["type"]
			var value = data_item[col_idx]
			var editor: Control
			if type == "bool":
				editor = CheckBox.new() as CheckBox
				editor.button_pressed = bool(value)
			elif type == "int":
				editor = SpinBox.new() as SpinBox
				editor.allow_greater = true
				editor.allow_lesser = true
				editor.value = int(value)
			elif type == "float":
				editor = SpinBox.new() as SpinBox
				editor.step = 0.0001
				editor.allow_greater = true
				editor.allow_lesser = true
				editor.value = float(value)
			elif type == "string":
				editor = LineEdit.new() as LineEdit
				editor.placeholder_text = "empty"
				editor.text = str(value)
			else:
				continue
			
			if editor is Range:
				editor.value_changed.connect(func(value): update_col_value(row_idx, col_idx, value))
			elif editor is LineEdit:
				editor.text_changed.connect(func(value): update_col_value(row_idx, col_idx, value))
			elif editor is BaseButton:
				editor.pressed.connect(func(): update_col_value(row_idx, col_idx, editor.button_pressed))
			
			# editor.size = h_box_container_heads.get_child(col_idx).size
			editor.size_flags_horizontal = Control.SizeFlags.SIZE_EXPAND_FILL
			hbox.add_child(editor)
		
		if hbox.get_child_count() > 0:
			var button_remove_row: Button = Button.new()
			button_remove_row.icon = get_theme_icon("Remove", "EditorIcons")
			button_remove_row.set("theme_override_colors/icon_normal_color", Color(1, 0.47, 0.42))
			button_remove_row.pressed.connect(func():
				remove_row(row_idx)
				load_data()
			)
			hbox.add_child(button_remove_row)
		v_box_container_data_list.add_child(hbox)

func update_col_value(row_idx: int, col_idx: int, value: Variant):
	var data_source = load(data_path).data
	data_source.dataList[row_idx][col_idx] = value
	save_data(data_source)

func append_row():
	var data_source = load(data_path).data
	var new_row = []
	data_source.fields.map(func(field):
		var type: String = field["type"]
		if type == "bool":
			new_row.push_back(false)
		elif type == "int":
			new_row.push_back(0)
		elif type == "float":
			new_row.push_back(0.0)
		elif type == "string":
			new_row.push_back("")
	)
	data_source.dataList.push_back(new_row)
	save_data(data_source)

func remove_row(row_idx):
	var data_source = load(data_path).data
	data_source.dataList.remove_at(row_idx)
	save_data(data_source)

func save_data(data_source: Variant):
	var file = FileAccess.open(data_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data_source, "  "))
	file.close()
