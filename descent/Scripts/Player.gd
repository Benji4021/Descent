extends CharacterBody2D

@export var move_speed : float = 75
@onready var animated_sprite = $Base_Sprite
@onready var player_position = global_position

func _ready():

	
	if(Input.get_action_strength("shift")):
		move_speed = 175 #Sprint
		#move_speed = 25 #Sneak
	else:
		move_speed = 75
	

#get input direction
	var input_direction = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down") - Input.get_action_strength("up")
	)	

	#update velocity
	velocity = input_direction * move_speed

	#Flip the Sprite
	if input_direction.x > 0:
		animated_sprite.flip_h = false
		
	if input_direction.x < 0:
		animated_sprite.flip_h = true

	# Play appropriate animation based on movement
	if(velocity != Vector2(0, 0)):
		animated_sprite.play("Running")
		
	else:
		animated_sprite.play("Idle")
	
	#Move and Slide function uses velocity of character body to move character on map
	move_and_slide()
	#move_and_collide()
