extends Area2D
## Straight-line bolt projectile. Built purely in code (no .tscn): flies along
## a snapshot direction, frees itself on the first enemy contact
## (non-piercing) and self-frees past its lifetime so misses never accumulate.

@export var speed := 700.0
@export var damage := 1
@export var max_range := 700.0

var direction := Vector2.RIGHT

var _travelled := 0.0
var _life := 0.0
var _max_life := 1.5


func launch(from: Vector2, target_pos: Vector2, p_speed: float, p_damage: int, p_range: float) -> void:
	var offset := target_pos - from
	if offset.length() < 0.01:
		direction = Vector2.RIGHT
	else:
		direction = offset.normalized()
	speed = p_speed
	damage = p_damage
	max_range = p_range
	_travelled = 0.0
	_life = 0.0
	if speed > 0.0:
		_max_life = max_range / speed + 0.5
	else:
		_max_life = 0.5
	rotation = direction.angle()
	if is_inside_tree():
		global_position = from
	else:
		position = from
	queue_redraw()


func _ready() -> void:
	add_to_group("projectiles")
	collision_layer = 4
	collision_mask = 1
	monitoring = true
	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape_node.shape = circle
	add_child(shape_node)
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_travelled += speed * delta
	_life += delta
	if _travelled >= max_range or _life >= _max_life:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not is_instance_valid(body):
		return
	if not body.is_in_group("enemies"):
		return
	print("BOLT_HIT pierce_count==0 damage=%d" % damage)
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()


func _draw() -> void:
	draw_rect(Rect2(Vector2(-4, -1.5), Vector2(8, 3)), Color(0.3, 1.0, 0.55, 1.0))
