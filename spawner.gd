extends Node2D
## Off-screen ring spawner. Spawns chaser enemies on a player-centered ring
## just outside the viewport, refusing to exceed max_entities.

const CHASER_SCENE: PackedScene = preload("res://enemies/chaser.tscn")
const FALLBACK_VIEWPORT_SIZE := Vector2(1280, 720)
const STATUS_EVERY_TICKS := 60

@export var max_entities := 300
@export var spawn_interval := 0.5
@export var batch_size := 1
@export var spawn_margin_min := 50.0
@export var spawn_margin_max := 150.0
@export var chaser_scene: PackedScene = CHASER_SCENE
@export var player_path: NodePath
## When true, emits SPAWNER_STATUS / SPAWNER_SPAWN diagnostics. Silent by default.
@export var verbose := false

var player: Node2D
var peak_alive := 0
var _accum := 0.0
var _tick := 0


func get_peak_alive() -> int:
	return peak_alive


func reset_peak() -> void:
	peak_alive = 0


func _update_peak() -> void:
	var alive := get_tree().get_nodes_in_group("enemies").size()
	if alive > peak_alive:
		peak_alive = alive


func _is_run_active() -> bool:
	var coordinator := get_parent()
	if coordinator == null or not is_instance_valid(coordinator):
		return true
	if coordinator.has_method("is_run_active"):
		return bool(coordinator.call("is_run_active"))
	if "run_active" in coordinator:
		return bool(coordinator.get("run_active"))
	return true


func _ready() -> void:
	_resolve_player()


func _physics_process(delta: float) -> void:
	if not _is_run_active():
		return
	_tick += 1
	_update_peak()
	_accum += delta
	while spawn_interval > 0.0 and _accum >= spawn_interval:
		_accum -= spawn_interval
		_try_spawn()
	if _tick % STATUS_EVERY_TICKS == 0 and verbose:
		var current := get_tree().get_nodes_in_group("enemies").size()
		print("SPAWNER_STATUS get_nodes_in_group(\"enemies\").size()=%d MAX_ALIVE=%d" % [current, peak_alive])


## Kill accounting: a spawner-produced chaser that emits died was lethally
## damaged, so log the poof placeholder and forward the kill to the run
## coordinator through the same guarded lookup shape as _is_run_active.
func _on_enemy_died(enemy: Node) -> void:
	var pos := Vector2.ZERO
	if enemy != null and is_instance_valid(enemy) and enemy is Node2D:
		pos = (enemy as Node2D).global_position
	var coordinator := get_parent()
	var kills := 1
	if coordinator != null and is_instance_valid(coordinator):
		if coordinator.has_method("get_kills"):
			kills = int(coordinator.call("get_kills")) + 1
		print("ENEMY_POOF XP_PLACEHOLDER kills=%d pos=(%.1f, %.1f)" % [kills, pos.x, pos.y])
		if coordinator.has_method("register_kill"):
			coordinator.call("register_kill")
		return
	print("ENEMY_POOF XP_PLACEHOLDER kills=%d pos=(%.1f, %.1f)" % [kills, pos.x, pos.y])


func _resolve_player() -> void:
	if player_path != null and not player_path.is_empty():
		player = get_node_or_null(player_path) as Node2D
	if player == null:
		player = get_node_or_null("../Player") as Node2D
	if player == null and get_tree() != null:
		player = get_tree().get_first_node_in_group("player") as Node2D


func _min_view_radius() -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = FALLBACK_VIEWPORT_SIZE
	return 0.5 * viewport_size.length()


func _spawn_center() -> Vector2:
	if is_instance_valid(player):
		return (player as Node2D).global_position
	push_error("spawner: no valid player; skipping spawn")
	return global_position


func _try_spawn() -> void:
	if not _is_run_active():
		return
	var alive := get_tree().get_nodes_in_group("enemies").size()
	if alive >= max_entities:
		return
	var room: int = mini(batch_size, max_entities - alive)
	if room <= 0:
		return
	if not is_instance_valid(player):
		_resolve_player()
	if not is_instance_valid(player):
		push_error("spawner: no valid player; skipping spawn")
		return
	var center := _spawn_center()
	var radius := _min_view_radius()
	for i in room:
		var scene: PackedScene = chaser_scene if chaser_scene != null else CHASER_SCENE
		if scene == null:
			return
		var chaser := scene.instantiate() as Node2D
		if chaser == null:
			return
		var angle := randf() * TAU
		var dist := radius + randf_range(spawn_margin_min, spawn_margin_max)
		add_child(chaser)
		chaser.global_position = center + Vector2(cos(angle), sin(angle)) * dist
		if is_instance_valid(player):
			chaser.set("target", player)
		if chaser.has_signal("died"):
			chaser.connect("died", _on_enemy_died.bind(chaser))
		if verbose:
			var now_alive := get_tree().get_nodes_in_group("enemies").size()
			print("SPAWNER_SPAWN SPAWN_DIST=%.2f MIN_VIEW_RADIUS=%.2f ALIVE=%d" % [dist, radius, now_alive])
	_update_peak()
