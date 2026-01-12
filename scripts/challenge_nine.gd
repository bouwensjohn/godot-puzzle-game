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

const RNG_SEED := 9191
const CH5_WALL_COLOR := Color(0.26, 0.48, 0.72, 0.2)
const CHASE_DELAY := 3.0
const MAX_TOTAL_BUMPERS := 8
const BIG_ROOM_PROB := 0.20

const CELL_W := 380.0
const CELL_H := 300.0
const WALL_THICK := 52.0
const OUTER_THICK := 60.0
const DOOR_GAP := 140.0

const PILL_COUNT := 60

var _castle_left: float
var _castle_top: float
var _cols: int
var _rows: int
var _entrance_row: int
var _rng := RandomNumberGenerator.new()

var _vwall
var _hwall
var _room_rects: Array[Rect2] = []
var _room_group_rect: Array[Rect2] = []
var _room_group_id: Array[int] = []
var _big_room_parent

var _bumpers: Array[Node2D] = []
var _bumper_active: Array[bool] = []
var _bumper_room_idx: Array[int] = []
var _bumper_speed: Array[float] = []
var _bumper_home: Array[Vector2] = []
var _room_linger_bumper := {}
var _fk_prev_gid := -1

var elapsed_time := 0.0
var _fk_history: Array = []
var release_cooldown := 0.0

# Unlock spot like Challenge Three
var unlock_spot_center: Vector2 = Vector2.ZERO

# Pills
var _pills: Array[Node2D] = []
var _held_pill_idx: int = -1

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
	_plan_castle_area()
	_build_castle_walls_and_rooms()
	_spawn_bumpers_in_rooms()
	_spawn_pills_in_rooms()
	for w: StaticBody2D in walls:
		move_child(w, get_child_count())
	add_child(slot)
	add_child(piece)
	add_child(forklift)
	add_child(hud)
	for b in _bumpers:
		move_child(b, get_child_count())
	camera = Camera2D.new()
	camera.enabled = true
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_W)
	camera.limit_bottom = int(WORLD_H)
	add_child(camera)
	init_state()

func init_state() -> void:
	var ent_x := _castle_left
	var ent_y := _castle_top + (_entrance_row + 0.5) * CELL_H
	var outside_pos := Vector2(ent_x - 220.0, ent_y)
	forklift.global_position = outside_pos
	forklift.rotation = -PI/2.0
	forklift.set("velocity", Vector2.ZERO)
	slot.global_position = outside_pos + Vector2(-120.0, 0.0)
	slot.rotation = 0.0
	slot.set("snapped", false)
	slot.set("locked", true)
	piece.global_position = _cell_center(_pick_farthest_cell(Vector2i(0, _entrance_row), _vwall, _hwall, true))
	piece.rotation = 0.0
	piece.set("velocity", Vector2.ZERO)
	piece.set("held", false)
	release_cooldown = 0.0
	elapsed_time = 0.0
	_fk_history.clear()
	camera.position = forklift.global_position
	update_camera()
	update_hud()
	_room_linger_bumper.clear()
	_fk_prev_gid = -1
	for i in range(_bumpers.size()):
		_bumper_active[i] = false
	# Pick unlock spot in a different empty cell
	var piece_cell := _room_index_at_point(piece.global_position)
	var unlock_cell := piece_cell
	for _i in range(200):
		var rx := _rng.randi_range(0, _cols-1)
		var ry := _rng.randi_range(0, _rows-1)
		var idx := ry * _cols + rx
		if idx != piece_cell:
			unlock_cell = idx
			break
	unlock_spot_center = _cell_center(Vector2i(unlock_cell % _cols, unlock_cell / _cols))

func _draw() -> void:
	# Draw unlock spot circle (locked=red, unlocked=normal)
	draw_circle(unlock_spot_center, GameConfig.SNAP_RADIUS, (GameConfig.SLOT_LOCK_COLOR if slot.get("locked") else GameConfig.SLOT_NORMAL_ARC_COLOR))

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
	_fk_history.push_back({"t": elapsed_time, "p": forklift.global_position})
	while _fk_history.size() > 0 and (elapsed_time - (_fk_history[0]["t"] as float)) > (CHASE_DELAY + 1.0):
		_fk_history.pop_front()
	(forklift as Node).call("update_move", delta)
	handle_wall_collision()
	clamp_to_world(forklift, 30.0)
	update_camera()
	# Piece hold/update
	if piece.get("held"):
		piece.rotation = forklift.rotation
		var hold_dist: float = 28.0 + float(piece.get("size")) * 0.5
		var fwd: Vector2 = Vector2.RIGHT.rotated(forklift.rotation)
		piece.global_position = forklift.global_position + fwd * hold_dist
		piece.set("velocity", forklift.get("velocity"))
	else:
		(piece as Node).call("update_free", delta)
		clamp_to_world(piece, 20.0)
	# Pills hold/update
	var held_idx := _held_pill_idx
	for i in range(_pills.size()):
		var pl: Node2D = _pills[i]
		if i == held_idx and pl.get("held"):
			pl.rotation = forklift.rotation
			var hold_d: float = 24.0 + float(pl.get("size")) * 0.5
			var fwd2: Vector2 = Vector2.RIGHT.rotated(forklift.rotation)
			pl.global_position = forklift.global_position + fwd2 * hold_d
			pl.set("velocity", forklift.get("velocity"))
		else:
			(pl as Node).call("update_free", delta)
			clamp_to_world(pl, 12.0)
	# Activate/linger logic
	var room_idx := _room_index_at_point(forklift.global_position)
	var fk_gid := -1
	if room_idx >= 0:
		fk_gid = _room_group_id[room_idx]
	if fk_gid != _fk_prev_gid:
		if _fk_prev_gid >= 0:
			if not _room_linger_bumper.has(_fk_prev_gid):
				var li := _pick_linger_bumper_for_gid(_fk_prev_gid)
				if li >= 0:
					_room_linger_bumper[_fk_prev_gid] = li
		if fk_gid >= 0:
			var am_bark := get_node_or_null("/root/AudioManager")
			if am_bark:
				# Bark once per bumper in this room group on every entry
				for i in range(_bumpers.size()):
					var b_gid := _room_group_id[_bumper_room_idx[i]]
					if b_gid == fk_gid:
						am_bark.call("bark_notice")
		_fk_prev_gid = fk_gid
	for i in range(_bumpers.size()):
		_bumper_active[i] = false
	if fk_gid >= 0:
		for i in range(_bumpers.size()):
			var b_gid := _room_group_id[_bumper_room_idx[i]]
			if b_gid == fk_gid:
				_bumper_active[i] = true
	for gid in _room_linger_bumper.keys():
		var bi := int(_room_linger_bumper[gid])
		if bi >= 0 and bi < _bumper_active.size():
			_bumper_active[bi] = true
	# Move bumpers: prefer chasing moving pills in their room, else chase forklift trail
	for i in range(_bumpers.size()):
		var b: Node2D = _bumpers[i]
		if not _bumper_active[i]:
			# Return to home within room
			if i < _bumper_home.size():
				var hp: Vector2 = _bumper_home[i]
				var d2 := hp - b.global_position
				var dist2 := d2.length()
				if dist2 > 0.5:
					var step := _bumper_speed[i] * 0.85 * delta
					if step > dist2: step = dist2
					b.global_position += d2.normalized() * step
				else:
					b.global_position = hp
				var rr2 := _room_group_rect[_bumper_room_idx[i]]
				var margin2 := (b.get("radius") as float) + 10.0
				var p2 := b.global_position
				p2.x = clamp(p2.x, rr2.position.x + margin2, rr2.position.x + rr2.size.x - margin2)
				p2.y = clamp(p2.y, rr2.position.y + margin2, rr2.position.y + rr2.size.y - margin2)
				b.global_position = p2
			continue
		# Active: find moving pill in same room group
		var target := _trail_pos_ago(CHASE_DELAY)
		var my_gid := _room_group_id[_bumper_room_idx[i]]
		var best_pill := -1
		var best_d2 := 1e12
		for j in range(_pills.size()):
			var pl: Node2D = _pills[j]
			if not is_instance_valid(pl):
				continue
			if pl.get("held"):
				continue
			var vel: Vector2 = pl.get("velocity")
			if vel.length() < 20.0:
				continue
			var gid_of_p := _room_group_id[_room_index_at_point(pl.global_position)]
			if gid_of_p != my_gid:
				continue
			var d := (pl.global_position - b.global_position).length_squared()
			if d < best_d2:
				best_d2 = d
				best_pill = j
		if best_pill >= 0:
			target = (_pills[best_pill] as Node2D).global_position
		# Move toward target
		var dir := target - b.global_position
		if dir.length() > 1.0:
			dir = dir.normalized()
			b.global_position += dir * _bumper_speed[i] * delta
		# Clamp within its room
		var rr := _room_group_rect[_bumper_room_idx[i]]
		var margin := (b.get("radius") as float) + 10.0
		var p := b.global_position
		p.x = clamp(p.x, rr.position.x + margin, rr.position.x + rr.size.x - margin)
		p.y = clamp(p.y, rr.position.y + margin, rr.position.y + rr.size.y - margin)
		b.global_position = p
		# Eat pills on contact
		for j in range(_pills.size()-1, -1, -1):
			var pl2: Node2D = _pills[j]
			if not is_instance_valid(pl2):
				_pills.remove_at(j)
				continue
			if pl2.get("held"):
				continue
			var pr := float(pl2.get("size")) * 0.5
			if (pl2.global_position - b.global_position).length() <= (float(b.get("radius")) + pr):
				# Eat
				pl2.queue_free()
				_pills.remove_at(j)
				var new_r := float(b.get("radius")) + 2.0
				if new_r > 60.0: new_r = 60.0
				b.set("radius", new_r)
	# Interactions with bumpers
	for b2 in _bumpers:
		b2.call("bounce_piece", piece)
		var hit_fk: bool = b2.call("bounce_forklift", forklift)
		if hit_fk and piece.get("held"):
			piece.set("held", false)
			release_cooldown = 0.3
			var fwd3: Vector2 = Vector2.RIGHT.rotated(forklift.rotation)
			var nudge: Vector2 = fwd3 * 50.0 * (1.0/60.0) * 60.0
			var piece_velocity: Vector2 = (forklift.get("velocity") as Vector2) + nudge
			piece.set("velocity", piece_velocity)
			var am := get_node_or_null("/root/AudioManager")
			if am: am.call("release")
	# Unlock spot check (piece over spot)
	if slot.get("locked") and piece.global_position.distance_to(unlock_spot_center) < GameConfig.SNAP_RADIUS:
		slot.set("locked", false)
		var am_unlock := get_node_or_null("/root/AudioManager")
		if am_unlock:
			am_unlock.call("spot")
	# Snap check
	if not piece.get("held") and not slot.get("snapped"):
		var near: bool = piece.global_position.distance_to(slot.global_position) < SNAP_RADIUS
		var ang_diff: float = abs(wrapf(piece.rotation - slot.rotation, -PI, PI))
		if near and ang_diff < ANGLE_TOL and not slot.get("locked"):
			slot.set("snapped", true)
			piece.set("velocity", Vector2.ZERO)
			piece.global_position = slot.global_position
			piece.rotation = slot.rotation
			var am2 := get_node_or_null("/root/AudioManager")
			if am2: am2.call("click")
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
	var margin_x := viewport_w * 0.4
	var margin_y := viewport_h * 0.4
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
		if (forklift_pos.x + forklift_radius > wall_left and forklift_pos.x - forklift_radius < wall_right and forklift_pos.y + forklift_radius > wall_top and forklift_pos.y - forklift_radius < wall_bottom):
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
	# Release priority: if holding piece, release piece; else if holding a pill, release pill
	if piece.get("held"):
		piece.set("held", false)
		release_cooldown = 0.3
		var fwd: Vector2 = Vector2.RIGHT.rotated(forklift.rotation)
		var nudge: Vector2 = fwd * 50.0 * dt * 60.0
		var v: Vector2 = (forklift.get("velocity") as Vector2) + nudge
		piece.set("velocity", v)
		var am := get_node_or_null("/root/AudioManager")
		if am: am.call("release")
		update_hud()
		return
	if _held_pill_idx >= 0 and _held_pill_idx < _pills.size():
		var pl: Node2D = _pills[_held_pill_idx]
		if is_instance_valid(pl) and pl.get("held"):
			pl.set("held", false)
			release_cooldown = 0.3
			var fwdp: Vector2 = Vector2.RIGHT.rotated(forklift.rotation)
			var nudgep: Vector2 = fwdp * 50.0 * dt * 60.0
			var vp: Vector2 = (forklift.get("velocity") as Vector2) + nudgep
			pl.set("velocity", vp)
			var am2 := get_node_or_null("/root/AudioManager")
			if am2: am2.call("release")
			_held_pill_idx = -1
			update_hud()
			return
	# Grab priority: piece first, else nearest pill
	if not slot.get("snapped") and release_cooldown <= 0.0:
		var nose: Vector2 = ((forklift as Node).call("nose_global_position") as Vector2)
		if nose.distance_to(piece.global_position) < GRAB_RADIUS:
			piece.set("held", true)
			update_hud()
			return
		var best_j := -1
		var best_d := 1e9
		for j in range(_pills.size()):
			var pl2: Node2D = _pills[j]
			if not is_instance_valid(pl2):
				continue
			if pl2.get("held"):
				continue
			var d := nose.distance_to(pl2.global_position)
			if d < GRAB_RADIUS and d < best_d:
				best_d = d
				best_j = j
		if best_j >= 0:
			var target_pill: Node2D = _pills[best_j]
			target_pill.set("held", true)
			_held_pill_idx = best_j
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

func _plan_castle_area() -> void:
	var margin_x := W * 0.18
	var margin_y := H * 0.16
	var usable_w := WORLD_W - 2.0 * margin_x
	var usable_h := WORLD_H - 2.0 * margin_y
	_cols = max(5, int(floor(usable_w / CELL_W)))
	_rows = max(3, int(floor(usable_h / CELL_H)))
	var total_w := _cols * CELL_W
	var total_h := _rows * CELL_H
	_castle_left = (WORLD_W - total_w) * 0.5
	_castle_top  = (WORLD_H - total_h) * 0.5
	_entrance_row = _rows / 2

func _cell_center(c: Vector2i) -> Vector2:
	return Vector2(_castle_left + (c.x + 0.5) * CELL_W, _castle_top + (c.y + 0.5) * CELL_H)

func _build_castle_walls_and_rooms() -> void:
	_vwall = []
	_hwall = []
	_vwall.resize(_cols + 1)
	for x in range(_cols + 1):
		_vwall[x] = []
		_vwall[x].resize(_rows)
		for y in range(_rows):
			_vwall[x][y] = true
	_hwall.resize(_cols)
	for x in range(_cols):
		_hwall[x] = []
		_hwall[x].resize(_rows + 1)
		for y in range(_rows + 1):
			_hwall[x][y] = true
	var visited := []
	visited.resize(_cols)
	for x in range(_cols):
		visited[x] = []
		visited[x].resize(_rows)
		for y in range(_rows):
			visited[x][y] = false
	var start: Vector2i = Vector2i(0, _entrance_row)
	_dfs_carve(start, visited, _vwall, _hwall)
	_vwall[0][_entrance_row] = false
	_apply_big_rooms()
	var wall_scene: PackedScene = load("res://scenes/Wall.tscn") as PackedScene
	walls = [] as Array[StaticBody2D]
	_room_rects.clear()
	for y in range(_rows):
		for x in range(_cols):
			var r := Rect2(_castle_left + x * CELL_W, _castle_top + y * CELL_H, CELL_W, CELL_H)
			_room_rects.append(r)
	_build_room_groups()
	for y in range(_rows):
		if _vwall[0][y]: _spawn_vwall(wall_scene, 0, y, OUTER_THICK, false)
		if _vwall[_cols][y]: _spawn_vwall(wall_scene, _cols, y, OUTER_THICK, false)
	for x in range(_cols):
		if _hwall[x][0]: _spawn_hwall(wall_scene, x, 0, OUTER_THICK, false)
		if _hwall[x][_rows]: _spawn_hwall(wall_scene, x, _rows, OUTER_THICK, false)
	for x in range(1, _cols):
		for y in range(_rows):
			var left_idx: int = y * _cols + (x - 1)
			var right_idx: int = y * _cols + x
			if _room_group_id[left_idx] == _room_group_id[right_idx]:
				continue
			var present: bool = _vwall[x][y]
			_spawn_vwall(wall_scene, x, y, WALL_THICK, not present)
	for x in range(_cols):
		for y in range(1, _rows):
			var up_idx: int = (y - 1) * _cols + x
			var down_idx: int = y * _cols + x
			if _room_group_id[up_idx] == _room_group_id[down_idx]:
				continue
			var present2: bool = _hwall[x][y]
			_spawn_hwall(wall_scene, x, y, WALL_THICK, not present2)

func _spawn_vwall(wall_scene: PackedScene, grid_x: int, grid_y: int, thick: float, door_gap: bool) -> void:
	var x := _castle_left + grid_x * CELL_W
	var y := _castle_top + (grid_y + 0.5) * CELL_H
	if door_gap:
		var seg_h: float = max(0.0, (CELL_H - DOOR_GAP) * 0.5)
		if seg_h > 1.0:
			_spawn_wall_segment(wall_scene, Vector2(thick, seg_h), Vector2(x, y - (DOOR_GAP * 0.5 + seg_h * 0.5)))
			_spawn_wall_segment(wall_scene, Vector2(thick, seg_h), Vector2(x, y + (DOOR_GAP * 0.5 + seg_h * 0.5)))
	else:
		_spawn_wall_segment(wall_scene, Vector2(thick, CELL_H + 0.001), Vector2(x, y))

func _spawn_hwall(wall_scene: PackedScene, grid_x: int, grid_y: int, thick: float, door_gap: bool) -> void:
	var x := _castle_left + (grid_x + 0.5) * CELL_W
	var y := _castle_top + grid_y * CELL_H
	if door_gap:
		var seg_w: float = max(0.0, (CELL_W - DOOR_GAP) * 0.5)
		if seg_w > 1.0:
			_spawn_wall_segment(wall_scene, Vector2(seg_w, thick), Vector2(x - (DOOR_GAP * 0.5 + seg_w * 0.5), y))
			_spawn_wall_segment(wall_scene, Vector2(seg_w, thick), Vector2(x + (DOOR_GAP * 0.5 + seg_w * 0.5), y))
	else:
		_spawn_wall_segment(wall_scene, Vector2(CELL_W + 0.001, thick), Vector2(x, y))

func _spawn_wall_segment(wall_scene: PackedScene, size: Vector2, center: Vector2) -> void:
	var w: StaticBody2D = wall_scene.instantiate() as StaticBody2D
	w.set("size", size)
	w.global_position = center
	add_child(w)
	walls.append(w)

func _dfs_carve(c: Vector2i, visited, vwall, hwall) -> void:
	visited[c.x][c.y] = true
	var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	dirs.shuffle()
	for d in dirs:
		var nx : int = c.x + d.x
		var ny : int = c.y + d.y
		if nx < 0 or ny < 0 or nx >= _cols or ny >= _rows:
			continue
		if visited[nx][ny]:
			continue
		if d.x == 1:
			vwall[c.x + 1][c.y] = false
		elif d.x == -1:
			vwall[c.x][c.y] = false
		elif d.y == 1:
			hwall[c.x][c.y + 1] = false
		else:
			hwall[c.x][c.y] = false
		_dfs_carve(Vector2i(nx, ny), visited, vwall, hwall)

func _apply_big_rooms() -> void:
	_big_room_parent = []
	_big_room_parent.resize(_cols)
	for x in range(_cols):
		_big_room_parent[x] = []
		_big_room_parent[x].resize(_rows)
		for y in range(_rows):
			_big_room_parent[x][y] = Vector2i(x, y)
	for x in range(_cols - 1):
		for y in range(_rows - 1):
			if _rng.randf() >= BIG_ROOM_PROB:
				continue
			if _big_room_parent[x][y] != Vector2i(x, y): continue
			if _big_room_parent[x+1][y] != Vector2i(x+1, y): continue
			if _big_room_parent[x][y+1] != Vector2i(x, y+1): continue
			if _big_room_parent[x+1][y+1] != Vector2i(x+1, y+1): continue
			var parent := Vector2i(x, y)
			_big_room_parent[x][y] = parent
			_big_room_parent[x+1][y] = parent
			_big_room_parent[x][y+1] = parent
			_big_room_parent[x+1][y+1] = parent
			_vwall[x+1][y] = false
			_vwall[x+1][y+1] = false
			_hwall[x][y+1] = false
			_hwall[x+1][y+1] = false

func _build_room_groups() -> void:
	var total := _cols * _rows
	_room_group_id.resize(total)
	_room_group_rect.resize(total)
	var group_index_by_parent := {}
	var group_cells := {}
	for y in range(_rows):
		for x in range(_cols):
			var parent: Vector2i = _big_room_parent[x][y]
			if not group_index_by_parent.has(parent):
				group_index_by_parent[parent] = group_index_by_parent.size()
				group_cells[parent] = []
			(group_cells[parent] as Array).append(Vector2i(x, y))
	for parent in group_cells.keys():
		var cells: Array = group_cells[parent]
		var minx := 1_000_000
		var miny := 1_000_000
		var maxx := -1
		var maxy := -1
		for c in cells:
			var cx: int = (c as Vector2i).x
			var cy: int = (c as Vector2i).y
			if cx < minx: minx = cx
			if cy < miny: miny = cy
			if cx > maxx: maxx = cx
			if cy > maxy: maxy = cy
		var rect := Rect2(
			_castle_left + float(minx) * CELL_W,
			_castle_top + float(miny) * CELL_H,
			float(maxx - minx + 1) * CELL_W,
			float(maxy - miny + 1) * CELL_H
		)
		var gid: int = group_index_by_parent[parent]
		for c in cells:
			var cx2: int = (c as Vector2i).x
			var cy2: int = (c as Vector2i).y
			var idx: int = cy2 * _cols + cx2
			_room_group_id[idx] = gid
			_room_group_rect[idx] = rect

func _room_index_at_point(p: Vector2) -> int:
	if p.x < _castle_left or p.y < _castle_top:
		return -1
	var rx := int((p.x - _castle_left) / CELL_W)
	var ry := int((p.y - _castle_top) / CELL_H)
	if rx < 0 or ry < 0 or rx >= _cols or ry >= _rows:
		return -1
	return ry * _cols + rx

func _pick_linger_bumper_for_gid(gid: int) -> int:
	var best := -1
	for i in range(_bumpers.size()):
		var b_gid := _room_group_id[_bumper_room_idx[i]]
		if b_gid == gid:
			best = i
			break
	return best

func _trail_pos_ago(seconds_ago: float) -> Vector2:
	var target_t := elapsed_time - seconds_ago
	if _fk_history.size() == 0:
		return forklift.global_position
	var prev: Dictionary = _fk_history[0]
	for i in range(1, _fk_history.size()):
		var cur: Dictionary = _fk_history[i]
		if (cur["t"] as float) >= target_t:
			var t0: float = prev["t"]
			var t1: float = cur["t"]
			var p0: Vector2 = prev["p"]
			var p1: Vector2 = cur["p"]
			if t1 <= t0:
				return p1
			var f: float = clamp((target_t - t0) / (t1 - t0), 0.0, 1.0)
			return p0.lerp(p1, f)
		prev = cur
	return (_fk_history[_fk_history.size() - 1]["p"] as Vector2)

func _spawn_bumpers_in_rooms() -> void:
	var BumperScript = load("res://scripts/bounce_bumper.gd")
	_bumpers.clear()
	_bumper_active.clear()
	_bumper_room_idx.clear()
	_bumper_speed.clear()
	_bumper_home.clear()
	var piece_cell := _pick_farthest_cell(Vector2i(0, _entrance_row), _vwall, _hwall, true)
	var piece_cell_idx: int = piece_cell.y * _cols + piece_cell.x
	var group_cells_by_gid := {}
	for idx in range(_room_rects.size()):
		var gid: int = _room_group_id[idx]
		if not group_cells_by_gid.has(gid):
			group_cells_by_gid[gid] = []
		(group_cells_by_gid[gid] as Array).append(idx)
	var total: int = 0
	var gids: Array = group_cells_by_gid.keys()
	gids.sort()
	for gid in gids:
		if total >= MAX_TOTAL_BUMPERS:
			break
		var cells: Array = group_cells_by_gid[gid]
		var is_big: bool = cells.size() > 1
		var allowed: Array = cells.duplicate()
		allowed.erase(piece_cell_idx)
		var count := 0
		var rnd := _rng.randf()
		if is_big:
			if rnd < 0.4:
				count = 2
			elif rnd < 0.85:
				count = 1
			else:
				count = 0
		else:
			if rnd < 0.55:
				count = 1
			else:
				count = 0
		if allowed.size() == 0:
			count = 0
		if not is_big and count > 1:
			count = 1
		if is_big and count > 2:
			count = 2
		if total + count > MAX_TOTAL_BUMPERS:
			count = MAX_TOTAL_BUMPERS - total
		for i in range(count):
			if total >= MAX_TOTAL_BUMPERS: break
			if allowed.size() == 0: break
			var pick_i := int(floor(_rng.randf() * allowed.size()))
			if pick_i < 0: pick_i = 0
			if pick_i >= allowed.size(): pick_i = allowed.size() - 1
			var cell_idx = allowed[pick_i]
			var cr: Rect2 = _room_rects[cell_idx]
			var px := _rng.randf_range(cr.position.x + 60.0, cr.position.x + cr.size.x - 60.0)
			var py := _rng.randf_range(cr.position.y + 60.0, cr.position.y + cr.size.y - 60.0)
			var b: Node2D = BumperScript.new()
			b.set("radius", 15.0)
			b.set("boost", 0.01)
			b.set("angle_mix", 0.9)
			b.global_position = Vector2(px, py)
			add_child(b)
			_bumpers.append(b)
			_bumper_active.append(false)
			_bumper_room_idx.append(int(cell_idx))
			_bumper_speed.append(_rng.randf_range(120.0, 180.0))
			_bumper_home.append(b.global_position)
			total += 1

func _spawn_pills_in_rooms() -> void:
	_pills.clear()
	var PillScript = load("res://scripts/pill.gd")
	# Avoid entrance-adjacent cell (x=0, entrance_row) and the piece cell
	var avoid_idx := _entrance_row * _cols + 0
	var piece_cell := _pick_farthest_cell(Vector2i(0, _entrance_row), _vwall, _hwall, true)
	var piece_idx: int = piece_cell.y * _cols + piece_cell.x
	# Exclude any room group that contains a bumper
	var exclude_gids := {}
	for i in range(_bumper_room_idx.size()):
		var gid := _room_group_id[_bumper_room_idx[i]]
		exclude_gids[gid] = true
	# Build allowed cell indices: not entrance, not piece cell, and not in excluded bumper groups
	var allowed: Array[int] = []
	for idx in range(_room_rects.size()):
		if idx == avoid_idx or idx == piece_idx:
			continue
		var gid2 := _room_group_id[idx]
		if exclude_gids.has(gid2):
			continue
		allowed.append(idx)
	if allowed.size() == 0:
		return
	for i in range(PILL_COUNT):
		var pick_i := _rng.randi_range(0, allowed.size() - 1)
		var pick := allowed[pick_i]
		var rr: Rect2 = _room_rects[pick]
		var px := _rng.randf_range(rr.position.x + 50.0, rr.position.x + rr.size.x - 50.0)
		var py := _rng.randf_range(rr.position.y + 50.0, rr.position.y + rr.size.y - 50.0)
		var pill: Node2D = PillScript.new()
		pill.set("size", 18.0)
		pill.global_position = Vector2(px, py)
		add_child(pill)
		_pills.append(pill)

func _neighbors_open(c: Vector2i, vwall: Array, hwall: Array) -> int:
	var open := 0
	if c.x + 1 < _cols and vwall[c.x + 1][c.y] == false: open += 1
	if c.x - 1 >= 0 and vwall[c.x][c.y] == false: open += 1
	if c.y + 1 < _rows and hwall[c.x][c.y + 1] == false: open += 1
	if c.y - 1 >= 0 and hwall[c.x][c.y] == false: open += 1
	return open

func _pick_farthest_cell(start: Vector2i, vwall: Array, hwall: Array, avoid_straight: bool) -> Vector2i:
	var dist := {}
	var q: Array[Vector2i] = []
	dist[start] = 0
	q.push_back(start)
	var cells: Array[Vector2i] = [start]
	while q.size() > 0:
		var c: Vector2i = q.pop_front()
		var dcur: int = dist[c]
		if c.x + 1 < _cols and vwall[c.x + 1][c.y] == false:
			var nr := Vector2i(c.x + 1, c.y)
			if not dist.has(nr): dist[nr] = dcur + 1; q.push_back(nr); cells.push_back(nr)
		if c.x - 1 >= 0 and vwall[c.x][c.y] == false:
			var nl := Vector2i(c.x - 1, c.y)
			if not dist.has(nl): dist[nl] = dcur + 1; q.push_back(nl); cells.push_back(nl)
		if c.y + 1 < _rows and hwall[c.x][c.y + 1] == false:
			var nd := Vector2i(c.x, c.y + 1)
			if not dist.has(nd): dist[nd] = dcur + 1; q.push_back(nd); cells.push_back(nd)
		if c.y - 1 >= 0 and hwall[c.x][c.y] == false:
			var nu := Vector2i(c.x, c.y - 1)
			if not dist.has(nu): dist[nu] = dcur + 1; q.push_back(nu); cells.push_back(nu)
	var center := Vector2i(_cols / 2, _rows / 2)
	var best := start
	var best_score := -1000000
	for c in cells:
		var d: int = dist[c]
		var opens: int = _neighbors_open(c, vwall, hwall)
		var away_center: int = abs(c.x - center.x) + abs(c.y - center.y)
		var penalty := 0
		if avoid_straight:
			if c.y == start.y: penalty += 3
			if abs(c.x - center.x) <= 1: penalty += 2
		var score: int = d * 100 + (30 if opens == 1 else 0) + away_center * 2 - penalty * 50
		if score > best_score:
			best_score = score
			best = c
	return best
