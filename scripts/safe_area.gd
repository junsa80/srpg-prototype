class_name SafeArea
## Notch / home-bar insets in viewport units (top, bottom).
## Web: reads CSS env(safe-area-inset-*) (needs viewport-fit=cover in index.html, set via export head_include).
## Dev/emulation: URL hash "#safearea=TOP,BOTTOM" (CSS px) overrides. Native: DisplayServer safe area.
## Fallback when nothing is reported: 0 top, MIN_BOTTOM bottom (keeps buttons off the gesture bar edge).
const MIN_BOTTOM_CSS = 8.0
static var _cache = null

static func insets(vp: Viewport) -> Vector2:
	var vs = vp.get_visible_rect().size
	var css = _css_insets()
	if css != null:
		var k = _css_to_vp(vs)
		return Vector2(css.x * k, maxf(css.y, MIN_BOTTOM_CSS) * k)
	var ss = DisplayServer.screen_get_size(); var sa = DisplayServer.get_display_safe_area()
	if ss.y <= 0 or sa.size.y <= 0: return Vector2.ZERO
	var t = clampf(sa.position.y * vs.y / float(ss.y), 0.0, 200.0)
	var b = clampf((ss.y - sa.end.y) * vs.y / float(ss.y), 0.0, 200.0)
	return Vector2(t, b)

static func top(vp: Viewport) -> float: return insets(vp).x
static func bottom(vp: Viewport) -> float: return insets(vp).y

## viewport units per CSS px (canvas fills the window).
static func _css_to_vp(vs: Vector2) -> float:
	var w = float(JavaScriptBridge.eval("window.innerWidth", true))
	return vs.x / maxf(1.0, w)

static func _css_insets():
	if not OS.has_feature("web"): return null
	if _cache != null: return _cache
	var js = """(function(){var h=location.hash.match(/safearea=(\\d+),(\\d+)/);if(h)return h[1]+','+h[2];
var d=document.createElement('div');d.style.cssText='position:fixed;top:0;left:0;visibility:hidden;padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)';
document.body.appendChild(d);var s=getComputedStyle(d);var r=parseFloat(s.paddingTop)+','+parseFloat(s.paddingBottom);d.remove();return r;})()"""
	var r = str(JavaScriptBridge.eval(js, true)).split(",")
	if r.size() != 2: return null
	_cache = Vector2(float(r[0]), float(r[1]))
	return _cache
