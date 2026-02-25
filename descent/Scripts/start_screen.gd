extends Control
@onready var TransitionScreen = $TransitionScreen

func _on_play_pressed() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().change_scene_to_file("res://Scenes/Main.tscn") 
	



func _on_exit_pressed() -> void:
	get_tree().quit()




func _on_controls_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Controls.tscn")
