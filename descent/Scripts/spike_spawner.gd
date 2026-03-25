extends Node2D

@export_group("Spikes")
@export var spike_scene: PackedScene
@export var spikes_count: int = 10

@export_group("Lava")
@export var lava_scene: PackedScene
@export var lava_count: int = 3

@export_group("Water")
@export var water_scene: PackedScene
@export var water_count: int = 3

@export_group("Settings")
@export var map_node_path: NodePath
@export var min_distance_to_player: float = 200.0

# Floor Einstellungen
@export var tilemap_layer: int = 0
@export var floor_terrain_id: int = 0

const FEATURE_GROUP: StringName = &"map_features"

var map: Node
var valid_cells: Array[Vector2i] = []
var floor_cell_set: Dictionary = {}
var occupied_tiles: Dictionary = {}

func _ready():
	map = get_node(map_node_path)
	if map.has_signal("level_generated"):
		map.level_generated.connect(_on_level_generated)
	else:
		push_error("Map hat kein level_generated Signal")

func _on_level_generated() -> void:
	_clear_existing_features()

	# Race-Condition Absicherung: Tilemap/Gaea-Render rendert teils deferred/threaded.
	await get_tree().process_frame
	await get_tree().process_frame

	_refresh_cells()
	if valid_cells.is_empty():
		return

	floor_cell_set.clear()
	occupied_tiles.clear()
	for c in valid_cells:
		floor_cell_set[c] = true

	# Kandidatenpool muss nicht "removed" werden, weil `occupied_tiles` Overlaps zwischen Hazard-Typen verhindert.
	_spawn_hazard(spike_scene, spikes_count)
	_spawn_hazard(lava_scene, lava_count)
	_spawn_hazard(water_scene, water_count)

func _clear_existing_features() -> void:
	for n in get_tree().get_nodes_in_group(FEATURE_GROUP):
		if is_instance_valid(n):
			n.queue_free()

func _refresh_cells() -> void:
	if not map.has_method("get_floor_cells"):
		push_error("Map hat keine get_floor_cells Methode")
		valid_cells.clear()
		return
	valid_cells = map.get_floor_cells(tilemap_layer, floor_terrain_id)

func _spawn_hazard(scene: PackedScene, count: int) -> void:
	if scene == null or count <= 0:
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var candidates: Array[Vector2i] = valid_cells.duplicate()
	candidates.shuffle()

	var spawned := 0
	for cell in candidates:
		if spawned >= count:
			break

		var world_pos: Vector2 = map.map_to_world(cell)
		if player != null and world_pos.distance_to(player.global_position) < min_distance_to_player:
			continue

		var hazard = scene.instantiate()
		hazard.global_position = world_pos
		get_tree().current_scene.add_child(hazard)
		hazard.add_to_group(FEATURE_GROUP)

		var footprint := _get_hazard_footprint_tiles(hazard)
		if _is_footprint_valid(footprint):
			_mark_occupied(footprint)
			spawned += 1
		else:
			hazard.queue_free()

func _world_to_map(world_pos: Vector2) -> Vector2i:
	# Map-Script stellt `tilemap` als @onready bereit.
	var tilemap: TileMap = map.tilemap
	return tilemap.local_to_map(tilemap.to_local(world_pos))

func _get_hazard_footprint_tiles(hazard: Node2D) -> Array[Vector2i]:
	var shapes := _collect_collision_shapes(hazard)
	if shapes.is_empty():
		return []

	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	var has_any_supported_shape := false

	for cs in shapes:
		if cs.shape == null:
			continue

		var local_corners: Array[Vector2] = []

		if cs.shape is RectangleShape2D:
			var r := cs.shape as RectangleShape2D
			var half := r.size * 0.5
			local_corners = [
				Vector2(-half.x, -half.y),
				Vector2(half.x, -half.y),
				Vector2(-half.x, half.y),
				Vector2(half.x, half.y),
			]
			has_any_supported_shape = true
		elif cs.shape is CircleShape2D:
			var c := cs.shape as CircleShape2D
			local_corners = [
				Vector2(-c.radius, -c.radius),
				Vector2(c.radius, -c.radius),
				Vector2(-c.radius, c.radius),
				Vector2(c.radius, c.radius),
			]
			has_any_supported_shape = true
		elif cs.shape is CapsuleShape2D:
			# Grobe AABB-Approximation einer Capsule.
			var cap := cs.shape as CapsuleShape2D
			var half_h := cap.height * 0.5
			var r := cap.radius
			local_corners = [
				Vector2(-r, -half_h),
				Vector2(r, -half_h),
				Vector2(-r, half_h),
				Vector2(r, half_h),
			]
			has_any_supported_shape = true
		else:
			continue

		var xform := cs.global_transform
		for p_local in local_corners:
			var p_world := xform * p_local
			min_x = min(min_x, p_world.x)
			min_y = min(min_y, p_world.y)
			max_x = max(max_x, p_world.x)
			max_y = max(max_y, p_world.y)

	if not has_any_supported_shape:
		return []

	# Tile-Range aus den AABB-Ecken ableiten (konservativ, dafür robust).
	var corners: Array[Vector2] = [
		Vector2(min_x, min_y),
		Vector2(min_x, max_y),
		Vector2(max_x, min_y),
		Vector2(max_x, max_y),
	]

	var corner_cells: Array[Vector2i] = []
	for wpos in corners:
		corner_cells.append(_world_to_map(wpos))

	var min_cell_x := corner_cells[0].x
	var min_cell_y := corner_cells[0].y
	var max_cell_x := corner_cells[0].x
	var max_cell_y := corner_cells[0].y

	for c in corner_cells:
		min_cell_x = min(min_cell_x, c.x)
		min_cell_y = min(min_cell_y, c.y)
		max_cell_x = max(max_cell_x, c.x)
		max_cell_y = max(max_cell_y, c.y)

	var footprint_tiles: Array[Vector2i] = []
	for x in range(min_cell_x, max_cell_x + 1):
		for y in range(min_cell_y, max_cell_y + 1):
			footprint_tiles.append(Vector2i(x, y))

	return footprint_tiles

func _collect_collision_shapes(root: Node) -> Array[CollisionShape2D]:
	var out: Array[CollisionShape2D] = []
	for child in root.get_children():
		if child is CollisionShape2D:
			out.append(child as CollisionShape2D)
		out.append_array(_collect_collision_shapes(child))
	return out

func _is_footprint_valid(footprint: Array[Vector2i]) -> bool:
	if footprint.is_empty():
		return false

	for t in footprint:
		# muss Floor sein
		if not floor_cell_set.has(t):
			return false
		# darf nicht mit anderen Hazards überlappen
		if occupied_tiles.has(t):
			return false
	return true

func _mark_occupied(footprint: Array[Vector2i]) -> void:
	for t in footprint:
		occupied_tiles[t] = true
