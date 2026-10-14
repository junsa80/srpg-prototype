extends Node
## Autoload. 3 slots, versioned JSON, atomic write (temp file then rename).
const SAVE_VERSION = 1
const SLOTS = 3
const AUTOSAVE_SLOT = 0  # autosave uses slot 0 by default

func slot_path(slot: int) -> String: return "user://save_%d.json" % slot

func save(slot: int, chapter: String, turn: int, payload: Dictionary) -> bool:
	assert(slot >= 0 and slot < SLOTS)
	var doc = {"version": SAVE_VERSION, "timestamp": Time.get_unix_time_from_system(),
		"timestamp_iso": Time.get_datetime_string_from_system(true), "chapter": chapter, "turn": turn, "data": payload}
	var final = slot_path(slot); var tmp = final + ".tmp"
	var f = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null: push_error("save open failed"); return false
	f.store_string(JSON.stringify(doc)); f.flush(); f.close()
	var dir = DirAccess.open("user://")
	if dir.file_exists(final.get_file()): dir.remove(final.get_file())  # rename over existing isn't atomic on all platforms
	var err = dir.rename(tmp.get_file(), final.get_file())
	return err == OK

func autosave(chapter: String, turn: int, payload: Dictionary) -> void:
	save(AUTOSAVE_SLOT, chapter, turn, payload)

func load_slot(slot: int) -> Dictionary:
	var p = slot_path(slot)
	if not FileAccess.file_exists(p):
		if FileAccess.file_exists(p + ".tmp"): p = p + ".tmp"  # recover interrupted save
		else: return {}
	var doc = JSON.parse_string(FileAccess.get_file_as_string(p))
	if typeof(doc) != TYPE_DICTIONARY: return {}
	return _migrate(doc)

func _migrate(doc: Dictionary) -> Dictionary:
	# if doc.version < SAVE_VERSION: upgrade fields here
	return doc

func slot_metadata() -> Array:
	var out = []
	for i in SLOTS:
		var d = load_slot(i)
		out.append({} if d.is_empty() else {"slot": i, "chapter": d.chapter, "turn": d.turn, "timestamp": d.timestamp_iso})
	return out

# TODO(cloud-sync): NOT IMPLEMENTED — stub only.
# Design: on sync, fetch remote doc per slot. If remote.timestamp != local.timestamp and both changed
# since last sync, DO NOT auto-pick. Show both side by side (chapter, turn, timestamp) and let the
# player choose which to keep; the other is kept as save_N.conflict.json.
func cloud_sync() -> void:
	push_warning("cloud_sync: TODO not implemented")
