extends CharacterBody2D

@export var speed: float = 150.0
@export var slowed: bool = false

# --- Feuer ---
@export var projectile_scene: PackedScene
@onready var shoot_point: Marker2D = $ShootPoint

@export var shoot_range: float = 220.0      # ab welcher Distanz er schießt
@export var shoot_cooldown: float = 1.2
var shoot_timer: float = 0.0
# ------------

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var animated_sprite: AnimatedSprite2D = $Base_Sprite

var player: Node2D

func _ready() -> void:
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

	if slowed:
		speed = 50.0

func set_player(p: Node2D) -> void:
	player = p

func _physics_process(delta: float) -> void:
	if player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# cooldown runter
	shoot_timer = max(0.0, shoot_timer - delta)

	# Bewegung wie vorher (mit deinem -50 Offset)
	var dir: Vector2 = (player.global_position - global_position + Vector2(0, -50)).normalized()
	velocity = dir * speed

	# Flip + Animation wie vorher
	if velocity.x > 0.0:
		animated_sprite.flip_h = true
	elif velocity.x < 0.0:
		animated_sprite.flip_h = false

	animated_sprite.play("Move")
	move_and_slide()

	# --- Feuerspucken ---
	var dist := global_position.distance_to(player.global_position)
	if dist <= shoot_range and shoot_timer <= 0.0 and projectile_scene != null:
		shoot_timer = shoot_cooldown

		var p = projectile_scene.instantiate()
		p.source = self
		
		p.global_position = shoot_point.global_position

		# Richtung (mit leichtem Y-Offset wie du es hattest)
		p.dir = (player.global_position - shoot_point.global_position + Vector2(0, -20)).normalized()

		get_tree().current_scene.add_child(p)
		
