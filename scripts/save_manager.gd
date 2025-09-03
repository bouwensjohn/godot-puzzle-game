extends Node

var save_path: String = "user://save.json"
var data: Dictionary = {
	"completed_count": 0,
	"attempts": 0,
	"best_time_seconds": null,
	"last_played_iso": ""
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
				data = parsed as Dictionary
	else:
		# Create an empty file on first run
		save()

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
