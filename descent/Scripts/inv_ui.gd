extends Control
@onready var inv : Inv = preload("res://inventory/playerinv.tres") 
@onready var slots : Array = $NinePatchRect/GridContainer.get_children()

var is_open = false 
func _ready(): 
	close()



func _process(delta: float) -> void:
	if Input.is_action_just_pressed("e"): 
		if is_open: 
			close() 
		else: 
			open()  

func open(): 
	visible = true 
	is_open = true 

func close(): 
	visible=false 
	is_open = false 
