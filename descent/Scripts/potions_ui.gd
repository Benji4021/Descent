extends CanvasLayer
class_name PotionsUI

@export var potion_full: Texture2D
@export var potion_empty: Texture2D   # optional, kann null sein

@export var max_slots: int = 10        # wie viele Slots du anzeigen willst
@export var icon_size: Vector2 = Vector2(16, 16)
@export var icon_spacing: int = 2
@export var show_empty_slots: bool = true

@onready var container: HBoxContainer = $PotionsContainer

var icons: Array[TextureRect] = []

func _ready() -> void:
	container.add_theme_constant_override("separation", icon_spacing)
	_rebuild()

func _rebuild() -> void:
	for c in container.get_children():
		c.queue_free()
	icons.clear()

	var count := max_slots if show_empty_slots else 0
	if not show_empty_slots:
		# wenn du keine leeren Slots willst, bauen wir dynamisch in set_potions
		return

	for i in range(count):
		var tr := TextureRect.new()
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.custom_minimum_size = icon_size
		tr.texture = potion_empty if potion_empty != null else null
		container.add_child(tr)
		icons.append(tr)

func set_max_slots(slots: int) -> void:
	max_slots = max(0, slots)
	if show_empty_slots:
		_rebuild()

func set_potions(current: int) -> void:
	current = max(current, 0)

	if show_empty_slots:
		# fixed slots, fill/empty
		for i in range(icons.size()):
			icons[i].texture = potion_full if i < current else (potion_empty if potion_empty != null else null)
	else:
		# only show as many icons as potions
		for c in container.get_children():
			c.queue_free()
		for i in range(current):
			var tr := TextureRect.new()
			tr.stretch_mode = TextureRect.STRETCH_SCALE
			tr.custom_minimum_size = icon_size
			tr.texture = potion_full
			container.add_child(tr)


func _on_player_potions_changed(current: int) -> void:
	pass # Replace with function body.
