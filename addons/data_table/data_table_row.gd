class_name DataTableRow

var row_name: String

func _to_string() -> String:
	var arr := []
	for p in get_property_list():
		if p.type == Variant.Type.TYPE_NIL || p.class_name == "Script" || p.name == "row_name":
			continue
		var v = get(p.name)
		if p.type == Variant.Type.TYPE_VECTOR2:
			v = {"x": v.x, "y": v.y}
		elif p.type == Variant.Type.TYPE_VECTOR3:
			v = {"x": v.x, "y": v.y, "z": v.z}
		arr.push_back(JSON.stringify({p.name: v}))
	return ", ".join(arr).replace("}, {", ", ")

func to_json() -> String:
	return JSON.stringify(JSON.parse_string(_to_string()), "  ")