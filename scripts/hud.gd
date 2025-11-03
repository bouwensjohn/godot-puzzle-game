extends CanvasLayer

@onready var vels: Label = $VelsLabel
@onready var hold: Label = $HoldLabel
@onready var stats_lbl: Label = $StatsLabel
var last_vel: Vector2 = Vector2.ZERO
var last_pos: Vector2 = Vector2.ZERO
var _player_name: String = ""
var _player_color: Color = Color(1,1,1)

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
	hold.text = ""
	hold.visible = false

func set_stats(stats: Dictionary) -> void:
	if _player_name != "":
		stats_lbl.visible = true
		return
	var attempts: int = int(stats.get("attempts", 0))
	var completed: int = int(stats.get("completed_count", 0))
	var best_v: Variant = stats.get("best_time_seconds", null)
	var best_str: String = "-" if best_v == null else "%.2f" % float(best_v)
	var prefix := ""
	if _player_name != "":
		prefix = "%s  " % _player_name
		stats_lbl.add_theme_color_override("font_color", _player_color)
	stats_lbl.text = "%sAttempts: %d  Completed: %d  Best: %s s" % [prefix, attempts, completed, best_str]

func set_player(name: String, color: Color) -> void:
	_player_name = name
	_player_color = color
	stats_lbl.add_theme_color_override("font_color", _player_color)
	if _player_name != "":
		stats_lbl.visible = true
		stats_lbl.text = "%s  %.2f s" % [_player_name, 0.0]

func set_run_time(t: float) -> void:
	if _player_name != "":
		stats_lbl.visible = true
		stats_lbl.add_theme_color_override("font_color", _player_color)
		stats_lbl.text = "%s  %.2f s" % [_player_name, t]

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
