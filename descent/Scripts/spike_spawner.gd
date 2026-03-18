extends Node2D

@export var spike_scene: PackedScene
@export var spikes_per_level: int = 10
@export var map_node_path: NodePath

# Floor Einstellungen
@export var tilemap_layer: int = 0
@export var floor_terrain_id: int = 0
@export var min_distance_to_player: float = 200.0

var map: Node
var valid_cells: Array[Vector2i] = []

func _ready():
	map = get_node(map_node_path)

	if map.has_signal("level_generated"):
		map.level_generated.connect(_on_level_generated)
	else:
		push_error("Map hat kein level_generated Signal")

func _on_level_generated() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	_refresh_cells()

	if valid_cells.is_empty():
		push_error("Keine Floor Tiles gefunden")
		return

	_spawn_spikes()

func _refresh_cells() -> void:
	if not map.has_method("get_floor_cells"):
		push_error("Map hat keine get_floor_cells Methode")
		valid_cells.clear()
		return

	valid_cells = map.get_floor_cells(tilemap_layer, floor_terrain_id)

func _spawn_spikes() -> void:
	if spike_scene == null:
		push_error("spike_scene nicht gesetzt")
		return

	var player: Node2D = get_tree().get_first_node_in_group("player")

	var cells = valid_cells.duplicate()
	cells.shuffle()

	var spawned := 0

	for cell in cells:
		if spawned >= spikes_per_level:
			break

		var world_pos: Vector2 = map.map_to_world(cell)

		if player == null or world_pos.distance_to(player.global_position) >= min_distance_to_player:

			var spike = spike_scene.instantiate()
			spike.global_position = world_pos
			get_tree().current_scene.add_child(spike)

			spawned += 1
