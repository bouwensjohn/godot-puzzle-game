extends Node

var _click: AudioStreamPlayer
var _release: AudioStreamPlayer
var _engine: AudioStreamPlayer

func _ready() -> void:
	_refresh_nodes()
	_create_beep_sounds()

func _refresh_nodes() -> void:
	# Try to resolve players in the running scene. Safe if not found.
	var root := get_tree().get_current_scene()
	if root == null:
		return
	_click = root.get_node_or_null("Audio/Click")
	_release = root.get_node_or_null("Audio/Release")
	_engine = root.get_node_or_null("Audio/Engine")

func _create_beep_sounds() -> void:
	# Create simple beep sounds using AudioStreamWAV
	if _click:
		_click.stream = _generate_beep(1000.0, 0.1)
		_click.volume_db = -6.0
	
	if _release:
		_release.stream = _generate_beep(600.0, 0.12)
		_release.volume_db = -6.0
	
	if _engine:
		_engine.stream = _generate_beep(200.0, 1.0)
		_engine.volume_db = -80.0

func _generate_beep(frequency: float, duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var samples := int(sample_rate * duration)
	var data := PackedFloat32Array()
	
	for i in samples:
		var t := float(i) / sample_rate
		var amplitude := sin(2.0 * PI * frequency * t) * 0.3
		# Fade out to avoid clicks
		if t > duration * 0.8:
			var fade := 1.0 - (t - duration * 0.8) / (duration * 0.2)
			amplitude *= fade
		data.append(amplitude)
	
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	
	# Convert float data to 16-bit PCM (little-endian)
	var pcm_data := PackedByteArray()
	for sample in data:
		var int_sample := int(sample * 32767.0)
		int_sample = clamp(int_sample, -32768, 32767)
		# Encode as 16-bit little-endian
		pcm_data.append(int_sample & 0xFF)
		pcm_data.append((int_sample >> 8) & 0xFF)
	
	wav.data = pcm_data
	return wav

func click() -> void:
	if _click == null: _refresh_nodes()
	if _click and _click.stream:
		_click.play()

func release() -> void:
	if _release == null: _refresh_nodes()
	if _release and _release.stream:
		_release.play()

func thrust(on: bool) -> void:
	if _engine == null: _refresh_nodes()
	if _engine and _engine.stream:
		if on:
			_engine.volume_db = -12.0
			if not _engine.playing:
				_engine.play()
		else:
			_engine.volume_db = -80.0
			if _engine.playing:
				_engine.stop()
