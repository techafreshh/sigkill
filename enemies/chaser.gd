extends CharacterBody2D

const TERMINAL_THEME := preload("res://data/theme.tres")

@export var speed := 140.0
@export var acceleration := 600.0
@export var standoff_distance := 28.0
@export var target_path: NodePath
## Tunable base HP until the data-table lap owns balance.
@export var max_health := 3.0

signal died
signal health_changed(current: float, maximum: float)

## Mirrors the max_health default above; _init and _ready re-assert from max_health.
var health: float = 3.0
var _dead := false
var target: Node2D
var theme: TerminalTheme


func _init() -> void:
	health = max_health


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("enemies")
	health = max_health
	theme = TERMINAL_THEME as TerminalTheme
	if target_path != null and not target_path.is_empty():
		target = get_node_or_null(target_path) as Node2D
	queue_redraw()


func _resolve_target() -> void:
	if is_instance_valid(target):
		return
	if target_path != null and not target_path.is_empty():
		target = get_node_or_null(target_path) as Node2D
	if is_instance_valid(target):
		return
	if get_tree() != null:
		target = get_tree().get_first_node_in_group("player") as Node2D


func is_dead() -> bool:
	return _dead or health <= 0.0


func get_health() -> float:
	return health


func take_damage(amount: float) -> void:
	if _dead or is_queued_for_deletion():
		return
	if amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_dead = true
		died.emit()
		queue_free()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		_resolve_target()
	if not is_instance_valid(target):
		move_and_slide()
		return
	var direction: Vector2 = target.global_position - global_position
	var dist := direction.length()
	var desired := Vector2.ZERO
	if dist > 1.0:
		var approach := 1.0
		if dist < standoff_distance:
			approach = dist / standoff_distance
		desired = direction.normalized() * speed * approach
	velocity = velocity.move_toward(desired, acceleration * delta)
	move_and_slide()


func _draw() -> void:
	var col := Color(1.0, 0.25, 0.35, 1.0)
	draw_rect(Rect2(Vector2(-12, -8), Vector2(24, 16)), col)
	if theme != null and theme.font != null and theme.glyphs != null and (theme.glyphs as PackedStringArray).size() > 0:
		var glyph: String = (theme.glyphs as PackedStringArray)[0]
		draw_string(theme.font, Vector2(-5, 5), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12.0, Color(0.05, 0.0, 0.0, 1.0))
