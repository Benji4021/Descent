extends CharacterBody2D

@export_group("Movement")
@export var run_speed: float = 160.0
@export var acceleration: float = 5.0
@export var friction: float = 4.0

@export_group("Combat")
@export var damage: int = 1
@export var attack_range: float = 35.0
@export var melee_cooldown: float = 0.8
@export var melee_active_time: float = 0.15

@export_group("Navigation")
@export var player_group: StringName = &"player"
@export var repath_time: float = 0.2
@export var stuck_repath_time: float = 0.35
@export var stuck_min_move_distance: float = 2.0

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var repath_timer: Timer = $PathfindingUpdateTimer
@onready var health: HealthComponent = $HealthComponent
@onready var hp_bar: ProgressBar = $HPBar
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var animated_sprite: AnimatedSprite2D = $Base_Sprite
@onready var melee_hitbox: Hitbox = $MeleeHitbox

signal killed(enemy)

enum State {
	CHASE,
	ATTACK,
	DEAD
}

var state: State = State.CHASE
var player: Node2D = null

var melee_cd_timer: float = 0.0
var melee_active_timer: float = 0.0
var attack_dir: Vector2 = Vector2.RIGHT

var last_pos: Vector2 = Vector2.ZERO
var stuck_timer: float = 0.0

func _ready() -> void:
	melee_hitbox.deactivate()
	melee_hitbox.set_damage(damage)

	hurtbox.health = health

	if not health.died.is_connected(_on_died):
		health.died.connect(_on_died)

	if not health.hp_changed.is_connected(_on_hp_changed):
		health.hp_changed.connect(_on_hp_changed)

	_on_hp_changed(health.hp, health.max_hp)

	repath_timer.wait_time = repath_time
	if not repath_timer.timeout.is_connected(_update_nav_target):
		repath_timer.timeout.connect(_update_nav_target)
	repath_timer.start()

	if not animated_sprite.animation_finished.is_connected(_on_base_sprite_animation_finished):
		animated_sprite.animation_finished.connect(_on_base_sprite_animation_finished)

	call_deferred("_acquire_player")
	last_pos = global_position

	if animated_sprite.sprite_frames.has_animation("Idle"):
		animated_sprite.play("Idle")

func _on_hp_changed(current: int, max_hp: int) -> void:
	if hp_bar == null:
		return

	hp_bar.max_value = max_hp
	hp_bar.value = current

func _resolve_player_target(node: Node) -> Node2D:
	var current: Node = node

	while current != null:
		if current is CharacterBody2D:
			return current as Node2D
		current = current.get_parent()

	return node as Node2D

func _acquire_player() -> void:
	var nodes: Array = get_tree().get_nodes_in_group(player_group)

	for node in nodes:
		var resolved: Node2D = _resolve_player_target(node)
		if resolved != null:
			player = resolved
			return

	player = null

func _update_nav_target() -> void:
	if state != State.CHASE:
		return

	if not is_instance_valid(player):
		_acquire_player()

	if is_instance_valid(player):
		nav_agent.target_position = player.global_position

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	if melee_cd_timer > 0.0:
		melee_cd_timer -= delta

	if melee_active_timer > 0.0:
		melee_active_timer -= delta
		if melee_active_timer <= 0.0:
			melee_hitbox.deactivate()

	if not is_instance_valid(player):
		_acquire_player()

	var has_player: bool = is_instance_valid(player)
	var dist: float = INF

	if has_player:
		dist = global_position.distance_to(player.global_position)

	match state:
		State.CHASE:
			if has_player and dist <= attack_range and melee_cd_timer <= 0.0:
				_start_attack()
			else:
				if has_player:
					var dir: Vector2 = _get_navigation_direction()
					velocity = velocity.move_toward(dir * run_speed, run_speed * acceleration * delta)
					_handle_stuck_repath(delta)
				else:
					_apply_friction(delta)
					stuck_timer = 0.0

		State.ATTACK:
			_apply_friction(delta)
			stuck_timer = 0.0

	move_and_slide()
	_handle_visuals()

	last_pos = global_position

func _get_navigation_direction() -> Vector2:
	if nav_agent.is_navigation_finished():
		if is_instance_valid(player):
			return global_position.direction_to(player.global_position)
		return Vector2.ZERO

	var next_path_pos: Vector2 = nav_agent.get_next_path_position()
	var dir: Vector2 = next_path_pos - global_position

	if dir.length() <= 1.0:
		if is_instance_valid(player):
			return global_position.direction_to(player.global_position)
		return Vector2.ZERO

	return dir.normalized()

func _handle_stuck_repath(delta: float) -> void:
	var moved: float = global_position.distance_to(last_pos)

	if velocity.length() > 5.0 and moved < stuck_min_move_distance:
		stuck_timer += delta
		if stuck_timer >= stuck_repath_time:
			stuck_timer = 0.0
			_update_nav_target()
	else:
		stuck_timer = 0.0

func _apply_friction(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, run_speed * friction * delta)

func _start_attack() -> void:
	if state != State.CHASE:
		return

	if not is_instance_valid(player):
		return

	melee_cd_timer = melee_cooldown
	state = State.ATTACK
	velocity = Vector2.ZERO

	attack_dir = (player.global_position - global_position).normalized()
	if attack_dir == Vector2.ZERO:
		attack_dir = Vector2.RIGHT

	animated_sprite.flip_h = attack_dir.x < 0.0
	animated_sprite.play("Attack")

	melee_hitbox.position = attack_dir * 10.0
	melee_hitbox.set_damage(damage)
	melee_hitbox.activate()
	melee_active_timer = melee_active_time

func _handle_visuals() -> void:
	if state == State.ATTACK:
		return

	if is_instance_valid(player):
		var to_player_x: float = player.global_position.x - global_position.x
		animated_sprite.flip_h = to_player_x < 0.0

	if velocity.length() > 10.0:
		if animated_sprite.animation != "Move":
			animated_sprite.play("Move")
	else:
		if animated_sprite.animation != "Idle":
			animated_sprite.play("Idle")

func _on_died() -> void:
	if state == State.DEAD:
		return

	state = State.DEAD
	melee_hitbox.deactivate()
	velocity = Vector2.ZERO
	emit_signal("killed", self)
	queue_free()

func _on_base_sprite_animation_finished() -> void:
	if state == State.ATTACK and animated_sprite.animation == "Attack":
		melee_hitbox.deactivate()
		state = State.CHASE
		_update_nav_target()
