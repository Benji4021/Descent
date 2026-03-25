extends CharacterBody2D

## --- EXPORTS ---
@export_group("Movement")
@export var move_speed: float = 210.0
@export var acceleration: float = 10.0
@export var friction: float = 10.0

@export_group("Damage")
@export var damage: int = 1
@export var player_group: StringName = &"player"
@export var hitbox_offset: float = 0.0 

@export_group("Lifetime")
@export var lifetime_seconds: float = 3.0
@export var fade_out_time: float = 0.0
@export var despawn_anim: StringName = &"Death"

@export_group("Reliability")
@export var overlap_check_each_frame: bool = true

## --- NODES ---
@onready var body_cs: CollisionShape2D = $CollisionShape2D
@onready var sprite: AnimatedSprite2D = $Base_Sprite
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hurtbox_cs: CollisionShape2D = $Hurtbox/CollisionShape2D

@onready var melee_hitbox: Area2D = $MeleeHitbox
@onready var melee_hitbox_cs: CollisionShape2D = $MeleeHitbox/CollisionShape2D

@onready var hp_bar: ProgressBar = $HPBar # <-- NEU

## --- INTERNAL STATE ---
var player: Node2D
var life_timer: float = 0.0
var despawning: bool = false
var hit_done: bool = false

func _ready() -> void:
	# Health wiring
	hurtbox.health = health
	health.died.connect(_on_died)
	
	# HP BAR <--- NEU
	health.hp_changed.connect(_on_hp_changed)
	_on_hp_changed(health.hp, health.max_hp)
	
	life_timer = max(0.05, lifetime_seconds)

	melee_hitbox.monitoring = true
	if not melee_hitbox.area_entered.is_connected(_on_melee_hitbox_area_entered):
		melee_hitbox.area_entered.connect(_on_melee_hitbox_area_entered)

	call_deferred("_acquire_player")
	call_deferred("_check_overlaps_once")

# HP BAR LOGIK <--- NEU
func _on_hp_changed(current: int, max_hp: int) -> void:
	if hp_bar == null: return
	hp_bar.max_value = max_hp
	hp_bar.value = current

func _acquire_player() -> void:
	var nodes: Array = get_tree().get_nodes_in_group(player_group)
	if not nodes.is_empty():
		player = nodes[0] as Node2D

func _physics_process(delta: float) -> void:
	if despawning or hit_done:
		return

	life_timer -= delta
	if life_timer <= 0.0:
		_despawn()
		return

	if fade_out_time > 0.0 and life_timer <= fade_out_time:
		var t: float = clamp(life_timer / fade_out_time, 0.0, 1.0)
		sprite.modulate.a = t

	if not is_instance_valid(player):
		_acquire_player()

	if not is_instance_valid(player):
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * friction * delta)
		move_and_slide()
		return

	var dir: Vector2 = (player.global_position - global_position).normalized()
	velocity = velocity.move_toward(dir * move_speed, move_speed * acceleration * delta)
	move_and_slide()

	if hitbox_offset != 0.0:
		melee_hitbox.position = dir * hitbox_offset

	sprite.flip_h = (dir.x < 0.0)

	if overlap_check_each_frame:
		_check_overlaps_once()

func _check_overlaps_once() -> void:
	if hit_done or despawning: return
	if not melee_hitbox.monitoring: return

	var areas: Array = melee_hitbox.get_overlapping_areas()
	for a in areas:
		if a is Hurtbox:
			var hb: Hurtbox = a as Hurtbox
			if hb.owner != null and hb.owner.is_in_group(player_group):
				_do_hit(hb)
				return

func _on_melee_hitbox_area_entered(area: Area2D) -> void:
	if hit_done or despawning: return
	if area is Hurtbox:
		var hb: Hurtbox = area as Hurtbox
		if hb.owner != null and hb.owner.is_in_group(player_group):
			_do_hit(hb)

func _do_hit(hb: Hurtbox) -> void:
	if hit_done or despawning: return
	hit_done = true
	melee_hitbox.monitoring = false
	hb.apply_damage(damage)
	queue_free()

func _despawn() -> void:
	if despawning or hit_done: return
	despawning = true

	velocity = Vector2.ZERO
	body_cs.disabled = true
	hurtbox_cs.disabled = true
	(hurtbox as Area2D).monitorable = false
	melee_hitbox.monitoring = false
	melee_hitbox_cs.disabled = true

	if sprite.sprite_frames and sprite.sprite_frames.has_animation(String(despawn_anim)):
		sprite.play(String(despawn_anim))
		sprite.animation_finished.connect(_on_despawn_anim_finished, CONNECT_ONE_SHOT)
	else:
		queue_free()

func _on_despawn_anim_finished() -> void:
	queue_free()

func _on_died() -> void:
	queue_free()
