extends Node2D

@export var radius: float = 40.0
@export var boost: float = 1.0
@export var angle_mix: float = 0.6
@export var color: Color = Color8(100, 100, 255, 190)
@export var separation_margin: float = 12.0
@export var velocity_smoothing: float = 0.2

var _prev_global_pos: Vector2 = Vector2.ZERO
var _bumper_vel: Vector2 = Vector2.ZERO

func _draw() -> void:
	# core disk and ring for visibility
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius + 3.0, 0, TAU, 48, Color8(30, 30, 30, 200), 3.0, true)

func _ready() -> void:
	_prev_global_pos = global_position

func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	var inst_vel: Vector2 = (global_position - _prev_global_pos) / delta
	_bumper_vel = _bumper_vel * (1.0 - velocity_smoothing) + inst_vel * velocity_smoothing
	_prev_global_pos = global_position

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
		var v_b: Vector2 = _bumper_vel
		var v_rel: Vector2 = v - v_b
		var v_rel_len: float = v_rel.length()
		var n: Vector2 = to_piece
		if n.length() < 0.0001:
			n = Vector2.RIGHT
		n = n.normalized()
		if v_rel.dot(n) > 0.0:
			return false
		var v_reflect_rel: Vector2 = v_rel - 2.0 * v_rel.dot(n) * n
		var v_blend_rel: Vector2 = v_rel * (1.0 - angle_mix) + v_reflect_rel * angle_mix
		var out_dir: Vector2 = v_blend_rel
		if out_dir.length() < 0.0001:
			out_dir = n
		else:
			out_dir = out_dir.normalized()
		var v_new: Vector2 = v_b + out_dir * v_rel_len * boost
		piece.set("velocity", v_new)
		piece.global_position = global_position + n * (radius + piece_radius + separation_margin)
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
		var v_b: Vector2 = _bumper_vel
		var v_rel: Vector2 = v - v_b
		var v_rel_len: float = v_rel.length()
		var n: Vector2 = to_fk
		if n.length() < 0.0001:
			n = Vector2.RIGHT
		n = n.normalized()
		if v_rel.dot(n) > 0.0:
			return false
		var v_reflect_rel: Vector2 = v_rel - 2.0 * v_rel.dot(n) * n
		var v_blend_rel: Vector2 = v_rel * (1.0 - angle_mix) + v_reflect_rel * angle_mix
		var out_dir: Vector2 = v_blend_rel
		if out_dir.length() < 0.0001:
			out_dir = n
		else:
			out_dir = out_dir.normalized()
		var v_new: Vector2 = v_b + out_dir * (v_rel_len * boost * 2.0)
		forklift.set("velocity", v_new)
		forklift.rotation = v_new.angle()
		forklift.global_position = global_position + n * (radius + forklift_radius + separation_margin)
		var am := get_node_or_null("/root/AudioManager")
		if am: am.call("click")
		return true
	return false

func _process(_delta: float) -> void:
	queue_redraw()
