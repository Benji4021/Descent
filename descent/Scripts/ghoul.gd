extends CharacterBody2D

## --- EXPORTS ---
@export_group("Movement")
@export var run_speed: float = 160.0
@export var acceleration: float = 5.0
@export var friction: float = 4.0

@export_group("Combat")
@export var damage: int = 1
@export var attack_range: float = 35.0      # Distanz, um den Schlag zu starten
@export var melee_cooldown: float = 0.8     # Zeit zwischen den Angriffen
@export var melee_active_time: float = 0.15 # Wie lange die Hitbox Schaden macht

@export_group("Navigation")
@export var player_group: StringName = &"player"
@export var repath_time: float = 0.2

## --- NODES ---
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var animated_sprite: AnimatedSprite2D = $Base_Sprite
@onready var melee_hitbox: Area2D = $MeleeHitbox

## --- INTERNAL STATE ---
var player: Node2D
var animation_playing := false
var melee_cd_timer := 0.0
var melee_active_timer := 0.0

func _ready() -> void:
	# Setup analog zum Player-Skript
	melee_hitbox.monitoring = false
	hurtbox.health = health
	health.died.connect(_on_died)
	
	# Navigation Timer
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = repath_time
	timer.timeout.connect(_update_nav_target)
	timer.start()

	call_deferred("_acquire_player")

func _acquire_player() -> void:
	var nodes = get_tree().get_nodes_in_group(player_group)
	if not nodes.is_empty():
		player = nodes[0]

func _update_nav_target() -> void:
	if not is_instance_valid(player) or animation_playing: return
	nav_agent.target_position = player.global_position

func _physics_process(delta: float) -> void:
	# Cooldowns (wie im Player-Skript)
	if melee_cd_timer > 0: melee_cd_timer -= delta
	
	# Aktives Fenster der Hitbox
	if melee_active_timer > 0:
		melee_active_timer -= delta
		if melee_active_timer <= 0:
			melee_hitbox.monitoring = false

	if not is_instance_valid(player):
		_apply_friction(delta)
		return

	var dist = global_position.distance_to(player.global_position)

	# Angriffs-Check
	if dist <= attack_range and melee_cd_timer <= 0:
		try_melee()

	# Bewegung (nur wenn nicht angegriffen wird)
	if not animation_playing and not nav_agent.is_navigation_finished():
		var next_path_pos = nav_agent.get_next_path_position()
		var dir = (next_path_pos - global_position).normalized()
		velocity = velocity.move_toward(dir * run_speed, run_speed * acceleration * delta)
	else:
		_apply_friction(delta)

	move_and_slide()
	_handle_visuals()

func _apply_friction(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, run_speed * friction * delta)

func try_melee() -> void:
	melee_cd_timer = melee_cooldown
	animation_playing = true
	animated_sprite.play("Attack")
	
	# Hitbox aktivieren (wie beim Player)
	melee_hitbox.monitoring = true
	melee_active_timer = melee_active_time
	
	# Da der Ghoul kein "last_dir" braucht, greift er einfach in seiner Mitte/Area an
	# Falls die Area2D verschoben werden muss:
	var dir_to_player = (player.global_position - global_position).normalized()
	melee_hitbox.position = dir_to_player * 10.0

func _handle_visuals() -> void:
	if animation_playing: return
	
	# Flip Sprite basierend auf Spielerposition
	var to_player_x = player.global_position.x - global_position.x
	animated_sprite.flip_h = (to_player_x < 0)

	if velocity.length() > 10.0:
		animated_sprite.play("Move")
	else:
		animated_sprite.play("Idle")

func _on_died() -> void:
	queue_free()

# WICHTIG: Signal vom AnimatedSprite2D verbinden!
func _on_base_sprite_animation_finished() -> void:
	if animated_sprite.animation == "Attack":
		animation_playing = false

# Schaden applizieren, wenn Hitbox etwas berührt
func _on_melee_hitbox_area_entered(area: Area2D) -> void:
	if area is Hurtbox and area.owner.is_in_group(player_group):
		area.apply_damage(damage)
