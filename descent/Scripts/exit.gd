extends Node2D

signal level_generated

@export var tile_size: int = 16
@onready var tilemap: TileMap = $TileMap

@onready var generator = $WalkerGenerator
@export var player: CharacterBody2D
@onready var exit = $Exit

# Spawn-Helper (optional für Exit-Offset)
@export var exit_offset: Vector2 = Vector2(100, 0)

func _ready():
	if exit and player:
		exit.body_entered.connect(_on_exit_reached)

	generate_new_level()

func get_floor_cells(layer: int, terrain_id: int) -> Array[Vector2i]:
	var used := tilemap.get_used_cells(layer)
	print("USED CELLS:", used.size(), " layer:", layer)

	var result: Array[Vector2i] = []
	var sample_printed := false

	for cell: Vector2i in used:
		var data: TileData = tilemap.get_cell_tile_data(layer, cell)
		if data and not sample_printed:
			print("TERRAIN SAMPLE:", data.terrain)
			sample_printed = true

		if data and data.terrain == terrain_id:
			result.append(cell)

	print("FLOOR CELLS:", result.size(), " terrain_id:", terrain_id)
	return result


func generate_new_level():
	print("--- Generiere Level ---")
	_hide_exit()

	if generator.has_method("erase"):
		generator.erase()

	var new_seed: int = randi()
	if generator.settings:
		generator.settings.set("seed", new_seed)

	generator.generate()

	# WICHTIG: Generator braucht offenbar mehr als 1 Frame, bis die TileMap wirklich befüllt ist
	await get_tree().process_frame
	await get_tree().process_frame

	player.global_position = Vector2.ZERO

	print("Level generiert. Exit ist noch versteckt.")
	emit_signal("level_generated")

func map_to_world(cell: Vector2i) -> Vector2:
	# Zellkoordinate -> lokale Position -> globale Position
	return tilemap.to_global(tilemap.map_to_local(cell))


func _hide_exit() -> void:
	if not exit:
		return
	exit.visible = false
	exit.set_deferred("monitoring", false) # Area2D: verhindert triggern solange versteckt

func show_exit_near_player() -> void:
	if not exit or not player:
		return

	# Neben Spieler platzieren
	exit.global_position = player.global_position + exit_offset

	exit.visible = true
	exit.set_deferred("monitoring", true)

	print("Exit erscheint neben dem Spieler!")

func _on_exit_reached(body):
	if body == player:
		call_deferred("generate_new_level")
