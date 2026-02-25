extends Area2D
#
# UpgradePickup.gd
# Beim Aufsammeln durch den Player gibt es entweder:
# - +2 Melee-Schaden
# - +2 Spell-Schaden
# - +2 HP (max + current, wenn möglich)
#
# Node: Dieses Script kommt auf dein Pickup-Objekt (Area2D).
# CollisionShape2D muss vorhanden sein, Monitoring an.
#
# Unterstützt 2 Arten von Triggern:
# - body_entered (Player-CharacterBody2D läuft drüber)
# - area_entered (Player-Hurtbox läuft drüber)

enum UpgradeKind { RANDOM, MELEE_DAMAGE, SPELL_DAMAGE, MAX_HP }

@export var kind: UpgradeKind = UpgradeKind.RANDOM
@export var amount: int = 2
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

	# sofort weg
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

	# Wenn du später im Player eine zentrale Methode haben willst:
	# func apply_upgrade(kind: String, amount: int) -> void:
	# Dann nutzen wir die automatisch.
	if player.has_method("apply_upgrade"):
		match chosen:
			UpgradeKind.MELEE_DAMAGE:
				player.call("apply_upgrade", "melee_damage", amount)
			UpgradeKind.SPELL_DAMAGE:
				player.call("apply_upgrade", "spell_damage", amount)
			UpgradeKind.MAX_HP:
				player.call("apply_upgrade", "max_hp", amount)
			_:
				player.call("apply_upgrade", "unknown", amount)
		return

	# Fallback: direkt Werte erhöhen
	match chosen:
		UpgradeKind.MELEE_DAMAGE:
			_apply_melee_damage(player, amount)
		UpgradeKind.SPELL_DAMAGE:
			_apply_spell_damage(player, amount)
		UpgradeKind.MAX_HP:
			_apply_hp(player, amount)

func _choose_kind() -> UpgradeKind:
	if kind != UpgradeKind.RANDOM:
		return kind

	var r: int = randi_range(0, 2)
	if r == 0:
		return UpgradeKind.MELEE_DAMAGE
	if r == 1:
		return UpgradeKind.SPELL_DAMAGE
	return UpgradeKind.MAX_HP

func _apply_melee_damage(player: Node, add: int) -> void:
	# typischerweise Player/MeleeHitbox hat eine Variable "damage"
	var melee_hitbox: Node = player.get_node_or_null("MeleeHitbox")
	if melee_hitbox == null:
		# fallback: vielleicht liegt sie anders
		melee_hitbox = player.find_child("MeleeHitbox", true, false)

	if melee_hitbox == null:
		return

	if _has_property(melee_hitbox, "damage"):
		var cur: int = int(melee_hitbox.get("damage"))
		melee_hitbox.set("damage", cur + add)
		return

	# alternative Namen, falls du anders benannt hast
	if _has_property(melee_hitbox, "hit_damage"):
		var cur2: int = int(melee_hitbox.get("hit_damage"))
		melee_hitbox.set("hit_damage", cur2 + add)
		return

func _apply_spell_damage(player: Node, add: int) -> void:
	# Am saubersten: Player hat einen Bonus-Wert, den du beim Spell-Spawn benutzt.
	# Wir versuchen ein paar typische Property-Namen.
	var candidates: Array[StringName] = [
		&"spell_damage_bonus",
		&"spell_bonus_damage",
		&"magic_damage_bonus",
		&"spell_damage",
		&"magic_damage"
	]

	for prop in candidates:
		if _has_property(player, String(prop)):
			var cur: int = int(player.get(String(prop)))
			player.set(String(prop), cur + add)
			return

	# Wenn du (noch) keine Spell-Damage-Variable hast:
	# Wir speichern es als Meta, damit du später leicht drauf zugreifen kannst:
	# var bonus = int(get_meta("spell_damage_bonus", 0))
	# set_meta("spell_damage_bonus", bonus + add)
	var meta_key: StringName = &"spell_damage_bonus"
	var cur_meta: int = 0
	if player.has_meta(meta_key):
		cur_meta = int(player.get_meta(meta_key))
	player.set_meta(meta_key, cur_meta + add)

func _apply_hp(player: Node, add: int) -> void:
	# HealthComponent unter Player finden
	var hc: Node = player.get_node_or_null("HealthComponent")
	if hc == null:
		hc = player.find_child("HealthComponent", true, false)

	if hc == null:
		return

	# Wenn dein HealthComponent eine Methode hat, bevorzugen wir die
	if hc.has_method("increase_max_hp"):
		hc.call("increase_max_hp", add)
		return

	# Sonst versuchen wir typische Property-Namen:
	# max_hp + hp (oder max_health + health/current_health)
	if _has_property(hc, "max_hp"):
		var max_hp: int = int(hc.get("max_hp"))
		hc.set("max_hp", max_hp + add)

		# current hp gleich mit erhöhen (falls vorhanden)
		if _has_property(hc, "hp"):
			var hp: int = int(hc.get("hp"))
			hc.set("hp", hp + add)
		return

	if _has_property(hc, "max_health"):
		var max_h: int = int(hc.get("max_health"))
		hc.set("max_health", max_h + add)

		if _has_property(hc, "health"):
			var h: int = int(hc.get("health"))
			hc.set("health", h + add)
		elif _has_property(hc, "current_health"):
			var ch: int = int(hc.get("current_health"))
			hc.set("current_health", ch + add)
		return

func _has_property(obj: Object, prop_name: String) -> bool:
	var list: Array = obj.get_property_list()
	for p in list:
		# p ist Dictionary mit keys wie "name"
		if typeof(p) == TYPE_DICTIONARY and p.has("name") and String(p["name"]) == prop_name:
			return true
	return false
