extends Node2D
## Minimal run coordinator: physics-clock run time, kill-counter API, and
## live StatusLabel refresh. Baseline hook for swarm/XP/kill laps.

@export var hud_refresh_interval := 0.25

var elapsed_seconds := 0.0
var kill_count := 0
var run_active := true
var game_over := false
var _hud_accum := 0.0
var _cached_alive := 0

var player: Node2D
var spawner: Node2D
var ground: Node2D
var status_label: Label
var _wired_health: Node


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
	_connect_health_signals()
	_connect_spawner_signals()
	_refresh_hud()


## Synchronous HUD refresh on player health events: non-lethal damage
## otherwise trails the 0.25s poll by up to a full interval. Direct calls
## only; _hud_accum keeps its overshoot schedule untouched.
func _connect_health_signals() -> void:
	if player == null or not is_instance_valid(player):
		player = get_node_or_null("Player") as Node2D
	if player == null or not is_instance_valid(player):
		return
	var health: Node = player.get_node_or_null("Health")
	if _wired_health != null and is_instance_valid(_wired_health) and _wired_health != health:
		if _wired_health.has_signal("health_changed"):
			if _wired_health.is_connected("health_changed", _on_player_health_changed):
				_wired_health.disconnect("health_changed", _on_player_health_changed)
		if _wired_health.has_signal("died"):
			if _wired_health.is_connected("died", _on_player_died):
				_wired_health.disconnect("died", _on_player_died)
	if health == null or not is_instance_valid(health):
		_wired_health = null
		return
	if health.has_signal("health_changed"):
		if not health.is_connected("health_changed", _on_player_health_changed):
			health.connect("health_changed", _on_player_health_changed)
	if health.has_signal("died"):
		if not health.is_connected("died", _on_player_died):
			health.connect("died", _on_player_died)
	_wired_health = health


func _on_player_health_changed(_current: float, _maximum: float) -> void:
	_refresh_hud()


func _on_player_died() -> void:
	end_run("death")


## Spawner push cache: keep ALIVE= fresh outside the 0.25s poll. Mirrors the
## _connect_health_signals guard idiom (null/valid, has_signal, is_connected).
func _connect_spawner_signals() -> void:
	if spawner == null or not is_instance_valid(spawner):
		spawner = get_node_or_null("Spawner") as Node2D
	if spawner == null or not is_instance_valid(spawner):
		return
	if spawner.has_signal("alive_changed"):
		if not spawner.is_connected("alive_changed", _on_spawner_alive_changed):
			spawner.connect("alive_changed", _on_spawner_alive_changed)
	if spawner.has_method("get_alive"):
		_cached_alive = int(spawner.call("get_alive"))


func _on_spawner_alive_changed(count: int) -> void:
	_cached_alive = count
	_refresh_hud()


func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	_connect_health_signals()
	if not run_active:
		return
	elapsed_seconds += delta
	_hud_accum += delta
	while hud_refresh_interval > 0.0 and _hud_accum >= hud_refresh_interval:
		_hud_accum -= hud_refresh_interval
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


func is_game_over() -> bool:
	return game_over


## Lethal run end: freeze the sim clock, spawner, and HUD (player and enemy
## motion keep running headless-harmlessly) and publish the greppable token.
func end_run(reason: String = "death") -> void:
	run_active = false
	if reason == "death":
		game_over = true
		print("RUN_END=death game_over=true ERRORS=0 elapsed=%.2f kills=%d" % [elapsed_seconds, kill_count])
	else:
		print("RUN_END=%s" % reason)
	_refresh_hud()


func restart_run() -> void:
	reset_run()


func get_peak_alive() -> int:
	if spawner == null or not is_instance_valid(spawner):
		return 0
	if not spawner.has_method("get_peak_alive"):
		return 0
	return int(spawner.call("get_peak_alive"))


func reset_run() -> void:
	elapsed_seconds = 0.0
	kill_count = 0
	run_active = true
	game_over = false
	_hud_accum = 0.0
	if spawner != null and is_instance_valid(spawner) and spawner.has_method("reset_peak"):
		spawner.call("reset_peak")
	if player != null and is_instance_valid(player) and player.has_method("restore_full_health"):
		player.call("restore_full_health")
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not game_over:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_R or key.physical_keycode == KEY_R):
			restart_run()


func _refresh_hud() -> void:
	if status_label == null or not is_instance_valid(status_label):
		return
	var alive := _cached_alive
	var hp := 100
	if player != null and is_instance_valid(player) and player.has_method("get_hp"):
		hp = int(player.call("get_hp"))
	status_label.text = "SIGKILL T+%.1fs HP=%d KILLS=%d ALIVE=%d" % [elapsed_seconds, hp, kill_count, alive]
	if game_over:
		status_label.text += "\nGAME_OVER press R to restart"
