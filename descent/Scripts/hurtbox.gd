extends Area2D
class_name Hurtbox

@export var health: HealthComponent

func apply_damage(amount: int) -> void:
	if amount <= 0:
		return

	var owner_node := get_parent()

	if owner_node != null:
		if owner_node.has_method("should_ignore_damage"):
			if owner_node.call("should_ignore_damage"):
				return

		if owner_node.has_method("modify_incoming_damage"):
			amount = int(owner_node.call("modify_incoming_damage", amount))
			if amount <= 0:
				return

	if health:
		health.take_damage(amount)
