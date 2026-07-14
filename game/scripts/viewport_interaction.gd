class_name ViewportInteraction
extends Control
## Full-window overlay owning all 3D interaction: selection clicks, body
## drag-move on the ground plane, face push/pull drag, and palette drops.

signal status(text: String)

var view: DocumentView
var camera: OrbitCamera
var model_space: Node3D  # kernel Z-up frame
var sketch_mode: SketchMode  # optional; when active, input goes to sketching

enum DragMode { NONE, MOVE_BODY, PUSH_PULL }
var _drag_mode := DragMode.NONE
var _drag_start_mouse := Vector2.ZERO
var _drag_start_point := Vector3.ZERO   # model-space hit point at drag start
var _drag_normal := Vector3.ZERO        # model-space face normal (push/pull)
var _drag_accum := Vector3.ZERO         # applied translation so far
var _drag_pp_applied := 0.0
var _press_pos := Vector2.ZERO
var _pressed := false

const CLICK_SLOP := 6.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_ALL


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


func insert_at_center(kind: String) -> void:
	var gp = ground_point(size / 2.0)
	if gp == null:
		gp = Vector3.ZERO
	view.insert_primitive(kind, gp)
	status.emit("Inserted " + kind)


func _gui_input(event: InputEvent) -> void:
	if camera.handle_input(event):
		accept_event()
		return
	if sketch_mode != null and sketch_mode.active:
		_sketch_input(event)
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
	return false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and has_focus():
		if _gui_key(event):
			accept_event()
