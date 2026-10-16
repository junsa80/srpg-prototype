extends Node
## Autoload. Slot 0 = autosave, slots 1..3 = manual. Versioned JSON, atomic write (tmp -> rename, .bak kept until done).
const SAVE_VERSION = 2
const SLOTS = 4            # 0 auto + 3 manual
const AUTOSAVE_SLOT = 0

func slot_path(slot: int) -> String: return "user://save_%d.json" % slot

## Atomic replace: write tmp, move old to .bak, rename tmp -> final, drop .bak. A crash at any point leaves
## either the old file, the .bak (old), or the complete new file; load_slot() recovers from .bak/.tmp.
static func write_atomic(final: String, text: String) -> bool:
	var tmp = final + ".tmp"; var bak = final + ".bak"
	var f = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null: push_error("save open failed " + tmp); return false
	f.store_string(text); f.flush(); f.close()
	var check = FileAccess.get_file_as_string(tmp)
	if check.length() != text.length(): return false
	var dir = DirAccess.open("user://")
	if dir.file_exists(bak.get_file()): dir.remove(bak.get_file())
	if dir.file_exists(final.get_file()): dir.rename(final.get_file(), bak.get_file())
	var err = dir.rename(tmp.get_file(), final.get_file())
	if err == OK and dir.file_exists(bak.get_file()): dir.remove(bak.get_file())
	return err == OK

## payload: {"campaign": Campaign.to_dict(), "battle": {} or battle snapshot}
func save(slot: int, chapter: String, turn: int, payload: Dictionary) -> bool:
	assert(slot >= 0 and slot < SLOTS)
	var lead = payload.get("campaign", {}).get("roster", {}).get("아린", {})
	var doc = {"version": SAVE_VERSION, "timestamp": Time.get_unix_time_from_system(),
		"timestamp_local": Time.get_datetime_string_from_system(false, true), "chapter": chapter,
		"chapter_title": ChapterData.CHAPTERS.get(chapter, {}).get("title", chapter), "turn": turn,
		"in_battle": not payload.get("battle", {}).is_empty(),
		"playtime": int(Campaign.playtime), "lead": "아린 Lv%d %s" % [int(lead.get("level", 1)), lead.get("class", "용병")],
		"data": payload}
	return write_atomic(slot_path(slot), JSON.stringify(doc))

func autosave(chapter: String, turn: int, payload: Dictionary) -> void:
	save(AUTOSAVE_SLOT, chapter, turn, payload)

## Loads a slot; if the main file is damaged, falls back to .bak/.tmp (marked "recovered").
## A file that can't be read at all is reported as {"corrupt": true} instead of silently "empty".
func load_slot(slot: int) -> Dictionary:
	var p = slot_path(slot)
	var seen = false
	for cand in [p, p + ".bak", p + ".tmp"]:
		if not FileAccess.file_exists(cand): continue
		var doc = parse_doc(FileAccess.get_file_as_string(cand))
		if not doc.is_empty():
			if seen: doc["recovered"] = true
			return doc
		seen = true
	return {"corrupt": true} if seen else {}

## Validate + migrate a save document from text. {} when invalid.
func parse_doc(text: String) -> Dictionary:
	var doc = JSON.parse_string(text)
	if typeof(doc) != TYPE_DICTIONARY or not doc.has("data") or typeof(doc.data) != TYPE_DICTIONARY: return {}
	if not doc.has("chapter") or not doc.has("turn"): return {}
	return _migrate(doc)

# ---- local export / import (no cloud: cloud sync is NOT implemented)
const EXPORT_PREFIX = "SRPGSAVE1:"
## Portable code for a slot ("" if empty/corrupt).
func export_text(slot: int) -> String:
	var d = load_slot(slot)
	if d.is_empty() or d.get("corrupt", false): return ""
	d.erase("recovered")
	return EXPORT_PREFIX + Marshalls.utf8_to_base64(JSON.stringify(d))

## Import a code (or raw JSON) into manual slot 1..3. Returns "" on success, else an error message.
func import_text(slot: int, text: String) -> String:
	if slot < 1 or slot >= SLOTS: return "슬롯 1~3에만 가져올 수 있습니다"
	var t = text.strip_edges().replace("\n", "").replace(" ", "")
	if t.begins_with(EXPORT_PREFIX): t = Marshalls.base64_to_utf8(t.substr(EXPORT_PREFIX.length()))
	else: t = text.strip_edges()
	var doc = parse_doc(t)
	if doc.is_empty(): return "올바른 저장 코드가 아닙니다"
	return "" if write_atomic(slot_path(slot), JSON.stringify(doc)) else "저장 실패"

func delete_slot(slot: int) -> void:
	var dir = DirAccess.open("user://")
	for f in [slot_path(slot), slot_path(slot) + ".bak", slot_path(slot) + ".tmp"]:
		if dir.file_exists(f.get_file()): dir.remove(f.get_file())

func _migrate(doc: Dictionary) -> Dictionary:
	if int(doc.get("version", 1)) < 2:   # v1: data was a battle snapshot {campaign, turn, units}
		var d = doc.data
		doc["data"] = {"campaign": d.get("campaign", {}), "battle": {}}
		doc["timestamp_local"] = doc.get("timestamp_iso", ""); doc["chapter_title"] = doc.get("chapter", "")
		doc["playtime"] = 0; doc["lead"] = ""; doc["version"] = 2
	return doc

func slot_metadata() -> Array:
	var out = []
	for i in SLOTS:
		var d = load_slot(i)
		if d.get("corrupt", false): out.append({"slot": i, "corrupt": true}); continue
		out.append({} if d.is_empty() else {"slot": i, "chapter": d.chapter, "chapter_title": d.get("chapter_title", d.chapter), "turn": d.turn,
			"timestamp": d.get("timestamp_local", ""), "unix": d.get("timestamp", 0), "playtime": d.get("playtime", 0), "lead": d.get("lead", ""),
			"in_battle": d.get("in_battle", false), "recovered": d.get("recovered", false)})
	return out

## Most recent slot (any) or -1.
func latest_slot() -> int:
	var best = -1; var t = -1.0
	for m in slot_metadata():
		if not m.is_empty() and not m.get("corrupt", false) and float(m.unix) > t: t = float(m.unix); best = m.slot
	return best

## Apply a slot: restore campaign, return scene path to change to.
func apply(slot: int) -> String:
	var d = load_slot(slot)
	if d.is_empty() or d.get("corrupt", false): return ""
	var cd: Dictionary = d.data.get("campaign", {}); var from_ver = int(cd.get("game_ver", 1))
	Campaign.from_dict(cd); Campaign.playtime = float(d.get("playtime", 0))
	Campaign.resume = d.data.get("battle", {})
	if from_ver < Campaign.GAME_VERSION and Campaign.resume.has("units"):
		for u in Campaign.resume.units:
			if int(u.get("team", 0)) == 0: Campaign.migrate_entry(u.get("name", ""), u, from_ver)
	Campaign.save_campaign()
	if not Campaign.resume.is_empty(): return "res://scenes/battle.tscn"
	return "res://scenes/base.tscn" if Campaign.cleared.size() > 0 else "res://scenes/battle.tscn"

static func fmt_time(sec: int) -> String: return "%d:%02d:%02d" % [sec / 3600, sec / 60 % 60, sec % 60]

# TODO(cloud-sync): NOT IMPLEMENTED — stub only. On conflict show both and let the player choose.
func cloud_sync() -> void:
	push_warning("cloud_sync: TODO not implemented")
