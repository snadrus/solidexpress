class_name TransformHud
extends PanelContainer
## Bottom-of-viewport editable X/Y/Z position and W×H×D size for place mode
## and body selection. Move drag shows editable Δ (ΔZ hops off the plane).
## Resize/rotate show a focused precision distance/angle field.

signal position_committed(pos: Vector3)
signal size_committed(size: Vector3)
## Shown after a resize/rotate drag; user can refine the travelled value.
signal precision_committed(distance: float)
## Live or post-drag move Δ from the pre-drag center (mm).
signal move_delta_committed(delta: Vector3)

var _pos_x: SpinBox
var _pos_y: SpinBox
var _pos_z: SpinBox
var _size_w: SpinBox
var _size_h: SpinBox
var _size_d: SpinBox
var _precision_row: HBoxContainer
var _precision_spin: SpinBox
var _precision_label: Label
var _move_row: HBoxContainer
var _delta_x: SpinBox
var _delta_y: SpinBox
var _delta_z: SpinBox
var _syncing := false
var _size_editable := true


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -320
	offset_right = 320
	offset_top = -72
	offset_bottom = -16
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	root.add_child(row)
	_pos_x = _spin(row, "X", -1e6, 1e6, 0.1, 0.0)
	_pos_y = _spin(row, "Y", -1e6, 1e6, 0.1, 0.0)
	_pos_z = _spin(row, "Z", -1e6, 1e6, 0.1, 0.0)
	row.add_child(VSeparator.new())
	_size_w = _spin(row, "W", 0.1, 1e6, 0.1, 5.0)
	_size_h = _spin(row, "H", 0.1, 1e6, 0.1, 5.0)
	_size_d = _spin(row, "D", 0.1, 1e6, 0.1, 5.0)
	for s in [_pos_x, _pos_y, _pos_z]:
		s.value_changed.connect(_on_pos_changed)
		s.get_line_edit().text_submitted.connect(func(_t: String) -> void:
			s.apply()
			if not _syncing:
				position_committed.emit(current_position()))
	for s in [_size_w, _size_h, _size_d]:
		s.value_changed.connect(_on_size_changed)
		s.get_line_edit().text_submitted.connect(func(_t: String) -> void:
			s.apply()
			if not _syncing and _size_editable:
				size_committed.emit(current_size()))

	_move_row = HBoxContainer.new()
	_move_row.visible = false
	_move_row.add_theme_constant_override("separation", 6)
	root.add_child(_move_row)
	var move_lbl := Label.new()
	move_lbl.text = "Δ move"
	move_lbl.add_theme_font_size_override("font_size", 11)
	_move_row.add_child(move_lbl)
	_delta_x = _spin(_move_row, "ΔX", -1e6, 1e6, 0.1, 0.0)
	_delta_y = _spin(_move_row, "ΔY", -1e6, 1e6, 0.1, 0.0)
	_delta_z = _spin(_move_row, "ΔZ", -1e6, 1e6, 0.1, 0.0)
	for s in [_delta_x, _delta_y, _delta_z]:
		s.value_changed.connect(_on_move_delta_changed)
		s.get_line_edit().text_submitted.connect(func(_t: String) -> void:
			s.apply()
			if not _syncing:
				move_delta_committed.emit(current_move_delta()))
	var z_hint := Label.new()
	z_hint.text = "ΔZ typed only (drag stays on plane)"
	z_hint.add_theme_font_size_override("font_size", 10)
	z_hint.modulate = Color(1, 1, 1, 0.55)
	_move_row.add_child(z_hint)

	_precision_row = HBoxContainer.new()
	_precision_row.visible = false
	_precision_row.add_theme_constant_override("separation", 8)
	root.add_child(_precision_row)
	_precision_label = Label.new()
	_precision_label.text = "Δ"
	_precision_label.add_theme_font_size_override("font_size", 11)
	_precision_row.add_child(_precision_label)
	_precision_spin = SpinBox.new()
	_precision_spin.min_value = -1e6
	_precision_spin.max_value = 1e6
	_precision_spin.step = 0.01
	_precision_spin.suffix = "mm"
	_precision_spin.custom_minimum_size = Vector2(120, 0)
	_precision_spin.value_changed.connect(_on_precision_changed)
	_precision_row.add_child(_precision_spin)
	_precision_spin.get_line_edit().text_submitted.connect(
		func(_t: String) -> void: _commit_precision_ui(true))
	var hint := Label.new()
	hint.text = "Enter confirms · Esc dismisses"
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color(1, 1, 1, 0.55)
	_precision_row.add_child(hint)


func _spin(parent: Container, label: String, mn: float, mx: float, step: float,
		value: float) -> SpinBox:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 11)
	box.add_child(lbl)
	var spin := SpinBox.new()
	spin.min_value = mn
	spin.max_value = mx
	spin.step = step
	spin.value = value
	spin.custom_minimum_size = Vector2(72, 0)
	spin.select_all_on_focus = true
	box.add_child(spin)
	return spin


func set_values(pos: Vector3, size: Vector3, size_editable := true) -> void:
	_syncing = true
	_pos_x.value = pos.x
	_pos_y.value = pos.y
	_pos_z.value = pos.z
	_size_w.value = size.x
	_size_h.value = size.y
	_size_d.value = size.z
	_size_editable = size_editable
	_size_w.editable = size_editable
	_size_h.editable = size_editable
	_size_d.editable = size_editable
	_syncing = false


func current_position() -> Vector3:
	return Vector3(_pos_x.value, _pos_y.value, _pos_z.value)


func current_size() -> Vector3:
	return Vector3(_size_w.value, _size_h.value, _size_d.value)


func current_move_delta() -> Vector3:
	return Vector3(_delta_x.value, _delta_y.value, _delta_z.value)


## Live update during planar move (does not steal focus).
func set_move_delta(delta: Vector3) -> void:
	_move_row.visible = true
	_lift_for_extra_row()
	_syncing = true
	_delta_x.value = delta.x
	_delta_y.value = delta.y
	_delta_z.value = delta.z
	_syncing = false


func show_move_delta(delta: Vector3, focus_axis := "x") -> void:
	set_move_delta(delta)
	visible = true
	await get_tree().process_frame
	var spin := _delta_x
	match focus_axis:
		"y":
			spin = _delta_y
		"z":
			spin = _delta_z
	spin.get_line_edit().grab_focus()
	spin.get_line_edit().select_all()


func hide_move_delta() -> void:
	_move_row.visible = false
	_restore_height()


func show_precision(distance: float, axis_hint := "Δ", unit := "mm") -> void:
	_precision_row.visible = true
	_precision_label.text = axis_hint
	_precision_spin.suffix = unit
	_syncing = true
	_precision_spin.value = distance
	_syncing = false
	_lift_for_extra_row()
	visible = true
	await get_tree().process_frame
	_precision_spin.get_line_edit().grab_focus()
	_precision_spin.get_line_edit().select_all()


func hide_precision() -> void:
	_precision_row.visible = false
	_restore_height()


func is_pointer_over(global_pos: Vector2) -> bool:
	return visible and get_global_rect().has_point(global_pos)


func _lift_for_extra_row() -> void:
	offset_top = -130
	offset_bottom = -16


func _restore_height() -> void:
	if _move_row.visible or _precision_row.visible:
		_lift_for_extra_row()
	else:
		offset_top = -72
		offset_bottom = -16


func _on_pos_changed(_v: float) -> void:
	if _syncing:
		return
	position_committed.emit(current_position())


func _on_size_changed(_v: float) -> void:
	if _syncing or not _size_editable:
		return
	size_committed.emit(current_size())


func _on_move_delta_changed(_v: float) -> void:
	if _syncing:
		return
	move_delta_committed.emit(current_move_delta())


func _on_precision_changed(_v: float) -> void:
	if _syncing:
		return
	precision_committed.emit(_precision_spin.value)


func _commit_precision_ui(hide_after: bool) -> void:
	if not _precision_row.visible:
		return
	_precision_spin.apply()
	if not _syncing:
		precision_committed.emit(_precision_spin.value)
	if hide_after:
		hide_precision()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE:
			if _precision_row.visible:
				hide_precision()
				accept_event()
			elif _move_row.visible:
				hide_move_delta()
				accept_event()
		elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
			if _precision_row.visible:
				_commit_precision_ui(true)
				accept_event()
			elif _move_row.visible:
				_delta_x.apply()
				_delta_y.apply()
				_delta_z.apply()
				if not _syncing:
					move_delta_committed.emit(current_move_delta())
				hide_move_delta()
				accept_event()
