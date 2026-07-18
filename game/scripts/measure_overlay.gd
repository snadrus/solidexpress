class_name MeasureOverlay
extends Node
## Measure chrome state: AABB size labels on the selection, plus a single
## hover pair (touch A → X sticks, touch B → live cardinal + diagonal dims
## to the nearest edge). Drawn in screen space by ViewportInteraction so
## marks stay on top at a fixed fraction of the viewport height.

signal changed

const COLOR_X := Color(0.95, 0.35, 0.3)
const COLOR_Y := Color(0.35, 0.9, 0.4)
const COLOR_Z := Color(0.4, 0.55, 1.0)
const COLOR_DIAG := Color(0.95, 0.9, 0.35)
const COLOR_BOUND := Color(0.85, 0.88, 0.95)
const COLOR_MARK := Color(1.0, 0.55, 0.2)

const BOUND_OFFSET_FRAC := 0.08
const BOUND_OFFSET_MIN := 2.5
## Label / mark size relative to viewport height (drawn in screen space).
const SCREEN_FRAC := 1.0 / 40.0

var view: DocumentView

## Pinned / following anchor from the first touched body.
var anchor_point: Variant = null  # Vector3 when set
var anchor_body := ""
## True while the cursor is still on the anchor body (X follows nearest edge).
var following := false
## Last live B point while hovering a second body (null when not showing pair).
var _last_b: Variant = null

## Screen-draw lists (model-space points); rebuilt on every update.
var segments: Array = []  # {a: Vector3, b: Vector3, color: Color}
var marks: Array = []  # {p: Vector3, color: Color}
var labels: Array = []  # {p: Vector3, text: String, color: Color}


## Clear the A→B pair (keeps selection bound dims until refresh).
func clear_pair() -> void:
	anchor_point = null
	anchor_body = ""
	following = false
	_last_b = null
	_rebuild()


func clear_all() -> void:
	clear_pair()


## Hover update. Leaving A pins the X so B can compare against it.
## Pair dimensions exist only while hovering B; leave B → dims vanish, X stays.
func update_hover(body: String, hit_point: Vector3) -> void:
	if view == null:
		return
	if body == "":
		if anchor_point == null:
			return
		# Pin A when the cursor leaves — do not drop the X; hide pair dims.
		following = false
		_rebuild()
		return

	if anchor_body == "" or body == anchor_body:
		# First touch / still on A / returned to A — X prefers nearest corner.
		anchor_body = body
		anchor_point = view.closest_corner_point(body, hit_point)
		following = true
		_rebuild()
		return

	# Touching a different body B: pin A, show live dims to nearest edge.
	following = false
	_rebuild(view.closest_edge_point(body, hit_point))


## Force the X onto `body` at the nearest corner (place-mode re-anchor). Always
## becomes the new A — never treats the body as a B measure target.
func relocate_anchor(body: String, hit_point: Vector3) -> void:
	if view == null or body == "":
		return
	anchor_body = body
	anchor_point = view.closest_corner_point(body, hit_point)
	following = true
	_rebuild()


## Show live pair dims to an explicit point (e.g. closest corner of a place ghost).
## Requires a pinned/following anchor; no-ops otherwise.
func set_live_target(point: Vector3) -> void:
	if anchor_point == null:
		return
	following = false
	_rebuild(point)


## Hide live B dims but keep the pinned X (leave-B / leave-ghost).
func clear_live_target() -> void:
	if anchor_point == null:
		return
	following = false
	_rebuild()


## Refresh selection AABB size labels (and redraw pair if any).
func refresh_bounds() -> void:
	_rebuild(_last_b if _last_b != null else null)


func has_anchor() -> bool:
	return anchor_point != null


func is_showing_pair() -> bool:
	return anchor_point != null and _last_b != null


func _rebuild(b_point: Variant = null) -> void:
	_last_b = b_point if b_point != null and typeof(b_point) == TYPE_VECTOR3 else null
	segments.clear()
	marks.clear()
	labels.clear()

	# Bound size labels only when idle (no live A→B pair crowding the view).
	if _last_b == null:
		_append_selection_bounds()

	if anchor_point != null:
		var a: Vector3 = anchor_point
		marks.append({"p": a, "color": COLOR_MARK})
		if _last_b != null:
			var b: Vector3 = _last_b
			marks.append({"p": b, "color": COLOR_DIAG})
			_append_pair_dims(a, b)

	changed.emit()


func _append_selection_bounds() -> void:
	if view == null:
		return
	var bb := view.selection_bbox()
	if bb.is_empty():
		return
	var mn: Vector3 = bb["min"]
	var mx: Vector3 = bb["max"]
	var size: Vector3 = mx - mn
	if size.length_squared() < 1e-12:
		return
	var pad := maxf(size.length() * BOUND_OFFSET_FRAC, BOUND_OFFSET_MIN)

	var ax0 := Vector3(mn.x, mn.y - pad, mn.z)
	var ax1 := Vector3(mx.x, mn.y - pad, mn.z)
	_add_dim_seg(ax0, ax1, COLOR_BOUND)
	labels.append({"p": (ax0 + ax1) * 0.5, "text": "%.2f" % size.x, "color": COLOR_BOUND, "rank": 10})

	var ay0 := Vector3(mn.x - pad, mn.y, mn.z)
	var ay1 := Vector3(mn.x - pad, mx.y, mn.z)
	_add_dim_seg(ay0, ay1, COLOR_BOUND)
	labels.append({"p": (ay0 + ay1) * 0.5, "text": "%.2f" % size.y, "color": COLOR_BOUND, "rank": 11})

	var az0 := Vector3(mx.x + pad, mn.y, mn.z)
	var az1 := Vector3(mx.x + pad, mn.y, mx.z)
	_add_dim_seg(az0, az1, COLOR_BOUND)
	labels.append({"p": (az0 + az1) * 0.5, "text": "%.2f" % size.z, "color": COLOR_BOUND, "rank": 12})


func _append_pair_dims(a: Vector3, b: Vector3) -> void:
	var d := b - a
	# Stagger label stations along each segment + a perpendicular nudge so the
	# three cardinals and the diagonal don't share one midpoint in 3D.
	_add_dim_seg(a, b, COLOR_DIAG)
	labels.append({
		"p": a.lerp(b, 0.55) + _perp_nudge(d, Vector3(0, 0, 1), 1.6),
		"text": "%.2f" % a.distance_to(b),
		"color": COLOR_DIAG,
		"rank": 0,
	})

	if absf(d.x) > 1e-4:
		var bx := Vector3(b.x, a.y, a.z)
		_add_dim_seg(a, bx, COLOR_X)
		labels.append({
			"p": a.lerp(bx, 0.35) + Vector3(0, 1.2, 1.2),
			"text": "Δx %.2f" % absf(d.x),
			"color": COLOR_X,
			"rank": 1,
		})
	if absf(d.y) > 1e-4:
		var by0 := Vector3(b.x, a.y, a.z)
		var by1 := Vector3(b.x, b.y, a.z)
		_add_dim_seg(by0, by1, COLOR_Y)
		labels.append({
			"p": by0.lerp(by1, 0.5) + Vector3(1.2, 0, 1.2),
			"text": "Δy %.2f" % absf(d.y),
			"color": COLOR_Y,
			"rank": 2,
		})
	if absf(d.z) > 1e-4:
		var bz0 := Vector3(b.x, b.y, a.z)
		var bz1 := b
		_add_dim_seg(bz0, bz1, COLOR_Z)
		labels.append({
			"p": bz0.lerp(bz1, 0.65) + Vector3(1.2, 1.2, 0),
			"text": "Δz %.2f" % absf(d.z),
			"color": COLOR_Z,
			"rank": 3,
		})


func _perp_nudge(along: Vector3, prefer: Vector3, amount: float) -> Vector3:
	var n := along.cross(prefer)
	if n.length_squared() < 1e-10:
		n = along.cross(Vector3(0, 1, 0))
	if n.length_squared() < 1e-10:
		return Vector3(0, 0, amount)
	return n.normalized() * amount


func _add_dim_seg(a: Vector3, b: Vector3, color: Color) -> void:
	segments.append({"a": a, "b": b, "color": color})
