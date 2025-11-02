extends Node2D

@export var size: float = 16.0
var velocity: Vector2 = Vector2.ZERO
var held: bool = false

func update_free(delta: float) -> void:
	# drift with slight damping (same as piece)
	velocity *= 0.998
	position += velocity * delta

func _draw() -> void:
	# yellow pill as a circle with a thin outline
	draw_circle(Vector2.ZERO, size * 0.5, Color8(255, 226, 58))
	draw_arc(Vector2.ZERO, size * 0.5 + 2.0, 0, TAU, 48, Color8(30, 30, 30), 2.0)
