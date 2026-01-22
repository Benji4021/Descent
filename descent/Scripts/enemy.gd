extends CharacterBody2D

@export var speed: float = 150.0
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var animated_sprite = $Base_Sprite

var player: Node2D

func _ready():
	hurtbox.health = health
	health.died.connect(func(): queue_free())

func set_player(p: Node2D) -> void:
	player = p

func _physics_process(delta: float) -> void:
	if player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dir = (player.global_position - global_position).normalized()
	velocity = dir * speed
	if velocity.x > 0:
		animated_sprite.flip_h = true
	if velocity.x < 0:
		animated_sprite.flip_h = false
	animated_sprite.play("Move")
	move_and_slide()
