extends StaticBody2D

var _size: Vector2 = Vector2(40, 640)
@export var size: Vector2:
	set = set_size, get = get_size

@export var color: Color = Color(0.6, 0.4, 0.2, 0.3)

func _ready() -> void:
	add_to_group("walls")
	_apply_size_to_collision()

func _apply_size_to_collision() -> void:
	var cs := get_node_or_null("WallCollision")
	if cs and cs is CollisionShape2D and cs.shape is RectangleShape2D:
		(cs.shape as RectangleShape2D).size = _size

func set_size(v: Vector2) -> void:
	_size = v
	_apply_size_to_collision()
	var vis := get_node_or_null("WallVisual")
	if vis:
		(vis as Node2D).queue_redraw()

func get_size() -> Vector2:
	return _size
