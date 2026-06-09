@tool
extends EditorPlugin

var dock: Control

func _enter_tree() -> void:
	dock = preload("res://addons/claude_assistant/claude_dock.gd").new()
	dock.name = "Godo4NewbiAI"
	dock.editor_plugin = self
	add_control_to_bottom_panel(dock, "✦ Godo4NewbiAI")

func _exit_tree() -> void:
	if dock:
		remove_control_from_bottom_panel(dock)
		dock.queue_free()
