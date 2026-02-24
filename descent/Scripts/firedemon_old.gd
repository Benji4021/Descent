extends CharacterBody2D

@export var speed: float = 150.0
@export var slowed: bool = false

# Abstand / Verhalten
@export var min_range: float = 60.0     # zu nah -> weg
@export var max_range: float = 160.0     # zu weit -> hin
@export var shoot_min: float = 90.0     # idealer schussbereich start
@export var shoot_max: float = 130.0     # idealer schussbereich ende

# Schießen
@export var shoot_cooldown: float = 1.2
@export var projectile_scene: PackedScene

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var animated_sprite: AnimatedSprite2D = $Base_Sprite
@onready var shoot_point: Marker2D = $ShootPoint   # Marker2D als Kind hinzufügen!

var player: Node2D = null
var shoot_timer: float = 0.0

enum State { CHASE, KEEP_DISTANCE, SHOOT }
var state: State = State.CHASE

func _ready() -> void:
	hurtbox.health = health
	health.died.connect(func(): queue_free())

	if slowed:
		speed = 50.0

func set_player(p: Node2D) -> void:
	player = p

func _physics_process(delta: float) -> void:
	if player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# cooldown runterzählen
	if shoot_timer > 0.0:
		shoot_timer -= delta

	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()

	# --- State decision ---
	if dist < min_range:
		state = State.KEEP_DISTANCE
	elif dist > max_range:
		state = State.CHASE
	elif dist >= shoot_min and dist <= shoot_max:
		state = State.SHOOT
	else:
		# reposition zwischen min..shoot_min oder shoot_max..max
		state = State.CHASE if dist > shoot_max else State.KEEP_DISTANCE

	# --- Verhalten ---
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

	# Flip + Animation
	if velocity.x > 0.0:
		animated_sprite.flip_h = true
	elif velocity.x < 0.0:
		animated_sprite.flip_h = false

	if state == State.SHOOT:
		animated_sprite.play("Idle") # falls kein Idle: "Move" nehmen
	else:
		animated_sprite.play("Move")

	move_and_slide()

func _try_shoot() -> void:
	if shoot_timer > 0.0:
		return
	if projectile_scene == null:
		return
	if shoot_point == null:
		return

	shoot_timer = shoot_cooldown

	var p = projectile_scene.instantiate()
	p.source = self

	# dir vor add_child setzen (damit _ready() im Projektil korrekt rotieren kann)
	var d: Vector2 = (player.global_position - shoot_point.global_position).normalized()
	p.dir = d
	p.global_position = shoot_point.global_position

	get_tree().current_scene.add_child(p)
