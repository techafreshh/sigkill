extends Node2D
## Infinite terminal-grid ground. Redraws every frame with grid lines snapped
## to the active camera, so the plane looks endless as the player moves.

const THEME_PATH := "res://data/theme.tres"
const MAJOR_EVERY := 4

var theme: TerminalTheme


func _ready() -> void:
	theme = load(THEME_PATH) as TerminalTheme


func _process(_delta: float) -> void:
	queue_redraw()


func get_cell_size() -> float:
	if theme != null:
		return theme.grid_cell_size
	return 64.0


func _draw() -> void:
	if theme == null:
		theme = load(THEME_PATH) as TerminalTheme
	if theme == null:
		return
	var cell := theme.grid_cell_size
	if cell <= 0.0:
		return
	var viewport_size := get_viewport_rect().size
	var center := _camera_center()
	var top_left := center - viewport_size * 0.5
	var bottom_right := center + viewport_size * 0.5
	var x := floorf(top_left.x / cell) * cell
	while x <= bottom_right.x:
		var major := int(roundf(x / cell)) % MAJOR_EVERY == 0
		var col := theme.grid_major_color if major else theme.grid_color
		draw_line(Vector2(x, top_left.y), Vector2(x, bottom_right.y), col, 2.0 if major else 1.0)
		x += cell
	var y := floorf(top_left.y / cell) * cell
	while y <= bottom_right.y:
		var major_y := int(roundf(y / cell)) % MAJOR_EVERY == 0
		var col_y := theme.grid_major_color if major_y else theme.grid_color
		draw_line(Vector2(top_left.x, y), Vector2(bottom_right.x, y), col_y, 2.0 if major_y else 1.0)
		y += cell


func _camera_center() -> Vector2:
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		return cam.get_screen_center_position()
	return global_position
