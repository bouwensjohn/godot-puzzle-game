extends Node2D

@export var size: float = 16.0
var velocity: Vector2 = Vector2.ZERO
var thrusting := false
var is_skidding := false
var skid_intensity := 0.0
@export var dust_lag_seconds := 0.05
var _trail_time := 0.0
var _trail_hist := []

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
	
	# Calculate skidding for visual effects only
	calculate_skidding()
	
	# Apply angular drag based on movement direction vs forklift orientation
	apply_angular_drag()
	
	# integrate
	position += velocity * delta
	_trail_time += delta
	_trail_hist.push_back({"t": _trail_time, "p": global_position, "r": global_rotation})
	while _trail_hist.size() > 0 and (_trail_time - (_trail_hist[0]["t"] as float)) > 2.5:
		_trail_hist.pop_front()
	
	# audio hook
	var am := get_node_or_null("/root/AudioManager")
	if am: am.thrust(thrusting)

func apply_angular_drag() -> void:
	if velocity.length() < 10.0:  # Skip drag for very slow movement
		return
	
	var forward_dir := Vector2.RIGHT.rotated(rotation)
	var movement_dir := velocity.normalized()
	
	# Calculate angle between forklift orientation and movement direction
	var angle_diff := forward_dir.angle_to(movement_dir)
	
	# Convert angle to 0-1 range where 0 = aligned, 1 = perpendicular
	var perpendicular_factor: float = abs(sin(angle_diff))
	
	# Apply drag proportional to how perpendicular the movement is
	var base_drag: float = 0.995  # Normal drag when moving forward/backward (includes general damping)
	var max_drag: float = 0.975   # Maximum drag when moving sideways (angular + general)
	var drag_factor: float = lerp(base_drag, max_drag, perpendicular_factor)
	
	velocity *= drag_factor

func calculate_skidding() -> void:
	var speed := velocity.length()
	var forward_dir := Vector2.RIGHT.rotated(rotation)
	var lateral_velocity := velocity - forward_dir * velocity.dot(forward_dir)
	var lateral_speed := lateral_velocity.length()
	
	# Determine if we're skidding based on lateral movement
	is_skidding = lateral_speed > 50.0 and speed > 20.0
	skid_intensity = clamp(lateral_speed / 100.0, 0.2, 1.0)

func nose_global_position() -> Vector2:
	# Forklift nose is at the tip of the forks (front of the vehicle)
	return global_position + Vector2( 44.0, 0.0 ).rotated(global_rotation)

func _draw() -> void:
	# grab radius visualization
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var grab_radius := GameConfig.GRAB_RADIUS
	var nose_offset := 44.0  # Forklift forks tip position
	# draw_arc(Vector2(nose_offset, 0), grab_radius, 0, TAU, 64, Color(0.49,1,0.77,0.35), 1.0, true)
	
	# Calculate movement vectors for skid marks (drawn first, behind forklift)
	var speed := velocity.length()
	var forward_dir := Vector2.RIGHT.rotated(rotation)
	var lateral_velocity := velocity - forward_dir * velocity.dot(forward_dir)
	var lateral_speed := lateral_velocity.length()
	
	# skid marks when skidding - draw FIRST so they appear behind the forklift
	if is_skidding:
		var tp := _trail_pose_ago(dust_lag_seconds)
		var local_pos := to_local(tp["p"])
		var local_rot := (tp["r"] as float) - global_rotation
		draw_set_transform(local_pos, local_rot, Vector2.ONE)
		var skid_alpha := int(max(skid_intensity, 0.5) * 255)  # More visible
		var skid_color := Color8(255, 255, 255, skid_alpha)  # Darker gray color
		# Draw skid marks from rear wheels following lateral velocity direction
		var rear_left_center := Vector2(-20, -18)
		var rear_right_center := Vector2(-20, 18)
		# Transform lateral velocity to local coordinates and invert direction
		var local_lateral_direction := -lateral_velocity.rotated(-rotation).normalized()
		
		# Create multiple shorter, scattered skid marks for sprinkled effect
		for i in range(8):  # 8 main marks per wheel
			var offset := Vector2(randf_range(-9, 9), randf_range(-8, 8))  # Random scatter
			var skid_length := randf_range(8, 10)  # Shorter marks
			var skid_direction := local_lateral_direction * skid_length
			# Left wheel marks
			draw_line(rear_left_center + offset, rear_left_center + offset + skid_direction, skid_color, 3.0)
			# Right wheel marks  
			draw_line(rear_right_center + offset, rear_right_center + offset + skid_direction, skid_color, 3.0)
		
		# Add extra small sprinkles around the main marks
		for i in range(10):  # Fewer sprinkles for more compact coverage
			var sprinkle_offset := Vector2(randf_range(-15, 15), randf_range(-15, 15))  # Compact scatter
			var sprinkle_length := randf_range(8, 20)  # Shorter marks
			var sprinkle_direction := local_lateral_direction * sprinkle_length
			var sprinkle_alpha := int(skid_alpha * randf_range(0.5, 1.0))  # More visible sprinkles
			var sprinkle_color := Color8(16, 96, 16, sprinkle_alpha)
			var line_thickness := randf_range(1.0, 2.5)  # Slightly thinner
			# Left wheel sprinkles
			draw_line(rear_left_center + sprinkle_offset, rear_left_center + sprinkle_offset + sprinkle_direction, sprinkle_color, line_thickness)
			# Right wheel sprinkles
			draw_line(rear_right_center + sprinkle_offset, rear_right_center + sprinkle_offset + sprinkle_direction, sprinkle_color, line_thickness)
		
		# Add some perpendicular dust marks for extra width
		for i in range(20):  # Additional perpendicular marks
			var dust_offset := Vector2(randf_range(-50, 50), randf_range(-30, 30))
			var perpendicular_dir := Vector2(-local_lateral_direction.y, local_lateral_direction.x)  # 90 degrees rotated
			var dust_direction := perpendicular_dir * randf_range(8, 20)
			var dust_alpha := int(skid_alpha * randf_range(0.6, 1.0))  # More visible dust
			var dust_color := Color8(64, 128, 64, dust_alpha)
			# Left wheel dust
			draw_line(rear_left_center + dust_offset, rear_left_center + dust_offset + dust_direction, dust_color, 2.0)
			# Right wheel dust
			draw_line(rear_right_center + dust_offset, rear_right_center + dust_offset + dust_direction, dust_color, 2.0)
		
		# Add skid marks for front wheels too
		var front_left_center := Vector2(18, -13)
		var front_right_center := Vector2(18, 13)
		
		# Front wheel main marks
		for i in range(6):  # Fewer marks for front wheels
			var offset := Vector2(randf_range(-6, 6), randf_range(-5, 5))  # Random scatter
			var skid_length := randf_range(6, 8)  # Shorter marks for front
			var skid_direction := local_lateral_direction * skid_length
			# Left front wheel marks
			draw_line(front_left_center + offset, front_left_center + offset + skid_direction, skid_color, 2.5)
			# Right front wheel marks  
			draw_line(front_right_center + offset, front_right_center + offset + skid_direction, skid_color, 2.5)
		
		# Front wheel sprinkles
		for i in range(8):  # Fewer sprinkles for front wheels
			var sprinkle_offset := Vector2(randf_range(-12, 12), randf_range(-12, 12))  # Compact scatter
			var sprinkle_length := randf_range(6, 15)  # Shorter marks
			var sprinkle_direction := local_lateral_direction * sprinkle_length
			var sprinkle_alpha := int(skid_alpha * randf_range(0.3, 1.0))  # More visible sprinkles
			var sprinkle_color := Color8(16, 96, 16, sprinkle_alpha)
			var line_thickness := randf_range(1.0, 2.0)  # Slightly thinner
			# Left front wheel sprinkles
			draw_line(front_left_center + sprinkle_offset, front_left_center + sprinkle_offset + sprinkle_direction, sprinkle_color, line_thickness)
			# Right front wheel sprinkles
			draw_line(front_right_center + sprinkle_offset, front_right_center + sprinkle_offset + sprinkle_direction, sprinkle_color, line_thickness)
		
		# Front wheel perpendicular dust marks
		for i in range(15):  # Fewer dust marks for front wheels
			var dust_offset := Vector2(randf_range(-40, 40), randf_range(-25, 25))
			var perpendicular_dir := Vector2(-local_lateral_direction.y, local_lateral_direction.x)  # 90 degrees rotated
			var dust_direction := perpendicular_dir * randf_range(6, 15)
			var dust_alpha := int(skid_alpha * randf_range(0.2, 1.0))  # More visible dust
			var dust_color := Color8(64, 128, 64, dust_alpha)
			# Left front wheel dust
			draw_line(front_left_center + dust_offset, front_left_center + dust_offset + dust_direction, dust_color, 0.8)
			# Right front wheel dust
			draw_line(front_right_center + dust_offset, front_right_center + dust_offset + dust_direction, dust_color, 0.8)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
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
	
	
	# Debug text - using ThemeDB for Godot 4.x
	var font = ThemeDB.fallback_font
	#draw_string(font, Vector2(-50, -40), "Speed: %.1f" % speed, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	#draw_string(font, Vector2(-50, -25), "Lateral: %.1f" % lateral_speed, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	#draw_string(font, Vector2(-50, -10), "Skidding: %s" % str(is_skidding), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	#draw_string(font, Vector2(-50, 5), "Skid Intensity: %.2f" % skid_intensity, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

func _process(_delta: float) -> void:
	queue_redraw()

func _trail_pose_ago(seconds_ago: float) -> Dictionary:
	var target_t := _trail_time - seconds_ago
	if _trail_hist.size() == 0:
		return {"p": global_position, "r": global_rotation}
	var prev: Dictionary = _trail_hist[0]
	for i in range(1, _trail_hist.size()):
		var cur: Dictionary = _trail_hist[i]
		if (cur["t"] as float) >= target_t:
			var t0: float = prev["t"]
			var t1: float = cur["t"]
			var p0: Vector2 = prev["p"]
			var p1: Vector2 = cur["p"]
			var r0: float = prev["r"]
			var r1: float = cur["r"]
			if t1 <= t0:
				return {"p": p1, "r": r1}
			var f: float = clamp((target_t - t0) / (t1 - t0), 0.0, 1.0)
			var ang := r0 + wrapf(r1 - r0, -PI, PI) * f
			return {"p": p0.lerp(p1, f), "r": ang}
		prev = cur
	return {"p": (_trail_hist[_trail_hist.size() - 1]["p"] as Vector2), "r": (_trail_hist[_trail_hist.size() - 1]["r"] as float)}
