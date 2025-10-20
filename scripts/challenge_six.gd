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
var camera: Camera2D
var WORLD_W: float
var WORLD_H: float
const WORLD_SCALE := 2.0

var release_cooldown := 0.0
var elapsed_time := 0.0

var door: StaticBody2D
var door_closed_pos: Vector2
var door_size: Vector2
var hook: Node2D
var spring_anchor: Vector2
var hook_pivot: Vector2

func init_state() -> void:
	forklift.global_position = GameConfig.FORKLIFT_INIT_POS
	forklift.rotation = -PI/2.0
	forklift.set("velocity", Vector2.ZERO)
	piece.global_position = Vector2(W*0.20, H*0.55)
	piece.rotation = 0.0
	piece.set("velocity", Vector2.ZERO)
	piece.set("held", false)
	slot.global_position = Vector2(W*1.60, H*0.35)
	slot.rotation = 0.0
	slot.set("snapped", false)
	release_cooldown = 0.0
	elapsed_time = 0.0
	if hook:
		(hook as Node).call("reset", 0.0)
	if door:
		(door as Node).set("size", door_size)
		(door as Node).call("reset_to_closed", door_closed_pos)
		(door as Node).set("spring_anchor", spring_anchor)
	camera.position = forklift.global_position
	update_camera()
	update_hud()

func _ready() -> void:
	W = GameConfig.SCREEN_WIDTH
	H = GameConfig.SCREEN_HEIGHT
	GRAB_RADIUS = GameConfig.GRAB_RADIUS
	SNAP_RADIUS = GameConfig.SNAP_RADIUS
	ANGLE_TOL = GameConfig.ANGLE_TOL
	WORLD_W = W * WORLD_SCALE
	WORLD_H = H * WORLD_SCALE
	var background = load("res://scenes/CaveBackground.tscn").instantiate()
	(background as Node).set("scale_factor", WORLD_SCALE)
	forklift = load("res://scenes/Forklift.tscn").instantiate()
	piece = load("res://scenes/Piece.tscn").instantiate()
	slot = load("res://scenes/Slot.tscn").instantiate()
	hud = load("res://scenes/HUD.tscn").instantiate()
	add_child(background)
	var wall_scene: PackedScene = load("res://scenes/Wall.tscn") as PackedScene
	var barrier_x := W * 0.95
	var gap_h := 160.0
	var gap_y := H * 0.60
	var post_w := 40.0
	var top_h := gap_y - gap_h*0.5
	var bot_h := WORLD_H - (gap_y + gap_h*0.5)
	var top_seg: StaticBody2D = wall_scene.instantiate() as StaticBody2D
	top_seg.set("size", Vector2(post_w, top_h))
	top_seg.global_position = Vector2(barrier_x, top_h * 0.5)
	add_child(top_seg)
	var bot_seg: StaticBody2D = wall_scene.instantiate() as StaticBody2D
	bot_seg.set("size", Vector2(post_w, bot_h))
	bot_seg.global_position = Vector2(barrier_x, gap_y + gap_h*0.5 + bot_h * 0.5)
	add_child(bot_seg)
	door_size = Vector2(post_w, gap_h - 8.0)
	door_closed_pos = Vector2(barrier_x, gap_y)
	var DoorScene: PackedScene = load("res://scenes/Door.tscn") as PackedScene
	door = DoorScene.instantiate() as StaticBody2D
	(door as Node).set("size", door_size)
	(door as Node).set("spring_anchor", Vector2(barrier_x + 150.0, gap_y))
	(door as Node).call("reset_to_closed", door_closed_pos)
	add_child(door)
	spring_anchor = Vector2(barrier_x + 150.0, gap_y)
	var HookScene: PackedScene = load("res://scenes/CornerHook.tscn") as PackedScene
	hook = HookScene.instantiate() as Node2D
	hook.global_position = Vector2(barrier_x + 120.0, gap_y - gap_h * 0.5 + 10.0)
	(hook as Node).set("rotation_duration", 1.2)
	add_child(hook)
	(hook as Node).connect("triggered_signal", Callable(self, "_on_hook_triggered"))
	walls = [] as Array[StaticBody2D]
	walls.append(top_seg)
	walls.append(bot_seg)
	walls.append(door)
	var left_corridor_top: StaticBody2D = wall_scene.instantiate() as StaticBody2D
	left_corridor_top.set("size", Vector2(300, 40))
	left_corridor_top.global_position = Vector2(W*0.45, H*0.46)
	add_child(left_corridor_top)
	walls.append(left_corridor_top)
	var left_corridor_bot: StaticBody2D = wall_scene.instantiate() as StaticBody2D
	left_corridor_bot.set("size", Vector2(300, 40))
	left_corridor_bot.global_position = Vector2(W*0.45, H*0.74)
	add_child(left_corridor_bot)
	walls.append(left_corridor_bot)
	add_child(slot)
	add_child(piece)
	add_child(forklift)
	add_child(hud)
	camera = Camera2D.new()
	camera.enabled = true
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_W)
	camera.limit_bottom = int(WORLD_H)
	add_child(camera)
	init_state()

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
	clamp_to_world(forklift, 30.0)
	update_camera()
	if piece.get("held"):
		piece.rotation = forklift.rotation
		var hold_dist: float = 28.0 + float(piece.get("size")) * 0.5
		var fwd: Vector2 = Vector2.RIGHT.rotated(forklift.rotation)
		piece.global_position = forklift.global_position + fwd * hold_dist
		piece.set("velocity", forklift.get("velocity"))
	elif not slot.get("snapped"):
		(piece as Node).call("update_free", delta)
		clamp_to_world(piece, 20.0)
	if hook:
		(hook as Node).call("check_and_trigger", piece)
	if door:
		(door as Node).call("update_open", delta)
	if not piece.get("held") and not slot.get("snapped"):
		var near: bool = piece.global_position.distance_to(slot.global_position) < SNAP_RADIUS
		var ang_diff: float = abs( wrapf(piece.rotation - slot.rotation, -PI, PI) )
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

func _on_hook_triggered() -> void:
	if door:
		(door as Node).call("open")
	var am := get_node_or_null("/root/AudioManager")
	if am: am.call("click")

func clamp_to_world(n: Node2D, radius: float = 30.0) -> void:
	var p := n.global_position
	p.x = clamp(p.x, radius, WORLD_W - radius)
	p.y = clamp(p.y, radius, WORLD_H - radius)
	n.global_position = p

func update_camera() -> void:
	if camera == null:
		return
	var viewport_w := W
	var viewport_h := H
	var margin_x := viewport_w * 0.25
	var margin_y := viewport_h * 0.25
	var cam_pos := camera.position
	var left := cam_pos.x - viewport_w * 0.5
	var right := cam_pos.x + viewport_w * 0.5
	var top := cam_pos.y - viewport_h * 0.5
	var bottom := cam_pos.y + viewport_h * 0.5
	var fp := forklift.global_position
	if fp.x > right - margin_x:
		cam_pos.x = fp.x + margin_x - viewport_w * 0.5
	elif fp.x < left + margin_x:
		cam_pos.x = fp.x - margin_x + viewport_w * 0.5
	if fp.y > bottom - margin_y:
		cam_pos.y = fp.y + margin_y - viewport_h * 0.5
	elif fp.y < top + margin_y:
		cam_pos.y = fp.y - margin_y + viewport_h * 0.5
	cam_pos.x = clamp(cam_pos.x, viewport_w * 0.5, WORLD_W - viewport_w * 0.5)
	cam_pos.y = clamp(cam_pos.y, viewport_h * 0.5, WORLD_H - viewport_h * 0.5)
	camera.position = cam_pos

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
	init_state()
	var sm := get_node_or_null("/root/SaveManager")
	if sm: sm.call("record_attempt", false, 0.0)

func challenge_completed() -> void:
	var game_manager = get_node("/root/GameManager")
	if game_manager and game_manager.has_method("on_challenge_completed"):
		game_manager.on_challenge_completed()

func update_hud() -> void:
	var vel: Vector2 = forklift.get("velocity")
	(hud as Node).call("set_position", forklift.global_position)
	(hud as Node).call("set_velocity", vel)
	(hud as Node).call("set_hold", piece.get("held"))
	var sm := get_node_or_null("/root/SaveManager")
	if sm:
		var stats: Dictionary = sm.call("get_stats")
		(hud as Node).call("set_stats", stats)
