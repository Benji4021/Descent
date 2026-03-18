extends CharacterBody2D

@export var inventory: Inv
@export var walk_speed: float = 150.0
@export var sprint_speed: float = 300.0

@export var melee_cooldown: float = 0.25
@export var melee_active_time: float = 0.08

@export var spell_scene: PackedScene   # hier SpellProjectile.tscn reinziehen
@export var spell_cooldown: float = 5.0

@onready var cooldown_bar: ProgressBar = $CooldownBar
@onready var burn_particles: CPUParticles2D = $BurningParticles

@export var cooldown_show_time := 1.2   # wie lange nach letztem Klick anzeigen
var cooldown_show_timer := 0.0
enum CooldownType { NONE, MELEE, SPELL }
var last_requested_cd: int = CooldownType.NONE

# Burning / Lava DOT
var burn_time_left: float = 0.0
var burn_tick_left: float = 0.0
var burn_damage_per_tick: int = 0
var burn_tick_interval: float = 0.5

# Flüssigkeiten: solange wir drin sind, Movement-Slow
@export var lava_move_multiplier: float = 0.6
@export var water_move_multiplier: float = 0.6
var _in_lava: int = 0
var _in_water: int = 0

@export var heal_amount: int = 2
@export var heal_potions: int = 3

@onready var animated_sprite : AnimatedSprite2D = $Base_Sprite
@onready var health: HealthComponent = $HealthComponent
@onready var hearts_ui: HeartsUI = $HeartsUI
@onready var potions_ui: PotionsUI = $PotionsUI
@onready var melee_hitbox: Area2D = $MeleeHitbox
@onready var shoot_point: Marker2D = $ShootPoint

var animation_playing := false

var last_dir: Vector2 = Vector2.RIGHT
var melee_cd_timer := 0.0
var melee_active_timer := 0.0
var spell_cd_timer := 0.0
signal potions_changed(current: int) 

func _ready():
	
	# Projektil automatisch laden, falls noch nicht im Inspektor gesetzt
	if spell_scene == null:
		spell_scene = load("res://Scenes/MagicMissile.tscn")
		
	melee_hitbox.monitoring = false
	health.died.connect(_on_died)
	$Hurtbox.health = $HealthComponent
	health.hp_changed.connect(_on_hp_changed)
	potions_changed.connect(_on_potions_changed)
	_on_potions_changed(heal_potions) 
	hearts_ui.set_max_hearts(health.max_hp)
	hearts_ui.set_hearts(health.hp)
	
	cooldown_bar.visible = false
	cooldown_bar.min_value = 0.0
	cooldown_bar.max_value = 1.0
	cooldown_bar.value = 0.0
	if burn_particles != null:
		burn_particles.emitting = false

func _on_hp_changed(current: int, max_hp: int) -> void:
	# falls max_hp sich ändern kann (Upgrades)
	if hearts_ui.hearts.size() != max_hp:
		hearts_ui.set_max_hearts(max_hp)
	hearts_ui.set_hearts(current)

func _on_potions_changed(current: int) -> void:
	potions_ui.set_potions(current)

func _physics_process(delta: float) -> void:
	# Burn DOT
	if burn_time_left > 0.0:
		burn_time_left -= delta
		burn_tick_left -= delta
		if burn_tick_left <= 0.0:
			burn_tick_left = burn_tick_interval
			if burn_damage_per_tick > 0 and health != null:
				health.take_damage(burn_damage_per_tick)
		if burn_time_left <= 0.0:
			burn_time_left = 0.0
			if burn_particles != null:
				burn_particles.emitting = false

	# Cooldowns runterzählen
	if melee_cd_timer > 0: melee_cd_timer -= delta
	if spell_cd_timer > 0: spell_cd_timer -= delta

	if cooldown_show_timer > 0.0:
		cooldown_show_timer -= delta
	if cooldown_show_timer <= 0.0:
		cooldown_bar.visible = false
		last_requested_cd = CooldownType.NONE
	else:
		_update_cooldown_bar()
	# Melee active window
	if melee_active_timer > 0:
		melee_active_timer -= delta
		if melee_active_timer <= 0:
			melee_hitbox.monitoring = false

	# Sprint / Walk
	var move_speed := walk_speed
	if Input.is_action_pressed("shift"):
		move_speed = sprint_speed
	# Flüssigkeit-Slow (gilt für Sprint & Walk)
	var mult := 1.0
	if _in_lava > 0:
		mult = min(mult, lava_move_multiplier)
	if _in_water > 0:
		mult = min(mult, water_move_multiplier)
	move_speed *= mult

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

func _request_cooldown_text(kind: int) -> void:
	last_requested_cd = kind
	cooldown_show_timer = cooldown_show_time
	cooldown_bar.visible = true
	_update_cooldown_bar()

func _update_cooldown_bar() -> void:
	var t := 0.0
	var total := 0.0
	if last_requested_cd == CooldownType.MELEE:
		t = melee_cd_timer
		total = melee_cooldown
	elif last_requested_cd == CooldownType.SPELL:
		t = spell_cd_timer
		total = spell_cooldown
	else:
		cooldown_bar.visible = false
		return

	# falls inzwischen ready -> ausblenden
	if t <= 0.0:
		cooldown_bar.visible = false
		last_requested_cd = CooldownType.NONE
		return
	if total <= 0.0:
		cooldown_bar.value = 1.0
		return
	var progress := clampf(1.0 - (t / total), 0.0, 1.0)
	cooldown_bar.value = progress

func try_melee() -> void:
	if melee_cd_timer > 0:
		_request_cooldown_text(CooldownType.MELEE)
		return
	melee_cd_timer = melee_cooldown

	animation_playing = true
	animated_sprite.play("Attack")
	
	# Hitbox vor den Player setzen
	melee_hitbox.position = last_dir * 10.0

	melee_hitbox.monitoring = true
	melee_active_timer = melee_active_time

func try_spell() -> void:
	if spell_cd_timer > 0:
		_request_cooldown_text(CooldownType.SPELL)
		return
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
	potions_changed.emit(heal_potions)
	health.heal(heal_amount)

func add_potions(amount: int = 1) -> void:
	heal_potions += amount
	potions_changed.emit(heal_potions)

func _on_died() -> void:
	# Player "deaktivieren"
	set_physics_process(false)
	velocity = Vector2.ZERO
	animated_sprite.visible = false
	
	# Optional: Kollision aus
	$CollisionShape2D.disabled = true
	$Hurtbox.monitoring = false
	
	# DeathScreen finden und anzeigen
	var death_screen := get_tree().current_scene.get_node("DeathScreen")
	death_screen.show_death()


func _on_base_sprite_animation_finished():
	if animated_sprite.animation == "Attack":
		animation_playing = false
		

func collect(item): 
	inventory.insert(item)
	
func apply_upgrade(kind: String, a, b = null) -> void:
	# a/b sind absichtlich flexibel:
	# - melee_damage: a=int
	# - max_hp: a=int
	# - spell_cooldown_reduce: a=float(seconds), b=float(min_cd)
	match kind:
		"melee_damage":
			var add := int(a)
			melee_damage += add

			# optional: falls deine MeleeHitbox eine eigene damage-Variable nutzt
			if melee_hitbox != null and melee_hitbox.has_method("set"):
				if _has_property(melee_hitbox, "damage"):
					melee_hitbox.set("damage", int(melee_hitbox.get("damage")) + add)

		"max_hp":
			var add_hp := int(a)
			# dein HealthComponent ist @onready var health: HealthComponent = $HealthComponent
			if health != null:
				if health.has_method("increase_max_hp"):
					health.call("increase_max_hp", add_hp)
				else:
					# fallback wenn du nur max_hp/hp als vars hast
					if _has_property(health, "max_hp"):
						health.max_hp += add_hp
					if _has_property(health, "hp"):
						health.hp += add_hp

		"spell_cooldown_reduce":
			var reduce_s := float(a)
			var min_cd := 0.25
			if b != null:
				min_cd = float(b)

			spell_cooldown = max(min_cd, spell_cooldown - reduce_s)
			spell_cd_timer = max(0.0, spell_cd_timer - reduce_s)

		_:
			pass

func _has_property(obj: Object, prop_name: String) -> bool:
	var list: Array = obj.get_property_list()
	for p in list:
		if typeof(p) == TYPE_DICTIONARY and p.has("name") and String(p["name"]) == prop_name:
			return true
	return false

func apply_burn(duration: float, damage_per_tick: int, tick_interval: float) -> void:
	# Refresh/extend burn; repeated lava contact keeps it on
	burn_time_left = max(burn_time_left, max(0.0, duration))
	burn_damage_per_tick = max(0, damage_per_tick)
	burn_tick_interval = max(0.05, tick_interval)
	# Tick soon after application
	if burn_tick_left <= 0.0:
		burn_tick_left = burn_tick_interval
	if burn_particles != null:
		burn_particles.emitting = burn_time_left > 0.0

func extinguish() -> void:
	burn_time_left = 0.0
	burn_tick_left = 0.0
	if burn_particles != null:
		burn_particles.emitting = false

func set_in_lava(is_in: bool) -> void:
	_in_lava = max(0, _in_lava + (1 if is_in else -1))

func set_in_water(is_in: bool) -> void:
	_in_water = max(0, _in_water + (1 if is_in else -1))
