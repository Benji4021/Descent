extends CharacterBody2D

@export var inventory: Inv
@export var walk_speed: float = 150.0
@export var sprint_speed: float = 300.0

@export var melee_damage: int = 2
@export var melee_cooldown: float = 0.25
@export var melee_active_time: float = 0.08

@export var spell_scene: PackedScene   # hier SpellProjectile.tscn reinziehen
@export var spell_cooldown: float = 5.0

@onready var cooldown_label: Label = $CooldownLabel

@export var cooldown_show_time := 1.2   # wie lange nach letztem Klick anzeigen
var cooldown_show_timer := 0.0
enum CooldownType { NONE, MELEE, SPELL }
var last_requested_cd: int = CooldownType.NONE

@export var heal_amount: int = 2
@export var heal_potions: int = 3

@onready var animated_sprite : AnimatedSprite2D = $Base_Sprite
@onready var health: HealthComponent = $HealthComponent
@onready var hearts_ui = $HeartsUI
@onready var potions_ui = $PotionsUI
@onready var melee_hitbox: Area2D = $MeleeHitbox
@onready var shoot_point: Marker2D = $ShootPoint

var animation_playing := false

var last_dir: Vector2 = Vector2.RIGHT
var melee_cd_timer := 0.0
var melee_active_timer := 0.0
var spell_cd_timer := 0.0
signal potions_changed(current: int) 

func _ready():
	melee_hitbox.monitoring = false
	health.died.connect(_on_died)
	$Hurtbox.health = $HealthComponent
	health.hp_changed.connect(_on_hp_changed)
	potions_changed.connect(_on_potions_changed)
	_on_potions_changed(heal_potions) 
	hearts_ui.set_max_hearts(health.max_hp)
	hearts_ui.set_hearts(health.hp)
	
	cooldown_label.visible = false

func _on_hp_changed(current: int, max_hp: int) -> void:
	# falls max_hp sich ändern kann (Upgrades)
	if hearts_ui.hearts.size() != max_hp:
		hearts_ui.set_max_hearts(max_hp)
	hearts_ui.set_hearts(current)

func _on_potions_changed(current: int) -> void:
	potions_ui.set_potions(current)

func _physics_process(delta: float) -> void:
	# Cooldowns runterzählen
	if melee_cd_timer > 0: melee_cd_timer -= delta
	if spell_cd_timer > 0: spell_cd_timer -= delta

	if cooldown_show_timer > 0.0:
		cooldown_show_timer -= delta
	if cooldown_show_timer <= 0.0:
		cooldown_label.visible = false
		last_requested_cd = CooldownType.NONE
	else:
		_update_cooldown_label()
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
	if input_direction != Vector2.ZERO:
		last_dir = input_direction

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
	cooldown_label.visible = true
	_update_cooldown_label()

func _update_cooldown_label() -> void:
	var t := 0.0
	if last_requested_cd == CooldownType.MELEE:
		t = melee_cd_timer
	elif last_requested_cd == CooldownType.SPELL:
		t = spell_cd_timer
	else:
		cooldown_label.visible = false
		return

	# falls inzwischen ready -> ausblenden
	if t <= 0.0:
		cooldown_label.visible = false
		last_requested_cd = CooldownType.NONE
		return

	cooldown_label.text = "Cooldown: %.2f s" % t

func try_melee() -> void:
	if melee_cd_timer > 0:
		_request_cooldown_text(CooldownType.MELEE)
		return
	print(melee_damage)
	melee_hitbox.damage = melee_damage
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
	p.dir = last_dir.normalized()
	get_tree().current_scene.add_child(p)

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
	if death_screen != null:
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
