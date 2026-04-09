@tool
extends EditorPlugin

const MainPanel = preload("res://addons/data_table/data_table_editor.tscn")

var main_panel_instance: Control

func _enable_plugin() -> void:
	# Add autoloads here.
	pass

func _disable_plugin() -> void:
	# Remove autoloads here.
	pass

func _enter_tree() -> void:
	main_panel_instance = MainPanel.instantiate()
	#main_panel_instance.get_child(1).editor_interface = get_editor_interface()

	# Add the main panel to the editor's main viewport.
	EditorInterface.get_editor_main_screen().add_child(main_panel_instance)

	# Hide the main panel.
	_make_visible(false)
	# When this plugin node enters tree, add the custom types.

func _exit_tree() -> void:
	if main_panel_instance:
		main_panel_instance.queue_free()
	# When the plugin node exits the tree, remove the custom types.

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if main_panel_instance:
		if visible:
			main_panel_instance.show()
		else:
			main_panel_instance.hide()

func _get_plugin_name() -> String:
	return "Data Table"

func _get_plugin_icon() -> Texture2D:
	return Control.new().get_theme_icon("list_mode", "FileDialog")

func _handles(obj: Object) -> bool:
	return false
