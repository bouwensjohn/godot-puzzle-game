extends Node2D

func _draw():
    # Draw the wall as a filled rectangle
    var p := get_parent()
    var s: Vector2 = p.get("size") if p else Vector2(20, 640)
    var c: Color = p.get("color") if p else Color(0.4, 0.3, 0.2, 1.0)
    var rect = Rect2(-s.x * 0.5, -s.y * 0.5, s.x, s.y)
    draw_rect(rect, c)
    
    # Draw border for better visibility
    draw_rect(rect, Color.BLACK, false, 2.0)

func _ready():
    # Ensure the wall is always drawn
    queue_redraw()
