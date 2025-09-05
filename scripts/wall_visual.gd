extends Node2D

var wall_size = Vector2(20, 640)
var wall_color = Color(0.4, 0.3, 0.2, 1.0)

func _draw():
	# Draw the wall as a filled rectangle
	var rect = Rect2(-wall_size.x * 0.5, -wall_size.y * 0.5, wall_size.x, wall_size.y)
	draw_rect(rect, wall_color)
	
	# Draw border for better visibility
	draw_rect(rect, Color.BLACK, false, 2.0)

func _ready():
	# Ensure the wall is always drawn
	queue_redraw()
