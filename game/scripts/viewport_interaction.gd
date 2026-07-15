class_name ViewportInteraction
extends Control
## Full-window overlay owning all 3D interaction: selection clicks, body
## drag-move on the ground plane, face push/pull drag, palette drops, and
## click-to-place for palette button clicks.

signal status(text: String)
## Emitted when click-to-place arms or disarms (main swaps left-rail chrome).
signal place_changed(active: bool)
## Request sketch-on-selection (main owns SketchMode.begin).
signal sketch_requested

var view: DocumentView
var camera: OrbitCamera
var model_space: Node3D  # kernel Z-up frame
var sketch_mode: SketchMode  # optional; when active, input goes to sketching
var world_gizmos: WorldGizmos
var transform_hud: TransformHud
var ops_panel: OpsPanel

enum DragMode { NONE, MOVE_BODY, ROTATE_BODY, PUSH_PULL, BOX_SELECT, ORBIT_VIEW, RESIZE_BODY, MOVE_INSTANCE }
var _drag_mode := DragMode.NONE
var _drag_start_mouse := Vector2.ZERO
var _drag_start_point := Vector3.ZERO   # model-space hit point at drag start
var _drag_normal := Vector3.ZERO        # model-space face normal (push/pull)
var _drag_accum := Vector3.ZERO         # applied translation so far (move)
var _drag_pp_applied := 0.0
var _press_pos := Vector2.ZERO
var _pressed := false
var _last_drag_pos := Vector2.ZERO
## Move drag: pre-drag selection center + body node transform for live preview.
var _move_start_center := Vector3.ZERO
var _move_start_node_xform := Transform3D.IDENTITY
var _move_delta_base := Vector3.ZERO  # last kernel-committed Δ from start center
## Blender-style axis lock during a body move: tap X/Y to toggle (-1 = free).
const AXIS_X := 0
const AXIS_Y := 1
var _move_axis_lock := -1
## Rotate drag about a principal axis through the selection center.
var _rotate_axis := Vector3.ZERO
var _rotate_center := Vector3.ZERO
var _rotate_start_angle := 0.0
var _rotate_angle := 0.0
var _rotate_start_node_xform := Transform3D.IDENTITY
## True when the LMB press landed on empty space (orbit / box-select candidate).
var _press_empty := false
## Screen travel accumulated during the current press (for soft click detection).
var _press_travel := 0.0
## Screen-space rubber-band rect while in BOX_SELECT (drawn via _draw).
var _box_rect := Rect2()
## Ctrl held on the last LMB press: empty-drag becomes rubber-band box select.
var _box_drag := false
## Shift or Ctrl held on press: additive select; empty click will not clear.
var _additive_click := false
## SELECT-tool drag-to-edit in sketch mode (begin/update/end_drag).
var _sketch_dragging := false
var _sketch_drag_moved := false
## Push/pull preview distance (wire badge while dragging).
var _pp_preview_dist := 0.0
var _pp_badge_screen := Vector2.ZERO
## Selection-aware chrome.
var _context_menu: PopupMenu
var _selection_strip: PanelContainer
var _strip_fillet: Button
var _strip_hide: Button
var _strip_delete: Button
var _strip_sketch: Button
var _strip_look: Button
## RMB: click = context menu, drag = orbit (peer FreeCAD / SW-like).
var _rmb_pressed := false
var _rmb_press_pos := Vector2.ZERO
var _rmb_orbiting := false
## LMB on selected body: wait for travel before arming move (avoids nudge).
var _pending_body_move := false
var _pending_move_point := Vector3.ZERO
## LMB on a component instance: deferred ground-plane drag; on release the
## transform commits and mates re-solve (peer "drag then snap home" feel).
var _pending_instance_move := false
var _drag_instance_id := ""
var _instance_start_xform := Transform3D.IDENTITY
var _instance_grab_point := Vector3.ZERO
## Spacebar orientation / named-view popup (SW Spacebar / Onshape S lite).
var _orient_popup: PopupPanel
## Click-a-dimension in-viewport editor (sketch SELECT tool).
var _dim_edit_popup: PopupPanel
var _dim_edit_line: LineEdit
var _dim_edit_index := -1
var _last_hover_key := ""

## Armed click-to-place kind, or "" when idle.
var _place_kind := ""
var _place_ghost: MeshInstance3D = null
## Sizes used for the place ghost / commit (W×H×D mm; see DocumentView mapping).
var place_size := Vector3(
		DocumentView.DEFAULT_PRIMITIVE_MM,
		DocumentView.DEFAULT_PRIMITIVE_MM,
		DocumentView.DEFAULT_PRIMITIVE_MM)
## After a place commit, skip the matching LMB release select (avoids clear-on-miss).
var _ignore_select_release := false
## Place-mode snap UI (shown while armed).
var place_snap_enabled := true
var place_snap_mm := 0.1
var _place_snap_panel: PanelContainer
var _place_snap_check: CheckBox
var _place_snap_spin: SpinBox

## Resize-drag state (AABB corner / face-center handles).
var _resize_min := Vector3.ZERO
var _resize_max := Vector3.ZERO
var _resize_start_min := Vector3.ZERO
var _resize_start_max := Vector3.ZERO
## Per-axis: -1 = moving min face, +1 = moving max face, 0 = fixed.
var _resize_signs := Vector3.ZERO
var _resize_distance := 0.0
var _resize_axis_hint := "Δ"
## Precision field: last committed resize distance / rotate degrees.
var _precision_base := 0.0
var _precision_signs := Vector3.ZERO
var _precision_min := Vector3.ZERO
var _precision_max := Vector3.ZERO
var _precision_kind := ""  # "resize" | "rotate"
var _precision_rotate_axis := Vector3.ZERO
var _precision_rotate_center := Vector3.ZERO

const CLICK_SLOP := 12.0
## Empty-drag travel below this is still treated as a deselect click (trackpad).
const ORBIT_CLICK_SLOP := 22.0
const HANDLE_PX := 22.0
const AXIS_HANDLE_PX := 26.0
const AXIS_LEN_FRAC := 0.35
const GHOST_NAME := "PlaceGhost"
## Kernel primitive sizes used for sit-on-plane ghost offsets (half-heights).
const PLACE_HALF_Z := {
	"box": 5.0,
	"cylinder": 5.0,
	"cone": 5.0,
	"sphere": 5.0,
	"torus": 1.6,
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# anchors_and_offsets so we actually fill the viewport (preset alone can
	# leave size at 0 until a parent container lays us out — and we are not
	# in a container).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_ALL
	_mount_world_gizmos()
	_build_place_snap_ui()
	_build_transform_hud()
	_build_context_menu()
	_build_selection_strip()
	_build_orient_popup()
	_build_dim_edit_popup()
	if sketch_mode != null:
		sketch_mode.dimension_edit_requested.connect(_show_dim_edit)
		# Strip hides while sketching (modal); restore it when the sketch ends.
		sketch_mode.finished.connect(func(_id: String) -> void: _refresh_selection_strip())
		sketch_mode.cancelled.connect(_refresh_selection_strip)
	if view != null:
		view.selection_changed.connect(_on_view_selection_changed)
		view.document_changed.connect(_on_view_document_changed)


func is_placing() -> bool:
	return _place_kind != ""


## Re-evaluate the selection strip (call after entering sketch mode, which
## has no start signal of its own).
func refresh_selection_chrome() -> void:
	_refresh_selection_strip()


func _process(_delta: float) -> void:
	# Keep gizmo screen projections tracking the camera.
	if view != null and view.selected_body != "" and _place_kind == "":
		queue_redraw()


func _build_transform_hud() -> void:
	transform_hud = TransformHud.new()
	transform_hud.name = "TransformHud"
	add_child(transform_hud)
	transform_hud.position_committed.connect(_on_hud_position)
	transform_hud.size_committed.connect(_on_hud_size)
	transform_hud.precision_committed.connect(_on_hud_precision)
	transform_hud.move_delta_committed.connect(_on_hud_move_delta)


func _build_context_menu() -> void:
	_context_menu = PopupMenu.new()
	_context_menu.name = "SelectionContext"
	add_child(_context_menu)
	_context_menu.id_pressed.connect(_on_context_id)


func _build_selection_strip() -> void:
	_selection_strip = PanelContainer.new()
	_selection_strip.name = "SelectionStrip"
	_selection_strip.visible = false
	_selection_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_strip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_selection_strip.offset_left = -260
	_selection_strip.offset_right = 260
	_selection_strip.offset_top = 8
	_selection_strip.offset_bottom = 44
	add_child(_selection_strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_selection_strip.add_child(row)
	_strip_fillet = Button.new()
	_strip_fillet.text = "Fillet"
	_strip_fillet.pressed.connect(func() -> void: _ctx_fillet())
	row.add_child(_strip_fillet)
	_strip_sketch = Button.new()
	_strip_sketch.text = "Sketch"
	_strip_sketch.tooltip_text = "Sketch on the selected face (then Extrude from the sketch bar)"
	_strip_sketch.pressed.connect(func() -> void: sketch_requested.emit())
	row.add_child(_strip_sketch)
	_strip_look = Button.new()
	_strip_look.text = "Look at"
	_strip_look.tooltip_text = "Orient the camera normal to the selected face"
	_strip_look.pressed.connect(func() -> void: _ctx_look_at())
	row.add_child(_strip_look)
	_strip_hide = Button.new()
	_strip_hide.text = "Hide"
	_strip_hide.pressed.connect(func() -> void: _ctx_hide())
	row.add_child(_strip_hide)
	_strip_delete = Button.new()
	_strip_delete.text = "Delete"
	_strip_delete.pressed.connect(func() -> void: _ctx_delete())
	row.add_child(_strip_delete)


func _build_orient_popup() -> void:
	_orient_popup = PopupPanel.new()
	_orient_popup.name = "OrientPopup"
	add_child(_orient_popup)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_orient_popup.add_child(col)
	var title := Label.new()
	title.text = "Orientation (Space)"
	col.add_child(title)
	for entry in [
		["Front", 1], ["Right", 2], ["Top", 3], ["Isometric", 7],
		["Fit selection", 20], ["Fit all", 21], ["Ortho/Persp", 5],
		["Restore “User”", 30],
	]:
		var b := Button.new()
		b.text = str(entry[0])
		var id: int = int(entry[1])
		b.pressed.connect(func() -> void:
			_on_orient_id(id)
			_orient_popup.hide())
		col.add_child(b)


func _build_dim_edit_popup() -> void:
	_dim_edit_popup = PopupPanel.new()
	_dim_edit_popup.name = "DimEditPopup"
	add_child(_dim_edit_popup)
	var row := HBoxContainer.new()
	_dim_edit_popup.add_child(row)
	var lbl := Label.new()
	lbl.text = "Dim:"
	row.add_child(lbl)
	_dim_edit_line = LineEdit.new()
	_dim_edit_line.custom_minimum_size = Vector2(90, 0)
	_dim_edit_line.select_all_on_focus = true
	_dim_edit_line.text_submitted.connect(_apply_dim_edit)
	row.add_child(_dim_edit_line)


## Open the in-viewport dimension editor for dimensions[index] (SELECT click
## on the label). Enter commits + re-solves; Esc / clicking away cancels.
func _show_dim_edit(index: int) -> void:
	if sketch_mode == null or _dim_edit_popup == null:
		return
	if index < 0 or index >= sketch_mode.dimensions.size():
		return
	_dim_edit_index = index
	var dim: Dictionary = sketch_mode.dimensions[index]
	_dim_edit_line.text = String.num(sketch_mode._dimension_display_value(dim), 3)
	var at := Vector2i(get_viewport().get_mouse_position()) + Vector2i(8, 8)
	_dim_edit_popup.popup(Rect2i(at, Vector2i(150, 40)))
	_dim_edit_line.grab_focus()


func _apply_dim_edit(text: String) -> void:
	_dim_edit_popup.hide()
	if sketch_mode == null or _dim_edit_index < 0:
		return
	var v := text.to_float()
	if v <= 0.0:
		status.emit("Dimension must be a positive number")
		return
	var result: String = sketch_mode.set_dimension_value(_dim_edit_index, v)
	_dim_edit_index = -1
	if result == "failed":
		status.emit("Dimension rejected — constraints could not be satisfied")
	elif result != "":
		status.emit("Dimension updated")


func _build_place_snap_ui() -> void:
	_place_snap_panel = PanelContainer.new()
	_place_snap_panel.name = "PlaceSnapBar"
	_place_snap_panel.visible = false
	_place_snap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_snap_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_place_snap_panel.offset_left = -160
	_place_snap_panel.offset_right = 160
	_place_snap_panel.offset_top = -148
	_place_snap_panel.offset_bottom = -92
	add_child(_place_snap_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_place_snap_panel.add_child(row)
	_place_snap_check = CheckBox.new()
	_place_snap_check.text = "Snap to grid"
	_place_snap_check.button_pressed = place_snap_enabled
	_place_snap_check.toggled.connect(func(on: bool) -> void:
		place_snap_enabled = on)
	row.add_child(_place_snap_check)
	var lbl := Label.new()
	lbl.text = "Res"
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)
	_place_snap_spin = SpinBox.new()
	_place_snap_spin.min_value = 0.01
	_place_snap_spin.max_value = 100.0
	_place_snap_spin.step = 0.01
	_place_snap_spin.value = place_snap_mm
	_place_snap_spin.suffix = "mm"
	_place_snap_spin.custom_minimum_size = Vector2(100, 0)
	_place_snap_spin.value_changed.connect(func(v: float) -> void:
		place_snap_mm = maxf(v, 0.01))
	row.add_child(_place_snap_spin)


func _snap_point(p: Vector3) -> Vector3:
	if not place_snap_enabled:
		return p
	var s := maxf(place_snap_mm, 0.01)
	return Vector3(snappedf(p.x, s), snappedf(p.y, s), snappedf(p.z, s))


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
	return _horizontal_plane_point(screen_pos, 0.0)


## Intersection with a horizontal plane at model height `z` (active move plane).
func _horizontal_plane_point(screen_pos: Vector2, z: float) -> Variant:
	var ray := _model_ray(screen_pos)
	var origin: Vector3 = ray[0]
	var dir: Vector3 = ray[1]
	if absf(dir.z) < 1e-9:
		return null
	var t := (z - origin.z) / dir.z
	return null if t < 0 else origin + dir * t


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("sx_primitive")


func _drop_data(at: Vector2, data: Variant) -> void:
	var target := _place_target(at)
	var kind: String = str(data["sx_primitive"])
	view.insert_primitive(kind, target["point"], DocumentView.default_primitive_size(kind))
	_ignore_select_release = true
	if target.get("stacked", false):
		status.emit("Stacked " + kind + " — Alt-drag or two-finger drag to orbit")
	else:
		status.emit("Inserted " + kind + " — Alt-drag or two-finger drag to orbit")
	if target.get("need_frame", false):
		camera.frame_contents()
	_refresh_transform_hud()


## Arm click-to-place for `kind` (palette button click). Does not insert yet.
func insert_at_center(kind: String) -> void:
	_arm_place(kind)


func _screen_center() -> Vector2:
	if size.x > 1.0 and size.y > 1.0:
		return size * 0.5
	return get_viewport().get_visible_rect().size * 0.5


## Half-height offset so a centered Godot mesh sits with its floor on z=floor.
func _ghost_sit_offset(kind: String) -> Vector3:
	match kind:
		"box", "cylinder", "cone":
			return Vector3(0, 0, place_size.z * 0.5)
		"sphere":
			return Vector3(0, 0, place_size.x * 0.5)
		"torus":
			return Vector3(0, 0, place_size.y * 0.5)
		_:
			var hz: float = float(PLACE_HALF_Z.get(kind, 25.0))
			return Vector3(0, 0, hz)


## Resolve place floor: body hit → sit on that point's height; else ground z=0.
func _place_target(screen_pos: Vector2) -> Dictionary:
	var ray := _model_ray(screen_pos)
	var hit: Dictionary = view.pick_info(ray[0], ray[1])
	if not hit.is_empty() and hit.has("point"):
		var pt: Vector3 = hit["point"]
		# Snap soft stacking to the hit body's top when the click is near it.
		var body: String = str(hit.get("body", ""))
		if body != "":
			var bb: Dictionary = view.doc.measure_bbox(body)
			if not bb.is_empty():
				var mx: Vector3 = bb["max"]
				if pt.z >= float(mx.z) - 2.0:
					pt = Vector3(pt.x, pt.y, float(mx.z))
		pt = _snap_point(pt)
		return {"point": pt, "stacked": true, "need_frame": false}
	var gp = ground_point(screen_pos)
	if gp == null:
		return {"point": Vector3.ZERO, "stacked": false, "need_frame": true}
	return {"point": _snap_point(gp), "stacked": false, "need_frame": false}


func _arm_place(kind: String) -> void:
	_free_ghost()
	view.clear_selection()
	view.clear_hover()
	_place_kind = kind
	place_size = DocumentView.default_primitive_size(kind)
	grab_focus()
	if _place_snap_panel != null:
		_place_snap_panel.visible = true
		_place_snap_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		_place_snap_check.button_pressed = place_snap_enabled
		_place_snap_spin.value = place_snap_mm
	status.emit("Click ground or a face to place %s (Esc to cancel)" % kind)
	_place_ghost = _make_ghost(kind)
	model_space.add_child(_place_ghost)
	_update_ghost(_screen_center())
	_refresh_transform_hud()
	place_changed.emit(true)


func _make_ghost(kind: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = GHOST_NAME
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_apply_ghost_mesh(mi, kind, place_size)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.45, 0.7, 1.0, 0.4)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	return mi


func _apply_ghost_mesh(mi: MeshInstance3D, kind: String, s: Vector3) -> void:
	mi.rotation_degrees = Vector3.ZERO
	var mesh: Mesh
	match kind:
		"box":
			var bm := BoxMesh.new()
			bm.size = Vector3(s.x, s.y, s.z)
			mesh = bm
		"cylinder", "cone":
			var cm := CylinderMesh.new()
			cm.top_radius = s.y * 0.5 if kind == "cone" else s.x * 0.5
			cm.bottom_radius = s.x * 0.5
			cm.height = s.z
			mesh = cm
			# Godot cylinder is Y-up; model space is Z-up.
			mi.rotation_degrees.x = 90.0
		"sphere":
			var sm := SphereMesh.new()
			sm.radius = s.x * 0.5
			sm.height = s.x
			mesh = sm
		"torus":
			var tm := SphereMesh.new()
			tm.radius = s.y * 0.5
			tm.height = s.y
			mesh = tm
		_:
			var fallback := BoxMesh.new()
			fallback.size = s
			mesh = fallback
	mi.mesh = mesh


func _update_ghost(screen_pos: Vector2) -> void:
	if _place_ghost == null:
		return
	var target := _place_target(screen_pos)
	var floor_pt: Vector3 = target["point"]
	_place_ghost.visible = true
	_place_ghost.position = floor_pt + _ghost_sit_offset(_place_kind)
	# Don't clobber typed values while a HUD SpinBox has focus.
	if transform_hud != null and transform_hud.visible and not _hud_editing():
		transform_hud.set_values(floor_pt, place_size, true)


func _hud_editing() -> bool:
	if transform_hud == null:
		return false
	var focused := get_viewport().gui_get_focus_owner()
	return focused != null and transform_hud.is_ancestor_of(focused)


func _free_ghost() -> void:
	if _place_ghost != null and is_instance_valid(_place_ghost):
		_place_ghost.queue_free()
	_place_ghost = null


func _disarm_place(emit_cancel: bool) -> void:
	_free_ghost()
	_place_kind = ""
	if _place_snap_panel != null:
		_place_snap_panel.visible = false
		_place_snap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if emit_cancel:
		status.emit("Placement cancelled")
	_refresh_transform_hud()
	place_changed.emit(false)


func _commit_place(screen_pos: Vector2) -> void:
	var kind := _place_kind
	var target := _place_target(screen_pos)
	_free_ghost()
	_place_kind = ""
	if _place_snap_panel != null:
		_place_snap_panel.visible = false
		_place_snap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ignore_select_release = true
	view.insert_primitive(kind, target["point"], place_size)
	if target.get("stacked", false):
		status.emit("Stacked %s on face — drag empty space or Alt-drag to orbit" % kind)
	else:
		status.emit("Inserted %s — drag empty space or Alt-drag to orbit" % kind)
	if target.get("need_frame", false):
		camera.frame_contents()
	_refresh_transform_hud()
	place_changed.emit(false)


func _place_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_ghost((event as InputEventMouseMotion).position)
		accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			# Swallow the release that paired with a place-commit press.
			if _ignore_select_release and mb.button_index == MOUSE_BUTTON_LEFT:
				_ignore_select_release = false
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_commit_place(mb.position)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_disarm_place(true)
			accept_event()


func _gui_input(event: InputEvent) -> void:
	# Prefer `_input` for model pointers (works when this Control is not the
	# hovered target). Keep `_gui_input` as a fallback for headless tests and
	# for sketch which historically used Control-local events.
	var allow_scroll := not OrbitCamera.pointer_over_scrollable_ui()
	if camera != null and camera.is_nav_event(event, allow_scroll):
		if camera.handle_input(event, allow_scroll):
			accept_event()
		return
	# Place is owned entirely by `_input` — do not swallow `_gui_input` here.
	if _place_kind != "":
		return
	if sketch_mode != null and sketch_mode.active:
		_sketch_input(event)
		return
	if _handle_model_pointer(event):
		accept_event()


## True when the pointer is over the 3D view (or nothing), not a dock / HUD.
func _viewport_owns_pointer() -> bool:
	var vp := get_viewport()
	if vp == null:
		return true
	var h: Control = vp.gui_get_hovered_control()
	if h == null:
		# Nothing under the cursor (or Interaction size not hit-tested) → allow
		# viewport gestures from `_input`.
		return true
	if h == self:
		return true
	# TransformHud / SelectionStrip / PlaceSnapBar / PopupMenu are our children.
	if is_ancestor_of(h):
		return false
	return false


## Shared LMB / motion path for select, empty-orbit, and handle drags.
## Returns true when the event was consumed.
func _handle_model_pointer(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		# RMB click = context menu; RMB drag = orbit (FreeCAD / peer-friendly).
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_rmb_pressed = true
				_rmb_press_pos = mb.position
				_rmb_orbiting = false
				_last_drag_pos = mb.position
			else:
				if _rmb_pressed and not _rmb_orbiting:
					_open_context_menu(_rmb_press_pos)
				_rmb_pressed = false
				_rmb_orbiting = false
			return true
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_box_drag = mb.ctrl_pressed
				_additive_click = mb.shift_pressed or mb.ctrl_pressed
				_on_press(mb.position)
			else:
				# After place/drop, suppress the select-on-release click — but still
				# finish a real drag (empty-orbit, move, box select, push/pull).
				if _ignore_select_release and _drag_mode == DragMode.NONE:
					_ignore_select_release = false
					_pressed = false
					return true
				_ignore_select_release = false
				_on_release(mb.position)
			return true
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _rmb_pressed:
			if not _rmb_orbiting and mm.position.distance_to(_rmb_press_pos) >= CLICK_SLOP:
				_rmb_orbiting = true
				_last_drag_pos = _rmb_press_pos
				status.emit("Orbit (right-drag) — release without drag for context menu")
			if _rmb_orbiting and camera != null:
				var rel := mm.position - _last_drag_pos
				_last_drag_pos = mm.position
				if Input.is_key_pressed(KEY_SHIFT):
					camera._pan_by(rel.x, rel.y)
				else:
					camera._orbit_by(rel.x, rel.y)
			return true
		if _pressed:
			_on_drag(mm.position)
			return true
		_update_hover(mm.position)
		return false
	return false


func _over_chrome(global_mouse: Vector2) -> bool:
	# Ignore absurd chrome rects (headless / layout-before-size can make
	# CENTER_BOTTOM HUD cover most of a tiny viewport and freeze place/select).
	var vp := get_viewport()
	var vp_area := 1.0
	if vp != null:
		var s := vp.get_visible_rect().size
		vp_area = maxf(s.x * s.y, 1.0)
	var max_area := vp_area * 0.25
	for ctrl in [_place_snap_panel, transform_hud, _selection_strip]:
		if ctrl == null or not ctrl.visible:
			continue
		if ctrl.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		var r: Rect2 = ctrl.get_global_rect()
		if r.get_area() < 4.0 or r.get_area() > max_area:
			continue
		if r.has_point(global_mouse):
			return true
	return false


func _update_hover(screen_pos: Vector2) -> void:
	if view == null or _place_kind != "" or (_drag_mode != DragMode.NONE):
		return
	if OrbitCamera.pointer_over_scrollable_ui():
		view.clear_hover()
		_last_hover_key = ""
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		return
	var ray := _model_ray(screen_pos)
	var hit: Dictionary = view.pick_info(ray[0], ray[1])
	if hit.is_empty():
		view.clear_hover()
		if _last_hover_key != "":
			_last_hover_key = ""
			mouse_default_cursor_shape = Control.CURSOR_ARROW
		return
	var body := str(hit.get("body", ""))
	var face := str(hit.get("face", ""))
	var edge := str(hit.get("edge", ""))
	view.set_hover(body, face, edge)
	var key := "%s|%s|%s" % [body, face, edge]
	if key == _last_hover_key:
		return
	_last_hover_key = key
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if edge != "":
		status.emit("Edge — click to select · Ctrl/Shift+click adds")
	elif face != "":
		status.emit("Face — click selects body first, click again for face · then Pull arrow")
	else:
		status.emit("Body — click to select · drag empty space / Alt / two-finger to orbit")


func _sketch_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var ray := _model_ray(mb.position)
			var p2 = sketch_mode.ray_to_sketch(ray[0], ray[1])
			if p2 != null:
				# With the SELECT tool, grabbing geometry starts a drag-to-edit;
				# constraint glyphs and dimension labels win over grabbing, and
				# a plain click (no hit) falls through to selection.
				if sketch_mode.tool == SketchMode.Tool.SELECT \
						and sketch_mode.constraint_hit(p2) == "" \
						and sketch_mode.dimension_hit(p2) < 0 \
						and not sketch_mode.drag_hit(p2).is_empty():
					sketch_mode.begin_drag(p2)
					_sketch_dragging = true
				else:
					sketch_mode.click(p2)
			accept_event()
		elif not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _sketch_dragging:
			var ray_up := _model_ray(mb.position)
			var p2_up = sketch_mode.ray_to_sketch(ray_up[0], ray_up[1])
			# A press-release without movement is a click-select, not a drag.
			if not _sketch_drag_moved and p2_up != null:
				sketch_mode.end_drag()
				sketch_mode.click(p2_up)
			else:
				sketch_mode.end_drag()
			_sketch_dragging = false
			_sketch_drag_moved = false
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			sketch_mode.end_chain()
			accept_event()
	elif event is InputEventMouseMotion:
		var ray := _model_ray(event.position)
		var p2 = sketch_mode.ray_to_sketch(ray[0], ray[1])
		if p2 != null:
			if _sketch_dragging:
				_sketch_drag_moved = true
				sketch_mode.update_drag(p2)
			else:
				sketch_mode.hover(p2)
	elif event is InputEventKey and event.pressed and not event.ctrl_pressed:
		match (event as InputEventKey).keycode:
			KEY_S: sketch_mode.set_tool(SketchMode.Tool.SELECT)
			KEY_L: sketch_mode.set_tool(SketchMode.Tool.LINE)
			KEY_R: sketch_mode.set_tool(SketchMode.Tool.RECT)
			KEY_C: sketch_mode.set_tool(SketchMode.Tool.CIRCLE)
			KEY_T: sketch_mode.set_tool(SketchMode.Tool.TRIM)
			KEY_X: sketch_mode.toggle_construction_selected()
			KEY_DELETE, KEY_BACKSPACE:
				if not sketch_mode.delete_selected_constraint():
					status.emit("Click a constraint badge first, then Del removes it")
			KEY_ESCAPE: sketch_mode.cancel()
		accept_event()


func _on_press(pos: Vector2) -> void:
	_pressed = true
	_press_pos = pos
	_last_drag_pos = pos
	_press_travel = 0.0
	_drag_mode = DragMode.NONE
	_box_rect = Rect2()
	_pp_preview_dist = 0.0
	_pending_body_move = false
	_pending_instance_move = false
	_move_axis_lock = -1
	grab_focus()
	view.clear_hover()

	var ray := _model_ray(pos)
	var hit: Dictionary = view.pick_info(ray[0], ray[1])
	_press_empty = hit.is_empty()

	# Shift/Ctrl+click is additive selection only — never arms a move/push drag.
	# Ctrl+empty-drag becomes a rubber-band box select in _on_drag.
	if _additive_click:
		return

	# Component instances aren't in the kernel pick — prefer whichever is
	# closer along the ray so an instance in front of a body is grabbable.
	var ihit: Dictionary = view.pick_instance(ray[0], ray[1])
	if not ihit.is_empty() \
			and (hit.is_empty() or float(ihit["distance"]) < float(hit["distance"])):
		var iid: String = ihit["id"]
		if view.selected_instance != iid:
			view.select_instance(iid)
		_pending_instance_move = true
		_drag_instance_id = iid
		_instance_grab_point = ihit["point"]
		var inode := view.instance_node(iid)
		_instance_start_xform = inode.transform if inode != null else Transform3D.IDENTITY
		_press_empty = false
		return

	var hit_selected := (not hit.is_empty() and view.selected_body != ""
			and str(hit.get("body", "")) == view.selected_body)

	# Body mesh itself is the move grip. Defer MOVE until past CLICK_SLOP so a
	# tiny press still drill-selects (face/edge) instead of nudging. Face drag
	# starts push/pull immediately. Stretch / rotate grips when ray misses body.
	if hit_selected:
		_drag_start_mouse = pos
		_drag_start_point = hit["point"]
		_press_empty = false
		if view.selected_face != "" and hit["face"] == view.selected_face:
			_drag_mode = DragMode.PUSH_PULL
			_drag_normal = view.selected_face_normal()
			_drag_pp_applied = 0.0
		else:
			_pending_body_move = true
			_pending_move_point = hit["point"]
		return

	var rotate_handle := _pick_rotate_grip(pos)
	if not rotate_handle.is_empty():
		_begin_rotate(rotate_handle, pos)
		_press_empty = false
		return
	var pp_handle := _pick_push_pull_handle(pos)
	if not pp_handle.is_empty():
		_drag_mode = DragMode.PUSH_PULL
		_drag_normal = pp_handle["normal"]
		_drag_pp_applied = 0.0
		_drag_start_mouse = pos
		_drag_start_point = pp_handle["point"]
		_press_empty = false
		return
	var resize_handle := _pick_resize_handle(pos)
	if not resize_handle.is_empty():
		_begin_resize(resize_handle, pos)
		_press_empty = false
		return

	# Empty space: drag will orbit the camera (plain click clears selection).
	if _press_empty:
		return


func _begin_move_body(pos: Vector2, hit_point: Vector3) -> void:
	_drag_mode = DragMode.MOVE_BODY
	_drag_accum = Vector3.ZERO
	_move_delta_base = Vector3.ZERO
	var bb := view.selection_bbox()
	_move_start_center = bb["center"] if not bb.is_empty() else hit_point
	var node := view.body_node(view.selected_body)
	_move_start_node_xform = node.transform if node != null else Transform3D.IDENTITY
	if transform_hud != null:
		transform_hud.hide_precision()
		transform_hud.set_move_delta(Vector3.ZERO)


func _begin_rotate(handle: Dictionary, pos: Vector2) -> void:
	_drag_mode = DragMode.ROTATE_BODY
	_rotate_axis = handle["axis"]
	_rotate_center = handle["center"]
	_rotate_angle = 0.0
	_rotate_start_angle = _angle_about_axis(pos, _rotate_axis, _rotate_center)
	var node := view.body_node(view.selected_body)
	_rotate_start_node_xform = node.transform if node != null else Transform3D.IDENTITY
	_drag_start_mouse = pos
	if transform_hud != null:
		transform_hud.hide_move_delta()
		transform_hud.hide_precision()


func _begin_resize(handle: Dictionary, pos: Vector2) -> void:
	_drag_mode = DragMode.RESIZE_BODY
	_drag_start_mouse = pos
	_drag_start_point = handle["point"]
	_resize_signs = handle["signs"]
	_resize_start_min = handle["min"]
	_resize_start_max = handle["max"]
	_resize_min = _resize_start_min
	_resize_max = _resize_start_max
	_resize_distance = 0.0
	_resize_axis_hint = str(handle.get("hint", "Δ"))
	if transform_hud != null:
		transform_hud.hide_move_delta()
		transform_hud.hide_precision()


func _on_drag(pos: Vector2) -> void:
	_press_travel = maxf(_press_travel, pos.distance_to(_press_pos))
	if pos.distance_to(_press_pos) < CLICK_SLOP:
		return
	# Deferred body move after travel threshold.
	if _pending_body_move and _drag_mode == DragMode.NONE:
		_pending_body_move = false
		_begin_move_body(_press_pos, _pending_move_point)
	if _pending_instance_move and _drag_mode == DragMode.NONE:
		_pending_instance_move = false
		_drag_mode = DragMode.MOVE_INSTANCE
	# Empty-space drag: orbit. Ctrl+empty-drag: rubber-band box select.
	if _drag_mode == DragMode.NONE and _press_empty and _place_kind == "":
		_drag_mode = DragMode.BOX_SELECT if _box_drag else DragMode.ORBIT_VIEW
		# Orbit from the press origin so the first post-slop frame applies real delta.
		_last_drag_pos = _press_pos
	match _drag_mode:
		DragMode.ORBIT_VIEW:
			var rel := pos - _last_drag_pos
			_last_drag_pos = pos
			if camera != null and rel.length_squared() > 0.0:
				if Input.is_key_pressed(KEY_SHIFT):
					camera._pan_by(rel.x, rel.y)
				else:
					camera._orbit_by(rel.x, rel.y)
			status.emit("Orbit (empty drag) — two-finger drag or Alt-drag also orbit")
		DragMode.BOX_SELECT:
			_box_rect = Rect2(_press_pos, pos - _press_pos).abs()
			queue_redraw()
		DragMode.MOVE_BODY:
			# Drag stays on the horizontal plane; ΔZ only via typed HUD.
			_last_drag_pos = pos
			var plane_z := _drag_start_point.z
			var gp = _horizontal_plane_point(pos, plane_z)
			var gp0 = _horizontal_plane_point(_drag_start_mouse, plane_z)
			if gp == null or gp0 == null:
				return
			var target: Vector3 = gp - gp0
			match _move_axis_lock:
				AXIS_X: target.y = 0.0
				AXIS_Y: target.x = 0.0
			target.z = _drag_accum.z  # preserve typed off-plane hop
			_apply_live_move(target)
			var lock_hint := ""
			match _move_axis_lock:
				AXIS_X: lock_hint = " [X locked]"
				AXIS_Y: lock_hint = " [Y locked]"
			status.emit("Move Δ (%.2f, %.2f, %.2f)%s — tap X/Y to lock axis, type ΔZ to leave plane" \
					% [target.x, target.y, target.z, lock_hint])
			queue_redraw()
		DragMode.ROTATE_BODY:
			var ang := _angle_about_axis(pos, _rotate_axis, _rotate_center)
			_rotate_angle = wrapf(ang - _rotate_start_angle, -PI, PI)
			_apply_live_rotate(_rotate_angle)
			status.emit("Rotate %s: %.1f°" % [_axis_label(_rotate_axis),
					rad_to_deg(_rotate_angle)])
			queue_redraw()
		DragMode.PUSH_PULL:
			var d := _push_pull_distance(pos)
			_pp_preview_dist = d
			var tip := _drag_start_point + _drag_normal * d
			_pp_badge_screen = _model_to_screen(tip)
			status.emit("Push/pull: %.1f mm (release to apply)" % d)
			queue_redraw()
		DragMode.RESIZE_BODY:
			_update_resize_drag(pos)
			queue_redraw()
		DragMode.MOVE_INSTANCE:
			# Live preview on the grabbed instance's horizontal plane.
			var plane_z := _instance_grab_point.z
			var gp = _horizontal_plane_point(pos, plane_z)
			var gp0 = _horizontal_plane_point(_press_pos, plane_z)
			if gp == null or gp0 == null:
				return
			var delta: Vector3 = gp - gp0
			var inode := view.instance_node(_drag_instance_id)
			if inode != null:
				inode.transform = Transform3D(_instance_start_xform.basis,
						_instance_start_xform.origin + delta)
			status.emit("Move instance Δ (%.1f, %.1f) — release re-solves mates"
					% [delta.x, delta.y])


func _draw() -> void:
	if _drag_mode == DragMode.BOX_SELECT and _box_rect.size != Vector2.ZERO:
		draw_rect(_box_rect, Color(0.35, 0.6, 0.95, 0.18), true)
		draw_rect(_box_rect, Color(0.35, 0.6, 0.95, 0.85), false, 1.0)
	_draw_selection_gizmos()
	if _drag_mode == DragMode.PUSH_PULL and absf(_pp_preview_dist) > 1e-3:
		_draw_push_pull_preview()


func _clear_box_band() -> void:
	_box_rect = Rect2()
	if _drag_mode == DragMode.BOX_SELECT:
		_drag_mode = DragMode.NONE
	queue_redraw()


## Stored rotation of an instance as [axis: Vector3, angle_deg: float].
func _instance_rotation(instance_id: String) -> Array:
	for inst in view.doc.instance_list():
		if str(inst["id"]) == instance_id:
			return [inst["rotation_axis"], inst["rotation_angle_deg"]]
	return [Vector3(0, 0, 1), 0.0]


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
	_press_travel = maxf(_press_travel, pos.distance_to(_press_pos))
	# Trackpads often jitter past a few pixels during a "click". Treat small travel
	# as a click for select / deselect; real empty-orbit needs more motion.
	var was_click := _press_travel < CLICK_SLOP
	match _drag_mode:
		DragMode.ORBIT_VIEW:
			_drag_mode = DragMode.NONE
			var keep_additive := _additive_click
			_box_drag = false
			_additive_click = false
			_press_empty = false
			# Empty-space travel below ORBIT_CLICK_SLOP is still a deselect
			# click (trackpad jitter); a real tumble keeps selection like peers.
			if _press_travel < ORBIT_CLICK_SLOP and not keep_additive:
				view.clear_selection()
				status.emit("")
			_press_travel = 0.0
			return
		DragMode.BOX_SELECT:
			_box_rect = Rect2(_press_pos, pos - _press_pos).abs()
			view.select_in_rect(_box_rect, camera, model_space, _additive_click)
			if view.selection_size() > 1:
				status.emit("%d selected" % view.selection_size())
			elif view.selection_size() == 1:
				status.emit("Selected " + view.selected_body.left(8))
			else:
				status.emit("")
			_clear_box_band()
			_box_drag = false
			_additive_click = false
			_press_travel = 0.0
			return
		DragMode.MOVE_BODY:
			if not was_click and _drag_accum.length() > 1e-6:
				# Reset live preview, then commit absolute Δ from pre-drag pose.
				var node := view.body_node(view.selected_body)
				if node != null:
					node.transform = _move_start_node_xform
				if view.move_selected(_drag_accum):
					_move_delta_base = _drag_accum
					status.emit("Moved body")
					if transform_hud != null:
						transform_hud.show_move_delta(_drag_accum)
				else:
					status.emit("Move failed")
			elif view.selected_body != "":
				view.refresh()
				if transform_hud != null:
					transform_hud.hide_move_delta()
			_drag_mode = DragMode.NONE
			_box_drag = false
			_additive_click = false
			_refresh_transform_hud()
			queue_redraw()
			_press_travel = 0.0
			return
		DragMode.ROTATE_BODY:
			if not was_click and absf(_rotate_angle) > 1e-4:
				var node_r := view.body_node(view.selected_body)
				if node_r != null:
					node_r.transform = _rotate_start_node_xform
				if view.rotate_selected(_rotate_center, _rotate_axis, _rotate_angle):
					status.emit("Rotated %.1f° about %s" % [
							rad_to_deg(_rotate_angle), _axis_label(_rotate_axis)])
					_precision_kind = "rotate"
					_precision_rotate_axis = _rotate_axis
					_precision_rotate_center = _rotate_center
					_show_precision_after_drag(rad_to_deg(_rotate_angle),
							"Δ° %s" % _axis_label(_rotate_axis), "°")
				else:
					status.emit("Rotate failed")
			elif view.selected_body != "":
				view.refresh()
			_drag_mode = DragMode.NONE
			_box_drag = false
			_additive_click = false
			_refresh_transform_hud()
			queue_redraw()
			_press_travel = 0.0
			return
		DragMode.PUSH_PULL:
			if not was_click:
				var dist := _push_pull_distance(pos)
				if absf(dist) > 1e-3:
					if view.push_pull_selected(dist):
						status.emit("Push/pull %.1f mm applied" % dist)
						_show_precision_after_drag(dist, "Δ push")
					else:
						status.emit("Push/pull failed (planar faces only for now)")
			_pp_preview_dist = 0.0
			_drag_mode = DragMode.NONE
			_box_drag = false
			_additive_click = false
			_refresh_transform_hud()
			queue_redraw()
			_press_travel = 0.0
			return
		DragMode.RESIZE_BODY:
			if not was_click and absf(_resize_distance) > 1e-3:
				_commit_resize()
			_drag_mode = DragMode.NONE
			_box_drag = false
			_additive_click = false
			queue_redraw()
			_press_travel = 0.0
			return
		DragMode.MOVE_INSTANCE:
			var inode := view.instance_node(_drag_instance_id)
			if not was_click and inode != null:
				var rot := _instance_rotation(_drag_instance_id)
				if view.doc.set_instance_transform(_drag_instance_id,
						inode.transform.origin, rot[0], rot[1]):
					# Peer feel: drop the instance, then mates pull it home.
					var had_mates: bool = view.doc.mate_list().size() > 0
					var solved: bool = view.doc.solve_mates() if had_mates else true
					view.refresh()
					if had_mates:
						status.emit("Instance moved — mates re-solved" if solved
								else "Instance moved — mate solve FAILED")
					else:
						status.emit("Instance moved")
				else:
					inode.transform = _instance_start_xform
					status.emit("Move instance failed")
			_drag_mode = DragMode.NONE
			_drag_instance_id = ""
			_box_drag = false
			_additive_click = false
			_press_travel = 0.0
			return
	# Press landed on an instance but never travelled: keep it selected.
	if _pending_instance_move:
		_pending_instance_move = false
		_drag_mode = DragMode.NONE
		_box_drag = false
		_additive_click = false
		_press_empty = false
		_press_travel = 0.0
		status.emit("Instance selected — drag to move (mates re-solve on release)")
		return
	# No drag gesture was armed (or pending move never started): resolve selection.
	_pending_body_move = false
	_drag_mode = DragMode.NONE
	if _press_empty and not _additive_click:
		view.clear_selection()
		status.emit("")
	else:
		# Prefer the press ray so a tiny slide off the body still selects it.
		var ray := _model_ray(_press_pos)
		if view.select_ray(ray[0], ray[1], _additive_click):
			if view.selection_size() > 1:
				status.emit("%d selected" % view.selection_size())
			else:
				status.emit("Selected " + (view.selected_face if view.selected_face != "" else view.selected_body).left(8))
		elif not _additive_click:
			status.emit("")
	_box_drag = false
	_additive_click = false
	_press_empty = false
	_press_travel = 0.0


func _gui_key(event: InputEventKey) -> bool:
	if not event.pressed:
		return false
	match event.keycode:
		KEY_ESCAPE:
			# Sketch Esc is handled in _sketch_input; do not steal it.
			if sketch_mode != null and sketch_mode.active:
				return false
			if _drag_mode == DragMode.BOX_SELECT or (_pressed and _press_empty and _box_rect.size != Vector2.ZERO):
				_pressed = false
				_clear_box_band()
				_box_drag = false
				_additive_click = false
				_press_empty = false
				status.emit("")
				return true
			if _place_kind != "":
				_disarm_place(true)
				return true
			view.clear_selection()
			status.emit("")
			return true
		KEY_DELETE, KEY_BACKSPACE:
			if view.selected_instance != "":
				if view.doc.remove_instance(view.selected_instance):
					view.refresh()
					status.emit("Instance removed")
				return true
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
		KEY_H:
			if not event.ctrl_pressed:
				if event.shift_pressed:
					view.unhide_all()
					status.emit("All shown")
				else:
					var ids := _selected_body_ids()
					for id in ids:
						view.set_body_hidden(id, true)
					status.emit("%d hidden" % ids.size())
				return true
		KEY_I:
			if not event.ctrl_pressed:
				var ids := _selected_body_ids()
				view.isolate(ids)
				status.emit("All shown" if ids.is_empty() else "Isolated")
				return true
		KEY_SPACE:
			# SolidWorks Spacebar / Onshape S-lite: orientation + named views.
			if not event.ctrl_pressed and _place_kind == "" \
					and (sketch_mode == null or not sketch_mode.active):
				_show_orient_popup()
				return true
	return false


## Unique body ids from the current selection (bodies / face+edge owners).
func _selected_body_ids() -> Array:
	var ids: Array = []
	for b in view.selected_bodies:
		if not ids.has(b):
			ids.append(b)
	if view.selected_body != "" and not ids.has(view.selected_body):
		ids.append(view.selected_body)
	return ids


func _on_view_selection_changed(_body: String, _face: String) -> void:
	_refresh_transform_hud()
	_refresh_selection_strip()
	queue_redraw()


func _on_view_document_changed() -> void:
	_refresh_transform_hud()
	_refresh_selection_strip()
	queue_redraw()


func _apply_live_move(delta: Vector3) -> void:
	_drag_accum = delta
	var node := view.body_node(view.selected_body)
	if node != null:
		node.transform = _move_start_node_xform.translated(delta)
	if transform_hud != null:
		var bb := view.selection_bbox()
		var size: Vector3 = bb["size"] if not bb.is_empty() else Vector3(50, 50, 50)
		transform_hud.set_values(_move_start_center + delta, size,
				view.is_primitive_body(view.selected_body))
		transform_hud.set_move_delta(delta)


func _apply_live_rotate(angle: float) -> void:
	var node := view.body_node(view.selected_body)
	if node == null:
		return
	var R := Basis(_rotate_axis.normalized(), angle)
	var c := _rotate_center
	var origin0: Vector3 = _rotate_start_node_xform.origin
	var basis0: Basis = _rotate_start_node_xform.basis
	node.transform = Transform3D(R * basis0, c + R * (origin0 - c))


func _refresh_transform_hud() -> void:
	if transform_hud == null:
		return
	if _place_kind != "":
		var center := _screen_center()
		var target := _place_target(center)
		transform_hud.visible = true
		transform_hud.mouse_filter = Control.MOUSE_FILTER_STOP
		transform_hud.set_values(target["point"], place_size, true)
		return
	if view.selected_body == "" or view.selection_size() != 1:
		transform_hud.visible = false
		transform_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		transform_hud.hide_precision()
		transform_hud.hide_move_delta()
		return
	var bb := view.selection_bbox()
	if bb.is_empty():
		transform_hud.visible = false
		transform_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	transform_hud.visible = true
	transform_hud.mouse_filter = Control.MOUSE_FILTER_STOP
	transform_hud.set_values(bb["center"], bb["size"], view.is_primitive_body(view.selected_body))


func _on_hud_position(pos: Vector3) -> void:
	if _place_kind != "":
		# Jump the ghost floor to the typed position.
		if _place_ghost != null:
			_place_ghost.position = pos + _ghost_sit_offset(_place_kind)
		return
	if view.selected_body == "":
		return
	var bb := view.selection_bbox()
	if bb.is_empty():
		return
	var delta: Vector3 = pos - bb["center"]
	if delta.length() < 1e-6:
		return
	view.move_selected(delta)
	_refresh_transform_hud()


func _on_hud_size(size: Vector3) -> void:
	if _place_kind != "":
		# Keep the ghost's floor contact while rebuilding the mesh.
		var floor_z := 0.0
		var floor_xy := Vector2.ZERO
		if _place_ghost != null:
			floor_xy = Vector2(_place_ghost.position.x, _place_ghost.position.y)
			floor_z = _place_ghost.position.z - _ghost_sit_offset(_place_kind).z
		place_size = size
		if _place_ghost != null:
			_apply_ghost_mesh(_place_ghost, _place_kind, place_size)
			_place_ghost.position = Vector3(floor_xy.x, floor_xy.y, floor_z) \
					+ _ghost_sit_offset(_place_kind)
		return
	if view.selected_body == "" or not view.is_primitive_body(view.selected_body):
		return
	var bb := view.selection_bbox()
	if bb.is_empty():
		return
	var center: Vector3 = bb["center"]
	var half := size * 0.5
	if view.resize_primitive_aabb(view.selected_body, center - half, center + half):
		status.emit("Size → %.1f × %.1f × %.1f" % [size.x, size.y, size.z])
	_refresh_transform_hud()


func _on_hud_move_delta(delta: Vector3) -> void:
	if view.selected_body == "":
		return
	if _drag_mode == DragMode.MOVE_BODY:
		# Typed ΔZ hops off-plane while mouse still drives XY.
		_apply_live_move(delta)
		return
	# Post-drag refine: apply correction past the last committed Δ.
	var corr := delta - _move_delta_base
	if corr.length() < 1e-6:
		return
	if view.move_selected(corr):
		_move_delta_base = delta
		status.emit("Move Δ → (%.2f, %.2f, %.2f)" % [delta.x, delta.y, delta.z])
	_refresh_transform_hud()
	if transform_hud != null:
		transform_hud.set_move_delta(delta)


func _on_hud_precision(distance: float) -> void:
	if view.selected_body == "":
		return
	if _precision_kind == "rotate":
		var wanted := deg_to_rad(distance)
		var corr := wanted - deg_to_rad(_precision_base)
		if absf(corr) < 1e-6:
			return
		if view.rotate_selected(_precision_rotate_center, _precision_rotate_axis, corr):
			_precision_base = distance
			status.emit("Rotated to %.2f°" % distance)
		_refresh_transform_hud()
		return
	if not view.is_primitive_body(view.selected_body):
		return
	_apply_precision_resize(distance)


func _apply_precision_resize(distance: float) -> void:
	var mn := Vector3(_precision_min)
	var mx := Vector3(_precision_max)
	for axis in range(3):
		var s: float = _precision_signs[axis]
		if absf(s) < 0.5:
			continue
		if s > 0.0:
			mx[axis] = _precision_max[axis] + distance
		else:
			mn[axis] = _precision_min[axis] - distance
	for axis in range(3):
		if mx[axis] - mn[axis] < 0.1:
			status.emit("Size too small")
			return
	if view.resize_primitive_aabb(view.selected_body, mn, mx):
		_precision_base = distance
		status.emit("Resized to Δ %.2f mm" % distance)
	_refresh_transform_hud()


func _show_precision_after_drag(distance: float, hint: String, unit := "mm") -> void:
	_precision_base = distance
	if transform_hud == null:
		return
	transform_hud.show_precision(distance, hint, unit)


func _model_to_screen(model_pt: Vector3) -> Vector2:
	var world: Vector3 = model_space.to_global(model_pt)
	return camera.unproject_position(world)


## Pick an AABB resize handle near `screen_pos`.
## Pick/test points are pushed slightly outside the AABB so a face/corner
## grab can miss the mesh (body hits always move — see `_on_press`).
func _pick_resize_handle(screen_pos: Vector2) -> Dictionary:
	if view.selected_body == "" or not view.is_primitive_body(view.selected_body):
		return {}
	if view.selection_size() != 1:
		return {}
	var bb := view.selection_bbox()
	if bb.is_empty():
		return {}
	var mn: Vector3 = bb["min"]
	var mx: Vector3 = bb["max"]
	var center: Vector3 = bb["center"]
	var pad := maxf(maxf(bb["size"].x, bb["size"].y), bb["size"].z) * 0.06 + 2.0
	var best := {}
	var best_d := HANDLE_PX
	# Face centers (dimension-line style, single-axis).
	var face_handles := [
		{"point": Vector3(mx.x, (mn.y + mx.y) * 0.5, (mn.z + mx.z) * 0.5),
			"signs": Vector3(1, 0, 0), "hint": "ΔX"},
		{"point": Vector3(mn.x, (mn.y + mx.y) * 0.5, (mn.z + mx.z) * 0.5),
			"signs": Vector3(-1, 0, 0), "hint": "ΔX"},
		{"point": Vector3((mn.x + mx.x) * 0.5, mx.y, (mn.z + mx.z) * 0.5),
			"signs": Vector3(0, 1, 0), "hint": "ΔY"},
		{"point": Vector3((mn.x + mx.x) * 0.5, mn.y, (mn.z + mx.z) * 0.5),
			"signs": Vector3(0, -1, 0), "hint": "ΔY"},
		{"point": Vector3((mn.x + mx.x) * 0.5, (mn.y + mx.y) * 0.5, mx.z),
			"signs": Vector3(0, 0, 1), "hint": "ΔZ"},
		{"point": Vector3((mn.x + mx.x) * 0.5, (mn.y + mx.y) * 0.5, mn.z),
			"signs": Vector3(0, 0, -1), "hint": "ΔZ"},
	]
	for h in face_handles:
		var signs: Vector3 = h["signs"]
		var pick_pt: Vector3 = h["point"] + signs * pad
		var d: float = _model_to_screen(pick_pt).distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = h
	# Corners (multi-axis).
	var corners: Array[Vector3] = [
		Vector3(mn.x, mn.y, mn.z), Vector3(mx.x, mn.y, mn.z),
		Vector3(mx.x, mx.y, mn.z), Vector3(mn.x, mx.y, mn.z),
		Vector3(mn.x, mn.y, mx.z), Vector3(mx.x, mn.y, mx.z),
		Vector3(mx.x, mx.y, mx.z), Vector3(mn.x, mx.y, mx.z),
	]
	for c in corners:
		var signs2 := Vector3(
			1.0 if c.x > center.x else -1.0,
			1.0 if c.y > center.y else -1.0,
			1.0 if c.z > center.z else -1.0)
		var pick_c: Vector3 = c + signs2.normalized() * pad
		var d2: float = _model_to_screen(pick_c).distance_to(screen_pos)
		if d2 < best_d:
			best_d = d2
			best = {"point": c, "signs": signs2, "hint": "Δ"}
	if best.is_empty():
		return {}
	best["min"] = mn
	best["max"] = mx
	return best


func _update_resize_drag(screen_pos: Vector2) -> void:
	var ray := _model_ray(screen_pos)
	var o: Vector3 = ray[0]
	var d: Vector3 = ray[1]
	# For single-axis handles, project along that axis; for corners, use the
	# dominant screen-space axis of motion.
	var signs := _resize_signs
	var axis_count := int(absf(signs.x) > 0.5) + int(absf(signs.y) > 0.5) + int(absf(signs.z) > 0.5)
	var delta_vec := Vector3.ZERO
	if axis_count == 1:
		var axis := Vector3(signs.x, signs.y, signs.z).normalized()
		var cross_dn := d.cross(axis)
		var denom := cross_dn.length_squared()
		if denom < 1e-12:
			return
		var dist := (o - _drag_start_point).dot(cross_dn.cross(d)) / denom
		delta_vec = axis * dist
		_resize_distance = dist
	else:
		# Corner: intersect with plane through start point facing the camera.
		var world_fwd: Vector3 = -camera.global_transform.basis.z
		var inv: Transform3D = model_space.global_transform.affine_inverse()
		var cam_dir: Vector3 = (inv.basis * world_fwd).normalized()
		var denom2 := d.dot(cam_dir)
		if absf(denom2) < 1e-9:
			return
		var t := (_drag_start_point - o).dot(cam_dir) / denom2
		var hit_pt: Vector3 = o + d * t
		delta_vec = hit_pt - _drag_start_point
		# Only move along signed axes.
		delta_vec = Vector3(
			delta_vec.x if absf(signs.x) > 0.5 else 0.0,
			delta_vec.y if absf(signs.y) > 0.5 else 0.0,
			delta_vec.z if absf(signs.z) > 0.5 else 0.0)
		_resize_distance = delta_vec.length() * (1.0 if delta_vec.dot(signs) >= 0.0 else -1.0)
	_resize_min = _resize_start_min
	_resize_max = _resize_start_max
	for axis in range(3):
		var s: float = signs[axis]
		if absf(s) < 0.5:
			continue
		if s > 0.0:
			_resize_max[axis] = _resize_start_max[axis] + delta_vec[axis]
		else:
			_resize_min[axis] = _resize_start_min[axis] + delta_vec[axis]
	# Keep a minimum size.
	for axis in range(3):
		if _resize_max[axis] - _resize_min[axis] < 0.1:
			if signs[axis] > 0.0:
				_resize_max[axis] = _resize_min[axis] + 0.1
			elif signs[axis] < 0.0:
				_resize_min[axis] = _resize_max[axis] - 0.1
	if transform_hud != null:
		var size := _resize_max - _resize_min
		transform_hud.set_values((_resize_min + _resize_max) * 0.5, size, true)
	status.emit("Resize: %.1f mm" % _resize_distance)


func _commit_resize() -> void:
	var body := view.selected_body
	if body == "" or not view.is_primitive_body(body):
		status.emit("Resize needs a primitive body")
		return
	_precision_min = _resize_start_min
	_precision_max = _resize_start_max
	_precision_signs = _resize_signs
	_precision_kind = "resize"
	if view.resize_primitive_aabb(body, _resize_min, _resize_max):
		status.emit("Resized %.1f mm" % _resize_distance)
		_show_precision_after_drag(_resize_distance, _resize_axis_hint)
	else:
		status.emit("Resize failed")
	_refresh_transform_hud()


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
	# Camera first — before Control STOP panels so orbit works over docks, and
	# before place so Alt+drag / two-finger pan don't commit a solid.
	# Never steal wheel / two-finger pan from ScrollContainers; pinch always zooms.
	var allow_scroll := not OrbitCamera.pointer_over_scrollable_ui()
	# Magnify must never fall through place/sketch even if scroll gating diffs.
	if event is InputEventMagnifyGesture and camera != null:
		if camera.handle_input(event, true):
			get_viewport().set_input_as_handled()
			return
	if camera != null and camera.is_nav_event(event, allow_scroll):
		if camera.handle_input(event, allow_scroll):
			get_viewport().set_input_as_handled()
			return
	# Place mode uses viewport mouse coords so ghost/commit work even when the
	# cursor is "over" a sibling Control or Interaction fails hit-tests.
	if _place_kind != "" and sketch_mode != null and sketch_mode.active:
		_disarm_place(false)
	if _place_kind != "":
		# Don't steal clicks aimed at the snap / transform chrome.
		if event is InputEventMouseButton or event is InputEventMouseMotion:
			var mouse_pos := (event as InputEventMouse).position
			if _over_chrome(mouse_pos):
				return
		if event is InputEventMouseMotion:
			# event.position is viewport coords in _input (not Control-local).
			_update_ghost((event as InputEventMouseMotion).position)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if not mb.pressed:
				if _ignore_select_release and mb.button_index == MOUSE_BUTTON_LEFT:
					_ignore_select_release = false
				get_viewport().set_input_as_handled()
				return
			if mb.button_index == MOUSE_BUTTON_LEFT and not mb.alt_pressed:
				_commit_place(mb.position)
				get_viewport().set_input_as_handled()
				return
			if mb.button_index == MOUSE_BUTTON_RIGHT:
				_disarm_place(true)
				get_viewport().set_input_as_handled()
				return
		if event is InputEventKey and event.pressed and not event.echo:
			if (event as InputEventKey).keycode == KEY_ESCAPE:
				_disarm_place(true)
				get_viewport().set_input_as_handled()
				return
		return

	# Sketch: same `_input` ownership so it works if Interaction isn't hovered.
	if sketch_mode != null and sketch_mode.active:
		if event is InputEventMouse or (event is InputEventKey and event.pressed):
			_sketch_input(event)
			get_viewport().set_input_as_handled()
			return

	# Select / empty-orbit / handles — also via `_input` so they work when
	# Interaction has size 0 or is under another Control for hit-testing.
	# Keep capturing motion/release after a press even if the cursor drifts
	# over a dock edge.
	if _pressed or _viewport_owns_pointer():
		if _handle_model_pointer(event):
			get_viewport().set_input_as_handled()
			return

	# Tap X / Y mid body-move to lock the drag to that axis (tap again to free).
	# Handled here (not _gui_key) so it works regardless of Control focus.
	if event is InputEventKey and event.pressed and not event.echo \
			and _drag_mode == DragMode.MOVE_BODY:
		var kc := (event as InputEventKey).keycode
		if kc == KEY_X or kc == KEY_Y:
			var axis := AXIS_X if kc == KEY_X else AXIS_Y
			_move_axis_lock = -1 if _move_axis_lock == axis else axis
			_on_drag(_last_drag_pos)  # re-apply preview under the new lock
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey and has_focus():
		if _gui_key(event):
			get_viewport().set_input_as_handled()


# --- selection chrome (strip + RMB) ---

func _refresh_selection_strip() -> void:
	if _selection_strip == null:
		return
	var has_instance := view != null and view.selected_instance != ""
	var has := (view != null and view.selected_body != "") or has_instance
	# Sketch mode is modal: its toolbar takes the top-center slot, and the
	# strip's body verbs don't apply while sketching.
	var sketching := sketch_mode != null and sketch_mode.active
	_selection_strip.visible = has and _place_kind == "" and not sketching
	_selection_strip.mouse_filter = Control.MOUSE_FILTER_STOP if _selection_strip.visible \
			else Control.MOUSE_FILTER_IGNORE
	if not has:
		return
	# Instances get a slim strip: Delete only (modeling ops act on bodies).
	_strip_fillet.visible = not has_instance
	_strip_sketch.visible = not has_instance and view.selected_face != ""
	_strip_look.visible = not has_instance and view.selected_face != ""
	_strip_hide.visible = not has_instance
	_strip_delete.visible = true


func _open_context_menu(screen_pos: Vector2) -> void:
	if _context_menu == null:
		return
	_context_menu.clear()
	var has := view != null and view.selected_body != ""
	if has:
		_context_menu.add_item("Fillet", 1)
		if view.selected_face != "":
			_context_menu.add_item("Sketch on face…", 2)
			_context_menu.add_item("Look at face", 6)
			_context_menu.add_item("Push/Pull (drag orange arrow)", 7)
		_context_menu.add_item("Hide", 3)
		_context_menu.add_item("Isolate", 4)
		_context_menu.add_item("Delete", 5)
		_context_menu.add_item("Fit selection", 12)
	else:
		_context_menu.add_item("Fit all", 10)
		_context_menu.add_item("Unhide all", 11)
		_context_menu.add_item("Orientation… (Space)", 13)
	var global_pos := get_global_transform_with_canvas() * screen_pos
	_context_menu.position = Vector2i(global_pos)
	_context_menu.popup()


func _on_context_id(id: int) -> void:
	match id:
		1: _ctx_fillet()
		2: sketch_requested.emit()
		3: _ctx_hide()
		4: _ctx_isolate()
		5: _ctx_delete()
		6: _ctx_look_at()
		7:
			status.emit("Drag the orange Pull arrow on the face to push/pull")
		10:
			if camera != null:
				camera.frame_contents()
		11:
			view.unhide_all()
			status.emit("All shown")
		12:
			if camera != null:
				camera.frame_selection_or_all(false)
		13:
			_show_orient_popup()


func _ctx_fillet() -> void:
	if ops_panel != null:
		ops_panel._fillet_all()
	else:
		status.emit("Fillet: open Modify panel")


func _ctx_hide() -> void:
	var ids := _selected_body_ids()
	for id in ids:
		view.set_body_hidden(id, true)
	status.emit("%d hidden" % ids.size())


func _ctx_isolate() -> void:
	view.isolate(_selected_body_ids())
	status.emit("Isolated")


func _ctx_delete() -> void:
	if view.selected_instance != "":
		if view.doc.remove_instance(view.selected_instance):
			view.refresh()
			status.emit("Instance removed")
		return
	if view.delete_selected():
		status.emit("Deleted body")


func _ctx_look_at() -> void:
	if camera == null or view == null or view.selected_face == "":
		status.emit("Select a face first")
		return
	var n := view.selected_face_normal()
	camera.look_along_model_normal(n)
	status.emit("Look at face")


func _show_orient_popup() -> void:
	if _orient_popup == null:
		return
	var center := get_viewport().get_visible_rect().get_center()
	_orient_popup.popup(Rect2i(Vector2i(center) - Vector2i(80, 120), Vector2i(160, 260)))


func _on_orient_id(id: int) -> void:
	if camera == null:
		return
	match id:
		1:
			camera.set_view(deg_to_rad(0.0), deg_to_rad(0.0), true)
		2:
			camera.set_view(deg_to_rad(90.0), deg_to_rad(0.0), true)
		3:
			camera.set_view(deg_to_rad(0.0), deg_to_rad(89.0), true)
		7:
			camera.set_view(deg_to_rad(-35.0), deg_to_rad(30.0), true)
		5:
			camera.toggle_projection()
			status.emit("Projection toggled")
		20:
			camera.frame_selection_or_all(false)
			status.emit("Fit selection")
		21:
			camera.frame_contents()
			status.emit("Fit all")
		30:
			if camera.restore_named_view("User"):
				status.emit("Restored view “User”")
			else:
				status.emit("No saved view “User” — use ViewHud Save view first")


# --- on-canvas gizmos ---

func _axis_label(axis: Vector3) -> String:
	if absf(axis.x) > 0.5:
		return "X"
	if absf(axis.y) > 0.5:
		return "Y"
	return "Z"


func _selection_center() -> Vector3:
	var bb := view.selection_bbox()
	if bb.is_empty():
		return Vector3.ZERO
	return bb["center"]


func _axis_len() -> float:
	var bb := view.selection_bbox()
	if bb.is_empty():
		return 40.0
	var s: Vector3 = bb["size"]
	return maxf(maxf(s.x, s.y), s.z) * AXIS_LEN_FRAC + 12.0


## Rotation grips: three arcs about principal axes through the selection center.
func _rotate_grips() -> Array:
	if view == null or view.selected_body == "" or view.selected_face != "":
		return []
	if view.selection_size() != 1:
		return []
	var c := _selection_center()
	var r := _axis_len() * 1.15
	return [
		{"axis": Vector3.RIGHT, "center": c, "radius": r, "color": Color(0.9, 0.25, 0.2)},
		{"axis": Vector3.UP, "center": c, "radius": r, "color": Color(0.25, 0.85, 0.3)},
		{"axis": Vector3(0, 0, 1), "center": c, "radius": r, "color": Color(0.3, 0.55, 1.0)},
	]


func _circle_frame(axis: Vector3) -> Array:
	# Orthonormal u,v spanning the plane perpendicular to axis.
	var a := axis.normalized()
	var u := a.cross(Vector3.UP)
	if u.length_squared() < 1e-8:
		u = a.cross(Vector3.RIGHT)
	u = u.normalized()
	var v := a.cross(u).normalized()
	return [u, v]


func _angle_about_axis(screen_pos: Vector2, axis: Vector3, center: Vector3) -> float:
	var hit = _plane_point_along_axis(screen_pos, axis, center)
	if hit == null:
		return 0.0
	var frame: Array = _circle_frame(axis)
	var d: Vector3 = hit - center
	return atan2(d.dot(frame[1]), d.dot(frame[0]))


func _plane_point_along_axis(screen_pos: Vector2, axis: Vector3, center: Vector3) -> Variant:
	var ray := _model_ray(screen_pos)
	var o: Vector3 = ray[0]
	var d: Vector3 = ray[1]
	var n := axis.normalized()
	var denom := d.dot(n)
	if absf(denom) < 1e-9:
		return null
	var t := (center - o).dot(n) / denom
	if t < 0.0:
		return null
	return o + d * t


## Screen-space pick targets: the four angle ticks on each rotate ring
## (not the whole arc — full-circle sampling stole empty-space clicks).
func _rotate_tick_points(g: Dictionary) -> Array:
	var frame: Array = _circle_frame(g["axis"])
	var u: Vector3 = frame[0]
	var v: Vector3 = frame[1]
	var c: Vector3 = g["center"]
	var r: float = g["radius"]
	var pts: Array = []
	for i in range(4):
		var ang := TAU * 0.25 * float(i)
		pts.append(c + (u * cos(ang) + v * sin(ang)) * r)
	return pts


func _pick_rotate_grip(screen_pos: Vector2) -> Dictionary:
	var best := {}
	var best_d := AXIS_HANDLE_PX
	for g in _rotate_grips():
		for pt in _rotate_tick_points(g):
			var d: float = _model_to_screen(pt).distance_to(screen_pos)
			if d < best_d:
				best_d = d
				best = g
	return best


func _face_pull_anchor() -> Dictionary:
	if view == null or view.selected_face == "" or view.selected_body == "":
		return {}
	var n := view.selected_face_normal()
	if n.length_squared() < 1e-8:
		return {}
	n = n.normalized()
	var bb := view.selection_bbox()
	if bb.is_empty():
		return {}
	var c: Vector3 = bb["center"]
	var half: Vector3 = bb["size"] * 0.5
	var anchor := c + Vector3(
		n.x * half.x if absf(n.x) > 0.5 else 0.0,
		n.y * half.y if absf(n.y) > 0.5 else 0.0,
		n.z * half.z if absf(n.z) > 0.5 else 0.0)
	var tip := anchor + n * maxf(_axis_len() * 0.8, 20.0)
	return {"point": tip, "anchor": anchor, "normal": n}


func _pick_push_pull_handle(screen_pos: Vector2) -> Dictionary:
	var h := _face_pull_anchor()
	if h.is_empty():
		return {}
	if _model_to_screen(h["point"]).distance_to(screen_pos) > AXIS_HANDLE_PX:
		return {}
	return h


func _draw_selection_gizmos() -> void:
	if view == null or view.selected_body == "" or _place_kind != "":
		return
	if camera == null or model_space == null:
		return
	# Stretch grips (face centers + corners) for primitives.
	if view.is_primitive_body(view.selected_body) and view.selection_size() == 1:
		var bb := view.selection_bbox()
		if not bb.is_empty():
			var mn: Vector3 = bb["min"]
			var mx: Vector3 = bb["max"]
			var faces: Array[Vector3] = [
				Vector3(mx.x, (mn.y + mx.y) * 0.5, (mn.z + mx.z) * 0.5),
				Vector3(mn.x, (mn.y + mx.y) * 0.5, (mn.z + mx.z) * 0.5),
				Vector3((mn.x + mx.x) * 0.5, mx.y, (mn.z + mx.z) * 0.5),
				Vector3((mn.x + mx.x) * 0.5, mn.y, (mn.z + mx.z) * 0.5),
				Vector3((mn.x + mx.x) * 0.5, (mn.y + mx.y) * 0.5, mx.z),
				Vector3((mn.x + mx.x) * 0.5, (mn.y + mx.y) * 0.5, mn.z),
			]
			for p in faces:
				var sp := _model_to_screen(p)
				draw_rect(Rect2(sp - Vector2(5, 5), Vector2(10, 10)), Color(0.2, 0.65, 1.0, 0.95), true)
				draw_rect(Rect2(sp - Vector2(5, 5), Vector2(10, 10)), Color(1, 1, 1, 0.9), false, 1.0)
			var corners: Array[Vector3] = [
				Vector3(mn.x, mn.y, mn.z), Vector3(mx.x, mn.y, mn.z),
				Vector3(mx.x, mx.y, mn.z), Vector3(mn.x, mx.y, mn.z),
				Vector3(mn.x, mn.y, mx.z), Vector3(mx.x, mn.y, mx.z),
				Vector3(mx.x, mx.y, mx.z), Vector3(mn.x, mx.y, mx.z),
			]
			for cpt in corners:
				var cp := _model_to_screen(cpt)
				var diamond := PackedVector2Array([
					cp + Vector2(0, -6), cp + Vector2(6, 0),
					cp + Vector2(0, 6), cp + Vector2(-6, 0),
				])
				draw_colored_polygon(diamond, Color(0.15, 0.75, 1.0, 0.95))
				draw_polyline(diamond + PackedVector2Array([diamond[0]]), Color(1, 1, 1, 0.85), 1.0)
	# Rotate arcs (no move triad — body itself is the move grip).
	for g in _rotate_grips():
		_draw_rotate_arc(g)
	# During move: old center, new center, connecting segment.
	if _drag_mode == DragMode.MOVE_BODY and _drag_accum.length() > 1e-4:
		var old_s := _model_to_screen(_move_start_center)
		var new_s := _model_to_screen(_move_start_center + _drag_accum)
		draw_line(old_s, new_s, Color(1.0, 0.85, 0.2, 0.9), 1.5)
		_draw_center_mark(old_s, Color(0.85, 0.85, 0.9, 0.95))
		_draw_center_mark(new_s, Color(1.0, 0.75, 0.15, 0.95))
		draw_string(ThemeDB.fallback_font, old_s + Vector2(8, -8), "old",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.85, 0.9))
		draw_string(ThemeDB.fallback_font, new_s + Vector2(8, -8), "new",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.75, 0.15))
	# Face push/pull arrow.
	var pull := _face_pull_anchor()
	if not pull.is_empty():
		var a: Vector2 = _model_to_screen(pull["anchor"])
		var t: Vector2 = _model_to_screen(pull["point"])
		var col2 := Color(1.0, 0.62, 0.15, 0.95)
		draw_line(a, t, col2, 3.0)
		draw_circle(t, 6.0, col2)
		draw_string(ThemeDB.fallback_font, t + Vector2(8, -8), "Pull", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col2)


func _draw_center_mark(screen: Vector2, color: Color) -> void:
	draw_circle(screen, 4.0, color)
	draw_line(screen + Vector2(-8, 0), screen + Vector2(8, 0), color, 1.5)
	draw_line(screen + Vector2(0, -8), screen + Vector2(0, 8), color, 1.5)


func _draw_rotate_arc(g: Dictionary) -> void:
	var frame: Array = _circle_frame(g["axis"])
	var u: Vector3 = frame[0]
	var v: Vector3 = frame[1]
	var c: Vector3 = g["center"]
	var r: float = g["radius"]
	var col: Color = g["color"]
	const SEGS := 48
	var prev := Vector2.ZERO
	for i in range(SEGS + 1):
		var ang := TAU * float(i) / float(SEGS)
		var pt: Vector3 = c + (u * cos(ang) + v * sin(ang)) * r
		var sp := _model_to_screen(pt)
		if i > 0:
			draw_line(prev, sp, col, 2.0)
		prev = sp
	# Grip ticks at 90° intervals.
	for i in range(4):
		var ang2 := TAU * 0.25 * float(i)
		var tick: Vector3 = c + (u * cos(ang2) + v * sin(ang2)) * r
		var ts := _model_to_screen(tick)
		draw_circle(ts, 4.0, col)
		draw_circle(ts, 4.0, Color(1, 1, 1, 0.65))


func _draw_push_pull_preview() -> void:
	var tip := _drag_start_point + _drag_normal * _pp_preview_dist
	var a := _model_to_screen(_drag_start_point)
	var t := _model_to_screen(tip)
	draw_line(a, t, Color(1.0, 0.72, 0.2, 0.95), 2.5)
	draw_circle(t, 5.0, Color(1.0, 0.72, 0.2))
	var label := "%.1f mm" % _pp_preview_dist
	var pos := _pp_badge_screen + Vector2(10, -18)
	draw_rect(Rect2(pos - Vector2(4, 2), Vector2(70, 18)), Color(0.12, 0.14, 0.18, 0.85), true)
	draw_string(ThemeDB.fallback_font, pos + Vector2(2, 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.9, 0.6))
