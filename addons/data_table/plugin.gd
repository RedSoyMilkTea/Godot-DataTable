@tool
extends EditorPlugin

const MAIN_PANEL = preload("res://addons/data_table/data_table_editor.tscn")

var main_panel: Control

func _enable_plugin() -> void:
	# Add autoloads here.
	pass

func _disable_plugin() -> void:
	# Remove autoloads here.
	pass

func _enter_tree() -> void:
	main_panel = MAIN_PANEL.instantiate()

	# Add the main panel to the editor's main viewport.
	EditorInterface.get_editor_main_screen().add_child(main_panel)

	# Hide the main panel.
	_make_visible(false)
	# When this plugin node enters tree, add the custom types.

func _exit_tree() -> void:
	if main_panel:
		main_panel.queue_free()
	# When the plugin node exits the tree, remove the custom types.

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if main_panel:
		if visible:
			main_panel.show()
		else:
			main_panel.hide()

func _get_plugin_name() -> String:
	var config = ConfigFile.new()
	var err = config.load("res://addons/data_table/plugin.cfg")
	return config.get_value("plugin", "name", "Data Table")

func _get_plugin_icon() -> Texture2D:
	return Control.new().get_theme_icon("list_mode", "FileDialog")

func _handles(obj: Object) -> bool:
	if obj is not DataTable:
		return false

	main_panel.handle(obj)
	return true
