extends CharacterBody2D

## --- EXPORTS ---
@export_group("Movement")
@export var run_speed: float = 160.0
@export var stroll_speed: float = 60.0
@export var acceleration: float = 4.0
@export var friction: float = 3.0
@export var slowed: bool = false

@export_group("Navigation & Kiting")
@export var player_group: StringName = &"player"
@export var repath_time: float = 0.2
@export var keep_dist_min: float = 170.0
@export var keep_dist_max: float = 250.0
@export var target_update_threshold: float = 30.0

@export_group("Combat")
@export var projectile_scene: PackedScene
@export var shoot_range: float = 310.0
@export var shoot_cooldown: float = 4
@export var aim_offset: Vector2 = Vector2(0, -20)

## --- NODES ---
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var animated_sprite: AnimatedSprite2D = $Base_Sprite
@onready var shoot_point: Marker2D = $ShootPoint
@onready var hp_bar: ProgressBar = $HPBar   # <- NEU

## --- INTERNAL STATE ---
var player: Node2D
var shoot_timer: float = 0.0
var strafe_dir: int = 1
var strafe_timer: float = 0.0
var source: Node2D  

enum State { IDLE, CHASING, KITING, STROLLING }
var current_state: State = State.IDLE


func _ready() -> void:
	
	if self.name.contains("FireDemon") and projectile_scene == null:
		projectile_scene = load("res://Scenes/Fireball.tscn")

	hurtbox.health = health
	health.died.connect(_on_died)

	# HP BAR
	health.hp_changed.connect(_on_hp_changed)
	_on_hp_changed(health.hp, health.max_hp)

	if slowed:
		run_speed *= 0.5
		stroll_speed *= 0.5

	nav_agent.path_desired_distance = 25.0
	nav_agent.target_desired_distance = 40.0
	
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = repath_time
	timer.timeout.connect(_update_nav_target)
	timer.start()

	call_deferred("_acquire_player")


func _on_hp_changed(current: int, max_hp: int) -> void:
	if hp_bar == null:
		return
	
	hp_bar.max_value = max_hp
	hp_bar.value = current


func _acquire_player() -> void:
	var nodes = get_tree().get_nodes_in_group(player_group)
	if not nodes.is_empty():
		player = nodes[0]


func _update_nav_target() -> void:
	if not is_instance_valid(player): return

	var to_player = player.global_position - global_position
	var dist = to_player.length()
	
	strafe_timer -= repath_time
	if strafe_timer <= 0.0:
		strafe_timer = randf_range(2.0, 4.0)
		strafe_dir = [-1, 1].pick_random()

	var forward = to_player.normalized()
	var right = Vector2(-forward.y, forward.x) * strafe_dir
	var wanted_pos: Vector2

	if dist > keep_dist_max:
		current_state = State.CHASING
		wanted_pos = player.global_position
	elif dist < keep_dist_min:
		current_state = State.KITING
		wanted_pos = global_position - forward * 100.0 + right * 60.0
	else:
		current_state = State.STROLLING
		wanted_pos = global_position + right * 50.0

	var snapped_pos = _snap_to_nav(wanted_pos)

	if snapped_pos.distance_to(nav_agent.target_position) > target_update_threshold:
		nav_agent.target_position = snapped_pos


func _snap_to_nav(pos: Vector2) -> Vector2:
	return NavigationServer2D.map_get_closest_point(get_world_2d().navigation_map, pos)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		velocity = velocity.move_toward(Vector2.ZERO, run_speed * friction * delta)
		move_and_slide()
		return

	var current_max_speed = stroll_speed
	if current_state == State.CHASING or current_state == State.KITING:
		current_max_speed = run_speed
	
	var target_velocity = Vector2.ZERO
	
	if not nav_agent.is_navigation_finished():
		var next_path_pos = nav_agent.get_next_path_position()
		var dir = (next_path_pos - global_position).normalized()
		target_velocity = dir * current_max_speed
	
	if target_velocity.length() > 0:
		velocity = velocity.move_toward(target_velocity, run_speed * acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, run_speed * friction * delta)
	
	move_and_slide()

	_handle_visuals()
	_handle_combat(delta)


func _handle_visuals() -> void:
	var to_player_x = player.global_position.x - global_position.x
	animated_sprite.flip_h = (to_player_x > 0)

	if velocity.length() > 15.0:
		animated_sprite.play("Move")
		animated_sprite.speed_scale = velocity.length() / stroll_speed
	else:
		animated_sprite.play("idle")
		animated_sprite.speed_scale = 1.0


func _handle_combat(delta: float) -> void:
	shoot_timer = max(0.0, shoot_timer - delta)
	var dist = global_position.distance_to(player.global_position)
	
	if dist <= shoot_range and shoot_timer <= 0.0 and projectile_scene != null:
		_shoot()


func _shoot() -> void:
	shoot_timer = shoot_cooldown
	if projectile_scene == null: return
	
	var p = projectile_scene.instantiate()
	p.global_position = shoot_point.global_position
	
	var target_dir = (player.global_position + aim_offset - shoot_point.global_position).normalized()
	
	if "dir" in p:
		p.dir = target_dir 
	
	get_tree().current_scene.add_child(p)


func _on_died() -> void:
	var manager = get_tree().current_scene
	if manager and manager.has_method("check_enemies"):
		manager.check_enemies()
	queue_free()
