extends CanvasLayer

@onready var retry_button: Button = $ColorRect/MarginContainer/HBoxContainer/VBoxContainer/Play

func _ready() -> void:
	visible = false
	retry_button.pressed.connect(_on_retry_pressed)

func show_death() -> void:
	visible = true
	get_tree().paused = true
	retry_button.grab_focus()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene() 




func _on_exit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()


func _on_credits_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/Credits.tscn")
