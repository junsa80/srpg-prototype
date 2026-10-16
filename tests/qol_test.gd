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
	print("QOLTEST ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
