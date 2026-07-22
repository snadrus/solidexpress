class_name OriginTriadHud
extends Control
## Tiny RGB XYZ sticks that track OrbitCamera orientation. Sits above ViewHud;
## sized to the menu width. Model axes are kernel Z-up (via ModelSpace).

@export var camera: OrbitCamera

## Match WorldGizmos triad colors (X red, Y green, Z blue).
const COLOR_X := Color(0.92, 0.22, 0.18)
const COLOR_Y := Color(0.22, 0.82, 0.28)
const COLOR_Z := Color(0.22, 0.42, 0.95)
const AXIS_LEN_FRAC := 0.42
const LINE_W := 2.0
const TIP := 4.5


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 40)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if camera != null:
		camera.view_changed.connect(queue_redraw)
	queue_redraw()


func set_camera(cam: OrbitCamera) -> void:
	if camera != null and camera.view_changed.is_connected(queue_redraw):
		camera.view_changed.disconnect(queue_redraw)
	camera = cam
	if camera != null:
		camera.view_changed.connect(queue_redraw)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		# Keep a short strip the width of the menu (not a tall square).
		var h := clampf(size.x * 0.55, 36.0, 52.0)
		if not is_equal_approx(custom_minimum_size.y, h):
			custom_minimum_size.y = h
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var len := minf(size.x, size.y) * AXIS_LEN_FRAC
	var axes := _projected_axes(len)
	# Painter's algorithm: farther (into scene) first.
	axes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["depth"]) > float(b["depth"]))
	for ax: Dictionary in axes:
		var tip: Vector2 = c + (ax["xy"] as Vector2)
		_draw_stick(c, tip, ax["color"] as Color)


## Project model-space XYZ into the widget (screen Y down).
func _projected_axes(len: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dirs: Array = [
		{"dir": _model_axis_world(Vector3.RIGHT), "color": COLOR_X},
		{"dir": _model_axis_world(Vector3.UP), "color": COLOR_Y},
		{"dir": _model_axis_world(Vector3(0, 0, 1)), "color": COLOR_Z},
	]
	var bx := Vector3.RIGHT
	var by := Vector3.UP
	var bz := Vector3.FORWARD
	if camera != null:
		var b: Basis = camera.global_transform.basis
		bx = b.x
		by = b.y
		bz = b.z
	for entry: Dictionary in dirs:
		var d: Vector3 = (entry["dir"] as Vector3).normalized()
		var xy := Vector2(d.dot(bx), -d.dot(by)) * len
		# Camera looks along -Z; larger +Z.dot(dir) is farther from the viewer.
		var depth := d.dot(bz)
		out.append({"xy": xy, "depth": depth, "color": entry["color"]})
	return out


## Kernel/model axis → Godot world (ModelSpace is Rx(-90°): Z-up → Y-up).
func _model_axis_world(model_dir: Vector3) -> Vector3:
	if camera != null and camera.model_space != null:
		return camera.model_space.global_transform.basis * model_dir
	# Same mapping as Main's ModelSpace when the camera has no link yet.
	return Basis(Vector3.RIGHT, -PI / 2.0) * model_dir


func _draw_stick(from: Vector2, to: Vector2, color: Color) -> void:
	draw_line(from, to, color, LINE_W, true)
	var delta := to - from
	if delta.length_squared() < 1.0:
		return
	var tang := delta.normalized()
	var perp := Vector2(-tang.y, tang.x)
	var base := to - tang * TIP
	var pts := PackedVector2Array([to, base + perp * (TIP * 0.55), base - perp * (TIP * 0.55)])
	draw_colored_polygon(pts, color)
