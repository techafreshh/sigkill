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
		"test_spawner_default_cap_is_300",
		"test_chaser_in_enemies_group",
		"test_spawner_ring_spawns_offscreen",
		"test_spawner_enforces_cap",
		"test_chaser_steers_toward_player",
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


func _clear_enemies() -> void:
	for node: Node in get_nodes_in_group("enemies"):
		node.queue_free()
	await process_frame
	await process_frame


func _viewport_radius() -> float:
	var viewport_size := root.get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1280, 720)
	return 0.5 * viewport_size.length()


func _mean_enemy_distance_to(player: Node2D, enemies: Array) -> float:
	var total := 0.0
	var count := 0
	for enemy: Node in enemies:
		if is_instance_valid(enemy) and enemy is Node2D and is_instance_valid(player):
			total += (enemy as Node2D).global_position.distance_to((player as Node2D).global_position)
			count += 1
	if count == 0:
		return -1.0
	return total / float(count)


func test_spawner_default_cap_is_300() -> bool:
	var ok := true
	var spawner: Node = load("res://spawner.gd").new()
	ok = assert_true(spawner != null, "spawner script instantiates") and ok
	if spawner == null:
		return false
	ok = assert_eq(int(spawner.get("max_entities")), 300, "spawner default cap is 300") and ok
	spawner.free()
	return ok


func test_chaser_in_enemies_group() -> bool:
	var ok := true
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		return false
	var chaser := packed.instantiate()
	root.add_child(chaser)
	ok = assert_true(chaser.is_in_group("enemies"), "chaser joins enemies group") and ok
	chaser.queue_free()
	return ok


func test_spawner_ring_spawns_offscreen() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player") as Node2D
	ok = assert_true(player != null, "main scene has Player") and ok
	if player == null:
		instance.queue_free()
		return false
	for i in 40:
		await physics_frame
	var enemies := get_nodes_in_group("enemies")
	ok = assert_true(enemies.size() > 0, "spawner produced enemies") and ok
	if enemies.is_empty():
		instance.queue_free()
		return false
	var radius := _viewport_radius()
	var farthest := 0.0
	for enemy: Node in enemies:
		var dist: float = (enemy as Node2D).global_position.distance_to(player.global_position)
		if dist > farthest:
			farthest = dist
	ok = assert_true(farthest > radius, "newest spawn outside viewport (dist=%.1f radius=%.1f)" % [farthest, radius]) and ok
	instance.queue_free()
	return ok


func test_spawner_enforces_cap() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var spawner := instance.get_node_or_null("Spawner")
	ok = assert_true(spawner != null, "main scene has Spawner") and ok
	if spawner == null:
		instance.queue_free()
		return false
	spawner.set("max_entities", 5)
	spawner.set("spawn_interval", 0.05)
	for i in 120:
		await physics_frame
	var alive := get_nodes_in_group("enemies").size()
	ok = assert_true(alive <= 5, "spawner respects overridden cap (alive=%d)" % alive) and ok
	instance.queue_free()
	return ok


func test_chaser_steers_toward_player() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player") as Node2D
	var spawner := instance.get_node_or_null("Spawner")
	ok = assert_true(player != null, "main scene has Player") and ok
	ok = assert_true(spawner != null, "main scene has Spawner") and ok
	if player == null or spawner == null:
		instance.queue_free()
		return false
	for i in 90:
		await physics_frame
	var tracked := get_nodes_in_group("enemies").duplicate()
	ok = assert_true(tracked.size() > 0, "spawner produced enemies to track") and ok
	if tracked.is_empty():
		instance.queue_free()
		return false
	var before := _mean_enemy_distance_to(player, tracked)
	spawner.set("spawn_interval", 3600.0)
	for i in 60:
		await physics_frame
	var after := _mean_enemy_distance_to(player, tracked)
	ok = assert_true(after >= 0.0, "tracked enemies still alive") and ok
	ok = assert_true(after < before, "enemies steer toward player (%.1f -> %.1f)" % [before, after]) and ok
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
