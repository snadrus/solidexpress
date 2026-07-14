class_name TimelinePanel
extends PanelContainer
## Feature timeline (parametric history). One row per feature: suppress
## checkbox, name (inline rename), up/down reorder, delete. Selecting a row
## highlights its body and opens a universal JSON param editor (v0 — structured
## data by design, so the same editor works for every feature type and for AI
## round-trips).

signal status(text: String)

var view: DocumentView

var _list: VBoxContainer
var _rows := {}  # feature id -> row control
var _selected_fid := ""
var _editor_box: VBoxContainer
var _params_edit: TextEdit
var _json_toggle: CheckButton
var _refreshing := false
var _renaming_fid := ""
var property_panel: PropertyPanel


func _ready() -> void:
	custom_minimum_size = Vector2(260, 0)
	var vbox := VBoxContainer.new()
	add_child(vbox)
	var title := Label.new()
	title.text = "Timeline"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(250, 180)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	# Structured property editor (typed fields, live preview). The raw JSON
	# editor below stays available behind an "advanced" toggle.
	property_panel = PropertyPanel.new()
	property_panel.view = view
	property_panel.status.connect(func(t: String) -> void: status.emit(t))
	vbox.add_child(property_panel)

	_editor_box = VBoxContainer.new()
	_editor_box.visible = false
	vbox.add_child(_editor_box)
	_json_toggle = CheckButton.new()
	_json_toggle.text = "Params (JSON, advanced)"
	_json_toggle.add_theme_font_size_override("font_size", 11)
	_json_toggle.toggled.connect(func(on: bool) -> void:
		_params_edit.visible = on
		_params_edit.get_parent().get_node("ApplyJson").visible = on)
	_editor_box.add_child(_json_toggle)
	_params_edit = TextEdit.new()
	_params_edit.custom_minimum_size = Vector2(250, 70)
	_params_edit.add_theme_font_size_override("font_size", 11)
	_params_edit.visible = false
	_editor_box.add_child(_params_edit)
	var apply_btn := Button.new()
	apply_btn.name = "ApplyJson"
	apply_btn.text = "Apply"
	apply_btn.visible = false
	apply_btn.pressed.connect(_apply_params)
	_editor_box.add_child(apply_btn)

	view.document_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if _refreshing:
		return
	_refreshing = true
	_renaming_fid = ""
	for child in _list.get_children():
		child.queue_free()
	_rows.clear()
	var feats: Array = view.doc.graph_features()
	var n := feats.size()
	for i in n:
		_list.add_child(_make_row(feats[i], i, n))
	if _selected_fid != "" and not _has_feature(feats, _selected_fid):
		_selected_fid = ""
		_editor_box.visible = false
	_refreshing = false


func _has_feature(feats: Array, fid: String) -> bool:
	for f in feats:
		if f["id"] == fid:
			return true
	return false


func _make_row(f: Dictionary, index: int, count: int) -> Control:
	var fid: String = f["id"]
	var row := HBoxContainer.new()
	_rows[fid] = row

	var suppress := CheckBox.new()
	suppress.button_pressed = not f["suppressed"]
	suppress.tooltip_text = "Suppress/unsuppress"
	suppress.toggled.connect(func(on: bool) -> void: _set_suppressed(fid, not on))
	row.add_child(suppress)

	var name_btn := Button.new()
	name_btn.text = f["name"]
	name_btn.flat = true
	name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if f["suppressed"]:
		name_btn.modulate = Color(1, 1, 1, 0.45)
	name_btn.pressed.connect(_select_feature.bind(fid))
	name_btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.double_click \
				and ev.button_index == MOUSE_BUTTON_LEFT:
			_begin_rename(fid, row, name_btn)
	)
	row.add_child(name_btn)

	var edit_btn := Button.new()
	edit_btn.text = "e"
	edit_btn.tooltip_text = "Rename feature"
	edit_btn.pressed.connect(func() -> void: _begin_rename(fid, row, name_btn))
	row.add_child(edit_btn)

	var up := Button.new()
	up.text = "^"
	up.tooltip_text = "Move up"
	up.disabled = index <= 0
	up.pressed.connect(func() -> void: _move_feature(fid, index - 1))
	row.add_child(up)

	var down := Button.new()
	down.text = "v"
	down.tooltip_text = "Move down"
	down.disabled = index >= count - 1
	down.pressed.connect(func() -> void: _move_feature(fid, index + 1))
	row.add_child(down)

	var del := Button.new()
	del.text = "x"
	del.tooltip_text = "Delete feature"
	del.pressed.connect(_delete_feature.bind(fid))
	row.add_child(del)
	return row


func _begin_rename(fid: String, row: HBoxContainer, name_btn: Button) -> void:
	if _renaming_fid != "":
		return
	_renaming_fid = fid
	var edit := LineEdit.new()
	edit.text = name_btn.text
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var idx := name_btn.get_index()
	name_btn.visible = false
	row.add_child(edit)
	row.move_child(edit, idx)
	edit.grab_focus()
	edit.select_all()
	var finish := func(commit: bool) -> void:
		if _renaming_fid != fid:
			return
		var new_name := edit.text.strip_edges()
		_renaming_fid = ""
		if edit.get_parent() == row:
			row.remove_child(edit)
			edit.queue_free()
		name_btn.visible = true
		if commit and new_name != "" and new_name != name_btn.text:
			if view.doc.graph_rename(fid, new_name):
				view.graph_changed()
				status.emit("Feature renamed")
			else:
				status.emit("Rename failed")
	edit.text_submitted.connect(func(_t: String) -> void: finish.call(true))
	edit.focus_exited.connect(func() -> void: finish.call(true))
	edit.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
			finish.call(false)
			edit.accept_event()
	)


func _move_feature(fid: String, new_index: int) -> void:
	if view.doc.graph_move(fid, new_index):
		view.graph_changed()
		status.emit("Feature moved")
	else:
		status.emit("Cannot move: would break feature dependencies")


func _select_feature(fid: String) -> void:
	_selected_fid = fid
	for f in view.doc.graph_features():
		if f["id"] != fid:
			continue
		_params_edit.text = _pretty_json(f["params"])
		_editor_box.visible = true
		# Typed property editor when the feature type has a schema; the JSON
		# editor stays available behind the advanced toggle either way.
		if PropertyPanel.has_schema(f["type"]):
			property_panel.open(fid)
		else:
			property_panel.visible = false
		var body: String = f["output_body"]
		if body != "":
			view.select_entity(body, "")
		return


func _pretty_json(raw: String) -> String:
	var parsed = JSON.parse_string(raw)
	return JSON.stringify(parsed, "  ") if parsed != null else raw


func _apply_params() -> void:
	if _selected_fid == "":
		return
	if JSON.parse_string(_params_edit.text) == null:
		status.emit("Invalid JSON in params")
		return
	if view.doc.graph_set_params(_selected_fid, _params_edit.text):
		view.graph_changed()
		status.emit("Feature updated")
	else:
		status.emit("Regenerate FAILED — params reverted? check values")


func _set_suppressed(fid: String, suppressed: bool) -> void:
	if view.doc.graph_set_suppressed(fid, suppressed):
		view.graph_changed()


func _delete_feature(fid: String) -> void:
	if view.doc.graph_remove(fid):
		view.graph_changed()
		status.emit("Feature deleted")
	else:
		status.emit("Cannot delete: later features depend on it")
