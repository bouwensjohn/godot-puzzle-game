extends Node2D

@export var size: float = 48.0
var snapped: bool = false
var locked: bool = false
const SLOT_TEX: Texture2D = preload("res://textures/slot.jpg")
const LOCK_COLOR: Color = GameConfig.SLOT_LOCK_COLOR

func _draw() -> void:
	var s: float = size
	draw_texture_rect(SLOT_TEX, Rect2(Vector2(-s/2, -s/2), Vector2(s, s)), false)
	# snap radius
	draw_arc(Vector2.ZERO, GameConfig.SNAP_RADIUS, 0, TAU, 64, (GameConfig.SLOT_LOCK_COLOR if locked else GameConfig.SLOT_NORMAL_ARC_COLOR), 9.0, true)
	# slot square
	var col: Color = Color8(98,255,154) if snapped else Color8(154,166,255)
	# In Godot 4, draw_rect(color, filled=false, width=3.0) uses 'color' for outline when not filled
	draw_rect(Rect2(Vector2(-s/2, -s/2), Vector2(s, s)), col, false, 3.0)

func _process(_delta: float) -> void:
	queue_redraw()
