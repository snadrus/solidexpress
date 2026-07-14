class_name OrbitCamera
extends Camera3D
## Turntable orbit camera: middle-drag orbits, shift+middle-drag pans,
## wheel zooms toward the cursor. F frames the scene contents;
## 1/2/3/7 jump to front/right/top/isometric standard views;
## 5 toggles orthographic/perspective projection.
## Named views persist in user://views.cfg.

var pivot := Vector3.ZERO
var distance := 400.0
var yaw := deg_to_rad(-35.0)
var pitch := deg_to_rad(30.0)
## Set by main; used by frame_contents (F) to fit all bodies.
var view: DocumentView
var model_space: Node3D

const MIN_DISTANCE := 5.0
const MAX_DISTANCE := 20000.0
const ORBIT_SPEED := 0.008
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


func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_at(mb.position, 0.9)
			return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_at(mb.position, 1.0 / 0.9)
			return true
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			if mm.shift_pressed:
				var pan_scale := distance * 0.0012
				pivot += global_transform.basis.x * (-mm.relative.x * pan_scale)
				pivot += global_transform.basis.y * (mm.relative.y * pan_scale)
			else:
				yaw -= mm.relative.x * ORBIT_SPEED
				pitch = clampf(pitch + mm.relative.y * ORBIT_SPEED, MIN_PITCH, MAX_PITCH)
			_update_transform()
			return true
	elif event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.ctrl_pressed:
			return false
		match k.keycode:
			KEY_F:
				frame_contents()
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


## Frames all bodies (world-space AABB union); origin fallback when empty.
func frame_contents() -> void:
	if view == null or view.doc.body_ids().is_empty():
		pivot = Vector3.ZERO
		distance = 400.0
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
	pivot = united.get_center()
	var radius: float = united.size.length() / 2.0
	distance = clampf(radius / tan(deg_to_rad(fov) / 2.0) * 1.2, MIN_DISTANCE, MAX_DISTANCE)
	_update_transform()


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
			"distance": cfg.get_value(section, "distance", 400.0),
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
	if is_inside_tree():
		global_position = pos
		look_at(pivot, Vector3.UP)
	else:
		# Headless / orphan nodes (e.g. unit tests) cannot use look_at().
		look_at_from_position(pos, pivot, Vector3.UP)
