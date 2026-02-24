extends CharacterBody2D

# --- Exportierte Variablen ---
@export var speed: float = 150.0
@export var slowed: bool = false

# Abstand / Verhalten
@export var min_range: float = 60.0      # zu nah -> weg
@export var max_range: float = 160.0     # zu weit -> hin
@export var shoot_min: float = 90.0      # idealer schussbereich start
@export var shoot_max: float = 130.0     # idealer schussbereich ende

# Schießen
@export var shoot_cooldown: float = 1.2
@export var projectile_scene: PackedScene

# --- Nodes ---
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var animated_sprite: AnimatedSprite2D = $Base_Sprite
@onready var shoot_point: Marker2D = $ShootPoint

# --- Logik Variablen ---
var player: Node2D = null
var shoot_timer: float = 0.0

enum State { CHASE, KEEP_DISTANCE, SHOOT }
var state: State = State.CHASE

func _ready() -> void:
	# 1. Setup Komponenten
	hurtbox.health = health
	health.died.connect(func(): queue_free())

	if slowed:
		speed = 50.0

	# 2. Spieler automatisch finden (ersetzt den Code der Test-Scene)
	# Wir suchen in der aktuellen Szene nach einem Node namens "Player"
	_find_player()

func _find_player() -> void:
	# Sucht den Spieler im Scene Tree (effizienter als get_tree().get_nodes_in_group())
	#player = get_tree().current_scene.find_child("Player", true, false)
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	# Alternative falls du Gruppen nutzt (empfohlen):
	# var players = get_tree().get_nodes_in_group("Player")
	# if players.size() > 0: player = players[0]

func _physics_process(delta: float) -> void:
	# Falls kein Spieler da ist (oder er gestorben ist), bleib stehen
	if not is_instance_valid(player):
		_find_player()
		if not is_instance_valid(player):
			velocity = Vector2.ZERO
			move_and_slide()
			return

	# Cooldown runterzählen
	if shoot_timer > 0.0:
		shoot_timer -= delta

	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()

	# --- State Entscheidung ---
	if dist < min_range:
		state = State.KEEP_DISTANCE
	elif dist > max_range:
		state = State.CHASE
	elif dist >= shoot_min and dist <= shoot_max:
		state = State.SHOOT
	else:
		# Reposition zwischen min..shoot_min oder shoot_max..max
		state = State.CHASE if dist > shoot_max else State.KEEP_DISTANCE

	# --- Verhalten ausführen ---
	var dir: Vector2 = Vector2.ZERO

	match state:
		State.CHASE:
			dir = to_player.normalized()
		State.KEEP_DISTANCE:
			dir = (-to_player).normalized()
		State.SHOOT:
			dir = Vector2.ZERO
			_try_shoot()

	velocity = dir * speed

	# --- Animation & Visuals ---
	_update_visuals()
	move_and_slide()

func _update_visuals() -> void:
	# Flip basierend auf Bewegungsrichtung (oder Spielerposition)
	if velocity.x > 0.0:
		animated_sprite.flip_h = true
	elif velocity.x < 0.0:
		animated_sprite.flip_h = false

	# Animation abspielen
	if state == State.SHOOT:
		animated_sprite.play("Idle") 
	else:
		animated_sprite.play("Move")

func _try_shoot() -> void:
	if shoot_timer > 0.0 or projectile_scene == null or shoot_point == null:
		return

	shoot_timer = shoot_cooldown

	var p = projectile_scene.instantiate()
	
	# Richtung zum Spieler berechnen
	var d: Vector2 = (player.global_position - shoot_point.global_position).normalized()
	
	# Projektil-Daten setzen
	p.global_position = shoot_point.global_position
	if "dir" in p:
		p.dir = d
	
	get_tree().current_scene.add_child(p)
