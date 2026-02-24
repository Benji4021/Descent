extends Node2D

@export var enemy_scene: PackedScene
@export var map_node_path: NodePath

# Floor-Spawn
@export var tilemap_layer: int = 0
@export var floor_terrain_id: int = 0
@export var min_distance_to_player: float = 250.0

# Wellen-System
@export var base_waves: int = 1                 # Start: wie viele Wellen im ersten Level
@export var waves_increase_per_level: int = 1   # pro Level +1 Welle
@export var enemies_per_wave_base: int = 1      # Gegner pro Welle (Basis)
@export var enemies_per_wave_increase: int = 1  # pro zusätzlicher Welle mehr Gegner

@export var time_between_spawns: float = 0.25   # Spawn-Abstand innerhalb einer Welle
@export var time_between_waves: float = 30     # Pause zwischen Wellen

var map: Node
var valid_cells: Array[Vector2i] = []

var level_index: int = 0
var total_waves_this_level: int = 0
var current_wave: int = 0
var alive_enemies: int = 0
var spawning_wave: bool = false

func _ready():
	map = get_node(map_node_path)

	if map.has_signal("level_generated"):
		map.level_generated.connect(_on_level_generated)
	else:
		push_error("Map hat kein Signal level_generated")

func _on_level_generated() -> void:
	level_index += 1

	get_tree().call_group("enemy", "queue_free")
	alive_enemies = 0

	# WICHTIG: warten bis TileMap wirklich gefüllt ist
	await get_tree().process_frame
	await get_tree().process_frame  # bei deinem Generator oft nötig

	_refresh_cells()
	print("REFRESH valid_cells:", valid_cells.size())

	# wenn immer noch leer -> nicht starten
	if valid_cells.is_empty():
		push_error("Keine Floor-Zellen gefunden. Prüfe Layer/Terrain oder Generator-Timing.")
		return

	total_waves_this_level = base_waves + (level_index - 1) * waves_increase_per_level
	current_wave = 0

	print("Level:", level_index, " Wellen:", total_waves_this_level)
	_start_next_wave()


func _refresh_cells() -> void:
	if not map.has_method("get_floor_cells"):
		push_error("Map hat keine get_floor_cells(layer, terrain_id).")
		valid_cells.clear()
		return

	valid_cells = map.get_floor_cells(tilemap_layer, floor_terrain_id)

func _start_next_wave() -> void:
	if spawning_wave:
		return

	current_wave += 1

	if current_wave > total_waves_this_level:
		# Keine Wellen mehr -> wenn keine Gegner leben -> Exit zeigen
		_check_end_condition()
		return

	spawning_wave = true

	# Gegneranzahl pro Welle skalieren
	var enemies_this_wave: int = enemies_per_wave_base + (current_wave - 1) * enemies_per_wave_increase

	print("Starte Welle", current_wave, "mit", enemies_this_wave, "Gegnern")

	_spawn_wave_async(enemies_this_wave)

func _spawn_wave_async(count: int) -> void:
	# asynchron ohne extra Timer-Nodes
	call_deferred("_spawn_wave_coroutine", count)

func _spawn_wave_coroutine(count: int) -> void:
	for i in range(count):
		_spawn_one_enemy()
		await get_tree().create_timer(time_between_spawns).timeout

	spawning_wave = false

	# Nach jeder Welle warten, dann nächste starten
	await get_tree().create_timer(time_between_waves).timeout
	_start_next_wave()

func _spawn_one_enemy() -> void:
	if enemy_scene == null:
		push_error("enemy_scene ist NULL – im Inspector nicht gesetzt!")
		return

	if valid_cells.is_empty():
		push_error("valid_cells ist leer – get_floor_cells liefert nichts.")
		return

	var player: Node2D = get_tree().get_first_node_in_group("player")
	var tries: int = 20

	while tries > 0:
		var cell: Vector2i = valid_cells.pick_random()
		var world_pos: Vector2 = map.map_to_world(cell)

		if player == null or world_pos.distance_to(player.global_position) >= min_distance_to_player:
			var enemy = enemy_scene.instantiate()
			enemy.global_position = world_pos
			get_tree().current_scene.add_child(enemy)

			enemy.add_to_group("enemy")
			alive_enemies += 1
			enemy.tree_exited.connect(_on_enemy_exited)
			return

		tries -= 1

	print("Kein geeigneter Spawnplatz gefunden.")


func _on_enemy_exited() -> void:
	alive_enemies -= 1
	_check_end_condition()


func _check_end_condition() -> void:
	# Exit nur dann, wenn:
	# - alle Wellen gestartet sind UND
	# - keine Gegner mehr leben UND
	# - gerade keine Welle spawnt
	if current_wave >= total_waves_this_level and alive_enemies <= 0 and not spawning_wave:
		if map.has_method("show_exit_near_player"):
			map.show_exit_near_player()
		else:
			push_error("Map hat keine show_exit_near_player()-Methode.")
