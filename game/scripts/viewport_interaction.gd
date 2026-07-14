class_name ViewportInteraction
extends Control
## Full-window overlay owning all 3D interaction: selection clicks, body
## drag-move on the ground plane, face push/pull drag, palette drops, and
## click-to-place for palette button clicks.

signal status(text: String)

var view: DocumentView
var camera: OrbitCamera
var model_space: Node3D  # kernel Z-up frame
var sketch_mode: SketchMode  # optional; when active, input goes to sketching
var world_gizmos: WorldGizmos

enum DragMode { NONE, MOVE_BODY, PUSH_PULL }
var _drag_mode := DragMode.NONE
var _drag_start_mouse := Vector2.ZERO
var _drag_start_point := Vector3.ZERO   # model-space hit point at drag start
var _drag_normal := Vector3.ZERO        # model-space face normal (push/pull)
var _drag_accum := Vector3.ZERO         # applied translation so far
var _drag_pp_applied := 0.0
var _press_pos := Vector2.ZERO
var _pressed := false

## Armed click-to-place kind, or "" when idle.
var _place_kind := ""
var _place_ghost: MeshInstance3D = null

const CLICK_SLOP := 6.0
const GHOST_NAME := "PlaceGhost"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_ALL
	_mount_world_gizmos()


## Origin triad + ground grid as a sibling of DocumentView under ModelSpace.
func _mount_world_gizmos() -> void:
	if model_space == null:
		return
	if model_space.get_node_or_null("WorldGizmos") != null:
		world_gizmos = model_space.get_node("WorldGizmos") as WorldGizmos
		return
	world_gizmos = WorldGizmos.new()
	world_gizmos.name = "WorldGizmos"
	model_space.add_child(world_gizmos)


func _model_ray(screen_pos: Vector2) -> Array:
	# Returns [origin, direction] in model (kernel Z-up) space.
	var world_origin := camera.project_ray_origin(screen_pos)
	var world_dir := camera.project_ray_normal(screen_pos)
	var inv: Transform3D = model_space.global_transform.affine_inverse()
	return [inv * world_origin, inv.basis * world_dir]


## Intersection of the screen ray with the model XY (ground) plane.
func ground_point(screen_pos: Vector2) -> Variant:
	var ray := _model_ray(screen_pos)
	var origin: Vector3 = ray[0]
	var dir: Vector3 = ray[1]
	if absf(dir.z) < 1e-9:
		return null
	var t := -origin.z / dir.z
	return null if t < 0 else origin + dir * t


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("sx_primitive")


func _drop_data(at: Vector2, data: Variant) -> void:
	var gp = ground_point(at)
	if gp == null:
		gp = Vector3.ZERO
	view.insert_primitive(data["sx_primitive"], gp)
	status.emit("Inserted " + str(data["sx_primitive"]))


## Arm click-to-place for `kind` (palette button click). Does not insert yet.
func insert_at_center(kind: String) -> void:
	_arm_place(kind)


func _screen_center() -> Vector2:
	if size.x > 1.0 and size.y > 1.0:
		return size * 0.5
	return get_viewport().get_visible_rect().size * 0.5


func _arm_place(kind: String) -> void:
	_free_ghost()
	_place_kind = kind
	status.emit("Click to place %s (Esc to cancel)" % kind)
	_place_ghost = _make_ghost(kind)
	model_space.add_child(_place_ghost)
	_update_ghost(_screen_center())


func _make_ghost(kind: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = GHOST_NAME
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh: Mesh
	match kind:
		"box":
			var bm := BoxMesh.new()
			bm.size = Vector3(60, 60, 60)
			mesh = bm
		"cylinder", "cone":
			var cm := CylinderMesh.new()
			cm.top_radius = 25.0
			cm.bottom_radius = 25.0 if kind == "cylinder" else 5.0
			cm.height = 50.0
			mesh = cm
			# Godot cylinder is Y-up; model space is Z-up.
			mi.rotation_degrees.x = 90.0
		"sphere", "torus":
			var sm := SphereMesh.new()
			sm.radius = 25.0
			sm.height = 50.0
			mesh = sm
		_:
			var fallback := BoxMesh.new()
			fallback.size = Vector3(60, 60, 60)
			mesh = fallback
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.45, 0.7, 1.0, 0.4)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	return mi


func _update_ghost(screen_pos: Vector2) -> void:
	if _place_ghost == null:
		return
	var gp = ground_point(screen_pos)
	if gp == null:
		_place_ghost.visible = false
	else:
		_place_ghost.visible = true
		_place_ghost.position = gp


func _free_ghost() -> void:
	if _place_ghost != null and is_instance_valid(_place_ghost):
		_place_ghost.queue_free()
	_place_ghost = null


func _disarm_place(emit_cancel: bool) -> void:
	_free_ghost()
	_place_kind = ""
	if emit_cancel:
		status.emit("Placement cancelled")


func _commit_place(screen_pos: Vector2) -> void:
	var kind := _place_kind
	var gp = ground_point(screen_pos)
	var need_frame := gp == null
	if need_frame:
		gp = Vector3.ZERO
	_free_ghost()
	_place_kind = ""
	view.insert_primitive(kind, gp)
	status.emit("Inserted " + kind)
	if need_frame:
		camera.frame_contents()


func _place_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_ghost((event as InputEventMouseMotion).position)
		accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_commit_place(mb.position)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_disarm_place(true)
			accept_event()


func _gui_input(event: InputEvent) -> void:
	if camera.handle_input(event):
		accept_event()
		return
	if sketch_mode != null and sketch_mode.active:
		if _place_kind != "":
			_disarm_place(false)
		_sketch_input(event)
		return
	if _place_kind != "":
		_place_input(event)
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_on_press(mb.position)
			else:
				_on_release(mb.position)
			accept_event()
	elif event is InputEventMouseMotion and _pressed:
		_on_drag(event.position)
		accept_event()


func _sketch_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var ray := _model_ray(mb.position)
			var p2 = sketch_mode.ray_to_sketch(ray[0], ray[1])
			if p2 != null:
				sketch_mode.click(p2)
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			sketch_mode.end_chain()
			accept_event()
	elif event is InputEventMouseMotion:
		var ray := _model_ray(event.position)
		var p2 = sketch_mode.ray_to_sketch(ray[0], ray[1])
		if p2 != null:
			sketch_mode.hover(p2)
	elif event is InputEventKey and event.pressed and not event.ctrl_pressed:
		match (event as InputEventKey).keycode:
			KEY_S: sketch_mode.set_tool(SketchMode.Tool.SELECT)
			KEY_L: sketch_mode.set_tool(SketchMode.Tool.LINE)
			KEY_R: sketch_mode.set_tool(SketchMode.Tool.RECT)
			KEY_C: sketch_mode.set_tool(SketchMode.Tool.CIRCLE)
			KEY_T: sketch_mode.set_tool(SketchMode.Tool.TRIM)
			KEY_X: sketch_mode.toggle_construction_selected()
			KEY_ESCAPE: sketch_mode.cancel()
		accept_event()


func _on_press(pos: Vector2) -> void:
	_pressed = true
	_press_pos = pos
	_drag_mode = DragMode.NONE
	grab_focus()

	# If pressing on the current selection, arm a drag; commit on movement.
	var ray := _model_ray(pos)
	var hit: Dictionary = view.pick_info(ray[0], ray[1])
	if hit.is_empty() or view.selected_body == "":
		return
	if hit["body"] != view.selected_body:
		return
	if view.selected_face != "" and hit["face"] == view.selected_face:
		_drag_mode = DragMode.PUSH_PULL
		_drag_normal = view.selected_face_normal()
		_drag_pp_applied = 0.0
	else:
		_drag_mode = DragMode.MOVE_BODY
		_drag_accum = Vector3.ZERO
	_drag_start_mouse = pos
	_drag_start_point = hit["point"]


func _on_drag(pos: Vector2) -> void:
	if pos.distance_to(_press_pos) < CLICK_SLOP:
		return
	match _drag_mode:
		DragMode.MOVE_BODY:
			var gp = ground_point(pos)
			var gp0 = ground_point(_drag_start_mouse)
			if gp == null or gp0 == null:
				return
			var target: Vector3 = gp - gp0
			target.z = 0
			var delta: Vector3 = target - _drag_accum
			if delta.length() > 1e-6:
				# Live preview: nudge the scene node; commit to kernel on release.
				var node := view.body_node(view.selected_body)
				if node:
					node.position += delta
				_drag_accum = target
			status.emit("Move: (%.1f, %.1f)" % [target.x, target.y])
		DragMode.PUSH_PULL:
			var d := _push_pull_distance(pos)
			status.emit("Push/pull: %.1f mm (release to apply)" % d)


func _push_pull_distance(pos: Vector2) -> float:
	# Distance along the face normal: closest approach between the screen ray
	# and the line (start_point, normal).
	var ray := _model_ray(pos)
	var o: Vector3 = ray[0]
	var d: Vector3 = ray[1]
	var p := _drag_start_point
	var n := _drag_normal
	var cross_dn := d.cross(n)
	var denom := cross_dn.length_squared()
	if denom < 1e-12:
		return 0.0
	return (o - p).dot(cross_dn.cross(d)) / denom


func _on_release(pos: Vector2) -> void:
	_pressed = false
	var was_click := pos.distance_to(_press_pos) < CLICK_SLOP
	match _drag_mode:
		DragMode.MOVE_BODY:
			if not was_click and _drag_accum.length() > 1e-6:
				view.move_selected(_drag_accum)
				status.emit("Moved body")
				_drag_mode = DragMode.NONE
				return
		DragMode.PUSH_PULL:
			if not was_click:
				var dist := _push_pull_distance(pos)
				if absf(dist) > 1e-3:
					if view.push_pull_selected(dist):
						status.emit("Push/pull %.1f mm applied" % dist)
					else:
						status.emit("Push/pull failed (planar faces only for now)")
				_drag_mode = DragMode.NONE
				return
	_drag_mode = DragMode.NONE
	if was_click:
		var ray := _model_ray(pos)
		if view.select_ray(ray[0], ray[1]):
			status.emit("Selected " + (view.selected_face if view.selected_face != "" else view.selected_body).left(8))
		else:
			status.emit("")


func _gui_key(event: InputEventKey) -> bool:
	if not event.pressed:
		return false
	match event.keycode:
		KEY_ESCAPE:
			# Sketch Esc is handled in _sketch_input; do not steal it.
			if sketch_mode != null and sketch_mode.active:
				return false
			if _place_kind != "":
				_disarm_place(true)
				return true
			view.clear_selection()
			status.emit("")
			return true
		KEY_DELETE, KEY_BACKSPACE:
			if view.delete_selected():
				status.emit("Deleted body")
			return true
		KEY_Z:
			if event.ctrl_pressed:
				if event.shift_pressed:
					view.redo()
				else:
					view.undo()
				status.emit("Undo/redo")
				return true
		KEY_Y:
			if event.ctrl_pressed:
				view.redo()
				status.emit("Redo")
				return true
		KEY_W:
			if not event.ctrl_pressed:
				var mode: int = view.cycle_display_mode()
				status.emit("Display: " + ["Shaded", "Shaded + Edges", "Wireframe"][mode])
				return true
		KEY_K:
			if not event.ctrl_pressed:
				toggle_section()
				return true
		KEY_G:
			if not event.ctrl_pressed and world_gizmos != null:
				world_gizmos.set_gizmos_visible(not world_gizmos.gizmos_visible)
				status.emit("Gizmos " + ("on" if world_gizmos.gizmos_visible else "off"))
				return true
	return false


## Midpoint of all bodies' combined AABB (model space), or ZERO if empty.
func _bodies_aabb_center() -> Vector3:
	var first := true
	var united_min := Vector3.ZERO
	var united_max := Vector3.ZERO
	for id in view.doc.body_ids():
		var bb: Dictionary = view.doc.measure_bbox(id)
		if bb.is_empty():
			continue
		var mn: Vector3 = bb["min"]
		var mx: Vector3 = bb["max"]
		if first:
			united_min = mn
			united_max = mx
			first = false
		else:
			united_min = united_min.min(mn)
			united_max = united_max.max(mx)
	if first:
		return Vector3.ZERO
	return (united_min + united_max) * 0.5


## Toggle section-view clipping through the combined body AABB center (+X).
func toggle_section() -> void:
	if view.section_enabled:
		view.clear_section_plane()
		status.emit("Section view off")
	else:
		var center := _bodies_aabb_center()
		view.set_section_plane(center, Vector3(1, 0, 0))
		status.emit("Section view on")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and has_focus():
		if _gui_key(event):
			accept_event()
