extends CharacterBody2D

@export var walk_speed: float = 150.0
@export var sprint_speed: float = 300.0

@export var melee_cooldown: float = 0.25
@export var melee_active_time: float = 0.08

@export var spell_scene: PackedScene   # hier SpellProjectile.tscn reinziehen
@export var spell_cooldown: float = 5.0

@export var heal_amount: int = 2
@export var heal_potions: int = 3

@onready var animated_sprite : AnimatedSprite2D = $Base_Sprite
@onready var health: HealthComponent = $HealthComponent
@onready var melee_hitbox: Area2D = $MeleeHitbox
@onready var shoot_point: Marker2D = $ShootPoint

var animation_playing := false

var last_dir: Vector2 = Vector2.RIGHT
var melee_cd_timer := 0.0
var melee_active_timer := 0.0
var spell_cd_timer := 0.0

func _ready():
	melee_hitbox.monitoring = false
	health.died.connect(_on_died)
	$Hurtbox.health = $HealthComponent

func _physics_process(delta: float) -> void:
	# Cooldowns runterzählen
	if melee_cd_timer > 0: melee_cd_timer -= delta
	if spell_cd_timer > 0: spell_cd_timer -= delta

	# Melee active window
	if melee_active_timer > 0:
		melee_active_timer -= delta
		if melee_active_timer <= 0:
			melee_hitbox.monitoring = false

	# Sprint / Walk
	var move_speed := walk_speed
	if Input.is_action_pressed("shift"):
		move_speed = sprint_speed

	# Input Direction
	var input_direction = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down") - Input.get_action_strength("up")
	).normalized()

	# last_dir merken (für melee/spell richtung)
	if input_direction.length_squared() != 0:
		last_dir = input_direction.normalized()
	# Velocity
	velocity = input_direction * move_speed

	# Flip Sprite (wie bei dir)
	if input_direction.x > 0:
		animated_sprite.flip_h = false
	elif input_direction.x < 0:
		animated_sprite.flip_h = true

	# Animation
	if velocity != Vector2.ZERO:
		if !animation_playing:
			animated_sprite.play("Running")
	else:
		if !animation_playing:
			animated_sprite.play("Idle")
	move_and_slide()

	# Combat Inputs (im Physics okay)
	if Input.is_action_just_pressed("attack_melee"):
		try_melee()

	if Input.is_action_just_pressed("attack_spell"):
		try_spell()

	if Input.is_action_just_pressed("use_heal"):
		use_heal()

func try_melee() -> void:
	if melee_cd_timer > 0: return
	melee_cd_timer = melee_cooldown

	animation_playing = true
	animated_sprite.play("Attack")
	
	# Hitbox vor den Player setzen
	melee_hitbox.position = last_dir * 10.0

	melee_hitbox.monitoring = true
	melee_active_timer = melee_active_time

func try_spell() -> void:
	if spell_cd_timer > 0: return
	spell_cd_timer = spell_cooldown
	if spell_scene == null: return

	var p = spell_scene.instantiate()
	p.source = self
	p.dir = last_dir.normalized()
	get_tree().current_scene.add_child(p)

	# Shootpoint vor den Player setzen
	shoot_point.position.x = last_dir.x * 10.0

	# Spawnpoint nutzen
	p.global_position = shoot_point.global_position
	p.dir = last_dir.normalized()

func use_heal() -> void:
	if heal_potions <= 0: return
	if health.is_full(): return
	heal_potions -= 1
	health.heal(heal_amount)

func _on_died() -> void:
	queue_free()

func _on_base_sprite_animation_finished():
	if animated_sprite.animation == "Attack":
		animation_playing = false
		
