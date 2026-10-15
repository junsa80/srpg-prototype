class_name TouchScroll extends ScrollContainer
## ScrollContainer that scrolls by finger drag even when the drag starts on a child Button.
## Once a drag passes the threshold, the button under the finger is briefly disabled so lifting the
## finger does not "press" it (no accidental purchases while scrolling).
const THRESHOLD = 18.0
var _down = false; var _dragging = false; var _start = Vector2.ZERO; var _start_scroll = 0; var _blocked: Array = []

func _input(ev: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_down = get_global_rect().has_point(ev.position)
			_dragging = false; _start = ev.position; _start_scroll = scroll_vertical
		elif _down:
			_down = false
			if _dragging:
				_dragging = false
				var unblock = _blocked.duplicate(); _blocked = []
				(func(): for b in unblock: if is_instance_valid(b): b.disabled = b.get_meta("ts_was_disabled", false)).call_deferred()
	elif ev is InputEventMouseMotion and _down:
		var dy = ev.position.y - _start.y
		if not _dragging and absf(dy) > THRESHOLD:
			_dragging = true
			var h = get_viewport().gui_get_hovered_control()
			while h and not h is BaseButton and h != self: h = h.get_parent()
			if h is BaseButton and is_ancestor_of(h):
				h.set_meta("ts_was_disabled", h.disabled); h.disabled = true; _blocked.append(h)
		if _dragging: scroll_vertical = int(_start_scroll - dy)

## Ignore presses that land on an overlay drawn above us (another CanvasLayer).
func _top_layer_ok(p: Vector2) -> bool:
	var h = get_viewport().gui_get_hovered_control()
	return h == null or h == self or is_ancestor_of(h)
