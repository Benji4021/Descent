extends CharacterBody2D

## --- EXPORTS ---
@export_group("Movement")
@export var run_speed: float = 160.0
@export var acceleration: float = 5.0
@export var friction: float = 4.0

@export_group("Combat")
@export var damage: int = 1
@export var attack_range: float = 35.0
@export var melee_cooldown: float = 1.5
@export var melee_active_time: float = 0.15

@export_group("Navigation")
@export var player_group: StringName = &"player"
@export var repath_time: float = 0.2

## --- NODES ---
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var health: HealthComponent = $HealthComponent
@onready var hp_bar: ProgressBar = $HPBar
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var animated_sprite: AnimatedSprite2D = $Base_Sprite
@onready var melee_hitbox: Area2D = $MeleeHitbox

signal killed(enemy)

## --- INTERNAL STATE ---
var player: Node2D
var animation_playing := false
var melee_cd_timer := 0.0
var melee_active_timer := 0.0

func _ready() -> void:
	# Combat Setup
	melee_hitbox.monitoring = false
	hurtbox.health = health

	# Death & HP
	health.died.connect(_on_died)
	health.hp_changed.connect(_on_hp_changed)
	_on_hp_changed(health.hp, health.max_hp)

	# Sprite Signal Connect (Wichtig!)
	animated_sprite.animation_finished.connect(_on_animation_finished)

	# Navigation Timer
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = repath_time
	timer.timeout.connect(_update_nav_target)
	timer.start()

	call_deferred("_acquire_player")

func _on_hp_changed(current: int, max_hp: int) -> void:
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current

func _acquire_player() -> void:
	var nodes = get_tree().get_nodes_in_group(player_group)
	if not nodes.is_empty():
		player = nodes[0]

func _update_nav_target() -> void:
	# Wir aktualisieren das Ziel IMMER, auch wenn wir gerade angreifen.
	# So weiß der Ghul sofort nach dem Schlag, wo der Spieler hin ist.
	if is_instance_valid(player):
		nav_agent.target_position = player.global_position

func _physics_process(delta: float) -> void:
	# Timer-Management
	if melee_cd_timer > 0:
		melee_cd_timer -= delta

	if melee_active_timer > 0:
		melee_active_timer -= delta
		if melee_active_timer <= 0:
			melee_hitbox.monitoring = false

	# Abbruch, falls kein Spieler da ist
	if not is_instance_valid(player):
		_apply_friction(delta)
		move_and_slide()
		return

	var dist = global_position.distance_to(player.global_position)

	# Angriff auslösen
	if dist <= attack_range and melee_cd_timer <= 0:
		try_melee()

	# Bewegung: Nur wenn wir nicht gerade in der Angriffs-Animation stecken
	if not animation_playing:
		var next_path_pos = nav_agent.get_next_path_position()
		var dir = (next_path_pos - global_position).normalized()
		
		# Falls wir am Ziel sind oder keine Richtung haben -> Reibung
		if nav_agent.is_navigation_finished():
			_apply_friction(delta)
		else:
			velocity = velocity.move_toward(dir * run_speed, run_speed * acceleration * delta)
	else:
		# Während des Schlags bremsen wir ab
		_apply_friction(delta)

	move_and_slide()
	_handle_visuals()

func _apply_friction(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, run_speed * friction * delta)

func try_melee() -> void:
	melee_cd_timer = melee_cooldown
	animation_playing = true
	animated_sprite.play("Attack")

	melee_hitbox.monitoring = true
	melee_active_timer = melee_active_time

	# Hitbox in Richtung Spieler schieben
	var dir_to_player = (player.global_position - global_position).normalized()
	melee_hitbox.position = dir_to_player * 15.0 # Etwas weiter raus für besseres Feedback

func _handle_visuals() -> void:
	if animation_playing:
		return

	# Umdrehen basierend auf Spielerposition
	if is_instance_valid(player):
		animated_sprite.flip_h = (player.global_position.x < global_position.x)

	if velocity.length() > 20.0:
		animated_sprite.play("Move")
	else:
		animated_sprite.play("Idle")

func _on_animation_finished() -> void:
	# Wir setzen animation_playing zurück, egal welche Animation endete,
	# solange es ein Angriff war oder wir sichergehen wollen, dass er weiterläuft.
	if animated_sprite.animation == "Attack":
		animation_playing = false

func _on_died() -> void:
	emit_signal("killed", self)
	queue_free()

func _on_melee_hitbox_area_entered(area: Area2D) -> void:
	if area is Hurtbox and area.owner.is_in_group(player_group):
		area.apply_damage(damage)
