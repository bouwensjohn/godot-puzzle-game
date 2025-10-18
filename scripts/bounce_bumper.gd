extends Node2D

@export var radius: float = 40.0
@export var boost: float = 2.0
@export var color: Color = Color8(255, 90, 90, 220)

func _draw() -> void:
	# core disk and ring for visibility
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius + 3.0, 0, TAU, 48, Color8(30, 30, 30, 200), 3.0, true)

func bounce_piece(piece: Node2D) -> bool:
	if piece == null:
		return false
	if piece.get("held"):
		return false
	var ppos: Vector2 = piece.global_position
	var to_piece: Vector2 = ppos - global_position
	var piece_radius: float = float(piece.get("size")) * 0.5
	if to_piece.length() <= (radius + piece_radius):
		var v: Vector2 = piece.get("velocity")
		var n: Vector2 = to_piece
		if n.length() < 0.0001:
			n = Vector2.RIGHT
		n = n.normalized()
		var v_reflect: Vector2 = v - 2.0 * v.dot(n) * n
		piece.set("velocity", v_reflect * boost)
		piece.global_position = global_position + n * (radius + piece_radius + 1.0)
		var am := get_node_or_null("/root/AudioManager")
		if am: am.call("click")
		return true
	return false

func _process(_delta: float) -> void:
	queue_redraw()
