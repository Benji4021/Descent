extends Area2D

@export var speed: float = 250.0
@export var damage: int = 2
@export var life_time: float = 1.0

# Wer soll getroffen werden?
# "player" = trifft nur Player-Hurtbox
# "enemy"  = trifft nur Enemy-Hurtbox
@export var target_group: StringName = &"player"

@onready var sprite: Sprite2D = $Sprite2D

var dir: Vector2 = Vector2.RIGHT
var source: Node = null


func _ready() -> void:
	area_entered.connect(_on_area_entered)

	# Dein Sprite schaut standardmäßig nach links -> 180° Offset
	rotation = dir.angle() + PI

func _physics_process(delta: float) -> void:
	global_position += dir * speed * delta
	life_time -= delta
	if life_time <= 0.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if not (area is Hurtbox):
		return

	var root := area.owner
	if root == null:
		return

	# Selbsttreffer vermeiden
	if source != null and root == source:
		return

	# Nur gewünschtes Ziel treffen
	if not root.is_in_group(target_group):
		return

	(area as Hurtbox).apply_damage(damage)
	queue_free()

	
func _on_body_entered(body: Node) -> void:
	#var owner_node: Node = body.get_parent()
	if source != null and body == source:
		return
	queue_free()
	#Bei jeder Wand / jedem Body verschwinden
