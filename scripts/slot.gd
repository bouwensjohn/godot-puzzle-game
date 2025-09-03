extends Node2D

@export var size: float = 48.0
var snapped: bool = false

func _draw() -> void:
    var s: float = size
    # snap radius
    draw_arc(Vector2.ZERO, GameConfig.SNAP_RADIUS, 0, TAU, 64, Color(0.57,0.71,1,0.5), 1.0, true)
    # slot square
    var col: Color = Color8(98,255,154) if snapped else Color8(154,166,255)
    # In Godot 4, draw_rect(color, filled=false, width=3.0) uses 'color' for outline when not filled
    draw_rect(Rect2(Vector2(-s/2, -s/2), Vector2(s, s)), col, false, 3.0)

func _process(_delta: float) -> void:
    queue_redraw()
