# Headless autoplay bot. Boots the main scene, drives scripted idle wander for
# 60 simulated seconds (3600 fixed physics frames), then prints a greppable
# verdict and exits 0 on PASS, 1 on FAIL. Run with:
#   godot --headless --path . --script res://autopilot/autopilot.gd
#
# SIM TIME CONTRACT: SIM_SECONDS is nominal frame-count time by design
# (frames / PHYSICS_FPS, exactly 60.00 for a full run). It is NOT wall-clock
# proof. MEASURED_SECONDS (sum of real per-tick delta observed by SimClock)
# and WALL_SECONDS (wall-clock elapsed via Time.get_ticks_msec around the
# wander loop) are the only wall-clock evidence; CI gates strictly on the
# nominal clock and sanity-checks measured/wall loosely.
extends SceneTree

class SimClock extends Node:
	var measured := 0.0

	func _physics_process(delta: float) -> void:
		measured += delta


static func nominal_seconds(frames: int, fps: float) -> float:
	return float(frames) / fps


const TOTAL_PHYSICS_FRAMES := 3600
const PHYSICS_FPS := 60.0
const FRAMES_PER_DIRECTION := 60

var _errors := 0
var _sim_seconds := 0.0
var _measured_seconds := 0.0
var _wall_seconds := 0.0
var _frames := 0


func _initialize() -> void:
	await _run()
	var result := "PASS" if _errors == 0 else "FAIL"
	print("AUTOPLAY_VERDICT ERRORS=%d SIM_SECONDS=%.2f MEASURED_SECONDS=%.2f WALL_SECONDS=%.2f FRAMES=%d RESULT=%s" % [_errors, _sim_seconds, _measured_seconds, _wall_seconds, _frames, result])
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
	var clock := SimClock.new()
	root.add_child(clock)
	var start_pos := player.global_position
	var directions: Array[String] = ["move_up", "move_right", "move_down", "move_left"]
	var current := 0
	Input.action_press(directions[current])
	var wall_start := Time.get_ticks_msec()
	for frame in TOTAL_PHYSICS_FRAMES:
		if frame > 0 and frame % FRAMES_PER_DIRECTION == 0:
			Input.action_release(directions[current])
			current = (current + 1) % directions.size()
			Input.action_press(directions[current])
		await physics_frame
		_frames += 1
	for action: String in directions:
		Input.action_release(action)
	var wall_end := Time.get_ticks_msec()
	_sim_seconds = nominal_seconds(_frames, PHYSICS_FPS)
	_measured_seconds = clock.measured
	_wall_seconds = float(wall_end - wall_start) / 1000.0
	clock.queue_free()
	if player.global_position.distance_to(start_pos) < 1.0:
		_errors += 1
		push_error("autopilot: player did not wander (input had no effect)")
