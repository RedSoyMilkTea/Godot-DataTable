@tool
extends MarginContainer

@onready var v_box_container_table_editor: VBoxContainer = $VBoxContainerTableEditor
@onready var button_add_row: Button = $VBoxContainerTableEditor/HBoxContainer/ButtonAddRow
@onready var button_import: Button = $VBoxContainerTableEditor/HBoxContainer/ButtonImport
@onready var button_export: Button = $VBoxContainerTableEditor/HBoxContainer/ButtonExport
@onready var label_row_struct_file: Label = $VBoxContainerTableEditor/HBoxContainer/LabelRowStructFile
@onready var label_table_file: Label = $VBoxContainerTableEditor/HBoxContainer/LabelTableFile

@onready var h_box_container_heads: HBoxContainer = $VBoxContainerTableEditor/HBoxContainerHeads
@onready var v_box_container_data_list: VBoxContainer = $VBoxContainerTableEditor/ScrollContainer/VBoxContainerDataList

@onready var v_box_container_row_selector: VBoxContainer = $VBoxContainerRowSelector
@onready var option_button_row_selector: OptionButton = $VBoxContainerRowSelector/HBoxContainer/OptionButtonRowSelector
@onready var button_row_selector: Button = $VBoxContainerRowSelector/HBoxContainer/ButtonRowSelector

@onready var file_dialog: FileDialog = $FileDialog
@onready var popup_menu: PopupMenu = $PopupMenu

var data_table: DataTable
var style_box_head: StyleBoxFlat
const supported_types = {
	Variant.Type.TYPE_BOOL: false,
	Variant.Type.TYPE_INT: 0,
	Variant.Type.TYPE_FLOAT: 0.0,
	Variant.Type.TYPE_STRING: ""
}

func _ready() -> void:
	button_add_row.icon = get_theme_icon("add_preset", "ColorPicker")
	button_add_row.pressed.connect(func():
		add_row()
		load_data()
	)
	
	button_import.icon = get_theme_icon("Load", "EditorIcons")
	button_import.pressed.connect(func():
		file_dialog.file_mode = FileDialog.FileMode.FILE_MODE_OPEN_FILE
		file_dialog.filters = PackedStringArray(["*.json ; JSON Files"])
		file_dialog.popup_centered()
	)
	
	button_export.icon = get_theme_icon("Save", "EditorIcons")
	button_export.pressed.connect(func():
		file_dialog.file_mode = FileDialog.FileMode.FILE_MODE_SAVE_FILE
		file_dialog.filters = PackedStringArray(["*.json ; JSON Files"])
		file_dialog.current_file = data_table.resource_path.get_basename().trim_prefix("res://") + ".json"
		file_dialog.popup_centered()
	)

	var scroll_container: ScrollContainer = v_box_container_data_list.get_parent()
	scroll_container.add_theme_constant_override("scrollbar_h_separation", -scroll_container.get_v_scroll_bar().size.x)

	button_row_selector.pressed.connect(func():
		if data_table == null:
			return
		var row_struct_resources: Array = get_row_struct_resources()
		data_table.row_struct = row_struct_resources[option_button_row_selector.selected].new()
		ResourceSaver.save(data_table, data_table.resource_path)
		load_data()
	)

	file_dialog.file_selected.connect(func(selected_path):
		if file_dialog.file_mode == FileDialog.FileMode.FILE_MODE_OPEN_FILE:
			data_table.data_list = JSON.parse_string(FileAccess.get_file_as_string(selected_path))
			load_data()
			save_data()
		elif file_dialog.file_mode == FileDialog.FileMode.FILE_MODE_SAVE_FILE:
			FileAccess.open(selected_path, FileAccess.WRITE).store_string(JSON.stringify(data_table.data_list, "  "))
	)

	popup_menu.set_item_icon(0, get_theme_icon("ActionCopy", "EditorIcons"))
	popup_menu.set_item_icon(1, get_theme_icon("ActionPaste", "EditorIcons"))
	popup_menu.set_item_icon(2, get_theme_icon("Remove", "EditorIcons"))
	popup_menu.set_item_icon_modulate(2, Color.RED)
	popup_menu.set_item_icon(4, get_theme_icon("MoveUp", "EditorIcons"))
	popup_menu.set_item_icon(5, get_theme_icon("MoveDown", "EditorIcons"))
	popup_menu.set_item_icon(7, get_theme_icon("ArrowUp", "EditorIcons"))
	popup_menu.set_item_icon(8, get_theme_icon("ArrowDown", "EditorIcons"))
	popup_menu.id_pressed.connect(func(id):
		var row_idx = popup_menu.get_meta("row_idx")
		if id == 11:
			copy_row(row_idx)
		elif id == 12:
			paste_row(row_idx)
			load_data()
		elif id == 13:
			remove_row(row_idx)
			load_data()
		elif id == 21:
			move_row(row_idx, row_idx - 1)
			load_data()
		elif id == 22:
			move_row(row_idx, row_idx + 1)
			load_data()
		elif id == 31:
			add_row(row_idx)
			load_data()
		elif id == 32:
			add_row(row_idx + 1)
			load_data()
	)

	style_box_head = StyleBoxFlat.new()
	style_box_head.bg_color = get_theme_color("background_color", "Editor")
	style_box_head.content_margin_left = 8
	style_box_head.set_corner_radius_all(4)
	
	visibility_changed.connect(func():
		if visible:
			load_data()
	)

func handle(_data_table: DataTable):
	data_table = _data_table
	visibility_changed.emit()

func load_data():
	update_row_selector()
	
	v_box_container_table_editor.visible = data_table && data_table.row_struct
	v_box_container_row_selector.visible = data_table != null && data_table.row_struct == null

	if data_table == null || data_table.row_struct == null:
		return

	data_table = ResourceLoader.load(data_table.resource_path)
	update_toolbar()
	update_heads()
	update_data_list()
	update_visual()

func update_row_selector():
	var row_struct_resources: Array = get_row_struct_resources()
	option_button_row_selector.clear()
	for resource in row_struct_resources:
		var global_name = resource.get_global_name()
		if (global_name.is_empty()):
			option_button_row_selector.add_item(resource.resource_path)
		else:
			option_button_row_selector.add_item(global_name)
	button_row_selector.disabled = row_struct_resources.size() == 0

func update_toolbar():
	label_table_file.text = data_table.resource_path.trim_prefix("res:/") if data_table else "No Data Table Selected"
	label_row_struct_file.text = data_table.row_struct.get_script().resource_path.trim_prefix("res:/") if data_table && data_table.row_struct else "No Row Struct Selected"

func update_heads():
	h_box_container_heads.get_children().map(func(i): if i.get_index() > 1: i.queue_free())
	
	# placeholder for index column
	if h_box_container_heads.get_child_count() == 0:
		var label_index: Label = Label.new()
		label_index.text = "#"
		label_index.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
		h_box_container_heads.add_child(label_index)
		
		# placeholder for remove button column
		var button_placeholder: Button = Button.new()
		button_placeholder.icon = get_theme_icon("Remove", "EditorIcons")
		button_placeholder.disabled = true
		button_placeholder.modulate = Color.TRANSPARENT
		h_box_container_heads.add_child(button_placeholder)
	
	# heads
	var fields: Array = get_fields()
	for field in fields:
		if field.type not in supported_types.keys():
			continue
		var label_head := Label.new()
		var head_text = field.hint_string if field.hint_string != "" else field.name
		var arr := Array(head_text.to_snake_case().split("_"))
		label_head.text = " ".join(arr.map(func(s): return s.capitalize()))
		label_head.custom_minimum_size.y = 36
		label_head.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
		label_head.size_flags_horizontal = Control.SizeFlags.SIZE_EXPAND_FILL
		label_head.add_theme_font_override("font", get_theme_font("bold", "EditorFonts"))
		label_head.add_theme_stylebox_override("normal", style_box_head)
		h_box_container_heads.add_child(label_head)

func update_data_list():
	v_box_container_data_list.get_children().map(func(i): i.queue_free())

	var fields: Array = get_fields()
	var data_list: Array = data_table.data_list
	
	for row_idx: int in data_list.size():
		var hbox := HBoxContainer.new()
		hbox.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MouseButton.MOUSE_BUTTON_RIGHT and event.pressed:
				popup_menu.set_item_text(7, "Insert to Top" if row_idx == 0 else "Insert Above")
				popup_menu.set_item_disabled(4, row_idx == 0)
				popup_menu.set_item_text(8, "Add to End" if row_idx >= data_list.size() - 1 else "Insert Below")
				popup_menu.set_item_disabled(5, row_idx >= data_list.size() - 1)
				popup_menu.set_meta("row_idx", row_idx)
				popup_menu.popup(Rect2i(DisplayServer.mouse_get_position(), Vector2.ZERO))
				# popup_menu.popup(Rect2i(event.get_global_position() + Vector2(get_window().position), Vector2.ZERO))
		)
		
		# index column
		var label_index: Label = Label.new()
		label_index.text = str(row_idx + 1)
		label_index.custom_minimum_size.x = str(data_list.size()).length() * 22
		label_index.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(label_index)

		# remove button
		var button_remove_row: Button = Button.new()
		button_remove_row.icon = get_theme_icon("Remove", "EditorIcons")
		button_remove_row.set("theme_override_colors/icon_normal_color", Color(1, 0.47, 0.42))
		button_remove_row.pressed.connect(func():
			remove_row(row_idx)
			load_data()
		)
		hbox.add_child(button_remove_row)

		var data_item = data_list[row_idx]
		for col_idx in fields.size():
			var value: Variant
			var type: Variant.Type = fields[col_idx]["type"]
			if type not in supported_types.keys():
				continue
			if data_item.size() > col_idx:
				value = data_item[col_idx]
			else:
				value = supported_types[type]
			var editor: Control
			match type:
				Variant.Type.TYPE_BOOL:
					editor = CheckBox.new() as CheckBox
					editor.button_pressed = bool(value)
					editor.mouse_filter = Control.MOUSE_FILTER_PASS
				Variant.Type.TYPE_INT:
					editor = SpinBox.new() as SpinBox
					editor.select_all_on_focus = true
					editor.allow_greater = true
					editor.allow_lesser = true
					editor.value = int(value)
				Variant.Type.TYPE_FLOAT:
					editor = SpinBox.new() as SpinBox
					editor.select_all_on_focus = true
					editor.step = 0.0001
					editor.allow_greater = true
					editor.allow_lesser = true
					editor.value = float(value)
				Variant.Type.TYPE_STRING:
					editor = LineEdit.new() as LineEdit
					editor.select_all_on_focus = true
					editor.placeholder_text = "empty"
					editor.text = str(value)
				_:
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

		hbox.get_children().map(func(i):
			i.mouse_entered.connect(func(): hbox.modulate = Color(1, 1, 1, 0.8))
			i.mouse_exited.connect(func(): hbox.modulate = Color(1, 1, 1, 1))
		)

		v_box_container_data_list.add_child(hbox)
	
func update_visual():
	var data_list: Array = data_table.data_list
	h_box_container_heads.get_child(0).set_custom_minimum_size(Vector2(str(data_list.size()).length() * 22, 0))
	
	get_tree().process_frame.connect(
		(
		func():
		var scroll_container: ScrollContainer = v_box_container_data_list.get_parent()
		scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value
		)
		# v_box_container_data_list.get_parent().get_v_scroll_bar().set_value.bind(v_box_container_data_list.size.y),
		, CONNECT_ONE_SHOT)

func get_fields() -> Array:
	var fields = data_table.row_struct.get_script().get_script_property_list().filter(func(p):
		return p.type != Variant.Type.TYPE_NIL
	)
	fields.sort_custom(func(a, b): return a.name == "row_name")
	return fields

func add_row(new_row_idx := -1):
	var new_row = []
	get_fields().map(func(field):
		match field["type"]:
			Variant.Type.TYPE_BOOL:
				new_row.push_back(false)
			Variant.Type.TYPE_INT:
				new_row.push_back(0)
			Variant.Type.TYPE_FLOAT:
				new_row.push_back(0.0)
			Variant.Type.TYPE_STRING:
				var value = create_new_row_name() if field.name == "row_name" else ""
				new_row.push_back(value)
			_:
				new_row.push_back("")
	)
	if new_row_idx == -1:
		data_table.data_list.push_back(new_row)
	else:
		data_table.data_list.insert(new_row_idx, new_row)
	save_data()

func remove_row(row_idx):
	data_table.data_list.remove_at(row_idx)
	save_data()

func update_col_value(row_idx: int, col_idx: int, value: Variant):
	data_table.data_list[row_idx][col_idx] = value
	save_data()

func copy_row(row_idx):
	DisplayServer.clipboard_set(JSON.stringify(data_table.data_list[row_idx]))

func paste_row(row_idx):
	var data: Array = JSON.parse_string(DisplayServer.clipboard_get())
	data[0] = data_table.data_list[row_idx][0]
	data_table.data_list[row_idx] = data
	save_data()

func move_row(current_row_idx, desired_row_idx):
	var data: Array = data_table.data_list[desired_row_idx].duplicate()
	data_table.data_list[desired_row_idx] = data_table.data_list[current_row_idx]
	data_table.data_list[current_row_idx] = data
	save_data()

func save_data():
	ResourceSaver.save(data_table, data_table.resource_path)

func create_new_row_name():
	var data_list: Array = data_table.data_list
	var idx := 1
	while true:
		var new_row_name = "New Row" + ((" " + str(idx)) if idx > 1 else "")
		if data_list.any(func(row):
			return row[0] == new_row_name
		):
			idx += 1
		else:
			return new_row_name

func get_row_struct_resources(path := "") -> Array:
	var scripts = []
	if path.begins_with(".") || path.begins_with("addons"):
		return scripts
		
	var dir = DirAccess.open("res://" + path)
	for d in dir.get_directories():
		scripts.append_array(get_row_struct_resources(path.path_join(d)))

	for f in dir.get_files():
		if f.get_extension() == "gd":
			var resource := ResourceLoader.load(path.path_join(f))
			if resource is GDScript && resource.new() is DataTableRow:
				scripts.append(resource)
	return scripts
