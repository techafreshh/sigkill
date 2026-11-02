extends Node2D
## Bolt auto-weapon: child of the Player, fires a single non-piercing
## projectile at the nearest enemy in range on a Timer-driven cooldown.
## No attack input exists anywhere; aiming is a snapshot taken at fire time.

const ProjectileScript := preload("res://weapons/projectile.gd")

@export var cooldown := 0.8
# Covers the spawner off-screen ring (viewport half-diagonal + spawn_margin_max ≈ 884px at 1280x720) so fresh spawns are engageable on spawn.
@export var attack_range := 950.0
@export var projectile_speed := 700.0
@export var damage := 1

var shots := 0

@onready var _timer: Timer = $Cooldown


func _ready() -> void:
	if _timer != null:
		_timer.wait_time = cooldown
		_timer.start()


func _is_run_active() -> bool:
	if not is_inside_tree():
		return true
	var node := get_parent()
	while node != null and is_instance_valid(node):
		if node.has_method("is_run_active"):
			return bool(node.call("is_run_active"))
		if "run_active" in node:
			return bool(node.get("run_active"))
		node = node.get_parent()
	return true


func _on_cooldown_timeout() -> void:
	if not _is_run_active():
		return
	_try_fire()
	if is_instance_valid(_timer):
		_timer.start()


func _try_fire() -> void:
	if not _is_run_active():
		return
	if get_tree() == null:
		return
	var origin := global_position
	var best: Node2D = null
	var best_dist := 0.0
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == null or not is_instance_valid(node):
			continue
		if not (node is Node2D):
			continue
		var enemy := node as Node2D
		var dist := origin.distance_to(enemy.global_position)
		if dist > attack_range:
			continue
		if best == null or dist < best_dist:
			best = enemy
			best_dist = dist
	if best == null:
		return
	var projectile := ProjectileScript.new()
	if projectile == null:
		return
	var host: Node = get_tree().current_scene
	if host == null:
		var holder := get_parent()
		if holder != null and holder.get_parent() != null:
			host = holder.get_parent()
		else:
			host = get_tree().root
	host.add_child(projectile)
	projectile.call("launch", origin, best.global_position, projectile_speed, damage, attack_range)
	shots += 1
	print("BOLT_FIRE projectiles_spawned=%d target_dist=%.1f" % [shots, best_dist])
