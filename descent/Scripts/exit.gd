extends Node2D

@export var tile_size: int = 16

# Stelle sicher, dass diese Namen EXAKT wie in deinem Szenen-Baum geschrieben sind!
@onready var generator = $WalkerGenerator
@onready var player = $"../Player"
@onready var exit = $Exit

func _ready():
	# Signal verbinden, falls Exit und Player existieren
	if exit and player:
		exit.body_entered.connect(_on_exit_reached)
	
	generate_new_level()

func generate_new_level():
	
	# 1. Altes Level löschen
	if generator.has_method("erase"):
		generator.erase()
	
	# 2. Neuen Seed setzen (per set-Methode, um Fehler zu vermeiden)
	var new_seed = randi()
	if generator.settings:
		generator.settings.set("seed", new_seed)
	
	# 3. Dungeon generieren
	generator.generate()
	
	# 4. Kurze Pause für die Engine
	await get_tree().process_frame
	
	# 5. Positionen zurücksetzen (Spawnen aufeinander bei 0,0)
	player.global_position = Vector2.ZERO
	exit.global_position = Vector2(100, 100) # Ein kleiner Versatz, damit man den Exit sieht
	

func _on_exit_reached(body):
	if body == player:
		# Nutze call_deferred für einen sicheren Level-Wechsel
		call_deferred("generate_new_level")
