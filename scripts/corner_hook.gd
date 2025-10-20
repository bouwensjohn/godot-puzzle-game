extends Node2D

signal triggered_signal

@export var arm_len: float = 100.0
@export var angle: float = PI
@export var color: Color = Color8(220, 180, 60)

var triggered: bool = false
@export var rotation_duration: float = 0.6
var rotating: bool = false
var angle_start: float = 0.0
var angle_target: float = 0.0
var rotate_progress: float = 0.0

func _ready() -> void:
	z_index = 60

func reset(a: float = PI) -> void:
	angle = a
	triggered = false
	rotating = false
	rotate_progress = 0.0
	angle_start = angle
	angle_target = angle
	queue_redraw()

func _draw() -> void:
	var a1 := angle - PI * 0.5
	var a2 := angle - PI
	var arm1_end := Vector2(arm_len, 0).rotated(a1)
	var arm2_end := Vector2(arm_len, 0).rotated(a2)
	draw_line(Vector2.ZERO, arm1_end, color, 6.0)
	draw_line(Vector2.ZERO, arm2_end, color, 6.0)
	draw_circle(Vector2.ZERO, 8.0, Color8(200,120,40))

func _process(delta: float) -> void:
	if rotating:
		rotate_progress = min(1.0, rotate_progress + delta / rotation_duration)
		var t: float = rotate_progress
		var ease_t: float = t * t * (3.0 - 2.0 * t)
		angle = lerp(angle_start, angle_target, ease_t)
		queue_redraw()
		if rotate_progress >= 1.0:
			rotating = false

func _dist_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ap: Vector2 = p - a
	var ab: Vector2 = b - a
	var ab_len2: float = ab.length_squared()
	if ab_len2 <= 0.0001:
		return ap.length()
	var t: float = clamp(ap.dot(ab) / ab_len2, 0.0, 1.0)
	var proj: Vector2 = a + ab * t
	return (p - proj).length()

func check_and_trigger(piece: Node2D) -> void:
	if triggered:
		return
	if piece == null:
		return
	if piece.get("held"):
		return
	var p: Vector2 = piece.global_position
	var r: float = float(piece.get("size")) * 0.5
	var a1: Vector2 = global_position
	var b1: Vector2 = global_position + Vector2(arm_len, 0).rotated(angle - PI * 0.5)
	var a2: Vector2 = global_position
	var b2: Vector2 = global_position + Vector2(arm_len, 0).rotated(angle - PI)
	var hit: bool = false
	var v_before: Vector2 = piece.get("velocity") as Vector2
	var threshold: float = r + 12.0
	var dist1: float = _dist_point_to_segment(p, a1, b1)
	if dist1 <= threshold:
		hit = true
		var v1: Vector2 = (b1 - a1).normalized()
		var n1: Vector2 = Vector2(-v1.y, v1.x).normalized()
		var v_ref: Vector2 = v_before - 2.0 * v_before.dot(n1) * n1
		piece.set("velocity", v_ref)
		var ap: Vector2 = p - a1
		var ab: Vector2 = b1 - a1
		var ab_len2: float = ab.length_squared()
		if ab_len2 < 0.0001:
			ab_len2 = 0.0001
		var t: float = clamp(ap.dot(ab) / ab_len2, 0.0, 1.0)
		var proj: Vector2 = a1 + ab * t
		var corr: Vector2 = (p - proj)
		var corr_n: Vector2 = (corr.normalized() if corr.length() > 0.0001 else n1)
		piece.global_position = proj + corr_n * (threshold + 0.5)
	else:
		var dist2: float = _dist_point_to_segment(p, a2, b2)
		if dist2 <= threshold:
			hit = true
			var v2: Vector2 = (b2 - a2).normalized()
			var n2: Vector2 = Vector2(-v2.y, v2.x).normalized()
			var v_ref2: Vector2 = v_before - 2.0 * v_before.dot(n2) * n2
			piece.set("velocity", v_ref2)
			var ap2: Vector2 = p - a2
			var ab2: Vector2 = b2 - a2
			var ab2_len2: float = ab2.length_squared()
			if ab2_len2 < 0.0001:
				ab2_len2 = 0.0001
			var t2: float = clamp(ap2.dot(ab2) / ab2_len2, 0.0, 1.0)
			var proj2: Vector2 = a2 + ab2 * t2
			var corr2: Vector2 = (p - proj2)
			var corr2_n: Vector2 = (corr2.normalized() if corr2.length() > 0.0001 else n2)
			piece.global_position = proj2 + corr2_n * (threshold + 0.5)
	if hit:
		triggered = true
		rotating = true
		angle_start = angle
		angle_target = angle + PI * 0.25
		rotate_progress = 0.0
		emit_signal("triggered_signal")
