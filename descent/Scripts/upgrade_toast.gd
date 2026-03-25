extends CanvasLayer

@export var show_time: float = 4

@onready var label: Label = $Label

var _t: float = 0.0

func _ready() -> void:
	visible = false
	if label != null:
		label.text = ""

func show_message(text: String, duration: float = -1.0) -> void:
	if label == null:
		return
	label.text = text
	visible = true
	_t = duration if duration > 0.0 else show_time

func _process(delta: float) -> void:
	if not visible:
		return
	_t -= delta
	if _t <= 0.0:
		visible = false
