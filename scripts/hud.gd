extends CanvasLayer

@onready var vels: Label = $VelsLabel
@onready var hold: Label = $HoldLabel
@onready var stats_lbl: Label = $StatsLabel
var last_vel: Vector2 = Vector2.ZERO
var last_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Scale and position UI elements based on GameConfig
	setup_responsive_ui()

func set_velocity(v: Vector2) -> void:
	last_vel = v
	vels.text = "x: %.1f  y: %.1f  vx: %.1f  vy: %.1f" % [last_pos.x, last_pos.y, last_vel.x, last_vel.y]

func set_position(p: Vector2) -> void:
	last_pos = p
	vels.text = "x: %.1f  y: %.1f  vx: %.1f  vy: %.1f" % [last_pos.x, last_pos.y, last_vel.x, last_vel.y]

func set_hold(is_held: bool) -> void:
	hold.text = "Vastgehouden: %s" % ("ja" if is_held else "nee")
	hold.add_theme_color_override("font_color", Color(0.49,1,0.77) if is_held else Color(1.0,0.70,0.70))

func set_stats(stats: Dictionary) -> void:
	var attempts: int = int(stats.get("attempts", 0))
	var completed: int = int(stats.get("completed_count", 0))
	var best_v: Variant = stats.get("best_time_seconds", null)
	var best_str: String = "-" if best_v == null else "%.2f" % float(best_v)
	stats_lbl.text = "Attempts: %d  Completed: %d  Best: %s s" % [attempts, completed, best_str]

func setup_responsive_ui() -> void:
	# Create scaled font for all labels
	var font_size = GameConfig.SCALED_FONT_SIZE
	
	# Scale positions based on screen dimensions
	var scale_x = GameConfig.SCALE_FACTOR_X
	var scale_y = GameConfig.SCALE_FACTOR_Y
	
	# Update HoldLabel (top-left)
	hold.position = Vector2(16 * scale_x, 16 * scale_y)
	hold.add_theme_font_size_override("font_size", font_size)
	
	# Update StatsLabel (below HoldLabel)
	stats_lbl.position = Vector2(16 * scale_x, 36 * scale_y)
	stats_lbl.add_theme_font_size_override("font_size", font_size)
	
	# Update VelsLabel (bottom-left, scaled from original 600px from top)
	vels.position = Vector2(14 * scale_x, (GameConfig.BASE_HEIGHT - 40) * scale_y)
	vels.add_theme_font_size_override("font_size", font_size)
