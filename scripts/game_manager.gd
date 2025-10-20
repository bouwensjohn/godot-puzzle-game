extends Node2D

var splash_screen_scene = preload("res://scenes/SplashScreen.tscn")
var main_game_scene = preload("res://scenes/Main.tscn")

var current_challenge_index = 0
var challenges = []
var challenge_completed_timer: Timer
var is_transitioning = false

func _ready() -> void:
	# Initialize challenges array for future expansion
	setup_challenges()
	
	# Setup completion timer
	setup_completion_timer()
	
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
	# Load the main game after splash screen
	load_current_challenge()

func load_current_challenge() -> void:
	# Clear any existing children (splash screen should already be freed)
	for child in get_children():
		if child != challenge_completed_timer:  # Don't free the timer
			child.queue_free()
	
	# Wait a frame to ensure cleanup
	await get_tree().process_frame
	
	# Load the current challenge
	if current_challenge_index < challenges.size():
		var challenge = challenges[current_challenge_index]
		print("Loading challenge ", current_challenge_index, ": ", challenge.name)
		var game_instance = challenge.scene.instantiate()
		add_child(game_instance)
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

func _on_completion_timer_timeout() -> void:
	is_transitioning = false
	next_challenge()

func get_current_challenge_info() -> Dictionary:
	if current_challenge_index < challenges.size():
		return challenges[current_challenge_index]
	return {}

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var code = event.keycode
		var idx := -1
		if code >= KEY_1 and code <= KEY_9:
			idx = code - KEY_1
		elif code == KEY_0:
			idx = 9
		if idx >= 0 and idx < challenges.size():
			jump_to_challenge(idx)

func jump_to_challenge(n: int) -> void:
	is_transitioning = false
	if challenge_completed_timer and is_instance_valid(challenge_completed_timer):
		challenge_completed_timer.stop()
	current_challenge_index = n
	load_current_challenge()
