extends Area2D
class_name Hitbox

@export var damage: int = 1

func _ready() -> void:
	monitoring = false

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func activate() -> void:
	monitoring = false
	set_deferred("monitoring", true)

func deactivate() -> void:
	monitoring = false

func set_damage(value: int) -> void:
	damage = value

func add_damage(amount: int) -> void:
	damage += amount

func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		(area as Hurtbox).apply_damage(damage)
