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

var _slot_cell: Vector2i = Vector2i.ZERO

# ------------- MAZE PARAMS (tweak safely) -------------
const CELL_SIZE := 160.0              # corridor span; forklift radius ~30 → roomy corridors
const THICK_MIN := 30.0               # min wall thickness
const THICK_MAX := 56.0               # max wall thickness
const OUTER_THICK := 60.0             # frame thickness
const RNG_SEED := 31415               # change for a different layout keeping same rules
const CH5_WALL_COLOR := Color(0.26, 0.48, 0.72, 1.0)

# Maze area (centered in the world); leave margins for camera movement
var _maze_left: float
var _maze_top: float
var _maze_cols: int
var _maze_rows: int
var _rng := RandomNumberGenerator.new()

func init_state() -> void:
	forklift.global_position = GameConfig.FORKLIFT_INIT_POS
	forklift.rotation = -PI/2.0
	forklift.set("velocity", Vector2.ZERO)

	# Start the piece near the maze entrance (left edge mid)
	var ent_cell := Vector2i(0, _maze_rows / 2)
	var ent_center := _cell_center(ent_cell)
	piece.global_position = ent_center + Vector2(-CELL_SIZE * 0.6, 0)
	piece.rotation = 0.0
	piece.set("velocity", Vector2.ZERO)
	piece.set("held", false)

	# Place the slot at the chosen cell (computed during build)
	slot.global_position = _cell_center(_slot_cell)
	slot.rotation = 0.0
	slot.set("snapped", false)

	release_cooldown = 0.0
	elapsed_time = 0.0
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

	_rng.seed = RNG_SEED

	var background = load("res://scenes/CaveBackground.tscn").instantiate()
	(background as Node).set("scale_factor", WORLD_SCALE)

	forklift = load("res://scenes/Forklift.tscn").instantiate()
	piece = load("res://scenes/Piece.tscn").instantiate()
	slot = load("res://scenes/Slot.tscn").instantiate()
	hud = load("res://scenes/HUD.tscn").instantiate()

	add_child(background)

	# ---------- Build a proper maze (walls) ----------
	_plan_maze_area()
	_build_maze_walls()

	# Usual node order (walls behind interactive items)
	for w: StaticBody2D in walls:
		move_child(w, get_child_count())

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
		# Integrate + collide piece against walls when free
		(piece as Node).call("update_free", delta)

		var pradius: float = float(piece.get("size")) * 0.5   # same size you use for hold_dist
		var pvel: Vector2 = piece.get("velocity") as Vector2

		# resolve collisions (do two passes to reduce corner tunneling)
		pvel = _collide_circle_with_walls(piece, pradius, pvel, 0.4)
		pvel = _collide_circle_with_walls(piece, pradius, pvel, 0.4)

		piece.set("velocity", pvel)
		clamp_to_world(piece, 20.0)

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
			
# Resolve a circular body (node+radius) against all walls; returns new velocity.
func _collide_circle_with_walls(n: Node2D, radius: float, vel: Vector2, bounce: float = 0.4) -> Vector2:
	var pos := n.global_position
	var collided := false

	for w: StaticBody2D in walls:
		var wall_pos: Vector2 = w.global_position
		var ws: Vector2 = (w.get("size") as Vector2)
		var wall_left = wall_pos.x - ws.x * 0.5
		var wall_right = wall_pos.x + ws.x * 0.5
		var wall_top = wall_pos.y - ws.y * 0.5
		var wall_bottom = wall_pos.y + ws.y * 0.5

		if (pos.x + radius > wall_left and 
			pos.x - radius < wall_right and
			pos.y + radius > wall_top and
			pos.y - radius < wall_bottom):

			var overlap_left   = (pos.x + radius) - wall_left
			var overlap_right  = wall_right - (pos.x - radius)
			var overlap_top    = (pos.y + radius) - wall_top
			var overlap_bottom = wall_bottom - (pos.y - radius)
			var min_overlap = min(min(overlap_left, overlap_right), min(overlap_top, overlap_bottom))

			if min_overlap == overlap_left:
				vel.x = -abs(vel.x) * bounce
				pos.x = wall_left - radius - 2
			elif min_overlap == overlap_right:
				vel.x = abs(vel.x) * bounce
				pos.x = wall_right + radius + 2
			elif min_overlap == overlap_top:
				vel.y = -abs(vel.y) * bounce
				pos.y = wall_top - radius - 2
			else:
				vel.y = abs(vel.y) * bounce
				pos.y = wall_bottom + radius + 2

			collided = true

	# apply the corrected position
	if collided:
		n.global_position = pos
	return vel

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

# ===================== Maze builder =====================

func _plan_maze_area() -> void:
	# Center a rectangular maze in the world with margins
	var margin_x := W * 0.25
	var margin_y := H * 0.20
	var usable_w := WORLD_W - 2.0 * margin_x
	var usable_h := WORLD_H - 2.0 * margin_y

	_maze_cols = max(5, int(floor(usable_w / CELL_SIZE)))
	_maze_rows = max(5, int(floor(usable_h / CELL_SIZE)))

	var total_w := _maze_cols * CELL_SIZE
	var total_h := _maze_rows * CELL_SIZE

	_maze_left = (WORLD_W - total_w) * 0.5
	_maze_top  = (WORLD_H - total_h) * 0.5

func _cell_center(c: Vector2i) -> Vector2:
	return Vector2(_maze_left + (c.x + 0.5) * CELL_SIZE, _maze_top + (c.y + 0.5) * CELL_SIZE)

func _build_maze_walls() -> void:
	# Depth-first carve of a perfect maze
	var visited := []
	visited.resize(_maze_cols)
	for x in range(_maze_cols):
		visited[x] = []
		visited[x].resize(_maze_rows)
		for y in range(_maze_rows):
			visited[x][y] = false

	# walls: true means wall present between cells
	var vwall := []   # vertical walls: size (_maze_cols + 1) x _maze_rows
	var hwall := []   # horizontal walls: size _maze_cols x (_maze_rows + 1)
	vwall.resize(_maze_cols + 1)
	for x in range(_maze_cols + 1):
		vwall[x] = []
		vwall[x].resize(_maze_rows)
		for y in range(_maze_rows):
			vwall[x][y] = true
	hwall.resize(_maze_cols)
	for x in range(_maze_cols):
		hwall[x] = []
		hwall[x].resize(_maze_rows + 1)
		for y in range(_maze_rows + 1):
			hwall[x][y] = true

	var start: Vector2i = Vector2i(0, _maze_rows / 2)
	_dfs_carve(start, visited, vwall, hwall)
	vwall[0][start.y] = false   # open entrance on far left

	### var target := Vector2i(_maze_cols / 2, _maze_rows / 2)

	# Choose a harder slot location (far from entrance, prefer dead-ends, avoid straight row)
	_slot_cell = _pick_farthest_cell(start, vwall, hwall, true)

	_dfs_carve(start, visited, vwall, hwall)

	# (Optional) Bias a corridor toward the center to guarantee easier route
	### _carve_tunnel_toward(target, vwall, hwall)

	# Open the entrance (left boundary at start.y)
	vwall[0][start.y] = false

	# Convert intact walls → Wall.tscn segments with varied thickness
	var wall_scene: PackedScene = load("res://scenes/Wall.tscn") as PackedScene
	walls = [] as Array[StaticBody2D]

	# Outer frame (keep closed except the entrance we opened)
	for y in range(_maze_rows):
		if vwall[0][y]: _spawn_vwall(wall_scene, 0, y, OUTER_THICK)
		if vwall[_maze_cols][y]: _spawn_vwall(wall_scene, _maze_cols, y, OUTER_THICK)
	for x in range(_maze_cols):
		if hwall[x][0]: _spawn_hwall(wall_scene, x, 0, OUTER_THICK)
		if hwall[x][_maze_rows]: _spawn_hwall(wall_scene, x, _maze_rows, OUTER_THICK)

	# Inner walls
	for x in range(1, _maze_cols):
		for y in range(_maze_rows):
			if vwall[x][y]:
				_spawn_vwall(wall_scene, x, y, _rng.randf_range(THICK_MIN, THICK_MAX))
	for x in range(_maze_cols):
		for y in range(1, _maze_rows):
			if hwall[x][y]:
				_spawn_hwall(wall_scene, x, y, _rng.randf_range(THICK_MIN, THICK_MAX))

func _dfs_carve(c: Vector2i, visited, vwall, hwall) -> void:
	visited[c.x][c.y] = true
	var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	dirs.shuffle()

	for d in dirs:
		var nx : int = c.x + d.x
		var ny : int = c.y + d.y
		if nx < 0 or ny < 0 or nx >= _maze_cols or ny >= _maze_rows:
			continue
		if visited[nx][ny]:
			continue
		# remove wall between c and (nx,ny)
		if d.x == 1:
			vwall[c.x + 1][c.y] = false
		elif d.x == -1:
			vwall[c.x][c.y] = false
		elif d.y == 1:
			hwall[c.x][c.y + 1] = false
		else:
			hwall[c.x][c.y] = false
		_dfs_carve(Vector2i(nx, ny), visited, vwall, hwall)
	
func _spawn_vwall(wall_scene: PackedScene, grid_x: int, grid_y: int, thick: float) -> void:
	var w: StaticBody2D = wall_scene.instantiate() as StaticBody2D
	var size := Vector2(thick, CELL_SIZE + 0.001) # +eps to avoid visual seams
	w.set("size", size)
	w.set("color", CH5_WALL_COLOR)
	var x := _maze_left + grid_x * CELL_SIZE
	var y := _maze_top + (grid_y + 0.5) * CELL_SIZE
	w.global_position = Vector2(x, y)
	add_child(w)
	walls.append(w)

func _spawn_hwall(wall_scene: PackedScene, grid_x: int, grid_y: int, thick: float) -> void:
	var w: StaticBody2D = wall_scene.instantiate() as StaticBody2D
	var size := Vector2(CELL_SIZE + 0.001, thick)
	w.set("size", size)
	w.set("color", CH5_WALL_COLOR)
	var x := _maze_left + (grid_x + 0.5) * CELL_SIZE
	var y := _maze_top + grid_y * CELL_SIZE
	w.global_position = Vector2(x, y)
	add_child(w)
	walls.append(w)

func _neighbors_open(c: Vector2i, vwall: Array, hwall: Array) -> int:
	var open := 0
	if c.x + 1 < _maze_cols and vwall[c.x + 1][c.y] == false: open += 1
	if c.x - 1 >= 0        and vwall[c.x][c.y] == false:      open += 1
	if c.y + 1 < _maze_rows and hwall[c.x][c.y + 1] == false: open += 1
	if c.y - 1 >= 0         and hwall[c.x][c.y] == false:     open += 1
	return open

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func _pick_farthest_cell(start: Vector2i, vwall: Array, hwall: Array, avoid_straight: bool) -> Vector2i:
	# BFS across carved maze graph
	var dist := {}                         # Dictionary: Vector2i -> int
	var q: Array[Vector2i] = []
	dist[start] = 0
	q.push_back(start)
	var cells: Array[Vector2i] = [start]

	while q.size() > 0:
		var c: Vector2i = q.pop_front()
		var dcur: int = dist[c]

		# Right
		if c.x + 1 < _maze_cols and vwall[c.x + 1][c.y] == false:
			var nr := Vector2i(c.x + 1, c.y)
			if not dist.has(nr):
				dist[nr] = dcur + 1
				q.push_back(nr)
				cells.push_back(nr)
		# Left
		if c.x - 1 >= 0 and vwall[c.x][c.y] == false:
			var nl := Vector2i(c.x - 1, c.y)
			if not dist.has(nl):
				dist[nl] = dcur + 1
				q.push_back(nl)
				cells.push_back(nl)
		# Down
		if c.y + 1 < _maze_rows and hwall[c.x][c.y + 1] == false:
			var nd := Vector2i(c.x, c.y + 1)
			if not dist.has(nd):
				dist[nd] = dcur + 1
				q.push_back(nd)
				cells.push_back(nd)
		# Up
		if c.y - 1 >= 0 and hwall[c.x][c.y] == false:
			var nu := Vector2i(c.x, c.y - 1)
			if not dist.has(nu):
				dist[nu] = dcur + 1
				q.push_back(nu)
				cells.push_back(nu)

	# Score cells: far from start (primary), prefer dead-ends, penalize same entrance row / center column
	var center := Vector2i(_maze_cols / 2, _maze_rows / 2)
	var best := start
	var best_score := -1_000_000

	for c in cells:
		var d: int = dist[c]
		var opens: int = _neighbors_open(c, vwall, hwall)
		var away_center: int = _manhattan(c, center)
		var penalty := 0
		if avoid_straight:
			if c.y == start.y: penalty += 3         # avoid a straight row from entrance
			if abs(c.x - center.x) <= 1: penalty += 2

		var score: int = d * 100 + (30 if opens == 1 else 0) + away_center * 2 - penalty * 50
		if score > best_score:
			best_score = score
			best = c

	return best
