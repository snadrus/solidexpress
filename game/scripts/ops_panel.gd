class_name OpsPanel
extends PanelContainer
## Context operations for the current selection. Body selected: fillet/chamfer
## (all edges), mirror, linear/circular pattern, offset, boolean (arm, then
## click the tool body), measure (arm, then click the other entity). Face
## selected: shell (removes that face) plus face measurements.

signal status(text: String)

enum Pending { NONE, BOOLEAN, MEASURE }

var view: DocumentView

var _body_ops: VBoxContainer
var _face_ops: VBoxContainer
var _name_edit: LineEdit
var _color_picker: ColorPickerButton
var _radius_spin: SpinBox
var _pattern_count: SpinBox
var _pattern_spacing: SpinBox
var _offset_spin: SpinBox
var _thickness_spin: SpinBox
var _draft_angle_spin: SpinBox
var _hole_type: OptionButton
var _hole_diameter: SpinBox
var _hole_depth: SpinBox
var _boolean_op := "fuse"
var _pending: Pending = Pending.NONE
var _pending_first := ""  # armed source entity (body for boolean, any for measure)


func _ready() -> void:
	custom_minimum_size = Vector2(230, 0)
	var vbox := VBoxContainer.new()
	add_child(vbox)
	var title := Label.new()
	title.text = "Modify"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_body_ops = VBoxContainer.new()
	vbox.add_child(_body_ops)
	_build_body_ops()

	_face_ops = VBoxContainer.new()
	vbox.add_child(_face_ops)
	_build_face_ops()

	view.selection_changed.connect(_on_selection_changed)
	_on_selection_changed(view.selected_body, view.selected_face)


func _labeled_spin(parent: Container, text: String, min_v: float, max_v: float,
		step: float, value: float) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(80, 0)
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spin)
	return spin


func _op_button(parent: Container, text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(handler)
	parent.add_child(b)
	return b


func _build_body_ops() -> void:
	var name_row := HBoxContainer.new()
	_body_ops.add_child(name_row)
	var name_lbl := Label.new()
	name_lbl.text = "Name"
	name_lbl.custom_minimum_size = Vector2(80, 0)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_row.add_child(name_lbl)
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_submitted.connect(_on_name_submitted)
	name_row.add_child(_name_edit)

	var color_row := HBoxContainer.new()
	_body_ops.add_child(color_row)
	var color_lbl := Label.new()
	color_lbl.text = "Color"
	color_lbl.custom_minimum_size = Vector2(80, 0)
	color_lbl.add_theme_font_size_override("font_size", 11)
	color_row.add_child(color_lbl)
	_color_picker = ColorPickerButton.new()
	_color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_color_picker.edit_alpha = false
	_color_picker.color_changed.connect(_on_color_changed)
	color_row.add_child(_color_picker)

	_body_ops.add_child(HSeparator.new())
	_radius_spin = _labeled_spin(_body_ops, "Radius", 0.1, 100.0, 0.5, 2.0)
	var round_row := HBoxContainer.new()
	_body_ops.add_child(round_row)
	_op_button(round_row, "Fillet", _fillet_all)
	_op_button(round_row, "Chamfer", _chamfer_all)

	_body_ops.add_child(HSeparator.new())
	_pattern_spacing = _labeled_spin(_body_ops, "Spacing", 1.0, 1000.0, 1.0, 60.0)
	_pattern_count = _labeled_spin(_body_ops, "Count", 2, 36, 1, 3)
	var pat_row := HBoxContainer.new()
	_body_ops.add_child(pat_row)
	_op_button(pat_row, "Linear", _linear_pattern)
	_op_button(pat_row, "Circular", _circular_pattern)
	_op_button(pat_row, "Mirror", _mirror)

	_body_ops.add_child(HSeparator.new())
	_offset_spin = _labeled_spin(_body_ops, "Offset", -50.0, 50.0, 0.5, 2.0)
	_op_button(_body_ops, "Offset body", _offset)

	_body_ops.add_child(HSeparator.new())
	var bool_row := HBoxContainer.new()
	_body_ops.add_child(bool_row)
	for op in ["fuse", "cut", "common"]:
		var b := Button.new()
		b.text = op.capitalize()
		b.pressed.connect(_arm_boolean.bind(op))
		bool_row.add_child(b)
	_op_button(_body_ops, "Measure to...", _arm_measure)


func _build_face_ops() -> void:
	_thickness_spin = _labeled_spin(_face_ops, "Thickness", 0.1, 50.0, 0.5, 2.0)
	_op_button(_face_ops, "Shell (open here)", _shell)
	_face_ops.add_child(HSeparator.new())
	_draft_angle_spin = _labeled_spin(_face_ops, "Draft °", 0.1, 45.0, 0.5, 3.0)
	_op_button(_face_ops, "Apply draft", _draft)
	_face_ops.add_child(HSeparator.new())
	var hole_type_row := HBoxContainer.new()
	_face_ops.add_child(hole_type_row)
	var hole_type_lbl := Label.new()
	hole_type_lbl.text = "Hole type"
	hole_type_lbl.custom_minimum_size = Vector2(80, 0)
	hole_type_lbl.add_theme_font_size_override("font_size", 11)
	hole_type_row.add_child(hole_type_lbl)
	_hole_type = OptionButton.new()
	_hole_type.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hole_type.add_item("Simple", 0)
	_hole_type.add_item("Counterbore", 1)
	_hole_type.add_item("Countersink", 2)
	hole_type_row.add_child(_hole_type)
	_hole_diameter = _labeled_spin(_face_ops, "Hole Ø", 0.1, 200.0, 0.5, 6.0)
	_hole_depth = _labeled_spin(_face_ops, "Depth", 0.0, 1000.0, 1.0, 0.0)
	_op_button(_face_ops, "Apply hole", _apply_hole)
	_op_button(_face_ops, "Face area", func() -> void:
		status.emit("Area: %.2f mm^2" % view.doc.measure_face_area(view.selected_face)))


func _on_selection_changed(body: String, face: String) -> void:
	if _pending != Pending.NONE:
		_resolve_pending(body, face)
		return
	visible = body != ""
	_body_ops.visible = body != "" and face == ""
	_face_ops.visible = face != ""
	if body != "" and face == "":
		_name_edit.text = view.doc.body_name(body)
		_color_picker.color = view.doc.get_body_color(body)


func _on_name_submitted(text: String) -> void:
	if view.selected_body == "":
		return
	if view.doc.rename_body(view.selected_body, text):
		view.refresh()
		status.emit("Renamed to %s" % text)


func _on_color_changed(color: Color) -> void:
	if view.selected_body == "":
		return
	if view.doc.set_body_color(view.selected_body, color):
		view.refresh()
		view._apply_selection_materials()


# --- body ops ---

# Fillet/chamfer target: the selected edge when there is one, else all edges.
func _round_targets() -> PackedStringArray:
	if view.selected_edge != "":
		return PackedStringArray([view.selected_edge])
	return view.doc.get_edge_ids(view.selected_body)


func _fillet_all() -> void:
	_apply_dressup(true)


func _chamfer_all() -> void:
	_apply_dressup(false)


func _apply_dressup(fillet: bool) -> void:
	if view.selected_body == "":
		return
	var name := "Fillet" if fillet else "Chamfer"
	var scope := "edge" if view.selected_edge != "" else "all edges"
	var targets := _round_targets()
	var value: float = _radius_spin.value
	# Timeline bodies get a parametric feature; free bodies (e.g. STEP imports)
	# use the direct command.
	var fid := view.feature_of_body(view.selected_body)
	var ok: bool
	if fid != "":
		if fillet:
			ok = view.doc.graph_add_fillet(fid, targets, value) != ""
		else:
			ok = view.doc.graph_add_chamfer(fid, targets, value) != ""
	elif fillet:
		ok = view.doc.fillet_edges(targets, value)
	else:
		ok = view.doc.chamfer_edges(targets, value)
	if ok:
		view.graph_changed()
		status.emit("%s %s %.1f applied" % [name, scope, value])
	else:
		status.emit("%s failed (value too large?)" % name)


func _mirror() -> void:
	var body := view.selected_body
	if body == "":
		return
	# Mirror across the YZ plane through the body's +X extent.
	var bb: Dictionary = view.doc.measure_bbox(body)
	if bb.is_empty():
		return
	var created: String = view.doc.mirror_body(body, Vector3(bb["max"].x, 0, 0), Vector3(1, 0, 0), true)
	view.graph_changed()
	status.emit("Mirrored body" if created != "" else "Mirror failed")


func _linear_pattern() -> void:
	var body := view.selected_body
	if body == "":
		return
	var made: PackedStringArray = view.doc.linear_pattern(
		body, Vector3(1, 0, 0), _pattern_spacing.value, int(_pattern_count.value))
	view.graph_changed()
	status.emit("%d copies created" % made.size() if made.size() > 0 else "Pattern failed")


func _circular_pattern() -> void:
	var body := view.selected_body
	if body == "":
		return
	# Around the Z axis through the world origin.
	var made: PackedStringArray = view.doc.circular_pattern(
		body, Vector3.ZERO, Vector3(0, 0, 1), int(_pattern_count.value), TAU)
	view.graph_changed()
	status.emit("%d copies created" % made.size() if made.size() > 0 else "Pattern failed")


func _offset() -> void:
	var body := view.selected_body
	if body == "":
		return
	if view.doc.offset_body(body, _offset_spin.value):
		view.graph_changed()
		status.emit("Offset %.1f mm applied" % _offset_spin.value)
	else:
		status.emit("Offset failed")


func _shell() -> void:
	var face := view.selected_face
	if face == "":
		return
	if view.doc.shell_body(PackedStringArray([face]), _thickness_spin.value):
		view.graph_changed()
		status.emit("Shelled, wall %.1f mm" % _thickness_spin.value)
	else:
		status.emit("Shell failed (thickness too large?)")


func _draft() -> bool:
	var face := view.selected_face
	var body := view.selected_body
	if face == "" or body == "":
		return false
	var bb: Dictionary = view.doc.measure_bbox(body)
	if bb.is_empty():
		status.emit("Draft failed (no bbox)")
		return false
	var mn: Vector3 = bb["min"]
	var mx: Vector3 = bb["max"]
	# Neutral plane at the body's bounding-box bottom; pull along +Z.
	var neutral_point := Vector3((mn.x + mx.x) * 0.5, (mn.y + mx.y) * 0.5, mn.z)
	var angle: float = _draft_angle_spin.value
	if view.doc.draft_faces(PackedStringArray([face]), angle, Vector3(0, 0, 1),
			neutral_point, Vector3(0, 0, 1)):
		view.graph_changed()
		status.emit("Draft %.1f° applied" % angle)
		return true
	status.emit("Draft failed")
	return false


func _apply_hole() -> bool:
	var face := view.selected_face
	var body := view.selected_body
	if face == "" or body == "":
		return false
	var target_fid := view.feature_of_body(body)
	if target_fid == "":
		status.emit("Hole needs a timeline body")
		return false
	var face_bb: Dictionary = view.doc.measure_bbox(face)
	if face_bb.is_empty():
		status.emit("Hole failed (no face bbox)")
		return false
	var fmn: Vector3 = face_bb["min"]
	var fmx: Vector3 = face_bb["max"]
	var position := (fmn + fmx) * 0.5
	# Outward face normal → reverse so direction points into the material.
	var outward: Vector3 = view.selected_face_normal()
	var direction: Vector3
	if outward.length_squared() > 1e-12:
		direction = -outward.normalized()
	else:
		var body_bb: Dictionary = view.doc.measure_bbox(body)
		if body_bb.is_empty():
			status.emit("Hole failed (no body bbox)")
			return false
		var bmn: Vector3 = body_bb["min"]
		var bmx: Vector3 = body_bb["max"]
		var body_center := (bmn + bmx) * 0.5
		direction = (body_center - position).normalized()
	var d: float = _hole_diameter.value
	var depth: float = _hole_depth.value
	var type_names := ["simple", "counterbore", "countersink"]
	var htype: String = type_names[_hole_type.selected]
	var hole_fid: String = view.doc.graph_add_hole(
		target_fid, htype, position, direction, d, depth,
		1.6 * d, 0.5 * d, 2.0 * d, 90.0)
	if hole_fid != "":
		view.graph_changed()
		status.emit("Hole Ø%.1f applied" % d)
		return true
	status.emit("Hole failed")
	return false


# --- two-target ops: arm, then click the second entity ---

func _arm_boolean(op: String) -> void:
	if view.selected_body == "":
		return
	_boolean_op = op
	_pending = Pending.BOOLEAN
	_pending_first = view.selected_body
	status.emit("%s: click the tool body" % op.capitalize())


func _arm_measure() -> void:
	var first := view.selected_face if view.selected_face != "" else view.selected_body
	if first == "":
		return
	_pending = Pending.MEASURE
	_pending_first = first
	status.emit("Measure: click the other body/face")


func _resolve_pending(body: String, face: String) -> void:
	var mode := _pending
	_pending = Pending.NONE
	var second := face if face != "" else body
	if second == "" or second == _pending_first:
		status.emit("Cancelled")
		return
	match mode:
		Pending.BOOLEAN:
			if body == "" or body == _pending_first:
				status.emit("Boolean cancelled")
				return
			if view.doc.boolean_op(_pending_first, body, _boolean_op, false):
				view.graph_changed()
				view.select_entity(_pending_first, "")
				status.emit("Boolean %s applied" % _boolean_op)
			else:
				status.emit("Boolean %s failed" % _boolean_op)
		Pending.MEASURE:
			var r: Dictionary = view.doc.measure_distance(_pending_first, second)
			if r.is_empty():
				status.emit("Measure failed")
			else:
				status.emit("Distance: %.2f mm" % r["distance"])
