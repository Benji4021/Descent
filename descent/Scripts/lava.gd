extends Area2D

@export var damage_per_tick := 1
@export var tick_speed := 1.0 # Sekunden zwischen jedem Schadens-Tick

@export var burn_duration := 2.5      # wie lange nach Verlassen weiter brennen
@export var burn_damage_per_tick := 1 # DOT-Schaden während Burning
@export var burn_tick_speed := 2    # Tick-Intervall fürs Burning (Sek)

@onready var timer: Timer = $DamageTimer

func _ready():
	# Wir brauchen Signale für "rein" und "raus"
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Timer-Setup
	timer.wait_time = tick_speed
	timer.timeout.connect(_apply_lava_damage)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("set_in_lava"):
			body.call("set_in_lava", true)
		if body.has_method("apply_burn"):
			body.call("apply_burn", burn_duration, burn_damage_per_tick, burn_tick_speed)
		_apply_lava_damage() # Sofort beim ersten Kontakt Schaden machen
		timer.start()        # Dann den Rhythmus starten

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("set_in_lava"):
			body.call("set_in_lava", false)
		timer.stop()         # Aufhören, wenn der Spieler die Lava verlässt

func _apply_lava_damage() -> void:
	# Wir prüfen alle Körper in der Lava (falls mehrere drin stehen)
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			if body.has_method("apply_burn"):
				body.call("apply_burn", burn_duration, burn_damage_per_tick, burn_tick_speed)
			var health = body.get_node_or_null("HealthComponent")
			if health != null:
				health.take_damage(damage_per_tick)
