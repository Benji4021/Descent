extends Area2D
class_name Pickup

@export var item_data: InvItem

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_apply_item()
	body_entered.connect(_on_body_entered)

func set_item(data: InvItem) -> void:
	item_data = data
	if is_node_ready():
		_apply_item()

func _apply_item() -> void:
	if item_data == null:
		return
	sprite.texture = item_data.icon

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	# TODO: hier in dein Inventar legen:
	# Global.inventory.add(item_data, 1)
	# oder SignalBus.emit_signal("pickup_item", item_data)

	queue_free()
