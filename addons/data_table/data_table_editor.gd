@tool
extends MarginContainer

@onready var v_box_container_table_editor: VBoxContainer = $VBoxContainerTableEditor
@onready var button_add_row: Button = $VBoxContainerTableEditor/HBoxContainer/ButtonAddRow
@onready var button_import: Button = $VBoxContainerTableEditor/HBoxContainer/ButtonImport
@onready var button_export: Button = $VBoxContainerTableEditor/HBoxContainer/ButtonExport
@onready var label_row_struct_file: Label = $VBoxContainerTableEditor/HBoxContainer/LabelRowStructFile
@onready var label_table_file: Label = $VBoxContainerTableEditor/HBoxContainer/LabelTableFile

@onready var h_box_container_columns: HBoxContainer = $VBoxContainerTableEditor/ScrollContainer/HBoxContainerColumns

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
	Variant.Type.TYPE_STRING: "",
	Variant.Type.TYPE_VECTOR2: Vector2.ZERO,
	Variant.Type.TYPE_VECTOR3: Vector3.ZERO
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
		file_dialog.current_file = data_table.resource_path.get_file().get_basename() + ".json"
		file_dialog.popup_centered()
	)

	# h_box_container_heads.visible = false
	# control_heads.custom_minimum_size.y = 36

	var scroll_container: ScrollContainer = h_box_container_columns.get_parent()
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
			var fields = get_fields()
			var imported_data = JSON.parse_string(FileAccess.get_file_as_string(selected_path))
			for row_idx in imported_data.size():
				for col_idx in fields.size():
					var value: Variant = imported_data[row_idx][col_idx]
					if fields[col_idx]["type"] == Variant.Type.TYPE_VECTOR2:
						imported_data[row_idx][col_idx] = Vector2(value.x, value.y)
					elif fields[col_idx]["type"] == Variant.Type.TYPE_VECTOR3:
						imported_data[row_idx][col_idx] = Vector3(value.x, value.y, value.z)
			data_table.data_list = imported_data
			load_data()
			save_data()
		elif file_dialog.file_mode == FileDialog.FileMode.FILE_MODE_SAVE_FILE:
			var fields = get_fields()
			var export_data := data_table.data_list.duplicate_deep()
			for row_idx in export_data.size():
				for col_idx in fields.size():
					var value: Variant = export_data[row_idx][col_idx]
					if fields[col_idx]["type"] == Variant.Type.TYPE_VECTOR2:
						export_data[row_idx][col_idx] = {"x": value.x, "y": value.y}
					elif fields[col_idx]["type"] == Variant.Type.TYPE_VECTOR3:
						export_data[row_idx][col_idx] = {"x": value.x, "y": value.y, "z": value.z}
			FileAccess.open(selected_path, FileAccess.WRITE).store_string(JSON.stringify(export_data, "  "))
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
	h_box_container_columns.get_children().map(func(i):
		if i.get_index() > 1:
			h_box_container_columns.remove_child(i)
			i.queue_free()
	)
	
	# placeholder for index column
	if h_box_container_columns.get_child_count() == 0:
		var label_index: Label = Label.new()
		label_index.custom_minimum_size.y = 36
		label_index.text = "#"
		label_index.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
		var vbox := VBoxContainer.new()
		vbox.add_child(label_index)
		h_box_container_columns.add_child(vbox)
		
		# placeholder for remove button column
		var button_placeholder: Button = Button.new()
		button_placeholder.custom_minimum_size.y = 36
		button_placeholder.icon = get_theme_icon("Remove", "EditorIcons")
		button_placeholder.disabled = true
		button_placeholder.modulate = Color.TRANSPARENT
		var vbox2 := VBoxContainer.new()
		vbox2.add_child(button_placeholder)
		h_box_container_columns.add_child(vbox2)
	
	# heads
	var fields: Array = get_fields()
	for field in fields:
		if field.type not in supported_types.keys():
			continue
		var label := Label.new()
		var head_text = field.hint_string if field.hint_string != "" else field.name
		var arr := Array(head_text.to_snake_case().split("_"))
		label.text = " ".join(arr.map(func(s): return s.capitalize()))
		# label.clip_text = true
		label.custom_minimum_size.y = 36
		label.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SizeFlags.SIZE_EXPAND_FILL
		label.add_theme_font_override("font", get_theme_font("bold", "EditorFonts"))
		label.add_theme_stylebox_override("normal", style_box_head)
		var vbox := VBoxContainer.new()
		if field.type != Variant.Type.TYPE_BOOL:
			vbox.size_flags_horizontal = Control.SizeFlags.SIZE_EXPAND_FILL
		else:
			vbox.custom_minimum_size.x = 60
		vbox.add_child(label)
		h_box_container_columns.add_child(vbox)

func update_data_list():
	h_box_container_columns.get_children().map(func(i):
		i.get_children().map(func(j):
			if j.get_index() > 0:
				i.remove_child(j)
				j.queue_free()
		)
	)

	var fields: Array = get_fields()
	var data_list: Array = data_table.data_list
	
	for row_idx: int in data_list.size():
		# index column
		var label_index: Label = Label.new()
		label_index.text = str(row_idx + 1)
		label_index.custom_minimum_size.y = 29
		label_index.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
		label_index.mouse_filter = Control.MOUSE_FILTER_PASS
		label_index.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MouseButton.MOUSE_BUTTON_RIGHT and event.pressed:
				popup_menu.set_item_text(7, "Insert to Top" if row_idx == 0 else "Insert Above")
				popup_menu.set_item_disabled(4, row_idx == 0)
				popup_menu.set_item_text(8, "Add to End" if row_idx >= data_list.size() - 1 else "Insert Below")
				popup_menu.set_item_disabled(5, row_idx >= data_list.size() - 1)
				popup_menu.set_meta("row_idx", row_idx)
				popup_menu.popup(Rect2i(DisplayServer.mouse_get_position(), Vector2.ZERO))
				# popup_menu.popup(Rect2i(event.get_global_position() + Vector2(get_window().position), Vector2.ZERO))
		)
		h_box_container_columns.get_child(0).add_child(label_index)

		# remove button
		var button_remove_row: Button = Button.new()
		button_remove_row.custom_minimum_size.y = 29
		button_remove_row.icon = get_theme_icon("Remove", "EditorIcons")
		button_remove_row.set("theme_override_colors/icon_normal_color", Color(1, 0.47, 0.42))
		button_remove_row.pressed.connect(func():
			remove_row(row_idx)
			load_data()
		)
		h_box_container_columns.get_child(1).add_child(button_remove_row)

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
					if value is not bool: value = false
					var check_box := CheckBox.new()
					check_box.mouse_filter = Control.MOUSE_FILTER_PASS
					check_box.button_pressed = value
					check_box.size_flags_horizontal = Control.SizeFlags.SIZE_EXPAND | Control.SizeFlags.SIZE_SHRINK_CENTER
					editor = HBoxContainer.new()
					editor.add_child(check_box)
				Variant.Type.TYPE_INT:
					if value is not int && value is not float: value = 0
					editor = create_spin_box(int(value))
				Variant.Type.TYPE_FLOAT:
					if value is not float: value = 0.0
					editor = create_spin_box(0.0001)
					editor.value = value
				Variant.Type.TYPE_STRING:
					if value is not String: value = ""
					editor = LineEdit.new() as LineEdit
					editor.select_all_on_focus = true
					editor.placeholder_text = "empty"
					editor.text = value
				Variant.Type.TYPE_VECTOR2:
					if value is not Vector2: value = Vector2.ZERO
					editor = HBoxContainer.new()
					editor.add_child(create_spin_box(value.x, 0.0001))
					editor.add_child(create_spin_box(value.y, 0.0001))
				Variant.Type.TYPE_VECTOR3:
					if value is not Vector3: value = Vector3.ZERO
					editor = HBoxContainer.new()
					editor.add_child(create_spin_box(value.x, 0.0001))
					editor.add_child(create_spin_box(value.y, 0.0001))
					editor.add_child(create_spin_box(value.z, 0.0001))
				_:
					continue
			
			editor.custom_minimum_size.y = 29

			if type == Variant.Type.TYPE_INT || type == Variant.Type.TYPE_FLOAT:
				editor.value_changed.connect(func(value): update_col_value(row_idx, col_idx, value))
			elif type == Variant.Type.TYPE_STRING:
				editor.text_changed.connect(func(value): update_col_value(row_idx, col_idx, value))
			elif type == Variant.Type.TYPE_BOOL:
				var check_box: CheckBox = editor.get_child(0)
				check_box.pressed.connect(func(): update_col_value(row_idx, col_idx, check_box.button_pressed))
			elif type == Variant.Type.TYPE_VECTOR2:
				var editor_x: SpinBox = editor.get_child(0)
				var editor_y: SpinBox = editor.get_child(1)
				editor_x.value_changed.connect(func(value): update_col_value(row_idx, col_idx, Vector2(editor_x.value, editor_y.value)))
				editor_y.value_changed.connect(func(value): update_col_value(row_idx, col_idx, Vector2(editor_x.value, editor_y.value)))
			elif type == Variant.Type.TYPE_VECTOR3:
				var editor_x: SpinBox = editor.get_child(0)
				var editor_y: SpinBox = editor.get_child(1)
				var editor_z: SpinBox = editor.get_child(2)
				editor_x.value_changed.connect(func(value): update_col_value(row_idx, col_idx, Vector3(editor_x.value, editor_y.value, editor_z.value)))
				editor_y.value_changed.connect(func(value): update_col_value(row_idx, col_idx, Vector3(editor_x.value, editor_y.value, editor_z.value)))
				editor_z.value_changed.connect(func(value): update_col_value(row_idx, col_idx, Vector3(editor_x.value, editor_y.value, editor_z.value)))

			h_box_container_columns.get_child(col_idx + 2).add_child(editor)

func get_fields() -> Array:
	var fields = data_table.row_struct.get_script().get_script_property_list().filter(func(p):
		return p.type != Variant.Type.TYPE_NIL
	)
	fields.sort_custom(func(a, b): return a.name == "row_name")
	return fields

func add_row(new_row_idx := -1):
	var new_row = [create_new_row_name()]
	get_fields().map(func(field):
		if field["type"] in supported_types.keys():
			new_row.push_back(supported_types[field["type"]])
	)
	if new_row_idx == -1:
		data_table.data_list.push_back(new_row)
	else:
		data_table.data_list.insert(new_row_idx, new_row)
	save_data()
	if new_row_idx == -1 || new_row_idx >= data_table.data_list.size() - 1:
		await get_tree().create_timer(0.01).timeout
		var scroll_container: ScrollContainer = h_box_container_columns.get_parent()
		scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

func remove_row(row_idx):
	data_table.data_list.remove_at(row_idx)
	save_data()

func update_col_value(row_idx: int, col_idx: int, value: Variant):
	while data_table.data_list.size() <= row_idx:
		data_table.data_list.push_back([])
	while data_table.data_list[row_idx].size() <= col_idx:
		data_table.data_list[row_idx].push_back(null)
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

func create_spin_box(value: Variant, step: float = 1):
	var editor := SpinBox.new()
	editor.custom_arrow_step = max(step, 0.1)
	editor.select_all_on_focus = true
	editor.max_value = pow(2, 36)
	editor.min_value = - pow(2, 36)
	editor.step = step
	editor.allow_greater = true
	editor.allow_lesser = true
	editor.value = value
	return editor

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
