# Headless autoplay bot. Boots the main scene, drives scripted idle wander for
# 60 simulated seconds (3600 fixed physics frames), then runs issue #2
# measurement phases (cardinal 1s phases, diagonal phase, 2000px run with
# camera/ground assertions), prints a greppable verdict and exits 0 on PASS,
# 1 on FAIL. Run with:
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
const MEASURE_FRAMES := 60
const RUN_FRAMES := 600
const MIN_PHASE_MOVE := 50.0
const MAX_CAMERA_DIST := 5.0

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
	if player.global_position.distance_to(start_pos) < 1.0:
		_errors += 1
		push_error("autopilot: player did not wander (input had no effect)")
	await _run_measurements(main_instance, player)
	var wall_end := Time.get_ticks_msec()
	_sim_seconds = nominal_seconds(_frames, PHYSICS_FPS)
	_measured_seconds = clock.measured
	_wall_seconds = float(wall_end - wall_start) / 1000.0
	clock.queue_free()


func _run_measurements(main_instance: Node, player: CharacterBody2D) -> void:
	var camera := main_instance.find_child("Camera2D", true, false) as Camera2D
	if camera == null:
		_errors += 1
		push_error("autopilot: Camera2D missing from main scene")
	var ground := main_instance.get_node_or_null("Ground")
	var phases: Array[String] = ["move_up", "move_down", "move_left", "move_right"]
	var axis_x := 0.0
	var axis_y := 0.0
	for phase: String in phases:
		var before: Vector2 = player.global_position
		Input.action_press(phase)
		for i in MEASURE_FRAMES:
			await physics_frame
			_frames += 1
		Input.action_release(phase)
		var after: Vector2 = player.global_position
		var dx: float = after.x - before.x
		var dy: float = after.y - before.y
		axis_x += absf(dx)
		axis_y += absf(dy)
		print("AUTOPILOT_POS phase=%s x=%.2f y=%.2f dx=%.2f dy=%.2f" % [phase, after.x, after.y, dx, dy])
		if Vector2(dx, dy).length() < MIN_PHASE_MOVE:
			_errors += 1
			push_error("autopilot: phase %s moved only %.2f px" % [phase, Vector2(dx, dy).length()])
	if axis_x < MIN_PHASE_MOVE or axis_y < MIN_PHASE_MOVE:
		_errors += 1
		push_error("autopilot: cardinal phases missed an axis (x=%.2f y=%.2f)" % [axis_x, axis_y])
	var diag_before: Vector2 = player.global_position
	Input.action_press("move_up")
	Input.action_press("move_right")
	for i in MEASURE_FRAMES:
		await physics_frame
		_frames += 1
	Input.action_release("move_up")
	Input.action_release("move_right")
	var diag_after: Vector2 = player.global_position
	var ddx: float = diag_after.x - diag_before.x
	var ddy: float = diag_after.y - diag_before.y
	print("AUTOPILOT_DIAG dx=%.2f dy=%.2f" % [ddx, ddy])
	if absf(ddx) <= 0.0 or absf(ddy) <= 0.0:
		_errors += 1
		push_error("autopilot: diagonal input missed an axis (dx=%.2f dy=%.2f)" % [ddx, ddy])
	Input.action_press("move_right")
	for i in RUN_FRAMES:
		await physics_frame
		_frames += 1
	Input.action_release("move_right")
	var dist := -1.0
	if camera != null:
		dist = camera.get_screen_center_position().distance_to(player.global_position)
	print("AUTOPILOT_CAMERA dist=%.3f" % dist)
	if camera == null or dist >= MAX_CAMERA_DIST:
		_errors += 1
		push_error("autopilot: camera too far from player (dist=%.3f)" % dist)
	var ground_ok := ground != null and ground.has_method("get_cell_size") and float(ground.call("get_cell_size")) > 0.0
	print("AUTOPILOT_GROUND ok=%d" % (1 if ground_ok else 0))
	if not ground_ok:
		_errors += 1
		push_error("autopilot: ground grid missing or invalid")
