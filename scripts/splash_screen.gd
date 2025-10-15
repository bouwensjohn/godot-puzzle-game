extends Control

signal splash_finished

func _ready() -> void:
	# Timer signal is already connected in the scene file
	$VersionLabel.add_theme_font_size_override("font_size", 32)
	$CopyrightLabel.add_theme_font_size_override("font_size", 32)
	# Ensure this Control uses the viewport as its reference rect
	self.top_level = true
	self.set_anchors_preset(Control.PRESET_FULL_RECT)
	self.offset_left = 0
	self.offset_top = 0
	self.offset_right = 0
	self.offset_bottom = 0
	var splash := $SplashImage as TextureRect
	# Switch to anchor-based layout and stretch to full viewport
	splash.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash.offset_left = 0
	splash.offset_top = 0
	splash.offset_right = 0
	splash.offset_bottom = 0
	splash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# Ensure texture is set explicitly
	splash.texture = load("res://textures/pushy_splash.jpg")
	# Wait a frame so anchors/layout apply, then ensure visible and sized
	await get_tree().process_frame
	splash.position = Vector2.ZERO
	splash.size = get_viewport_rect().size
	splash.visible = true
	# Place labels bottom-right using anchors so they stay visible
	var ver := $VersionLabel as Label
	ver.layout_mode = 1
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_right = -32
	ver.offset_bottom = -72
	var cr := $CopyrightLabel as Label
	cr.layout_mode = 1
	cr.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	cr.offset_right = -32
	cr.offset_bottom = -32

func _on_timer_timeout() -> void:
	# Emit signal to indicate splash screen is done
	splash_finished.emit()
	# Remove this scene from the tree
	queue_free()
