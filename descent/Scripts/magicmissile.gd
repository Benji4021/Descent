extends Area2D

@export var speed: float = 250.0
@export var damage: int = 2
@export var life_time: float = 1
@export var target_group: StringName = &"enemy"

@onready var sprite : Sprite2D = $Sprite2D

var dir: Vector2 = Vector2.RIGHT


func _ready():
	area_entered.connect(_on_area_entered)
#	if dir.x > 0:
#		sprite.flip_h = true
	rotation = dir.angle() + PI


func _physics_process(delta: float) -> void:
	global_position += dir * speed * delta
	life_time -= delta
	if life_time <= 0.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	# Nur Hurtboxes treffen
	if not (area is Hurtbox):
		return

	# Hurtbox-Owner (z.B. Player/Enemy Node) prüfen
	var owner_node: Node = area.get_parent()
	if owner_node == null:
		return

	# Nur gewünschtes Ziel treffen
	if not owner_node.is_in_group(target_group):
		return

	area.apply_damage(damage)
	queue_free()
