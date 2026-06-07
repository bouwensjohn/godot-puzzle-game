extends Node

var save_path: String = "user://save.json"
var data: Dictionary = {
	"completed_count": 0,
	"attempts": 0,
	"best_time_seconds": null,
	"last_played_iso": "",
	# Progression
	"unlocked_level": 0,
	"level_best_times": {},
	# First-time onboarding / mechanic intros that have already been shown
	"seen_intros": [],
	# Audio settings (dB), persisted across sessions
	"audio": {
		"master_db": 0.0,
		"sfx_db": 0.0,
		"music_db": 0.0,
		"muted": false
	}
}

func _ready() -> void:
	load_save()

func load_save() -> void:
	var f: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if f:
		var txt: String = f.get_as_text()
		f.close()
		if txt.length() > 0:
			var parsed: Variant = JSON.parse_string(txt)
			if typeof(parsed) == TYPE_DICTIONARY:
				# Merge parsed values over defaults so new fields always exist
				var loaded := parsed as Dictionary
				for k in loaded.keys():
					data[k] = loaded[k]
				_ensure_defaults()
	else:
		# Create an empty file on first run
		save()

func _ensure_defaults() -> void:
	if not data.has("unlocked_level"): data["unlocked_level"] = 0
	if not data.has("level_best_times") or typeof(data["level_best_times"]) != TYPE_DICTIONARY:
		data["level_best_times"] = {}
	if not data.has("seen_intros") or typeof(data["seen_intros"]) != TYPE_ARRAY:
		data["seen_intros"] = []
	if not data.has("audio") or typeof(data["audio"]) != TYPE_DICTIONARY:
		data["audio"] = {"master_db": 0.0, "sfx_db": 0.0, "music_db": 0.0, "muted": false}
	else:
		var a: Dictionary = data["audio"]
		if not a.has("master_db"): a["master_db"] = 0.0
		if not a.has("sfx_db"): a["sfx_db"] = 0.0
		if not a.has("music_db"): a["music_db"] = 0.0
		if not a.has("muted"): a["muted"] = false

func save() -> void:
	var f: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func record_attempt(success: bool, time_sec: float) -> void:
	data.attempts += 1
	data.last_played_iso = Time.get_datetime_string_from_system(true)
	if success:
		data.completed_count += 1
		if data.best_time_seconds == null or time_sec < float(data.best_time_seconds):
			data.best_time_seconds = time_sec
	save()

func get_stats() -> Dictionary:
	return data.duplicate(true)

# --- Progression ---------------------------------------------------------

func max_unlocked() -> int:
	return int(data.get("unlocked_level", 0))

func is_unlocked(idx: int) -> bool:
	return idx <= max_unlocked()

func unlock_through(idx: int) -> void:
	if idx > max_unlocked():
		data["unlocked_level"] = idx
		save()

func record_level_result(idx: int, time_sec: float) -> void:
	# Track best time per level (string keys, since JSON keys are strings)
	var key := str(idx)
	var bests: Dictionary = data.get("level_best_times", {})
	if not bests.has(key) or time_sec < float(bests[key]):
		bests[key] = time_sec
	data["level_best_times"] = bests
	save()

func get_level_best(idx: int) -> float:
	var bests: Dictionary = data.get("level_best_times", {})
	var key := str(idx)
	if bests.has(key):
		return float(bests[key])
	return -1.0

func get_medal(idx: int, gold_threshold: float, silver_threshold: float) -> String:
	# Returns "gold" / "silver" / "bronze" / "" based on best time for this level.
	var best := get_level_best(idx)
	if best < 0.0:
		return ""
	if best <= gold_threshold:
		return "gold"
	if best <= silver_threshold:
		return "silver"
	return "bronze"

# --- First-time intros ---------------------------------------------------

func has_seen_intro(intro_id: String) -> bool:
	var seen: Array = data.get("seen_intros", [])
	return seen.has(intro_id)

func mark_intro_seen(intro_id: String) -> void:
	var seen: Array = data.get("seen_intros", [])
	if not seen.has(intro_id):
		seen.append(intro_id)
		data["seen_intros"] = seen
		save()

# --- Audio settings ------------------------------------------------------

func get_audio() -> Dictionary:
	return (data.get("audio", {}) as Dictionary).duplicate(true)

func set_audio_value(key: String, value) -> void:
	var a: Dictionary = data.get("audio", {})
	a[key] = value
	data["audio"] = a
	save()
