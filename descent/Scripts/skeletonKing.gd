extends CharacterBody2D

@export_group("Movement")
@export var move_speed: float = 90.0
@export var acceleration: float = 4.0
@export var friction: float = 7.0

@export_group("Combat")
@export var damage: int = 1
@export var melee_cooldown: float = 2.0
@export var melee_active_time: float = 0.15

# Die doppelte Variable "melee_trigger_range" wurde hier entfernt, 
# da sie unten in der Melee-Gruppe erneut vorkommt.
@export var melee_windup_time: float = 0.12

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
@export var leap_obstacle_mask: int = 1

@export_group("Landing Hitbox")
@export var landing_capsule_radius: float = 14.0
@export var landing_capsule_height: float = 55.0
@export var landing_center_offset: float = 8.0
@export var capsule_rotation_offset: float = PI * 0.5

@export_group("Animation Offsets")
@export var idle_offset: Vector2 = Vector2.ZERO
@export var move_offset: Vector2 = Vector2.ZERO
@export var attack_offset: Vector2 = Vector2.ZERO
@export var point_offset: Vector2 = Vector2.ZERO
@export var leap_offset: Vector2 = Vector2(4,0)

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
@onready var melee_hitbox: Area2D = $MeleeHitbox
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
var already_hit: Dictionary = {}

var leap_start: Vector2
var leap_target: Vector2
var leap_progress: float = 0.0
var leap_blocked: bool = false
var leap_last_frame: int = 0

var base_shape: Shape2D
var melee_capsule := CapsuleShape2D.new()
var landing_capsule := CapsuleShape2D.new()

var sprite_rest_pos: Vector2
var current_anim: StringName = &""
var current_anim_offset: Vector2 = Vector2.ZERO

func _ready():
	melee_hitbox.monitoring = false
	hurtbox.health = health
	health.died.connect(_on_died)
	health.hp_changed.connect(_on_hp_changed)
	
	if health.hp:
		_on_hp_changed(health.hp, health.max_hp)

	sprite_rest_pos = animated_sprite.position
	base_shape = melee_shape.shape

	melee_capsule.radius = melee_capsule_radius
	melee_capsule.height = melee_capsule_height
	landing_capsule.radius = landing_capsule_radius
	landing_capsule.height = landing_capsule_height

	repath_timer.wait_time = repath_time
	repath_timer.timeout.connect(_update_nav_target)
	repath_timer.start()

	animated_sprite.animation_finished.connect(_on_animation_finished)
	melee_hitbox.area_entered.connect(_on_melee_hitbox_area_entered)

	call_deferred("_acquire_player")

	if upgrade_scene == null:
		upgrade_scene = load("res://Scenes/Upgrade.tscn")

	_set_visual_offset(idle_offset)
	_update_sprite_transform(0)

func _on_hp_changed(current: int, max_hp: int) -> void:
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current

func _acquire_player() -> void:
	var nodes = get_tree().get_nodes_in_group(player_group)
	if not nodes.is_empty():
		player = nodes[0]

func _update_nav_target():
	if state != State.CHASE: return
	if is_instance_valid(player):
		nav_agent.target_position = player.global_position

func _physics_process(delta):
	if attack_cd_timer > 0.0:
		attack_cd_timer -= delta

	if attack_active_timer > 0.0:
		attack_active_timer -= delta
		if attack_active_timer <= 0.0:
			_reset_hitbox()

	if not is_instance_valid(player):
		_acquire_player()
		if not is_instance_valid(player):
			_apply_friction(delta)
			move_and_slide()
			return

	var dist = global_position.distance_to(player.global_position)
	var hop_y = 0.0
	var use_move_and_slide = true

	match state:
		State.CHASE:
			if dist <= melee_trigger_range and attack_cd_timer <= 0:
				_start_melee()
			elif dist <= leap_trigger_range and dist >= leap_min_range and attack_cd_timer <= 0:
				_start_leap_point()
			else:
				if not nav_agent.is_navigation_finished():
					var next_pos = nav_agent.get_next_path_position()
					var dir = (next_pos - global_position).normalized()
					velocity = velocity.move_toward(dir * move_speed, move_speed * acceleration * delta)
				else:
					_apply_friction(delta)

		State.MELEE_WINDUP:
			_apply_friction(delta)
			# Logik für Windup-Dauer könnte hier über state_timer laufen

		State.MELEE_SWING:
			_apply_friction(delta)

		State.LEAP_POINT:
			_apply_friction(delta)
			state_timer -= delta
			if state_timer <= 0:
				_start_leap()

		State.LEAP:
			use_move_and_slide = false
			leap_progress += delta / leap_time
			var t = clamp(leap_progress, 0.0, 1.0)
			hop_y = -sin(t * PI) * leap_visual_height

			if not leap_blocked:
				var next = leap_start.lerp(leap_target, t)
				var motion = next - global_position
				var col = move_and_collide(motion)
				if col: leap_blocked = true
			
			if t >= 1.0:
				_start_leap_land()

		State.LEAP_LAND:
			_apply_friction(delta)
			state_timer -= delta
			if state_timer <= 0:
				_enter_recover()

		State.RECOVER:
			_apply_friction(delta)
			state_timer -= delta
			if state_timer <= 0:
				state = State.CHASE

	if use_move_and_slide:
		move_and_slide()

	if state == State.CHASE:
		_handle_idle_move()
	else:
		_set_facing_from_attack_dir()

	_update_sprite_transform(hop_y)

func _apply_friction(delta):
	velocity = velocity.move_toward(Vector2.ZERO, move_speed * friction * delta)

func _set_attack_dir():
	if is_instance_valid(player):
		attack_dir = (player.global_position - global_position).normalized()

func _set_facing_from_attack_dir():
	if attack_dir.x != 0:
		animated_sprite.flip_h = attack_dir.x < 0

func _set_facing_from_player():
	if is_instance_valid(player):
		var dx = player.global_position.x - global_position.x
		if dx != 0:
			animated_sprite.flip_h = dx < 0

func _set_visual_offset(o):
	current_anim_offset = o

func _get_facing_offset(o):
	if animated_sprite.flip_h:
		return Vector2(-o.x, o.y)
	return o

func _update_sprite_transform(extra_y):
	var facing_offset = _get_facing_offset(current_anim_offset)
	animated_sprite.position = sprite_rest_pos + facing_offset + Vector2(0, extra_y)

func _play_anim(anim, restart=false):
	if not animated_sprite.sprite_frames.has_animation(anim): return
	if not restart and current_anim == anim and animated_sprite.is_playing(): return
	current_anim = anim
	animated_sprite.play(anim)

func _handle_idle_move():
	_set_facing_from_player()
	if velocity.length() > 10:
		_set_visual_offset(move_offset)
		_play_anim(&"Move")
	else:
		_set_visual_offset(idle_offset)
		_play_anim(&"Idle")

func _start_melee():
	attack_cd_timer = melee_cooldown
	_set_attack_dir()
	state = State.MELEE_WINDUP
	_set_visual_offset(attack_offset)
	_play_anim(&"Attack", true)

func _start_melee_swing():
	state = State.MELEE_SWING
	melee_shape.shape = melee_capsule
	melee_hitbox.rotation = attack_dir.angle() + capsule_rotation_offset
	melee_hitbox.position = attack_dir * melee_center_offset
	melee_hitbox.monitoring = true
	attack_active_timer = melee_active_time
	already_hit.clear()

func _start_leap_point():
	attack_cd_timer = melee_cooldown
	_set_attack_dir()
	state = State.LEAP_POINT
	state_timer = 0.22
	_set_visual_offset(point_offset)
	_play_anim(&"Point", true)

func _start_leap():
	state = State.LEAP
	leap_progress = 0.0
	leap_blocked = false
	leap_start = global_position
	var dist = leap_start.distance_to(player.global_position)
	var travel = clamp(dist - desired_landing_gap, leap_min_distance, leap_max_distance)
	leap_target = leap_start + attack_dir * travel
	_set_visual_offset(leap_offset)
	_play_anim(&"Leap", true)
	leap_last_frame = animated_sprite.sprite_frames.get_frame_count("Leap") - 1

func _start_leap_land():
	state = State.LEAP_LAND
	state_timer = leap_land_time
	_set_visual_offset(leap_offset)
	_play_anim(&"Leap")
	animated_sprite.stop()
	animated_sprite.frame = leap_last_frame
	
	melee_shape.shape = landing_capsule
	melee_hitbox.rotation = attack_dir.angle() + capsule_rotation_offset
	melee_hitbox.position = attack_dir * landing_center_offset
	melee_hitbox.monitoring = true
	attack_active_timer = melee_active_time
	already_hit.clear()

func _enter_recover():
	state = State.RECOVER
	state_timer = 0.5 # Hier kannst du einen festen Wert oder eine Variable nutzen

func _reset_hitbox():
	melee_hitbox.monitoring = false
	melee_hitbox.rotation = 0
	melee_hitbox.position = Vector2.ZERO
	melee_shape.shape = base_shape

func _on_melee_hitbox_area_entered(area):
	if area.is_in_group(player_group) or area.name == "Hurtbox":
		var id = area.get_instance_id()
		if already_hit.has(id): return
		already_hit[id] = true
		if area.has_method("apply_damage"):
			area.apply_damage(damage)

func _on_animation_finished():
	match state:
		State.MELEE_WINDUP:
			_start_melee_swing()
		State.MELEE_SWING:
			_enter_recover()

func _on_died():
	state = State.DEAD
	velocity = Vector2.ZERO
	_reset_hitbox()
	_play_anim(&"Death", true)
	if upgrade_scene:
		var upgrade = upgrade_scene.instantiate()
		get_parent().add_child(upgrade)
		upgrade.global_position = global_position
