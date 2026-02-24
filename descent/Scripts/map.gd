extends Node2D

@onready var tilemap: TileMap = $TileMap

func get_floor_cells(layer: int, terrain_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	
	for cell in tilemap.get_used_cells(layer):
		var data = tilemap.get_cell_tile_data(layer, cell)
		if data and data.terrain == terrain_id:
			result.append(cell)
	
	return result

func map_to_world(cell: Vector2i) -> Vector2:
	return tilemap.to_global(tilemap.map_to_local(cell))
