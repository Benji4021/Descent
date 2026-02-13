extends CharacterBody2D

@export var speed: float = 150.0
@export var slowed: bool = false

# Player automatisch holen (Player muss in Gruppe "player" sein)
@export var player_group: StringName = &"player"

# Navigation (wie im Video)
@export var repath_time: float = 0.15
@export var body_offset: Vector2 = Vector2(0, -50)

# Ranged Abstand halten
@export var keep_dist_min: float = 160.0   # wenn näher als das -> wegkiten
@export var keep_dist_max: float = 260.0   # wenn weiter als das -> näher ran
@export var stop_buffer: float = 20.0      # verhindert jitter an der grenze
@export var kite_extra: float = 30.0       # wie stark er "weg" zieht wenn zu nah

# --- Feuer ---
@export var projectile_scene: PackedScene
@onready var shoot_point: Marker2D = $ShootPoint
@export var shoot_range: float = 300.0     # sollte >= keep_dist_max sein
@export var shoot_cooldown: float = 1.2
@export var aim_offset: Vector2 = Vector2(0, -20)
var shoot_timer: float = 0.0
# ------------

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var repath_timer: Timer = $PathfindingUpdateTimer

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var animated_sprite: AnimatedSprite2D = $Base_Sprite

var player: Node2D


func _ready() -> void:
	hurtbox.health = health
	health.died.connect(_on_died)

	if slowed:
		speed = 50.0

	# Timer setup (wie im Video)
	repath_timer.wait_time = repath_time
	repath_timer.one_shot = false
	repath_timer.timeout.connect(_on_repath_timeout)

	# Player finden sobald alles im Tree ist
	call_deferred("_acquire_player")


func _acquire_player() -> void:
	var nodes := get_tree().get_nodes_in_group(player_group)
	if nodes.is_empty():
		push_warning("Enemy: kein Player in Gruppe '%s' gefunden." % [player_group])
		return

	player = nodes[0] as Node2D
	if player == null:
		push_warning("Enemy: Node in Gruppe '%s' ist kein Node2D." % [player_group])
		return

	_update_nav_target()
	repath_timer.start()


func _update_nav_target() -> void:
	if player == null:
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()

	# Zu nah -> weg (kite)
	if dist < keep_dist_min - stop_buffer:
		var away_dir := (-to_player).normalized()
		var desired_pos := global_position + away_dir * ((keep_dist_min - dist) + kite_extra)
		nav_agent.target_position = desired_pos
		return

	# Zu weit -> näher ran (aber nicht direkt in den Player rein)
	if dist > keep_dist_max + stop_buffer:
		var toward_dir := to_player.normalized()
		var desired_pos := (player.global_position + body_offset) - toward_dir * keep_dist_min
		nav_agent.target_position = desired_pos
		return

	# Idealbereich -> stehen bleiben (kein neues pathing)
	nav_agent.target_position = global_position


func _on_repath_timeout() -> void:
	_update_nav_target()


func _physics_process(delta: float) -> void:
	if player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# cooldown runter
	shoot_timer = max(0.0, shoot_timer - delta)

	# Wenn wir "stehen bleiben" wollen: wirklich stoppen
	if nav_agent.target_position.distance_to(global_position) < 2.0:
		velocity = Vector2.ZERO
	else:
		# Navigation-Move
		if not nav_agent.is_target_reached():
			var next_pos: Vector2 = nav_agent.get_next_path_position()
			var dir: Vector2 = (next_pos - global_position).normalized()
			velocity = dir * speed
		else:
			velocity = Vector2.ZERO

	# Flip + Animation
	if velocity.x > 0.0:
		animated_sprite.flip_h = true
	elif velocity.x < 0.0:
		animated_sprite.flip_h = false

	if velocity.length() > 0.1:
		animated_sprite.play("Move")
	# else: optional animated_sprite.play("Idle")

	move_and_slide()

	# --- Feuerspucken ---
	var dist := global_position.distance_to(player.global_position)
	if dist <= shoot_range and shoot_timer <= 0.0 and projectile_scene != null:
		shoot_timer = shoot_cooldown

		var p = projectile_scene.instantiate()
		p.source = self
		p.global_position = shoot_point.global_position
		p.dir = (player.global_position - shoot_point.global_position + aim_offset).normalized()

		get_tree().current_scene.add_child(p)


func _on_died() -> void:
	var manager = get_tree().current_scene
	queue_free()

	if manager and manager.has_method("check_enemies"):
		manager.check_enemies()
