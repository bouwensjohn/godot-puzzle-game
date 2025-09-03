extends Node

# Centralized game configuration
# Screen dimensions - should match project.godot window settings
const SCREEN_WIDTH := 2000.0
const SCREEN_HEIGHT := 1280.0

# Base dimensions for scaling calculations
const BASE_WIDTH := 1000.0
const BASE_HEIGHT := 640.0

# Scaling factors
const SCALE_FACTOR_X := SCREEN_WIDTH / BASE_WIDTH
const SCALE_FACTOR_Y := SCREEN_HEIGHT / BASE_HEIGHT
const UI_SCALE := SCALE_FACTOR_X  # Use X scale for UI elements

# Game constants
const GRAB_RADIUS := 36.0
const SNAP_RADIUS := 28.0
const ANGLE_TOL := deg_to_rad(20.0)

# UI Constants
const BASE_FONT_SIZE := 16
const SCALED_FONT_SIZE := int(BASE_FONT_SIZE * UI_SCALE)

# Convenience properties for backward compatibility
var W: float:
	get: return SCREEN_WIDTH

var H: float:
	get: return SCREEN_HEIGHT
