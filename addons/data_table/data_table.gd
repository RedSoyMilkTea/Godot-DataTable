@tool
@icon("res://addons/data_table/data_table_icon.svg")
class_name DataTable extends Resource

var row_struct: DataTableRow

var data_list: Array = []

func _get_property_list():
	var properties = []
	properties.append({
		"name": "row_struct",
		"type": TYPE_OBJECT,
		"usage": PROPERTY_USAGE_STORAGE # This tells ResourceSaver to save it
	})
	properties.append({
		"name": "data_list",
		"type": TYPE_ARRAY,
		"usage": PROPERTY_USAGE_STORAGE
	})
	return properties

func get_data(row_name: String = "Default") -> DataTableRow:
	var row_idx: int = data_list.find_custom(func(row):
		return row[0] == row_name
	)
	if row_idx == -1:
		return
	
	var row_data_array: Variant = data_list[row_idx]
	var script: GDScript = row_struct.get_script()
	var row_data: Variant = script.new()
	var property_idx := 1
	for p in script.get_script_property_list():
		if p.type == Variant.Type.TYPE_NIL || p.name == "row_name":
			continue
		row_data.set(p.name, row_data_array[property_idx])
		property_idx += 1
	return row_data