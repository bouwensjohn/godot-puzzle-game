extends Node2D

@export var size: float = 16.0
var velocity: Vector2 = Vector2.ZERO
var thrusting := false

const ROT_SPEED := 3.4 # rad/s
const ACC := 220.0

func update_move(delta: float) -> void:
	# rotation
	var rot_input := 0.0
	if Input.is_action_pressed("ui_left"): rot_input -= 1.0
	if Input.is_action_pressed("ui_right"): rot_input += 1.0
	rotation += rot_input * ROT_SPEED * delta
	# thrust
	thrusting = Input.is_action_pressed("ui_up")
	if thrusting:
		velocity += Vector2.RIGHT.rotated(rotation) * ACC * delta
	# damping and integrate
	velocity *= 0.995
	position += velocity * delta
	# audio hook
	var am := get_node_or_null("/root/AudioManager")
	if am: am.thrust(thrusting)

func nose_global_position() -> Vector2:
	# Forklift nose is at the tip of the forks (front of the vehicle)
	return global_position + Vector2( 44.0, 0.0 ).rotated(global_rotation)

func _draw() -> void:
	# grab radius visualization
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var grab_radius := GameConfig.GRAB_RADIUS
	var nose_offset := 44.0  # Forklift forks tip position
	draw_arc(Vector2(nose_offset, 0), grab_radius, 0, TAU, 64, Color(0.49,1,0.77,0.35), 1.0, true)
	
	# forklift main body (U-shaped rear section)
	# Dark background fill inside U-shape
	var inner_fill := PackedVector2Array([
		Vector2(-8, -10), Vector2(-8, 10), Vector2(16, 10), Vector2(16, -10)
	])
	draw_colored_polygon(inner_fill, Color8(128, 128, 128))  # Gray fill to match forks
	
	# Outer U-shape
	var outer_body := PackedVector2Array([
		Vector2(-24, -16), Vector2(-24, 16), Vector2(16, 16), Vector2(16, 10),
		Vector2(-8, 10), Vector2(-8, -10), Vector2(16, -10), Vector2(16, -16)
	])
	draw_colored_polygon(outer_body, Color8(255, 140, 0))  # Orange body
	draw_polyline(outer_body, Color8(139, 69, 19), 2.0)
	draw_line(outer_body[-1], outer_body[0], Color8(139, 69, 19), 2.0)
	
	# forklift cab (driver section)
	var cab_pts := PackedVector2Array([
		Vector2(16, -12), Vector2(16, 12), Vector2(28, 12), Vector2(28, -12)
	])
	draw_colored_polygon(cab_pts, Color8(200, 100, 0))  # Darker orange cab
	draw_polyline(cab_pts, Color8(139, 69, 19), 2.0)
	draw_line(cab_pts[-1], cab_pts[0], Color8(139, 69, 19), 2.0)
	
	# forklift forks (front) - 4 pixels wide each
	draw_rect(Rect2(Vector2(28, -10), Vector2(16, 4)), Color8(128, 128, 128))  # Left fork
	draw_rect(Rect2(Vector2(28, 6), Vector2(16, 4)), Color8(128, 128, 128))   # Right fork
	
	# wheels (top-down view as rectangles) - bigger rear wheels
	draw_rect(Rect2(Vector2(-26, -22), Vector2(12, 8)), Color8(64, 64, 64))  # Rear left wheel
	draw_rect(Rect2(Vector2(-26, 14), Vector2(12, 8)), Color8(64, 64, 64))   # Rear right wheel
	draw_rect(Rect2(Vector2(14, -16), Vector2(8, 6)), Color8(64, 64, 64))   # Front left wheel
	draw_rect(Rect2(Vector2(14, 10), Vector2(8, 6)), Color8(64, 64, 64))    # Front right wheel
	
	# exhaust smoke when moving
	if thrusting:
		draw_line(Vector2(-24, -4), Vector2(-40 - randi()%8, -4), Color8(128, 128, 128), 4.0)

func _process(_delta: float) -> void:
	queue_redraw()
