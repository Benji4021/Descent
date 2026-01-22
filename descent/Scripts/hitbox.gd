extends Area2D

@export var damage: int = 2

func _ready():
	monitoring = false
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		area.apply_damage(damage)
