extends Node2D
@export var variation_strength: float = 0.7
@export var speckle_count: int = 120
@export var speckle_min_radius: float = 19.0
@export var speckle_max_radius: float = 34.0
@export var seed: int = 12345
var _speckles: Array[Dictionary] = []
var _last_size: Vector2 = Vector2.ZERO

func _draw():
	# Draw the wall as a filled rectangle
	var p := get_parent()
	var s: Vector2 = p.get("size") if p else Vector2(20, 640)
	var c: Color = p.get("color") if p else Color(0.4, 0.3, 0.2, 1.0)
	var rect = Rect2(-s.x * 0.5, -s.y * 0.5, s.x, s.y)
	draw_rect(rect, c)
	_ensure_speckles()
	for sp in _speckles:
		var delta: float = sp["delta"]
		var col: Color = c.lightened(delta) if delta >= 0.0 else c.darkened(-delta)
		col.a = sp["alpha"]
		draw_circle(sp["pos"], sp["r"], col)


func _ensure_speckles() -> void:
	var p := get_parent()
	var s: Vector2 = p.get("size") if p else Vector2(20, 640)
	if _speckles.size() > 0 and s == _last_size:
		return
	_last_size = s
	_speckles.clear()
	var area: float = maxf(1.0, s.x * s.y)
	var base_area: float = 80000.0
	var count: int = int(maxf(16.0, float(speckle_count) * area / base_area))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed + int(s.x) * 131 + int(s.y) * 197)
	var half_w := s.x * 0.5
	var half_h := s.y * 0.5
	for i in count:
		var r := rng.randf_range(speckle_min_radius, speckle_max_radius)
		var px := rng.randf_range(-half_w + r, half_w - r)
		var py := rng.randf_range(-half_h + r, half_h - r)
		var delta := rng.randf_range(-variation_strength, variation_strength)
		var alpha := rng.randf_range(0.06, 0.16)
		_speckles.append({
			"pos": Vector2(px, py),
			"r": r,
			"delta": delta,
			"alpha": alpha,
		})
	
func _ready():
	# Ensure the wall is always drawn
	queue_redraw()
