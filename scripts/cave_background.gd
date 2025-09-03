extends Node2D

@export var background_texture: Texture2D

func _ready() -> void:
	# Try to load cave background image
	if background_texture == null:
		background_texture = load("res://textures/cave_background.jpg")
	
	# If no image found, we'll fall back to procedural drawing
	if background_texture == null:
		print("No cave background image found, using procedural background")

func _draw() -> void:
	var width = GameConfig.SCREEN_WIDTH
	var height = GameConfig.SCREEN_HEIGHT
	
	if background_texture:
		# Draw the background image scaled to fit the screen
		draw_texture_rect(background_texture, Rect2(0, 0, width, height), false)
	else:
		# Fallback to procedural background
		draw_rect(Rect2(0, 0, width, height), Color(0.15, 0.12, 0.08))
		draw_cave_walls(width, height)
		draw_rock_formations(width, height)
		draw_cave_shadows(width, height)
		draw_mineral_veins(width, height)

func draw_cave_walls(width: float, height: float) -> void:
	# Rough cave wall texture using overlapping shapes
	var wall_color = Color(0.25, 0.2, 0.15)
	var wall_dark = Color(0.18, 0.15, 0.12)
	
	# Top wall with irregular edge
	var top_points = PackedVector2Array()
	for i in range(0, int(width), 80):
		var y_offset = randf_range(height * 0.1, height * 0.25)
		top_points.append(Vector2(i, y_offset))
	top_points.append(Vector2(width, 0))
	top_points.append(Vector2(0, 0))
	draw_colored_polygon(top_points, wall_color)
	
	# Bottom wall with irregular edge
	var bottom_points = PackedVector2Array()
	for i in range(0, int(width), 80):
		var y_offset = randf_range(height * 0.75, height * 0.9)
		bottom_points.append(Vector2(i, y_offset))
	bottom_points.append(Vector2(width, height))
	bottom_points.append(Vector2(0, height))
	draw_colored_polygon(bottom_points, wall_dark)

func draw_rock_formations(width: float, height: float) -> void:
	# Scattered rock formations
	var rock_color = Color(0.3, 0.25, 0.2)
	var rock_highlight = Color(0.4, 0.35, 0.28)
	
	# Large rocks scattered around
	var rock_positions = [
		Vector2(width * 0.1, height * 0.8),
		Vector2(width * 0.85, height * 0.7),
		Vector2(width * 0.2, height * 0.3),
		Vector2(width * 0.9, height * 0.2),
		Vector2(width * 0.05, height * 0.4),
		Vector2(width * 0.75, height * 0.85)
	]
	
	for pos in rock_positions:
		var size = randf_range(40, 80) * GameConfig.UI_SCALE
		# Main rock body
		draw_circle(pos, size, rock_color)
		# Highlight
		draw_circle(pos + Vector2(-size * 0.3, -size * 0.3), size * 0.6, rock_highlight)

func draw_cave_shadows(width: float, height: float) -> void:
	# Add depth with gradient shadows
	var shadow_color = Color(0.08, 0.06, 0.04, 0.7)
	
	# Vertical shadows on sides
	var gradient_width = width * 0.15
	for i in range(int(gradient_width)):
		var alpha = float(i) / gradient_width * 0.5
		var shadow = Color(0.08, 0.06, 0.04, alpha)
		draw_line(Vector2(i, 0), Vector2(i, height), shadow, 2.0)
		draw_line(Vector2(width - i, 0), Vector2(width - i, height), shadow, 2.0)

func draw_mineral_veins(width: float, height: float) -> void:
	# Subtle mineral veins for atmosphere
	var vein_color = Color(0.4, 0.35, 0.3, 0.6)
	var crystal_color = Color(0.6, 0.5, 0.8, 0.4)
	
	# Draw some mineral veins
	var vein_paths = [
		[Vector2(width * 0.3, height * 0.2), Vector2(width * 0.45, height * 0.6), Vector2(width * 0.4, height * 0.8)],
		[Vector2(width * 0.7, height * 0.1), Vector2(width * 0.8, height * 0.4), Vector2(width * 0.85, height * 0.7)],
		[Vector2(width * 0.1, height * 0.5), Vector2(width * 0.25, height * 0.65), Vector2(width * 0.2, height * 0.9)]
	]
	
	for path in vein_paths:
		for i in range(path.size() - 1):
			draw_line(path[i], path[i + 1], vein_color, 3.0 * GameConfig.UI_SCALE)
	
	# Small crystal formations
	var crystal_positions = [
		Vector2(width * 0.15, height * 0.6),
		Vector2(width * 0.8, height * 0.3),
		Vector2(width * 0.4, height * 0.75)
	]
	
	for pos in crystal_positions:
		var crystal_size = 8 * GameConfig.UI_SCALE
		draw_circle(pos, crystal_size, crystal_color)
		draw_circle(pos, crystal_size * 0.6, Color(0.8, 0.7, 0.9, 0.3))

func _process(_delta: float) -> void:
	queue_redraw()
