extends Area2D

@export var damage := 999

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var health = body.get_node("HealthComponent")
		if health != null:
			health.take_damage(damage)
