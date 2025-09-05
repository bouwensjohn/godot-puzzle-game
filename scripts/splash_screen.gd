extends Control

signal splash_finished

func _ready() -> void:
	# Timer signal is already connected in the scene file
	pass

func _on_timer_timeout() -> void:
	# Emit signal to indicate splash screen is done
	splash_finished.emit()
	# Remove this scene from the tree
	queue_free()
