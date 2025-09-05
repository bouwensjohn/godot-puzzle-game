extends Node

# Simple test script to validate game flow
func _ready():
	print("=== Game Flow Test ===")
	
	# Test 1: Check if GameManager exists
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		print("✓ GameManager found")
		
		# Test challenges array
		if game_manager.has_method("get_current_challenge_info"):
			var challenge_info = game_manager.get_current_challenge_info()
			print("✓ Current challenge: ", challenge_info.get("name", "Unknown"))
		
		# Test challenge completion method
		if game_manager.has_method("on_challenge_completed"):
			print("✓ Challenge completion method exists")
	else:
		print("✗ GameManager not found")
	
	# Test 2: Check AudioManager
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager:
		print("✓ AudioManager found")
		if audio_manager.has_method("triumph"):
			print("✓ Triumph sound method exists")
	else:
		print("✗ AudioManager not found")
	
	# Test 3: Check scene files exist
	var main_scene = load("res://scenes/Main.tscn")
	var challenge_two_scene = load("res://scenes/ChallengeTwo.tscn")
	
	if main_scene:
		print("✓ Main scene loads successfully")
	else:
		print("✗ Main scene failed to load")
		
	if challenge_two_scene:
		print("✓ ChallengeTwo scene loads successfully")
	else:
		print("✗ ChallengeTwo scene failed to load")
	
	print("=== Test Complete ===")
	
	# Clean up
	queue_free()
