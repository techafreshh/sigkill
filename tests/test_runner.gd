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
		"test_player_has_accel_tuning",
		"test_player_velocity_ramps",
		"test_player_friction_decays",
		"test_camera_follows_player",
		"test_ground_renders",
		"test_spawner_default_cap_is_300",
		"test_player_in_player_group",
		"test_chaser_in_enemies_group",
		"test_spawner_ring_spawns_offscreen",
		"test_spawner_enforces_cap",
		"test_spawner_preserves_overshoot",
		"test_spawner_zero_interval_no_hang",
		"test_spawner_quiet_by_default",
		"test_spawner_verbose_reemits_diagnostics",
		"test_chaser_steers_toward_player",
		"test_chaser_has_accel_tuning",
		"test_chaser_velocity_ramps",
		"test_chaser_turns_gradually",
		"test_chaser_player_collide",
		"test_chaser_does_not_pass_through_player",
		"test_main_exposes_run_api",
		"test_main_clock_accumulates",
		"test_main_kill_counter_and_reset",
		"test_main_hud_updates",
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


func test_player_has_accel_tuning() -> bool:
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
	ok = assert_eq(float(player.get("speed")), 220.0, "player default speed is 220") and ok
	ok = assert_true(float(player.get("acceleration")) > 0.0, "player acceleration positive") and ok
	ok = assert_true(float(player.get("friction")) > 0.0, "player friction positive") and ok
	instance.queue_free()
	return ok


func test_player_velocity_ramps() -> bool:
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
	var speed: float = float(player.get("speed"))
	Input.action_press("move_right")
	for i in 3:
		await physics_frame
	var early: Vector2 = player.velocity
	ok = assert_true(early.x > 0.0 and early.x < speed, "velocity ramps, not snapped (x=%.1f)" % early.x) and ok
	for i in 30:
		await physics_frame
	var full: Vector2 = player.velocity
	ok = assert_true(absf(full.x - speed) < speed * 0.05, "velocity reaches full speed (x=%.1f)" % full.x) and ok
	_release_move_actions()
	instance.queue_free()
	return ok


func test_player_friction_decays() -> bool:
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
	Input.action_press("move_right")
	for i in 60:
		await physics_frame
	Input.action_release("move_right")
	var peak: float = player.velocity.length()
	for i in 5:
		await physics_frame
	var sliding: float = player.velocity.length()
	ok = assert_true(sliding < peak and sliding > 0.0, "friction decays gradually (%.1f -> %.1f)" % [peak, sliding]) and ok
	for i in 60:
		await physics_frame
	var rest: float = player.velocity.length()
	ok = assert_true(rest < 5.0, "velocity settles near zero (%.2f)" % rest) and ok
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


func test_player_in_player_group() -> bool:
	var ok := true
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player")
	ok = assert_true(player != null, "main scene has Player") and ok
	if player == null:
		instance.queue_free()
		return false
	ok = assert_true(player.is_in_group("player"), "player joins player group") and ok
	ok = assert_true(get_first_node_in_group("player") == player, "group lookup resolves to Player") and ok
	var spawner := instance.get_node_or_null("Spawner")
	ok = assert_true(spawner != null, "main scene has Spawner") and ok
	if spawner != null:
		ok = assert_true(spawner.get("player") == player, "spawner resolves to Player") and ok
	instance.queue_free()
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


func test_spawner_preserves_overshoot() -> bool:
	var ok := true
	await _clear_enemies()
	var spawner: Node = load("res://spawner.gd").new()
	root.add_child(spawner)
	spawner.set_physics_process(false)
	spawner.set("spawn_interval", 0.5)
	spawner.set("batch_size", 1)
	spawner.set("max_entities", 1000)
	await process_frame
	spawner.call("_physics_process", 0.6)
	var after_first := get_nodes_in_group("enemies").size()
	ok = assert_eq(after_first, 1, "overshoot frame spawns one batch") and ok
	var resid := float(spawner.get("_accum"))
	ok = assert_true(resid > 0.0 and resid < 0.5, "overshoot residue carried (accum=%.4f)" % resid) and ok
	ok = assert_true(absf(resid - 0.1) < 0.01, "residue is ~0.1 (accum=%.4f)" % resid) and ok
	await _clear_enemies()
	spawner.set("_accum", 0.0)
	spawner.call("_physics_process", 1.1)
	var after_long := get_nodes_in_group("enemies").size()
	ok = assert_eq(after_long, 2, "long frame fires two batches") and ok
	spawner.queue_free()
	await _clear_enemies()
	return ok


func test_spawner_zero_interval_no_hang() -> bool:
	var ok := true
	await _clear_enemies()
	var spawner: Node = load("res://spawner.gd").new()
	root.add_child(spawner)
	spawner.set_physics_process(false)
	spawner.set("spawn_interval", 0.0)
	spawner.set("batch_size", 1)
	spawner.set("max_entities", 1000)
	await process_frame
	spawner.call("_physics_process", 1.0)
	var alive := get_nodes_in_group("enemies").size()
	ok = assert_eq(alive, 0, "zero interval spawns nothing") and ok
	spawner.queue_free()
	await _clear_enemies()
	return ok


func test_spawner_quiet_by_default() -> bool:
	var ok := true
	await _clear_enemies()
	var spawner: Node = load("res://spawner.gd").new()
	ok = assert_true(spawner != null, "spawner script instantiates") and ok
	if spawner == null:
		return false
	ok = assert_eq(spawner.get("verbose"), false, "spawner verbose defaults to false") and ok
	root.add_child(spawner)
	spawner.set_physics_process(false)
	spawner.set("spawn_interval", 0.5)
	spawner.set("batch_size", 1)
	spawner.set("max_entities", 1000)
	await process_frame
	spawner.call("_physics_process", 0.6)
	var spawned := get_nodes_in_group("enemies").size()
	ok = assert_eq(spawned, 1, "quiet spawner still spawns") and ok
	ok = assert_true(int(spawner.get("peak_alive")) >= 1, "quiet spawner still tracks peak_alive") and ok
	spawner.set("_tick", 59)
	spawner.call("_physics_process", 0.0)
	ok = assert_true(int(spawner.get("peak_alive")) >= get_nodes_in_group("enemies").size(), "quiet status tick still tracks peak_alive") and ok
	var source := FileAccess.get_file_as_string("res://spawner.gd")
	ok = assert_true(source.contains("SPAWNER_STATUS"), "spawner retains SPAWNER_STATUS string") and ok
	ok = assert_true(source.contains("SPAWNER_SPAWN"), "spawner retains SPAWNER_SPAWN string") and ok
	spawner.queue_free()
	await _clear_enemies()
	return ok


func test_spawner_verbose_reemits_diagnostics() -> bool:
	var ok := true
	await _clear_enemies()
	var quiet: Node = load("res://spawner.gd").new()
	root.add_child(quiet)
	quiet.set_physics_process(false)
	quiet.set("spawn_interval", 0.5)
	quiet.set("batch_size", 1)
	quiet.set("max_entities", 1000)
	await process_frame
	quiet.call("_physics_process", 1.1)
	var quiet_spawned := get_nodes_in_group("enemies").size()
	var quiet_peak := int(quiet.get("peak_alive"))
	quiet.queue_free()
	await _clear_enemies()
	var loud: Node = load("res://spawner.gd").new()
	ok = assert_true(loud != null, "spawner script instantiates") and ok
	if loud == null:
		return false
	loud.set("verbose", true)
	ok = assert_eq(loud.get("verbose"), true, "spawner verbose opt-in sticks") and ok
	root.add_child(loud)
	loud.set_physics_process(false)
	loud.set("spawn_interval", 0.5)
	loud.set("batch_size", 1)
	loud.set("max_entities", 1000)
	await process_frame
	loud.call("_physics_process", 1.1)
	var loud_spawned := get_nodes_in_group("enemies").size()
	var loud_peak := int(loud.get("peak_alive"))
	ok = assert_eq(loud_spawned, quiet_spawned, "verbose flag does not change spawn count") and ok
	ok = assert_eq(loud_peak, quiet_peak, "verbose flag does not change peak_alive") and ok
	ok = assert_true(loud_peak >= 1, "verbose spawner tracks peak_alive") and ok
	loud.set("_tick", 59)
	loud.call("_physics_process", 0.0)
	ok = assert_true(int(loud.get("peak_alive")) >= get_nodes_in_group("enemies").size(), "verbose status tick tracks peak_alive") and ok
	loud.queue_free()
	await _clear_enemies()
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


func test_chaser_player_collide() -> bool:
	var ok := true
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		return false
	var chaser := packed.instantiate() as CharacterBody2D
	ok = assert_true(chaser != null, "chaser instantiates as CharacterBody2D") and ok
	if chaser == null:
		return false
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		chaser.queue_free()
		return false
	await process_frame
	var player := instance.get_node_or_null("Player") as CharacterBody2D
	ok = assert_true(player != null, "main scene has Player") and ok
	if player == null:
		chaser.queue_free()
		instance.queue_free()
		return false
	ok = assert_eq(chaser.collision_layer, 1, "chaser collision_layer is 1") and ok
	ok = assert_eq(chaser.collision_mask, 1, "chaser collision_mask is 1") and ok
	ok = assert_true((chaser.collision_mask & player.collision_layer) != 0, "chaser scans player layer") and ok
	ok = assert_true((player.collision_mask & chaser.collision_layer) != 0, "player scans chaser layer") and ok
	chaser.queue_free()
	instance.queue_free()
	return ok


func test_chaser_does_not_pass_through_player() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player") as CharacterBody2D
	var spawner := instance.get_node_or_null("Spawner")
	ok = assert_true(player != null, "main scene has Player") and ok
	ok = assert_true(spawner != null, "main scene has Spawner") and ok
	if player == null or spawner == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		instance.queue_free()
		return false
	var chaser := packed.instantiate() as CharacterBody2D
	root.add_child(chaser)
	chaser.global_position = player.global_position + Vector2(100, 0)
	chaser.set("target", player)
	await process_frame
	for i in 90:
		await physics_frame
	var final_dist: float = chaser.global_position.distance_to(player.global_position)
	ok = assert_true(final_dist < 100.0, "chaser approached player (dist=%.1f)" % final_dist) and ok
	ok = assert_true(final_dist > 15.0, "chaser blocked at contact boundary (dist=%.1f)" % final_dist) and ok
	chaser.queue_free()
	instance.queue_free()
	return ok


func test_chaser_has_accel_tuning() -> bool:
	var ok := true
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		return false
	var chaser := packed.instantiate() as CharacterBody2D
	root.add_child(chaser)
	await process_frame
	ok = assert_eq(float(chaser.get("speed")), 140.0, "chaser default speed is 140") and ok
	ok = assert_true(float(chaser.get("acceleration")) > 0.0, "chaser acceleration positive") and ok
	chaser.queue_free()
	return ok


func test_chaser_velocity_ramps() -> bool:
	var ok := true
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		return false
	var chaser := packed.instantiate() as CharacterBody2D
	var dummy := Node2D.new()
	root.add_child(dummy)
	root.add_child(chaser)
	chaser.global_position = Vector2.ZERO
	dummy.global_position = Vector2(500, 0)
	chaser.set("target", dummy)
	chaser.set("velocity", Vector2.ZERO)
	await process_frame
	chaser.set("velocity", Vector2.ZERO)
	var speed: float = float(chaser.get("speed"))
	for i in 3:
		await physics_frame
	var early: float = (chaser as CharacterBody2D).velocity.length()
	ok = assert_true(early > 0.0 and early < speed, "chaser velocity ramps, not snapped (%.1f)" % early) and ok
	for i in 60:
		await physics_frame
	var full: float = (chaser as CharacterBody2D).velocity.length()
	ok = assert_true(absf(full - speed) < speed * 0.05, "chaser velocity converges to speed (%.1f)" % full) and ok
	chaser.queue_free()
	dummy.queue_free()
	return ok


func test_chaser_turns_gradually() -> bool:
	var ok := true
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		return false
	var chaser := packed.instantiate() as CharacterBody2D
	var dummy := Node2D.new()
	root.add_child(dummy)
	root.add_child(chaser)
	chaser.global_position = Vector2.ZERO
	dummy.global_position = Vector2(-500, 0)
	chaser.set("target", dummy)
	chaser.set("velocity", Vector2(140, 0))
	await process_frame
	chaser.set("velocity", Vector2(140, 0))
	for i in 2:
		await physics_frame
	var vx: float = (chaser as CharacterBody2D).velocity.x
	ok = assert_true(vx > 0.0, "chaser reversal takes multiple ticks (vx=%.1f)" % vx) and ok
	var before: float = (chaser as CharacterBody2D).velocity.length()
	chaser.set("target", null)
	for i in 5:
		await physics_frame
	var decaying: float = (chaser as CharacterBody2D).velocity.length()
	ok = assert_true(decaying < before and decaying > 0.0, "invalid target decays gradually (%.1f -> %.1f)" % [before, decaying]) and ok
	for i in 60:
		await physics_frame
	var rest: float = (chaser as CharacterBody2D).velocity.length()
	ok = assert_true(rest < 5.0, "chaser settles near zero without target (%.2f)" % rest) and ok
	chaser.queue_free()
	dummy.queue_free()
	return ok


func test_main_exposes_run_api() -> bool:
	var ok := true
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	for method_name: String in ["register_kill", "get_elapsed", "get_kills", "is_run_active", "reset_run"]:
		ok = assert_true(instance.has_method(method_name), "main exposes " + method_name) and ok
	ok = assert_true(instance.get_node_or_null("Player") != null, "main wires Player") and ok
	ok = assert_true(instance.get_node_or_null("Spawner") != null, "main wires Spawner") and ok
	ok = assert_true(instance.get_node_or_null("Ground") != null, "main wires Ground") and ok
	ok = assert_true(instance.get_node_or_null("StatusLabel") != null, "main wires StatusLabel") and ok
	ok = assert_true(bool(instance.call("is_run_active")), "run starts active") and ok
	instance.queue_free()
	return ok


func test_main_clock_accumulates() -> bool:
	var ok := true
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var before: float = float(instance.call("get_elapsed"))
	var frames := 60
	for i in frames:
		await physics_frame
	var after: float = float(instance.call("get_elapsed"))
	var grown := after - before
	var expected := float(frames) / 60.0
	ok = assert_true(grown > 0.0, "run clock advances") and ok
	ok = assert_true(grown > expected * 0.5, "run clock above generous lower bound") and ok
	ok = assert_true(grown < expected * 2.0 + 0.05, "run clock below generous upper bound") and ok
	instance.queue_free()
	return ok


func test_main_kill_counter_and_reset() -> bool:
	var ok := true
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	instance.call("register_kill")
	instance.call("register_kill")
	ok = assert_eq(int(instance.call("get_kills")), 2, "kill counter increments") and ok
	instance.call("reset_run")
	ok = assert_eq(int(instance.call("get_kills")), 0, "reset zeroes kills") and ok
	ok = assert_eq(float(instance.call("get_elapsed")), 0.0, "reset zeroes clock") and ok
	ok = assert_true(bool(instance.call("is_run_active")), "reset reactivates run") and ok
	instance.queue_free()
	return ok


func test_main_hud_updates() -> bool:
	var ok := true
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	for i in 30:
		await physics_frame
	var label := instance.get_node_or_null("StatusLabel") as Label
	ok = assert_true(label != null, "main scene has StatusLabel") and ok
	if label == null:
		instance.queue_free()
		return false
	ok = assert_true(label.text != "SIGKILL skeleton", "HUD leaves skeleton text") and ok
	ok = assert_true(label.text.contains("KILLS="), "HUD reflects kill state") and ok
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
