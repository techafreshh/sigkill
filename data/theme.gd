extends Resource
class_name TerminalTheme
## Swappable terminal theme: phosphor-green-on-black palette, monospace font,
## grid cell size, and glyph map shared by player, ground, and UI.

@export var player_color: Color = Color(0.3, 1.0, 0.55, 1.0)
@export var grid_color: Color = Color(0.09, 0.28, 0.16, 0.55)
@export var grid_major_color: Color = Color(0.14, 0.45, 0.25, 0.85)
@export var background_color: Color = Color(0.02, 0.05, 0.03, 1.0)
@export var font: Font
@export var grid_cell_size: float = 64.0
@export var glyphs: PackedStringArray = PackedStringArray(["@", "#", "$", "%", "&", "*", "+", ":", "."])
