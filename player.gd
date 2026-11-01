extends CharacterBody2D

const TERMINAL_THEME := preload("res://data/theme.tres")

@export var speed := 220.0
@export var acceleration := 1200.0
@export var friction := 1400.0

var theme: TerminalTheme


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	theme = TERMINAL_THEME as TerminalTheme
	queue_redraw()


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target := input * speed
	var rate := acceleration if input.length() > 0.0 else friction
	velocity = velocity.move_toward(target, rate * delta)
	move_and_slide()


func _draw() -> void:
	var col := Color(0.3, 1.0, 0.55, 1.0)
	if theme != null:
		col = theme.player_color
	draw_rect(Rect2(Vector2(-14, -10), Vector2(28, 20)), col)
