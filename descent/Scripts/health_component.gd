extends Node
class_name HealthComponent

signal died
signal hp_changed(current: int, max_hp: int)

@export var max_hp: int = 10
var hp: int

func _ready():
	hp = max_hp
	hp_changed.emit(hp, max_hp)

func take_damage(amount: int) -> void:
	if amount <= 0: return
	hp = max(hp - amount, 0)
	hp_changed.emit(hp, max_hp)
	if hp == 0:
		died.emit()

func heal(amount: int) -> void:
	if amount <= 0: return
	hp = min(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)

func is_full() -> bool:
	return hp >= max_hp
