extends Node2D

# Use centralized configuration
var W: float
var H: float
var GRAB_RADIUS: float
var SNAP_RADIUS: float
var ANGLE_TOL: float

var ship: Node2D
var piece: Node2D
var slot: Node2D
var hud: CanvasLayer

var release_cooldown := 0.0
var elapsed_time := 0.0

func _ready() -> void:
	# Initialize configuration values
	W = GameConfig.SCREEN_WIDTH
	H = GameConfig.SCREEN_HEIGHT
	GRAB_RADIUS = GameConfig.GRAB_RADIUS
	SNAP_RADIUS = GameConfig.SNAP_RADIUS
	ANGLE_TOL = GameConfig.ANGLE_TOL
	
	# Instance scenes
	var background = load("res://scenes/CaveBackground.tscn").instantiate()
	ship = load("res://scenes/Ship.tscn").instantiate()
	piece = load("res://scenes/Piece.tscn").instantiate()
	slot = load("res://scenes/Slot.tscn").instantiate()
	hud = load("res://scenes/HUD.tscn").instantiate()
	add_child(background)
	add_child(piece)
	add_child(slot)
	add_child(ship)
	add_child(hud)
	# Initial state (mirrors HTML prototype)
	ship.global_position = Vector2(W*0.5, H*0.75)
	ship.rotation = -PI/2.0
	ship.set("velocity", Vector2.ZERO)
	piece.global_position = Vector2(W*0.3, H*0.35)
	piece.rotation = 0.0
	piece.set("velocity", Vector2.ZERO)
	piece.set("held", false)
	slot.global_position = Vector2(W*0.7, H*0.35)
	slot.rotation = 0.0
	slot.set("snapped", false)
	update_hud()

func _unhandled_input(event: InputEvent) -> void:
	# Action-based (works if Input Map is configured)
	if event.is_action_pressed("grab"):
		try_grab_or_release(1.0/60.0)
		return
	if event.is_action_pressed("reset"):
		reset_state()
		return
	# Direct key handling fallback (works even without Input Map)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			try_grab_or_release(1.0/60.0)
		elif event.keycode == KEY_R:
			reset_state()

func _physics_process(delta: float) -> void:
	elapsed_time += delta
	if release_cooldown > 0.0:
		release_cooldown -= delta
	# Movement
	(ship as Node).call("update_move", delta)
	wrap_position(ship)
	# Held / free movement
	if piece.get("held"):
		piece.rotation = ship.rotation
		var hold_dist: float = 28.0 + float(piece.get("size")) * 0.5
		var fwd: Vector2 = Vector2.RIGHT.rotated(ship.rotation)
		piece.global_position = ship.global_position + fwd * hold_dist
		piece.set("velocity", ship.get("velocity"))
	elif not slot.get("snapped"):
		(piece as Node).call("update_free", delta)
		wrap_position(piece)
	# Snap check
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
			# record completion
			var sm := get_node_or_null("/root/SaveManager")
			if sm:
				sm.call("record_attempt", true, elapsed_time)
				update_hud()
			# Notify game manager that challenge is complete
			challenge_completed()
	update_hud()

func try_grab_or_release(dt: float) -> void:
	if piece.get("held"):
		# release
		piece.set("held", false)
		release_cooldown = 0.3
		var fwd: Vector2 = Vector2.RIGHT.rotated(ship.rotation)
		var nudge: Vector2 = fwd * 50.0 * dt * 60.0
		var v: Vector2 = (ship.get("velocity") as Vector2) + nudge
		piece.set("velocity", v)
		var am := get_node_or_null("/root/AudioManager")
		if am: am.call("release")
	elif not slot.get("snapped") and release_cooldown <= 0.0:
		var nose: Vector2 = ((ship as Node).call("nose_global_position") as Vector2)
		if nose.distance_to(piece.global_position) < GRAB_RADIUS:
			piece.set("held", true)
	update_hud()

func reset_state() -> void:
	ship.global_position = Vector2(W*0.5, H*0.75)
	ship.rotation = -PI/2.0
	ship.set("velocity", Vector2.ZERO)
	piece.global_position = Vector2(W*0.3, H*0.35)
	piece.rotation = 0.0
	piece.set("velocity", Vector2.ZERO)
	piece.set("held", false)
	slot.global_position = Vector2(W*0.7, H*0.35)
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
	# Get the game manager and signal completion
	var game_manager = get_node("/root/GameManager")
	if game_manager and game_manager.has_method("on_challenge_completed"):
		game_manager.on_challenge_completed()

func update_hud() -> void:
	var vel: Vector2 = ship.get("velocity")
	(hud as Node).call("set_velocity", vel)
	(hud as Node).call("set_hold", piece.get("held"))
	var sm := get_node_or_null("/root/SaveManager")
	if sm:
		var stats: Dictionary = sm.call("get_stats")
		(hud as Node).call("set_stats", stats)
