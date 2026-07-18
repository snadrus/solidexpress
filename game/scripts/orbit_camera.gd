class_name OrbitCamera
extends Camera3D
## Turntable orbit camera with CAD-familiar presets (SolidWorks / Fusion /
## SolidExpress). Two-finger orbits; middle / 3-finger grip pans under SX;
## Alt / empty-drag navigate; wheel zooms toward the cursor. Wheel / pan over
## ScrollContainers are left alone.
## F frames selection (or all); Shift+F / double-middle-click fit all / selection.
## 1/2/3/7 standard views; 5 toggles ortho. Named views in user://views.cfg.

## Fired after yaw/pitch/distance/pivot/projection update the camera transform.
## Overlay gizmos connect so they redraw only when the view actually moves.
signal view_changed

enum NavPreset { SOLIDEXPRESS, SOLIDWORKS, FUSION }

var pivot := Vector3.ZERO
## Empty-scene start: close enough that 0.1 mm grid cells resolve on screen.
var distance := DEFAULT_DISTANCE
var yaw := deg_to_rad(-35.0)
var pitch := deg_to_rad(30.0)
## Set by main; used by frame_contents (F) to fit all bodies.
var view: DocumentView
var model_space: Node3D
## Mouse binding preset for middle-drag (and Shift+middle).
var nav_preset := NavPreset.SOLIDEXPRESS

## ~15 mm puts ≈4 px on a 0.1 mm cell at 900p / 75° FOV.
const DEFAULT_DISTANCE := 15.0
const MIN_DISTANCE := 1.0
const MAX_DISTANCE := 20000.0
## Fraction of half-frustum height to aim above the orbit pivot so the axis
## origin sits near the bottom of the screen (0 = centered, 1 ≈ bottom edge).
const VIEW_PIVOT_Y_BIAS := 0.72
const ORBIT_SPEED := 0.008
## Two-finger pan sensitivity. Higher so a short trackpad swipe actually turns.
const PAN_GESTURE_SCALE := 0.045
## Map pan-gesture deltas into `_pan_by` pixel units (≈ PAN_GESTURE_SCALE / ORBIT_SPEED).
const PAN_GESTURE_MOVE_SCALE := 5.5
## Amplify near-1.0 MagnifyGesture deltas (Wayland/libinput often sends tiny factors).
const MAGNIFY_GAIN := 4.0
## Ctrl/Cmd + two-finger drag vertical → zoom (fallback when MagnifyGesture is absent).
const PAN_ZOOM_SCALE := 0.018
const MIN_PITCH := deg_to_rad(-89.0)
const MAX_PITCH := deg_to_rad(89.0)
const VIEWS_CFG := "user://views.cfg"

## name -> {yaw, pitch, distance, pivot, projection}
var _named_views: Dictionary = {}
var _view_tween: Tween


func _ready() -> void:
	far = 100000.0
	_load_named_views()
	_update_transform()


func _orbit_by(dx: float, dy: float) -> void:
	yaw -= dx * ORBIT_SPEED
	pitch = clampf(pitch + dy * ORBIT_SPEED, MIN_PITCH, MAX_PITCH)
	_update_transform()


func _pan_by(dx: float, dy: float) -> void:
	var pan_scale := distance * 0.0012
	pivot += global_transform.basis.x * (-dx * pan_scale)
	pivot += global_transform.basis.y * (dy * pan_scale)
	_update_transform()


## True when the pointer is over a control that should consume wheel / two-finger
## scroll (ScrollContainer, TextEdit, etc.) instead of the 3D camera.
static func pointer_over_scrollable_ui() -> bool:
	var vp := Engine.get_main_loop() as SceneTree
	if vp == null or vp.root == null:
		return false
	var hovered: Control = vp.root.get_viewport().gui_get_hovered_control()
	while hovered != null:
		if hovered is ScrollContainer:
			return true
		if hovered is TextEdit or hovered is CodeEdit:
			return true
		if hovered is ItemList or hovered is Tree:
			return true
		if hovered is RichTextLabel and (hovered as RichTextLabel).scroll_active:
			return true
		hovered = hovered.get_parent() as Control
	return false


## True when this event should drive the camera (middle, Alt+left, pan gesture, wheel).
## Pass `allow_scroll_gestures=false` when the pointer is over a scrolling UI panel.
## Pinch-zoom (MagnifyGesture) is never gated — docks don't use pinch.
func is_nav_event(event: InputEvent, allow_scroll_gestures := true) -> bool:
	if event is InputEventMagnifyGesture:
		return true
	if event is InputEventPanGesture:
		# Ctrl/Cmd+pan is treated as pinch-zoom and always available.
		if event.ctrl_pressed or event.meta_pressed:
			return true
		return allow_scroll_gestures
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP \
				or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Ctrl+wheel is pinch-zoom on many Linux trackpads — never gate it.
			if mb.ctrl_pressed or mb.meta_pressed:
				return true
			return allow_scroll_gestures
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			return true
		# Consume Alt+LMB press/release so place/select don't also fire.
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.alt_pressed:
			return true
		# Two-finger click on many trackpads = middle; some emit left+ctrl/meta.
		if mb.button_index == MOUSE_BUTTON_LEFT and (mb.ctrl_pressed or mb.meta_pressed) \
				and mb.alt_pressed:
			return true
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			return true
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and mm.alt_pressed:
			return true
	return false


func handle_input(event: InputEvent, allow_scroll_gestures := true) -> bool:
	# Pinch always zooms (never defer to dock scroll — ScrollContainers don't pinch).
	if event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		# factor > 1 = pinch out = zoom in. Gain helps tiny Wayland deltas.
		var boosted := 1.0 + (mg.factor - 1.0) * MAGNIFY_GAIN
		var factor := 1.0 / maxf(boosted, 0.01)
		factor = clampf(factor, 0.5, 2.0)
		var vp := get_viewport()
		var pos := vp.get_mouse_position() if vp != null else Vector2.ZERO
		zoom_at(pos, factor)
		return true
	if event is InputEventPanGesture and (event.ctrl_pressed or event.meta_pressed):
		# Ctrl+two-finger drag → zoom (Linux fallback when MagnifyGesture is missing).
		var pg_zoom := event as InputEventPanGesture
		var vp2 := get_viewport()
		var pos2 := vp2.get_mouse_position() if vp2 != null else Vector2.ZERO
		# Finger move up (negative Y delta) → zoom in (distance shrinks).
		var zfactor := exp(pg_zoom.delta.y * PAN_ZOOM_SCALE)
		zoom_at(pos2, clampf(zfactor, 0.5, 2.0))
		return true
	if not allow_scroll_gestures and (
			event is InputEventPanGesture
			or (event is InputEventMouseButton and (
				(event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_UP
				or (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_DOWN)
				and not (event as InputEventMouseButton).ctrl_pressed
				and not (event as InputEventMouseButton).meta_pressed)):
		return false
	if event is InputEventPanGesture:
		# Two-finger drag orbits. Shift+two-finger pans. A 3-finger grip
		# (middle-click on clickfinger trackpads) follows the nav preset.
		var pg := event as InputEventPanGesture
		var middle_grip := Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
		var do_pan := false
		if middle_grip:
			do_pan = _want_pan(pg.shift_pressed)
		elif pg.shift_pressed:
			do_pan = true
		if do_pan:
			_pan_by(pg.delta.x * PAN_GESTURE_MOVE_SCALE, pg.delta.y * PAN_GESTURE_MOVE_SCALE)
			return true
		var scale := PAN_GESTURE_SCALE
		# Left-click held under the fingers → slightly snappier turn.
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			scale *= 1.35
		yaw -= pg.delta.x * scale
		pitch = clampf(pitch + pg.delta.y * scale, MIN_PITCH, MAX_PITCH)
		_update_transform()
		return true
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_at(mb.position, 0.85 if (mb.ctrl_pressed or mb.meta_pressed) else 0.9)
			return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			var out := 0.85 if (mb.ctrl_pressed or mb.meta_pressed) else 0.9
			zoom_at(mb.position, 1.0 / out)
			return true
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			# SolidWorks muscle memory: double-middle = zoom to fit.
			if mb.pressed and mb.double_click:
				frame_selection_or_all(false)
				return true
			return true  # claim press/release so LMB paths ignore them
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.alt_pressed:
			return true  # Alt+LMB orbit/pan — do not place/select
		return false
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var middle := (mm.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0
		var alt_left := (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and mm.alt_pressed
		if not middle and not alt_left:
			return false
		# Middle / 3-finger uses the nav preset. Alt stays orbit-first under SX
		# so trackpads keep a reliable orbit chord when middle is rebound to pan.
		var pan := _want_pan(mm.shift_pressed) if middle else _want_alt_pan(mm.shift_pressed)
		if pan:
			_pan_by(mm.relative.x, mm.relative.y)
		else:
			_orbit_by(mm.relative.x, mm.relative.y)
		return true
	elif event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.ctrl_pressed:
			return false
		match k.keycode:
			KEY_F:
				# F → selection (or all); Shift+F → always all.
				frame_selection_or_all(k.shift_pressed)
				return true
			KEY_1:  # front: looking along -Y in model space (Z-up kernel)
				set_view(deg_to_rad(0.0), deg_to_rad(0.0))
				return true
			KEY_2:  # right: looking along -X
				set_view(deg_to_rad(90.0), deg_to_rad(0.0))
				return true
			KEY_3:  # top: looking down model +Z (world +Y)
				set_view(deg_to_rad(0.0), deg_to_rad(89.0))
				return true
			KEY_7:  # isometric
				set_view(deg_to_rad(-35.0), deg_to_rad(30.0))
				return true
			KEY_5:
				toggle_projection()
				return true
	return false


## SX / Fusion: middle (3-finger grip on clickfinger trackpads) pans,
## Shift+middle orbits. SolidWorks: middle orbits, Shift+middle pans.
func _want_pan(shift_held: bool) -> bool:
	if nav_preset == NavPreset.FUSION or nav_preset == NavPreset.SOLIDEXPRESS:
		return not shift_held
	return shift_held


## Alt+left: Fusion mirrors middle (pan). SX/SW keep Alt as orbit so a
## touchpad always has an orbit chord even when middle/3-finger pans.
func _want_alt_pan(shift_held: bool) -> bool:
	if nav_preset == NavPreset.FUSION:
		return not shift_held
	return shift_held


## Zoom by `factor` (< 1 in, > 1 out) keeping the point under `screen_pos`
## approximately fixed: intersect the cursor ray with the plane through the
## pivot perpendicular to the view axis, then shift the pivot by (1 - factor)
## of that pivot→anchor vector (in-plane).
func zoom_at(screen_pos: Vector2, factor: float) -> void:
	var anchor := _zoom_anchor(screen_pos)
	var basis := global_transform.basis if is_inside_tree() else transform.basis
	var forward := -basis.z
	var to_anchor := anchor - pivot
	# Project onto the view plane (numerical safety; anchor should already lie on it).
	var plane_delta := to_anchor - forward * to_anchor.dot(forward)
	distance = clampf(distance * factor, MIN_DISTANCE, MAX_DISTANCE)
	pivot += (1.0 - factor) * plane_delta
	_update_transform()


func _zoom_anchor(screen_pos: Vector2) -> Vector3:
	var vp := get_viewport()
	if vp == null:
		return pivot
	var vp_size := vp.get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return pivot
	var ray_origin := project_ray_origin(screen_pos)
	var ray_dir := project_ray_normal(screen_pos)
	var basis := global_transform.basis if is_inside_tree() else transform.basis
	var forward := -basis.z
	var denom := ray_dir.dot(forward)
	if absf(denom) < 1e-12:
		return pivot
	var t := (pivot - ray_origin).dot(forward) / denom
	return ray_origin + ray_dir * t


## Switch between perspective and orthographic, keeping apparent size:
## the ortho frustum height matches what the perspective fov sees at the pivot.
func toggle_projection() -> void:
	if projection == PROJECTION_PERSPECTIVE:
		projection = PROJECTION_ORTHOGONAL
	else:
		projection = PROJECTION_PERSPECTIVE
	_update_transform()


func set_view(new_yaw: float, new_pitch: float, animated := false) -> void:
	if animated:
		animate_to(new_yaw, new_pitch)
		return
	yaw = new_yaw
	pitch = clampf(new_pitch, MIN_PITCH, MAX_PITCH)
	_update_transform()


## Smoothly tween yaw/pitch to the target (shortest angular path for yaw).
func animate_to(new_yaw: float, new_pitch: float, duration := 0.25) -> void:
	new_pitch = clampf(new_pitch, MIN_PITCH, MAX_PITCH)
	if _view_tween != null and _view_tween.is_valid():
		_view_tween.kill()
		_view_tween = null
	if duration <= 0.0 or not is_inside_tree():
		yaw = new_yaw
		pitch = new_pitch
		_update_transform()
		return
	var start_yaw := yaw
	var start_pitch := pitch
	var yaw_delta := wrapf(new_yaw - start_yaw, -PI, PI)
	var target_yaw := start_yaw + yaw_delta
	_view_tween = create_tween()
	_view_tween.tween_method(
		func(t: float) -> void:
			yaw = lerpf(start_yaw, target_yaw, t)
			pitch = lerpf(start_pitch, new_pitch, t)
			_update_transform(),
		0.0, 1.0, duration
	)


## Frame selection when anything is selected; otherwise all bodies.
## Pass `force_all=true` for Shift+F / “fit whole model”.
func frame_selection_or_all(force_all := false) -> void:
	if not force_all and view != null and view.selected_body != "":
		if frame_selection():
			return
	frame_contents()


## Frames the current selection AABB (model → world). Returns false if empty.
func frame_selection() -> bool:
	if view == null:
		return false
	var bb: Dictionary = view.selection_bbox()
	if bb.is_empty():
		return false
	var mn: Vector3 = bb["min"]
	var mx: Vector3 = bb["max"]
	var corners: Array[Vector3] = [
		Vector3(mn.x, mn.y, mn.z), Vector3(mx.x, mn.y, mn.z),
		Vector3(mx.x, mx.y, mn.z), Vector3(mn.x, mx.y, mn.z),
		Vector3(mn.x, mn.y, mx.z), Vector3(mx.x, mn.y, mx.z),
		Vector3(mx.x, mx.y, mx.z), Vector3(mn.x, mx.y, mx.z),
	]
	var united := AABB()
	var first := true
	for c in corners:
		var w: Vector3 = model_space.to_global(c) if model_space != null else c
		var a := AABB(w, Vector3.ZERO)
		united = a if first else united.merge(a)
		first = false
	_frame_world_aabb(united)
	return true


## Frames all bodies (world-space AABB union); origin fallback when empty.
func frame_contents() -> void:
	if view == null or view.doc.body_ids().is_empty():
		pivot = Vector3.ZERO
		distance = DEFAULT_DISTANCE
		_update_transform()
		return
	var united := AABB()
	var first := true
	for id in view.doc.body_ids():
		var node := view.body_node(id)
		if node == null:
			continue
		var aabb := node.get_aabb()
		# Transform into world space through ModelSpace.
		var world_aabb: AABB = node.global_transform * aabb
		united = world_aabb if first else united.merge(world_aabb)
		first = false
	if first:
		return
	_frame_world_aabb(united)


func _frame_world_aabb(united: AABB) -> void:
	pivot = united.get_center()
	var radius: float = united.size.length() / 2.0
	distance = clampf(radius / tan(deg_to_rad(fov) / 2.0) * 1.2, MIN_DISTANCE, MAX_DISTANCE)
	_update_transform()


## Orient the camera to look along -normal (face “normal to” / look-at).
func look_along_model_normal(normal: Vector3) -> void:
	var n := normal.normalized()
	if n.length_squared() < 1e-8:
		return
	# Model Z-up: yaw around Z, pitch from XY plane.
	var yaw_n := atan2(n.x, -n.y)
	var pitch_n := asin(clampf(n.z, -1.0, 1.0))
	animate_to(yaw_n, pitch_n)
	if view != null and view.selected_body != "":
		frame_selection()


func save_named_view(view_name: String) -> void:
	_named_views[view_name] = {
		"yaw": yaw,
		"pitch": pitch,
		"distance": distance,
		"pivot": pivot,
		"projection": projection,
	}
	_save_named_views()


func restore_named_view(view_name: String) -> bool:
	if not _named_views.has(view_name):
		return false
	var v: Dictionary = _named_views[view_name]
	yaw = float(v["yaw"])
	pitch = float(v["pitch"])
	distance = float(v["distance"])
	pivot = v["pivot"] as Vector3
	projection = int(v["projection"]) as ProjectionType
	_update_transform()
	return true


func named_view_list() -> PackedStringArray:
	var keys := PackedStringArray()
	for k in _named_views.keys():
		keys.append(str(k))
	keys.sort()
	return keys


func remove_named_view(view_name: String) -> bool:
	if not _named_views.has(view_name):
		return false
	_named_views.erase(view_name)
	_save_named_views()
	return true


func _save_named_views() -> void:
	var cfg := ConfigFile.new()
	for view_name in _named_views:
		var v: Dictionary = _named_views[view_name]
		cfg.set_value(view_name, "yaw", v["yaw"])
		cfg.set_value(view_name, "pitch", v["pitch"])
		cfg.set_value(view_name, "distance", v["distance"])
		cfg.set_value(view_name, "pivot", v["pivot"])
		cfg.set_value(view_name, "projection", v["projection"])
	cfg.save(VIEWS_CFG)


func _load_named_views() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(VIEWS_CFG) != OK:
		return
	_named_views.clear()
	for section in cfg.get_sections():
		_named_views[section] = {
			"yaw": cfg.get_value(section, "yaw", 0.0),
			"pitch": cfg.get_value(section, "pitch", 0.0),
			"distance": cfg.get_value(section, "distance", DEFAULT_DISTANCE),
			"pivot": cfg.get_value(section, "pivot", Vector3.ZERO),
			"projection": cfg.get_value(section, "projection", PROJECTION_PERSPECTIVE),
		}


func _update_transform() -> void:
	if projection == PROJECTION_ORTHOGONAL:
		# Keep apparent size consistent with perspective: frustum height at the
		# pivot for the current fov. Wheel zoom then works in ortho too.
		size = 2.0 * distance * tan(deg_to_rad(fov) / 2.0)
	var offset := Vector3(
		cos(pitch) * sin(yaw),
		sin(pitch),
		cos(pitch) * cos(yaw)
	) * distance
	var pos := pivot + offset
	var look_target := _look_target_for(pos)
	if is_inside_tree():
		global_position = pos
		look_at(look_target, Vector3.UP)
	else:
		# Headless / orphan nodes (e.g. unit tests) cannot use look_at().
		look_at_from_position(pos, look_target, Vector3.UP)
	view_changed.emit()


## Aim above the orbit pivot along camera-up so the pivot projects low on screen.
func _look_target_for(camera_pos: Vector3) -> Vector3:
	if VIEW_PIVOT_Y_BIAS <= 0.0:
		return pivot
	var to_pivot := pivot - camera_pos
	if to_pivot.length_squared() < 1e-12:
		return pivot
	var forward := to_pivot.normalized()
	var right := forward.cross(Vector3.UP)
	if right.length_squared() < 1e-10:
		right = forward.cross(Vector3.RIGHT)
	right = right.normalized()
	var view_up := right.cross(forward).normalized()
	var half_height := distance * tan(deg_to_rad(fov) * 0.5)
	return pivot + view_up * (half_height * VIEW_PIVOT_Y_BIAS)
