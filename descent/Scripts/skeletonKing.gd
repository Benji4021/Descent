extends CharacterBody2D

## --- EXPORTS ---
@export_group("Movement")
@export var run_speed: float = 160.0
@export var acceleration: float = 5.0
@export var friction: float = 4.0

@export_group("Combat")
@export var damage: int = 1
@export var melee_cooldown: float = 0.8
@export var melee_active_time: float = 0.15

# Close Melee (damit er wieder normal angreift)
@export var melee_trigger_range: float = 55.0     # <= das: normaler Nahkampf
@export var melee_windup_time: float = 0.12       # kleines Ausholen für Melee

# Melee-Hitbox (kleines Oval)
@export var melee_capsule_radius: float = 10.0
@export var melee_capsule_height: float = 32.0
@export var melee_center_offset: float = 10.0     # leicht nach vorne Richtung Spieler

@export_group("Jump Attack (Topdown)")
@export var windup_time: float = 0.30             # >= 0.3s (Schwert zeigen)
@export var leap_time: float = 0.67               # 0.67s (Hop-Dauer)

# Jump soll aus weiter weg starten (damit es NICHT wie Nahkampf aussieht)
@export var jump_trigger_range: float = 170.0     # <= das: Jump ist erlaubt
@export var jump_min_range: float = 80.0          # < das: KEIN Jump (sonst wirkt's wie melee)

# Wie weit er beim Jump nach vorne kommt (dynamisch)
@export var desired_landing_gap: float = 10.0     # er landet knapp vor dem Spieler
@export var leap_min_distance: float = 55.0
@export var leap_max_distance: float = 140.0

# Visual Hop (nur Sprite nach oben/unten)
@export var jump_visual_height: float = 10.0
@export var recover_time: float = 0.10

# Collision-Maske für Wände/Hindernisse (stell passend zu deinen Wall-Layern ein!)
@export var leap_obstacle_mask: int = 1

# Landing-AOE Hitbox (großes Oval inkl. Schwert)
@export var landing_capsule_radius: float = 14.0
@export var landing_capsule_height: float = 55.0
@export var landing_center_offset: float = 8.0
# CapsuleShape2D ist standardmäßig "vertikal" -> meist +PI/2, damit sie in Angriffsrichtung liegt
@export var capsule_rotation_offset: float = PI * 0.5

@export_group("Navigation")
@export var player_group: StringName = &"player"
@export var repath_time: float = 0.2

@export_group("Drops")
@export var upgrade_scene: PackedScene

## --- NODES ---
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var repath_timer: Timer = $PathfindingUpdateTimer
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var animated_sprite: AnimatedSprite2D = $Base_Sprite
@onready var melee_hitbox: Area2D = $MeleeHitbox
@onready var melee_shape: CollisionShape2D = $MeleeHitbox/CollisionShape2D

## --- INTERNAL STATE ---
var player: Node2D

enum AttackState { NONE, WINDUP, LEAP, RECOVER }
enum AttackType { NONE, MELEE, JUMP }

var attack_state: AttackState = AttackState.NONE
var attack_type: AttackType = AttackType.NONE

var melee_cd_timer: float = 0.0
var melee_active_timer: float = 0.0

var windup_timer: float = 0.0
var leap_t: float = 0.0
var recover_timer: float = 0.0

var attack_dir: Vector2 = Vector2.ZERO
var already_hit: Dictionary = {}

# Leap motion (Dash)
var leap_start: Vector2 = Vector2.ZERO
var leap_target: Vector2 = Vector2.ZERO
var leap_blocked: bool = false

# Shapes: original vs. melee oval vs landing oval
var base_shape: Shape2D
var melee_shape_capsule: CapsuleShape2D = CapsuleShape2D.new()
var landing_shape: CapsuleShape2D = CapsuleShape2D.new()

# Visual hop
var sprite_rest_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	melee_hitbox.monitoring = false

	hurtbox.health = health
	health.died.connect(_on_died)

	sprite_rest_pos = animated_sprite.position

	# Backup + configure capsules
	base_shape = melee_shape.shape

	melee_shape_capsule.radius = melee_capsule_radius
	melee_shape_capsule.height = melee_capsule_height

	landing_shape.radius = landing_capsule_radius
	landing_shape.height = landing_capsule_height

	# Repath timer
	repath_timer.wait_time = repath_time
	if not repath_timer.timeout.is_connected(_update_nav_target):
		repath_timer.timeout.connect(_update_nav_target)
	repath_timer.start()

	call_deferred("_acquire_player")
	
	if upgrade_scene == null:
		upgrade_scene = load("res://Scenes/Upgrade.tscn") as PackedScene


func _acquire_player() -> void:
	var nodes: Array = get_tree().get_nodes_in_group(player_group)
	if not nodes.is_empty():
		player = nodes[0] as Node2D


func _update_nav_target() -> void:
	if not is_instance_valid(player): return
	if attack_state != AttackState.NONE: return
	nav_agent.target_position = player.global_position


func _physics_process(delta: float) -> void:
	# Cooldown
	if melee_cd_timer > 0.0:
		melee_cd_timer -= delta

	# Hitbox window
	if melee_active_timer > 0.0:
		melee_active_timer -= delta
		if melee_active_timer <= 0.0:
			_reset_hitbox()

	# Sprite Y reset (wenn nicht im Hop)
	if attack_state != AttackState.LEAP:
		animated_sprite.position = sprite_rest_pos

	if not is_instance_valid(player):
		_apply_friction(delta)
		move_and_slide()
		return

	var dist: float = global_position.distance_to(player.global_position)
	var use_move_and_slide: bool = true

	match attack_state:
		AttackState.NONE:
			# 1) NAH -> normaler Melee
			if dist <= melee_trigger_range and melee_cd_timer <= 0.0:
				_start_melee()

			# 2) MIDRANGE -> Jump-Attack
			elif dist <= jump_trigger_range and dist >= jump_min_range and melee_cd_timer <= 0.0:
				_start_jump_windup()

			# 3) Sonst verfolgen
			if attack_state == AttackState.NONE and not nav_agent.is_navigation_finished():
				var next_path_pos: Vector2 = nav_agent.get_next_path_position()
				var dir: Vector2 = (next_path_pos - global_position).normalized()
				velocity = velocity.move_toward(dir * run_speed, run_speed * acceleration * delta)
			else:
				_apply_friction(delta)

		AttackState.WINDUP:
			_apply_friction(delta)
			windup_timer -= delta
			if windup_timer <= 0.0:
				if attack_type == AttackType.MELEE:
					_melee_impact()
				else:
					_start_leap()

		AttackState.LEAP:
			# Hop + kurzer Dash, collision-safe
			use_move_and_slide = false
			velocity = Vector2.ZERO

			leap_t += delta / max(0.001, leap_time)
			var t: float = clamp(leap_t, 0.0, 1.0)

			# Visual hop
			var hop: float = sin(t * PI) * jump_visual_height
			animated_sprite.position = sprite_rest_pos + Vector2(0.0, -hop)

			# Vorwärtsbewegung nur solange nicht blockiert
			if not leap_blocked:
				var next_pos: Vector2 = leap_start.lerp(leap_target, t)
				var motion: Vector2 = next_pos - global_position
				if motion.length() > 0.0:
					var col: KinematicCollision2D = move_and_collide(motion)
					if col != null:
						leap_blocked = true

			if leap_t >= 1.0:
				_land_impact()

		AttackState.RECOVER:
			_apply_friction(delta)
			recover_timer -= delta
			# Fallback falls animation_finished nicht connected ist
			if recover_timer <= 0.0 and melee_active_timer <= 0.0:
				attack_state = AttackState.NONE
				attack_type = AttackType.NONE

	if use_move_and_slide:
		move_and_slide()

	_handle_visuals()


func _apply_friction(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, run_speed * friction * delta)


func _set_attack_dir() -> void:
	attack_dir = (player.global_position - global_position).normalized()
	if attack_dir == Vector2.ZERO:
		attack_dir = Vector2.RIGHT


# -------------------------
# NORMAL MELEE
# -------------------------
func _start_melee() -> void:
	melee_cd_timer = melee_cooldown
	attack_type = AttackType.MELEE
	attack_state = AttackState.WINDUP
	windup_timer = melee_windup_time

	_set_attack_dir()

	# Animationen (optional): "Melee_Windup" / "Melee"
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("Melee_Windup"):
		animated_sprite.play("Melee_Windup")
	elif animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("Attack_Windup"):
		animated_sprite.play("Attack_Windup")
	elif animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("Attack"):
		animated_sprite.play("Attack")


func _melee_impact() -> void:
	attack_state = AttackState.RECOVER
	recover_timer = recover_time

	# optional: extra Animation fürs Treffen
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("Melee"):
		animated_sprite.play("Melee")

	# kleine Capsule-Hitbox
	melee_shape.shape = melee_shape_capsule
	melee_hitbox.rotation = attack_dir.angle() + capsule_rotation_offset
	melee_hitbox.position = attack_dir * melee_center_offset

	melee_hitbox.monitoring = true
	melee_active_timer = melee_active_time
	already_hit.clear()


# -------------------------
# JUMP ATTACK (Telegraph -> Hop -> Land AOE)
# -------------------------
func _start_jump_windup() -> void:
	melee_cd_timer = melee_cooldown
	attack_type = AttackType.JUMP
	attack_state = AttackState.WINDUP
	windup_timer = windup_time

	_set_attack_dir()

	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("Attack_Windup"):
		animated_sprite.play("Attack_Windup")
	elif animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("Attack"):
		animated_sprite.play("Attack")


func _start_leap() -> void:
	attack_state = AttackState.LEAP
	leap_t = 0.0
	leap_blocked = false

	# Richtung beim Absprung neu nehmen (Player bewegt sich)
	_set_attack_dir()

	leap_start = global_position

	# Dynamische Dash-Distanz: von weiter weg -> größere Strecke
	var dist_to_player: float = leap_start.distance_to(player.global_position)
	var desired_travel: float = dist_to_player - desired_landing_gap
	desired_travel = clamp(desired_travel, leap_min_distance, leap_max_distance)

	var desired_target: Vector2 = leap_start + attack_dir * desired_travel
	leap_target = _clip_leap_target(leap_start, desired_target, attack_dir)

	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("Attack_Leap"):
		animated_sprite.play("Attack_Leap")


func _clip_leap_target(from_pos: Vector2, to_pos: Vector2, dir: Vector2) -> Vector2:
	var params: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	params.collision_mask = leap_obstacle_mask
	params.exclude = [self]

	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(params)
	if hit.is_empty():
		return to_pos

	var hit_pos: Vector2 = hit["position"] as Vector2
	return hit_pos - dir * 2.0


func _land_impact() -> void:
	attack_state = AttackState.RECOVER
	recover_timer = recover_time
	animated_sprite.position = sprite_rest_pos

	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("Attack_Land"):
		animated_sprite.play("Attack_Land")
	elif animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("Attack"):
		animated_sprite.play("Attack")

	# große Capsule (AOE inkl. Schwert)
	melee_shape.shape = landing_shape
	melee_hitbox.rotation = attack_dir.angle() + capsule_rotation_offset
	melee_hitbox.position = attack_dir * landing_center_offset

	melee_hitbox.monitoring = true
	melee_active_timer = melee_active_time
	already_hit.clear()


# -------------------------
# COMMON
# -------------------------
func _reset_hitbox() -> void:
	melee_hitbox.monitoring = false
	melee_hitbox.rotation = 0.0
	melee_hitbox.position = Vector2.ZERO
	melee_shape.shape = base_shape
	already_hit.clear()


func _handle_visuals() -> void:
	if attack_state != AttackState.NONE:
		animated_sprite.flip_h = (attack_dir.x < 0.0)
		return

	var to_player_x: float = player.global_position.x - global_position.x
	animated_sprite.flip_h = (to_player_x < 0.0)

	if velocity.length() > 10.0:
		animated_sprite.play("Move")
	else:
		animated_sprite.play("Idle")


func _on_died() -> void:
	
	if upgrade_scene == null:
		push_error("upgrade_scene ist null! Pfad/Inspector prüfen.")
		return

	var upgrade := upgrade_scene.instantiate()
	get_tree().current_scene.add_child(upgrade)  # oder: add_child(upgrade)

	if upgrade is Node2D:
		(upgrade as Node2D).global_position = self.position

	
	queue_free()


func _on_base_sprite_animation_finished() -> void:
	# Recover endet nach Attack-Animationen (falls connected)
	if attack_state == AttackState.RECOVER:
		attack_state = AttackState.NONE
		attack_type = AttackType.NONE


func _on_melee_hitbox_area_entered(area: Area2D) -> void:
	if area is Hurtbox and area.owner.is_in_group(player_group):
		var id: int = area.get_instance_id()
		if already_hit.has(id): return
		already_hit[id] = true
		area.apply_damage(damage)
