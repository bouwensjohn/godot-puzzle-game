extends Node2D

# Visual demonstration of the collision system for Challenge Two
# This script shows how the wall collision detection works

var wall_position = Vector2(1000, 448)  # W * 0.5, H * 0.35
var wall_size = Vector2(20, 640)        # 20 pixels wide, H * 0.5 tall
var ship_radius = 30.0

func _draw():
	# Draw the wall
	var wall_rect = Rect2(wall_position - wall_size * 0.5, wall_size)
	draw_rect(wall_rect, Color(0.4, 0.3, 0.2, 1.0))
	
	# Draw collision boundaries
	draw_rect(wall_rect, Color.RED, false, 2.0)
	
	# Draw example ship positions and collision zones
	var ship_pos = Vector2(970, 448)  # Approaching wall from left
	draw_circle(ship_pos, ship_radius, Color(1.0, 0.5, 0.0, 0.3))  # Ship collision radius
	draw_circle(ship_pos, 5, Color.ORANGE)  # Ship center
	
	# Show collision detection zones
	var wall_left = wall_position.x - wall_size.x * 0.5
	var wall_right = wall_position.x + wall_size.x * 0.5
	var wall_top = wall_position.y - wall_size.y * 0.5
	var wall_bottom = wall_position.y + wall_size.y * 0.5
	
	# Draw collision check visualization
	if (ship_pos.x + ship_radius > wall_left and 
		ship_pos.x - ship_radius < wall_right and
		ship_pos.y + ship_radius > wall_top and
		ship_pos.y - ship_radius < wall_bottom):
		
		# Collision detected - show bounce direction
		var center_to_ship = ship_pos - wall_position
		var bounce_direction = center_to_ship.normalized()
		draw_line(ship_pos, ship_pos + bounce_direction * 50, Color.RED, 3.0)
		draw_string(get_theme_default_font(), ship_pos + Vector2(0, -40), "COLLISION!", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.RED)
	
	# Draw labels
	draw_string(get_theme_default_font(), wall_position + Vector2(-50, -350), "WALL OBSTACLE", HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color.WHITE)
	draw_string(get_theme_default_font(), ship_pos + Vector2(-30, 50), "FORKLIFT", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.ORANGE)

func _ready():
	print("Collision System Demo:")
	print("- Wall Position: ", wall_position)
	print("- Wall Size: ", wall_size)
	print("- Ship Collision Radius: ", ship_radius)
	print("- Collision uses AABB detection with bounce physics")
	print("- Energy loss factor: 0.8 on collision")
	queue_redraw()
