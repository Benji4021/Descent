extends Node2D

signal level_generated

@export var tile_size: int = 16

@onready var tilemap: TileMap = $TileMap
@onready var TransitionScreen = $TransitionScreen
@onready var generator = $WalkerGenerator
@onready var exit = $Exit

@export var floor_layer: int = 0
@export var floor_terrain_id: int = 0

@export var exit_search_radius_tiles: int = 6
@export var exit_min_distance_tiles: int = 1
@export var exit_spawn_tries: int = 60

var _is_generating: bool = false

func _ready() -> void:
	if exit:
		exit.body_entered.connect(_on_exit_reached)

	generate_new_level()

func _resolve_player_target(node: Node) -> Node2D:
	var current: Node = node

	while current != null:
		if current is CharacterBody2D:
			return current as Node2D

		current = current.get_parent()

	return node as Node2D

func _get_player_root() -> Node2D:
	var nodes := get_tree().get_nodes_in_group("player")

	for node in nodes:
		var resolved := _resolve_player_target(node)
		if resolved != null:
			return resolved

	return null

func get_floor_cells(layer: int, terrain_id: int) -> Array[Vector2i]:
	var used := tilemap.get_used_cells(layer)
	var result: Array[Vector2i] = []

	for cell: Vector2i in used:
		var data: TileData = tilemap.get_cell_tile_data(layer, cell)
		if data and data.terrain == terrain_id:
			result.append(cell)

	return result

func generate_new_level() -> void:
	if _is_generating:
		return

	_is_generating = true
	_hide_exit()

	if TransitionScreen:
		TransitionScreen.fade_to_black()
		await TransitionScreen.faded_to_black

	if generator.has_method("erase"):
		generator.erase()

	var new_seed: int = randi()
	if generator.settings:
		generator.settings.set("seed", new_seed)

	generator.generate()

	await get_tree().process_frame
	await get_tree().process_frame

	NavigationServer2D.map_force_update(get_world_2d().navigation_map)
	NavigationServer2D.map_force_update(get_world_2d().navigation_map)

	emit_signal("level_generated")

	if TransitionScreen:
		TransitionScreen.fade_to_normal()

	_is_generating = false

func map_to_world(cell: Vector2i) -> Vector2:
	return tilemap.to_global(tilemap.map_to_local(cell))

func world_to_map(pos: Vector2) -> Vector2i:
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

	for y in range(center.y - exit_search_radius_tiles, center.y + exit_search_radius_tiles + 1):
		for x in range(center.x - exit_search_radius_tiles, center.x + exit_search_radius_tiles + 1):
			candidates.append(Vector2i(x, y))

	return candidates

func show_exit_near_player() -> void:
	var tree := get_tree()
	if tree == null:
		return

	var player := _get_player_root()

	if not exit or player == null:
		return

	exit.visible = false
	exit.set_deferred("monitoring", false)

	var player_cell: Vector2i = world_to_map(player.global_position)

	var candidates: Array[Vector2i] = _get_nearby_candidate_cells(player_cell)
	candidates.shuffle()

	var min_dist := float(exit_min_distance_tiles)
	var tries: int = min(exit_spawn_tries, candidates.size())

	for i in range(tries):
		var cell := candidates[i]
		var d := Vector2(cell - player_cell).length()

		if d < min_dist:
			continue

		if _is_floor_cell(cell):
			exit.global_position = map_to_world(cell)
			exit.visible = true
			exit.set_deferred("monitoring", true)
			return

	var floor_cells: Array[Vector2i] = get_floor_cells(floor_layer, floor_terrain_id)

	if floor_cells.is_empty():
		push_error("Exit: Keine Floor-Zellen gefunden. Prüfe floor_layer/floor_terrain_id.")
		return

	var fallback_cell: Vector2i = floor_cells.pick_random()
	exit.global_position = map_to_world(fallback_cell)
	exit.visible = true
	exit.set_deferred("monitoring", true)

func _on_exit_reached(body: Node) -> void:
	if _is_generating:
		return

	var player := _get_player_root()
	if player == null:
		return

	if body == player:
		call_deferred("generate_new_level")
