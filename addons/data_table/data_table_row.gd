class_name DataTableRow

var row_name: String

func _to_string() -> String:
	var arr := []
	for p in get_property_list():
		if p.type == Variant.Type.TYPE_NIL || p.class_name == "Script" || p.name == "row_name":
			continue
		arr.push_back(JSON.stringify({p.name: get(p.name)}))
	return ", ".join(arr).replace("}, {", ", ")
