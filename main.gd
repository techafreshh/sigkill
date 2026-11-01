extends Node2D
## Minimal run coordinator: physics-clock run time, kill-counter API, and
## live StatusLabel refresh. Baseline hook for swarm/XP/kill laps.

@export var hud_refresh_interval := 0.25

var elapsed_seconds := 0.0
var kill_count := 0
var run_active := true
var _hud_accum := 0.0

var player: Node2D
var spawner: Node2D
var ground: Node2D
var status_label: Label


func _ready() -> void:
	print("MAIN_READY SIGKILL walking skeleton")
	player = get_node_or_null("Player") as Node2D
	spawner = get_node_or_null("Spawner") as Node2D
	ground = get_node_or_null("Ground") as Node2D
	status_label = get_node_or_null("StatusLabel") as Label
	elapsed_seconds = 0.0
	kill_count = 0
	run_active = true
	_hud_accum = 0.0
	_refresh_hud()


func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	if not run_active:
		return
	elapsed_seconds += delta
	_hud_accum += delta
	if _hud_accum >= hud_refresh_interval:
		_hud_accum = 0.0
		_refresh_hud()


func register_kill() -> void:
	kill_count += 1
	_refresh_hud()


func get_elapsed() -> float:
	return elapsed_seconds


func get_kills() -> int:
	return kill_count


func is_run_active() -> bool:
	return run_active


func reset_run() -> void:
	elapsed_seconds = 0.0
	kill_count = 0
	run_active = true
	_hud_accum = 0.0
	_refresh_hud()


func _refresh_hud() -> void:
	if status_label == null or not is_instance_valid(status_label):
		return
	var alive := 0
	if get_tree() != null:
		alive = get_tree().get_nodes_in_group("enemies").size()
	status_label.text = "SIGKILL T+%.1fs KILLS=%d ALIVE=%d" % [elapsed_seconds, kill_count, alive]
