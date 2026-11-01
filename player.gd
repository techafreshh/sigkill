extends CharacterBody2D

const TERMINAL_THEME := preload("res://data/theme.tres")

@export var speed := 220.0
@export var acceleration := 1200.0
@export var friction := 1400.0
@export var shove_strength := 2.0
@export var shove_max_speed := 320.0
@export var shove_acceleration := 6000.0
@export var shove_radius := 128.0

var theme: TerminalTheme


func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	theme = TERMINAL_THEME as TerminalTheme
	queue_redraw()


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target := input * speed
	var rate := acceleration if input.length() > 0.0 else friction
	velocity = velocity.move_toward(target, rate * delta)
	var push := velocity.length()
	move_and_slide()
	_shove_crowd(push, delta)


## Crowd shove: a contact-only push cannot move a multi-layer pile, because
## kinematic bodies transmit no force through a contact chain and the outer
## layers keep ramming inward. Pushing every nearby enemy at once translates
## the whole pile as a loose mass, so the player barges through instead of
## wedging. Gated on push, so an idle player stays a hard wall.
func _shove_crowd(push: float, delta: float) -> void:
	if push <= 1.0:
		return
	var shove_vel := minf(push * shove_strength, shove_max_speed)
	for node in get_tree().get_nodes_in_group("enemies"):
		if node != self and node is CharacterBody2D:
			var enemy := node as CharacterBody2D
			var offset: Vector2 = enemy.global_position - global_position
			var dist := offset.length()
			if dist < 0.01 or dist > shove_radius:
				continue
			enemy.velocity = enemy.velocity.move_toward(offset.normalized() * shove_vel, shove_acceleration * delta)


func _draw() -> void:
	var col := Color(0.3, 1.0, 0.55, 1.0)
	if theme != null:
		col = theme.player_color
	draw_rect(Rect2(Vector2(-14, -10), Vector2(28, 20)), col)
