extends CharacterBody2D

## --- EXPORTS ---
@export_group("Movement")
@export var move_speed: float = 140.0
@export var acceleration: float = 8.0
@export var friction: float = 10.0

@export_group("Keep Distance")
@export var keep_min_range: float = 120.0   # wenn näher -> weg
@export var keep_max_range: float = 200.0   # wenn weiter -> hin
@export var retreat_distance: float = 140.0 # wie weit er beim Weglaufen als Zielpunkt nimmt

@export_group("Summon Skull")
@export var skull_scene: PackedScene        # im Inspector: BurningSkull.tscn reinziehen
@export var max_active_skulls: int = 1
@export var summon_cooldown: float = 2.4
@export var summon_windup: float = 0.45
@export var summon_only_when_in_band: bool = true # nur beschwören, wenn Distanz im Band ist
@export var spawn_jitter: float = 10.0             # kleine Zufallsabweichung beim Spawn

@export_group("Navigation")
@export var player_group: StringName = &"player"
@export var repath_time: float = 0.2

@export_group("Animations")
@export var anim_idle: StringName = &"Idle"
@export var anim_move: StringName = &"Move"
@export var anim_cast: StringName = &"Attack"  # du hast "Attack" in den Frames, das passt als Cast

## --- NODES ---
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var repath_timer: Timer = $PathfindingUpdateTimer

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox

@onready var sprite: AnimatedSprite2D = $Base_Sprite
@onready var shoot_point: Node2D = $ShootPoint

# Optional (für spätere Erweiterungen)
@onready var melee_hitbox: Area2D = $MeleeHitbox

## --- INTERNAL STATE ---
var player: Node2D

var casting: bool = false
var cast_timer: float = 0.0
var summon_cd_timer: float = 0.0

var last_dir_to_player: Vector2 = Vector2.RIGHT

var active_skulls: Array[Node2D] = []


func _ready() -> void:
	randomize()

	# Health wiring
	hurtbox.health = health
	health.died.connect(_on_died)

	# Hitbox für später erstmal aus
	melee_hitbox.monitoring = false

	# Repath timer
	repath_timer.wait_time = repath_time
	if not repath_timer.timeout.is_connected(_update_nav_target):
		repath_timer.timeout.connect(_update_nav_target)
	repath_timer.start()

	call_deferred("_acquire_player")


func _acquire_player() -> void:
	var nodes: Array = get_tree().get_nodes_in_group(player_group)
	if not nodes.is_empty():
		player = nodes[0] as Node2D


func _physics_process(delta: float) -> void:
	# Player re-acquire
	if not is_instance_valid(player):
		_acquire_player()

	# Cooldowns
	if summon_cd_timer > 0.0:
		summon_cd_timer -= delta

	# Casting state
	if casting:
		cast_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * friction * delta)
		move_and_slide()
		_handle_visuals()

		if cast_timer <= 0.0:
			casting = false
			_do_summon_skull()
		return

	# Ohne Player: idle
	if not is_instance_valid(player):
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * friction * delta)
		move_and_slide()
		_handle_visuals()
		return

	var dist: float = global_position.distance_to(player.global_position)
	var in_band: bool = (dist >= keep_min_range and dist <= keep_max_range)

	# Summon (nur 1 Skull aktiv)
	_cleanup_skulls()
	if summon_cd_timer <= 0.0 and _can_summon():
		if (not summon_only_when_in_band) or in_band:
			_start_cast()
			return

	# Abstand halten
	_maintain_distance(delta)

	move_and_slide()
	_handle_visuals()


func _maintain_distance(delta: float) -> void:
	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()

	if dist > 0.001:
		last_dir_to_player = to_player / dist

	var wants_move: bool = false
	var desired_target: Vector2 = global_position

	# zu nah -> weg
	if dist < keep_min_range:
		var away: Vector2 = (global_position - player.global_position).normalized()
		if away == Vector2.ZERO:
			away = -last_dir_to_player
		desired_target = global_position + away * retreat_distance
		wants_move = true

	# zu weit -> näher
	elif dist > keep_max_range:
		desired_target = player.global_position
		wants_move = true

	if not wants_move:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * friction * delta)
		return

	# Navigation bewegen
	nav_agent.target_position = desired_target
	if not nav_agent.is_navigation_finished():
		var next_pos: Vector2 = nav_agent.get_next_path_position()
		var dir: Vector2 = (next_pos - global_position).normalized()
		velocity = velocity.move_toward(dir * move_speed, move_speed * acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * friction * delta)


func _update_nav_target() -> void:
	# Optional: wir setzen das Target ohnehin im Maintain, daher ist das hier nur ein "Refresh"
	if casting:
		return
	if not is_instance_valid(player):
		return
	# no-op


func _start_cast() -> void:
	casting = true
	cast_timer = summon_windup
	summon_cd_timer = summon_cooldown

	velocity = Vector2.ZERO

	if sprite.sprite_frames and sprite.sprite_frames.has_animation(String(anim_cast)):
		sprite.play(String(anim_cast))


func _can_summon() -> bool:
	return skull_scene != null and active_skulls.size() < max_active_skulls


func _do_summon_skull() -> void:
	if skull_scene == null:
		return
	if not is_instance_valid(player):
		return

	_cleanup_skulls()
	if active_skulls.size() >= max_active_skulls:
		return

	var skull_node: Node = skull_scene.instantiate()
	var skull: Node2D = skull_node as Node2D
	if skull == null:
		return

	# Spawn pos: ShootPoint + bisschen jitter
	var jitter := Vector2(
		randf_range(-spawn_jitter, spawn_jitter),
		randf_range(-spawn_jitter, spawn_jitter)
	)

	var parent_node: Node = get_tree().current_scene
	if parent_node == null:
		parent_node = get_parent()

	parent_node.add_child(skull)
	skull.global_position = shoot_point.global_position + jitter

	active_skulls.append(skull)
	if not skull.tree_exited.is_connected(_on_skull_exited):
		skull.tree_exited.connect(_on_skull_exited)


func _on_skull_exited() -> void:
	_cleanup_skulls()


func _cleanup_skulls() -> void:
	var kept: Array[Node2D] = []
	for s in active_skulls:
		if is_instance_valid(s):
			kept.append(s)
	active_skulls = kept


func _handle_visuals() -> void:
	if not is_instance_valid(player):
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(String(anim_idle)):
			sprite.play(String(anim_idle))
		return

	var to_player_x: float = player.global_position.x - global_position.x
	sprite.flip_h = (to_player_x < 0.0)

	if casting:
		# anim_cast hat prio
		return

	if velocity.length() > 10.0:
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(String(anim_move)):
			sprite.play(String(anim_move))
	else:
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(String(anim_idle)):
			sprite.play(String(anim_idle))


func _on_died() -> void:
	queue_free()


# --------------------------------------------------------------------
# PLATZHALTER / SPÄTERE IDEEN (auskommentiert, wie gewünscht)
# --------------------------------------------------------------------

# func _try_bubble_delayed_aoe() -> void:
#     # Bubble als verzögerter Midrange-AOE:
#     # - cast -> marker am Ziel -> nach delay damage-area
#     # - perfekt zum alternieren mit Skull
#     pass

# func _bubble_shield_enable() -> void:
#     # Bubble als Schild:
#     # - während aktiv: Lich nimmt weniger/kein Schaden
#     # - Visual: Bubble Sprite/Shader an
#     pass

# func _bubble_shield_disable() -> void:
#     # Schild aus (nach duration oder nach X hits)
#     pass

# func _try_sword_melee() -> void:
#     # Nahkampf (wenn Player zu nah):
#     # - kurzer windup
#     # - MeleeHitbox kurz aktiv (wie Ghoul)
#     # - danach wieder kiten
#     pass

# func _alternate_spell_logic() -> void:
#     # später: abwechselnd Skull -> Bubble -> Skull -> Bubble ...
#     pass
