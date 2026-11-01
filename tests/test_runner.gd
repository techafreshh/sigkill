# Headless test entrypoint. Run with:
#   godot --headless --path . --script res://tests/test_runner.gd
# Exits 0 when every test passes, 1 otherwise, so CI can gate on the exit code.
extends SceneTree

const MOVE_ACTIONS: Array[String] = ["move_up", "move_down", "move_left", "move_right"]
const AutopilotScript := preload("res://autopilot/autopilot.gd")

var passed := 0
var failed := 0


func _initialize() -> void:
	await run_all()
	print("Results: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func assert_eq(actual: Variant, expected: Variant, label: String) -> bool:
	if actual == expected:
		return true
	push_error("FAIL %s: expected %s, got %s" % [label, str(expected), str(actual)])
	return false


func assert_true(value: bool, label: String) -> bool:
	return assert_eq(value, true, label)


func run_all() -> void:
	var tests: Array[String] = [
		"test_input_map_has_move_actions",
		"test_main_scene_loads",
		"test_theme_resource_exists",
		"test_player_is_cursor_block",
		"test_player_moves_all_axes",
		"test_camera_follows_player",
		"test_ground_renders",
		"test_sanity_math",
		"test_nominal_seconds_math",
		"test_measured_clock_accumulates",
	]
	for t: String in tests:
		var outcome: Variant = await call(t)
		if outcome == true:
			passed += 1
			print("PASS %s" % t)
		else:
			failed += 1
			push_error("FAIL %s: did not finish (runtime error?)" % t)


func _release_move_actions() -> void:
	for action: String in MOVE_ACTIONS:
		Input.action_release(action)


func _instantiate_main() -> Node:
	var packed := load("res://main.tscn") as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate()
	root.add_child(instance)
	return instance


func test_input_map_has_move_actions() -> bool:
	var ok := true
	for action: String in MOVE_ACTIONS:
		if not InputMap.has_action(action):
			push_error("FAIL test_input_map_has_move_actions: missing action " + action)
			ok = false
		elif InputMap.action_get_events(action).size() < 2:
			push_error("FAIL test_input_map_has_move_actions: action needs WASD+arrow bindings: " + action)
			ok = false
	return ok


func test_main_scene_loads() -> bool:
	var ok := true
	ok = assert_true(ResourceLoader.exists("res://main.tscn"), "main scene exists") and ok
	var packed := load("res://main.tscn") as PackedScene
	ok = assert_true(packed != null, "main scene loads as PackedScene") and ok
	if packed == null:
		return false
	await process_frame
	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame
	ok = assert_true(is_instance_valid(instance), "main scene instance valid in tree") and ok
	ok = assert_true(instance.get_node_or_null("Player") != null, "main scene has Player") and ok
	instance.queue_free()
	return ok


func test_theme_resource_exists() -> bool:
	var ok := true
	ok = assert_true(ResourceLoader.exists("res://data/theme.tres"), "theme resource exists") and ok
	var theme: Resource = load("res://data/theme.tres")
	ok = assert_true(theme != null, "theme resource loads") and ok
	if theme == null:
		return false
	ok = assert_true(theme.get("player_color") is Color, "theme has player_color") and ok
	ok = assert_true(theme.get("grid_color") is Color, "theme has grid_color") and ok
	ok = assert_true(theme.get("grid_major_color") is Color, "theme has grid_major_color") and ok
	ok = assert_true(theme.get("background_color") is Color, "theme has background_color") and ok
	ok = assert_true(float(theme.get("grid_cell_size")) > 0.0, "theme grid cell size positive") and ok
	var glyphs: Variant = theme.get("glyphs")
	ok = assert_true(glyphs is PackedStringArray and (glyphs as PackedStringArray).size() > 0, "theme has glyph map") and ok
	ok = assert_true(theme.get("font") != null, "theme has monospace font") and ok
	return ok


func test_player_is_cursor_block() -> bool:
	var ok := true
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player") as CharacterBody2D
	ok = assert_true(player != null, "main scene has Player") and ok
	if player == null:
		instance.queue_free()
		return false
	var collision := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	ok = assert_true(collision != null, "player has CollisionShape2D") and ok
	if collision != null:
		var rect := collision.shape as RectangleShape2D
		ok = assert_true(rect != null, "player collision shape is RectangleShape2D cursor block") and ok
		if rect != null:
			ok = assert_eq(rect.size, Vector2(28, 20), "cursor block size") and ok
	ok = assert_true(player.get("theme") != null, "player uses theme resource") and ok
	instance.queue_free()
	return ok


func test_player_moves_all_axes() -> bool:
	var ok := true
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player") as CharacterBody2D
	ok = assert_true(player != null, "main scene has Player") and ok
	if player == null:
		instance.queue_free()
		return false
	_release_move_actions()
	var axis_x := 0.0
	var axis_y := 0.0
	for action: String in MOVE_ACTIONS:
		var before: Vector2 = player.global_position
		Input.action_press(action)
		for i in 60:
			await physics_frame
		Input.action_release(action)
		var delta: Vector2 = player.global_position - before
		axis_x += absf(delta.x)
		axis_y += absf(delta.y)
		ok = assert_true(delta.length() > 50.0, "action %s moves player (%.1f px)" % [action, delta.length()]) and ok
	ok = assert_true(axis_x > 50.0 and axis_y > 50.0, "cardinal input moves both axes") and ok
	var diag_before: Vector2 = player.global_position
	Input.action_press("move_up")
	Input.action_press("move_right")
	for i in 60:
		await physics_frame
	Input.action_release("move_up")
	Input.action_release("move_right")
	var diag: Vector2 = player.global_position - diag_before
	ok = assert_true(absf(diag.x) > 0.0 and absf(diag.y) > 0.0, "diagonal input moves both axes") and ok
	_release_move_actions()
	instance.queue_free()
	return ok


func test_camera_follows_player() -> bool:
	var ok := true
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player") as CharacterBody2D
	var camera := instance.find_child("Camera2D", true, false) as Camera2D
	ok = assert_true(player != null, "main scene has Player") and ok
	ok = assert_true(camera != null, "main scene has Camera2D") and ok
	if player == null or camera == null:
		instance.queue_free()
		return false
	camera.make_current()
	player.global_position += Vector2(2000, 0)
	await process_frame
	await process_frame
	var dist := camera.get_screen_center_position().distance_to(player.global_position)
	ok = assert_true(dist < 5.0, "camera follows player after 2000px move (dist=%.3f)" % dist) and ok
	instance.queue_free()
	return ok


func test_ground_renders() -> bool:
	var ok := true
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var ground := instance.get_node_or_null("Ground")
	ok = assert_true(ground != null, "main scene has Ground") and ok
	if ground == null:
		instance.queue_free()
		return false
	ok = assert_true(ground.get_script() != null, "ground has script") and ok
	ok = assert_true(ground.has_method("get_cell_size"), "ground exposes get_cell_size") and ok
	if ground.has_method("get_cell_size"):
		ok = assert_eq(float(ground.call("get_cell_size")), 64.0, "ground cell size") and ok
	ok = assert_true((ground as Node2D).z_index < 0, "ground renders behind player") and ok
	instance.queue_free()
	return ok


func test_sanity_math() -> bool:
	var ok := true
	ok = assert_eq(2 + 2, 4, "sanity math") and ok
	ok = assert_true(true, "sanity true") and ok
	return ok


func test_nominal_seconds_math() -> bool:
	var ok := true
	ok = assert_eq(AutopilotScript.nominal_seconds(3600, 60.0), 60.0, "nominal 3600 frames at 60 fps is 60 seconds") and ok
	ok = assert_eq(AutopilotScript.nominal_seconds(0, 60.0), 0.0, "nominal 0 frames is 0 seconds") and ok
	ok = assert_eq(AutopilotScript.nominal_seconds(30, 60.0), 0.5, "nominal 30 frames at 60 fps is 0.5 seconds") and ok
	ok = assert_eq(AutopilotScript.nominal_seconds(3600, 60.0), AutopilotScript.nominal_seconds(3600, 60.0), "nominal helper is deterministic frame-count math") and ok
	return ok


func test_measured_clock_accumulates() -> bool:
	var ok := true
	await process_frame
	var clock := AutopilotScript.SimClock.new()
	root.add_child(clock)
	var frames := 10
	for i in frames:
		await physics_frame
	var measured: float = clock.measured
	clock.queue_free()
	var expected := float(frames) / 60.0
	ok = assert_true(measured > 0.0, "probe measured delta sum is positive") and ok
	ok = assert_true(measured > expected * 0.5, "probe measured above generous lower bound") and ok
	ok = assert_true(measured < expected * 2.0 + 0.05, "probe measured below generous upper bound") and ok
	return ok
