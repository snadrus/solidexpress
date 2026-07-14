class_name TimelinePanel
extends PanelContainer
## Feature timeline (parametric history). One row per feature: suppress
## checkbox, name, delete button. Selecting a row highlights its body and
## opens a universal JSON param editor (v0 — structured data by design, so
## the same editor works for every feature type and for AI round-trips).

signal status(text: String)

var view: DocumentView

var _list: VBoxContainer
var _rows := {}  # feature id -> row control
var _selected_fid := ""
var _editor_box: VBoxContainer
var _params_edit: TextEdit
var _refreshing := false


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

	_editor_box = VBoxContainer.new()
	_editor_box.visible = false
	vbox.add_child(_editor_box)
	var ed_label := Label.new()
	ed_label.text = "Params (JSON)"
	ed_label.add_theme_font_size_override("font_size", 11)
	_editor_box.add_child(ed_label)
	_params_edit = TextEdit.new()
	_params_edit.custom_minimum_size = Vector2(250, 70)
	_params_edit.add_theme_font_size_override("font_size", 11)
	_editor_box.add_child(_params_edit)
	var apply_btn := Button.new()
	apply_btn.text = "Apply"
	apply_btn.pressed.connect(_apply_params)
	_editor_box.add_child(apply_btn)

	view.document_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if _refreshing:
		return
	_refreshing = true
	for child in _list.get_children():
		child.queue_free()
	_rows.clear()
	var feats: Array = view.doc.graph_features()
	for f in feats:
		_list.add_child(_make_row(f))
	if _selected_fid != "" and not _has_feature(feats, _selected_fid):
		_selected_fid = ""
		_editor_box.visible = false
	_refreshing = false


func _has_feature(feats: Array, fid: String) -> bool:
	for f in feats:
		if f["id"] == fid:
			return true
	return false


func _make_row(f: Dictionary) -> Control:
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
	row.add_child(name_btn)

	var del := Button.new()
	del.text = "x"
	del.tooltip_text = "Delete feature"
	del.pressed.connect(_delete_feature.bind(fid))
	row.add_child(del)
	return row


func _select_feature(fid: String) -> void:
	_selected_fid = fid
	for f in view.doc.graph_features():
		if f["id"] != fid:
			continue
		_params_edit.text = _pretty_json(f["params"])
		_editor_box.visible = true
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
