extends Node2D
## Minimal run coordinator: physics-clock run time, kill-counter API, and
## live StatusLabel refresh. Baseline hook for swarm/XP/kill laps.

@export var hud_refresh_interval := 0.25

var elapsed_seconds := 0.0
var kill_count := 0
var run_active := true
var game_over := false
var run_reason := "death"
var _hud_accum := 0.0
var _cached_alive := 0

var player: Node2D
var spawner: Node2D
var ground: Node2D
var status_label: Label
var _wired_health: Node
var _wired_spawner: Node


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
	var current := get_node_or_null("Player") as Node2D
	if current == null or not is_instance_valid(current):
		if _wired_health != null and is_instance_valid(_wired_health):
			if _wired_health.has_signal("health_changed"):
				if _wired_health.is_connected("health_changed", _on_player_health_changed):
					_wired_health.disconnect("health_changed", _on_player_health_changed)
			if _wired_health.has_signal("died"):
				if _wired_health.is_connected("died", _on_player_died):
					_wired_health.disconnect("died", _on_player_died)
		player = current
		_wired_health = null
		return
	player = current
	var health: Node = current.get_node_or_null("Health")
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
## _connect_health_signals guard idiom (null/valid, has_signal, is_connected)
## with fresh child lookup each call, so a same-name replacement Spawner
## rewires within one physics tick even while the old node stays valid.
func _connect_spawner_signals() -> void:
	var current := get_node_or_null("Spawner") as Node2D
	if _wired_spawner != null and is_instance_valid(_wired_spawner) and _wired_spawner != current:
		if _wired_spawner.has_signal("alive_changed"):
			if _wired_spawner.is_connected("alive_changed", _on_spawner_alive_changed):
				_wired_spawner.disconnect("alive_changed", _on_spawner_alive_changed)
	if current == null or not is_instance_valid(current):
		spawner = current
		_wired_spawner = null
		return
	if current.has_signal("alive_changed"):
		if not current.is_connected("alive_changed", _on_spawner_alive_changed):
			current.connect("alive_changed", _on_spawner_alive_changed)
	spawner = current
	_wired_spawner = current
	if current.has_method("get_alive"):
		_cached_alive = int(current.call("get_alive"))


func _on_spawner_alive_changed(count: int) -> void:
	_cached_alive = count
	_refresh_hud()


func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	if not run_active:
		return
	_connect_spawner_signals()
	_connect_health_signals()
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


func get_run_reason() -> String:
	return run_reason


## Allowlist run-reason sanitizer: keep [A-Za-z0-9_-], map all else to _.
func _sanitize_run_reason(reason: String) -> String:
	if reason.is_empty():
		return "unknown"
	var out := ""
	for i in reason.length():
		var code := reason.unicode_at(i)
		if (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95 or code == 45:
			out += reason.substr(i, 1)
		else:
			out += "_"
	if out.is_empty():
		return "unknown"
	return out


## Terminal run end: freeze the sim clock, spawner, and HUD (player and enemy
## motion keep running headless-harmlessly) and publish the greppable token.
func end_run(reason: String = "death") -> void:
	if game_over:
		return
	var safe := _sanitize_run_reason(reason)
	run_reason = safe
	run_active = false
	game_over = true
	if safe == "death":
		print("RUN_END=death game_over=true ERRORS=0 elapsed=%.2f kills=%d" % [elapsed_seconds, kill_count])
	else:
		print("RUN_END=%s game_over=true ERRORS=0 elapsed=%.2f kills=%d" % [safe, elapsed_seconds, kill_count])
	_refresh_hud()


func restart_run() -> void:
	reset_run()


func get_peak_alive() -> int:
	var live: Node = get_node_or_null("Spawner")
	if live != null and is_instance_valid(live) and live.has_method("get_peak_alive"):
		return int(live.call("get_peak_alive"))
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
	run_reason = "death"
	_hud_accum = 0.0
	player = get_node_or_null("Player") as Node2D
	spawner = get_node_or_null("Spawner") as Node2D
	if spawner != null and is_instance_valid(spawner) and spawner.has_method("reset_peak"):
		spawner.call("reset_peak")
	if player != null and is_instance_valid(player) and player.has_method("restore_full_health"):
		player.call("restore_full_health")
	_connect_health_signals()
	_connect_spawner_signals()
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
		status_label.text += "\nGAME_OVER " + run_reason + " press R to restart"
