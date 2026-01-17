extends CanvasLayer

@onready var player_hp_label: Label = $PanelContainer/VBoxContainer/PlayerHP
@onready var potions_label: Label   = $PanelContainer/VBoxContainer/Potions
@onready var enemy_hp_label: Label  = $PanelContainer/VBoxContainer/EnemyHP

var player: Node = null
var player_health: HealthComponent = null

var tracked_enemy: Node = null
var tracked_enemy_health: HealthComponent = null

func _ready() -> void:
	_find_player()
	_find_enemy()

func _process(_delta: float) -> void:
	# Potions ändern sich oft ohne Signal -> einfach pro Frame updaten
	_update_potions()
	_update_enemy_tracking() # optional: immer nächsten Enemy anzeigen

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		player_hp_label.text = "Player HP: (no player group)"
		return

	player = players[0]
	player_health = player.get_node_or_null("HealthComponent")
	if player_health == null:
		player_hp_label.text = "Player HP: (no HealthComponent)"
		return

	player_health.hp_changed.connect(_on_player_hp_changed)
	_on_player_hp_changed(player_health.hp, player_health.max_hp)

func _find_enemy() -> void:
	tracked_enemy = _get_nearest_enemy()
	if tracked_enemy == null:
		enemy_hp_label.text = "Enemy HP: (none)"
		tracked_enemy_health = null
		return

	tracked_enemy_health = tracked_enemy.get_node_or_null("HealthComponent")
	if tracked_enemy_health == null:
		enemy_hp_label.text = "Enemy HP: (no HealthComponent)"
		return

	# falls du den Enemy tötest: label aktualisieren
	tracked_enemy_health.hp_changed.connect(_on_enemy_hp_changed)
	tracked_enemy_health.died.connect(_on_enemy_died)

	_on_enemy_hp_changed(tracked_enemy_health.hp, tracked_enemy_health.max_hp)

func _update_enemy_tracking() -> void:
	# Wenn du willst, dass immer der nächste Enemy angezeigt wird:
	var nearest = _get_nearest_enemy()
	if nearest == tracked_enemy:
		return

	# neu tracken
	tracked_enemy = null
	tracked_enemy_health = null
	_find_enemy()

func _get_nearest_enemy() -> Node:
	if player == null:
		return null

	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.size() == 0:
		return null

	var best: Node = null
	var best_d2 := INF

	for e in enemies:
		if not (e is Node2D): 
			continue
		var d2 = (e.global_position - (player as Node2D).global_position).length_squared()
		if d2 < best_d2:
			best_d2 = d2
			best = e

	return best

func _update_potions() -> void:
	if player == null:
		potions_label.text = "Potions: (no player)"
		return

	# liest einfach die Variable aus player.gd (heal_potions)
	var potions = player.get("heal_potions")
	if potions == null:
		potions_label.text = "Potions: (not found)"
	else:
		potions_label.text = "Potions: %s" % str(potions)

func _on_player_hp_changed(current: int, max_hp: int) -> void:
	player_hp_label.text = "Player HP: %d / %d" % [current, max_hp]

func _on_enemy_hp_changed(current: int, max_hp: int) -> void:
	enemy_hp_label.text = "Enemy HP: %d / %d" % [current, max_hp]

func _on_enemy_died() -> void:
	enemy_hp_label.text = "Enemy HP: (dead)"
