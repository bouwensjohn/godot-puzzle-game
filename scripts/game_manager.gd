extends Node2D

var splash_screen_scene = preload("res://scenes/SplashScreen.tscn")
var main_game_scene = preload("res://scenes/Main.tscn")

var current_challenge_index = 0
var challenges = []
var challenge_completed_timer: Timer
var is_transitioning = false
var fade_layer: CanvasLayer
var fade_rect: ColorRect
var fade_text: Label
var selection_layer: CanvasLayer
var current_challenge_node: Node
var mode_two_players := false
var player_names: Array[String] = ["Player 1", "Player 2"]
var player_colors: Array[Color] = [Color(0.85, 0.35, 0.35), Color(0.35, 0.65, 0.95)]
var player_scores: Array[int] = [0, 0]
var current_player_idx := 0
var run_elapsed := 0.0
var run_active := false
var last_times: Array[float] = [-1.0, -1.0]
var _prev_thrust := false
var awaiting_ok := false
var help_layer: CanvasLayer
var help_root: Control
var help_visible := false

# --- Player-experience additions -----------------------------------------
var info_layer: CanvasLayer
var briefing_panel: Control
var briefing_stats_label: Label
var briefing_loc_label: Label
var briefing_text_label: Label
var hint_label: Label
var menu_layer: CanvasLayer
var _briefing_tween: Tween
var _hint_queue: Array = []
var _hint_running := false
var level_attempts := 0
var hint_index := 0

# Lightweight story + onboarding metadata, parallel to `challenges`.
# location: place name for the story framework
# briefing: 1-2 sentence mission briefing shown at level start
# intro / intro_id: first-time-only explanation when a new mechanic appears
# hints: context-sensitive hints shown after repeated failed attempts
# gold / silver: medal time thresholds in seconds (slower still earns bronze)
const LEVEL_META := [
	{
		"location": "Training Yard",
		"briefing": "Welcome to the Training Yard. Move the crate onto the marked pad to earn your operator badge.",
		"intro": "",
		"intro_id": "",
		"hints": [
			"Line the forks up with the package, then press Space to grab it.",
			"Press Space again to set the package down on the goal pad.",
			"Drive slowly and turn early to stay in control."
		],
		"gold": 8.0, "silver": 16.0
	},
	{
		"location": "Warehouse District",
		"briefing": "Warehouse District: a pallet of supplies must reach the far dock. Mind the partition wall.",
		"intro": "New: walls block your path. Steer around obstacles to reach the goal.",
		"intro_id": "walls",
		"hints": [
			"Try approaching the goal from a different angle.",
			"Steer around the wall instead of pushing into it.",
			"Release the package with a gentle tap so it settles."
		],
		"gold": 12.0, "silver": 24.0
	},
	{
		"location": "Underground Maze",
		"briefing": "Underground Maze: deliver fragile medical equipment through the old tunnels. Handle it with care.",
		"intro": "New: fragile cargo. Bumping a wall while carrying it causes damage \u2014 after three hits you'll drop the package.",
		"intro_id": "fragile",
		"hints": [
			"Slower driving may help maintain control of the fragile cargo.",
			"Touch the glowing spot with the package to unlock the goal.",
			"Take corners wide to avoid scraping the maze walls."
		],
		"gold": 22.0, "silver": 45.0
	},
	{
		"location": "Research Facility",
		"briefing": "Research Facility: transport sensitive lab samples and bank them into the secure receiver.",
		"intro": "New: purple bumpers. The package bounces off them \u2014 use ricochets to reach locked goals.",
		"intro_id": "bounce",
		"hints": [
			"The package can bounce off the purple objects.",
			"Unlock the goal first, then line up your ricochet.",
			"A slower, angled bump aims the bounce better."
		],
		"gold": 18.0, "silver": 35.0
	},
	{
		"location": "Industrial Zone",
		"briefing": "Industrial Zone: route emergency power cells through the narrow service tunnels.",
		"intro": "New: tight tunnels. Thread the narrow passages slowly to keep control.",
		"intro_id": "tunnel",
		"hints": [
			"Slow right down before entering the narrow passages.",
			"If you get wedged, reverse out and realign.",
			"Keep the package straight so it fits through gaps."
		],
		"gold": 22.0, "silver": 42.0
	},
	{
		"location": "Security Compound",
		"briefing": "Security Compound: a sealed vault guards the drop point. Trip the lever to open it.",
		"intro": "New: corner hook and door. Rotate the hook to pull the lever and spring the door open.",
		"intro_id": "hook",
		"hints": [
			"Nudge the corner hook to rotate it onto the lever.",
			"Open the door first, then drive the package straight through.",
			"Line up before the door so you keep your momentum."
		],
		"gold": 24.0, "silver": 48.0
	},
	{
		"location": "Hazard Sector",
		"briefing": "Hazard Sector: cross the active bumper field and deliver the payload intact.",
		"intro": "New: moving bumpers. Dodge the roaming bumpers, then ricochet off the final one.",
		"intro_id": "gauntlet",
		"hints": [
			"Wait for a gap before crossing the moving bumpers.",
			"Use the final bumper to ricochet into the locked goal.",
			"Keep moving \u2014 a parked forklift is an easy target."
		],
		"gold": 30.0, "silver": 60.0
	},
	{
		"location": "Central Hub",
		"briefing": "Central Hub: rival loaders are active. Retrieve the package and get it outside.",
		"intro": "New: chasing bumpers. They awaken and chase your recent path \u2014 keep moving.",
		"intro_id": "chase",
		"hints": [
			"The bumpers chase where you were a moment ago \u2014 keep moving.",
			"Lead them away, then double back for the package.",
			"Use the doorways to break their line of sight."
		],
		"gold": 35.0, "silver": 70.0
	},
	{
		"location": "Final Priority Delivery",
		"briefing": "Final Priority Delivery: the last and most important shipment. Outwit the loaders and bring it home.",
		"intro": "New: throwable pills. Bumpers chase moving pills and grow \u2014 use pills to distract them.",
		"intro_id": "pills",
		"hints": [
			"Throw a pill to distract the bumpers, then grab the package.",
			"Bumpers chase moving pills \u2014 use them to clear your path.",
			"Unlock the goal, then make your run while they're busy."
		],
		"gold": 40.0, "silver": 80.0
	}
]

func _ready() -> void:
	# Initialize challenges array for future expansion
	setup_challenges()
	
	# Setup completion timer
	setup_completion_timer()
	setup_fade_overlay()
	_ensure_info_layer()
	
	# Start with splash screen
	show_splash_screen()

func setup_challenges() -> void:
	# Setup different forklift-based challenges
	# For now, we have the basic puzzle challenge
	challenges = [
		{
			"name": "Basic Puzzle",
			"scene": main_game_scene,
			"description": "Move the piece to the slot using the forklift"
		},
		{
			"name": "Wall Challenge",
			"scene": preload("res://scenes/ChallengeTwo.tscn"),
			"description": "Navigate around the wall to complete the puzzle"
		},
		{
			"name": "Maze Challenge",
			"scene": preload("res://scenes/ChallengeThree.tscn"),
			"description": "Navigate a maze of walls to solve the puzzle"
		},
		{
			"name": "Ricochet Challenge",
			"scene": preload("res://scenes/ChallengeFour.tscn"),
			"description": "Use the bounce bumper to unlock and ricochet the piece into the slot"
		},
		{
			"name": "Tunnel Challenge",
			"scene": preload("res://scenes/ChallengeFive.tscn"),
			"description": "Navigate a narrow winding tunnel to reach the slot"
		},
		{
			"name": "Hook Door Challenge",
			"scene": preload("res://scenes/ChallengeSix.tscn"),
			"description": "Rotate a corner hook to pull a lever and spring-open the door to reach the slot"
		},
		{
			"name": "Ricochet Gauntlet",
			"scene": preload("res://scenes/ChallengeSeven.tscn"),
			"description": "Evade 20 moving bumpers and use the final bumper to ricochet the piece into the locked slot"
		},
		{
			"name": "Castle Rooms",
			"scene": preload("res://scenes/ChallengeEight.tscn"),
			"description": "Navigate a castle of rooms with doorway gaps. Bumpers in rooms awaken and chase your 1s-ago path to retrieve the piece and deliver it outside."
		},
		{
			"name": "Castle Diversion",
			"scene": preload("res://scenes/ChallengeNine.tscn"),
			"description": "Castle rooms with an unlock spot and many throw-able pills; bumpers prefer moving pills and eat them to grow."
		}
	]

func setup_completion_timer() -> void:
	challenge_completed_timer = Timer.new()
	challenge_completed_timer.wait_time = 3.0
	challenge_completed_timer.one_shot = true
	challenge_completed_timer.timeout.connect(_on_completion_timer_timeout)
	add_child(challenge_completed_timer)

func show_splash_screen() -> void:
	var splash = splash_screen_scene.instantiate()
	add_child(splash)
	
	# Connect to the splash finished signal
	splash.splash_finished.connect(_on_splash_finished)

func _on_splash_finished() -> void:
	show_main_menu()

func _is_persistent(child: Node) -> bool:
	# Overlays that must survive challenge swaps.
	return child == challenge_completed_timer or child == fade_layer \
		or child == info_layer or child == help_layer

func load_current_challenge() -> void:
	# Clear any existing children (splash screen should already be freed)
	for child in get_children():
		if not _is_persistent(child):  # Don't free the timer or persistent overlays
			child.queue_free()
	
	# Wait a frame to ensure cleanup
	await get_tree().process_frame
	
	# Load the current challenge
	if current_challenge_index < challenges.size():
		var challenge = challenges[current_challenge_index]
		print("Loading challenge ", current_challenge_index, ": ", challenge.name)
		var game_instance = challenge.scene.instantiate()
		current_challenge_node = game_instance
		add_child(game_instance)
		run_elapsed = 0.0
		run_active = not mode_two_players
		_prev_thrust = false
		await get_tree().process_frame
		_apply_player_to_hud()
		_on_level_started()
	else:
		print("No more challenges to load")

func next_challenge() -> void:
	current_challenge_index += 1
	print("Moving to challenge index: ", current_challenge_index)
	if current_challenge_index < challenges.size():
		load_current_challenge()
	else:
		# All challenges completed - could show completion screen
		print("All challenges completed!")

func restart_current_challenge() -> void:
	load_current_challenge()

func on_challenge_completed() -> void:
	if is_transitioning:
		return  # Prevent multiple calls
	
	is_transitioning = true
	print("Challenge completed! Starting transition...")
	
	if mode_two_players:
		if current_player_idx >= 0 and current_player_idx < 2:
			last_times[current_player_idx] = run_elapsed
		run_active = false
	else:
		# Single-player: record progression (best time, unlock next, medal).
		_record_level_completion(current_challenge_index, run_elapsed)
		run_active = false
	
	# Play triumph sound
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("triumph"):
		am.triumph()
	
	# Start the 3-second timer (check if timer still exists)
	if challenge_completed_timer and is_instance_valid(challenge_completed_timer):
		challenge_completed_timer.start()
	else:
		# Timer was freed, call next challenge directly after delay
		await get_tree().create_timer(3.0).timeout
		_on_completion_timer_timeout()

	if fade_rect:
		var tw := create_tween()
		tw.tween_property(fade_rect, "modulate:a", 1.0, 0.8)

func _on_completion_timer_timeout() -> void:
	is_transitioning = false
	if not mode_two_players:
		if current_challenge_index + 1 >= challenges.size():
			# Campaign complete — return to the main menu.
			await get_tree().process_frame
			show_main_menu()
			return
		if fade_rect:
			fade_rect.modulate.a = 1.0
		next_challenge()
		await get_tree().process_frame
		if fade_text:
			fade_text.text = ""
		if fade_rect:
			var tw := create_tween()
			tw.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
		return
	var p0: float = last_times[0]
	var p1: float = last_times[1]
	if current_player_idx == 0:
		if fade_rect:
			fade_rect.modulate.a = 1.0
		current_player_idx = 1
		await get_tree().process_frame
		load_current_challenge()
		await get_tree().process_frame
		if fade_rect:
			var tw2 := create_tween()
			tw2.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
		return
	if current_player_idx == 1:
		if fade_rect:
			fade_rect.modulate.a = 1.0
		var winner_msg: String = ""
		if p0 >= 0.0 and p1 >= 0.0:
			if abs(p0 - p1) < 0.0001:
				player_scores[0] += 1
				player_scores[1] += 1
				winner_msg = "Tie: both +1 point\n" + player_names[0] + ": " + String.num(p0, 2) + " seconds  vs  " + player_names[1] + ": " + String.num(p1, 2) + " seconds"
			elif p0 < p1:
				player_scores[0] += 1
				winner_msg = player_names[0] + " wins and gets a point\n" + String.num(p0, 2) + " seconds vs " + String.num(p1, 2) + " seconds"
			else:
				player_scores[1] += 1
				winner_msg = player_names[1] + " wins and gets a point\n" + String.num(p1, 2) + " seconds vs " + String.num(p0, 2) + " seconds"
		if fade_text:
			fade_text.text = winner_msg
			fade_text.add_theme_color_override("font_color", Color(1,1,1))
		await _await_ok()
		last_times = [-1.0, -1.0]
		current_player_idx = 0
		current_challenge_index += 1
		if current_challenge_index < challenges.size():
			await get_tree().process_frame
			load_current_challenge()
			await get_tree().process_frame
			if fade_text:
				fade_text.text = ""
			if fade_rect:
				var tw3 := create_tween()
				tw3.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
		else:
			if fade_text:
				var final_msg: String = player_names[0] + ": " + str(player_scores[0]) + " points\n" + player_names[1] + ": " + str(player_scores[1]) + " points\n"
				var winner: String = ""
				if player_scores[0] > player_scores[1]: winner = player_names[0]
				elif player_scores[1] > player_scores[0]: winner = player_names[1]
				else: winner = "Tie"
				fade_text.text = "Final Score\n" + final_msg + "\nWinner: " + winner
			await _await_ok()
			if fade_text:
				fade_text.text = ""
			if fade_rect:
				var twf := create_tween()
				twf.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
			await get_tree().process_frame
			_reset_to_start()

func get_current_challenge_info() -> Dictionary:
	if current_challenge_index < challenges.size():
		return challenges[current_challenge_index]
	return {}

func _apply_player_to_hud() -> void:
	if not current_challenge_node:
		return
	var hud := _find_hud(current_challenge_node)
	if hud and hud.has_method("set_player"):
		if mode_two_players:
			hud.call("set_player", player_names[current_player_idx], player_colors[current_player_idx])
		else:
			hud.call("set_player", "", Color(1,1,1))

func _find_hud(n: Node) -> Node:
	for c in n.get_children():
		if c is CanvasLayer and c.has_method("set_player"):
			return c
		var sub := _find_hud(c)
		if sub:
			return sub
	return null

func _process(delta: float) -> void:
	if run_active and not is_transitioning:
		run_elapsed += delta
		if mode_two_players:
			_update_hud_run_time()
	elif mode_two_players and not is_transitioning and not awaiting_ok:
		_check_start_on_first_thrust()

func _update_hud_run_time() -> void:
	if not current_challenge_node:
		return
	var hud := _find_hud(current_challenge_node)
	if hud and hud.has_method("set_run_time"):
		hud.call("set_run_time", run_elapsed)

func _await_ok() -> void:
	awaiting_ok = true
	var btn := Button.new()
	btn.text = "OK"
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size = Vector2(200, 72)
	btn.add_theme_font_size_override("font_size", 40)
	var playful_font := _playful_font()
	if playful_font:
		btn.add_theme_font_override("font", playful_font)
	btn.set_anchors_preset(Control.PRESET_CENTER)
	btn.offset_top = 240
	fade_layer.add_child(btn)
	btn.grab_focus()
	await btn.pressed
	btn.queue_free()
	awaiting_ok = false

func _check_start_on_first_thrust() -> void:
	var pressed := Input.is_action_pressed("ui_up")
	if pressed and not _prev_thrust:
		run_active = true
	_prev_thrust = pressed

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var code = event.keycode
		if code == KEY_H:
			_toggle_help()
			get_viewport().set_input_as_handled()
			return
		if code == KEY_R:
			# Observe resets to drive context-sensitive hints (challenge still
			# handles the actual reset; we don't consume the event here).
			_on_player_reset()
		if selection_layer and selection_layer.is_inside_tree():
			if code == KEY_1:
				_on_pick_one_player()
				get_viewport().set_input_as_handled()
				return
			if code == KEY_2:
				_on_pick_two_players()
				get_viewport().set_input_as_handled()
				return
		var idx := -1
		if code >= KEY_1 and code <= KEY_9:
			idx = code - KEY_1
		elif code == KEY_0:
			idx = 9
		if idx >= 0 and idx < challenges.size():
			jump_to_challenge(idx)

func _toggle_help() -> void:
	if help_visible:
		_hide_help()
	else:
		_show_help()

func _ensure_help_layer() -> void:
	if help_layer and help_layer.is_inside_tree():
		return
	help_layer = CanvasLayer.new()
	help_layer.layer = 120
	add_child(help_layer)
	help_root = Control.new()
	help_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	help_layer.add_child(help_root)
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.6)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	help_root.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	help_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1040, 700)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 20)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "Help & Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	var playful_font := _playful_font()
	if playful_font:
		title.add_theme_font_override("font", playful_font)
	vb.add_child(title)
	var controls := Label.new()
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 36)
	controls.text = "Arrows: steer (Left/Right), throttle (Up)\nSpace: grab/release piece\nR: reset challenge\n1/2: select players when prompted\n0-9: jump to challenge\nH: toggle this help"
	vb.add_child(controls)
	var sep := HSeparator.new()
	vb.add_child(sep)
	var vol_title := Label.new()
	vol_title.text = "Audio Settings"
	vol_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vol_title.add_theme_font_size_override("font_size", 42)
	if playful_font:
		vol_title.add_theme_font_override("font", playful_font)
	vb.add_child(vol_title)
	var grid := VBoxContainer.new()
	grid.add_theme_constant_override("separation", 10)
	vb.add_child(grid)
	var am := get_node_or_null("/root/AudioManager")
	var master_default := 0.0
	var sfx_default := 0.0
	var music_default := 0.0
	var muted_default := false
	if am:
		if am.has_method("get_master_volume_db"): master_default = am.call("get_master_volume_db")
		if am.has_method("get_sfx_volume_db"): sfx_default = am.call("get_sfx_volume_db")
		if am.has_method("get_music_volume_db"): music_default = am.call("get_music_volume_db")
		if am.has_method("is_muted"): muted_default = am.call("is_muted")
	_add_volume_row(grid, playful_font, "Master", master_default, "set_master_volume_db")
	_add_volume_row(grid, playful_font, "SFX", sfx_default, "set_sfx_volume_db")
	_add_volume_row(grid, playful_font, "Music", music_default, "set_music_volume_db")
	var mute_btn := CheckButton.new()
	mute_btn.text = "Mute all audio"
	mute_btn.button_pressed = muted_default
	mute_btn.add_theme_font_size_override("font_size", 32)
	if playful_font:
		mute_btn.add_theme_font_override("font", playful_font)
	mute_btn.toggled.connect(func(on):
		var amm := get_node_or_null("/root/AudioManager")
		if amm and amm.has_method("set_muted"):
			amm.call("set_muted", on)
	)
	grid.add_child(mute_btn)
	var close := Button.new()
	close.text = "Close"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.custom_minimum_size = Vector2(220, 72)
	close.add_theme_font_size_override("font_size", 48)
	if playful_font:
		close.add_theme_font_override("font", playful_font)
	vb.add_child(close)
	close.pressed.connect(func(): _hide_help())

func _show_help() -> void:
	_ensure_help_layer()
	if help_root:
		help_root.visible = true
	help_visible = true

func _hide_help() -> void:
	if help_root:
		help_root.visible = false
	help_visible = false

func _add_volume_row(parent: Node, font: Variant, label_text: String, default_db: float, setter: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(180, 0)
	label.add_theme_font_size_override("font_size", 32)
	if font:
		label.add_theme_font_override("font", font)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = -40.0
	slider.max_value = 0.0
	slider.step = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value = default_db
	row.add_child(slider)
	var val := Label.new()
	val.text = String.num(slider.value, 0) + " dB"
	val.custom_minimum_size = Vector2(80, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_size_override("font_size", 28)
	if font:
		val.add_theme_font_override("font", font)
	row.add_child(val)
	parent.add_child(row)
	slider.value_changed.connect(func(v):
		val.text = String.num(v, 0) + " dB"
		var am := get_node_or_null("/root/AudioManager")
		if am and am.has_method(setter):
			am.call(setter, v)
	)

func jump_to_challenge(n: int) -> void:
	is_transitioning = false
	if challenge_completed_timer and is_instance_valid(challenge_completed_timer):
		challenge_completed_timer.stop()
	current_challenge_index = n
	load_current_challenge()
	if fade_rect:
		fade_rect.modulate.a = 0.0

func setup_fade_overlay() -> void:
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 1)
	fade_rect.modulate = Color(1, 1, 1, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.offset_left = 0
	fade_rect.offset_top = 0
	fade_rect.offset_right = 0
	fade_rect.offset_bottom = 0
	fade_layer.add_child(fade_rect)
	var swirl_tex := load("res://textures/Swirl.png") as Texture2D
	if swirl_tex:
		var swirl_holder := CenterContainer.new()
		swirl_holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
		swirl_holder.offset_top = 24
		swirl_holder.custom_minimum_size = Vector2(0, 200)
		fade_rect.add_child(swirl_holder)
		var swirl := TextureRect.new()
		swirl.texture = swirl_tex
		swirl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		swirl.custom_minimum_size = Vector2(256, 256)
		swirl_holder.add_child(swirl)
	fade_text = Label.new()
	fade_text.text = ""
	fade_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fade_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fade_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_text.add_theme_font_size_override("font_size", 56)
	fade_text.add_theme_color_override("font_color", Color(1, 1, 1))
	fade_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	fade_text.add_theme_constant_override("outline_size", 5)
	var playful_font := _playful_font()
	if playful_font:
		fade_text.add_theme_font_override("font", playful_font)
	fade_layer.add_child(fade_text)

func show_player_mode_prompt() -> void:
	selection_layer = CanvasLayer.new()
	selection_layer.layer = 90
	add_child(selection_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	selection_layer.add_child(root)
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.5)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 12)
	stack.set_anchors_preset(Control.PRESET_CENTER)
	center.add_child(stack)
	var swirl_tex1 := load("res://textures/Swirl.png") as Texture2D
	if swirl_tex1:
		var swirl1 := TextureRect.new()
		swirl1.texture = swirl_tex1
		swirl1.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		swirl1.custom_minimum_size = Vector2(320, 320)
		stack.add_child(swirl1)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 220)
	stack.add_child(panel)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var ask := Label.new()
	ask.text = "How many players (1 or 2)?"
	ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ask.add_theme_font_size_override("font_size", 48)
	var playful_font := _playful_font()
	if playful_font:
		ask.add_theme_font_override("font", playful_font)
	vb.add_child(ask)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 24)
	vb.add_child(hb)
	var one := Button.new()
	one.text = "One Player [1]"
	one.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	one.add_theme_font_size_override("font_size", 36)
	if playful_font:
		one.add_theme_font_override("font", playful_font)
	one.pressed.connect(_on_pick_one_player)
	hb.add_child(one)
	var two := Button.new()
	two.text = "Two Players [2]"
	two.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	two.add_theme_font_size_override("font_size", 36)
	if playful_font:
		two.add_theme_font_override("font", playful_font)
	two.pressed.connect(_on_pick_two_players)
	hb.add_child(two)
	var back := Button.new()
	back.text = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.add_theme_font_size_override("font_size", 28)
	if playful_font:
		back.add_theme_font_override("font", playful_font)
	back.pressed.connect(func():
		if selection_layer: selection_layer.queue_free()
		selection_layer = null
		show_main_menu()
	)
	vb.add_child(back)

func _on_pick_one_player() -> void:
	mode_two_players = false
	current_challenge_index = 0
	if selection_layer: selection_layer.queue_free()
	if fade_rect: fade_rect.modulate.a = 1.0
	current_player_idx = 0
	if fade_text:
		fade_text.text = ""
	load_current_challenge()
	await get_tree().process_frame
	if fade_rect:
		var tw := create_tween()
		tw.tween_property(fade_rect, "modulate:a", 0.0, 0.8)

func _on_pick_two_players() -> void:
	mode_two_players = true
	current_challenge_index = 0
	show_name_entry()

func show_name_entry() -> void:
	for c in selection_layer.get_children():
		c.queue_free()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	selection_layer.add_child(root)
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.5)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var stack2 := VBoxContainer.new()
	stack2.alignment = BoxContainer.ALIGNMENT_CENTER
	stack2.add_theme_constant_override("separation", 12)
	stack2.set_anchors_preset(Control.PRESET_CENTER)
	center.add_child(stack2)
	var swirl_tex2 := load("res://textures/Swirl.png") as Texture2D
	if swirl_tex2:
		var swirl2 := TextureRect.new()
		swirl2.texture = swirl_tex2
		swirl2.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		swirl2.custom_minimum_size = Vector2(320, 320)
		stack2.add_child(swirl2)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 320)
	stack2.add_child(panel)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "Enter Player Names"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	var playful_font2 := _playful_font()
	if playful_font2:
		title.add_theme_font_override("font", playful_font2)
	vb.add_child(title)
	var l1 := LineEdit.new()
	l1.placeholder_text = "Player 1 Name"
	l1.text = player_names[0]
	l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l1.add_theme_font_size_override("font_size", 32)
	if playful_font2:
		l1.add_theme_font_override("font", playful_font2)
	vb.add_child(l1)
	var l2 := LineEdit.new()
	l2.placeholder_text = "Player 2 Name"
	l2.text = player_names[1]
	l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l2.add_theme_font_size_override("font_size", 32)
	if playful_font2:
		l2.add_theme_font_override("font", playful_font2)
	vb.add_child(l2)
	l1.focus_entered.connect(func(): l1.select_all())
	l2.focus_entered.connect(func(): l2.select_all())
	var start := Button.new()
	start.text = "Start"
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.add_theme_font_size_override("font_size", 36)
	if playful_font2:
		start.add_theme_font_override("font", playful_font2)
	start.pressed.connect(func():
		player_names[0] = l1.text.strip_edges()
		if player_names[0] == "": player_names[0] = "Player 1"
		player_names[1] = l2.text.strip_edges()
		if player_names[1] == "": player_names[1] = "Player 2"
		selection_layer.queue_free()
		if fade_rect: fade_rect.modulate.a = 1.0
		current_player_idx = 0
		load_current_challenge()
		await get_tree().process_frame
		if fade_rect:
			var tw := create_tween()
			tw.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	)
	vb.add_child(start)
	l1.grab_focus()

func _reset_to_start() -> void:
	player_scores = [0, 0]
	last_times = [-1.0, -1.0]
	current_player_idx = 0
	run_elapsed = 0.0
	run_active = false
	_prev_thrust = false
	awaiting_ok = false
	mode_two_players = false
	player_names = ["Player 1", "Player 2"]
	current_challenge_index = 0
	if fade_text:
		fade_text.text = ""
	if fade_rect:
		fade_rect.modulate.a = 0.0
	for child in get_children():
		if not _is_persistent(child):
			child.queue_free()
	await get_tree().process_frame
	show_main_menu()

# === Player-experience: overlays, menu, hints, progression ================

func _playful_font() -> Font:
	return load("res://fonts/PlaywriteGBJ.ttf")

func _ensure_info_layer() -> void:
	if info_layer and is_instance_valid(info_layer):
		return
	info_layer = CanvasLayer.new()
	info_layer.layer = 70
	add_child(info_layer)
	var font := _playful_font()
	# Top mission-briefing banner
	briefing_panel = PanelContainer.new()
	briefing_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	briefing_panel.offset_top = 0
	briefing_panel.offset_left = 0
	briefing_panel.offset_right = 0
	briefing_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	briefing_panel.modulate.a = 0.0
	briefing_panel.visible = false
	var briefing_sb := StyleBoxFlat.new()
	briefing_sb.bg_color = Color(0.05, 0.06, 0.09, 1.0)
	briefing_sb.content_margin_left = 40
	briefing_sb.content_margin_right = 40
	briefing_sb.content_margin_top = 18
	briefing_sb.content_margin_bottom = 24
	briefing_sb.border_width_bottom = 4
	briefing_sb.border_color = Color(1, 0.86, 0.45, 0.7)
	briefing_panel.add_theme_stylebox_override("panel", briefing_sb)
	info_layer.add_child(briefing_panel)
	var bcenter := CenterContainer.new()
	briefing_panel.add_child(bcenter)
	var bvb := VBoxContainer.new()
	bvb.alignment = BoxContainer.ALIGNMENT_CENTER
	bvb.add_theme_constant_override("separation", 6)
	bcenter.add_child(bvb)
	briefing_stats_label = Label.new()
	briefing_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	briefing_stats_label.add_theme_font_size_override("font_size", 34)
	briefing_stats_label.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0))
	briefing_stats_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	briefing_stats_label.add_theme_constant_override("outline_size", 4)
	if font: briefing_stats_label.add_theme_font_override("font", font)
	bvb.add_child(briefing_stats_label)
	briefing_loc_label = Label.new()
	briefing_loc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	briefing_loc_label.add_theme_font_size_override("font_size", 56)
	briefing_loc_label.add_theme_color_override("font_color", Color(1, 0.86, 0.45))
	briefing_loc_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	briefing_loc_label.add_theme_constant_override("outline_size", 5)
	if font: briefing_loc_label.add_theme_font_override("font", font)
	bvb.add_child(briefing_loc_label)
	briefing_text_label = Label.new()
	briefing_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	briefing_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	briefing_text_label.custom_minimum_size = Vector2(1400, 0)
	briefing_text_label.add_theme_font_size_override("font_size", 42)
	briefing_text_label.add_theme_color_override("font_color", Color(1, 1, 1))
	briefing_text_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	briefing_text_label.add_theme_constant_override("outline_size", 4)
	if font: briefing_text_label.add_theme_font_override("font", font)
	bvb.add_child(briefing_text_label)
	# Bottom subtle hint label
	hint_label = Label.new()
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint_label.offset_top = -140
	hint_label.offset_bottom = -48
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_size_override("font_size", 30)
	hint_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hint_label.add_theme_constant_override("outline_size", 5)
	if font: hint_label.add_theme_font_override("font", font)
	hint_label.modulate.a = 0.0
	hint_label.visible = false
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_layer.add_child(hint_label)

func show_briefing(location: String, text: String) -> void:
	_ensure_info_layer()
	briefing_loc_label.text = location
	briefing_text_label.text = text
	_update_briefing_stats()
	if _briefing_tween and _briefing_tween.is_valid():
		_briefing_tween.kill()
	briefing_panel.modulate.a = 0.0
	briefing_panel.visible = true
	_briefing_tween = create_tween()
	_briefing_tween.tween_property(briefing_panel, "modulate:a", 1.0, 0.45)
	_briefing_tween.tween_interval(4.5)
	_briefing_tween.tween_property(briefing_panel, "modulate:a", 0.0, 0.7)

func _update_briefing_stats() -> void:
	if not is_instance_valid(briefing_stats_label):
		return
	if mode_two_players:
		briefing_stats_label.visible = false
		return
	briefing_stats_label.visible = true
	var sm := get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("get_stats"):
		var st: Dictionary = sm.call("get_stats")
		var attempts: int = int(st.get("attempts", 0))
		var completed: int = int(st.get("completed_count", 0))
		var best_v: Variant = st.get("best_time_seconds", null)
		var best_str: String = "-" if best_v == null else "%.2f" % float(best_v)
		briefing_stats_label.text = "Attempts: %d    Completed: %d    Best: %s s" % [attempts, completed, best_str]
	else:
		briefing_stats_label.text = ""

func queue_hint(text: String) -> void:
	_ensure_info_layer()
	_hint_queue.append(text)
	if not _hint_running:
		_run_hint_queue()

func _run_hint_queue() -> void:
	_hint_running = true
	while _hint_queue.size() > 0:
		var t: String = str(_hint_queue.pop_front())
		if not is_instance_valid(hint_label):
			break
		hint_label.text = t
		hint_label.modulate.a = 0.0
		hint_label.visible = true
		var tin := create_tween()
		tin.tween_property(hint_label, "modulate:a", 0.95, 0.35)
		await tin.finished
		await get_tree().create_timer(3.6).timeout
		if not is_instance_valid(hint_label):
			break
		var tout := create_tween()
		tout.tween_property(hint_label, "modulate:a", 0.0, 0.55)
		await tout.finished
	if is_instance_valid(hint_label):
		hint_label.visible = false
	_hint_running = false

func _clear_hints() -> void:
	_hint_queue.clear()
	if is_instance_valid(hint_label):
		hint_label.visible = false
		hint_label.modulate.a = 0.0

func _on_level_started() -> void:
	var idx: int = current_challenge_index
	level_attempts = 0
	hint_index = 0
	_clear_hints()
	if idx < 0 or idx >= LEVEL_META.size():
		return
	var meta: Dictionary = LEVEL_META[idx]
	show_briefing("Assignment %d \u2014 %s" % [idx + 1, str(meta["location"])], str(meta["briefing"]))
	if mode_two_players:
		return
	var sm := get_node_or_null("/root/SaveManager")
	if idx == 0 and sm and sm.has_method("has_seen_intro") and not sm.call("has_seen_intro", "onboarding"):
		queue_hint("Use WASD or Arrow Keys to drive.")
		queue_hint("Press Space to pick up the package with the forklift.")
		queue_hint("Deliver the package to the goal pad.")
		sm.call("mark_intro_seen", "onboarding")
	var intro: String = str(meta.get("intro", ""))
	var intro_id: String = str(meta.get("intro_id", ""))
	if intro != "" and sm and sm.has_method("has_seen_intro") and not sm.call("has_seen_intro", intro_id):
		queue_hint(intro)
		sm.call("mark_intro_seen", intro_id)

func _on_player_reset() -> void:
	if mode_two_players or is_transitioning:
		return
	level_attempts += 1
	if level_attempts == 3 or (level_attempts > 3 and (level_attempts - 3) % 2 == 0):
		_show_next_struggle_hint()

func _show_next_struggle_hint() -> void:
	var idx: int = current_challenge_index
	if idx < 0 or idx >= LEVEL_META.size():
		return
	var hints: Array = LEVEL_META[idx].get("hints", [])
	if hints.is_empty():
		return
	queue_hint("Hint: " + str(hints[hint_index % hints.size()]))
	hint_index += 1

func _record_level_completion(idx: int, time_sec: float) -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null:
		return
	if sm.has_method("record_level_result"):
		sm.call("record_level_result", idx, time_sec)
	if sm.has_method("unlock_through"):
		sm.call("unlock_through", min(idx + 1, challenges.size() - 1))
	# Compose a short completion message shown during the fade transition.
	var loc := ""
	var medal := ""
	if idx >= 0 and idx < LEVEL_META.size():
		loc = str(LEVEL_META[idx]["location"])
		if sm.has_method("get_medal"):
			medal = str(sm.call("get_medal", idx, float(LEVEL_META[idx]["gold"]), float(LEVEL_META[idx]["silver"])))
	var best := time_sec
	if sm.has_method("get_level_best"):
		var b: float = sm.call("get_level_best", idx)
		if b >= 0.0:
			best = b
	var medal_str := ""
	match medal:
		"gold": medal_str = "Gold medal!"
		"silver": medal_str = "Silver medal"
		"bronze": medal_str = "Delivered"
		_: medal_str = ""
	if fade_text:
		var msg := "Delivery Complete"
		if loc != "":
			msg += " \u2014 " + loc
		msg += "\nTime %.2fs    Best %.2fs" % [time_sec, best]
		if medal_str != "":
			msg += "\n" + medal_str
		fade_text.text = msg
		fade_text.add_theme_color_override("font_color", Color(1, 1, 1))

func _menu_button(text: String, font: Font) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(560, 84)
	b.add_theme_font_size_override("font_size", 40)
	if font: b.add_theme_font_override("font", font)
	return b

func show_main_menu() -> void:
	# Tear down any loaded challenge / transient layers, keep overlays.
	if selection_layer and is_instance_valid(selection_layer):
		selection_layer.queue_free()
		selection_layer = null
	for child in get_children():
		if not _is_persistent(child):
			child.queue_free()
	_clear_hints()
	if is_instance_valid(briefing_panel):
		briefing_panel.visible = false
	if fade_rect:
		fade_rect.modulate.a = 0.0
	if fade_text:
		fade_text.text = ""
	current_challenge_node = null
	run_active = false
	is_transitioning = false
	var font := _playful_font()
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 95
	add_child(menu_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(root)
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.6)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	center.add_child(vb)
	var title := Label.new()
	title.text = "Forklift Logistics Co."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 76)
	if font: title.add_theme_font_override("font", font)
	vb.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Operator Delivery Assignments"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 34)
	if font: subtitle.add_theme_font_override("font", font)
	vb.add_child(subtitle)
	var sm := get_node_or_null("/root/SaveManager")
	var max_unlk := 0
	if sm and sm.has_method("max_unlocked"):
		max_unlk = int(sm.call("max_unlocked"))
	var cont := _menu_button("Continue (Assignment %d)" % (max_unlk + 1), font)
	cont.pressed.connect(func(): _start_single_player(max_unlk))
	vb.add_child(cont)
	var ng := _menu_button("New Game", font)
	ng.pressed.connect(func():
		if menu_layer: menu_layer.queue_free()
		show_player_mode_prompt()
	)
	vb.add_child(ng)
	var ls := _menu_button("Level Select", font)
	ls.pressed.connect(func():
		if menu_layer: menu_layer.queue_free()
		show_level_select()
	)
	vb.add_child(ls)
	var st := _menu_button("Settings", font)
	st.pressed.connect(func(): _show_help())
	vb.add_child(st)
	var tip := Label.new()
	tip.text = "Press H any time for help & audio settings"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 24)
	if font: tip.add_theme_font_override("font", font)
	vb.add_child(tip)

func _start_single_player(start_idx: int) -> void:
	mode_two_players = false
	current_player_idx = 0
	current_challenge_index = clampi(start_idx, 0, challenges.size() - 1)
	is_transitioning = false
	if challenge_completed_timer and is_instance_valid(challenge_completed_timer):
		challenge_completed_timer.stop()
	if menu_layer and is_instance_valid(menu_layer):
		menu_layer.queue_free()
	if selection_layer and is_instance_valid(selection_layer):
		selection_layer.queue_free()
		selection_layer = null
	if fade_text: fade_text.text = ""
	if fade_rect: fade_rect.modulate.a = 1.0
	load_current_challenge()
	await get_tree().process_frame
	if fade_rect:
		var tw := create_tween()
		tw.tween_property(fade_rect, "modulate:a", 0.0, 0.8)

func show_level_select() -> void:
	var font := _playful_font()
	var sm := get_node_or_null("/root/SaveManager")
	selection_layer = CanvasLayer.new()
	selection_layer.layer = 90
	add_child(selection_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	selection_layer.add_child(root)
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.78)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	center.add_child(vb)
	var title := Label.new()
	title.text = "Select Assignment"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 60)
	if font: title.add_theme_font_override("font", font)
	vb.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 18)
	vb.add_child(grid)
	for i in range(challenges.size()):
		grid.add_child(_make_level_cell(i, sm, font))
	var back := Button.new()
	back.text = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size = Vector2(260, 72)
	back.add_theme_font_size_override("font_size", 36)
	if font: back.add_theme_font_override("font", font)
	back.pressed.connect(func():
		if selection_layer: selection_layer.queue_free()
		selection_layer = null
		show_main_menu()
	)
	vb.add_child(back)

func _make_level_cell(i: int, sm, font: Font) -> Control:
	var unlocked := true
	if sm and sm.has_method("is_unlocked"):
		unlocked = bool(sm.call("is_unlocked", i))
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 150)
	var cvb := VBoxContainer.new()
	cvb.add_theme_constant_override("separation", 4)
	panel.add_child(cvb)
	var loc := ("Level %d" % (i + 1))
	if i < LEVEL_META.size():
		loc = str(LEVEL_META[i]["location"])
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(420, 86)
	btn.add_theme_font_size_override("font_size", 28)
	if font: btn.add_theme_font_override("font", font)
	if unlocked:
		btn.text = "%d. %s" % [i + 1, loc]
		btn.pressed.connect(func(): _start_single_player(i))
	else:
		btn.text = "%d. Locked" % (i + 1)
		btn.disabled = true
	cvb.add_child(btn)
	var info := Label.new()
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 24)
	if font: info.add_theme_font_override("font", font)
	if unlocked and sm and sm.has_method("get_level_best"):
		var best: float = sm.call("get_level_best", i)
		if best >= 0.0:
			var medal := ""
			if sm.has_method("get_medal") and i < LEVEL_META.size():
				medal = str(sm.call("get_medal", i, float(LEVEL_META[i]["gold"]), float(LEVEL_META[i]["silver"])))
			var ms := ""
			match medal:
				"gold": ms = "  [Gold]"
				"silver": ms = "  [Silver]"
				"bronze": ms = "  [Bronze]"
			info.text = "Best: %.2fs%s" % [best, ms]
		else:
			info.text = "Not yet completed"
	else:
		info.text = "Locked"
	cvb.add_child(info)
	return panel
