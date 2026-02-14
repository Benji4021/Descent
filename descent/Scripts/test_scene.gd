extends Node2D
@onready var enemy = $Enemy;
@onready var player = $Player;

# Called when the node enters the scene tree for the first time.
func _ready():
	enemy.set_player(player)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
