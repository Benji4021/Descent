extends Area2D

@export var speed: float = 260.0
@export var damage: int = 2
@export var life_time: float = 1.5

var dir: Vector2 = Vector2.RIGHT

func _ready():
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	global_position += dir * speed * delta
	life_time -= delta
	if life_time <= 0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		area.apply_damage(damage)
		queue_free()
