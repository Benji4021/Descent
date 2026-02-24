extends CanvasLayer


@export var heart_full: Texture2D
@export var heart_empty: Texture2D

@export var heart_spacing: int = 2
@export var heart_size: Vector2 = Vector2(16, 16) # an dein Pack anpassen

@onready var container: HBoxContainer = $HeartsContainer

var hearts: Array[TextureRect] = []

func set_max_hearts(max_hp: int) -> void:
	# alte Herzen löschen
	for c in container.get_children():
		c.queue_free()
	hearts.clear()

	container.add_theme_constant_override("separation", heart_spacing)

	# neue Herzen erstellen
	for i in range(max_hp):
		var tr := TextureRect.new()
		tr.texture = heart_empty
		tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tr.stretch_mode = TextureRect.STRETCH_SCALE  # skaliert die Textur auf die Control-Größe
		tr.custom_minimum_size = heart_size

		container.add_child(tr)
		hearts.append(tr)

func set_hearts(current_hp: int) -> void:
	for i in range(hearts.size()):
		hearts[i].texture = heart_full if i < current_hp else heart_empty
