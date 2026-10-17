extends SceneTree
## Art audit: every named speaker / unit / boss / NPC, where it appears, portrait + sprite source.
## Run: godot --headless --script tools/art_audit.gd  → prints TSV rows "AUDIT\t..."
var seen = {}   # name -> {"where": {}, "kind": {}, "class": ""}

func _add(n: String, kind: String, where: String, cls := "") -> void:
	if n == "": return
	if not seen.has(n): seen[n] = {"where": {}, "kind": {}, "class": ""}
	seen[n].where[where] = true; seen[n].kind[kind] = true
	if cls != "" and seen[n]["class"] == "": seen[n]["class"] = cls

func _lines(arr, kind: String, where: String) -> void:
	if typeof(arr) != TYPE_ARRAY: return
	for l in arr:
		if typeof(l) == TYPE_ARRAY and l.size() >= 2 and typeof(l[0]) == TYPE_STRING: _add(l[0], kind, where)

func _init() -> void:
	for n in Roster.UNITS: _add(n, "아군", "roster", Roster.UNITS[n][0])
	for ch in ChapterData.CHAPTERS:
		var c = ChapterData.CHAPTERS[ch]
		for k in ["pre", "boss", "post"]: _lines(c.get(k, []), "화자", ch)
	_lines(ChapterData.PROLOGUE, "화자", "prologue")
	for ch in ChapterData.EVENTS:
		for t in ChapterData.EVENTS[ch]: _lines(ChapterData.EVENTS[ch][t], "화자", ch + " 이벤트")
	for ch in ChapterData.CAMP: _lines(ChapterData.CAMP[ch], "화자", ch + " 야영")
	for k in ChapterData.TALK: _lines(ChapterData.TALK[k], "화자", "대화 " + k)
	for sp in ChapterData.SUPPORTS: _lines(sp.get("lines", []), "화자", "지원 " + sp.id)
	for k in ChapterData.ENDINGS: _lines(ChapterData.ENDINGS[k], "화자", "엔딩 " + k)
	for ch in Maps.CH:
		var m = Maps.CH[ch]
		for e in m.get("enemies", []):
			var o = e[3] if e.size() > 3 else {}
			if o.has("name"): _add(o.name, "보스" if o.get("boss", false) else "이름 적", ch, e[0])
			elif o.get("boss", false): _add(e[0], "보스", ch, e[0])
		for r in m.get("reinforcements", []):
			for e in r.get("units", []):
				var o = e[3] if e.size() > 3 else {}
				if o.has("name"): _add(o.name, "이름 적", ch, e[0])
		for npc in m.get("npc", []): _add(npc[0], "NPC", ch, npc[1])
		for v in m.get("villages", {}).values(): _lines(v.get("lines", []), "화자", ch + " 마을")
	var md5 = {}
	for n in seen:
		var p = "res://assets/portraits/%s.png" % n
		if FileAccess.file_exists(p):
			var h = FileAccess.get_md5(p); if not md5.has(h): md5[h] = []
			md5[h].append(n)
	for n in seen:
		var s = seen[n]; var p = "res://assets/portraits/%s.png" % n
		var port = "있음" if FileAccess.file_exists(p) else "없음"
		if port == "없음" and Sprites.NPC_ALIAS.has(n): port = "별칭 npc_%s%s" % [Sprites.NPC_ALIAS[n], "" if FileAccess.file_exists("res://assets/portraits/npc_%s.png" % Sprites.NPC_ALIAS[n]) else " (파일 없음)"]
		if port == "있음":
			var share = md5[FileAccess.get_md5(p)]
			if share.size() > 1: port = "공유(" + ",".join(share) + ")"
		var spr = []
		for f in [n, n + "@" + s["class"]]:
			if FileAccess.file_exists("res://assets/units/%s.png" % f): spr.append(f)
		var w = s.where.keys(); w.sort()
		print("AUDIT\t%s\t%s\t%s\t%s\t%s\t%s" % [n, "/".join(s.kind.keys()), s["class"], port, ",".join(spr), " ".join(w.slice(0, 6)) + (" …(+%d)" % (w.size() - 6) if w.size() > 6 else "")])
	quit(0)
