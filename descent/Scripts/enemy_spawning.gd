extends Node2D

@export var enemy_scenes: Array[PackedScene] = []
@export var boss_scenes: Array[PackedScene] = []
@export var map_node_path: NodePath

# Floor-Spawn
@export var tilemap_layer: int = 0
@export var floor_terrain_id: int = 0
@export var min_distance_to_player: float = 250.0

# Wellen-System
@export var base_waves: int = 1
@export var waves_increase_per_level: int = 1
@export var enemies_per_wave_base: int = 1
@export var enemies_per_wave_increase: int = 1

@export var time_between_spawns: float = 0.25
@export var time_between_waves: float = 30

var map: Node
var valid_cells: Array[Vector2i] = []

var level_index: int = 0
var total_waves_this_level: int = 0
var current_wave: int = 0 
var alive_enemies: int = 0
var spawning_wave: bool = false
var boss_spawned_this_level: bool = false

func _ready():
	map = get_node(map_node_path)
	if map.has_signal("level_generated"):
		map.level_generated.connect(_on_level_generated)

func _on_level_generated() -> void:
	level_index += 1
	boss_spawned_this_level = false
	
	# Sicherer Zugriff auf den Tree zum Aufräumen
	var tree = get_tree()
	if tree:
		tree.call_group("enemy", "queue_free")
	
	alive_enemies = 0

	# Warten bis TileMap stabil ist
	await get_tree().process_frame
	await get_tree().process_frame 

	_refresh_cells()

	if valid_cells.is_empty():
		return

	total_waves_this_level = base_waves + (level_index - 1) * waves_increase_per_level
	current_wave = 0
	_start_next_wave()

func _refresh_cells() -> void:
	if map and map.has_method("get_floor_cells"):
		valid_cells = map.get_floor_cells(tilemap_layer, floor_terrain_id)

func _start_next_wave() -> void:
	if spawning_wave: return
	current_wave += 1

	if current_wave > total_waves_this_level:
		_check_end_condition()
		return

	spawning_wave = true
	var count = enemies_per_wave_base + (current_wave - 1) * enemies_per_wave_increase
	_spawn_wave_async(count)

func _spawn_wave_async(count: int) -> void:
	call_deferred("_spawn_wave_coroutine", count)

func _spawn_wave_coroutine(count: int) -> void:
	for i in range(count):
		if not is_inside_tree(): return
		_spawn_one_enemy()
		await get_tree().create_timer(time_between_spawns).timeout

	spawning_wave = false
	if current_wave < total_waves_this_level:
		await get_tree().create_timer(time_between_waves).timeout
		if is_inside_tree(): _start_next_wave()
	else:
		_check_end_condition()

func _spawn_one_enemy() -> void:
	if enemy_scenes.is_empty() or valid_cells.is_empty(): return

	# SICHERER CHECK: Existiert ein Player?
	var player = _get_player_safe()
	var tries: int = 20

	while tries > 0:
		var cell = valid_cells.pick_random()
		var world_pos = map.map_to_world(cell)

		# Wenn player == null, wird der zweite Teil (distance_to) gar nicht erst geprüft (Short-circuit)
		if player == null or world_pos.distance_to(player.global_position) >= min_distance_to_player:
			var enemy = enemy_scenes.pick_random().instantiate()
			enemy.global_position = world_pos
			get_tree().current_scene.add_child(enemy)
			_register_enemy(enemy)
			return
		tries -= 1

func _spawn_boss() -> void:
	if boss_scenes.is_empty() or valid_cells.is_empty(): return

	var player = _get_player_safe()
	var tries := 30

	while tries > 0:
		var cell = valid_cells.pick_random()
		var world_pos = map.map_to_world(cell)

		if player == null or world_pos.distance_to(player.global_position) >= min_distance_to_player:
			var boss = boss_scenes.pick_random().instantiate()
			boss.global_position = world_pos
			get_tree().current_scene.add_child(boss)
			boss.add_to_group("boss")
			_register_enemy(boss)
			return
		tries -= 1

func _register_enemy(enemy: Node2D) -> void:
	enemy.add_to_group("enemy")
	alive_enemies += 1
	enemy.tree_exited.connect(_on_enemy_exited)

func _on_enemy_exited() -> void:
	# Verhindert Fehler beim Beenden des Spiels
	if not is_inside_tree(): return
	
	alive_enemies -= 1
	_check_end_condition.call_deferred()

func _check_end_condition() -> void:
	if not is_inside_tree(): return
	
	var waves_done = (current_wave >= total_waves_this_level and not spawning_wave)
	
	if waves_done:
		if alive_enemies <= 0 and not boss_spawned_this_level:
			boss_spawned_this_level = true
			_spawn_boss()
		elif alive_enemies <= 0 and boss_spawned_this_level:
			if map.has_method("show_exit_near_player"):
				map.show_exit_near_player()

# Die Rettung: Prüft sicher, ob ein Player da ist
func _get_player_safe() -> Node2D:
	var tree = get_tree()
	if not tree: return null
	
	var nodes = tree.get_nodes_in_group("player")
	if nodes.size() > 0:
		return nodes[0] as Node2D
	return null
