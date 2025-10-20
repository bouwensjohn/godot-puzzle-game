extends StaticBody2D

var _size: Vector2 = Vector2(40, 120)
@export var size: Vector2:
	set = set_size, get = get_size
@export var color: Color = Color8(80, 160, 255, 230)
@export var open_offset: float = 200.0
@export var open_duration: float = 1.2
@export var spring_anchor: Vector2 = Vector2.ZERO

var closed_pos: Vector2
var open_progress: float = 0.0
var opening: bool = false

func _ready() -> void:
	add_to_group("walls")
	z_index = 50
	_apply_size_to_collision()
	queue_redraw()

func _apply_size_to_collision() -> void:
	var cs := get_node_or_null("Collision")
	if cs and cs is CollisionShape2D and cs.shape is RectangleShape2D:
		(cs.shape as RectangleShape2D).size = _size

func set_size(v: Vector2) -> void:
	_size = v
	_apply_size_to_collision()
	queue_redraw()

func get_size() -> Vector2:
	return _size

func reset_to_closed(pos: Vector2) -> void:
	closed_pos = pos
	global_position = pos
	open_progress = 0.0
	opening = false
	queue_redraw()

func open() -> void:
	opening = true

func update_open(delta: float) -> void:
	if opening and open_progress < 1.0:
		open_progress = min(1.0, open_progress + delta / open_duration)
		global_position = closed_pos + Vector2(open_offset * open_progress, 0.0)
		queue_redraw()

func _draw() -> void:
	var s := _size
	draw_rect(Rect2(Vector2(-s.x * 0.5, -s.y * 0.5), s), color)
	draw_rect(Rect2(Vector2(-s.x * 0.5, -s.y * 0.5), s), Color8(20, 40, 80), false, 3.0)
	if spring_anchor != Vector2.ZERO:
		var s_from_local := Vector2(s.x * 0.5, 0)
		var s_to_local := to_local(spring_anchor)
		draw_line(s_from_local, s_to_local, Color8(120, 200, 255, 200), 6.0)
