# Headless test entrypoint. Run with:
#   godot --headless --path . --script res://tests/test_runner.gd
# Exits 0 when every test passes, 1 otherwise, so CI can gate on the exit code.
extends SceneTree

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
		"test_sanity_math",
	]
	for t: String in tests:
		var outcome: Variant = await call(t)
		if outcome == true:
			passed += 1
			print("PASS %s" % t)
		else:
			failed += 1
			push_error("FAIL %s: did not finish (runtime error?)" % t)


func test_input_map_has_move_actions() -> bool:
	var ok := true
	for action: String in ["move_up", "move_down", "move_left", "move_right"]:
		if not InputMap.has_action(action):
			push_error("FAIL test_input_map_has_move_actions: missing action " + action)
			ok = false
		elif InputMap.action_get_events(action).is_empty():
			push_error("FAIL test_input_map_has_move_actions: action has no events: " + action)
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


func test_sanity_math() -> bool:
	var ok := true
	ok = assert_eq(2 + 2, 4, "sanity math") and ok
	ok = assert_true(true, "sanity true") and ok
	return ok
