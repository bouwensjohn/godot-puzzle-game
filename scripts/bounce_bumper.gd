extends Node2D

@export var radius: float = 40.0
@export var boost: float = 1.0
@export var angle_mix: float = 0.6
@export var color: Color = Color8(100, 100, 255, 190)

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
		var v_len: float = v.length()
		var n: Vector2 = to_piece
		if n.length() < 0.0001:
			n = Vector2.RIGHT
		n = n.normalized()
		var v_reflect: Vector2 = v - 2.0 * v.dot(n) * n
		var v_blend: Vector2 = v * (1.0 - angle_mix) + v_reflect * angle_mix
		var out_dir: Vector2 = v_blend
		if out_dir.length() < 0.0001:
			out_dir = n
		else:
			out_dir = out_dir.normalized()
		piece.set("velocity", out_dir * v_len * boost)
		piece.global_position = global_position + n * (radius + piece_radius + 1.0)
		var am := get_node_or_null("/root/AudioManager")
		if am: am.call("click")
		return true
	return false

func bounce_forklift(forklift: Node2D) -> bool:
	if forklift == null:
		return false
	var fpos: Vector2 = forklift.global_position
	var to_fk: Vector2 = fpos - global_position
	var forklift_radius: float = 30.0
	if to_fk.length() <= (radius + forklift_radius):
		var v: Vector2 = forklift.get("velocity")
		var v_len: float = v.length()
		var n: Vector2 = to_fk
		if n.length() < 0.0001:
			n = Vector2.RIGHT
		n = n.normalized()
		var v_reflect: Vector2 = v - 2.0 * v.dot(n) * n
		var v_blend: Vector2 = v * (1.0 - angle_mix) + v_reflect * angle_mix
		var out_dir: Vector2 = v_blend
		if out_dir.length() < 0.0001:
			out_dir = n
		else:
			out_dir = out_dir.normalized()
		forklift.set("velocity", out_dir * v_len * boost * 2.0)
		forklift.global_position = global_position + n * (radius + forklift_radius + 1.0)
		var am := get_node_or_null("/root/AudioManager")
		if am: am.call("click")
		return true
	return false

func _process(_delta: float) -> void:
	queue_redraw()
