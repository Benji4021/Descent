extends Area2D
#
# UpgradePickup.gd
# Beim Aufsammeln durch den Player gibt es zufällig:
# - +2 Melee-Schaden
# - +2 HP (max + current)
# - Spell-Cooldown reduziert (dauerhaft) + Rest-Cooldown sofort senken
#
# Node: Dieses Script kommt auf dein Pickup-Objekt (Area2D).
# CollisionShape2D muss vorhanden sein, Monitoring an.

enum UpgradeKind { RANDOM, MELEE_DAMAGE, MAX_HP, SPELL_COOLDOWN_REDUCE }

@export var kind: UpgradeKind = UpgradeKind.RANDOM

# Für MELEE_DAMAGE und MAX_HP (z.B. +2)
@export var amount: int = 2

# Für SPELL_COOLDOWN_REDUCE (in Sekunden, z.B. 2.0 => -2s)
@export var spell_cd_reduce_seconds: float = 2.0
@export var min_spell_cooldown: float = 0.25

@export var player_group: StringName = &"player"

var _picked_up: bool = false

func _ready() -> void:
	monitoring = true
	monitorable = true
	randomize()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _on_body_entered(body: Node) -> void:
	_try_pickup(body)

func _on_area_entered(area: Area2D) -> void:
	_try_pickup(area)

func _try_pickup(source: Object) -> void:
	if _picked_up:
		return

	var player: Node = _extract_player(source)
	if player == null:
		return

	_picked_up = true
	_apply_upgrade(player)
	queue_free()

func _extract_player(source: Object) -> Node:
	# 1) direkt der Player-Body
	if source is Node:
		var n: Node = source as Node
		if n.is_in_group(player_group):
			return n

	# 2) z.B. Hurtbox-Area (owner ist Player)
	if source is Area2D:
		var a: Area2D = source as Area2D
		if a.owner != null and a.owner is Node:
			var owner_node: Node = a.owner as Node
			if owner_node.is_in_group(player_group):
				return owner_node

	return null

func _apply_upgrade(player: Node) -> void:
	var chosen: UpgradeKind = _choose_kind()

	# Wenn Player eine zentrale Methode hat, nutzen wir die.
	if player.has_method("apply_upgrade"):
		match chosen:
			UpgradeKind.MELEE_DAMAGE:
				player.call("apply_upgrade", "melee_damage", amount)
			UpgradeKind.MAX_HP:
				player.call("apply_upgrade", "max_hp", amount)
			UpgradeKind.SPELL_COOLDOWN_REDUCE:
				player.call("apply_upgrade", "spell_cooldown_reduce", spell_cd_reduce_seconds, min_spell_cooldown)
			_:
				player.call("apply_upgrade", "unknown", amount)
		return

	# Fallback (falls du apply_upgrade nicht willst): direkt Werte ändern.
	match chosen:
		UpgradeKind.MELEE_DAMAGE:
			_apply_melee_damage(player, amount)
		UpgradeKind.MAX_HP:
			_apply_hp(player, amount)
		UpgradeKind.SPELL_COOLDOWN_REDUCE:
			_apply_spell_cd(player, spell_cd_reduce_seconds, min_spell_cooldown)

func _choose_kind() -> UpgradeKind:
	if kind != UpgradeKind.RANDOM:
		return kind

	# 3 Optionen: melee / hp / spell-cd
	var r: int = randi_range(0, 2)
	if r == 0:
		return UpgradeKind.MELEE_DAMAGE
	if r == 1:
		return UpgradeKind.MAX_HP
	return UpgradeKind.SPELL_COOLDOWN_REDUCE

func _apply_melee_damage(player: Node, add: int) -> void:
	# typischerweise Player hat melee_damage + die Hitbox nutzt es oder hat eigene damage
	if _has_property(player, "melee_damage"):
		player.set("melee_damage", int(player.get("melee_damage")) + add)

	var melee_hitbox: Node = player.get_node_or_null("MeleeHitbox")
	if melee_hitbox == null:
		melee_hitbox = player.find_child("MeleeHitbox", true, false)
	if melee_hitbox == null:
		return

	if _has_property(melee_hitbox, "damage"):
		melee_hitbox.set("damage", int(melee_hitbox.get("damage")) + add)
	elif _has_property(melee_hitbox, "hit_damage"):
		melee_hitbox.set("hit_damage", int(melee_hitbox.get("hit_damage")) + add)

func _apply_hp(player: Node, add: int) -> void:
	var hc: Node = player.get_node_or_null("HealthComponent")
	if hc == null:
		hc = player.find_child("HealthComponent", true, false)
	if hc == null:
		return

	if hc.has_method("increase_max_hp"):
		hc.call("increase_max_hp", add)
		return

	# Fallback über Properties
	if _has_property(hc, "max_hp"):
		hc.set("max_hp", int(hc.get("max_hp")) + add)
		if _has_property(hc, "hp"):
			hc.set("hp", int(hc.get("hp")) + add)
		return

	if _has_property(hc, "max_health"):
		hc.set("max_health", int(hc.get("max_health")) + add)
		if _has_property(hc, "health"):
			hc.set("health", int(hc.get("health")) + add)
		elif _has_property(hc, "current_health"):
			hc.set("current_health", int(hc.get("current_health")) + add)

func _apply_spell_cd(player: Node, reduce_seconds: float, min_cd: float) -> void:
	# erwartet beim Player: spell_cooldown + spell_cd_timer (wie in deinem Script)
	if _has_property(player, "spell_cooldown"):
		var new_cd := float(player.get("spell_cooldown")) - reduce_seconds
		player.set("spell_cooldown", max(min_cd, new_cd))

	# aktuellen Rest-Timer auch reduzieren (fühlt sich besser an)
	if _has_property(player, "spell_cd_timer"):
		var new_timer := float(player.get("spell_cd_timer")) - reduce_seconds
		player.set("spell_cd_timer", max(0.0, new_timer))

func _has_property(obj: Object, prop_name: String) -> bool:
	var list: Array = obj.get_property_list()
	for p in list:
		if typeof(p) == TYPE_DICTIONARY and p.has("name") and String(p["name"]) == prop_name:
			return true
	return false
