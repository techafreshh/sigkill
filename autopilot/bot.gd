# Pure helpers for the 3-minute headless autoplay verdict
# (res://autopilot/verdict.gd). Loaded via preload as a RefCounted with
# static funcs only, so every helper stays unit-testable without booting the
# scene tree. Run the verdict with:
#   godot --headless --path . --script res://autopilot/verdict.gd
#
# SIM TIME CONTRACT: SIM_SECONDS is nominal frame-count time by design
# (frames / PHYSICS_FPS, exactly 180.00 for a full run). It is NOT wall-clock
# proof; see autopilot.gd for the measured/wall-clock idiom.
extends RefCounted

## Nominal 3-minute run length in simulated seconds.
const TARGET_SIM_SECONDS := 180.0
## Fixed physics rate the nominal clock assumes.
const PHYSICS_FPS := 60.0
## Total physics frames driven by the verdict runner (180 s * 60 fps).
const TOTAL_FRAMES := 10800
## Frames to hold one cardinal direction before re-evaluating.
const ROTATE_EVERY := 60
## Enemy distance (px) inside which the bot flees instead of wandering.
const FLEE_RADIUS := 200.0
## Acceptance thresholds for the 3-minute verdict line.
const SIM_MIN := 170.0
const KILLS_MIN := 20
const HP_MAX := 100
const RUN_END_OK := ["alive", "death"]


static func nominal_seconds(frames: int, fps: float) -> float:
	return float(frames) / fps


## Wander schedule: cycle ["move_up", "move_right", "move_down", "move_left"]
## one step per ROTATE_EVERY-frame block.
static func direction_for_index(i: int) -> String:
	var dirs: Array[String] = ["move_up", "move_right", "move_down", "move_left"]
	return dirs[posmod(i, dirs.size())]


## Flee override: "" when no enemy is within FLEE_RADIUS of the player,
## else the cardinal action most aligned with the away-from-nearest-enemy
## vector. Accepts Node2D enemies (uses global_position) or raw Vector2s.
static func flee_override(player_pos: Vector2, enemies: Array) -> String:
	var found := false
	var nearest := Vector2.ZERO
	var nearest_dist := FLEE_RADIUS
	for e in enemies:
		var pos := Vector2.ZERO
		var valid := false
		if e is Vector2:
			pos = e
			valid = true
		elif e is Node2D and is_instance_valid(e):
			pos = (e as Node2D).global_position
			valid = true
		if not valid:
			continue
		var dist := player_pos.distance_to(pos)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = pos
			found = true
	if not found:
		return ""
	var away := player_pos - nearest
	if away.length() <= 0.0:
		return ""
	var actions: Array[String] = ["move_up", "move_right", "move_down", "move_left"]
	var dirs: Array[Vector2] = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	var unit := away.normalized()
	var best := 0
	var best_dot := unit.dot(dirs[0])
	for i in range(1, dirs.size()):
		var dot := unit.dot(dirs[i])
		if dot > best_dot:
			best_dot = dot
			best = i
	return actions[best]


## Evaluate the 3-minute acceptance predicates. Returns
## {"ok": all pass, "error_count": failed count, "run_end_ok": RUN_END valid}.
static func check(sim_seconds: float, script_errors: int, kills: int, peak_alive: int, cap: int, hp: int, run_end: String) -> Dictionary:
	var failures := 0
	if sim_seconds < SIM_MIN:
		failures += 1
	if script_errors != 0:
		failures += 1
	if kills < KILLS_MIN:
		failures += 1
	if peak_alive > cap:
		failures += 1
	if hp > HP_MAX:
		failures += 1
	var run_end_ok := run_end in RUN_END_OK
	if not run_end_ok:
		failures += 1
	return {"ok": failures == 0, "error_count": failures, "run_end_ok": run_end_ok}


## Format the single greppable verdict line for CI gating.
static func format_verdict(sim_seconds: float, errors: int, kills: int, peak_alive: int, hp: int, run_end: String, passed: bool) -> String:
	var result := "PASS" if passed else "FAIL"
	return "AUTOPLAY_VERDICT_3MIN SIM_SECONDS=%.2f ERRORS=%d KILLS=%d MAX_ALIVE=%d PLAYER_HP=%d RUN_END=%s RESULT=%s" % [sim_seconds, errors, kills, peak_alive, hp, run_end, result]
