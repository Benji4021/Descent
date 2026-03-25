extends Node2D

# Wir nutzen ein Dictionary oder separate Variablen für mehr Übersicht
@export_group("Spikes")
@export var spike_scene: PackedScene
@export var spikes_count: int = 10

@export_group("Lava")
@export var lava_scene: PackedScene
@export var lava_count: int = 5

@export_group("Water")
@export var water_scene: PackedScene
@export var water_count: int = 5

@export_group("Settings")
@export var map_node_path: NodePath
@export var min_distance_to_player: float = 200.0

var map: Node
var valid_cells: Array[Vector2i] = []

func _ready():
	map = get_node(map_node_path)
	if map.has_signal("level_generated"):
		map.level_generated.connect(_on_level_generated)

func _on_level_generated() -> void:
	await get_tree().process_frame # Warten bis Map fertig gerendert ist
	
	_refresh_cells()
	if valid_cells.is_empty(): return

	# Wir mischen die Zellen einmal am Anfang
	valid_cells.shuffle()

	# Spawne beides nacheinander
	_spawn_hazard(spike_scene, spikes_count)
	_spawn_hazard(lava_scene, lava_count)
	_spawn_hazard(water_scene, water_count)

func _refresh_cells() -> void:
	# Nutzt deine existierende Logik
	valid_cells = map.get_floor_cells(0, 0) 

func _spawn_hazard(scene: PackedScene, count: int) -> void:
	if scene == null: return

	var player = get_tree().get_first_node_in_group("player")
	var spawned = 0
	
	# Wir loopen durch die valid_cells
	# Wichtig: Wir entfernen genutzte Zellen, damit Spikes nicht in der Lava stehen
	var i = valid_cells.size() - 1
	while i >= 0 and spawned < count:
		var cell = valid_cells[i]
		var world_pos = map.map_to_world(cell)

		if player == null or world_pos.distance_to(player.global_position) >= min_distance_to_player:
			var hazard = scene.instantiate()
			hazard.global_position = world_pos
			get_tree().current_scene.add_child(hazard)
			
			spawned += 1
			valid_cells.remove_at(i) # Zelle besetzt, aus Pool entfernen
		
		i -= 1
