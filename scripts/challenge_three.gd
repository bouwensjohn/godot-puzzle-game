extends Node2D

var W: float
var H: float
var GRAB_RADIUS: float
var SNAP_RADIUS: float
var ANGLE_TOL: float

var forklift: Node2D
var piece: Node2D
var slot: Node2D
var hud: CanvasLayer
var walls: Array[StaticBody2D]

var release_cooldown := 0.0
var elapsed_time := 0.0

func _ready() -> void:
	W = GameConfig.SCREEN_WIDTH
	H = GameConfig.SCREEN_HEIGHT
	GRAB_RADIUS = GameConfig.GRAB_RADIUS
	SNAP_RADIUS = GameConfig.SNAP_RADIUS
	ANGLE_TOL = GameConfig.ANGLE_TOL
	
	var background = load("res://scenes/CaveBackground.tscn").instantiate()
	forklift = load("res://scenes/Forklift.tscn").instantiate()
	piece = load("res://scenes/Piece.tscn").instantiate()
	slot = load("res://scenes/Slot.tscn").instantiate()
	hud = load("res://scenes/HUD.tscn").instantiate()
	
	add_child(background)
	
	var wall_scene: PackedScene = load("res://scenes/Wall.tscn") as PackedScene
	var maze_segments := [
		# Vertical columns with wide central/top gaps to keep corridors open
		{ "pos": Vector2(450, 260), "size": Vector2(20, 200) },
		{ "pos": Vector2(450, 550), "size": Vector2(20, 200) },
		{ "pos": Vector2(900, 360), "size": Vector2(20, 400) },
		{ "pos": Vector2(700, 540), "size": Vector2(20, 180) },
		# Horizontal segments shaping a path while keeping wide passages
		{ "pos": Vector2(570, 360), "size": Vector2(200, 20) },
		{ "pos": Vector2(1020, 660), "size": Vector2(400, 20) },
		{ "pos": Vector2(300, 440), "size": Vector2(220, 20) },
		{ "pos": Vector2(700, 790), "size": Vector2(200, 20) }
	]
	walls = [] as Array[StaticBody2D]
	for seg in maze_segments:
		var w: StaticBody2D = wall_scene.instantiate() as StaticBody2D
		w.set("size", seg["size"])
		w.global_position = seg["pos"]
		add_child(w)
		walls.append(w)
	for w: StaticBody2D in walls:
		move_child(w, get_child_count())
	
	add_child(piece)
	add_child(slot)
	add_child(forklift)
	add_child(hud)
	
	forklift.global_position = Vector2(W*0.1, H*0.8)
	forklift.rotation = -PI/2.0
	forklift.set("velocity", Vector2.ZERO)
	piece.global_position = Vector2(W*0.15, H*0.2)
	piece.rotation = 0.0
	piece.set("velocity", Vector2.ZERO)
	piece.set("held", false)
	slot.global_position = Vector2(W*0.9, H*0.2)
	slot.rotation = 0.0
	slot.set("snapped", false)
	update_hud()

func _draw() -> void:
	var font = ThemeDB.fallback_font
	for w: StaticBody2D in walls:
		var p: Vector2 = w.global_position
		draw_string(font, Vector2(p.x - 30, p.y - 350), "WALL", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)

func _process(_delta: float) -> void:
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("grab"):
		try_grab_or_release(1.0/60.0)
		return
	if event.is_action_pressed("reset"):
		reset_state()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			try_grab_or_release(1.0/60.0)
		elif event.keycode == KEY_R:
			reset_state()

func _physics_process(delta: float) -> void:
	elapsed_time += delta
	if release_cooldown > 0.0:
		release_cooldown -= delta
	(forklift as Node).call("update_move", delta)
	handle_wall_collision()
	wrap_position(forklift)
	if piece.get("held"):
		piece.rotation = forklift.rotation
		var hold_dist: float = 28.0 + float(piece.get("size")) * 0.5
		var fwd: Vector2 = Vector2.RIGHT.rotated(forklift.rotation)
		piece.global_position = forklift.global_position + fwd * hold_dist
		piece.set("velocity", forklift.get("velocity"))
	elif not slot.get("snapped"):
		(piece as Node).call("update_free", delta)
		wrap_position(piece)
	if not piece.get("held") and not slot.get("snapped"):
		var near: bool = piece.global_position.distance_to(slot.global_position) < SNAP_RADIUS
		var ang_diff: float = abs(wrapf(piece.rotation - slot.rotation, -PI, PI))
		if near and ang_diff < ANGLE_TOL:
			slot.set("snapped", true)
			piece.set("velocity", Vector2.ZERO)
			piece.global_position = slot.global_position
			piece.rotation = slot.rotation
			var am := get_node_or_null("/root/AudioManager")
			if am: am.call("click")
			var sm := get_node_or_null("/root/SaveManager")
			if sm:
				sm.call("record_attempt", true, elapsed_time)
				update_hud()
			challenge_completed()
	update_hud()

func handle_wall_collision() -> void:
	var forklift_pos = forklift.global_position
	var forklift_radius = 30.0
	for w: StaticBody2D in walls:
		var wall_pos: Vector2 = w.global_position
		var ws: Vector2 = (w.get("size") as Vector2)
		var wall_left = wall_pos.x - ws.x * 0.5
		var wall_right = wall_pos.x + ws.x * 0.5
		var wall_top = wall_pos.y - ws.y * 0.5
		var wall_bottom = wall_pos.y + ws.y * 0.5
		if (forklift_pos.x + forklift_radius > wall_left and 
			forklift_pos.x - forklift_radius < wall_right and
			forklift_pos.y + forklift_radius > wall_top and
			forklift_pos.y - forklift_radius < wall_bottom):
			var velocity = forklift.get("velocity") as Vector2
			var overlap_left = (forklift_pos.x + forklift_radius) - wall_left
			var overlap_right = wall_right - (forklift_pos.x - forklift_radius)
			var overlap_top = (forklift_pos.y + forklift_radius) - wall_top
			var overlap_bottom = wall_bottom - (forklift_pos.y - forklift_radius)
			var min_overlap = min(min(overlap_left, overlap_right), min(overlap_top, overlap_bottom))
			if min_overlap == overlap_left:
				velocity.x = -abs(velocity.x) * 0.8
				forklift.global_position.x = wall_left - forklift_radius - 2
			elif min_overlap == overlap_right:
				velocity.x = abs(velocity.x) * 0.8
				forklift.global_position.x = wall_right + forklift_radius + 2
			elif min_overlap == overlap_top:
				velocity.y = -abs(velocity.y) * 0.8
				forklift.global_position.y = wall_top - forklift_radius - 2
			else:
				velocity.y = abs(velocity.y) * 0.8
				forklift.global_position.y = wall_bottom + forklift_radius + 2
			forklift.set("velocity", velocity)
			if piece.get("held"):
				piece.set("held", false)
				release_cooldown = 0.3
				var fwd2: Vector2 = Vector2.RIGHT.rotated(forklift.rotation)
				var nudge: Vector2 = fwd2 * 50.0 * (1.0/60.0) * 60.0
				var piece_velocity: Vector2 = velocity + nudge
				piece.set("velocity", piece_velocity)
				var am := get_node_or_null("/root/AudioManager")
				if am: am.call("release")
			return

func try_grab_or_release(dt: float) -> void:
	if piece.get("held"):
		piece.set("held", false)
		release_cooldown = 0.3
		var fwd: Vector2 = Vector2.RIGHT.rotated(forklift.rotation)
		var nudge: Vector2 = fwd * 50.0 * dt * 60.0
		var v: Vector2 = (forklift.get("velocity") as Vector2) + nudge
		piece.set("velocity", v)
		var am := get_node_or_null("/root/AudioManager")
		if am: am.call("release")
	elif not slot.get("snapped") and release_cooldown <= 0.0:
		var nose: Vector2 = ((forklift as Node).call("nose_global_position") as Vector2)
		if nose.distance_to(piece.global_position) < GRAB_RADIUS:
			piece.set("held", true)
	update_hud()

func reset_state() -> void:
	forklift.global_position = Vector2(W*0.1, H*0.8)
	forklift.rotation = -PI/2.0
	forklift.set("velocity", Vector2.ZERO)
	piece.global_position = Vector2(W*0.15, H*0.2)
	piece.rotation = 0.0
	piece.set("velocity", Vector2.ZERO)
	piece.set("held", false)
	slot.global_position = Vector2(W*0.9, H*0.2)
	slot.rotation = 0.0
	slot.set("snapped", false)
	release_cooldown = 0.0
	elapsed_time = 0.0
	update_hud()
	var sm := get_node_or_null("/root/SaveManager")
	if sm: sm.call("record_attempt", false, 0.0)

func wrap_position(n: Node2D) -> void:
	var p := n.global_position
	if p.x < -30.0: p.x = W + 30.0
	elif p.x > W + 30.0: p.x = -30.0
	if p.y < -30.0: p.y = H + 30.0
	elif p.y > H + 30.0: p.y = -30.0
	n.global_position = p

func challenge_completed() -> void:
	var game_manager = get_node("/root/GameManager")
	if game_manager and game_manager.has_method("on_challenge_completed"):
		game_manager.on_challenge_completed()

func update_hud() -> void:
	var vel: Vector2 = forklift.get("velocity")
	(hud as Node).call("set_velocity", vel)
	(hud as Node).call("set_hold", piece.get("held"))
	var sm := get_node_or_null("/root/SaveManager")
	if sm:
		var stats: Dictionary = sm.call("get_stats")
		(hud as Node).call("set_stats", stats)
