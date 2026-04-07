extends CharacterBody2D

@export_group("Movement")
@export var move_speed: float = 90.0
@export var acceleration: float = 4.0
@export var friction: float = 7.0

@export_group("Combat")
@export var damage: int = 1
@export var melee_cooldown: float = 2.0
@export var melee_active_time: float = 0.15
@export var recover_time: float = 0.5
@export var leap_point_time: float = 0.22

@export_group("Melee")
@export var melee_trigger_range: float = 52.0
@export var melee_commit_range: float = 62.0
@export var melee_capsule_radius: float = 10.0
@export var melee_capsule_height: float = 32.0
@export var melee_center_offset: float = 12.0

@export_group("Leap")
@export var leap_trigger_range: float = 180.0
@export var leap_min_range: float = 90.0
@export var leap_commit_min_range: float = 75.0
@export var leap_commit_max_range: float = 210.0
@export var leap_time: float = 0.78
@export var leap_visual_height: float = 12.0
@export var desired_landing_gap: float = 12.0
@export var leap_min_distance: float = 60.0
@export var leap_max_distance: float = 145.0
@export var leap_land_time: float = 0.22

@export_group("Landing Hitbox")
@export var landing_capsule_radius: float = 14.0
@export var landing_capsule_height: float = 55.0
@export var landing_center_offset: float = 8.0
@export var capsule_rotation_offset: float = PI * 0.5

@export_group("Animation Offsets")
@export var sprite_asset_offset: Vector2 = Vector2.ZERO
@export var idle_offset: Vector2 = Vector2.ZERO
@export var move_offset: Vector2 = Vector2.ZERO
@export var attack_offset: Vector2 = Vector2.ZERO
@export var point_offset: Vector2 = Vector2.ZERO
@export var leap_offset: Vector2 = Vector2(4, 0)

@export_group("Navigation")
@export var player_group: StringName = &"player"
@export var repath_time: float = 0.2

@export_group("Drops")
@export var upgrade_scene: PackedScene

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var repath_timer: Timer = $PathfindingUpdateTimer
@onready var health = $HealthComponent
@onready var hurtbox = $Hurtbox
@onready var animated_sprite: AnimatedSprite2D = $Base_Sprite
@onready var melee_hitbox = $MeleeHitbox
@onready var melee_shape: CollisionShape2D = $MeleeHitbox/CollisionShape2D
@onready var hp_bar: ProgressBar = $HPBar

enum State {
	CHASE,
	MELEE_WINDUP,
	MELEE_SWING,
	LEAP_POINT,
	LEAP,
	LEAP_LAND,
	RECOVER,
	DEAD
}

var state: State = State.CHASE
var player: Node2D = null

var attack_cd_timer: float = 0.0
var attack_active_timer: float = 0.0
var state_timer: float = 0.0

var attack_dir: Vector2 = Vector2.RIGHT

var leap_start: Vector2 = Vector2.ZERO
var leap_target: Vector2 = Vector2.ZERO
var leap_progress: float = 0.0
var leap_blocked: bool = false
var leap_last_frame: int = 0

var base_shape: Shape2D
var melee_capsule: CapsuleShape2D = CapsuleShape2D.new()
var landing_capsule: CapsuleShape2D = CapsuleShape2D.new()

var sprite_rest_pos: Vector2 = Vector2.ZERO
var current_anim: StringName = &""
var current_anim_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	if melee_hitbox.has_method("deactivate"):
		melee_hitbox.deactivate()
	else:
		melee_hitbox.monitoring = false

	if melee_hitbox.has_method("set_damage"):
		melee_hitbox.set_damage(damage)
	elif "damage" in melee_hitbox:
		melee_hitbox.damage = damage

	hurtbox.health = health

	if not health.died.is_connected(_on_died):
		health.died.connect(_on_died)

	if not health.hp_changed.is_connected(_on_hp_changed):
		health.hp_changed.connect(_on_hp_changed)

	_on_hp_changed(health.hp, health.max_hp)

	sprite_rest_pos = animated_sprite.position
	base_shape = melee_shape.shape

	melee_capsule.radius = melee_capsule_radius
	melee_capsule.height = melee_capsule_height
	landing_capsule.radius = landing_capsule_radius
	landing_capsule.height = landing_capsule_height

	repath_timer.wait_time = repath_time
	if not repath_timer.timeout.is_connected(_update_nav_target):
		repath_timer.timeout.connect(_update_nav_target)
	repath_timer.start()

	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)

	call_deferred("_acquire_player")

	if upgrade_scene == null:
		upgrade_scene = load("res://Scenes/Upgrade.tscn")

	_set_visual_offset(idle_offset)
	_play_anim(&"Idle", true)
	_update_sprite_transform(0.0)


func _on_hp_changed(current: int, max_hp: int) -> void:
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current


func _resolve_player_target(node: Node) -> Node2D:
	var current: Node = node

	while current != null:
		if current is CharacterBody2D:
			return current as Node2D
		current = current.get_parent()

	if node is Node2D:
		return node as Node2D

	return null


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

	if attack_cd_timer > 0.0:
		attack_cd_timer -= delta

	if attack_active_timer > 0.0:
		attack_active_timer -= delta
		if attack_active_timer <= 0.0:
			_reset_hitbox()

	if not is_instance_valid(player):
		_acquire_player()

	var has_player: bool = is_instance_valid(player)
	var dist: float = INF
	var hop_y: float = 0.0
	var use_move_and_slide: bool = true

	if has_player:
		dist = global_position.distance_to(player.global_position)

	match state:
		State.CHASE:
			if has_player and dist <= melee_trigger_range and attack_cd_timer <= 0.0:
				_start_melee()
			elif has_player and dist <= leap_trigger_range and dist >= leap_min_range and attack_cd_timer <= 0.0:
				_start_leap_point()
			else:
				if has_player and not nav_agent.is_navigation_finished():
					var next_pos: Vector2 = nav_agent.get_next_path_position()
					var dir: Vector2 = (next_pos - global_position).normalized()
					velocity = velocity.move_toward(dir * move_speed, move_speed * acceleration * delta)
				else:
					_apply_friction(delta)

		State.MELEE_WINDUP:
			_apply_friction(delta)

		State.MELEE_SWING:
			_apply_friction(delta)
			state_timer -= delta
			if state_timer <= 0.0:
				_enter_recover()

		State.LEAP_POINT:
			_apply_friction(delta)
			state_timer -= delta
			if state_timer <= 0.0:
				if has_player:
					dist = global_position.distance_to(player.global_position)
					if dist >= leap_commit_min_range and dist <= leap_commit_max_range:
						_start_leap()
					else:
						state = State.CHASE
						_update_nav_target()
				else:
					state = State.CHASE
					_update_nav_target()

		State.LEAP:
			use_move_and_slide = false
			leap_progress += delta / leap_time
			var t: float = clampf(leap_progress, 0.0, 1.0)
			hop_y = -sin(t * PI) * leap_visual_height

			if not leap_blocked:
				var next: Vector2 = leap_start.lerp(leap_target, t)
				var motion: Vector2 = next - global_position
				var col := move_and_collide(motion)
				if col:
					leap_blocked = true

			if t >= 1.0:
				_start_leap_land()

		State.LEAP_LAND:
			_apply_friction(delta)
			state_timer -= delta
			if state_timer <= 0.0:
				_enter_recover()

		State.RECOVER:
			_apply_friction(delta)
			state_timer -= delta
			if state_timer <= 0.0:
				state = State.CHASE
				_update_nav_target()

	if use_move_and_slide:
		move_and_slide()

	if state == State.CHASE:
		_handle_idle_move()
	elif state == State.RECOVER:
		_set_visual_offset(idle_offset)
		_play_anim(&"Idle")
		_set_facing_from_attack_dir()
	else:
		_set_facing_from_attack_dir()

	_update_sprite_transform(hop_y)


func _apply_friction(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, move_speed * friction * delta)


func _set_attack_dir() -> void:
	if is_instance_valid(player):
		attack_dir = (player.global_position - global_position).normalized()
		if attack_dir == Vector2.ZERO:
			attack_dir = Vector2.RIGHT


func _set_facing_from_attack_dir() -> void:
	if attack_dir.x != 0.0:
		animated_sprite.flip_h = attack_dir.x < 0.0


func _set_facing_from_player() -> void:
	if is_instance_valid(player):
		var dx: float = player.global_position.x - global_position.x
		if dx != 0.0:
			animated_sprite.flip_h = dx < 0.0


func _set_visual_offset(offset: Vector2) -> void:
	current_anim_offset = offset


func _get_facing_offset(offset: Vector2) -> Vector2:
	if animated_sprite.flip_h:
		return Vector2(-offset.x, offset.y)
	return offset


func _update_sprite_transform(extra_y: float) -> void:
	var combined_offset: Vector2 = sprite_asset_offset + current_anim_offset
	var facing_offset: Vector2 = _get_facing_offset(combined_offset)
	animated_sprite.position = sprite_rest_pos + facing_offset + Vector2(0.0, extra_y)


func _play_anim(anim: StringName, restart: bool = false) -> void:
	if not animated_sprite.sprite_frames.has_animation(anim):
		return

	if not restart and current_anim == anim and animated_sprite.is_playing():
		return

	current_anim = anim
	animated_sprite.play(anim)


func _handle_idle_move() -> void:
	_set_facing_from_player()

	if velocity.length() > 10.0:
		_set_visual_offset(move_offset)
		_play_anim(&"Move")
	else:
		_set_visual_offset(idle_offset)
		_play_anim(&"Idle")


func _start_melee() -> void:
	attack_cd_timer = melee_cooldown
	_set_attack_dir()
	state = State.MELEE_WINDUP
	velocity = Vector2.ZERO
	_set_visual_offset(attack_offset)
	_play_anim(&"Attack", true)


func _start_melee_swing() -> void:
	state = State.MELEE_SWING
	state_timer = recover_time
	velocity = Vector2.ZERO

	melee_shape.shape = melee_capsule
	melee_hitbox.rotation = attack_dir.angle() + capsule_rotation_offset
	melee_hitbox.position = attack_dir * melee_center_offset

	if melee_hitbox.has_method("set_damage"):
		melee_hitbox.set_damage(damage)
	elif "damage" in melee_hitbox:
		melee_hitbox.damage = damage

	if melee_hitbox.has_method("activate"):
		melee_hitbox.activate()
	else:
		melee_hitbox.monitoring = true

	attack_active_timer = melee_active_time


func _start_leap_point() -> void:
	attack_cd_timer = melee_cooldown
	_set_attack_dir()
	state = State.LEAP_POINT
	state_timer = leap_point_time
	velocity = Vector2.ZERO
	_set_visual_offset(point_offset)
	_play_anim(&"Point", true)


func _start_leap() -> void:
	if not is_instance_valid(player):
		state = State.CHASE
		_update_nav_target()
		return

	state = State.LEAP
	leap_progress = 0.0
	leap_blocked = false
	leap_start = global_position
	velocity = Vector2.ZERO

	var dist: float = leap_start.distance_to(player.global_position)
	var travel: float = clampf(dist - desired_landing_gap, leap_min_distance, leap_max_distance)
	leap_target = leap_start + attack_dir * travel

	_set_visual_offset(leap_offset)
	_play_anim(&"Leap", true)
	leap_last_frame = animated_sprite.sprite_frames.get_frame_count("Leap") - 1


func _start_leap_land() -> void:
	state = State.LEAP_LAND
	state_timer = maxf(leap_land_time, 0.01)
	velocity = Vector2.ZERO

	_set_visual_offset(leap_offset)
	_play_anim(&"Leap", true)
	animated_sprite.stop()
	animated_sprite.frame = leap_last_frame

	melee_shape.shape = landing_capsule
	melee_hitbox.rotation = attack_dir.angle() + capsule_rotation_offset
	melee_hitbox.position = attack_dir * landing_center_offset

	if melee_hitbox.has_method("set_damage"):
		melee_hitbox.set_damage(damage)
	elif "damage" in melee_hitbox:
		melee_hitbox.damage = damage

	if melee_hitbox.has_method("activate"):
		melee_hitbox.activate()
	else:
		melee_hitbox.monitoring = true

	attack_active_timer = melee_active_time


func _enter_recover() -> void:
	state = State.RECOVER
	state_timer = recover_time
	velocity = Vector2.ZERO
	_set_visual_offset(idle_offset)
	_play_anim(&"Idle", true)


func _reset_hitbox() -> void:
	if melee_hitbox.has_method("deactivate"):
		melee_hitbox.deactivate()
	else:
		melee_hitbox.monitoring = false

	melee_hitbox.rotation = 0.0
	melee_hitbox.position = Vector2.ZERO
	melee_shape.shape = base_shape


func _on_animation_finished() -> void:
	if state == State.DEAD:
		if animated_sprite.animation == &"Death":
			if upgrade_scene:
				var upgrade = upgrade_scene.instantiate()
				get_parent().add_child(upgrade)
				upgrade.global_position = global_position
			queue_free()
		return

	match state:
		State.MELEE_WINDUP:
			if is_instance_valid(player):
				var dist: float = global_position.distance_to(player.global_position)
				if dist <= melee_commit_range:
					_start_melee_swing()
				else:
					state = State.CHASE
					_update_nav_target()
			else:
				state = State.CHASE
				_update_nav_target()


func _on_died() -> void:
	if state == State.DEAD:
		return

	state = State.DEAD
	velocity = Vector2.ZERO
	_reset_hitbox()

	if repath_timer:
		repath_timer.stop()

	if hurtbox is Area2D:
		(hurtbox as Area2D).monitoring = false
		(hurtbox as Area2D).monitorable = false

	_play_anim(&"Death", true)
