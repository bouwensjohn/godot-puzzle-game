extends Node2D

@export var size: float = 36.0
var velocity: Vector2 = Vector2.ZERO
var held: bool = false

func update_free(delta: float) -> void:
	# drift with slight damping
	velocity *= 0.998
	position += velocity * delta

func _draw() -> void:
	var s: float = size
	draw_rect(Rect2(Vector2(-s/2, -s/2), Vector2(s, s)), Color8(255,184,107))
	draw_rect(Rect2(Vector2(-s/2, -s/2), Vector2(s, s)), Color8(11,19,38), false, 2.0)
	draw_arc(Vector2.ZERO, s*0.2, 0, TAU, 32, Color8(11,19,38), 2.0)

func _process(_delta: float) -> void:
	queue_redraw()
