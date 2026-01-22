extends CanvasLayer

@onready var player_hp_label: Label      = $PanelContainer/VBoxContainer/PlayerHP
@onready var potions_label: Label        = $PanelContainer/VBoxContainer/Potions
@onready var enemy_hp_label: Label       = $PanelContainer/VBoxContainer/EnemyHP

@onready var melee_duration: Label       = $PanelContainer/VBoxContainer/Melee_duration
@onready var melee_cooldown: Label       = $PanelContainer/VBoxContainer/Melee_cooldown
@onready var spell_cooldown: Label       = $PanelContainer/VBoxContainer/Spell_cooldown

var player: Node = null
var player_health: HealthComponent = null

var tracked_enemy: Node = null
var tracked_enemy_health: HealthComponent = null

func _ready() -> void:
	_find_player()
	_find_enemy()

func _process(_delta: float) -> void:
	_update_potions()
	_update_melee_spell_timers()
	_update_enemy_tracking()

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		player_hp_label.text = "Player HP: (no player group)"
		potions_label.text = "Potions: (no player)"
		melee_duration.text = "Melee Duration: (no player)"
		melee_cooldown.text = "Melee Cooldown: (no player)"
		spell_cooldown.text = "Spell: (no player)"
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

	tracked_enemy_health.hp_changed.connect(_on_enemy_hp_changed)
	tracked_enemy_health.died.connect(_on_enemy_died)
	_on_enemy_hp_changed(tracked_enemy_health.hp, tracked_enemy_health.max_hp)

func _update_enemy_tracking() -> void:
	var nearest = _get_nearest_enemy()
	if nearest == tracked_enemy:
		return

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

	var potions = player.get("heal_potions")
	if potions == null:
		potions_label.text = "Potions: (not found)"
	else:
		potions_label.text = "Potions: %s" % str(potions)

func _update_melee_spell_timers() -> void:
	if player == null:
		melee_duration.text = "Melee Duration: (no player)"
		melee_cooldown.text = "Melee Cooldown: (no player)"
		spell_cooldown.text = "Spell: (no player)"
		return

	# Duration = Hitbox aktiv (melee_active_timer)
	# Cooldown = bis wieder schlagen darf (melee_cd_timer)
	var melee_active_v: Variant = player.get("melee_active_timer")
	var melee_cd_v: Variant     = player.get("melee_cd_timer")
	var spell_cd_v: Variant     = player.get("spell_cd_timer")

	var md: float = 0.0
	var mc: float = 0.0
	var sc: float = 0.0

	if melee_active_v != null: md = float(melee_active_v)
	if melee_cd_v != null:     mc = float(melee_cd_v)
	if spell_cd_v != null:     sc = float(spell_cd_v)

	# Melee Duration
	if md <= 0.0:
		melee_duration.text = "Melee Duration: inactive"
	else:
		melee_duration.text = "Melee Duration: %.2fs" % md

	# Melee Cooldown
	if mc <= 0.0:
		melee_cooldown.text = "Melee Cooldown: ready"
	else:
		melee_cooldown.text = "Melee Cooldown: %.2fs" % mc

	# Spell Cooldown
	if sc <= 0.0:
		spell_cooldown.text = "Spell: ready"
	else:
		spell_cooldown.text = "Spell: %.2fs" % sc

func _on_player_hp_changed(current: int, max_hp: int) -> void:
	player_hp_label.text = "Player HP: %d / %d" % [current, max_hp]

func _on_enemy_hp_changed(current: int, max_hp: int) -> void:
	enemy_hp_label.text = "Enemy HP: %d / %d" % [current, max_hp]

func _on_enemy_died() -> void:
	enemy_hp_label.text = "Enemy HP: (dead)"
