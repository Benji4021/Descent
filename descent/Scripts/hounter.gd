extends CharacterBody2D

@export_group("Movement")
@export var run_speed: float = 320.0
@export var acceleration: float = 14.0
@export var friction: float = 10.0

@export_group("Hit")
@export var damage: int = 2
@export var hit_range: float = 22.0              # ab dieser Distanz startet der "Hit"
@export var hit_cooldown: float = 0.35           # damit er nicht dauernd neu startet, falls was nicht passt
@export var hit_active_time: float = 0.08        # wie beim Ghoul: kurzes Fenster
@export var hit_offset: float = 8.0              # Hitbox leicht Richtung Player verschieben

@export_group("Navigation")
@export var player_group: StringName = &"player"
@export var repath_time: float = 0.15

# --- NODES ---
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var repath_timer: Timer = $PathfindingUpdateTimer
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var animated_sprite: AnimatedSprite2D = $Base_Sprite
@onready var melee_hitbox: Area2D = $MeleeHitbox

# --- STATE ---
var player: Node2D

var hit_cd_timer: float = 0.0
var hit_active_timer: float = 0.0
var hit_started: bool = false
var hit_done: bool = false

# verhindert Multi-Hits (auch wenn Player mehrere Hurtboxes hat)
var already_hit: Dictionary = {}

func _ready() -> void:
	# Health wiring
	hurtbox.health = health
	health.died.connect(_on_died)

	# Hitbox wie beim Ghoul: normalerweise AUS
	melee_hitbox.monitoring = false

	# Falls Signal nicht im Editor verbunden ist:
	if not melee_hitbox.area_entered.is_connected(_on_melee_hitbox_area_entered):
		melee_hitbox.area_entered.connect(_on_melee_hitbox_area_entered)

	# Repath
	repath_timer.wait_time = repath_time
	if not repath_timer.timeout.is_connected(_update_nav_target):
		repath_timer.timeout.connect(_update_nav_target)
	repath_timer.start()

	call_deferred("_acquire_player")

func _acquire_player() -> void:
	var nodes: Array = get_tree().get_nodes_in_group(player_group)
	if not nodes.is_empty():
		player = nodes[0] as Node2D

func _update_nav_target() -> void:
	if hit_done or hit_started: return
	if not is_instance_valid(player): return
	nav_agent.target_position = player.global_position

func _physics_process(delta: float) -> void:
	# Cooldown
	if hit_cd_timer > 0.0:
		hit_cd_timer -= delta

	# Active window
	if hit_active_timer > 0.0:
		hit_active_timer -= delta
		if hit_active_timer <= 0.0:
			melee_hitbox.monitoring = false
			melee_hitbox.position = Vector2.ZERO
			already_hit.clear()
			hit_started = false

	if hit_done:
		return

	if not is_instance_valid(player):
		_apply_friction(delta)
		move_and_slide()
		return

	var dist: float = global_position.distance_to(player.global_position)

	# Start "Hit" wie beim Ghoul: kurzer Window + Overlap-Check
	if not hit_started and hit_cd_timer <= 0.0 and dist <= hit_range:
		_start_hit()

	# Bewegung nur wenn nicht gerade im Hit-Window
	if not hit_started and not nav_agent.is_navigation_finished():
		var next_pos: Vector2 = nav_agent.get_next_path_position()
		var dir: Vector2 = (next_pos - global_position).normalized()
		velocity = velocity.move_toward(dir * run_speed, run_speed * acceleration * delta)
	else:
		_apply_friction(delta)

	move_and_slide()
	_handle_visuals()

func _apply_friction(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, run_speed * friction * delta)

func _start_hit() -> void:
	hit_cd_timer = hit_cooldown
	hit_started = true
	hit_active_timer = hit_active_time
	already_hit.clear()

	# Optional Anim
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("Attack"):
		animated_sprite.play("Attack")

	# Hitbox aktivieren + Richtung Player verschieben
	var dir_to_player: Vector2 = (player.global_position - global_position).normalized()
	if dir_to_player == Vector2.ZERO:
		dir_to_player = Vector2.RIGHT
	melee_hitbox.position = dir_to_player * hit_offset
	melee_hitbox.monitoring = true

	# Wichtig wie beim Ghoul: falls Player schon drin steht -> Overlaps checken
	call_deferred("_apply_hit_overlaps_once")

func _apply_hit_overlaps_once() -> void:
	if hit_done: return
	if not melee_hitbox.monitoring: return

	var areas: Array = melee_hitbox.get_overlapping_areas()
	for a in areas:
		if a is Hurtbox:
			var hb: Hurtbox = a as Hurtbox
			if hb.owner != null and hb.owner.is_in_group(player_group):
				_apply_damage_once(hb)
				return

func _apply_damage_once(hb: Hurtbox) -> void:
	if hit_done: return

	# blockiert auch mehrere Hurtbox-Areas am Player
	var owner_id: int = hb.owner.get_instance_id()
	if already_hit.has(owner_id):
		return
	already_hit[owner_id] = true

	hit_done = true
	melee_hitbox.monitoring = false

	hb.apply_damage(damage)

	# sofort weg (kein 2./3. Hit möglich)
	queue_free()

func _on_melee_hitbox_area_entered(area: Area2D) -> void:
	if hit_done: return
	if area is Hurtbox:
		var hb: Hurtbox = area as Hurtbox
		if hb.owner != null and hb.owner.is_in_group(player_group):
			_apply_damage_once(hb)

func _handle_visuals() -> void:
	if not is_instance_valid(player):
		return

	var to_player_x: float = player.global_position.x - global_position.x
	animated_sprite.flip_h = (to_player_x < 0.0)

	if velocity.length() > 10.0:
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("Move"):
			animated_sprite.play("Move")
	else:
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("Idle"):
			animated_sprite.play("Idle")

func _on_died() -> void:
	queue_free()
