extends CharacterBody2D

const TERMINAL_THEME := preload("res://data/theme.tres")

@export var speed := 220.0
@export var acceleration := 1200.0
@export var friction := 1400.0
@export var shove_strength := 2.0
@export var shove_max_speed := 320.0
@export var shove_acceleration := 6000.0
@export var shove_radius := 128.0
@export var contact_damage := 10.0
@export var contact_radius := 26.0
## Full-HP fallback for the get_hp() proxy when Health is missing/invalid.
@export var max_hp := 100.0

var theme: TerminalTheme

@onready var health: Node = get_node_or_null("Health")
var _wired_health: Node


func _wire_health() -> void:
	var current: Node = get_node_or_null("Health")
	if _wired_health != current or health != current:
		health = current
		_wired_health = health


func _refresh_health_wiring() -> void:
	_wire_health()


func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	theme = TERMINAL_THEME as TerminalTheme
	_wire_health()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_CHILD_ORDER_CHANGED:
		_wire_health()


func _is_run_active() -> bool:
	var coordinator := get_parent()
	if coordinator == null or not is_instance_valid(coordinator):
		return true
	if coordinator.has_method("is_run_active"):
		return bool(coordinator.call("is_run_active"))
	if "run_active" in coordinator:
		return bool(coordinator.get("run_active"))
	return true


func _physics_process(delta: float) -> void:
	if not _is_run_active():
		velocity = Vector2.ZERO
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target := input * speed
	var rate := acceleration if input.length() > 0.0 else friction
	velocity = velocity.move_toward(target, rate * delta)
	var push := velocity.length()
	move_and_slide()
	var enemies := get_tree().get_nodes_in_group("enemies")
	_shove_crowd(push, delta, enemies)
	_check_contact_damage(enemies)


## Crowd shove: a contact-only push cannot move a multi-layer pile, because
## kinematic bodies transmit no force through a contact chain and the outer
## layers keep ramming inward. Pushing every nearby enemy at once translates
## the whole pile as a loose mass, so the player barges through instead of
## wedging. Gated on push, so an idle player stays a hard wall.
func _shove_crowd(push: float, delta: float, enemies: Array) -> void:
	if push <= 1.0:
		return
	var shove_vel := minf(push * shove_strength, shove_max_speed)
	for node in enemies:
		if node != self and node is CharacterBody2D:
			var enemy := node as CharacterBody2D
			var offset: Vector2 = enemy.global_position - global_position
			var dist := offset.length()
			if dist < 0.01 or dist > shove_radius:
				continue
			enemy.velocity = enemy.velocity.move_toward(offset.normalized() * shove_vel, shove_acceleration * delta)


## Contact damage: per-tick enemies-group distance check mirroring _shove_crowd.
## Every toucher inside contact_radius contributes contact_damage to one summed
## Health tick (contact_damage * toucher count); the Health node's i-frame
## timer gates whole aggregate ticks, not individual touchers. Exact
## overlap (dist < 0.01) still counts as contact: unlike the shove there is
## no direction to normalize, so nothing to guard against.
func _check_contact_damage(enemies: Array) -> void:
	_wire_health()
	if health == null or not is_instance_valid(health):
		return
	if not health.has_method("is_dead") or not health.has_method("get_hp") or not health.has_method("take_damage"):
		return
	if bool(health.call("is_dead")):
		return
	var touchers := 0
	for node in enemies:
		if node == self or not (node is Node2D):
			continue
		var enemy := node as Node2D
		if not is_instance_valid(enemy):
			continue
		var dist: float = enemy.global_position.distance_to(global_position)
		if dist > contact_radius:
			continue
		touchers += 1
	if touchers == 0:
		return
	var total: float = contact_damage * touchers
	var before: float = float(health.call("get_hp"))
	health.call("take_damage", total)
	var after: float = float(health.call("get_hp"))
	if after < before:
		print("PLAYER_HIT hp=%d damage=%d" % [int(after), int(total)])


func get_hp() -> float:
	var live: Node = get_node_or_null("Health")
	if live != null and is_instance_valid(live) and live.has_method("get_hp"):
		return float(live.call("get_hp"))
	if health != null and is_instance_valid(health) and health.has_method("get_hp"):
		return float(health.call("get_hp"))
	return max_hp


func take_damage(amount: float) -> void:
	_wire_health()
	if health != null and is_instance_valid(health) and health.has_method("take_damage"):
		health.call("take_damage", amount)


func restore_full_health() -> void:
	_wire_health()
	if health != null and is_instance_valid(health) and health.has_method("restore_full_health"):
		health.call("restore_full_health")


func _draw() -> void:
	var col := Color(0.3, 1.0, 0.55, 1.0)
	if theme != null:
		col = theme.player_color
	draw_rect(Rect2(Vector2(-14, -10), Vector2(28, 20)), col)
