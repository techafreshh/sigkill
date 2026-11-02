# Headless 3-minute autoplay verdict. Boots the main scene, drives wander
# movement (~10800 physics frames, one cardinal direction per ROTATE_EVERY
# block with nearest-enemy flee override; Bolt auto-fires, no attack input
# exists), survives player death without resetting (death evidence must reach
# the verdict), then prints one greppable AUTOPLAY_VERDICT_3MIN line and exits
# 0 on PASS, 1 on FAIL. Run with:
#   godot --headless --path . --script res://autopilot/verdict.gd
#
# SIM TIME CONTRACT: SIM_SECONDS is nominal frame-count time by design
# (frames / 60.0, exactly 180.00 for a full run), counted even after death.
# It is NOT wall-clock proof.
extends SceneTree

const Bot := preload("res://autopilot/bot.gd")

class SimClock extends Node:
	var measured := 0.0

	func _physics_process(delta: float) -> void:
		measured += delta


var _errors := 0
var _frames := 0


func _initialize() -> void:
	await _run()
	quit(0 if _errors == 0 else 1)


func _run() -> void:
	await process_frame
	var packed := load("res://main.tscn") as PackedScene
	var main_instance: Node = null
	if packed == null:
		_errors += 1
		push_error("verdict3min: failed to load res://main.tscn")
	else:
		main_instance = packed.instantiate()
		root.add_child(main_instance)
		await process_frame
	var player: CharacterBody2D = null
	var spawner: Node = null
	if main_instance != null and is_instance_valid(main_instance):
		player = main_instance.get_node_or_null("Player") as CharacterBody2D
		spawner = main_instance.get_node_or_null("Spawner")
	if player == null:
		_errors += 1
		push_error("verdict3min: Player node missing from main scene")
	if spawner == null:
		_errors += 1
		push_error("verdict3min: Spawner node missing from main scene")
	var clock := SimClock.new()
	root.add_child(clock)
	var dirs: Array[String] = ["move_up", "move_right", "move_down", "move_left"]
	var current := ""
	if player != null:
		for frame in Bot.TOTAL_FRAMES:
			var over := main_instance != null and is_instance_valid(main_instance) and main_instance.has_method("is_game_over") and bool(main_instance.call("is_game_over"))
			if over:
				for action: String in dirs:
					Input.action_release(action)
				current = ""
			elif frame % Bot.ROTATE_EVERY == 0 or current.is_empty():
				var want := Bot.direction_for_index(frame / Bot.ROTATE_EVERY)
				if player != null and is_instance_valid(player):
					var flee := Bot.flee_override((player as Node2D).global_position, get_nodes_in_group("enemies"))
					if not flee.is_empty():
						want = flee
				if want != current:
					for action: String in dirs:
						Input.action_release(action)
					Input.action_press(want)
					current = want
			await physics_frame
			_frames += 1
	for action: String in dirs:
		Input.action_release(action)
	var sim_seconds := Bot.nominal_seconds(_frames, Bot.PHYSICS_FPS)
	var kills := 0
	var peak_alive := 0
	var hp := 0
	var run_end := "unknown"
	var cap := 300
	if main_instance != null and is_instance_valid(main_instance):
		if main_instance.has_method("get_kills"):
			kills = int(main_instance.call("get_kills"))
		else:
			_errors += 1
			push_error("verdict3min: main is missing get_kills")
		if main_instance.has_method("get_peak_alive"):
			peak_alive = int(main_instance.call("get_peak_alive"))
		else:
			_errors += 1
			push_error("verdict3min: main is missing get_peak_alive")
		if main_instance.has_method("is_game_over") and main_instance.has_method("get_run_reason"):
			if bool(main_instance.call("is_game_over")):
				run_end = str(main_instance.call("get_run_reason"))
			else:
				run_end = "alive"
		else:
			_errors += 1
			push_error("verdict3min: main is missing run-end API")
	if player != null and is_instance_valid(player) and player.has_method("get_hp"):
		hp = maxi(0, int(float(player.call("get_hp"))))
	else:
		_errors += 1
		push_error("verdict3min: player HP unreadable")
	if spawner != null and is_instance_valid(spawner):
		cap = int(spawner.get("max_entities"))
	var res := Bot.check(sim_seconds, _errors, kills, peak_alive, cap, hp, run_end)
	# check() counts nonzero script errors as one failure; add infra errors
	# once so ERRORS reflects every problem without double counting.
	var verdict_errors := _errors + int(res["error_count"])
	if _errors != 0:
		verdict_errors -= 1
	_errors = verdict_errors
	var passed := verdict_errors == 0
	print(Bot.format_verdict(sim_seconds, verdict_errors, kills, peak_alive, hp, run_end, passed))
	clock.queue_free()
