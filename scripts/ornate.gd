class_name Ornate extends RefCounted
## Ornate gold/dark frame styles (GBA-premium look).
static func frame(bg = Color8(20, 18, 36, 240), gold = Color8(216, 176, 72), width = 4) -> StyleBoxFlat:
	var s = StyleBoxFlat.new(); s.bg_color = bg; s.border_color = gold
	s.set_border_width_all(width); s.set_corner_radius_all(6)
	s.shadow_color = Color(0, 0, 0, 0.6); s.shadow_size = 6
	s.content_margin_left = 16; s.content_margin_right = 16; s.content_margin_top = 12; s.content_margin_bottom = 12
	return s

## Panel with inner dark line + corner gems, for portraits/cards.
static func card(parent: Control, rect: Rect2, bg = Color8(20, 18, 36, 240)) -> Panel:
	var p = Panel.new(); parent.add_child(p); p.position = rect.position; p.size = rect.size
	p.add_theme_stylebox_override("panel", frame(bg)); p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner = Panel.new(); p.add_child(inner); inner.position = Vector2(7, 7); inner.size = rect.size - Vector2(14, 14)
	var st = StyleBoxFlat.new(); st.bg_color = Color(0, 0, 0, 0); st.border_color = Color8(96, 64, 24); st.set_border_width_all(2)
	inner.add_theme_stylebox_override("panel", st); inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in [Vector2(0, 0), Vector2(rect.size.x, 0), Vector2(0, rect.size.y), Vector2(rect.size.x, rect.size.y)]:
		var g = ColorRect.new(); p.add_child(g); g.size = Vector2(12, 12); g.position = c - Vector2(6, 6); g.rotation_degrees = 0
		g.color = Color8(248, 216, 112); g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func button(b: Button, accent = Color8(216, 176, 72)) -> Button:
	var n = frame(Color8(36, 32, 64), accent, 3); var h = frame(Color8(56, 48, 96), Color8(248, 216, 112), 3)
	var pr = frame(Color8(96, 72, 24), Color8(255, 232, 144), 3); var d = frame(Color8(28, 26, 40), Color8(80, 72, 64), 3)
	b.add_theme_stylebox_override("normal", n); b.add_theme_stylebox_override("hover", h); b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("disabled", d); b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color8(248, 240, 216)); b.add_theme_color_override("font_disabled_color", Color8(110, 104, 96))
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	return b
