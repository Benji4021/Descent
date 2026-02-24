extends CharacterBody2D

@export var speed: float = 150.0
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var animated_sprite = $Base_Sprite

var player: Node2D

func _ready():
	# WICHTIG: Der Gegner muss in der Gruppe sein, damit der Manager ihn zählen kann
	add_to_group("enemies")
	
	hurtbox.health = health
	
	# Geänderte Verbindung: Wir rufen eine eigene Funktion auf statt nur queue_free
	health.died.connect(_on_died)

func _on_died():
	# Wir suchen den DungeonManager in der Szene
	# get_tree().current_scene greift auf die oberste Node deiner Main-Szene zu
	var manager = get_tree().current_scene 
	
	# Erst den Gegner löschen
	queue_free()
	
	# Dann dem Manager sagen, dass er prüfen soll
	if manager.has_method("check_enemies"):
		manager.check_enemies()

func set_player(p: Node2D) -> void:
	player = p

func _physics_process(delta: float) -> void:
	if player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dir = (player.global_position - global_position + Vector2(0,-50)).normalized()
	velocity = dir * speed
	if velocity.x > 0:
		animated_sprite.flip_h = true
	if velocity.x < 0:
		animated_sprite.flip_h = false
	animated_sprite.play("Move")
	move_and_slide()
