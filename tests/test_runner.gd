# Headless test entrypoint. Run with:
#   godot --headless --path . --script res://tests/test_runner.gd
# Exits 0 when every test passes, 1 otherwise, so CI can gate on the exit code.
extends SceneTree

const MOVE_ACTIONS: Array[String] = ["move_up", "move_down", "move_left", "move_right"]
const AutopilotScript := preload("res://autopilot/autopilot.gd")
const SpawnerScript := preload("res://spawner.gd")

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
		"test_teardown_resets_fixture_state",
		"test_spawner_ring_spawns_offscreen",
		"test_spawner_enforces_cap",
		"test_spawner_halts_when_run_inactive",
		"test_player_halts_when_run_inactive",
		"test_main_health_wiring_halts_when_run_inactive",
		"test_main_spawner_wiring_halts_when_run_inactive",
		"test_main_spawner_push_halts_when_run_inactive",
		"test_spawner_preserves_overshoot",
		"test_spawner_peak_tracks_and_resets",
		"test_spawner_peak_single_source_updates_same_frame",
		"test_spawner_single_group_scan_per_tick",
		"test_spawner_zero_interval_no_hang",
		"test_spawner_without_player_spawns_nothing",
		"test_spawner_quiet_by_default",
		"test_spawner_verbose_reemits_diagnostics",
		"test_spawner_died_rewire_is_idempotent",
		"test_chaser_steers_toward_player",
		"test_chaser_has_accel_tuning",
		"test_chaser_velocity_ramps",
		"test_chaser_turns_gradually",
		"test_chaser_without_target_keeps_moving",
		"test_chaser_reacquires_player",
		"test_player_survives_targetless_isolation",
		"test_chaser_player_collide",
		"test_chaser_does_not_pass_through_player",
		"test_player_shoves_through_encirclement",
		"test_player_shove_frozen_when_run_inactive",
		"test_chaser_stops_at_contact_band",
		"test_chaser_halts_when_run_inactive",
		"test_projectile_halts_when_run_inactive",
		"test_chaser_has_take_damage",
		"test_chaser_take_damage_reduces_health",
		"test_chaser_take_damage_kills_at_zero",
		"test_chaser_take_damage_guards",
		"test_main_exposes_run_api",
		"test_main_clock_accumulates",
		"test_main_kill_counter_and_reset",
		"test_main_register_kill_frozen_while_run_inactive",
		"test_main_reset_clears_peak",
		"test_main_peak_and_reset_follow_fresh_spawner_between_ticks",
		"test_main_hud_updates",
		"test_main_hud_preserves_overshoot",
		"test_main_hud_zero_interval_no_hang",
		"test_main_hud_reflects_damage_immediately",
		"test_main_health_push_frozen_when_run_inactive",
		"test_main_hud_rewires_after_health_replace",
		"test_main_hud_rewires_after_spawner_replace",
		"test_main_hud_rewires_after_player_replace",
		"test_main_hud_shows_game_over_immediately",
		"test_main_died_handler_ends_run_without_player_forwarding",
		"test_died_has_single_end_run_path",
		"test_main_hud_has_no_enemies_group_scan",
		"test_main_hud_alive_tracks_spawner_cache",
		"test_main_hud_refresh_is_pure_paint",
		"test_spawner_alive_count_tracks_spawn_and_died",
		"test_sanity_math",
		"test_nominal_seconds_math",
		"test_measured_clock_accumulates",
		"test_bolt_child_of_player_with_timer",
		"test_bolt_range_covers_spawn_ring",
		"test_bolt_fires_at_nearest_in_range",
		"test_projectile_frees_on_first_hit",
		"test_bolt_ticks_quiet_without_enemies",
		"test_no_attack_input_action",
		"test_combat_tuning_data_values",
		"test_player_iframes_ignore_rapid_second_hit",
		"test_player_invuln_frozen_while_run_inactive",
		"test_contact_damage_with_methodless_health_is_safe",
		"test_player_contact_damage_reduces_hp",
		"test_player_stacked_contact_damage_sums",
		"test_player_contact_path_scans_enemies_once",
		"test_end_run_non_death_logs_uniform_tokens",
		"test_end_run_is_idempotent",
		"test_enemy_died_wires_kill_and_xp_log",
		"test_enemy_lethal_damage_frees_within_half_second",
		"test_lethal_contact_ends_run_with_run_end_log",
		"test_end_run_sanitizes_reason_to_single_token",
		"test_end_run_hud_copy_varies_by_reason",
		"test_player_died_rewire_after_health_replace",
		"test_player_health_rewire_on_replace",
		"test_player_rewire_same_node_is_noop",
		"test_player_get_hp_does_not_rewire",
		"test_restart_run_restores_full_run",
		"test_reset_run_uses_fresh_handles_after_swap",
		"test_restore_full_health_rewires_after_swap",
		"test_contact_damage_rewires_after_swap",
		"test_player_health_full_before_tree_entry",
		"test_chaser_health_full_before_tree_entry",
		"test_player_proxy_hp_fallback_detached",
		"test_player_proxy_hp_full_before_tree_entry",
	]
	await _teardown_test_fixtures()
	for t: String in tests:
		var outcome: Variant = await call(t)
		if outcome == true:
			passed += 1
			print("PASS %s" % t)
		else:
			failed += 1
			push_error("FAIL %s: did not finish (runtime error?)" % t)
		await _teardown_test_fixtures()


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


func _stash_player_group() -> Array:
	await process_frame
	await process_frame
	var stashed := get_nodes_in_group("player").duplicate()
	for node: Node in stashed:
		if is_instance_valid(node):
			node.remove_from_group("player")
	return stashed


func _restore_player_group(stashed: Array) -> void:
	for node: Node in stashed:
		if is_instance_valid(node) and not node.is_in_group("player"):
			node.add_to_group("player")


func _teardown_test_fixtures() -> void:
	_release_move_actions()
	for child: Node in root.get_children().duplicate():
		child.queue_free()
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
	var holder := Node.new()
	holder.name = "DetachedHolder"
	root.add_child(holder)
	var detached: Node = load("res://spawner.gd").new()
	detached.set("player_path", NodePath(""))
	holder.add_child(detached)
	detached.set_physics_process(false)
	await process_frame
	detached.set("player", null)
	detached.call("_resolve_player")
	ok = assert_true(detached.get("player") == player, "detached spawner falls back to player group") and ok
	holder.queue_free()
	await process_frame
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


func test_teardown_resets_fixture_state() -> bool:
	var ok := true
	ok = assert_true(get_nodes_in_group("enemies").is_empty(), "runner teardown cleared prior enemies before test") and ok
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var spawned := false
	for i in 90:
		await physics_frame
		if get_nodes_in_group("enemies").size() > 0:
			spawned = true
			break
	ok = assert_true(spawned, "fixture produced enemies before teardown") and ok
	Input.action_press("move_right")
	ok = assert_true(Input.is_action_pressed("move_right"), "move input pressed before teardown") and ok
	await _teardown_test_fixtures()
	ok = assert_true(get_nodes_in_group("enemies").is_empty(), "teardown clears enemies group") and ok
	ok = assert_true(not Input.is_action_pressed("move_right"), "teardown releases move input") and ok
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


func test_spawner_halts_when_run_inactive() -> bool:
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
	spawner.set("spawn_interval", 0.05)
	spawner.set("max_entities", 1000)
	for i in 30:
		await physics_frame
	ok = assert_true(get_nodes_in_group("enemies").size() > 0, "spawner produces enemies while active") and ok
	var alive_baseline := get_nodes_in_group("enemies").size()
	var peak_baseline := int(spawner.get("peak_alive"))
	var tick_baseline := int(spawner.get("_tick"))
	spawner.set("_accum", 0.0)
	instance.set("run_active", false)
	for i in 60:
		await physics_frame
	ok = assert_eq(get_nodes_in_group("enemies").size(), alive_baseline, "inactive run spawns nothing") and ok
	ok = assert_eq(int(spawner.get("peak_alive")), peak_baseline, "peak_alive frozen while inactive") and ok
	ok = assert_eq(float(spawner.get("_accum")), 0.0, "spawn debt frozen while inactive") and ok
	ok = assert_eq(int(spawner.get("_tick")), tick_baseline, "tick frozen while inactive") and ok
	spawner.call("_try_spawn")
	ok = assert_eq(get_nodes_in_group("enemies").size(), alive_baseline, "direct _try_spawn spawns nothing while inactive") and ok
	ok = assert_eq(int(spawner.get("peak_alive")), peak_baseline, "direct _try_spawn leaves peak while inactive") and ok
	instance.set("run_active", true)
	for i in 60:
		await physics_frame
		if get_nodes_in_group("enemies").size() > alive_baseline:
			break
	ok = assert_true(get_nodes_in_group("enemies").size() > alive_baseline, "spawning resumes when run reactivates") and ok
	instance.queue_free()
	await _clear_enemies()
	var lone: Node = load("res://spawner.gd").new()
	root.add_child(lone)
	lone.set_physics_process(false)
	lone.set("spawn_interval", 0.5)
	lone.set("batch_size", 1)
	lone.set("max_entities", 1000)
	var dummy := Node2D.new()
	root.add_child(dummy)
	lone.set("player", dummy)
	await process_frame
	lone.call("_physics_process", 0.6)
	ok = assert_eq(get_nodes_in_group("enemies").size(), 1, "detached spawner defaults to active") and ok
	lone.queue_free()
	dummy.queue_free()
	await _clear_enemies()
	return ok


func test_player_halts_when_run_inactive() -> bool:
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
	if player == null:
		instance.queue_free()
		return false
	if spawner != null:
		spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	var active_before: Vector2 = player.global_position
	Input.action_press("move_right")
	for i in 30:
		await physics_frame
	var active_disp: float = player.global_position.distance_to(active_before)
	ok = assert_true(active_disp > 10.0, "player displaces while run active (%.1f px)" % active_disp) and ok
	instance.call("end_run", "death")
	ok = assert_true(not bool(instance.call("is_run_active")), "run inactive after end_run") and ok
	var hp_before: float = float(player.call("get_hp"))
	player.set("velocity", Vector2(220, 0))
	var frozen_pos: Vector2 = player.global_position
	for i in 60:
		await physics_frame
	ok = assert_eq(player.global_position, frozen_pos, "inactive player holds position") and ok
	ok = assert_eq(player.velocity, Vector2.ZERO, "inactive player zeroes velocity") and ok
	ok = assert_eq(float(player.call("get_hp")), hp_before, "inactive player HP frozen") and ok
	player.call("_physics_process", 1.0 / 60.0)
	ok = assert_eq(player.global_position, frozen_pos, "direct tick moves nothing while inactive") and ok
	ok = assert_eq(player.velocity, Vector2.ZERO, "direct tick keeps zero velocity while inactive") and ok
	instance.call("reset_run")
	ok = assert_true(bool(instance.call("is_run_active")), "reset reactivates run") and ok
	var resume_before: Vector2 = player.global_position
	for i in 30:
		await physics_frame
	var resume_disp: float = player.global_position.distance_to(resume_before)
	ok = assert_true(resume_disp > 10.0, "player displaces again after reset (%.1f px)" % resume_disp) and ok
	_release_move_actions()
	instance.queue_free()
	await _clear_enemies()
	var lone := load("res://player.gd").new() as CharacterBody2D
	ok = assert_true(lone != null, "detached player instantiates") and ok
	if lone == null:
		return false
	ok = assert_true(bool(lone.call("_is_run_active")), "detached player defaults to active") and ok
	root.add_child(lone)
	lone.set_physics_process(false)
	lone.set("velocity", Vector2.ZERO)
	await process_frame
	var lone_start: Vector2 = (lone as Node2D).global_position
	_release_move_actions()
	Input.action_press("move_right")
	for i in 10:
		lone.call("_physics_process", 1.0 / 60.0)
	ok = assert_true(lone.velocity.length() > 0.0, "detached player still steers (speed=%.1f)" % lone.velocity.length()) and ok
	ok = assert_true((lone as Node2D).global_position.distance_to(lone_start) > 1.0, "detached player displaces (%.1f px)" % (lone as Node2D).global_position.distance_to(lone_start)) and ok
	_release_move_actions()
	lone.queue_free()
	await _clear_enemies()
	return ok


func test_main_health_wiring_halts_when_run_inactive() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player")
	var spawner := instance.get_node_or_null("Spawner")
	ok = assert_true(player != null, "main scene has Player") and ok
	if player == null or spawner == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	var stale_wired: Node = instance.get("_wired_health")
	ok = assert_true(stale_wired != null, "coordinator tracks a wired Health while active") and ok
	instance.call("end_run", "death")
	ok = assert_true(not bool(instance.call("is_run_active")), "run inactive after end_run") and ok
	var old_health := player.get_node_or_null("Health")
	ok = assert_true(old_health != null, "original Health present before swap") and ok
	if old_health != null:
		player.remove_child(old_health)
		old_health.queue_free()
	var fresh: Node = load("res://player/health.gd").new()
	fresh.name = "Health"
	player.add_child(fresh)
	var want_changed := Callable(instance, "_on_player_health_changed")
	var want_died := Callable(instance, "_on_player_died")
	for i in 10:
		await physics_frame
	ok = assert_true(not fresh.is_connected("health_changed", want_changed), "inactive ticks wire no health_changed") and ok
	ok = assert_true(not fresh.is_connected("died", want_died), "inactive ticks wire no died") and ok
	ok = assert_true(instance.get("_wired_health") == stale_wired, "inactive ticks leave wired Health handle unchanged") and ok
	instance.call("reset_run")
	ok = assert_true(bool(instance.call("is_run_active")), "reset reactivates run") and ok
	var wired := false
	for i in 10:
		await physics_frame
		if fresh.is_connected("health_changed", want_changed) and fresh.is_connected("died", want_died):
			wired = true
			break
	ok = assert_true(wired, "reactivated ticks rewire fresh Health signals") and ok
	var changed_conns := 0
	for entry: Dictionary in fresh.get_signal_connection_list("health_changed"):
		var changed_cal: Callable = entry["callable"]
		if changed_cal == want_changed:
			changed_conns += 1
	ok = assert_eq(changed_conns, 1, "fresh Health carries exactly one health_changed connection") and ok
	var died_conns := 0
	for entry: Dictionary in fresh.get_signal_connection_list("died"):
		var died_cal: Callable = entry["callable"]
		if died_cal == want_died:
			died_conns += 1
	ok = assert_eq(died_conns, 1, "fresh Health carries exactly one died connection") and ok
	instance.queue_free()
	return ok


func test_main_spawner_wiring_halts_when_run_inactive() -> bool:
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
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	var stale_spawner: Node = spawner
	var stale_wired: Node = instance.get("_wired_spawner")
	ok = assert_true(stale_wired != null, "coordinator tracks a wired Spawner while active") and ok
	var stale_cached := int(instance.get("_cached_alive"))
	instance.call("end_run", "death")
	ok = assert_true(not bool(instance.call("is_run_active")), "run inactive after end_run") and ok
	instance.remove_child(stale_spawner)
	var fresh: Node = load("res://spawner.gd").new()
	fresh.name = "Spawner"
	fresh.set("player_path", NodePath("../Player"))
	fresh.set("spawn_interval", 3600.0)
	fresh.set("alive_count", stale_cached + 7)
	instance.add_child(fresh)
	var want := Callable(instance, "_on_spawner_alive_changed")
	for i in 10:
		await physics_frame
	ok = assert_true(not fresh.is_connected("alive_changed", want), "inactive ticks wire no alive_changed") and ok
	ok = assert_true(instance.get("spawner") == stale_spawner, "inactive ticks leave spawner handle unchanged") and ok
	ok = assert_true(instance.get("_wired_spawner") == stale_wired, "inactive ticks leave wired Spawner handle unchanged") and ok
	ok = assert_eq(int(instance.get("_cached_alive")), stale_cached, "inactive ticks leave spawner push-cache unchanged") and ok
	instance.call("reset_run")
	ok = assert_true(bool(instance.call("is_run_active")), "reset reactivates run") and ok
	var wired := false
	for i in 10:
		await physics_frame
		if fresh.is_connected("alive_changed", want):
			wired = true
			break
	ok = assert_true(wired, "reactivated ticks rewire fresh Spawner signal") and ok
	var conns := 0
	for entry: Dictionary in fresh.get_signal_connection_list("alive_changed"):
		var cal: Callable = entry["callable"]
		if cal == want:
			conns += 1
	ok = assert_eq(conns, 1, "fresh Spawner carries exactly one alive_changed connection") and ok
	ok = assert_eq(int(instance.get("_cached_alive")), int(fresh.call("get_alive")), "cache re-primed from fresh Spawner") and ok
	if stale_spawner != null and is_instance_valid(stale_spawner):
		stale_spawner.queue_free()
	instance.queue_free()
	return ok


func test_main_spawner_push_halts_when_run_inactive() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var spawner := instance.get_node_or_null("Spawner")
	var label := instance.get_node_or_null("StatusLabel") as Label
	ok = assert_true(spawner != null, "main scene has Spawner") and ok
	ok = assert_true(label != null, "main scene has StatusLabel") and ok
	if spawner == null or label == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	spawner.set("_accum", 0.0)
	await process_frame
	ok = assert_true(get_nodes_in_group("enemies").is_empty(), "no background spawns before batch") and ok
	spawner.set("batch_size", 3)
	spawner.set("spawn_interval", 0.5)
	spawner.set("_accum", 0.0)
	spawner.call("_physics_process", 0.6)
	await process_frame
	ok = assert_eq(get_nodes_in_group("enemies").size(), 3, "known batch spawns three") and ok
	ok = assert_eq(int(spawner.call("get_alive")), 3, "spawner cache tracks batch") and ok
	ok = assert_eq(int(instance.get("_cached_alive")), 3, "HUD cache follows spawner push") and ok
	spawner.set("spawn_interval", 3600.0)
	spawner.set("_accum", 0.0)
	instance.call("end_run", "death")
	ok = assert_true(not bool(instance.call("is_run_active")), "run inactive after end_run") and ok
	var stale_cached := int(instance.get("_cached_alive"))
	var stale_kills := int(instance.call("get_kills"))
	var stale_label := label.text
	var victim: Node = null
	for enemy: Node in get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.get_parent() == spawner:
			victim = enemy
			break
	ok = assert_true(victim != null, "batch chaser available for inactive lethal damage") and ok
	if victim == null:
		instance.queue_free()
		return false
	victim.call("take_damage", float(victim.get("max_health")))
	for i in 30:
		await physics_frame
		if not is_instance_valid(victim):
			break
	ok = assert_eq(int(spawner.call("get_alive")), stale_cached - 1, "inactive died still decrements spawner counter") and ok
	ok = assert_eq(get_nodes_in_group("enemies").size(), stale_cached - 1, "inactive died frees chaser") and ok
	spawner.emit_signal("alive_changed", stale_cached + 5)
	for i in 10:
		await physics_frame
	ok = assert_eq(int(instance.get("_cached_alive")), stale_cached, "inactive pushes leave cache frozen") and ok
	ok = assert_eq(int(instance.call("get_kills")), stale_kills, "inactive died leaves kills frozen") and ok
	ok = assert_eq(label.text, stale_label, "inactive pushes leave HUD text frozen") and ok
	instance.call("reset_run")
	ok = assert_true(bool(instance.call("is_run_active")), "reset reactivates run") and ok
	ok = assert_eq(int(instance.get("_cached_alive")), int(spawner.call("get_alive")), "reset re-primes cache from spawner") and ok
	var live: Node = null
	for enemy: Node in get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.get_parent() == spawner:
			live = enemy
			break
	ok = assert_true(live != null, "live chaser available after reset") and ok
	if live == null:
		instance.queue_free()
		return false
	var kills_before := int(instance.call("get_kills"))
	var cache_before := int(instance.get("_cached_alive"))
	live.call("take_damage", float(live.get("max_health")))
	var tracked := false
	for i in 30:
		await physics_frame
		if int(instance.call("get_kills")) == kills_before + 1:
			tracked = true
			break
	ok = assert_true(tracked, "live died push resumes after reset") and ok
	ok = assert_eq(int(spawner.call("get_alive")), cache_before - 1, "live died decrements spawner counter") and ok
	ok = assert_eq(int(instance.get("_cached_alive")), cache_before - 1, "live died updates HUD cache") and ok
	ok = assert_true(label.text.contains("ALIVE=%d" % (cache_before - 1)), "HUD shows live ALIVE after died") and ok
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
	var dummy := Node2D.new()
	root.add_child(dummy)
	spawner.set("player", dummy)
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
	dummy.queue_free()
	await _clear_enemies()
	return ok


func test_spawner_peak_tracks_and_resets() -> bool:
	var ok := true
	await _clear_enemies()
	var spawner: Node = load("res://spawner.gd").new()
	root.add_child(spawner)
	spawner.set_physics_process(false)
	spawner.set("spawn_interval", 0.5)
	spawner.set("batch_size", 1)
	spawner.set("max_entities", 1000)
	var dummy := Node2D.new()
	root.add_child(dummy)
	spawner.set("player", dummy)
	await process_frame
	spawner.call("_physics_process", 0.6)
	var tracked := get_nodes_in_group("enemies").size()
	ok = assert_true(tracked >= 1, "peak tick spawns at least one enemy") and ok
	ok = assert_eq(int(spawner.call("get_peak_alive")), int(spawner.get("peak_alive")), "get_peak_alive mirrors peak_alive") and ok
	ok = assert_true(int(spawner.call("get_peak_alive")) >= tracked, "peak covers live enemies") and ok
	spawner.call("reset_peak")
	ok = assert_eq(int(spawner.get("peak_alive")), 0, "reset_peak zeroes peak_alive") and ok
	ok = assert_eq(int(spawner.call("get_peak_alive")), 0, "get_peak_alive reads zero after reset") and ok
	spawner.call("_physics_process", 0.0)
	ok = assert_true(int(spawner.call("get_peak_alive")) >= tracked, "peak re-tracks live enemies after reset") and ok
	spawner.queue_free()
	dummy.queue_free()
	await _clear_enemies()
	return ok


func test_spawner_peak_single_source_updates_same_frame() -> bool:
	var ok := true
	await _clear_enemies()
	var spawner: Node = load("res://spawner.gd").new()
	root.add_child(spawner)
	spawner.set_physics_process(false)
	spawner.set("spawn_interval", 0.5)
	spawner.set("batch_size", 5)
	spawner.set("max_entities", 1000)
	var dummy := Node2D.new()
	root.add_child(dummy)
	spawner.set("player", dummy)
	await process_frame
	spawner.call("_physics_process", 0.6)
	var alive := get_nodes_in_group("enemies").size()
	ok = assert_eq(alive, 5, "same-frame batch spawns five") and ok
	ok = assert_eq(int(spawner.call("get_peak_alive")), 5, "batch peak tracked same frame without extra tick") and ok
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		spawner.queue_free()
		dummy.queue_free()
		await _clear_enemies()
		return false
	for i in 3:
		var extra := packed.instantiate()
		root.add_child(extra)
	await process_frame
	ok = assert_eq(get_nodes_in_group("enemies").size(), 8, "externally added enemies present") and ok
	spawner.call("_physics_process", 0.0)
	ok = assert_true(int(spawner.call("get_peak_alive")) >= 8, "frame-top polling picks up externally added enemies") and ok
	var source := FileAccess.get_file_as_string("res://spawner.gd")
	ok = assert_true(source.contains("func _update_peak"), "single peak mutation helper exists") and ok
	ok = assert_eq(source.count("> peak_alive"), 1, "exactly one peak comparison site") and ok
	ok = assert_true(source.contains("SPAWNER_STATUS"), "spawner retains SPAWNER_STATUS string") and ok
	ok = assert_true(source.contains("SPAWNER_SPAWN"), "spawner retains SPAWNER_SPAWN string") and ok
	spawner.queue_free()
	dummy.queue_free()
	await _clear_enemies()
	return ok


func test_spawner_single_group_scan_per_tick() -> bool:
	var ok := true
	await _clear_enemies()
	var source := FileAccess.get_file_as_string("res://spawner.gd")
	ok = assert_eq(source.count("get_tree().get_nodes_in_group"), 1, "exactly one group-query site per tick") and ok
	ok = assert_true(source.contains("func _count_alive"), "single group-query helper exists") and ok
	ok = assert_true(source.contains("SPAWNER_STATUS"), "spawner retains SPAWNER_STATUS string") and ok
	ok = assert_true(source.contains("SPAWNER_SPAWN"), "spawner retains SPAWNER_SPAWN string") and ok
	var spawner: Node = load("res://spawner.gd").new()
	root.add_child(spawner)
	spawner.set_physics_process(false)
	spawner.set("spawn_interval", 0.5)
	spawner.set("batch_size", 5)
	spawner.set("max_entities", 1000)
	var dummy := Node2D.new()
	root.add_child(dummy)
	spawner.set("player", dummy)
	await process_frame
	spawner.call("_physics_process", 0.6)
	ok = assert_eq(get_nodes_in_group("enemies").size(), 5, "one tick multi-batch drain spawns full batch") and ok
	ok = assert_eq(int(spawner.call("get_peak_alive")), 5, "batch peak tracked same frame without extra tick") and ok
	await _clear_enemies()
	spawner.call("reset_peak")
	spawner.set("spawn_interval", 0.5)
	spawner.set("batch_size", 3)
	spawner.set("max_entities", 4)
	spawner.set("_accum", 0.0)
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		spawner.queue_free()
		dummy.queue_free()
		await _clear_enemies()
		return false
	var seed_enemy := packed.instantiate()
	root.add_child(seed_enemy)
	await process_frame
	ok = assert_eq(get_nodes_in_group("enemies").size(), 1, "cap fixture stages one live enemy") and ok
	spawner.call("_physics_process", 1.1)
	var capped := get_nodes_in_group("enemies").size()
	ok = assert_true(capped <= 4, "threaded cap holds across batches in one tick (alive=%d)" % capped) and ok
	ok = assert_eq(capped, 4, "debt drain fills exactly to cap without overshoot") and ok
	await _clear_enemies()
	spawner.set("max_entities", 1000)
	spawner.set("batch_size", 1)
	spawner.set("_accum", 0.0)
	spawner.call("_try_spawn")
	ok = assert_eq(get_nodes_in_group("enemies").size(), 1, "zero-arg _try_spawn still spawns") and ok
	spawner.queue_free()
	dummy.queue_free()
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


func test_spawner_without_player_spawns_nothing() -> bool:
	var ok := true
	await _clear_enemies()
	var stashed: Array = await _stash_player_group()
	ok = assert_true(get_nodes_in_group("player").is_empty(), "no player present for playerless spawn") and ok
	if not ok:
		_restore_player_group(stashed)
		return false
	var holder := Node.new()
	holder.name = "PlayerlessHolder"
	root.add_child(holder)
	var spawner: Node = load("res://spawner.gd").new()
	spawner.set("player_path", NodePath(""))
	holder.add_child(spawner)
	spawner.set_physics_process(false)
	spawner.set("spawn_interval", 0.5)
	spawner.set("batch_size", 1)
	spawner.set("max_entities", 1000)
	await process_frame
	spawner.set("player", null)
	spawner.call("_physics_process", 0.6)
	spawner.call("_try_spawn")
	var spawned := get_nodes_in_group("enemies").size()
	ok = assert_eq(spawned, 0, "playerless spawner spawns nothing") and ok
	holder.queue_free()
	await _clear_enemies()
	_restore_player_group(stashed)
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
	var dummy := Node2D.new()
	root.add_child(dummy)
	spawner.set("player", dummy)
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
	dummy.queue_free()
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
	var quiet_dummy := Node2D.new()
	root.add_child(quiet_dummy)
	quiet.set("player", quiet_dummy)
	await process_frame
	quiet.call("_physics_process", 1.1)
	var quiet_spawned := get_nodes_in_group("enemies").size()
	var quiet_peak := int(quiet.get("peak_alive"))
	quiet.queue_free()
	quiet_dummy.queue_free()
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
	var loud_dummy := Node2D.new()
	root.add_child(loud_dummy)
	loud.set("player", loud_dummy)
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
	loud_dummy.queue_free()
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
	for node: Node in get_nodes_in_group("player"):
		node.queue_free()
	await process_frame
	await process_frame
	ok = assert_true(get_nodes_in_group("player").is_empty(), "no player present for gradual-turn coast") and ok
	if not ok:
		return false
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
	var coasting: float = (chaser as CharacterBody2D).velocity.length()
	ok = assert_true(absf(coasting - before) < before * 0.05, "invalid target coasts, speed preserved (%.1f -> %.1f)" % [before, coasting]) and ok
	var coast_start: Vector2 = chaser.global_position
	for i in 60:
		await physics_frame
	var coast_disp: float = chaser.global_position.distance_to(coast_start)
	ok = assert_true(coast_disp > 50.0, "targetless chaser keeps displacing (%.1f px)" % coast_disp) and ok
	chaser.queue_free()
	dummy.queue_free()
	return ok


func test_chaser_without_target_keeps_moving() -> bool:
	var ok := true
	var stashed: Array = await _stash_player_group()
	ok = assert_true(get_nodes_in_group("player").is_empty(), "no player present for targetless drift") and ok
	if not ok:
		_restore_player_group(stashed)
		return false
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		_restore_player_group(stashed)
		return false
	var chaser := packed.instantiate() as CharacterBody2D
	root.add_child(chaser)
	chaser.global_position = Vector2.ZERO
	chaser.set("target", null)
	await process_frame
	chaser.set("velocity", Vector2(140, 0))
	var start_speed: float = (chaser as CharacterBody2D).velocity.length()
	var start_pos: Vector2 = chaser.global_position
	for i in 60:
		await physics_frame
	var end_speed: float = (chaser as CharacterBody2D).velocity.length()
	var disp: float = chaser.global_position.distance_to(start_pos)
	ok = assert_true(absf(end_speed - start_speed) < start_speed * 0.05, "targetless chaser preserves speed (%.1f -> %.1f)" % [start_speed, end_speed]) and ok
	ok = assert_true(disp > 50.0, "targetless chaser displaces (%.1f px)" % disp) and ok
	chaser.queue_free()
	await process_frame
	await process_frame
	_restore_player_group(stashed)
	return ok


func test_chaser_reacquires_player() -> bool:
	var ok := true
	var stashed: Array = await _stash_player_group()
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		_restore_player_group(stashed)
		return false
	var dummy := Node2D.new()
	root.add_child(dummy)
	dummy.add_to_group("player")
	dummy.global_position = Vector2(500, 0)
	var chaser := packed.instantiate() as CharacterBody2D
	root.add_child(chaser)
	chaser.global_position = Vector2.ZERO
	chaser.set("target", null)
	chaser.set("velocity", Vector2.ZERO)
	chaser.call("_resolve_target")
	ok = assert_true(chaser.get("target") == dummy, "chaser re-acquires group player") and ok
	var before: float = chaser.global_position.distance_to(dummy.global_position)
	for i in 60:
		await physics_frame
	var after: float = chaser.global_position.distance_to(dummy.global_position)
	ok = assert_true(after < before, "re-acquired chaser closes distance (%.1f -> %.1f)" % [before, after]) and ok
	chaser.queue_free()
	dummy.queue_free()
	await process_frame
	await process_frame
	_restore_player_group(stashed)
	return ok


func test_player_survives_targetless_isolation() -> bool:
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
	var stashed: Array = await _stash_player_group()
	ok = assert_true(get_nodes_in_group("player").is_empty(), "no player present for targetless drift") and ok
	if not ok:
		_restore_player_group(stashed)
		instance.queue_free()
		return false
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		_restore_player_group(stashed)
		instance.queue_free()
		return false
	var chaser := packed.instantiate() as CharacterBody2D
	root.add_child(chaser)
	chaser.global_position = Vector2.ZERO
	chaser.set("target", null)
	await process_frame
	chaser.set("velocity", Vector2(140, 0))
	var start_pos: Vector2 = chaser.global_position
	for i in 60:
		await physics_frame
	var disp: float = chaser.global_position.distance_to(start_pos)
	ok = assert_true(disp > 50.0, "targetless chaser displaces (%.1f px)" % disp) and ok
	chaser.queue_free()
	await process_frame
	await process_frame
	_restore_player_group(stashed)
	ok = assert_true(is_instance_valid(player), "player survives targetless isolation") and ok
	ok = assert_true(player.is_in_group("player"), "player rejoins player group after restore") and ok
	ok = assert_true(get_first_node_in_group("player") == player, "group lookup resolves to Player after restore") and ok
	instance.queue_free()
	return ok


func test_player_shoves_through_encirclement() -> bool:
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
	_release_move_actions()
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		instance.queue_free()
		return false
	var center: Vector2 = player.global_position
	var ring := 10
	for i in ring:
		var chaser := packed.instantiate() as CharacterBody2D
		root.add_child(chaser)
		var angle := TAU * float(i) / float(ring)
		chaser.global_position = center + Vector2(cos(angle), sin(angle)) * 40.0
		chaser.set("target", player)
	for i in 90:
		await physics_frame
	var before: Vector2 = player.global_position
	Input.action_press("move_right")
	for i in 60:
		await physics_frame
	Input.action_release("move_right")
	var pushed: float = player.global_position.distance_to(before)
	ok = assert_true(pushed > 50.0, "player shoves through encirclement (%.1f px)" % pushed) and ok
	_release_move_actions()
	instance.queue_free()
	return ok


func test_player_shove_frozen_when_run_inactive() -> bool:
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
	await _clear_enemies()
	_release_move_actions()
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		instance.queue_free()
		return false
	var chaser := packed.instantiate() as CharacterBody2D
	spawner.add_child(chaser)
	chaser.global_position = player.global_position + Vector2(40, 0)
	chaser.set("target", player)
	chaser.set("max_health", 1000.0)
	chaser.set("health", 1000.0)
	await process_frame
	chaser.global_position = player.global_position + Vector2(40, 0)
	chaser.set("velocity", Vector2.ZERO)
	var enemies: Array = [chaser]
	player.call("_shove_crowd", 200.0, 1.0 / 60.0, enemies)
	ok = assert_true((chaser.velocity as Vector2).length() > 0.0, "active direct shove mutates chaser velocity") and ok
	instance.call("end_run", "death")
	ok = assert_true(not bool(instance.call("is_run_active")), "run inactive after end_run") and ok
	chaser.set("velocity", Vector2.ZERO)
	var frozen_vel: Vector2 = chaser.velocity
	var frozen_pos: Vector2 = chaser.global_position
	player.call("_shove_crowd", 200.0, 1.0 / 60.0, enemies)
	ok = assert_eq(chaser.velocity, frozen_vel, "inactive direct shove leaves velocity unchanged") and ok
	for i in 60:
		await physics_frame
	ok = assert_eq(chaser.velocity, frozen_vel, "inactive idle keeps chaser velocity frozen") and ok
	ok = assert_eq(chaser.global_position, frozen_pos, "inactive chaser holds position") and ok
	instance.call("reset_run")
	ok = assert_true(bool(instance.call("is_run_active")), "reset reactivates run") and ok
	chaser.set("velocity", Vector2.ZERO)
	player.call("_shove_crowd", 200.0, 1.0 / 60.0, [chaser])
	ok = assert_true((chaser.velocity as Vector2).length() > 0.0, "shove resumes after reset") and ok
	_release_move_actions()
	instance.queue_free()
	return ok


func test_chaser_stops_at_contact_band() -> bool:
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
	_release_move_actions()
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
	for i in 120:
		await physics_frame
	var final_dist: float = chaser.global_position.distance_to(player.global_position)
	ok = assert_true(final_dist >= 15.0 and final_dist <= 60.0, "chaser holds standoff (dist=%.1f)" % final_dist) and ok
	chaser.queue_free()
	instance.queue_free()
	return ok


func test_chaser_halts_when_run_inactive() -> bool:
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
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		instance.queue_free()
		return false
	var chaser := packed.instantiate() as CharacterBody2D
	spawner.add_child(chaser)
	chaser.global_position = player.global_position + Vector2(600, 0)
	chaser.set("target", player)
	chaser.set("max_health", 1000.0)
	chaser.set("health", 1000.0)
	await process_frame
	var before: float = chaser.global_position.distance_to(player.global_position)
	for i in 60:
		await physics_frame
	var approaching: float = chaser.global_position.distance_to(player.global_position)
	ok = assert_true(approaching < before, "chaser closes on player while active (%.1f -> %.1f)" % [before, approaching]) and ok
	instance.call("end_run", "death")
	ok = assert_true(not bool(instance.call("is_run_active")), "run inactive after end_run") and ok
	var frozen_pos: Vector2 = chaser.global_position
	var frozen_vel: Vector2 = chaser.velocity
	for i in 60:
		await physics_frame
	ok = assert_eq(chaser.global_position, frozen_pos, "inactive chaser holds position") and ok
	ok = assert_eq(chaser.velocity, frozen_vel, "inactive chaser holds velocity") and ok
	chaser.call("_physics_process", 1.0 / 60.0)
	ok = assert_eq(chaser.global_position, frozen_pos, "direct tick moves nothing while inactive") and ok
	ok = assert_eq(chaser.velocity, frozen_vel, "direct tick changes no velocity while inactive") and ok
	instance.call("reset_run")
	ok = assert_true(bool(instance.call("is_run_active")), "reset reactivates run") and ok
	var resume_before: float = chaser.global_position.distance_to(player.global_position)
	for i in 60:
		await physics_frame
	var resume_after: float = chaser.global_position.distance_to(player.global_position)
	ok = assert_true(resume_after < resume_before, "chaser resumes closing after reset (%.1f -> %.1f)" % [resume_before, resume_after]) and ok
	instance.queue_free()
	await _clear_enemies()
	var dummy := Node2D.new()
	root.add_child(dummy)
	dummy.global_position = Vector2(500, 0)
	var lone := packed.instantiate() as CharacterBody2D
	root.add_child(lone)
	lone.global_position = Vector2.ZERO
	lone.set("target", dummy)
	lone.set("velocity", Vector2.ZERO)
	lone.set_physics_process(false)
	await process_frame
	lone.set("velocity", Vector2.ZERO)
	var lone_start: Vector2 = lone.global_position
	for i in 10:
		lone.call("_physics_process", 1.0 / 60.0)
	ok = assert_true(lone.velocity.length() > 0.0, "detached chaser defaults to active (speed=%.1f)" % lone.velocity.length()) and ok
	ok = assert_true(lone.global_position.distance_to(lone_start) > 1.0, "detached chaser displaces (%.1f px)" % lone.global_position.distance_to(lone_start)) and ok
	lone.queue_free()
	dummy.queue_free()
	await _clear_enemies()
	return ok


func test_projectile_halts_when_run_inactive() -> bool:
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
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	var projectile = load("res://weapons/projectile.gd").new()
	instance.add_child(projectile)
	await process_frame
	var from: Vector2 = player.global_position + Vector2(-400, 0)
	projectile.call("launch", from, from + Vector2(100, 0), 700.0, 1, 950.0)
	var start_pos: Vector2 = projectile.global_position
	for i in 30:
		await physics_frame
	ok = assert_true(is_instance_valid(projectile), "projectile alive while active") and ok
	if not is_instance_valid(projectile):
		instance.queue_free()
		return false
	ok = assert_true(projectile.global_position.distance_to(start_pos) > 1.0, "projectile displaces while active (%.1f px)" % projectile.global_position.distance_to(start_pos)) and ok
	instance.call("end_run", "death")
	ok = assert_true(not bool(instance.call("is_run_active")), "run inactive after end_run") and ok
	var frozen_pos: Vector2 = projectile.global_position
	var frozen_travelled: float = float(projectile.get("_travelled"))
	var frozen_life: float = float(projectile.get("_life"))
	for i in 60:
		await physics_frame
	ok = assert_true(is_instance_valid(projectile), "projectile not freed while inactive") and ok
	ok = assert_eq(projectile.global_position, frozen_pos, "inactive projectile holds position") and ok
	ok = assert_eq(float(projectile.get("_travelled")), frozen_travelled, "inactive projectile holds travelled") and ok
	ok = assert_eq(float(projectile.get("_life")), frozen_life, "inactive projectile holds life") and ok
	projectile.call("_physics_process", 1.0 / 60.0)
	ok = assert_eq(projectile.global_position, frozen_pos, "direct tick moves nothing while inactive") and ok
	ok = assert_eq(float(projectile.get("_travelled")), frozen_travelled, "direct tick advances no travelled while inactive") and ok
	ok = assert_eq(float(projectile.get("_life")), frozen_life, "direct tick advances no life while inactive") and ok
	var doomed = load("res://weapons/projectile.gd").new()
	instance.add_child(doomed)
	await process_frame
	doomed.call("launch", from, from + Vector2(100, 0), 700.0, 1, 950.0)
	doomed.set("_travelled", float(doomed.get("max_range")) - 0.01)
	doomed.set("_life", float(doomed.get("_max_life")) - 0.01)
	doomed.call("_physics_process", 1.0)
	for i in 60:
		await physics_frame
	ok = assert_true(is_instance_valid(doomed), "near-limit projectile is not freed by expiry while inactive") and ok
	if is_instance_valid(doomed):
		ok = assert_eq(float(doomed.get("_travelled")), float(doomed.get("max_range")) - 0.01, "inactive projectile holds near-limit travelled") and ok
	instance.call("reset_run")
	ok = assert_true(bool(instance.call("is_run_active")), "reset reactivates run") and ok
	var resume_before: Vector2 = projectile.global_position
	var freed := false
	for i in 30:
		await physics_frame
		if not is_instance_valid(projectile):
			freed = true
			break
	if is_instance_valid(projectile):
		ok = assert_true(projectile.global_position.distance_to(resume_before) > 1.0, "projectile resumes displacing after reset (%.1f px)" % projectile.global_position.distance_to(resume_before)) and ok
	else:
		ok = assert_true(freed, "projectile resumes sim after reset (expired by range/life)") and ok
	var doomed_freed := false
	for i in 30:
		await physics_frame
		if not is_instance_valid(doomed):
			doomed_freed = true
			break
	ok = assert_true(doomed_freed, "expiry resumes after reset") and ok
	instance.queue_free()
	await _clear_enemies()
	var lone = load("res://weapons/projectile.gd").new()
	root.add_child(lone)
	await process_frame
	lone.call("launch", Vector2.ZERO, Vector2(100, 0), 700.0, 1, 950.0)
	lone.set_physics_process(false)
	await process_frame
	ok = assert_true(bool(lone.call("_is_run_active")), "detached projectile defaults to active") and ok
	var lone_start: Vector2 = lone.global_position
	for i in 10:
		lone.call("_physics_process", 1.0 / 60.0)
	ok = assert_true(lone.global_position.distance_to(lone_start) > 1.0, "detached projectile displaces (%.1f px)" % lone.global_position.distance_to(lone_start)) and ok
	lone.queue_free()
	await _clear_enemies()
	return ok


func test_main_exposes_run_api() -> bool:
	var ok := true
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	for method_name: String in ["register_kill", "get_elapsed", "get_kills", "is_run_active", "reset_run", "get_peak_alive"]:
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


func test_main_register_kill_frozen_while_run_inactive() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var spawner := instance.get_node_or_null("Spawner")
	if spawner != null:
		spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	instance.call("register_kill")
	var baseline := int(instance.call("get_kills"))
	ok = assert_eq(baseline, 1, "baseline kill counted while active") and ok
	var label := instance.get_node_or_null("StatusLabel") as Label
	ok = assert_true(label != null, "main scene has StatusLabel") and ok
	if label == null:
		instance.queue_free()
		return false
	instance.call("end_run", "death")
	await process_frame
	ok = assert_true(not bool(instance.call("is_run_active")), "run inactive after end_run") and ok
	ok = assert_true(label.text.contains("GAME_OVER"), "HUD shows GAME_OVER after end_run") and ok
	var frozen_kills := int(instance.call("get_kills"))
	var frozen_text := label.text
	instance.call("register_kill")
	instance.call("register_kill")
	await process_frame
	ok = assert_eq(int(instance.call("get_kills")), frozen_kills, "inactive register_kill leaves counter frozen") and ok
	ok = assert_eq(label.text, frozen_text, "inactive register_kill leaves HUD frozen") and ok
	instance.call("reset_run")
	ok = assert_true(bool(instance.call("is_run_active")), "reset reactivates run") and ok
	var resumed_baseline := int(instance.call("get_kills"))
	ok = assert_eq(resumed_baseline, 0, "reset zeroes kills") and ok
	instance.call("register_kill")
	ok = assert_eq(int(instance.call("get_kills")), resumed_baseline + 1, "kills count again once active") and ok
	ok = assert_true(label.text.contains("KILLS=1"), "HUD KILLS token reflects resumed kill") and ok
	instance.queue_free()
	return ok


func test_main_reset_clears_peak() -> bool:
	var ok := true
	await _clear_enemies()
	var bare: Node = load("res://main.gd").new()
	ok = assert_eq(int(bare.call("get_peak_alive")), 0, "unwired coordinator reads zero peak") and ok
	bare.free()
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
	spawner.set("peak_alive", 7)
	instance.call("register_kill")
	ok = assert_eq(int(instance.call("get_peak_alive")), 7, "coordinator delegates spawner peak") and ok
	instance.call("reset_run")
	ok = assert_eq(int(spawner.get("peak_alive")), 0, "reset_run zeroes spawner peak") and ok
	ok = assert_eq(int(instance.call("get_peak_alive")), 0, "coordinator reads zero peak after reset") and ok
	ok = assert_eq(int(instance.call("get_kills")), 0, "reset still zeroes kills") and ok
	ok = assert_eq(float(instance.call("get_elapsed")), 0.0, "reset still zeroes clock") and ok
	ok = assert_true(bool(instance.call("is_run_active")), "reset still reactivates run") and ok
	instance.queue_free()
	await _clear_enemies()
	return ok


func test_main_peak_and_reset_follow_fresh_spawner_between_ticks() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var old_spawner := instance.get_node_or_null("Spawner")
	ok = assert_true(old_spawner != null, "main scene has Spawner") and ok
	if old_spawner == null:
		instance.queue_free()
		return false
	old_spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	old_spawner.set("peak_alive", 7)
	instance.remove_child(old_spawner)
	var fresh: Node = load("res://spawner.gd").new()
	fresh.name = "Spawner"
	fresh.set("player_path", NodePath("../Player"))
	fresh.set("spawn_interval", 3600.0)
	fresh.set("peak_alive", 42)
	instance.add_child(fresh)
	ok = assert_eq(int(instance.call("get_peak_alive")), 42, "same-frame peak read follows fresh Spawner") and ok
	instance.call("reset_run")
	ok = assert_eq(int(fresh.get("peak_alive")), 0, "reset_run zeroes fresh spawner peak") and ok
	ok = assert_eq(int(old_spawner.get("peak_alive")), 7, "reset_run leaves detached stale spawner untouched") and ok
	ok = assert_eq(int(instance.call("get_peak_alive")), 0, "coordinator reads zero peak after reset") and ok
	if old_spawner != null and is_instance_valid(old_spawner):
		old_spawner.queue_free()
	instance.queue_free()
	await _clear_enemies()
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


func test_main_hud_preserves_overshoot() -> bool:
	var ok := true
	var instance: Node = load("res://main.gd").new()
	root.add_child(instance)
	instance.set_physics_process(false)
	instance.set("hud_refresh_interval", 0.25)
	instance.set("_hud_accum", 0.0)
	instance.set("elapsed_seconds", 0.0)
	await process_frame
	instance.call("_physics_process", 0.30)
	var resid := float(instance.get("_hud_accum"))
	ok = assert_true(absf(resid - 0.05) < 0.01, "hud overshoot carried (accum=%.4f)" % resid) and ok
	ok = assert_true(absf(float(instance.call("get_elapsed")) - 0.30) < 0.01, "hud frame advances clock") and ok
	instance.set("_hud_accum", 0.0)
	instance.set("elapsed_seconds", 0.0)
	instance.call("_physics_process", 0.60)
	var resid2 := float(instance.get("_hud_accum"))
	ok = assert_true(absf(resid2 - 0.10) < 0.01, "hud long frame drains two intervals (accum=%.4f)" % resid2) and ok
	ok = assert_true(absf(float(instance.call("get_elapsed")) - 0.60) < 0.01, "hud long frame advances clock") and ok
	instance.queue_free()
	return ok


func test_main_hud_zero_interval_no_hang() -> bool:
	var ok := true
	var instance: Node = load("res://main.gd").new()
	root.add_child(instance)
	instance.set_physics_process(false)
	instance.set("hud_refresh_interval", 0.0)
	instance.set("_hud_accum", 0.0)
	instance.set("elapsed_seconds", 0.0)
	await process_frame
	instance.call("_physics_process", 1.0)
	ok = assert_true(absf(float(instance.call("get_elapsed")) - 1.0) < 0.01, "zero-interval hud frame still advances clock") and ok
	ok = assert_true(absf(float(instance.get("_hud_accum")) - 1.0) < 0.01, "zero-interval hud accumulates without draining (accum=%.4f)" % float(instance.get("_hud_accum"))) and ok
	instance.queue_free()
	return ok


func test_main_hud_reflects_damage_immediately() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player")
	var spawner := instance.get_node_or_null("Spawner")
	var label := instance.get_node_or_null("StatusLabel") as Label
	ok = assert_true(player != null, "main scene has Player") and ok
	ok = assert_true(label != null, "main scene has StatusLabel") and ok
	if player == null or label == null:
		instance.queue_free()
		return false
	if spawner != null:
		spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	ok = assert_true(label.text.contains("KILLS="), "HUD reflects kill state") and ok
	instance.set("_hud_accum", 0.0)
	player.call("take_damage", 10.0)
	ok = assert_eq(int(player.call("get_hp")), 90, "non-lethal hit reduces HP to 90") and ok
	await process_frame
	await physics_frame
	ok = assert_true(label.text.contains("HP=90"), "HUD shows HP=90 within 2 frames, no interval wait") and ok
	ok = assert_true(not bool(instance.call("is_game_over")), "non-lethal hit does not end run") and ok
	instance.queue_free()
	return ok


func test_main_health_push_frozen_when_run_inactive() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player")
	var spawner := instance.get_node_or_null("Spawner")
	var label := instance.get_node_or_null("StatusLabel") as Label
	ok = assert_true(player != null, "main scene has Player") and ok
	ok = assert_true(label != null, "main scene has StatusLabel") and ok
	if player == null or label == null:
		instance.queue_free()
		return false
	if spawner != null:
		spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	player.call("take_damage", 10.0)
	ok = assert_eq(int(player.call("get_hp")), 90, "non-lethal hit reduces HP to 90") and ok
	await process_frame
	await physics_frame
	ok = assert_true(label.text.contains("HP=90"), "HUD shows HP=90 within 2 frames, no interval wait") and ok
	for i in 40:
		await physics_frame
	instance.call("end_run", "quit")
	await process_frame
	ok = assert_true(not bool(instance.call("is_run_active")), "run inactive after end_run") and ok
	ok = assert_true(label.text.contains("GAME_OVER"), "HUD shows GAME_OVER after end_run") and ok
	var frozen := label.text
	instance.call("_on_player_health_changed", 90.0, 100.0)
	player.call("take_damage", 10.0)
	for i in 10:
		await physics_frame
	ok = assert_eq(label.text, frozen, "post-terminal health pushes leave HUD text frozen") and ok
	ok = assert_true(label.text.contains("GAME_OVER"), "HUD still shows GAME_OVER after post-terminal pushes") and ok
	instance.queue_free()
	return ok


func test_main_hud_rewires_after_health_replace() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player")
	var spawner := instance.get_node_or_null("Spawner")
	var label := instance.get_node_or_null("StatusLabel") as Label
	ok = assert_true(player != null, "main scene has Player") and ok
	ok = assert_true(label != null, "main scene has StatusLabel") and ok
	if player == null or label == null:
		instance.queue_free()
		return false
	if spawner != null:
		spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	var old_health := player.get_node_or_null("Health")
	ok = assert_true(old_health != null, "original Health present before swap") and ok
	if old_health != null:
		player.remove_child(old_health)
		old_health.queue_free()
	var fresh: Node = load("res://player/health.gd").new()
	fresh.name = "Health"
	player.add_child(fresh)
	var want_changed := Callable(instance, "_on_player_health_changed")
	var want_died := Callable(instance, "_on_player_died")
	var wired := false
	for i in 10:
		await physics_frame
		if fresh.is_connected("health_changed", want_changed) and fresh.is_connected("died", want_died):
			wired = true
			break
	ok = assert_true(wired, "physics-tick rewire connects fresh Health signals") and ok
	ok = assert_true(fresh.is_connected("health_changed", want_changed), "fresh Health health_changed wired") and ok
	ok = assert_true(fresh.is_connected("died", want_died), "fresh Health died wired") and ok
	var changed_conns := 0
	for entry: Dictionary in fresh.get_signal_connection_list("health_changed"):
		var changed_cal: Callable = entry["callable"]
		if changed_cal == want_changed:
			changed_conns += 1
	ok = assert_eq(changed_conns, 1, "fresh Health carries exactly one health_changed connection") and ok
	var died_conns := 0
	for entry: Dictionary in fresh.get_signal_connection_list("died"):
		var died_cal: Callable = entry["callable"]
		if died_cal == want_died:
			died_conns += 1
	ok = assert_eq(died_conns, 1, "fresh Health carries exactly one died connection") and ok
	instance.call("_connect_health_signals")
	instance.call("_connect_health_signals")
	var re_changed := 0
	for entry: Dictionary in fresh.get_signal_connection_list("health_changed"):
		var re_changed_cal: Callable = entry["callable"]
		if re_changed_cal == want_changed:
			re_changed += 1
	ok = assert_eq(re_changed, 1, "re-wiring twice keeps exactly one health_changed connection") and ok
	var re_died := 0
	for entry: Dictionary in fresh.get_signal_connection_list("died"):
		var re_died_cal: Callable = entry["callable"]
		if re_died_cal == want_died:
			re_died += 1
	ok = assert_eq(re_died, 1, "re-wiring twice keeps exactly one died connection") and ok
	if old_health != null and is_instance_valid(old_health):
		var stale := 0
		if old_health.has_signal("health_changed"):
			for entry: Dictionary in old_health.get_signal_connection_list("health_changed"):
				var stale_cal: Callable = entry["callable"]
				if stale_cal == want_changed:
					stale += 1
		if old_health.has_signal("died"):
			for entry: Dictionary in old_health.get_signal_connection_list("died"):
				var stale_died_cal: Callable = entry["callable"]
				if stale_died_cal == want_died:
					stale += 1
		ok = assert_eq(stale, 0, "stale Health carries zero coordinator connections") and ok
	instance.set("_hud_accum", 0.0)
	player.call("take_damage", 10.0)
	ok = assert_eq(int(player.call("get_hp")), 90, "non-lethal hit on fresh Health reduces HP to 90") and ok
	await process_frame
	await physics_frame
	ok = assert_true(label.text.contains("HP=90"), "HUD shows HP=90 within 2 frames after swap, no interval wait") and ok
	ok = assert_true(not bool(instance.call("is_game_over")), "non-lethal hit after swap does not end run") and ok
	for i in 40:
		await physics_frame
	instance.set("_hud_accum", 0.0)
	player.call("take_damage", 100.0)
	await process_frame
	await physics_frame
	ok = assert_true(bool(instance.call("is_game_over")), "lethal hit after swap ends run within 2 frames") and ok
	ok = assert_true(label != null and label.text.contains("GAME_OVER"), "HUD shows GAME_OVER within 2 frames after swap") and ok
	instance.queue_free()
	return ok


func test_main_hud_rewires_after_spawner_replace() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var spawner := instance.get_node_or_null("Spawner")
	var label := instance.get_node_or_null("StatusLabel") as Label
	ok = assert_true(spawner != null, "main scene has Spawner") and ok
	ok = assert_true(label != null, "main scene has StatusLabel") and ok
	if spawner == null or label == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	var old_spawner: Node = spawner
	ok = assert_true(old_spawner != null, "original Spawner present before swap") and ok
	instance.remove_child(old_spawner)
	var fresh: Node = load("res://spawner.gd").new()
	fresh.name = "Spawner"
	fresh.set("player_path", NodePath("../Player"))
	fresh.set("spawn_interval", 3600.0)
	instance.add_child(fresh)
	var want := Callable(instance, "_on_spawner_alive_changed")
	var wired := false
	for i in 10:
		await physics_frame
		if fresh.is_connected("alive_changed", want):
			wired = true
			break
	ok = assert_true(wired, "physics-tick rewire connects fresh Spawner signal") and ok
	ok = assert_true(fresh.is_connected("alive_changed", want), "fresh Spawner alive_changed wired") and ok
	ok = assert_true(instance.get("spawner") == fresh, "coordinator handle follows fresh Spawner") and ok
	var conns := 0
	for entry: Dictionary in fresh.get_signal_connection_list("alive_changed"):
		var cal: Callable = entry["callable"]
		if cal == want:
			conns += 1
	ok = assert_eq(conns, 1, "fresh Spawner carries exactly one alive_changed connection") and ok
	instance.call("_connect_spawner_signals")
	instance.call("_connect_spawner_signals")
	var re_conns := 0
	for entry: Dictionary in fresh.get_signal_connection_list("alive_changed"):
		var re_cal: Callable = entry["callable"]
		if re_cal == want:
			re_conns += 1
	ok = assert_eq(re_conns, 1, "re-wiring twice keeps exactly one alive_changed connection") and ok
	if old_spawner != null and is_instance_valid(old_spawner):
		var stale := 0
		if old_spawner.has_signal("alive_changed"):
			for entry: Dictionary in old_spawner.get_signal_connection_list("alive_changed"):
				var stale_cal: Callable = entry["callable"]
				if stale_cal == want:
					stale += 1
		ok = assert_eq(stale, 0, "stale Spawner carries zero coordinator connections") and ok
	ok = assert_eq(int(instance.get("_cached_alive")), int(fresh.call("get_alive")), "cache re-primed from fresh Spawner") and ok
	fresh.set("alive_count", 5)
	fresh.emit_signal("alive_changed", 5)
	await process_frame
	ok = assert_eq(int(instance.get("_cached_alive")), 5, "HUD cache follows fresh spawner push") and ok
	ok = assert_true(label.text.contains("ALIVE=5"), "HUD shows ALIVE=5 without interval wait") and ok
	if old_spawner != null and is_instance_valid(old_spawner):
		old_spawner.queue_free()
	instance.queue_free()
	return ok


func test_main_hud_rewires_after_player_replace() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var spawner := instance.get_node_or_null("Spawner")
	var label := instance.get_node_or_null("StatusLabel") as Label
	ok = assert_true(instance.get_node_or_null("Player") != null, "main scene has Player") and ok
	ok = assert_true(label != null, "main scene has StatusLabel") and ok
	if spawner == null or label == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	var old_player: Node = instance.get_node_or_null("Player")
	var old_health: Node = (old_player as Node).get_node_or_null("Health")
	ok = assert_true(old_player != null, "original Player present before swap") and ok
	ok = assert_true(old_health != null, "original Health present before swap") and ok
	instance.remove_child(old_player)
	var fresh := CharacterBody2D.new()
	fresh.name = "Player"
	fresh.set_script(load("res://player.gd"))
	var fresh_health: Node = load("res://player/health.gd").new()
	fresh_health.name = "Health"
	fresh.add_child(fresh_health)
	instance.add_child(fresh)
	var want_changed := Callable(instance, "_on_player_health_changed")
	var want_died := Callable(instance, "_on_player_died")
	var wired := false
	for i in 10:
		await physics_frame
		if fresh_health.is_connected("health_changed", want_changed) and fresh_health.is_connected("died", want_died):
			wired = true
			break
	ok = assert_true(wired, "physics-tick rewire connects fresh Player Health signals") and ok
	ok = assert_true(fresh_health.is_connected("health_changed", want_changed), "fresh Player Health health_changed wired") and ok
	ok = assert_true(fresh_health.is_connected("died", want_died), "fresh Player Health died wired") and ok
	ok = assert_true(instance.get("player") == fresh, "coordinator handle follows fresh Player") and ok
	var changed_conns := 0
	for entry: Dictionary in fresh_health.get_signal_connection_list("health_changed"):
		var changed_cal: Callable = entry["callable"]
		if changed_cal == want_changed:
			changed_conns += 1
	ok = assert_eq(changed_conns, 1, "fresh Player Health carries exactly one health_changed connection") and ok
	var died_conns := 0
	for entry: Dictionary in fresh_health.get_signal_connection_list("died"):
		var died_cal: Callable = entry["callable"]
		if died_cal == want_died:
			died_conns += 1
	ok = assert_eq(died_conns, 1, "fresh Player Health carries exactly one died connection") and ok
	instance.call("_connect_health_signals")
	instance.call("_connect_health_signals")
	var re_changed := 0
	for entry: Dictionary in fresh_health.get_signal_connection_list("health_changed"):
		var re_changed_cal: Callable = entry["callable"]
		if re_changed_cal == want_changed:
			re_changed += 1
	ok = assert_eq(re_changed, 1, "re-wiring twice keeps exactly one health_changed connection") and ok
	var re_died := 0
	for entry: Dictionary in fresh_health.get_signal_connection_list("died"):
		var re_died_cal: Callable = entry["callable"]
		if re_died_cal == want_died:
			re_died += 1
	ok = assert_eq(re_died, 1, "re-wiring twice keeps exactly one died connection") and ok
	if old_health != null and is_instance_valid(old_health):
		var stale := 0
		if old_health.has_signal("health_changed"):
			for entry: Dictionary in old_health.get_signal_connection_list("health_changed"):
				var stale_cal: Callable = entry["callable"]
				if stale_cal == want_changed:
					stale += 1
		if old_health.has_signal("died"):
			for entry: Dictionary in old_health.get_signal_connection_list("died"):
				var stale_died_cal: Callable = entry["callable"]
				if stale_died_cal == want_died:
					stale += 1
		ok = assert_eq(stale, 0, "stale Health carries zero coordinator connections") and ok
	instance.set("_hud_accum", 0.0)
	fresh.call("take_damage", 10.0)
	ok = assert_eq(int(fresh.call("get_hp")), 90, "non-lethal hit on fresh Player reduces HP to 90") and ok
	await process_frame
	await physics_frame
	ok = assert_true(label.text.contains("HP=90"), "HUD shows HP=90 within 2 frames after swap, no interval wait") and ok
	ok = assert_true(not bool(instance.call("is_game_over")), "non-lethal hit after swap does not end run") and ok
	for i in 40:
		await physics_frame
	instance.set("_hud_accum", 0.0)
	fresh.call("take_damage", 100.0)
	await process_frame
	await physics_frame
	ok = assert_true(bool(instance.call("is_game_over")), "lethal hit after swap ends run within 2 frames") and ok
	ok = assert_true(label != null and label.text.contains("GAME_OVER"), "HUD shows GAME_OVER within 2 frames after swap") and ok
	if old_player != null and is_instance_valid(old_player):
		old_player.queue_free()
	instance.queue_free()
	return ok


func test_main_hud_shows_game_over_immediately() -> bool:
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
	if player == null or spawner == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	player.call("take_damage", 95.0)
	ok = assert_eq(int(player.call("get_hp")), 5, "player reduced to HP 5") and ok
	for i in 36:
		await physics_frame
	instance.set("_hud_accum", 0.0)
	player.call("take_damage", 10.0)
	await process_frame
	await physics_frame
	ok = assert_true(bool(instance.call("is_game_over")), "lethal hit ends run within 2 frames") and ok
	var label := instance.get_node_or_null("StatusLabel") as Label
	ok = assert_true(label != null and label.text.contains("GAME_OVER"), "HUD shows GAME_OVER within 2 frames") and ok
	instance.queue_free()
	return ok


func test_main_died_handler_ends_run_without_player_forwarding() -> bool:
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
	if player == null or spawner == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	ok = assert_true(not bool(instance.call("is_game_over")), "run active before single-path died handler") and ok
	ok = assert_true(bool(instance.call("is_run_active")), "run active flag set before single-path died handler") and ok
	var health := player.get_node_or_null("Health")
	ok = assert_true(health != null, "Health present for single-path check") and ok
	if health == null:
		instance.queue_free()
		return false
	var player_cb := Callable(player, "_on_health_died")
	ok = assert_true(not health.is_connected("died", player_cb), "no player-side forwarding by construction") and ok
	ok = assert_true(not player.has_method("_on_health_died"), "player exposes no died forwarder") and ok
	var main_cb := Callable(instance, "_on_player_died")
	ok = assert_true(health.is_connected("died", main_cb), "Main died wiring present by construction") and ok
	var main_conns := 0
	for entry: Dictionary in health.get_signal_connection_list("died"):
		var cal: Callable = entry["callable"]
		if cal == main_cb:
			main_conns += 1
	ok = assert_eq(main_conns, 1, "Health died carries exactly one Main connection") and ok
	ok = assert_eq(health.get_signal_connection_list("died").size(), 1, "Health died carries exactly one subscriber total") and ok
	instance.call("_on_player_died")
	await process_frame
	await physics_frame
	ok = assert_true(bool(instance.call("is_game_over")), "Main handler alone ends run within 2 frames") and ok
	ok = assert_true(not bool(instance.call("is_run_active")), "run inactive after Main handler alone") and ok
	ok = assert_true(bool(instance.get("game_over")), "game_over flag set by Main handler alone") and ok
	var isolated_label := instance.get_node_or_null("StatusLabel") as Label
	ok = assert_true(isolated_label != null and isolated_label.text.contains("GAME_OVER"), "HUD shows GAME_OVER via Main handler alone") and ok
	var source := FileAccess.get_file_as_string("res://main.gd")
	ok = assert_true(source.contains("RUN_END=death"), "coordinator logs RUN_END=death") and ok
	var died_idx := source.find("func _on_player_died")
	ok = assert_true(died_idx >= 0, "main.gd defines _on_player_died") and ok
	var died_block := ""
	if died_idx >= 0:
		var next_func := source.find("\nfunc ", died_idx + 1)
		if next_func < 0:
			died_block = source.substr(died_idx)
		else:
			died_block = source.substr(died_idx, next_func - died_idx)
	ok = assert_true(died_block.contains('end_run("death")'), "Main died handler calls end_run death") and ok
	ok = assert_true(not died_block.contains("_refresh_hud"), "handler reaches HUD via end_run, no duplicated logic") and ok
	var end_idx := source.find("func end_run")
	ok = assert_true(end_idx >= 0, "main.gd defines end_run") and ok
	var end_block := ""
	if end_idx >= 0:
		var end_next := source.find("\nfunc ", end_idx + 1)
		if end_next < 0:
			end_block = source.substr(end_idx)
		else:
			end_block = source.substr(end_idx, end_next - end_idx)
	ok = assert_true(end_block.contains("_refresh_hud"), "end_run reaches _refresh_hud") and ok
	instance.queue_free()
	return ok


func test_died_has_single_end_run_path() -> bool:
	var ok := true
	var player_source := FileAccess.get_file_as_string("res://player.gd")
	ok = assert_eq(player_source.count("end_run"), 0, "player wires zero end_run paths") and ok
	ok = assert_eq(player_source.count('"died"'), 0, "player wires zero died subscriptions") and ok
	ok = assert_true(not player_source.contains("end_run"), "player source holds no end_run text") and ok
	ok = assert_true(not player_source.contains('"died"'), "player source holds no died text") and ok
	var main_source := FileAccess.get_file_as_string("res://main.gd")
	ok = assert_eq(main_source.count('end_run("death")'), 1, "coordinator holds exactly one end_run death call site") and ok
	var died_idx := main_source.find("func _on_player_died")
	ok = assert_true(died_idx >= 0, "main.gd defines _on_player_died") and ok
	var died_block := ""
	if died_idx >= 0:
		var next_func := main_source.find("\nfunc ", died_idx + 1)
		if next_func < 0:
			died_block = main_source.substr(died_idx)
		else:
			died_block = main_source.substr(died_idx, next_func - died_idx)
	ok = assert_true(died_block.contains('end_run("death")'), "single call site lives in _on_player_died") and ok
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player") as Node2D
	var spawner := instance.get_node_or_null("Spawner")
	ok = assert_true(player != null, "main scene has Player") and ok
	if player == null or spawner == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	var health := player.get_node_or_null("Health")
	ok = assert_true(health != null, "Health present for single-path check") and ok
	if health == null:
		instance.queue_free()
		return false
	var player_cb := Callable(player, "_on_health_died")
	ok = assert_true(not health.is_connected("died", player_cb), "no player-side forwarding by construction") and ok
	ok = assert_true(not player.has_method("_on_health_died"), "player exposes no died forwarder") and ok
	var main_cb := Callable(instance, "_on_player_died")
	ok = assert_true(health.is_connected("died", main_cb), "Health died wired only to Main") and ok
	var main_conns := 0
	for entry: Dictionary in health.get_signal_connection_list("died"):
		var cal: Callable = entry["callable"]
		if cal == main_cb:
			main_conns += 1
	ok = assert_eq(main_conns, 1, "Health died carries exactly one Main connection") and ok
	ok = assert_eq(health.get_signal_connection_list("died").size(), 1, "Health died carries exactly one subscriber total") and ok
	ok = assert_true(main_source.contains("RUN_END=death"), "coordinator logs RUN_END=death") and ok
	health.emit_signal("died")
	await process_frame
	await physics_frame
	ok = assert_true(bool(instance.call("is_game_over")), "emitted died ends the run via single path") and ok
	ok = assert_true(not bool(instance.call("is_run_active")), "run inactive after single-path died") and ok
	ok = assert_true(bool(instance.get("game_over")), "game_over flag set via single path") and ok
	var label := instance.get_node_or_null("StatusLabel") as Label
	ok = assert_true(label != null and label.text.contains("GAME_OVER"), "HUD shows GAME_OVER via single path") and ok
	instance.call("_on_player_died")
	await process_frame
	ok = assert_true(bool(instance.call("is_game_over")), "second end_run stays latched") and ok
	instance.queue_free()
	return ok


func test_main_hud_has_no_enemies_group_scan() -> bool:
	var ok := true
	var source := FileAccess.get_file_as_string("res://main.gd")
	ok = assert_true(not source.contains('get_nodes_in_group("enemies")'), "main.gd issues no enemies-group scan") and ok
	ok = assert_eq(source.count("get_nodes_in_group"), 0, "main.gd contains zero get_nodes_in_group calls") and ok
	ok = assert_eq(source.count("get_first_node_in_group"), 0, "main.gd contains zero get_first_node_in_group calls") and ok
	ok = assert_eq(source.count("call_group"), 0, "main.gd contains zero call_group calls") and ok
	ok = assert_true(source.contains("_cached_alive"), "HUD renders from cached alive count") and ok
	ok = assert_true(source.contains("alive_changed"), "HUD subscribes to spawner alive_changed") and ok
	return ok


func test_main_hud_alive_tracks_spawner_cache() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var spawner := instance.get_node_or_null("Spawner")
	var label := instance.get_node_or_null("StatusLabel") as Label
	ok = assert_true(spawner != null, "main scene has Spawner") and ok
	ok = assert_true(label != null, "main scene has StatusLabel") and ok
	if spawner == null or label == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	spawner.set("_accum", 0.0)
	await process_frame
	ok = assert_true(get_nodes_in_group("enemies").is_empty(), "no background spawns before batch") and ok
	ok = assert_eq(int(spawner.call("get_alive")), 0, "spawner cache starts at zero") and ok
	spawner.set("batch_size", 3)
	spawner.set("spawn_interval", 0.5)
	spawner.set("_accum", 0.0)
	spawner.call("_physics_process", 0.6)
	await process_frame
	ok = assert_eq(get_nodes_in_group("enemies").size(), 3, "known batch spawns three") and ok
	ok = assert_eq(int(spawner.call("get_alive")), 3, "spawner cache tracks batch") and ok
	ok = assert_eq(int(spawner.call("get_alive")), get_nodes_in_group("enemies").size(), "cache equals group size") and ok
	ok = assert_eq(int(instance.get("_cached_alive")), 3, "HUD cache follows spawner push") and ok
	ok = assert_true(label.text.contains("ALIVE=3"), "HUD shows ALIVE=3 without interval wait") and ok
	var victim: Node = null
	for enemy: Node in get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			victim = enemy
			break
	ok = assert_true(victim != null, "batch chaser available for lethal damage") and ok
	if victim == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	spawner.set("_accum", 0.0)
	victim.call("take_damage", float(victim.get("max_health")))
	for i in 30:
		await physics_frame
		if get_nodes_in_group("enemies").size() == 2:
			break
	ok = assert_eq(int(spawner.call("get_alive")), 2, "spawner cache decrements on died") and ok
	ok = assert_eq(get_nodes_in_group("enemies").size(), 2, "group reflects freed chaser") and ok
	ok = assert_eq(int(instance.get("_cached_alive")), 2, "HUD cache follows died push") and ok
	ok = assert_true(label.text.contains("ALIVE=2"), "HUD shows ALIVE=2 after died") and ok
	instance.queue_free()
	return ok


func test_main_hud_refresh_is_pure_paint() -> bool:
	var ok := true
	var source := FileAccess.get_file_as_string("res://main.gd")
	var hud_idx := source.find("func _refresh_hud")
	ok = assert_true(hud_idx >= 0, "main.gd defines _refresh_hud") and ok
	var hud_block := ""
	if hud_idx >= 0:
		var hud_next := source.find("\nfunc ", hud_idx + 1)
		if hud_next < 0:
			hud_block = source.substr(hud_idx)
		else:
			hud_block = source.substr(hud_idx, hud_next - hud_idx)
	ok = assert_true(not hud_block.contains("_connect_health_signals"), "_refresh_hud performs no health rewire") and ok
	ok = assert_true(not hud_block.contains("connect("), "_refresh_hud performs no signal connect") and ok
	ok = assert_true(not hud_block.contains("disconnect("), "_refresh_hud performs no signal disconnect") and ok
	var tick_idx := source.find("func _physics_process")
	ok = assert_true(tick_idx >= 0, "main.gd defines _physics_process") and ok
	var tick_block := ""
	if tick_idx >= 0:
		var tick_next := source.find("\nfunc ", tick_idx + 1)
		if tick_next < 0:
			tick_block = source.substr(tick_idx)
		else:
			tick_block = source.substr(tick_idx, tick_next - tick_idx)
	ok = assert_true(tick_block.contains("_connect_health_signals"), "physics tick still owns rewiring") and ok
	var end_idx := source.find("func end_run")
	ok = assert_true(end_idx >= 0, "main.gd defines end_run") and ok
	var end_block := ""
	if end_idx >= 0:
		var end_next := source.find("\nfunc ", end_idx + 1)
		if end_next < 0:
			end_block = source.substr(end_idx)
		else:
			end_block = source.substr(end_idx, end_next - end_idx)
	ok = assert_true(end_block.contains("_refresh_hud"), "end_run still reaches _refresh_hud") and ok
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player")
	var spawner := instance.get_node_or_null("Spawner")
	var label := instance.get_node_or_null("StatusLabel") as Label
	ok = assert_true(player != null, "main scene has Player") and ok
	ok = assert_true(label != null, "main scene has StatusLabel") and ok
	if player == null or label == null:
		instance.queue_free()
		return false
	if spawner != null:
		spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	instance.set_physics_process(false)
	var old_health := player.get_node_or_null("Health")
	ok = assert_true(old_health != null, "original Health present before swap") and ok
	if old_health != null:
		player.remove_child(old_health)
		old_health.queue_free()
	var fresh: Node = load("res://player/health.gd").new()
	fresh.name = "Health"
	player.add_child(fresh)
	await process_frame
	var want_changed := Callable(instance, "_on_player_health_changed")
	var want_died := Callable(instance, "_on_player_died")
	instance.call("_refresh_hud")
	ok = assert_true(label.text.contains("KILLS="), "paint-only refresh still paints kills") and ok
	ok = assert_true(label.text.contains("HP="), "paint-only refresh still paints HP") and ok
	ok = assert_true(not fresh.is_connected("health_changed", want_changed), "_refresh_hud alone wires no health_changed") and ok
	ok = assert_true(not fresh.is_connected("died", want_died), "_refresh_hud alone wires no died") and ok
	instance.call("_physics_process", 0.016)
	ok = assert_true(fresh.is_connected("health_changed", want_changed), "physics tick wires fresh health_changed") and ok
	ok = assert_true(fresh.is_connected("died", want_died), "physics tick wires fresh died") and ok
	var changed_conns := 0
	for entry: Dictionary in fresh.get_signal_connection_list("health_changed"):
		var changed_cal: Callable = entry["callable"]
		if changed_cal == want_changed:
			changed_conns += 1
	ok = assert_eq(changed_conns, 1, "physics tick wires exactly one health_changed connection") and ok
	var died_conns := 0
	for entry: Dictionary in fresh.get_signal_connection_list("died"):
		var died_cal: Callable = entry["callable"]
		if died_cal == want_died:
			died_conns += 1
	ok = assert_eq(died_conns, 1, "physics tick wires exactly one died connection") and ok
	instance.queue_free()
	return ok


func test_spawner_alive_count_tracks_spawn_and_died() -> bool:
	var ok := true
	await _clear_enemies()
	var spawner: Node = load("res://spawner.gd").new()
	root.add_child(spawner)
	spawner.set_physics_process(false)
	spawner.set("spawn_interval", 0.5)
	spawner.set("batch_size", 1)
	spawner.set("max_entities", 1000)
	var dummy := Node2D.new()
	root.add_child(dummy)
	spawner.set("player", dummy)
	await process_frame
	ok = assert_eq(int(spawner.call("get_alive")), 0, "detached spawner cache starts at zero") and ok
	spawner.call("_physics_process", 0.6)
	ok = assert_eq(get_nodes_in_group("enemies").size(), 1, "detached tick spawns one") and ok
	ok = assert_eq(int(spawner.call("get_alive")), 1, "cache tracks spawn") and ok
	var victim: Node = null
	for enemy: Node in get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.get_parent() == spawner:
			victim = enemy
			break
	ok = assert_true(victim != null, "spawned chaser available") and ok
	if victim == null:
		spawner.queue_free()
		dummy.queue_free()
		await _clear_enemies()
		return false
	victim.call("take_damage", float(victim.get("max_health")))
	for i in 30:
		await physics_frame
		if not is_instance_valid(victim):
			break
	ok = assert_eq(int(spawner.call("get_alive")), 0, "cache decrements on died") and ok
	spawner.queue_free()
	dummy.queue_free()
	await _clear_enemies()
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


func test_bolt_child_of_player_with_timer() -> bool:
	var ok := true
	ok = assert_true(ResourceLoader.exists("res://weapons/bolt.tscn"), "bolt scene exists") and ok
	var packed := load("res://weapons/bolt.tscn") as PackedScene
	ok = assert_true(packed != null, "bolt scene loads as PackedScene") and ok
	if packed != null:
		var probe := packed.instantiate()
		root.add_child(probe)
		await process_frame
		var timer := probe.get_node_or_null("Cooldown")
		ok = assert_true(timer != null and timer is Timer, "bolt scene contains Cooldown Timer") and ok
		probe.queue_free()
		await process_frame
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var bolt := instance.get_node_or_null("Player/Bolt")
	ok = assert_true(bolt != null, "main scene mounts Bolt under Player") and ok
	if bolt == null:
		instance.queue_free()
		return false
	ok = assert_true(bolt.has_method("_try_fire"), "bolt exposes _try_fire") and ok
	ok = assert_true(bolt.has_method("_on_cooldown_timeout"), "bolt exposes _on_cooldown_timeout") and ok
	ok = assert_true(float(bolt.get("cooldown")) > 0.0, "bolt cooldown export positive") and ok
	ok = assert_true(float(bolt.get("attack_range")) > 0.0, "bolt attack_range export positive") and ok
	ok = assert_true(bolt.get("range") == null, "bolt no longer exposes shadowing range export") and ok
	ok = assert_true(float(bolt.get("projectile_speed")) > 0.0, "bolt projectile_speed export positive") and ok
	var cooldown := bolt.get_node_or_null("Cooldown")
	ok = assert_true(cooldown != null and cooldown is Timer, "mounted Bolt has Cooldown Timer child") and ok
	if cooldown != null:
		ok = assert_true(absf(float((cooldown as Timer).wait_time) - float(bolt.get("cooldown"))) < 0.01, "timer wait_time syncs to cooldown export") and ok
	var source := FileAccess.get_file_as_string("res://weapons/bolt.gd")
	ok = assert_true(source.contains("projectiles_spawned="), "bolt logs projectiles_spawned counter") and ok
	ok = assert_true(not source.contains("var range"), "bolt source declares no shadowing var range member") and ok
	instance.queue_free()
	return ok


func test_bolt_range_covers_spawn_ring() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player") as Node2D
	var spawner := instance.get_node_or_null("Spawner")
	var bolt := instance.get_node_or_null("Player/Bolt")
	ok = assert_true(player != null, "main scene has Player") and ok
	ok = assert_true(spawner != null, "main scene has Spawner") and ok
	ok = assert_true(bolt != null, "main scene has Bolt") and ok
	if player == null or spawner == null or bolt == null:
		instance.queue_free()
		return false
	var bolt_range := float(bolt.get("attack_range"))
	var margin_max := float(spawner.get("spawn_margin_max"))
	ok = assert_true(bolt_range > 0.0, "bolt attack_range export positive") and ok
	ok = assert_true(margin_max > 0.0, "spawner spawn_margin_max positive") and ok
	# Engagement envelope is the DESIGN viewport (project 1280x720, same as the
	# spawner's FALLBACK_VIEWPORT_SIZE): the unit runner's root window is a
	# square 1280x1280 artifact of headless --script mode, not the game
	# viewport, so the live visible rect is not the meaningful spawn bound.
	var design_size: Vector2 = SpawnerScript.FALLBACK_VIEWPORT_SIZE
	var design_radius := 0.5 * design_size.length()
	var ring_bound := design_radius + margin_max
	ok = assert_true(ring_bound > design_radius, "spawn ring stays off-screen (bound=%.1f radius=%.1f)" % [ring_bound, design_radius]) and ok
	ok = assert_true(bolt_range >= ring_bound, "bolt range covers spawn ring (range=%.1f bound=%.1f)" % [bolt_range, ring_bound]) and ok
	var projectile = load("res://weapons/projectile.gd").new()
	ok = assert_true(projectile != null, "projectile script instantiates") and ok
	if projectile != null:
		ok = assert_eq(float(projectile.get("max_range")), bolt_range, "projectile default max_range mirrors bolt attack_range") and ok
		projectile.free()
	# Behavioral proof: a worst-case fresh spawn (ring bound from the player)
	# sits outside the design viewport yet inside bolt range, so _try_fire
	# engages it on the first snapshot with no closing distance required.
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		instance.queue_free()
		return false
	var fresh := packed.instantiate() as Node2D
	root.add_child(fresh)
	fresh.global_position = player.global_position + Vector2(ring_bound, 0)
	fresh.set("speed", 0.0)
	fresh.set("target", player)
	await process_frame
	var spawn_dist: float = fresh.global_position.distance_to(player.global_position)
	ok = assert_true(spawn_dist > design_radius, "worst-case spawn outside viewport (dist=%.1f radius=%.1f)" % [spawn_dist, design_radius]) and ok
	ok = assert_true(spawn_dist <= bolt_range, "worst-case spawn within bolt range (dist=%.1f range=%.1f)" % [spawn_dist, bolt_range]) and ok
	var shots_before := int(bolt.get("shots"))
	bolt.call("_try_fire")
	await process_frame
	ok = assert_eq(int(bolt.get("shots")), shots_before + 1, "bolt engages worst-case fresh spawn on first snapshot") and ok
	fresh.queue_free()
	instance.queue_free()
	return ok


func test_bolt_fires_at_nearest_in_range() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player") as Node2D
	var spawner := instance.get_node_or_null("Spawner")
	var bolt := instance.get_node_or_null("Player/Bolt")
	ok = assert_true(player != null, "main scene has Player") and ok
	ok = assert_true(spawner != null, "main scene has Spawner") and ok
	ok = assert_true(bolt != null, "main scene has Bolt") and ok
	if player == null or spawner == null or bolt == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		instance.queue_free()
		return false
	var center: Vector2 = player.global_position
	var near := packed.instantiate() as CharacterBody2D
	root.add_child(near)
	near.global_position = center + Vector2(180, 0)
	near.set("speed", 0.0)
	near.set("target", player)
	var far := packed.instantiate() as CharacterBody2D
	root.add_child(far)
	far.global_position = center + Vector2(-450, 0)
	far.set("speed", 0.0)
	far.set("target", player)
	await process_frame
	var seen_shot := false
	var seen_dir := false
	for i in 300:
		await physics_frame
		if int(bolt.get("shots")) >= 1:
			seen_shot = true
		for node in get_nodes_in_group("projectiles"):
			if is_instance_valid(node) and node is Node2D and node.get("direction") != null:
				var dir: Vector2 = node.get("direction")
				if dir.normalized().dot(Vector2.RIGHT) > 0.9:
					seen_dir = true
			break
		if seen_shot and seen_dir:
			break
	ok = assert_true(seen_shot, "bolt fired at least one shot in 5s with enemy in range") and ok
	ok = assert_true(seen_dir, "projectile flies toward nearest enemy snapshot (east)") and ok
	near.queue_free()
	far.queue_free()
	instance.queue_free()
	return ok


func test_projectile_frees_on_first_hit() -> bool:
	var ok := true
	await _clear_enemies()
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		return false
	var chaser := packed.instantiate() as CharacterBody2D
	root.add_child(chaser)
	chaser.global_position = Vector2(120, 0)
	chaser.set("target", null)
	chaser.set("velocity", Vector2.ZERO)
	var projectile = load("res://weapons/projectile.gd").new()
	root.add_child(projectile)
	await process_frame
	# 950.0 is the current Bolt/projectile range default (not 700.0 projectile speed).
	projectile.call("launch", Vector2.ZERO, Vector2(120, 0), 700.0, 1, 950.0)
	ok = assert_eq(projectile.collision_layer, 4, "projectile collision_layer is 4") and ok
	ok = assert_eq(projectile.collision_mask, 1, "projectile collision_mask is 1") and ok
	var freed := false
	for i in 120:
		await physics_frame
		if not is_instance_valid(projectile):
			freed = true
			break
	ok = assert_true(freed, "projectile queue-frees on first enemy hit") and ok
	var source := FileAccess.get_file_as_string("res://weapons/projectile.gd")
	ok = assert_true(source.contains("pierce_count==0"), "projectile logs pierce_count==0 on hit") and ok
	chaser.queue_free()
	return ok


func test_bolt_ticks_quiet_without_enemies() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player") as Node2D
	var spawner := instance.get_node_or_null("Spawner")
	var bolt := instance.get_node_or_null("Player/Bolt")
	ok = assert_true(player != null, "main scene has Player") and ok
	ok = assert_true(bolt != null, "main scene has Bolt") and ok
	if player == null or spawner == null or bolt == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	ok = assert_true(get_nodes_in_group("enemies").is_empty(), "no enemies present for quiet tick") and ok
	var cooldown := bolt.get_node_or_null("Cooldown") as Timer
	ok = assert_true(cooldown != null, "bolt has Cooldown timer") and ok
	Engine.time_scale = 10.0
	for i in 180:
		await physics_frame
	Engine.time_scale = 1.0
	ok = assert_true(get_nodes_in_group("enemies").is_empty(), "quiet run spawned nothing") and ok
	ok = assert_eq(int(bolt.get("shots")), 0, "bolt fires nothing with no target in 30 sim-seconds") and ok
	ok = assert_true(is_instance_valid(cooldown) and not cooldown.is_stopped(), "bolt timer still ticking after quiet run") and ok
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		instance.queue_free()
		return false
	var chaser := packed.instantiate() as CharacterBody2D
	root.add_child(chaser)
	chaser.global_position = player.global_position + Vector2(200, 0)
	chaser.set("speed", 0.0)
	chaser.set("target", player)
	var fired := false
	for i in 120:
		await physics_frame
		if int(bolt.get("shots")) > 0:
			fired = true
			break
	ok = assert_true(fired, "bolt fires within 2s once an enemy enters range") and ok
	chaser.queue_free()
	instance.queue_free()
	return ok


func test_no_attack_input_action() -> bool:
	var ok := true
	ok = assert_true(not InputMap.has_action("attack"), "no attack input action exists") and ok
	var source := FileAccess.get_file_as_string("res://project.godot")
	ok = assert_true(source.contains("move_up"), "project.godot keeps move_up") and ok
	ok = assert_true(source.contains("move_down"), "project.godot keeps move_down") and ok
	ok = assert_true(source.contains("move_left"), "project.godot keeps move_left") and ok
	ok = assert_true(source.contains("move_right"), "project.godot keeps move_right") and ok
	ok = assert_true(not source.contains("attack"), "project.godot defines no attack action") and ok
	ok = assert_true(not source.contains("ui_accept"), "project.godot adds no ui_accept action") and ok
	return ok


func test_chaser_has_take_damage() -> bool:
	var ok := true
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		return false
	var chaser := packed.instantiate()
	root.add_child(chaser)
	await process_frame
	ok = assert_true(chaser.has_method("take_damage"), "chaser exposes take_damage") and ok
	ok = assert_true(chaser.has_method("get_health"), "chaser exposes get_health") and ok
	ok = assert_true(chaser.has_method("is_dead"), "chaser exposes is_dead") and ok
	ok = assert_true(float(chaser.get("max_health")) > 0.0, "chaser max_health positive") and ok
	ok = assert_eq(float(chaser.call("get_health")), float(chaser.get("max_health")), "chaser starts at full HP") and ok
	ok = assert_true(not bool(chaser.call("is_dead")), "fresh chaser is not dead") and ok
	chaser.queue_free()
	return ok


func test_chaser_take_damage_reduces_health() -> bool:
	var ok := true
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		return false
	var chaser := packed.instantiate()
	root.add_child(chaser)
	await process_frame
	var max_hp := float(chaser.get("max_health"))
	var changed := [0]
	var last := [0.0, 0.0]
	var on_changed := func(current: float, maximum: float) -> void:
		changed[0] += 1
		last[0] = current
		last[1] = maximum
	chaser.connect("health_changed", on_changed)
	chaser.call("take_damage", 1.0)
	await process_frame
	ok = assert_eq(float(chaser.call("get_health")), max_hp - 1.0, "partial damage reduces HP by 1.0") and ok
	ok = assert_true(changed[0] >= 1, "health_changed emitted on partial damage") and ok
	ok = assert_eq(last[1], max_hp, "health_changed reports maximum") and ok
	ok = assert_true(is_instance_valid(chaser), "partially damaged chaser still valid") and ok
	ok = assert_true(chaser.is_in_group("enemies"), "partially damaged chaser stays in enemies group") and ok
	ok = assert_true(not bool(chaser.call("is_dead")), "partial damage does not kill") and ok
	chaser.queue_free()
	return ok


func test_chaser_take_damage_kills_at_zero() -> bool:
	var ok := true
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		return false
	var chaser := packed.instantiate()
	root.add_child(chaser)
	await process_frame
	var max_hp := float(chaser.get("max_health"))
	var died_count := [0]
	var on_died := func() -> void:
		died_count[0] += 1
	chaser.connect("died", on_died)
	chaser.call("take_damage", max_hp)
	ok = assert_true(bool(chaser.call("is_dead")), "lethal damage marks dead") and ok
	ok = assert_eq(died_count[0], 1, "died emitted exactly once") and ok
	ok = assert_true(chaser.is_queued_for_deletion(), "lethal damage queues free") and ok
	chaser.call("take_damage", 999.0)
	ok = assert_eq(died_count[0], 1, "overkill after death is a no-op") and ok
	ok = assert_eq(float(chaser.call("get_health")), 0.0, "HP clamped at zero") and ok
	await process_frame
	await process_frame
	ok = assert_true(not is_instance_valid(chaser) or not chaser.is_in_group("enemies"), "dead chaser leaves enemies group") and ok
	return ok


func test_chaser_take_damage_guards() -> bool:
	var ok := true
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		return false
	var chaser := packed.instantiate()
	root.add_child(chaser)
	await process_frame
	var max_hp := float(chaser.get("max_health"))
	var died_count := [0]
	var on_died := func() -> void:
		died_count[0] += 1
	chaser.connect("died", on_died)
	chaser.call("take_damage", 0.0)
	await process_frame
	ok = assert_eq(float(chaser.call("get_health")), max_hp, "zero damage leaves HP unchanged") and ok
	chaser.call("take_damage", -5.0)
	await process_frame
	ok = assert_eq(float(chaser.call("get_health")), max_hp, "negative damage leaves HP unchanged") and ok
	ok = assert_eq(died_count[0], 0, "guarded hits emit no died") and ok
	ok = assert_true(not bool(chaser.call("is_dead")), "guarded chaser still alive") and ok
	ok = assert_true(is_instance_valid(chaser) and chaser.is_in_group("enemies"), "guarded chaser stays grouped") and ok
	chaser.queue_free()
	return ok


func test_combat_tuning_data_values() -> bool:
	var ok := true
	var tuning = load("res://data/combat.gd")
	ok = assert_true(tuning != null, "combat tuning script loads") and ok
	if tuning == null:
		return false
	var params: Dictionary = tuning.PLAYER
	ok = assert_eq(float(params.get("max_hp")), 100.0, "tuning max_hp is 100") and ok
	ok = assert_eq(float(params.get("contact_damage")), 10.0, "tuning contact_damage is 10") and ok
	ok = assert_eq(float(params.get("iframes")), 0.5, "tuning iframes is 0.5") and ok
	ok = assert_eq(float(params.get("contact_radius")), 26.0, "tuning contact_radius is 26") and ok
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player")
	ok = assert_true(player != null, "main scene has Player") and ok
	var health := instance.get_node_or_null("Player/Health")
	ok = assert_true(health != null, "main scene mounts Health under Player") and ok
	if player == null or health == null:
		instance.queue_free()
		return false
	ok = assert_eq(float(health.get("max_hp")), float(params.get("max_hp")), "live Health max_hp matches tuning") and ok
	ok = assert_eq(float(health.get("invuln_duration")), float(params.get("iframes")), "live Health iframes match tuning") and ok
	ok = assert_eq(float(player.get("contact_damage")), float(params.get("contact_damage")), "live contact_damage matches tuning") and ok
	ok = assert_eq(float(player.get("contact_radius")), float(params.get("contact_radius")), "live contact_radius matches tuning") and ok
	ok = assert_eq(float(player.call("get_hp")), 100.0, "player starts at full HP") and ok
	instance.queue_free()
	return ok


func test_player_iframes_ignore_rapid_second_hit() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player")
	var spawner := instance.get_node_or_null("Spawner")
	ok = assert_true(player != null, "main scene has Player") and ok
	if player == null or spawner == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	ok = assert_eq(float(player.call("get_hp")), 100.0, "player starts at HP 100") and ok
	player.call("take_damage", 10.0)
	ok = assert_eq(int(player.call("get_hp")), 90, "first hit reduces HP to 90") and ok
	player.call("take_damage", 10.0)
	ok = assert_eq(int(player.call("get_hp")), 90, "rapid second hit ignored by i-frames") and ok
	for i in 36:
		await physics_frame
	player.call("take_damage", 10.0)
	ok = assert_eq(int(player.call("get_hp")), 80, "hit after i-frames expire reduces HP again") and ok
	instance.queue_free()
	return ok


func test_player_invuln_frozen_while_run_inactive() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player")
	var spawner := instance.get_node_or_null("Spawner")
	ok = assert_true(player != null, "main scene has Player") and ok
	ok = assert_true(spawner != null, "main scene has Spawner") and ok
	if player == null or spawner == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	var health: Node = player.get_node_or_null("Health")
	ok = assert_true(health != null, "player has Health node") and ok
	if health == null:
		instance.queue_free()
		return false
	player.call("take_damage", 10.0)
	ok = assert_eq(int(player.call("get_hp")), 90, "first hit reduces HP to 90") and ok
	var frozen: float = float(health.get("_invuln"))
	ok = assert_true(frozen > 0.0, "i-frame timer running after hit") and ok
	instance.call("end_run", "death")
	ok = assert_true(not bool(instance.call("is_run_active")), "run inactive after end_run") and ok
	for i in 60:
		await physics_frame
		ok = assert_eq(float(health.get("_invuln")), frozen, "inactive invuln timer holds value") and ok
	player.call("take_damage", 10.0)
	ok = assert_eq(int(player.call("get_hp")), 90, "rapid second hit still ignored while frozen") and ok
	health.call("_physics_process", 1.0 / 60.0)
	ok = assert_eq(float(health.get("_invuln")), frozen, "direct tick is no-op while inactive") and ok
	instance.call("reset_run")
	ok = assert_true(bool(instance.call("is_run_active")), "reset reactivates run") and ok
	ok = assert_eq(int(player.call("get_hp")), 100, "reset restores full HP") and ok
	player.call("take_damage", 10.0)
	ok = assert_eq(int(player.call("get_hp")), 90, "hit lands on fresh timer after reset") and ok
	for i in 36:
		await physics_frame
	player.call("take_damage", 10.0)
	ok = assert_eq(int(player.call("get_hp")), 80, "hit lands again after resumed decay") and ok
	instance.queue_free()
	var lone = load("res://player/health.gd").new()
	root.add_child(lone)
	lone.set_physics_process(false)
	lone.set("_invuln", 0.5)
	lone.call("_physics_process", 1.0 / 60.0)
	ok = assert_true(float(lone.get("_invuln")) < 0.5, "detached health defaults to active") and ok
	lone.queue_free()
	await _clear_enemies()
	return ok


func test_contact_damage_with_methodless_health_is_safe() -> bool:
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
	if player == null or spawner == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	var old_health := player.get_node_or_null("Health")
	if old_health != null:
		player.remove_child(old_health)
		old_health.queue_free()
	var bare := Node.new()
	bare.name = "Health"
	player.add_child(bare)
	player.set("health", bare)
	await process_frame
	ok = assert_true(not bare.has_method("is_dead"), "bare Health exposes no is_dead") and ok
	ok = assert_true(not bare.has_method("get_hp"), "bare Health exposes no get_hp") and ok
	ok = assert_true(not bare.has_method("take_damage"), "bare Health exposes no take_damage") and ok
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		instance.queue_free()
		return false
	var chaser := packed.instantiate() as CharacterBody2D
	root.add_child(chaser)
	chaser.global_position = player.global_position
	chaser.set("speed", 0.0)
	chaser.set("target", player)
	var fallback := float(player.get("max_hp"))
	for i in 30:
		await physics_frame
	var source := FileAccess.get_file_as_string("res://player.gd")
	ok = assert_true(source.contains('has_method("is_dead")'), "contact guard checks is_dead") and ok
	ok = assert_true(source.contains('has_method("get_hp")'), "contact guard checks get_hp") and ok
	ok = assert_true(source.contains('has_method("take_damage")'), "contact guard checks take_damage") and ok
	ok = assert_eq(float(player.call("get_hp")), fallback, "method-less Health proxy reads max_hp fallback") and ok
	ok = assert_true(is_instance_valid(player), "player survives method-less Health contact ticks") and ok
	ok = assert_true(is_instance_valid(bare), "method-less Health node survives contact ticks") and ok
	chaser.queue_free()
	instance.queue_free()
	return ok


func test_player_contact_damage_reduces_hp() -> bool:
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
	if player == null or spawner == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		instance.queue_free()
		return false
	var before := float(player.call("get_hp"))
	var chaser := packed.instantiate() as CharacterBody2D
	root.add_child(chaser)
	chaser.global_position = player.global_position
	chaser.set("speed", 0.0)
	chaser.set("target", player)
	var touched := false
	for i in 30:
		await physics_frame
		if float(player.call("get_hp")) < before:
			touched = true
			break
	ok = assert_true(touched, "contact with chaser reduces HP within 30 frames") and ok
	chaser.queue_free()
	instance.queue_free()
	return ok


func test_player_stacked_contact_damage_sums() -> bool:
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
	if player == null or spawner == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		instance.queue_free()
		return false
	var per_hit := float(player.get("contact_damage"))
	var chasers: Array = []
	for i in 3:
		var chaser := packed.instantiate() as CharacterBody2D
		root.add_child(chaser)
		chaser.global_position = player.global_position
		chaser.set("speed", 0.0)
		chaser.set("target", player)
		chasers.append(chaser)
	var touched := false
	for i in 30:
		await physics_frame
		if float(player.call("get_hp")) < 100.0:
			touched = true
			break
	ok = assert_true(touched, "stacked contact reduces HP within 30 frames") and ok
	ok = assert_eq(int(player.call("get_hp")), int(100.0 - 3.0 * per_hit), "3 overlapping chasers deal summed damage in one tick") and ok
	for chaser in chasers:
		if is_instance_valid(chaser):
			chaser.queue_free()
	instance.queue_free()
	return ok


func test_player_contact_path_scans_enemies_once() -> bool:
	var ok := true
	var source := FileAccess.get_file_as_string("res://player.gd")
	ok = assert_eq(source.count('get_nodes_in_group("enemies")'), 1, "contact path issues exactly one enemies-group lookup per tick") and ok
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
	await _clear_enemies()
	_release_move_actions()
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		instance.queue_free()
		return false
	var per_hit := float(player.get("contact_damage"))
	var hp_before := float(player.call("get_hp"))
	var center: Vector2 = player.global_position
	var ring := 4
	var chasers: Array = []
	for i in ring:
		var chaser := packed.instantiate() as CharacterBody2D
		root.add_child(chaser)
		var angle := TAU * float(i) / float(ring)
		chaser.global_position = center + Vector2(cos(angle), sin(angle)) * 20.0
		chaser.set("target", player)
		chasers.append(chaser)
	var before: Vector2 = player.global_position
	Input.action_press("move_right")
	for i in 60:
		await physics_frame
	Input.action_release("move_right")
	var pushed: float = player.global_position.distance_to(before)
	ok = assert_true(pushed > 50.0, "moving player shoves through overlapping ring (%.1f px)" % pushed) and ok
	ok = assert_true(float(player.call("get_hp")) < hp_before, "overlapping ring deals contact damage in the same tick window") and ok
	ok = assert_true(float(player.call("get_hp")) <= hp_before - per_hit, "contact tick deals at least one contact_damage") and ok
	_release_move_actions()
	for chaser in chasers:
		if is_instance_valid(chaser):
			chaser.queue_free()
	instance.queue_free()
	return ok


func test_enemy_died_wires_kill_and_xp_log() -> bool:
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
	var spawned: Node = null
	for i in 60:
		await physics_frame
		var live := get_nodes_in_group("enemies")
		if live.size() > 0 and is_instance_valid(live[0]):
			spawned = live[0]
			break
	ok = assert_true(spawned != null, "spawner produced a chaser") and ok
	if spawned == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	var baseline := int(instance.call("get_kills"))
	spawned.call("take_damage", float(spawned.get("max_health")))
	var raised := false
	for i in 30:
		await physics_frame
		if int(instance.call("get_kills")) == baseline + 1:
			raised = true
			break
	ok = assert_true(raised, "lethal damage on spawner chaser raises kills by 1") and ok
	var source := FileAccess.get_file_as_string("res://spawner.gd")
	ok = assert_true(source.contains("XP_PLACEHOLDER"), "spawner logs XP_PLACEHOLDER on kill") and ok
	ok = assert_true(source.contains("ENEMY_POOF"), "spawner logs ENEMY_POOF on kill") and ok
	instance.queue_free()
	return ok


func test_spawner_died_rewire_is_idempotent() -> bool:
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
	var rewired: Node = null
	for i in 60:
		await physics_frame
		var live := get_nodes_in_group("enemies")
		if live.size() > 0 and is_instance_valid(live[0]):
			rewired = live[0]
			break
	ok = assert_true(rewired != null, "spawner produced a chaser") and ok
	if rewired == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	var expected := Callable(spawner, "_on_enemy_died").bind(rewired)
	if rewired.has_signal("died"):
		if not rewired.is_connected("died", expected):
			rewired.connect("died", expected)
	var spawner_conns := 0
	for entry: Dictionary in rewired.get_signal_connection_list("died"):
		var cal: Callable = entry["callable"]
		if cal == expected:
			spawner_conns += 1
	ok = assert_eq(spawner_conns, 1, "re-wiring same chaser keeps exactly one spawner connection") and ok
	var baseline := int(instance.call("get_kills"))
	rewired.call("take_damage", float(rewired.get("max_health")))
	var raised := false
	for i in 30:
		await physics_frame
		if int(instance.call("get_kills")) == baseline + 1:
			raised = true
			break
	ok = assert_true(raised, "lethal damage after re-wire raises kills by 1") and ok
	ok = assert_eq(int(instance.call("get_kills")), baseline + 1, "kill increment is exactly 1, no double count") and ok
	var source := FileAccess.get_file_as_string("res://spawner.gd")
	ok = assert_true(source.contains("has_signal(\"died\")"), "spawner retains has_signal died guard") and ok
	ok = assert_true(source.contains("is_connected"), "spawner guards died re-wire with is_connected") and ok
	instance.queue_free()
	return ok


func test_enemy_lethal_damage_frees_within_half_second() -> bool:
	var ok := true
	await _clear_enemies()
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		return false
	var chaser := packed.instantiate() as CharacterBody2D
	root.add_child(chaser)
	await process_frame
	chaser.call("take_damage", float(chaser.get("max_health")))
	var freed := false
	for i in 30:
		await physics_frame
		if not is_instance_valid(chaser):
			freed = true
			break
	ok = assert_true(freed, "lethally hit chaser freed within half a second") and ok
	return ok


func test_lethal_contact_ends_run_with_run_end_log() -> bool:
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
	if player == null or spawner == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	player.call("take_damage", 95.0)
	ok = assert_eq(int(player.call("get_hp")), 5, "player reduced to HP 5") and ok
	for i in 36:
		await physics_frame
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		instance.queue_free()
		return false
	var chaser := packed.instantiate() as CharacterBody2D
	root.add_child(chaser)
	chaser.global_position = player.global_position
	chaser.set("speed", 0.0)
	chaser.set("target", player)
	var over := false
	for i in 60:
		await physics_frame
		if bool(instance.call("is_game_over")) and bool(instance.get("game_over")) and not bool(instance.call("is_run_active")):
			over = true
			break
	ok = assert_true(over, "lethal contact ends the run within a second") and ok
	ok = assert_true(bool(instance.get("game_over")), "game_over flag set") and ok
	ok = assert_true(not bool(instance.call("is_run_active")), "run inactive after death") and ok
	var label := instance.get_node_or_null("StatusLabel") as Label
	ok = assert_true(label != null and label.text.contains("GAME_OVER"), "HUD shows GAME_OVER line") and ok
	var source := FileAccess.get_file_as_string("res://main.gd")
	ok = assert_true(source.contains("RUN_END=death"), "coordinator logs RUN_END=death") and ok
	ok = assert_true(source.contains("game_over=true"), "coordinator logs game_over=true") and ok
	ok = assert_true(source.contains("ERRORS=0"), "coordinator logs ERRORS=0") and ok
	chaser.queue_free()
	instance.queue_free()
	return ok


func test_end_run_non_death_logs_uniform_tokens() -> bool:
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
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	ok = assert_true(bool(instance.call("is_run_active")), "run active before non-death end") and ok
	ok = assert_true(not bool(instance.call("is_game_over")), "no game over before non-death end") and ok
	instance.call("end_run", "quit")
	await process_frame
	ok = assert_true(not bool(instance.call("is_run_active")), "run inactive after non-death end") and ok
	ok = assert_true(bool(instance.call("is_game_over")), "is_game_over true after non-death end") and ok
	ok = assert_true(bool(instance.get("game_over")), "game_over flag set after non-death end") and ok
	var label := instance.get_node_or_null("StatusLabel") as Label
	ok = assert_true(label != null and label.text.contains("GAME_OVER"), "HUD shows GAME_OVER after non-death end") and ok
	var source := FileAccess.get_file_as_string("res://main.gd")
	var end_idx := source.find("func end_run")
	ok = assert_true(end_idx >= 0, "main.gd defines end_run") and ok
	var end_block := ""
	if end_idx >= 0:
		var end_next := source.find("\nfunc ", end_idx + 1)
		if end_next < 0:
			end_block = source.substr(end_idx)
		else:
			end_block = source.substr(end_idx, end_next - end_idx)
	ok = assert_true(end_block.contains("RUN_END=%s"), "non-death branch logs RUN_END reason token") and ok
	ok = assert_true(end_block.contains("game_over=true"), "non-death branch logs game_over=true") and ok
	ok = assert_true(end_block.contains("ERRORS=0"), "non-death branch logs ERRORS=0") and ok
	ok = assert_true(end_block.contains("elapsed="), "non-death branch logs elapsed") and ok
	ok = assert_true(end_block.contains("kills="), "non-death branch logs kills") and ok
	ok = assert_true(end_block.contains("RUN_END=%s game_over=true ERRORS=0"), "non-death log carries uniform token tail") and ok
	ok = assert_true(source.contains("RUN_END=death"), "coordinator retains RUN_END=death literal") and ok
	instance.queue_free()
	return ok


func test_end_run_is_idempotent() -> bool:
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
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	instance.call("end_run", "death")
	await process_frame
	ok = assert_true(not bool(instance.call("is_run_active")), "run inactive after first end_run") and ok
	ok = assert_true(bool(instance.call("is_game_over")), "game over after first end_run") and ok
	var label := instance.get_node_or_null("StatusLabel") as Label
	ok = assert_true(label != null and label.text.contains("GAME_OVER"), "HUD shows GAME_OVER after first end_run") and ok
	var first_text := label.text
	var first_reason := str(instance.call("get_run_reason"))
	instance.call("end_run", "death")
	instance.call("_on_player_died")
	await process_frame
	await physics_frame
	ok = assert_true(not bool(instance.call("is_run_active")), "run stays inactive after repeated end_run") and ok
	ok = assert_true(bool(instance.call("is_game_over")), "game over stays true after repeated end_run") and ok
	ok = assert_eq(label.text, first_text, "HUD unchanged after repeated end_run") and ok
	ok = assert_eq(str(instance.call("get_run_reason")), first_reason, "first terminal reason wins") and ok
	var source := FileAccess.get_file_as_string("res://main.gd")
	var end_idx := source.find("func end_run")
	ok = assert_true(end_idx >= 0, "main.gd defines end_run") and ok
	var end_block := ""
	if end_idx >= 0:
		var end_next := source.find("\nfunc ", end_idx + 1)
		if end_next < 0:
			end_block = source.substr(end_idx)
		else:
			end_block = source.substr(end_idx, end_next - end_idx)
	ok = assert_true(end_block.contains("if game_over:"), "end_run latches on game_over") and ok
	ok = assert_true(end_block.contains("return"), "latch early-returns") and ok
	ok = assert_true(end_block.contains("_refresh_hud"), "end_run reaches _refresh_hud") and ok
	ok = assert_true(end_block.contains("RUN_END=death"), "end_run retains RUN_END=death literal") and ok
	instance.queue_free()
	return ok


func test_player_died_rewire_after_health_replace() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player")
	var spawner := instance.get_node_or_null("Spawner")
	ok = assert_true(player != null, "main scene has Player") and ok
	if player == null or spawner == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	var old_health := player.get_node_or_null("Health")
	ok = assert_true(old_health != null, "original Health present before swap") and ok
	if old_health != null:
		player.remove_child(old_health)
		old_health.queue_free()
	var fresh: Node = load("res://player/health.gd").new()
	fresh.name = "Health"
	player.add_child(fresh)
	await process_frame
	for i in 10:
		await physics_frame
		if fresh.is_connected("died", Callable(instance, "_on_player_died")):
			break
	var player_cb := Callable(player, "_on_health_died")
	ok = assert_true(not fresh.is_connected("died", player_cb), "player wires no died forwarding after swap") and ok
	ok = assert_true(not player.has_method("_on_health_died"), "player exposes no died forwarder") and ok
	var main_cb := Callable(instance, "_on_player_died")
	ok = assert_true(fresh.is_connected("died", main_cb), "coordinator rewires fresh Health died") and ok
	player.call("_refresh_health_wiring")
	var conns := 0
	for entry: Dictionary in fresh.get_signal_connection_list("died"):
		var cal: Callable = entry["callable"]
		if cal == main_cb:
			conns += 1
	ok = assert_eq(conns, 1, "fresh Health keeps exactly one Main died connection") and ok
	var player_conns := 0
	for entry: Dictionary in fresh.get_signal_connection_list("died"):
		var cal: Callable = entry["callable"]
		if cal == player_cb:
			player_conns += 1
	ok = assert_eq(player_conns, 0, "fresh Health keeps zero player died connections") and ok
	ok = assert_true(player.get("health") == fresh, "health proxy follows the swapped child") and ok
	ok = assert_true(not bool(instance.call("is_game_over")), "run active before lethal hit on replacement") and ok
	player.call("take_damage", 100.0)
	var over := false
	for i in 60:
		await physics_frame
		if bool(instance.call("is_game_over")) and not bool(instance.call("is_run_active")):
			over = true
			break
	ok = assert_true(over, "lethal hit on replaced Health ends the run within a second") and ok
	ok = assert_true(bool(instance.get("game_over")), "game_over flag set after replacement death") and ok
	ok = assert_true(not bool(instance.call("is_run_active")), "run inactive after replacement death") and ok
	var label := instance.get_node_or_null("StatusLabel") as Label
	ok = assert_true(label != null and label.text.contains("GAME_OVER"), "HUD shows GAME_OVER line") and ok
	var source := FileAccess.get_file_as_string("res://player.gd")
	ok = assert_eq(source.count("end_run"), 0, "player holds zero end_run paths") and ok
	ok = assert_eq(source.count('"died"'), 0, "player holds zero died subscriptions") and ok
	instance.queue_free()
	return ok


func test_player_health_rewire_on_replace() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player")
	var spawner := instance.get_node_or_null("Spawner")
	ok = assert_true(player != null, "main scene has Player") and ok
	if player == null or spawner == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	var old_health := player.get_node_or_null("Health")
	ok = assert_true(old_health != null, "original Health present before swap") and ok
	if old_health != null:
		player.remove_child(old_health)
		old_health.queue_free()
	var fresh: Node = load("res://player/health.gd").new()
	fresh.name = "Health"
	player.add_child(fresh)
	await process_frame
	await process_frame
	for i in 10:
		await physics_frame
		if fresh.is_connected("died", Callable(instance, "_on_player_died")):
			break
	ok = assert_true(player.get("health") == fresh, "health proxy follows the swapped child") and ok
	var player_cb := Callable(player, "_on_health_died")
	ok = assert_true(not fresh.is_connected("died", player_cb), "swap wires zero player died connections") and ok
	ok = assert_true(not player.has_method("_on_health_died"), "player exposes no died forwarder") and ok
	var want := Callable(instance, "_on_player_died")
	ok = assert_true(fresh.is_connected("died", want), "child-order notification wires fresh Health died via Main") and ok
	var conns := 0
	for entry: Dictionary in fresh.get_signal_connection_list("died"):
		var cal: Callable = entry["callable"]
		if cal == want:
			conns += 1
	ok = assert_eq(conns, 1, "swapped Health carries exactly one Main died connection") and ok
	player.call("_wire_health")
	player.call("_wire_health")
	var rewired := 0
	for entry: Dictionary in fresh.get_signal_connection_list("died"):
		var cal: Callable = entry["callable"]
		if cal == want:
			rewired += 1
	ok = assert_eq(rewired, 1, "re-wiring twice keeps exactly one Main died connection") and ok
	var stale_player := 0
	for entry: Dictionary in fresh.get_signal_connection_list("died"):
		var cal: Callable = entry["callable"]
		if cal == player_cb:
			stale_player += 1
	ok = assert_eq(stale_player, 0, "re-wiring twice keeps zero player died connections") and ok
	ok = assert_true(not bool(instance.call("is_game_over")), "run active before lethal hit on replacement") and ok
	player.call("take_damage", 100.0)
	var over := false
	for i in 60:
		await physics_frame
		if bool(instance.call("is_game_over")) and not bool(instance.call("is_run_active")):
			over = true
			break
	ok = assert_true(over, "lethal hit on replaced Health ends the run within a second") and ok
	ok = assert_true(bool(instance.get("game_over")), "game_over flag set after replacement death") and ok
	ok = assert_true(not bool(instance.call("is_run_active")), "run inactive after replacement death") and ok
	var label := instance.get_node_or_null("StatusLabel") as Label
	ok = assert_true(label != null and label.text.contains("GAME_OVER"), "HUD shows GAME_OVER line") and ok
	var source := FileAccess.get_file_as_string("res://player.gd")
	ok = assert_eq(source.count("end_run"), 0, "player holds zero end_run paths") and ok
	ok = assert_eq(source.count('"died"'), 0, "player holds zero died subscriptions") and ok
	instance.queue_free()
	return ok


func test_player_rewire_same_node_is_noop() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player")
	var spawner := instance.get_node_or_null("Spawner")
	ok = assert_true(player != null, "main scene has Player") and ok
	if player == null or spawner == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	var health := player.get_node_or_null("Health")
	ok = assert_true(health != null, "original Health present before re-wire") and ok
	if health == null:
		instance.queue_free()
		return false
	var player_cb := Callable(player, "_on_health_died")
	ok = assert_true(not health.is_connected("died", player_cb), "original Health carries no player forwarding") and ok
	ok = assert_true(not player.has_method("_on_health_died"), "player exposes no died forwarder") and ok
	var want := Callable(instance, "_on_player_died")
	ok = assert_true(health.is_connected("died", want), "original Health wired to Main died") and ok
	var before := 0
	for entry: Dictionary in health.get_signal_connection_list("died"):
		var cal: Callable = entry["callable"]
		if cal == want:
			before += 1
	ok = assert_eq(before, 1, "same-node Health carries exactly one Main died connection") and ok
	player.call("take_damage", 0.0)
	player.call("get_hp")
	player.call("_wire_health")
	player.call("take_damage", 0.0)
	player.call("get_hp")
	player.call("_wire_health")
	ok = assert_true(not health.is_connected("died", player_cb), "repeated proxy refresh adds no player forwarding") and ok
	ok = assert_true(health.is_connected("died", want), "repeated proxy refresh keeps Main wired") and ok
	var kept := 0
	for entry: Dictionary in health.get_signal_connection_list("died"):
		var cal: Callable = entry["callable"]
		if cal == want:
			kept += 1
	ok = assert_eq(kept, 1, "repeated proxy refresh keeps exactly one Main died connection") and ok
	var source := FileAccess.get_file_as_string("res://player.gd")
	ok = assert_true(source.contains("_wired_health != current"), "player guards re-wire with identity check") and ok
	ok = assert_eq(source.count("end_run"), 0, "player holds zero end_run paths") and ok
	ok = assert_eq(source.count('"died"'), 0, "player holds zero died subscriptions") and ok
	var old_health := player.get_node_or_null("Health")
	player.remove_child(old_health)
	old_health.queue_free()
	var fresh: Node = load("res://player/health.gd").new()
	fresh.name = "Health"
	player.add_child(fresh)
	await process_frame
	await process_frame
	for i in 10:
		await physics_frame
		if fresh.is_connected("died", want):
			break
	ok = assert_true(player.get("health") == fresh, "health proxy follows the swapped child") and ok
	ok = assert_true(fresh.is_connected("died", want), "swap wires fresh Health died via Main") and ok
	ok = assert_true(not fresh.is_connected("died", player_cb), "swap wires zero player died connections") and ok
	var swapped := 0
	for entry: Dictionary in fresh.get_signal_connection_list("died"):
		var cal: Callable = entry["callable"]
		if cal == want:
			swapped += 1
	ok = assert_eq(swapped, 1, "swapped Health carries exactly one Main died connection") and ok
	var stale := 0
	if is_instance_valid(old_health):
		for entry: Dictionary in old_health.get_signal_connection_list("died"):
			var cal: Callable = entry["callable"]
			if cal == want:
				stale += 1
	ok = assert_eq(stale, 0, "old Health carries no Main died connection after swap") and ok
	ok = assert_true(not bool(instance.call("is_game_over")), "run active before lethal hit on replacement") and ok
	player.call("take_damage", 100.0)
	var over := false
	for i in 60:
		await physics_frame
		if bool(instance.call("is_game_over")) and not bool(instance.call("is_run_active")):
			over = true
			break
	ok = assert_true(over, "lethal hit on replaced Health ends the run within a second") and ok
	instance.queue_free()
	return ok


func test_player_get_hp_does_not_rewire() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player")
	var spawner := instance.get_node_or_null("Spawner")
	ok = assert_true(player != null, "main scene has Player") and ok
	if player == null or spawner == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	var health := player.get_node_or_null("Health")
	ok = assert_true(health != null, "Health present before disconnect") and ok
	if health == null:
		instance.queue_free()
		return false
	var player_cb := Callable(player, "_on_health_died")
	ok = assert_true(not health.is_connected("died", player_cb), "player-side died absent by construction") and ok
	ok = assert_true(not player.has_method("_on_health_died"), "player exposes no died forwarder") and ok
	var main_cb := Callable(instance, "_on_player_died")
	ok = assert_true(health.is_connected("died", main_cb), "Main died wired before reads") and ok
	var live_hp := float(health.call("get_hp"))
	var hp_before := float(player.call("get_hp"))
	ok = assert_eq(hp_before, live_hp, "get_hp reads live Health") and ok
	var label := instance.get_node_or_null("StatusLabel") as Label
	var hud_before := ""
	if label != null:
		hud_before = label.text
	player.call("get_hp")
	player.call("get_hp")
	instance.call("_refresh_hud")
	ok = assert_true(not health.is_connected("died", player_cb), "reads add no player-side died") and ok
	var readded := 0
	for entry: Dictionary in health.get_signal_connection_list("died"):
		var cal: Callable = entry["callable"]
		if cal == player_cb:
			readded += 1
	ok = assert_eq(readded, 0, "reads re-add zero player-side died connections") and ok
	var main_kept := 0
	for entry: Dictionary in health.get_signal_connection_list("died"):
		var cal: Callable = entry["callable"]
		if cal == main_cb:
			main_kept += 1
	ok = assert_eq(main_kept, 1, "reads keep exactly one Main died connection") and ok
	ok = assert_eq(float(player.call("get_hp")), live_hp, "get_hp still returns live HP after reads") and ok
	var hud_label := instance.get_node_or_null("StatusLabel") as Label
	if hud_label != null:
		ok = assert_eq(hud_label.text, hud_before, "HUD text unchanged by read-only refresh") and ok
	else:
		ok = assert_true(false, "HUD label present after reads") and ok
	var source := FileAccess.get_file_as_string("res://player.gd")
	var get_idx := source.find("func get_hp")
	ok = assert_true(get_idx >= 0, "player.gd defines get_hp") and ok
	var get_body := ""
	if get_idx >= 0:
		var get_next := source.find("\nfunc ", get_idx + 1)
		if get_next < 0:
			get_body = source.substr(get_idx)
		else:
			get_body = source.substr(get_idx, get_next - get_idx)
	ok = assert_true(not get_body.contains("_wire_health"), "get_hp performs no health rewire") and ok
	ok = assert_true(not get_body.contains("connect"), "get_hp performs no signal connect") and ok
	ok = assert_true(not get_body.contains("disconnect"), "get_hp performs no signal disconnect") and ok
	ok = assert_eq(source.count("end_run"), 0, "player holds zero end_run paths") and ok
	ok = assert_eq(source.count('"died"'), 0, "player holds zero died subscriptions") and ok
	var take_body := source.substr(source.find("func take_damage"), 400)
	ok = assert_true(take_body.contains("_wire_health()"), "take_damage keeps health wiring preamble") and ok
	var restore_body := source.substr(source.find("func restore_full_health"), 400)
	ok = assert_true(restore_body.contains("_wire_health()"), "restore_full_health keeps health wiring preamble") and ok
	var contact_body := source.substr(source.find("func _check_contact_damage"), 500)
	ok = assert_true(contact_body.contains("_wire_health()"), "contact tick keeps health wiring preamble") and ok
	instance.queue_free()
	return ok


func test_restart_run_restores_full_run() -> bool:
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
	if player == null or spawner == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	instance.call("register_kill")
	instance.call("register_kill")
	player.call("take_damage", 95.0)
	for i in 36:
		await physics_frame
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		instance.queue_free()
		return false
	var chaser := packed.instantiate() as CharacterBody2D
	root.add_child(chaser)
	chaser.global_position = player.global_position
	chaser.set("speed", 0.0)
	chaser.set("target", player)
	var over := false
	for i in 60:
		await physics_frame
		if bool(instance.call("is_game_over")):
			over = true
			break
	ok = assert_true(over, "run ended before restart") and ok
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.echo = false
	key_event.keycode = KEY_R
	key_event.physical_keycode = KEY_R
	instance.call("_unhandled_input", key_event)
	ok = assert_eq(float(player.call("get_hp")), 100.0, "restart restores HP 100") and ok
	ok = assert_eq(int(instance.call("get_kills")), 0, "restart zeroes kills") and ok
	ok = assert_eq(float(instance.call("get_elapsed")), 0.0, "restart zeroes clock") and ok
	ok = assert_eq(bool(instance.get("game_over")), false, "restart clears game_over") and ok
	ok = assert_true(bool(instance.call("is_run_active")), "restart reactivates run") and ok
	var label := instance.get_node_or_null("StatusLabel") as Label
	ok = assert_true(label != null and not label.text.contains("GAME_OVER"), "HUD clears GAME_OVER after restart") and ok
	chaser.queue_free()
	instance.queue_free()
	return ok


func test_reset_run_uses_fresh_handles_after_swap() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var old_player := instance.get_node_or_null("Player")
	var old_spawner := instance.get_node_or_null("Spawner")
	var label := instance.get_node_or_null("StatusLabel") as Label
	ok = assert_true(old_player != null, "main scene has Player") and ok
	ok = assert_true(old_spawner != null, "main scene has Spawner") and ok
	ok = assert_true(label != null, "main scene has StatusLabel") and ok
	if old_player == null or old_spawner == null or label == null:
		instance.queue_free()
		return false
	old_spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	old_player.call("take_damage", 30.0)
	ok = assert_true(float(old_player.call("get_hp")) < 100.0, "live Player damaged before swap") and ok
	var stale_hp := float(old_player.call("get_hp"))
	old_spawner.set("peak_alive", 7)
	instance.call("register_kill")
	instance.call("register_kill")
	instance.set("elapsed_seconds", 12.5)
	var old_health := (old_player as Node).get_node_or_null("Health")
	ok = assert_true(old_health != null, "original Health present before swap") and ok
	# Same-name swap of both children with no physics frame in between,
	# mirroring test_main_hud_rewires_after_spawner_replace (Spawner half)
	# and test_main_hud_rewires_after_player_replace (Player half).
	instance.remove_child(old_spawner)
	old_spawner.queue_free()
	var fresh_spawner: Node = load("res://spawner.gd").new()
	fresh_spawner.name = "Spawner"
	fresh_spawner.set("player_path", NodePath("../Player"))
	fresh_spawner.set("spawn_interval", 3600.0)
	fresh_spawner.set("peak_alive", 42)
	instance.add_child(fresh_spawner)
	instance.remove_child(old_player)
	old_player.queue_free()
	var fresh_player := CharacterBody2D.new()
	fresh_player.name = "Player"
	fresh_player.set_script(load("res://player.gd"))
	var fresh_health: Node = load("res://player/health.gd").new()
	fresh_health.name = "Health"
	fresh_player.add_child(fresh_health)
	instance.add_child(fresh_player)
	fresh_player.call("take_damage", 40.0)
	ok = assert_true(float(fresh_health.call("get_hp")) < float(fresh_health.get("max_hp")), "fresh Health damaged before reset") and ok
	# Poison the coordinator caches to reproduce the stale-handle state:
	# remove/add delivery already leaves them stale, so re-assert it.
	instance.set("player", old_player)
	instance.set("spawner", old_spawner)
	# Synchronous reset with zero frames between swap and reset.
	instance.call("reset_run")
	ok = assert_true(instance.get("player") == fresh_player, "reset reseats player handle on live node") and ok
	ok = assert_true(instance.get("spawner") == fresh_spawner, "reset reseats spawner handle on live node") and ok
	ok = assert_eq(float(fresh_player.call("get_hp")), 100.0, "reset heals the live Player to full") and ok
	ok = assert_eq(float(fresh_health.call("get_hp")), float(fresh_health.get("max_hp")), "fresh Health reads full after reset") and ok
	ok = assert_eq(float(old_player.call("get_hp")), stale_hp, "reset leaves the detached stale Player untouched") and ok
	ok = assert_eq(int(fresh_spawner.get("peak_alive")), 0, "reset zeroes live spawner peak") and ok
	ok = assert_eq(int(old_spawner.get("peak_alive")), 7, "reset leaves detached stale spawner untouched") and ok
	ok = assert_eq(int(instance.call("get_peak_alive")), 0, "coordinator reads zero peak after reset") and ok
	ok = assert_eq(int(instance.call("get_kills")), 0, "reset zeroes kills") and ok
	ok = assert_eq(float(instance.call("get_elapsed")), 0.0, "reset zeroes clock") and ok
	ok = assert_true(bool(instance.call("is_run_active")), "reset reactivates run") and ok
	ok = assert_eq(bool(instance.get("game_over")), false, "reset clears game_over") and ok
	ok = assert_true(instance.get("_wired_spawner") == fresh_spawner, "reset rewires spawner handle synchronously") and ok
	ok = assert_true(instance.get("_wired_health") == fresh_health, "reset rewires health handle synchronously") and ok
	var want_changed := Callable(instance, "_on_player_health_changed")
	var want_died := Callable(instance, "_on_player_died")
	ok = assert_true(fresh_health.is_connected("health_changed", want_changed), "reset wires fresh health_changed") and ok
	ok = assert_true(fresh_health.is_connected("died", want_died), "reset wires fresh died") and ok
	var want_alive := Callable(instance, "_on_spawner_alive_changed")
	ok = assert_true(fresh_spawner.is_connected("alive_changed", want_alive), "reset wires fresh alive_changed") and ok
	ok = assert_true(label.text.contains("HP=100"), "HUD shows HP=100 after synchronous reset") and ok
	ok = assert_true(label.text.contains("KILLS=0"), "HUD shows KILLS=0 after synchronous reset") and ok
	ok = assert_true(not label.text.contains("GAME_OVER"), "HUD clears GAME_OVER after reset") and ok
	if old_spawner != null and is_instance_valid(old_spawner):
		old_spawner.queue_free()
	if old_player != null and is_instance_valid(old_player):
		old_player.queue_free()
	instance.queue_free()
	await _clear_enemies()
	return ok


func test_restore_full_health_rewires_after_swap() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player")
	var spawner := instance.get_node_or_null("Spawner")
	ok = assert_true(player != null, "main scene has Player") and ok
	if player == null or spawner == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	player.call("take_damage", 30.0)
	ok = assert_true(float(player.call("get_hp")) < 100.0, "original Health damaged before swap") and ok
	var old_health := player.get_node_or_null("Health")
	ok = assert_true(old_health != null, "original Health present before swap") and ok
	if old_health == null:
		instance.queue_free()
		return false
	# Swap the Health child (same remove/queue_free/add idiom as
	# test_player_health_rewire_on_replace), damage the fresh node so the
	# heal is observable, then restore in the SAME frame with no await in
	# between. The cached proxy is left pointing at the detached node to
	# reproduce the stale-cache state: add/remove_child delivery already
	# re-seats the proxy synchronously, so only a stale cache proves that
	# restore_full_health re-resolves instead of trusting the cache.
	player.remove_child(old_health)
	old_health.queue_free()
	var fresh: Node = load("res://player/health.gd").new()
	fresh.name = "Health"
	player.add_child(fresh)
	fresh.call("take_damage", 40.0)
	ok = assert_true(float(fresh.call("get_hp")) < float(fresh.get("max_hp")), "fresh Health damaged before restore") and ok
	player.set("health", old_health)
	player.call("restore_full_health")
	ok = assert_true(player.get("health") == fresh, "restore re-seats the health proxy on the live child") and ok
	ok = assert_eq(float(player.call("get_hp")), 100.0, "restore heals the live Health to full") and ok
	ok = assert_eq(float(fresh.call("get_hp")), float(fresh.get("max_hp")), "fresh node HP reads full after restore") and ok
	ok = assert_true(float(old_health.call("get_hp")) < 100.0, "restore leaves the stale node untouched") and ok
	await process_frame
	for i in 10:
		await physics_frame
		if fresh.is_connected("died", Callable(instance, "_on_player_died")):
			break
	var player_cb := Callable(player, "_on_health_died")
	ok = assert_true(not fresh.is_connected("died", player_cb), "restore wires zero player died connections") and ok
	ok = assert_true(not player.has_method("_on_health_died"), "player exposes no died forwarder") and ok
	var want := Callable(instance, "_on_player_died")
	ok = assert_true(fresh.is_connected("died", want), "restore path leaves fresh Health died wired via Main") and ok
	var conns := 0
	for entry: Dictionary in fresh.get_signal_connection_list("died"):
		var cal: Callable = entry["callable"]
		if cal == want:
			conns += 1
	ok = assert_eq(conns, 1, "fresh Health carries exactly one Main died connection") and ok
	var source := FileAccess.get_file_as_string("res://player.gd")
	var body := source.substr(source.find("func restore_full_health"), 400)
	ok = assert_true(body.contains("_wire_health()"), "restore_full_health refreshes health wiring") and ok
	ok = assert_eq(source.count("end_run"), 0, "player holds zero end_run paths") and ok
	ok = assert_eq(source.count('"died"'), 0, "player holds zero died subscriptions") and ok
	ok = assert_true(not bool(instance.call("is_game_over")), "run active before lethal hit on replacement") and ok
	player.call("take_damage", 100.0)
	var over := false
	for i in 60:
		await physics_frame
		if bool(instance.call("is_game_over")) and not bool(instance.call("is_run_active")):
			over = true
			break
	ok = assert_true(over, "lethal hit on replaced Health ends the run within a second") and ok
	ok = assert_true(bool(instance.get("game_over")), "game_over flag set after replacement death") and ok
	instance.queue_free()
	return ok


func test_contact_damage_rewires_after_swap() -> bool:
	var ok := true
	await _clear_enemies()
	var instance := _instantiate_main()
	ok = assert_true(instance != null, "main scene instantiates") and ok
	if instance == null:
		return false
	await process_frame
	var player := instance.get_node_or_null("Player")
	var spawner := instance.get_node_or_null("Spawner")
	ok = assert_true(player != null, "main scene has Player") and ok
	if player == null or spawner == null:
		instance.queue_free()
		return false
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	# Damage the original Health so the stale node is distinguishable from
	# the fresh full-HP replacement after the swap.
	player.call("take_damage", 30.0)
	var old_health := player.get_node_or_null("Health")
	ok = assert_true(old_health != null, "original Health present before swap") and ok
	if old_health == null:
		instance.queue_free()
		return false
	var stale_hp := float(old_health.call("get_hp"))
	ok = assert_true(stale_hp < 100.0, "original Health damaged before swap") and ok
	# Swap the Health child (same remove/queue_free/add idiom as
	# test_player_health_rewire_on_replace), then poison the cached proxy
	# to reproduce the notification-bypassing stale-cache state. NOTE: no
	# player.call("get_hp")/player.call("take_damage") between the poison
	# and the tick poll below — those proxies rewire and would mask the bug.
	player.remove_child(old_health)
	old_health.queue_free()
	var fresh: Node = load("res://player/health.gd").new()
	fresh.name = "Health"
	player.add_child(fresh)
	player.set("health", old_health)
	var per_hit := float(player.get("contact_damage"))
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		instance.queue_free()
		return false
	var chaser := packed.instantiate() as CharacterBody2D
	root.add_child(chaser)
	chaser.global_position = (player as Node2D).global_position
	chaser.set("speed", 0.0)
	chaser.set("target", player)
	var touched := false
	for i in 30:
		await physics_frame
		if float(fresh.call("get_hp")) < float(fresh.get("max_hp")):
			touched = true
			break
	ok = assert_true(touched, "contact tick damages the live Health within 30 frames") and ok
	ok = assert_true(player.get("health") == fresh, "contact tick re-seats the health proxy on the live child") and ok
	ok = assert_eq(float(fresh.call("get_hp")), float(fresh.get("max_hp")) - per_hit, "live Health takes exactly one summed contact tick") and ok
	ok = assert_true(not is_instance_valid(old_health) or float(old_health.call("get_hp")) == stale_hp, "contact tick leaves the stale node untouched") and ok
	for i in 10:
		await physics_frame
		if fresh.is_connected("died", Callable(instance, "_on_player_died")):
			break
	var player_cb := Callable(player, "_on_health_died")
	ok = assert_true(not fresh.is_connected("died", player_cb), "contact tick wires zero player died connections") and ok
	ok = assert_true(not player.has_method("_on_health_died"), "player exposes no died forwarder") and ok
	var want := Callable(instance, "_on_player_died")
	ok = assert_true(fresh.is_connected("died", want), "contact tick leaves fresh Health died wired via Main") and ok
	var conns := 0
	for entry: Dictionary in fresh.get_signal_connection_list("died"):
		var cal: Callable = entry["callable"]
		if cal == want:
			conns += 1
	ok = assert_eq(conns, 1, "fresh Health carries exactly one Main died connection") and ok
	var source := FileAccess.get_file_as_string("res://player.gd")
	var body := source.substr(source.find("func _check_contact_damage"), 500)
	ok = assert_true(body.contains("_wire_health()"), "contact tick refreshes health wiring") and ok
	ok = assert_eq(source.count("end_run"), 0, "player holds zero end_run paths") and ok
	ok = assert_eq(source.count('"died"'), 0, "player holds zero died subscriptions") and ok
	chaser.queue_free()
	instance.queue_free()
	return ok


func test_player_health_full_before_tree_entry() -> bool:
	var ok := true
	var health: Node = load("res://player/health.gd").new()
	ok = assert_true(health != null, "health script instantiates") and ok
	if health == null:
		return false
	ok = assert_true(not health.is_inside_tree(), "fresh Health reads pre-tree") and ok
	ok = assert_eq(float(health.call("get_hp")), float(health.get("max_hp")), "pre-tree HP reads full") and ok
	ok = assert_true(not bool(health.call("is_dead")), "pre-tree Health is not dead") and ok
	health.free()
	var packed := load("res://main.tscn") as PackedScene
	ok = assert_true(packed != null, "main scene loads as PackedScene") and ok
	if packed == null:
		return false
	var instance := packed.instantiate()
	ok = assert_true(not instance.is_inside_tree(), "instantiated main reads pre-tree") and ok
	var mounted := instance.get_node_or_null("Player/Health")
	ok = assert_true(mounted != null, "main scene mounts Health under Player") and ok
	if mounted == null:
		instance.queue_free()
		return false
	ok = assert_eq(float(mounted.call("get_hp")), float(mounted.get("max_hp")), "mounted pre-tree HP reads full") and ok
	ok = assert_true(not bool(mounted.call("is_dead")), "mounted pre-tree Health is not dead") and ok
	instance.queue_free()
	return ok


func test_chaser_health_full_before_tree_entry() -> bool:
	var ok := true
	var chaser = load("res://enemies/chaser.gd").new()
	ok = assert_true(chaser != null, "chaser script instantiates") and ok
	if chaser == null:
		return false
	ok = assert_true(not chaser.is_inside_tree(), "fresh chaser reads pre-tree") and ok
	ok = assert_eq(float(chaser.call("get_health")), float(chaser.get("max_health")), "pre-tree HP reads full") and ok
	ok = assert_true(not bool(chaser.call("is_dead")), "pre-tree chaser is not dead") and ok
	chaser.free()
	var packed := load("res://enemies/chaser.tscn") as PackedScene
	ok = assert_true(packed != null, "chaser scene loads as PackedScene") and ok
	if packed == null:
		return false
	var spawned := packed.instantiate()
	ok = assert_true(not spawned.is_inside_tree(), "instantiated chaser reads pre-tree") and ok
	ok = assert_eq(float(spawned.call("get_health")), float(spawned.get("max_health")), "spawned pre-tree HP reads full") and ok
	ok = assert_true(not bool(spawned.call("is_dead")), "spawned pre-tree chaser is not dead") and ok
	spawned.queue_free()
	return ok


func test_player_proxy_hp_fallback_detached() -> bool:
	var ok := true
	var player = load("res://player.gd").new()
	ok = assert_true(player != null, "player script instantiates") and ok
	if player == null:
		return false
	ok = assert_true(not player.is_inside_tree(), "fresh player reads pre-tree") and ok
	ok = assert_eq(float(player.get("max_hp")), 100.0, "detached player max_hp defaults to full") and ok
	ok = assert_eq(float(player.call("get_hp")), 100.0, "detached proxy reads full, not dead-at-zero") and ok
	player.free()
	var orphan = load("res://player.gd").new()
	var stray := Node.new()
	stray.name = "Health"
	orphan.add_child(stray)
	orphan.set("health", stray)
	stray.free()
	ok = assert_true(not is_instance_valid(stray), "stray Health freed for invalid branch") and ok
	ok = assert_eq(float(orphan.call("get_hp")), 100.0, "freed-Health proxy still reads full") and ok
	orphan.free()
	var methodless = load("res://player.gd").new()
	var bare := Node.new()
	bare.name = "Health"
	methodless.add_child(bare)
	methodless.set("health", bare)
	ok = assert_eq(float(methodless.call("get_hp")), 100.0, "method-less Health proxy still reads full") and ok
	methodless.free()
	return ok


func test_player_proxy_hp_full_before_tree_entry() -> bool:
	var ok := true
	var packed := load("res://main.tscn") as PackedScene
	ok = assert_true(packed != null, "main scene loads as PackedScene") and ok
	if packed == null:
		return false
	var instance := packed.instantiate()
	ok = assert_true(not instance.is_inside_tree(), "instantiated main reads pre-tree") and ok
	var player := instance.get_node_or_null("Player")
	ok = assert_true(player != null, "main scene mounts Player") and ok
	var mounted := instance.get_node_or_null("Player/Health")
	ok = assert_true(mounted != null, "main scene mounts Health under Player") and ok
	if player == null or mounted == null:
		instance.queue_free()
		return false
	ok = assert_eq(float(player.call("get_hp")), float(mounted.get("max_hp")), "mounted pre-tree proxy reads full") and ok
	ok = assert_true(float(player.call("get_hp")) > 0.0, "mounted pre-tree proxy is not dead-at-zero") and ok
	instance.queue_free()
	return ok


func test_end_run_sanitizes_reason_to_single_token() -> bool:
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
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	ok = assert_eq(str(instance.call("_sanitize_run_reason", "game over")), "game_over", "space maps to underscore") and ok
	ok = assert_eq(str(instance.call("_sanitize_run_reason", "a=b")), "a_b", "equals maps to underscore") and ok
	var messy := str(instance.call("_sanitize_run_reason", "x\ny=z\tw game_over=false"))
	ok = assert_true(not messy.contains(" ") and not messy.contains("=") and not messy.contains("\n") and not messy.contains("\t"), "newline/tab reason collapses to single grep-safe token") and ok
	ok = assert_eq(str(instance.call("_sanitize_run_reason", "")), "unknown", "empty reason maps to unknown") and ok
	instance.call("end_run", "game over")
	await process_frame
	ok = assert_true(not bool(instance.call("is_run_active")), "run inactive after multi-token end_run") and ok
	ok = assert_true(bool(instance.call("is_game_over")), "is_game_over true after multi-token end_run") and ok
	var label := instance.get_node_or_null("StatusLabel") as Label
	ok = assert_true(label != null and label.text.contains("GAME_OVER"), "HUD shows GAME_OVER after multi-token end_run") and ok
	var source := FileAccess.get_file_as_string("res://main.gd")
	var end_idx := source.find("func end_run")
	ok = assert_true(end_idx >= 0, "main.gd defines end_run") and ok
	var end_block := ""
	if end_idx >= 0:
		var end_next := source.find("\nfunc ", end_idx + 1)
		if end_next < 0:
			end_block = source.substr(end_idx)
		else:
			end_block = source.substr(end_idx, end_next - end_idx)
	ok = assert_true(end_block.contains("_sanitize_run_reason"), "end_run sanitizes reason first") and ok
	ok = assert_true(end_block.contains("RUN_END=%s game_over=true ERRORS=0"), "sanitized branch keeps uniform token tail") and ok
	ok = assert_true(not end_block.contains('RUN_END=%s" % reason'), "end_run no longer interpolates raw reason") and ok
	ok = assert_true(not end_block.contains("[reason"), "end_run print interpolates safe token, never raw reason") and ok
	instance.queue_free()
	return ok

func test_end_run_hud_copy_varies_by_reason() -> bool:
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
	spawner.set("spawn_interval", 3600.0)
	await _clear_enemies()
	_release_move_actions()
	var label := instance.get_node_or_null("StatusLabel") as Label
	ok = assert_true(label != null, "main scene has StatusLabel") and ok
	if label == null:
		instance.queue_free()
		return false
	instance.call("end_run", "death")
	await process_frame
	ok = assert_true(label.text.contains("GAME_OVER death"), "death HUD shows GAME_OVER death") and ok
	ok = assert_true(label.text.contains("press R to restart"), "death HUD keeps restart hint") and ok
	ok = assert_eq(str(instance.call("get_run_reason")), "death", "getter returns death token") and ok
	instance.call("reset_run")
	await process_frame
	ok = assert_true(not label.text.contains("GAME_OVER"), "HUD clears GAME_OVER after reset") and ok
	ok = assert_eq(str(instance.call("get_run_reason")), "death", "reset restores death default") and ok
	instance.call("end_run", "quit")
	await process_frame
	ok = assert_true(label.text.contains("GAME_OVER quit"), "quit HUD shows GAME_OVER quit") and ok
	ok = assert_true(not label.text.contains("GAME_OVER death"), "quit HUD distinct from death copy") and ok
	ok = assert_eq(str(instance.call("get_run_reason")), "quit", "getter returns quit token") and ok
	instance.call("reset_run")
	await process_frame
	instance.call("end_run", "victory")
	await process_frame
	ok = assert_true(label.text.contains("GAME_OVER victory"), "victory HUD shows GAME_OVER victory") and ok
	ok = assert_eq(str(instance.call("get_run_reason")), "victory", "getter returns victory token") and ok
	instance.call("reset_run")
	await process_frame
	instance.call("end_run", "game over")
	await process_frame
	ok = assert_true(label.text.contains("GAME_OVER game_over"), "sanitized reason HUD shows GAME_OVER game_over") and ok
	ok = assert_eq(str(instance.call("get_run_reason")), "game_over", "getter returns sanitized token") and ok
	instance.queue_free()
	return ok
