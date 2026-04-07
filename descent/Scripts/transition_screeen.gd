extends CanvasLayer

signal faded_to_black
signal faded_to_normal

@export var transition_speed_scale: float = 1.0

@onready var color_rect: ColorRect = $ColorRect
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	color_rect.visible = false
	animation_player.speed_scale = transition_speed_scale

	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"fadeToBlack":
		faded_to_black.emit()
	elif anim_name == &"fadeToNormal":
		color_rect.visible = false
		faded_to_normal.emit()

func fade_to_black() -> void:
	color_rect.visible = true
	animation_player.stop()
	animation_player.play("fadeToBlack")

func fade_to_normal() -> void:
	color_rect.visible = true
	animation_player.stop()
	animation_player.play("fadeToNormal")

func transition() -> void:
	fade_to_black()
