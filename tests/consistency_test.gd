extends SceneTree
## Story / art / code consistency. Errors fail; missing art is only a warning (code falls back to procedural/none).
## Run: godot --headless --script tests/consistency_test.gd
var errors = []; var warns = {}

func _w(kind: String, n: String) -> void:
	if not warns.has(kind): warns[kind] = {}
	warns[kind][n] = true

func _item_ok(n: String) -> bool: return n == "" or Weapons.LIST.has(n) or Weapons.ITEMS.has(n)

func _unit(ch: String, e: Array) -> void:
	var cls: String = e[0]; var opt: Dictionary = e[3] if e.size() > 3 else {}
	if not Roster.CLASSES.has(cls): errors.append("%s: 클래스 없음 '%s'" % [ch, cls])
	if not _item_ok(e[1]): errors.append("%s: 무기 없음 '%s'" % [ch, e[1]])
	for k in ["drop", "item"]:
		if opt.has(k) and not _item_ok(str(opt[k])): errors.append("%s: %s 아이템 없음 '%s'" % [ch, k, opt[k]])
	var nm = opt.get("name", "")
	if nm != "" and not ResourceLoader.exists("res://assets/portraits/%s.png" % nm): _w("초상 없음(이름 유닛)", nm)

func _init() -> void:
	for ch in Maps.CH:
		var m: Dictionary = Maps.CH[ch]
		if not ChapterData.CHAPTERS.has(ch): errors.append("맵 %s: ChapterData.CHAPTERS에 없음" % ch)
		var names = []
		for e in m.get("enemies", []): _unit(ch, e); names.append(e[3].get("name", e[0]) if e.size() > 3 else e[0])
		for r in m.get("reinforcements", []):
			for e in r.get("units", []): _unit(ch, e)
		if m.get("boss", "") != "" and not m.boss in names: errors.append("%s: 보스 '%s'가 적 목록에 없음" % [ch, m.boss])
		if m.has("boss") and m.boss != "" and not ResourceLoader.exists("res://assets/portraits/%s.png" % m.boss): _w("초상 없음(보스)", m.boss)
		for c in m.get("chests", {}).values(): if not _item_ok(c.get("item", "")): errors.append("%s: 상자 아이템 없음 '%s'" % [ch, c.item])
		for b in m.get("branch", []):
			if not ChapterData.CHAPTERS.has(b[0]): errors.append("%s: 분기 대상 %s 대본 없음" % [ch, b[0]])
			elif not Maps.CH.has(b[0]): _w("분기 대상 맵 미구현", b[0])
	for ch in ChapterData.CHAPTERS:
		if not Maps.CH.has(ch): _w("대본만 있고 맵 미구현", ch)
		var c: Dictionary = ChapterData.CHAPTERS[ch]
		for k in ["pre", "boss", "post"]:
			for l in c.get(k, []):
				if l.size() < 2: errors.append("%s.%s: 잘못된 대사 줄 %s" % [ch, k, str(l)])
				elif l[0] != "" and not ResourceLoader.exists("res://assets/portraits/%s.png" % l[0]): _w("초상 없음(화자)", l[0])
	for src in [ChapterData.EVENTS, ChapterData.CAMP]:
		for ch in src:
			if not ChapterData.CHAPTERS.has(ch): errors.append("EVENTS/CAMP 키 %s: 장 없음" % ch)
	for n in Roster.UNITS:
		if not Roster.CLASSES.has(Roster.UNITS[n][0]): errors.append("유닛 %s: 클래스 없음 '%s'" % [n, Roster.UNITS[n][0]])
		if not ResourceLoader.exists("res://assets/portraits/%s.png" % n): _w("초상 없음(아군)", n)
	for k in warns: print("WARN %s (%d): %s" % [k, warns[k].size(), ", ".join(warns[k].keys())])
	for e in errors: print("ERROR ", e)
	print("CONSISTENCY ", "PASS" if errors.is_empty() else "FAIL (%d)" % errors.size())
	quit(0 if errors.is_empty() else 1)
