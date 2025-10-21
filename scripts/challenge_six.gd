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

func _spawn_wall(wall_scene: PackedScene, size: Vector2, pos: Vector2) -> void:
	var w: StaticBody2D = wall_scene.instantiate() as StaticBody2D
	w.set("size", size)
	w.global_position = pos
	add_child(w)
	walls.append(w)
	
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

# Convert grid cell → world position for the left mini-maze
func _maze_cell_center(maze_left: float, maze_top: float, cell_size: float, cx: int, cy: int) -> Vector2:
	return Vector2(maze_left + (cx + 0.5) * cell_size, maze_top + (cy + 0.5) * cell_size)

# Random thickness helper (so we don’t use a lambda inside _ready)
func _rng_thick(rng: RandomNumberGenerator, min_t: float, max_t: float) -> float:
	return rng.randf_range(min_t, max_t)
	
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
	walls = [] as Array[StaticBody2D]

	# --- Room and door setup ---
	var post_w: float = 40.0
	var gap_h: float = 160.0
	var gap_y: float = H * 0.60
	var room_w: float = 520.0
	var room_h: float = 520.0
	var room_thick: float = 56.0
	var room_cx: float = W * 1.60
	var room_cy: float = H * 0.50
	var room_left: float = room_cx - room_w * 0.5
	var room_right: float = room_cx + room_w * 0.5
	var room_top: float = room_cy - room_h * 0.5
	var room_bottom: float = room_cy + room_h * 0.5
	var barrier_x: float = room_left

	# --- Inner room walls (sealed except west door gap) ---
	_spawn_wall(wall_scene, Vector2(room_w + room_thick, room_thick), Vector2(room_cx, room_top))      # North
	_spawn_wall(wall_scene, Vector2(room_w + room_thick, room_thick), Vector2(room_cx, room_bottom))   # South
	_spawn_wall(wall_scene, Vector2(room_thick, room_h + room_thick), Vector2(room_right, room_cy))    # East

	var west_top_h: float = max(40.0, (gap_y - gap_h * 0.5) - room_top - 8.0)
	if west_top_h > 0.0:
		_spawn_wall(wall_scene, Vector2(room_thick, west_top_h), Vector2(barrier_x, room_top + west_top_h * 0.5))
	var west_bot_h: float = max(40.0, room_bottom - (gap_y + gap_h * 0.5) - 8.0)
	if west_bot_h > 0.0:
		_spawn_wall(wall_scene, Vector2(room_thick, west_bot_h), Vector2(barrier_x, gap_y + gap_h * 0.5 + west_bot_h * 0.5))

	# --- Door + hook (unchanged behavior) ---
	door_size = Vector2(post_w, gap_h - 8.0)
	door_closed_pos = Vector2(barrier_x, gap_y)
	var DoorScene: PackedScene = load("res://scenes/Door.tscn") as PackedScene
	door = DoorScene.instantiate() as StaticBody2D
	(door as Node).set("size", door_size)
	(door as Node).set("spring_anchor", Vector2(barrier_x + 150.0, gap_y))
	(door as Node).call("reset_to_closed", door_closed_pos)
	add_child(door)
	walls.append(door)

	spring_anchor = Vector2(barrier_x + 150.0, gap_y)
	var HookScene: PackedScene = load("res://scenes/CornerHook.tscn") as PackedScene
	hook = HookScene.instantiate() as Node2D
	hook.global_position = Vector2(barrier_x + 120.0, gap_y - gap_h * 0.5 + 10.0)
	(hook as Node).set("rotation_duration", 1.2)
	add_child(hook)
	(hook as Node).connect("triggered_signal", Callable(self, "_on_hook_triggered"))

	# --- Perimeter walls behind the inner room (so you can’t drive around) ---
	###_spawn_wall(wall_scene, Vector2(120, WORLD_H * 0.8), Vector2(room_right + 80, WORLD_H * 0.5)) # right boundary
	###_spawn_wall(wall_scene, Vector2(W * 0.1, WORLD_H * 0.2), Vector2(W * 1.75, WORLD_H * 0.1))    # top cap
	###_spawn_wall(wall_scene, Vector2(W * 0.1, WORLD_H * 0.2), Vector2(W * 1.75, WORLD_H * 0.9))    # bottom cap

	# --- Left-side mini-maze (procedural, connects to the door) ---
	var rng := RandomNumberGenerator.new()
	rng.randomize()  # new seed every playthrough

	# Maze rectangle (to the left of the room’s west wall = barrier_x = room_left)
	var maze_left   := W * 0.22
	var maze_right  := barrier_x   # attach directly to the door wall
	var maze_top    := H * 0.32
	var maze_bottom := H * 0.86

	var maze_w := maze_right - maze_left
	var maze_h := maze_bottom - maze_top

	# Light complexity: 6–8 cols, 4–6 rows (corridors wide enough for forklift + piece)
	var cols: int = clamp(int(floor(maze_w / 140.0)), 6, 8)
	var rows: int = clamp(int(floor(maze_h / 140.0)), 4, 6)
	var CELL: float = min(maze_w / float(cols), maze_h / float(rows))
	var HALF: float = CELL * 0.5

	# Create wall grids: true = wall present between cells
	var vwall := []   # vertical walls: size (cols+1) x rows
	vwall.resize(cols + 1)
	for x in range(cols + 1):
		vwall[x] = []
		vwall[x].resize(rows)
		for y in range(rows):
			vwall[x][y] = true

	var hwall := []   # horizontal walls: size cols x (rows+1)
	hwall.resize(cols)
	for x in range(cols):
		hwall[x] = []
		hwall[x].resize(rows + 1)
		for y in range(rows + 1):
			hwall[x][y] = true

	# DFS carve a perfect maze
	var visited := []
	visited.resize(cols)
	for x in range(cols):
		visited[x] = []
		visited[x].resize(rows)
		for y in range(rows):
			visited[x][y] = false

	# Entrance near left-mid; Exit aligned vertically to door gap on east boundary
	var start_cx: int = 0
	var start_cy: int = clamp(int(round((gap_y - maze_top) / CELL)), 0, rows - 1)
	var exit_cx: int = cols - 1
	var exit_cy: int = start_cy  # bias exit to same row as door gap

	# Standard DFS
	var stack: Array[Vector2i] = []
	stack.push_back(Vector2i(start_cx, start_cy))
	visited[start_cx][start_cy] = true

	while stack.size() > 0:
		var c: Vector2i = stack.back()
		# randomized neighbors
		var dirs: Array[Vector2i] = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
		dirs.shuffle()

		var moved := false
		for d in dirs:
			var nx: int = c.x + d.x
			var ny: int = c.y + d.y
			if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
				continue
			if visited[nx][ny]:
				continue
			# open the wall between c and (nx,ny)
			if d.x == 1:
				vwall[c.x + 1][c.y] = false
			elif d.x == -1:
				vwall[c.x][c.y] = false
			elif d.y == 1:
				hwall[c.x][c.y + 1] = false
			else:
				hwall[c.x][c.y] = false
			visited[nx][ny] = true
			stack.push_back(Vector2i(nx, ny))
			moved = true
			break
		if not moved:
			stack.pop_back()

	# Open the entrance/exit gaps on outer boundary
	vwall[0][start_cy] = false           # entrance on the WEST boundary
	vwall[cols][exit_cy] = false         # exit on the EAST boundary (toward the door)

	# Now spawn walls as your Wall.tscn segments (keep corridors fairly wide)
	var thick_min := 34.0
	var thick_max := 50.0

	var gap_top := gap_y - gap_h * 0.5
	var gap_bot := gap_y + gap_h * 0.5

	for y in range(rows):
		# WEST outer edge:
		if vwall[0][y]:
			_spawn_wall(wall_scene, Vector2(thick_max, CELL + 0.001), Vector2(maze_left, maze_top + (y + 0.5) * CELL))

		# EAST outer edge — skip any segment that intersects the door opening
		if vwall[cols][y]:
			var seg_center_y := maze_top + (y + 0.5) * CELL
			var seg_top := seg_center_y - HALF
			var seg_bot := seg_center_y + HALF
			var intersects_door := not (seg_bot <= gap_top or seg_top >= gap_bot)
			if not intersects_door:
				_spawn_wall(wall_scene, Vector2(thick_max, CELL + 0.001), Vector2(maze_right, seg_center_y))
	# Inner walls (varied thickness)
	var t := _rng_thick(rng, thick_min, thick_max)

	for x in range(1, cols):
		for y in range(rows):
			if vwall[x][y]:
				_spawn_wall(wall_scene, Vector2(_rng_thick(rng, thick_min, thick_max), CELL + 0.001), Vector2(maze_left + x * CELL, maze_top + (y + 0.5) * CELL))
	for x in range(cols):
		for y in range(1, rows):
			if hwall[x][y]:
				_spawn_wall(wall_scene, Vector2(CELL + 0.001, _rng_thick(rng, thick_min, thick_max)), Vector2(maze_left + (x + 0.5) * CELL, maze_top + y * CELL))

	# Make sure the exit aligns cleanly to the door gap corridor:
	# Clear a tiny “vestibule” between maze exit and the door opening (no walls placed there).
	# (We already opened vwall[cols][exit_cy] = false, so the east edge of that cell is open toward barrier_x.)

	# Vertical connectors
	for i in range(2):
		var len_v: float = rng.randf_range(200.0, 260.0)
		var thick_v: float = rng.randf_range(36.0, 50.0)
		var x_v: float = rng.randf_range(W * 0.40, W * 0.75)
		var y_v: float = rng.randf_range(H * 0.45, H * 0.75)
		_spawn_wall(wall_scene, Vector2(thick_v, len_v), Vector2(x_v, y_v))

	var seal_x := barrier_x - room_thick * 0.5    # just left of the door line
	var top_len : int = max(0.0, gap_top - maze_top)
	if top_len > 0.0:
		_spawn_wall(wall_scene, Vector2(room_thick * 0.6, top_len), Vector2(seal_x, (maze_top + gap_top) * 0.5))

	var bot_len : int = max(0.0, maze_bottom - gap_bot)
		
	if bot_len > 0.0:
		_spawn_wall(wall_scene, Vector2(room_thick * 0.6, bot_len), Vector2(seal_x, (gap_bot + maze_bottom) * 0.5))
	#############
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
