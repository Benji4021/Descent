extends Node2D

@export var tile_size: int = 16 
@export var enemy_count: int = 5 

# Stelle sicher, dass diese Namen EXAKT wie in deinem Szenen-Baum geschrieben sind!
@onready var generator = $WalkerGenerator
@onready var player = $Player
@onready var exit = $Exit
@onready var enemy_spawner = $EnemySpawner # Referenz zum neuen Skript

func _ready():
	if exit:
		exit.body_entered.connect(_on_exit_reached)
		exit.visible = false # Exit am Anfang unsichtbar machen
	generate_new_level()

func generate_new_level():
	enemy_spawner.clear_enemies()
	
	if exit:
		exit.visible = false # Sicherstellen, dass er im neuen Level weg ist
		exit.global_position = Vector2(-1000, -1000) # Weit weg schieben
	
	generator.erase()
	if generator.settings:
		generator.settings.set("seed", randi())
	generator.generate()
	
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	
	var cells = _get_cells_from_gaea()
	
	if cells.size() > 0:
		player.global_position = Vector2(cells[0]) * tile_size + Vector2(tile_size/2, tile_size/2)
		# Den Exit platzieren wir hier NICHT mehr final, das passiert erst später.
		
		enemy_spawner.spawn_enemies(cells, enemy_count, player)
	else:
		print("Fehler: Keine Grid-Daten gefunden!")

# Diese Funktion wird von den Gegnern aufgerufen, wenn sie sterben
func check_enemies():
	# Wir warten einen Frame, damit queue_free() fertig ist
	await get_tree().process_frame
	
	var remaining = get_tree().get_nodes_in_group("enemies")
	if remaining.size() == 0:
		spawn_exit_at_player()

func spawn_exit_at_player():
	if exit and player:
		# Erscheint ein Stück versetzt neben dem Spieler
		exit.global_position = player.global_position + Vector2(48, 0)
		exit.visible = true
		print("Alle Gegner besiegt! Exit erscheint.")

func _get_cells_from_gaea() -> Array:
	if not generator.grid: return []
	if "_grid" in generator.grid: return generator.grid._grid.keys()
	if "grid_data" in generator.grid: return generator.grid.grid_data.keys()
	return []

func _on_exit_reached(body):
	if body == player:
		call_deferred("generate_new_level")
