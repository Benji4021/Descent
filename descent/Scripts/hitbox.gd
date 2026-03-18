# res://Scripts/hitbox.gd
extends Area2D

@export var damage: int = 2

func _ready() -> void:
	monitoring = false
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		area.apply_damage(damage)

func add_damage(amount: int) -> void:
	damage += amount
