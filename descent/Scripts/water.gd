extends Area2D

@export var tick_speed := 0.5 # Sekunden zwischen Updates (für Extinguish refresh)

@onready var timer: Timer = $EffectTimer

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	timer.wait_time = tick_speed
	timer.timeout.connect(_apply_effects)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("set_in_water"):
			body.call("set_in_water", true)
		if body.has_method("extinguish"):
			body.call("extinguish")
		timer.start()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("set_in_water"):
			body.call("set_in_water", false)
		timer.stop()

func _apply_effects() -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			if body.has_method("extinguish"):
				body.call("extinguish")
