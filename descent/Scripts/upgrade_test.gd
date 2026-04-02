extends Area2D

enum UpgradeKind {
	RANDOM,
	MELEE_DAMAGE,
	MAX_HP,
	SPELL_COOLDOWN_REDUCE,
	SPELL_DAMAGE,
	MOVE_SPEED,
	EXTRA_POTION
}

@export var kind: UpgradeKind = UpgradeKind.RANDOM

@export var stat_amount: int = 2
@export var spell_cd_reduce_seconds: float = 0.5
@export var min_spell_cooldown: float = 0.25
@export var move_speed_bonus: float = 20.0
@export var extra_potions: int = 1

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
	var chosen := _apply_upgrade(player)
	_show_upgrade_toast(chosen)
	queue_free()

func _extract_player(source: Object) -> Node:
	if source is Node:
		var n: Node = source as Node
		if n.is_in_group(player_group):
			return n

	if source is Area2D:
		var a: Area2D = source as Area2D
		if a.owner != null and a.owner is Node:
			var owner_node: Node = a.owner as Node
			if owner_node.is_in_group(player_group):
				return owner_node

	return null

func _apply_upgrade(player: Node) -> UpgradeKind:
	var chosen: UpgradeKind = _choose_kind()

	if player.has_method("apply_upgrade"):
		match chosen:
			UpgradeKind.MELEE_DAMAGE:
				player.call("apply_upgrade", "melee_damage", stat_amount)
			UpgradeKind.MAX_HP:
				player.call("apply_upgrade", "max_hp", stat_amount)
			UpgradeKind.SPELL_COOLDOWN_REDUCE:
				player.call("apply_upgrade", "spell_cooldown_reduce", spell_cd_reduce_seconds, min_spell_cooldown)
			UpgradeKind.SPELL_DAMAGE:
				player.call("apply_upgrade", "spell_damage", stat_amount)
			UpgradeKind.MOVE_SPEED:
				player.call("apply_upgrade", "move_speed", move_speed_bonus)
			UpgradeKind.EXTRA_POTION:
				player.call("apply_upgrade", "extra_potion", extra_potions)
			_:
				pass

	return chosen

func _show_upgrade_toast(chosen: UpgradeKind) -> void:
	var msg := ""

	match chosen:
		UpgradeKind.MELEE_DAMAGE:
			msg = "+%d Nahkampfschaden" % stat_amount
		UpgradeKind.MAX_HP:
			msg = "+%d Max-HP" % stat_amount
		UpgradeKind.SPELL_COOLDOWN_REDUCE:
			msg = "-%.2fs Zauber-Cooldown" % spell_cd_reduce_seconds
		UpgradeKind.SPELL_DAMAGE:
			msg = "+%d Zauberschaden" % stat_amount
		UpgradeKind.MOVE_SPEED:
			msg = "+%d Bewegungsgeschwindigkeit" % int(move_speed_bonus)
		UpgradeKind.EXTRA_POTION:
			msg = "+%d Heiltrank" % extra_potions
		_:
			return

	var scene := get_tree().current_scene
	if scene == null:
		return

	var toast := scene.get_node_or_null("UpgradeToast")
	if toast != null and toast.has_method("show_message"):
		toast.call("show_message", msg)

func _choose_kind() -> UpgradeKind:
	if kind != UpgradeKind.RANDOM:
		return kind

	var r := randi_range(0, 5)
	match r:
		0:
			return UpgradeKind.MELEE_DAMAGE
		1:
			return UpgradeKind.MAX_HP
		2:
			return UpgradeKind.SPELL_COOLDOWN_REDUCE
		3:
			return UpgradeKind.SPELL_DAMAGE
		4:
			return UpgradeKind.MOVE_SPEED
		5:
			return UpgradeKind.EXTRA_POTION
		_:
			return UpgradeKind.MELEE_DAMAGE
