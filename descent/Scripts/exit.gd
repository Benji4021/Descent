extends Node2D

@export var tile_size: int = 16 
@export var enemy_count: int = 5 

# Referenzen zum Szenen-Baum
@onready var generator = $WalkerGenerator
@onready var player = $Player
@onready var exit = $Exit
@onready var enemy_spawner = $EnemySpawner

func _ready():
	if exit:
		exit.body_entered.connect(_on_exit_reached)
		exit.visible = false 
	generate_new_level()

func generate_new_level():
	if enemy_spawner:
		enemy_spawner.clear_enemies()
	
	if exit:
		exit.visible = false 
		exit.global_position = Vector2(-1000, -1000) 
	
	generator.erase()
	if generator.settings:
		generator.settings.set("seed", randi())
	generator.generate()
	
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	
	var cells = _get_cells_from_gaea()
	
	if cells.size() > 0:
		var cell_data = cells[0]
		var cell_vector = Vector2.ZERO

		if cell_data is Vector2 or cell_data is Vector2i:
			cell_vector = Vector2(cell_data)
		elif cell_data is Dictionary and cell_data.has("x"):
			cell_vector = Vector2(cell_data.x, cell_data.y)
		elif cell_data is int:
			if generator.grid.has_method("get_position_from_index"):
				cell_vector = generator.grid.get_position_from_index(cell_data)
			else:
				print("Konnte Index nicht umrechnen, nutze (0,0)")

		if player:
			player.global_position = cell_vector * tile_size + Vector2(tile_size/2, tile_size/2)
			enemy_spawner.spawn_enemies(cells, enemy_count, player)
	else:
		print("Fehler: Keine Grid-Daten gefunden!")

func check_enemies():
	await get_tree().process_frame
	var remaining = get_tree().get_nodes_in_group("enemies")
	if remaining.size() == 0:
		spawn_exit_at_player()

func spawn_exit_at_player():
	if exit and player:
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
