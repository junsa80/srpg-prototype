extends Node
## P0 QoL regression: forecast labels, enemy intent wording, next_unit with pending move, auto-end option.
var ok = true
func chk(c: bool, tag: String) -> void:
	if not c and ok: print("FAILAT ", tag)
	ok = ok and c

func _ready() -> void:
	var keep_auto = Settings.auto_end
	var b = load("res://scenes/battle.tscn").instantiate(); add_child(b); await get_tree().process_frame
	var allies = b.units.filter(func(u): return u.team == 0 and u.hp > 0)
	var foes = b.units.filter(func(u): return u.team == 1 and u.hp > 0)
	var a: Unit = allies[0]; var e: Unit = foes[0]
	# 1. forecast flags + labels
	var f = BattleManager.forecast(a, e)
	chk(f.assumes_all_hit == true and f.has("extra_chance"), "fc-dict")
	var note = b.forecast_note(f); print("note: ", note)
	chk(note.contains("모든 타격 명중 시"), "fc-note")
	b._fill_forecast(f, a, e); await get_tree().process_frame
	var txt = []
	for c in b.fc_panel.find_children("*", "Label", true, false): txt.append(c.text)
	chk(" ".join(txt).contains("명중 시 HP"), "fc-label")
	# 2. intent wording
	var plan = EnemyAI.plan(e, b.units, b.grid); var it = b.intent_text(plan, e); print("intent: ", it)
	chk(it.contains("현재 배치 기준") and not it.contains("공격 예정"), "intent")
	b._show_enemy(e); chk(b.info.text.contains("공격 가능 범위"), "range-label")
	# 3. next_unit after an unconfirmed move reverts it and selects another unit
	if allies.size() >= 2:
		b._clear(); b._select(a); var c0 = a.cell
		var dest = c0
		for c in b.grid.highlight_move: if c != c0 and b._unit_at(c) == null: dest = c; break
		a.cell = dest; a.position = b.grid.cell_to_pos(dest); b.moved = true; b.orig_cell = c0
		b.next_unit()
		print("next_unit: a.cell ", a.cell, " orig ", c0, " selected ", b.selected.data.name if b.selected else "-")
		chk(a.cell == c0 and b.selected != a and b.selected != null and not b.moved, "next-unit")
	# 4. auto end option
	b._clear(); Settings.auto_end = false
	for u in allies: u.has_acted = true
	var t0 = b.tm.turn; b._maybe_auto_end(); chk(b.tm.phase == TurnManager.Phase.PLAYER and b.tm.turn == t0, "auto-off")
	Settings.auto_end = keep_auto
	# P1: unit list sort
	allies[0].has_acted = true; allies[0].hp = allies[0].stats.hp
	if allies.size() > 1: allies[1].has_acted = false; allies[1].hp = 1
	var s1 = Menus.sort_units(b.units, 1); chk(not s1.has(allies[0]) and s1[0].team == 0, "sort-unacted")
	var s2 = Menus.sort_units(b.units, 2); if allies.size() > 1: chk(s2[0] == allies[1], "sort-hp")
	var s3 = Menus.sort_units(b.units, 3); chk(s3.size() == b.units.size() and s3[-1].team == 1, "sort-uses")
	Menus.list_sort = 0
	# P1: save export/import + corruption recovery (slot 3, restored afterwards)
	var p3 = SaveManager.slot_path(3); var keep3 = FileAccess.get_file_as_string(p3) if FileAccess.file_exists(p3) else ""
	chk(SaveManager.save(3, "ch1", 2, {"campaign": Campaign.to_dict(), "battle": {}}), "save")
	var code = SaveManager.export_text(3); chk(code.begins_with(SaveManager.EXPORT_PREFIX), "export")
	chk(SaveManager.import_text(3, "garbage") != "", "import-reject")
	chk(SaveManager.import_text(0, code) != "", "import-no-auto")
	SaveManager.delete_slot(3); chk(SaveManager.import_text(3, code) == "" and SaveManager.load_slot(3).turn == 2, "import")
	# corrupt main file with good .bak -> recovered
	var good = FileAccess.get_file_as_string(p3)
	var fh = FileAccess.open(p3 + ".bak", FileAccess.WRITE); fh.store_string(good); fh.close()
	fh = FileAccess.open(p3, FileAccess.WRITE); fh.store_string("{broken"); fh.close()
	var r = SaveManager.load_slot(3); chk(r.get("recovered", false) and r.turn == 2, "recover-bak")
	chk(SaveManager.slot_metadata()[3].get("recovered", false), "meta-recovered")
	# everything broken -> reported corrupt, not empty; apply refuses
	fh = FileAccess.open(p3 + ".bak", FileAccess.WRITE); fh.store_string("xx"); fh.close()
	chk(SaveManager.load_slot(3).get("corrupt", false) and SaveManager.slot_metadata()[3].get("corrupt", false), "corrupt")
	chk(SaveManager.apply(3) == "" and SaveManager.latest_slot() != 3, "corrupt-apply")
	# truncated autosave (crash mid-write: only .tmp complete) still loads
	SaveManager.delete_slot(3)
	fh = FileAccess.open(p3 + ".tmp", FileAccess.WRITE); fh.store_string(good); fh.close()
	chk(SaveManager.load_slot(3).get("turn", -1) == 2, "recover-tmp")
	SaveManager.delete_slot(3)
	if keep3 != "": SaveManager.write_atomic(p3, keep3)
	# audio ON/OFF: separate music / sfx toggles, default ON, old settings files (no keys) load as ON
	var keep_set = FileAccess.get_file_as_string(Settings.PATH) if FileAccess.file_exists(Settings.PATH) else ""
	var kb = Settings.bgm_on; var ks = Settings.sfx_on; var kv = [Settings.bgm, Settings.sfx, Settings.anim]
	fh = FileAccess.open(Settings.PATH, FileAccess.WRITE); fh.store_string('{"bgm": 3, "sfx": 4, "anim": false}'); fh.close()
	Settings.bgm_on = false; Settings.sfx_on = false; Settings._ready()
	chk(Settings.bgm_on and Settings.sfx_on and Settings.bgm == 3 and not Settings.anim, "audio-old-settings")
	Settings.bgm_on = false; Settings.sfx_on = true; Settings.save(); Settings.bgm_on = true; Settings._ready()
	chk(not Settings.bgm_on and Settings.sfx_on, "audio-persist")
	chk(not Sfx.bgm.playing, "bgm-off-stops")
	var sl = VBoxContainer.new(); add_child(sl); Menus._fill_settings(sl); await get_tree().process_frame
	chk(sl.find_child("BGM_켬", true, false) != null and sl.find_child("SFX_끔", true, false) != null, "audio-buttons")
	sl.queue_free()
	Settings.bgm_on = kb; Settings.sfx_on = ks; Settings.bgm = kv[0]; Settings.sfx = kv[1]; Settings.anim = kv[2]
	if keep_set != "": SaveManager.write_atomic(Settings.PATH, keep_set)
	else: DirAccess.remove_absolute(Settings.PATH)
	Settings._ready()
	# prep 소지품 / 수송대: ◀ ▶ switch units directly
	if allies.size() >= 2:
		var ps = PrepScreen.new(); ps.b = b; add_child(ps)
		ps._unit_items(allies[0]); await get_tree().process_frame
		var nxb = ps.find_child("PINext", true, false); chk(nxb != null, "prep-nav")
		if nxb: nxb.pressed.emit(); await get_tree().process_frame
		var tops = ps.get_children().filter(func(c): return c.name.begins_with("PrepUnitItems") and not c.is_queued_for_deletion())
		var title_ok = false
		for t in tops:
			for l in t.find_children("*", "Label", true, false): if l.text == "%s의 소지품" % ps._live()[1].data.name: title_ok = true
		chk(title_ok, "prep-next-unit")
		var cvb = null
		for t in tops:
			for bt in t.find_children("*", "Button", true, false): if bt.text.begins_with("수송대"): cvb = bt
		if cvb: cvb.pressed.emit(); await get_tree().process_frame
		var cvn = ps.find_child("CVPrev", true, false); chk(cvn != null, "convoy-nav")
		if cvn: cvn.pressed.emit(); await get_tree().process_frame; await get_tree().process_frame
		var found = false
		for l in ps.find_children("*", "Label", true, false):
			if not l.is_queued_for_deletion() and l.text == "수송대 — %s" % ps._live()[0].data.name: found = true
		chk(found, "convoy-prev-unit")
		ps.queue_free()
	# battle scene replay: finishes at skip speed, all weapon motions, purely visual (HP untouched), anim_fast persisted
	var a2: Unit = allies[0]; var e2: Unit = foes[0]
	var hp0 = [a2.hp, e2.hp]
	var cs = CombatScene.new(); add_child(cs)
	BattleManager.pre_fc = BattleManager.forecast(a2, e2)
	var evs = []
	for wn in ["철검", "철창", "철도끼", "철활", "파이어", "라이트"]:
		evs.append({"type": "strike", "x": a2, "y": e2, "hit": true, "crit": wn == "철활", "dmg": 1, "w": Weapons.make(wn), "x_hp": a2.hp, "y_hp": maxi(1, e2.hp - 1)})
	evs.append({"type": "strike", "x": e2, "y": a2, "hit": false, "crit": false, "dmg": 0, "w": e2.weapon(), "x_hp": e2.hp, "y_hp": a2.hp})
	evs.append({"type": "strike", "x": a2, "y": e2, "hit": true, "crit": false, "dmg": 0, "w": null, "x_hp": a2.hp, "y_hp": 0})
	var fin = [0]; cs.done.connect(func(): fin[0] += 1)
	cs.play(a2, e2, evs, [], {a2: a2.hp, e2: e2.hp}); cs._set_speed(12.0)
	var t_end = Time.get_ticks_msec() + 20000
	while fin[0] < 1 and Time.get_ticks_msec() < t_end: await get_tree().process_frame
	chk(fin[0] == 1, "combat-scene-done")
	cs.play(a2, a2, [{"type": "heal", "x": a2, "y": a2, "amt": 3, "y_hp": a2.hp}], [], {a2: a2.hp}); cs._set_speed(12.0)
	t_end = Time.get_ticks_msec() + 10000
	while fin[0] < 2 and Time.get_ticks_msec() < t_end: await get_tree().process_frame
	chk(fin[0] == 2, "combat-heal-done")
	chk([a2.hp, e2.hp] == hp0, "combat-visual-only")
	cs.queue_free()
	var keep_fast = Settings.anim_fast; Settings.anim_fast = true; Settings.save()
	chk(FileAccess.get_file_as_string(Settings.PATH).contains("\"anim_fast\":true"), "anim-fast-saved")
	Settings.anim_fast = keep_fast; Settings.save()
	# no UI claims cloud save
	for fn in ["res://scripts/menus.gd", "res://scripts/title.gd", "res://scripts/base.gd"]:
		var src = FileAccess.get_file_as_string(fn)
		chk(not src.contains("클라우드 저장됨") and not src.contains("클라우드에 저장"), "cloud-claim " + fn)
	print("QOLTEST ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
