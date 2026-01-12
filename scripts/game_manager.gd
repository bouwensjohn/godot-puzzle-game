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

func _ready() -> void:
	# Initialize challenges array for future expansion
	setup_challenges()
	
	# Setup completion timer
	setup_completion_timer()
	setup_fade_overlay()
	
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
	show_player_mode_prompt()

func load_current_challenge() -> void:
	# Clear any existing children (splash screen should already be freed)
	for child in get_children():
		if child != challenge_completed_timer and child != fade_layer:  # Don't free the timer
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
	var playful_font_path := "res://fonts/A Gentle Touch.ttf"
	var playful_font := load(playful_font_path)
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
	var playful_font_path := "res://fonts/A Gentle Touch.ttf"
	var playful_font := load(playful_font_path)
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
	vol_title.text = "Volumes (dB)"
	vol_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vol_title.add_theme_font_size_override("font_size", 42)
	if playful_font:
		vol_title.add_theme_font_override("font", playful_font)
	vb.add_child(vol_title)
	var grid := VBoxContainer.new()
	grid.add_theme_constant_override("separation", 10)
	vb.add_child(grid)
	var am := get_node_or_null("/root/AudioManager")
	var engine_default := -8.0
	var skid_default := -16.0
	var bgm_default := -12.0
	if am:
		if am.has_method("get_engine_volume_db"): engine_default = am.call("get_engine_volume_db")
		if am.has_method("get_skid_volume_db"): skid_default = am.call("get_skid_volume_db")
		if am.has_method("get_bgm_volume_db"): bgm_default = am.call("get_bgm_volume_db")
	var engine_row := HBoxContainer.new()
	engine_row.add_theme_constant_override("separation", 12)
	var engine_label := Label.new()
	engine_label.text = "Throttle"
	engine_label.custom_minimum_size = Vector2(180, 0)
	engine_label.add_theme_font_size_override("font_size", 32)
	if playful_font:
		engine_label.add_theme_font_override("font", playful_font)
	engine_row.add_child(engine_label)
	var engine_slider := HSlider.new()
	engine_slider.min_value = -40.0
	engine_slider.max_value = 0.0
	engine_slider.step = 1.0
	engine_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	engine_slider.value = engine_default
	engine_row.add_child(engine_slider)
	var engine_val := Label.new()
	engine_val.text = String.num(engine_slider.value, 0) + " dB"
	engine_val.custom_minimum_size = Vector2(80, 0)
	engine_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	engine_val.add_theme_font_size_override("font_size", 28)
	if playful_font:
		engine_val.add_theme_font_override("font", playful_font)
	engine_row.add_child(engine_val)
	grid.add_child(engine_row)
	engine_slider.value_changed.connect(func(v):
		engine_val.text = String.num(v, 0) + " dB"
		var am2 := get_node_or_null("/root/AudioManager")
		if am2 and am2.has_method("set_engine_volume_db"):
			am2.call("set_engine_volume_db", v)
	)
	var skid_row := HBoxContainer.new()
	skid_row.add_theme_constant_override("separation", 12)
	var skid_label := Label.new()
	skid_label.text = "Skid"
	skid_label.custom_minimum_size = Vector2(180, 0)
	skid_label.add_theme_font_size_override("font_size", 32)
	if playful_font:
		skid_label.add_theme_font_override("font", playful_font)
	skid_row.add_child(skid_label)
	var skid_slider := HSlider.new()
	skid_slider.min_value = -40.0
	skid_slider.max_value = 0.0
	skid_slider.step = 1.0
	skid_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skid_slider.value = skid_default
	skid_row.add_child(skid_slider)
	var skid_val := Label.new()
	skid_val.text = String.num(skid_slider.value, 0) + " dB"
	skid_val.custom_minimum_size = Vector2(80, 0)
	skid_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skid_val.add_theme_font_size_override("font_size", 28)
	if playful_font:
		skid_val.add_theme_font_override("font", playful_font)
	skid_row.add_child(skid_val)
	grid.add_child(skid_row)
	skid_slider.value_changed.connect(func(v):
		skid_val.text = String.num(v, 0) + " dB"
		var am3 := get_node_or_null("/root/AudioManager")
		if am3 and am3.has_method("set_skid_volume_db"):
			am3.call("set_skid_volume_db", v)
	)
	var bgm_row := HBoxContainer.new()
	bgm_row.add_theme_constant_override("separation", 12)
	var bgm_label := Label.new()
	bgm_label.text = "Music"
	bgm_label.custom_minimum_size = Vector2(180, 0)
	bgm_label.add_theme_font_size_override("font_size", 32)
	if playful_font:
		bgm_label.add_theme_font_override("font", playful_font)
	bgm_row.add_child(bgm_label)
	var bgm_slider := HSlider.new()
	bgm_slider.min_value = -40.0
	bgm_slider.max_value = 0.0
	bgm_slider.step = 1.0
	bgm_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bgm_slider.value = bgm_default
	bgm_row.add_child(bgm_slider)
	var bgm_val := Label.new()
	bgm_val.text = String.num(bgm_slider.value, 0) + " dB"
	bgm_val.custom_minimum_size = Vector2(80, 0)
	bgm_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bgm_val.add_theme_font_size_override("font_size", 28)
	if playful_font:
		bgm_val.add_theme_font_override("font", playful_font)
	bgm_row.add_child(bgm_val)
	grid.add_child(bgm_row)
	bgm_slider.value_changed.connect(func(v):
		bgm_val.text = String.num(v, 0) + " dB"
		var am4 := get_node_or_null("/root/AudioManager")
		if am4 and am4.has_method("set_bgm_volume_db"):
			am4.call("set_bgm_volume_db", v)
	)
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
	var playful_font_path := "res://fonts/A Gentle Touch.ttf"
	var playful_font := load(playful_font_path)
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
	var playful_font_path := "res://fonts/A Gentle Touch.ttf"
	var playful_font := load(playful_font_path)
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
	# var playful_font_path := "res://fonts/A Gentle Touch.ttf"
	# var playful_font := load(playful_font_path)
	if playful_font:
		one.add_theme_font_override("font", playful_font)
	one.pressed.connect(_on_pick_one_player)
	hb.add_child(one)
	var two := Button.new()
	two.text = "Two Players [2]"
	two.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	two.add_theme_font_size_override("font_size", 36)
	# var playful_font_path := "res://fonts/A Gentle Touch.ttf"
	# var playful_font := load(playful_font_path)
	if playful_font:
		two.add_theme_font_override("font", playful_font)
	two.pressed.connect(_on_pick_two_players)
	hb.add_child(two)

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
	var playful_font_path2 := "res://fonts/A Gentle Touch.ttf"
	var playful_font2 := load(playful_font_path2)
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
		if child != challenge_completed_timer and child != fade_layer:
			child.queue_free()
	await get_tree().process_frame
	show_player_mode_prompt()
