extends Area2D
class_name Hurtbox

@export var health: HealthComponent

func apply_damage(amount: int) -> void:
	if health:
		health.take_damage(amount)
