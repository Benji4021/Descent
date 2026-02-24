extends Node2D

signal level_generated

@export var tile_size: int = 16
@onready var tilemap: TileMap = $TileMap
@onready var TransitionScreen = $TransitionScreen
@onready var generator = $WalkerGenerator
@export var player: CharacterBody2D
@onready var exit = $Exit

# Floor-Settings (müssen zu deinem TileSet/Terrain passen!)
@export var floor_layer: int = 0
@export var floor_terrain_id: int = 0

# Exit: "neben Player" -> wir suchen um den Player herum in einem kleinen Radius
@export var exit_search_radius_tiles: int = 6   # z.B. 6 Tiles um den Player herum
@export var exit_min_distance_tiles: int = 1    # nicht exakt im Player-Tile
@export var exit_spawn_tries: int = 60          # wie viele Kandidaten wir testen

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
	TransitionScreen.transition()
	await TransitionScreen.on_transition_finished
	# Generator braucht offenbar mehr als 1 Frame, bis die TileMap wirklich befüllt ist
	await get_tree().process_frame
	await get_tree().process_frame

	player.global_position = Vector2.ZERO

	print("Level generiert. Exit ist noch versteckt.")
	emit_signal("level_generated")

func map_to_world(cell: Vector2i) -> Vector2:
	# Zellkoordinate -> lokale Position -> globale Position
	return tilemap.to_global(tilemap.map_to_local(cell))

func world_to_map(pos: Vector2) -> Vector2i:
	# globale Position -> lokale -> Zellkoordinate
	return tilemap.local_to_map(tilemap.to_local(pos))

func _hide_exit() -> void:
	if not exit:
		return
	exit.visible = false
	exit.set_deferred("monitoring", false)

func _is_floor_cell(cell: Vector2i) -> bool:
	var data: TileData = tilemap.get_cell_tile_data(floor_layer, cell)
	return data != null and data.terrain == floor_terrain_id

func _get_nearby_candidate_cells(center: Vector2i) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []

	# Wir sammeln Zellen in einem Quadrat um den Player,
	# filtern später nach Distanz + Floor
	for y in range(center.y - exit_search_radius_tiles, center.y + exit_search_radius_tiles + 1):
		for x in range(center.x - exit_search_radius_tiles, center.x + exit_search_radius_tiles + 1):
			candidates.append(Vector2i(x, y))

	return candidates

func show_exit_near_player() -> void:
	if not exit or not player:
		return

	exit.visible = false
	exit.set_deferred("monitoring", false)

	# Player-Zelle bestimmen
	var player_cell: Vector2i = world_to_map(player.global_position)

	# Kandidaten in der Nähe holen und mischen (random)
	var candidates: Array[Vector2i] = _get_nearby_candidate_cells(player_cell)
	candidates.shuffle()

	var min_dist := float(exit_min_distance_tiles)
	var tries: int = mini(exit_spawn_tries, candidates.size())


	# 1) Nah am Player: nur Floor + Distanz>=min
	for i in range(tries):
		var cell := candidates[i]

		# Distanz in Tile-Einheiten (Manhattan oder Euclid; hier Euclid)
		var d := Vector2(cell - player_cell).length()
		if d < min_dist:
			continue

		if _is_floor_cell(cell):
			exit.global_position = map_to_world(cell)
			exit.visible = true
			exit.set_deferred("monitoring", true)
			print("Exit neben Player gespawnt bei:", cell)
			return

	# 2) Fallback: wenn direkt in der Nähe nix passt -> irgendein Floor-Tile
	var floor_cells: Array[Vector2i] = get_floor_cells(floor_layer, floor_terrain_id)
	if floor_cells.is_empty():
		push_error("Exit: Keine Floor-Zellen gefunden. Prüfe floor_layer/floor_terrain_id.")
		return

	var fallback_cell: Vector2i = floor_cells.pick_random()
	exit.global_position = map_to_world(fallback_cell)
	exit.visible = true
	exit.set_deferred("monitoring", true)
	print("Exit-Fallback gespawnt bei:", fallback_cell)

func _on_exit_reached(body):
	if body == player:
		call_deferred("generate_new_level")
