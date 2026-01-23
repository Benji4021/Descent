extends Node2D

@export var enemy_scene: PackedScene # Hier die Enemy.tscn im Inspektor zuweisen
@export var tile_size: int = 16

func clear_enemies():
	# Sucht alle Gegner in der Gruppe und löscht sie
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()

func spawn_enemies(cells: Array, count: int):
	if not enemy_scene:
		print("Fehler: Keine Enemy-Szene im Spawner zugewiesen!")
		return

	for i in range(count):
		var random_tile = cells[randi() % cells.size()]
		var spawn_pos = Vector2(random_tile) * tile_size + Vector2(tile_size/2, tile_size/2)
		
		var new_enemy = enemy_scene.instantiate()
		new_enemy.add_to_group("enemies")
		add_child(new_enemy)
		new_enemy.global_position = spawn_pos
