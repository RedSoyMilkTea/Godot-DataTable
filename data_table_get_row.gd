@tool
extends EditorScript

func _run() -> void:
	#reload_plugin()
	var data_table: DataTable = load("res://dt_character.tres")
	prints(data_table.get_data("warrior-boss"))
	
func reload_plugin() -> void:
	var plugin_name := "data_table"
	if EditorInterface.is_plugin_enabled(plugin_name):
		EditorInterface.set_plugin_enabled(plugin_name, false)
	EditorInterface.set_plugin_enabled(plugin_name, true)
