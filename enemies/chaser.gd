extends CharacterBody2D

const TERMINAL_THEME := preload("res://data/theme.tres")

@export var speed := 140.0
@export var acceleration := 600.0
@export var target_path: NodePath

var target: Node2D
var theme: TerminalTheme


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("enemies")
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


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		_resolve_target()
	if not is_instance_valid(target):
		move_and_slide()
		return
	var direction: Vector2 = target.global_position - global_position
	var desired := Vector2.ZERO
	if direction.length() > 1.0:
		desired = direction.normalized() * speed
	velocity = velocity.move_toward(desired, acceleration * delta)
	move_and_slide()


func _draw() -> void:
	var col := Color(1.0, 0.25, 0.35, 1.0)
	draw_rect(Rect2(Vector2(-12, -8), Vector2(24, 16)), col)
	if theme != null and theme.font != null and theme.glyphs != null and (theme.glyphs as PackedStringArray).size() > 0:
		var glyph: String = (theme.glyphs as PackedStringArray)[0]
		draw_string(theme.font, Vector2(-5, 5), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12.0, Color(0.05, 0.0, 0.0, 1.0))
