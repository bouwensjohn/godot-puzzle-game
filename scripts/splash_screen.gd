extends Control

signal splash_finished

func _ready() -> void:
	# Timer signal is already connected in the scene file
	$VersionLabel.add_theme_font_size_override("font_size", 32)
	$CopyrightLabel.add_theme_font_size_override("font_size", 32)

func _on_timer_timeout() -> void:
	# Emit signal to indicate splash screen is done
	splash_finished.emit()
	# Remove this scene from the tree
	queue_free()
