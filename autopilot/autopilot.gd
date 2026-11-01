# Headless autoplay bot. Boots the main scene, drives scripted idle wander for
# 60 simulated seconds (3600 fixed physics frames), then prints a greppable
# verdict and exits 0 on PASS, 1 on FAIL. Run with:
#   godot --headless --path . --script res://autopilot/autopilot.gd
extends SceneTree

const TOTAL_PHYSICS_FRAMES := 3600
const PHYSICS_FPS := 60.0
const FRAMES_PER_DIRECTION := 60

var _errors := 0
var _sim_seconds := 0.0


func _initialize() -> void:
	await _run()
	var result := "PASS" if _errors == 0 else "FAIL"
	print("AUTOPLAY_VERDICT ERRORS=%d SIM_SECONDS=%.2f RESULT=%s" % [_errors, _sim_seconds, result])
	quit(0 if _errors == 0 else 1)


func _run() -> void:
	await process_frame
	var packed := load("res://main.tscn") as PackedScene
	if packed == null:
		_errors += 1
		push_error("autopilot: failed to load res://main.tscn")
		return
	var main_instance := packed.instantiate()
	root.add_child(main_instance)
	await process_frame
	var player := main_instance.get_node_or_null("Player") as CharacterBody2D
	if player == null:
		_errors += 1
		push_error("autopilot: Player node missing from main scene")
		return
	var start_pos := player.global_position
	var directions: Array[String] = ["move_up", "move_right", "move_down", "move_left"]
	var current := 0
	Input.action_press(directions[current])
	for frame in TOTAL_PHYSICS_FRAMES:
		if frame > 0 and frame % FRAMES_PER_DIRECTION == 0:
			Input.action_release(directions[current])
			current = (current + 1) % directions.size()
			Input.action_press(directions[current])
		await physics_frame
		_sim_seconds += 1.0 / PHYSICS_FPS
	for action: String in directions:
		Input.action_release(action)
	if player.global_position.distance_to(start_pos) < 1.0:
		_errors += 1
		push_error("autopilot: player did not wander (input had no effect)")
