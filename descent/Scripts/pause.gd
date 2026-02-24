extends CanvasLayer

var paused := false

func _ready() -> void:
	hide()
	paused = false
	Engine.time_scale = 1
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		togglePauseMenu()

func _on_resume_pressed() -> void:
	hidePauseMenu()

func _on_quit_pressed() -> void:
	hidePauseMenu()
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	get_tree().change_scene_to_file("res://Scenes/menu.tscn")

func togglePauseMenu() -> void:
	paused = !paused
	if paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
		show()
		Engine.time_scale = 0
	else:
		hidePauseMenu()

func hidePauseMenu() -> void:
	hide()
	Engine.time_scale = 1
	paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
