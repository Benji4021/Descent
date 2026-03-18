extends Node2D

@export var player_scene: PackedScene
@export var map_node_path: NodePath

@export var tilemap_layer: int = 0
@export var floor_terrain_id: int = 0

var map: Node
var player: CharacterBody2D


func _ready() -> void:
	map = get_node(map_node_path)

	if map.has_signal("level_generated"):
		map.level_generated.connect(_on_level_generated)
	else:
		push_error("Map hat kein level_generated Signal")


func _on_level_generated() -> void:
	# alten Player entfernen (bei neuem Level)
	if player != null:
		player.queue_free()

	# warten bis Tiles wirklich gesetzt sind
	await get_tree().process_frame
	await get_tree().process_frame

	spawn_player()


func spawn_player() -> void:
	if not map.has_method("get_floor_cells"):
		push_error("Map hat keine get_floor_cells() Methode")
		return

	var cells: Array[Vector2i] = map.get_floor_cells(tilemap_layer, floor_terrain_id)

	if cells.is_empty():
		push_error("Keine Floor Tiles für Player Spawn gefunden")
		return

	var spawn_cell: Vector2i = cells.pick_random()
	var world_pos: Vector2 = map.map_to_world(spawn_cell)

	player = player_scene.instantiate()
	player.global_position = world_pos

	get_tree().current_scene.add_child(player)
	player.add_to_group("player")
