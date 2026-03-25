extends Area2D

@export var speed: float = 250.0
@export var damage: int = 2
@export var life_time: float = 1.0

# Wen darf das Projektil treffen?
# z.B. Enemy-Projectile: target_group="player"
# Player-Projectile:     target_group="enemy"
@export var target_group: StringName = &"player"
var source: Node2D
# Wen soll es komplett ignorieren? (Friendly fire aus)
# z.B. Enemy-Projectile: ignore_group="enemy"
# Player-Projectile:     ignore_group="player"
@export var ignore_group: StringName = &"enemy"

# Wen soll es komplett ignorieren? (Friendly fire aus)
# z.B. Enemy-Projectile: ignore_group="enemy"
# Player-Projectile:     ignore_group="player"
@export var ignore_group: StringName = &"enemy"

@onready var sprite: Sprite2D = $Sprite2D

var dir: Vector2 = Vector2.RIGHT


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	rotation = dir.angle() + PI


func _physics_process(delta: float) -> void:
	global_position += dir * speed * delta
	life_time -= delta
	if life_time <= 0.0:
		queue_free()


# Prüft: ist node ODER irgendein Parent in einer Gruppe?
func _is_in_group_or_parent(node: Node, group_name: StringName) -> bool:
	var n: Node = node
	while n != null:
		if n.is_in_group(group_name):
			return true
		n = n.get_parent()
	return false


func _on_area_entered(area: Area2D) -> void:
	if not (area is Hurtbox):
		return

	# Friendly-fire: eigene Seite komplett ignorieren
	if _is_in_group_or_parent(area, ignore_group):
		return

	# Nur gewünschtes Ziel treffen
	if not _is_in_group_or_parent(area, target_group):
		return

	(area as Hurtbox).apply_damage(damage)
	queue_free()


func _on_body_entered(body: Node) -> void:
	# Wenn das ein "eigener" Enemy/Player-Körper ist -> ignorieren (nicht verschwinden)
	if _is_in_group_or_parent(body, ignore_group):
		return

	# Sonst (Wand/Obstacle/Tilemap etc.) -> verschwinden
	queue_free()
