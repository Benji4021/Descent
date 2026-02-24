extends Control

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	

func _on_back_pressed():
	get_tree().change_scene_to_file("res://Scenes/menu.tscn")
