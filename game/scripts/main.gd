# Application composition root: 3D world (camera, light, grid, DocumentView
# inside a Z-up ModelSpace) plus the 2D UI shell (palette, card panel, status
# bar). Phase 1 drag-and-drop experience.
extends Node3D

var model_space: Node3D
var view: DocumentView
var camera: OrbitCamera
var interaction: ViewportInteraction
var card_panel: RichTextLabel
var card_box: PanelContainer
var status_label: Label
var show_variables := false  # View-menu override while the table is empty
var autosave_timer: Timer
var sketch_mode: SketchMode
var sketch_toolbar: PanelContainer
var timeline: TimelinePanel
var help_overlay: HelpOverlay
var variables_panel: VariablesPanel
var ops_panel: OpsPanel
var assembly_panel: AssemblyPanel
var view_widget: ViewWidget
var dim_value: SpinBox
var finish_op: OptionButton
var alias_edit: LineEdit
var notes_edit: TextEdit
var file_dialog: FileDialog
var confirm_dialog: ConfirmationDialog
var current_path := ""
enum FileAction { NONE, OPEN, SAVE_AS, IMPORT_STEP, EXPORT_STEP, EXPORT_STL, EXPORT_CONTEXT, EXPORT_DRAWING }
var _file_action: FileAction = FileAction.NONE
var _pending_discard: Callable = Callable()
var _file_popup: PopupMenu
var _recent_menu: PopupMenu
var _recent: Array = []  # paths, most recent first (max 8)
const _RECENT_CLEAR_ID := 100
const _RECENT_CFG := "user://recent.cfg"


func _finish_op_name() -> String:
	return ["new", "cut", "fuse"][finish_op.selected]
var extrude_distance: SpinBox
var _last_saved_revision := 0


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	_build_world()
	_build_ui()
	_build_autosave()
	# Keyboard cheat sheet on F1, above everything else.
	help_overlay = HelpOverlay.new()
	add_child(help_overlay)


func _build_world() -> void:
	camera = OrbitCamera.new()
	camera.name = "Camera"
	add_child(camera)
	# view/model_space wired after they exist (end of _build_world).

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(30, 140, 0)
	fill.light_energy = 0.4
	add_child(fill)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.17, 0.20)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.57, 0.62)
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)

	# Kernel is Z-up; Godot is Y-up. ModelSpace maps kernel +Z to world +Y.
	model_space = Node3D.new()
	model_space.name = "ModelSpace"
	model_space.basis = Basis(Vector3.RIGHT, -PI / 2.0)
	add_child(model_space)

	view = DocumentView.new()
	view.name = "DocumentView"
	model_space.add_child(view)

	sketch_mode = SketchMode.new()
	sketch_mode.name = "SketchMode"
	sketch_mode.view = view
	model_space.add_child(sketch_mode)

	# Grid + origin triad now come from WorldGizmos (mounted by ViewportInteraction).
	camera.view = view
	camera.model_space = model_space


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)

	# Interaction overlay (bottom of the UI stack, catches viewport input).
	interaction = ViewportInteraction.new()
	interaction.name = "Interaction"
	interaction.view = view
	interaction.camera = camera
	interaction.model_space = model_space
	interaction.sketch_mode = sketch_mode
	ui.add_child(interaction)

	# Top-left: file menu.
	var menu_bar := PanelContainer.new()
	menu_bar.name = "FileMenu"
	menu_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu_bar.position = Vector2(12, 12)
	ui.add_child(menu_bar)
	var file_btn := MenuButton.new()
	file_btn.text = "File"
	file_btn.flat = false
	var menu_row := HBoxContainer.new()
	menu_bar.add_child(menu_row)
	menu_row.add_child(file_btn)
	_file_popup = file_btn.get_popup()
	_file_popup.add_item("New", 0)
	_file_popup.add_item("Open...", 1)
	_file_popup.add_item("Save", 2)
	_file_popup.add_item("Save As...", 3)
	_file_popup.add_separator()
	_file_popup.add_item("Import STEP...", 4)
	_file_popup.add_item("Export STEP...", 5)
	_file_popup.add_item("Export STL...", 6)
	_file_popup.add_separator()
	_file_popup.add_item("Export AI Context...", 7)
	_file_popup.add_item("Export Drawing (SVG)...", 8)
	_file_popup.add_separator()
	_recent_menu = PopupMenu.new()
	_recent_menu.name = "RecentMenu"
	_file_popup.add_child(_recent_menu)
	_file_popup.add_submenu_node_item("Recent", _recent_menu)
	_recent_menu.id_pressed.connect(_on_recent_menu)
	_file_popup.id_pressed.connect(_on_file_menu)
	_load_recent()
	_rebuild_recent_menu()

	# Insert menu: reference geometry.
	var insert_btn := MenuButton.new()
	insert_btn.text = "Insert"
	insert_btn.flat = false
	menu_row.add_child(insert_btn)
	var insert_popup := insert_btn.get_popup()
	insert_popup.add_item("Datum Plane XY", 0)
	insert_popup.add_item("Datum Plane XZ", 1)
	insert_popup.add_item("Datum Plane YZ", 2)
	insert_popup.add_separator()
	insert_popup.add_item("Datum Axis X", 3)
	insert_popup.add_item("Datum Axis Y", 4)
	insert_popup.add_item("Datum Axis Z", 5)
	insert_popup.add_separator()
	insert_popup.add_item("Datum Point at Origin", 6)
	insert_popup.id_pressed.connect(_on_insert_menu)

	# View menu: entry points for panels that auto-hide when they have no data.
	var view_btn := MenuButton.new()
	view_btn.text = "View"
	view_btn.flat = false
	menu_row.add_child(view_btn)
	var view_popup := view_btn.get_popup()
	view_popup.add_check_item("Variables Panel", 0)
	view_popup.id_pressed.connect(func(id: int) -> void:
		if id == 0:
			show_variables = not show_variables
			view_popup.set_item_checked(view_popup.get_item_index(0), show_variables)
			_update_panel_visibility())

	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.min_size = Vector2i(700, 460)
	file_dialog.file_selected.connect(_on_file_selected)
	ui.add_child(file_dialog)

	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Discard unsaved changes?"
	confirm_dialog.confirmed.connect(_on_discard_confirmed)
	ui.add_child(confirm_dialog)

	# Left: primitive palette.
	var palette := PanelContainer.new()
	palette.name = "Palette"
	palette.set_anchors_preset(Control.PRESET_TOP_LEFT)
	palette.position = Vector2(12, 56)
	ui.add_child(palette)
	var vbox := VBoxContainer.new()
	palette.add_child(vbox)
	var title := Label.new()
	title.text = "Primitives"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	for entry in [["box", "Box"], ["cylinder", "Cylinder"], ["sphere", "Sphere"],
			["cone", "Cone"], ["torus", "Torus"]]:
		var btn := PaletteButton.new(entry[0], entry[1])
		btn.insert_requested.connect(interaction.insert_at_center)
		vbox.add_child(btn)
	vbox.add_child(HSeparator.new())
	var sketch_btn := UIIcons.button("sketch", "Sketch",
		"Start a sketch on the selected face (or the ground plane)")
	sketch_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	sketch_btn.custom_minimum_size = Vector2(110, 44)
	sketch_btn.pressed.connect(_start_sketch)
	vbox.add_child(sketch_btn)
	vbox.add_child(HSeparator.new())
	var hint := Label.new()
	hint.text = "drag into scene, or\nclick then place"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(hint)

	# Right: semantic card panel (auto-hides when nothing is selected).
	card_box = PanelContainer.new()
	card_box.name = "CardPanel"
	card_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	card_box.anchor_left = 1.0
	card_box.offset_left = -320
	card_box.offset_right = -12
	# Starts below the menu/toolbar row so the centered sketch toolbar can
	# never collide with it.
	card_box.offset_top = 52
	card_box.offset_bottom = 420
	card_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ui.add_child(card_box)
	var card_vbox := VBoxContainer.new()
	card_box.add_child(card_vbox)
	var card_title := Label.new()
	card_title.text = "Selection"
	card_vbox.add_child(card_title)
	card_panel = RichTextLabel.new()
	card_panel.fit_content = false
	card_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_panel.custom_minimum_size = Vector2(290, 200)
	card_panel.add_theme_font_size_override("normal_font_size", 12)
	card_vbox.add_child(card_panel)

	# Editable semantic-card free text: aliases (one line) and notes.
	var alias_label := Label.new()
	alias_label.text = "Aliases (what you'd call this)"
	alias_label.add_theme_font_size_override("font_size", 11)
	card_vbox.add_child(alias_label)
	alias_edit = LineEdit.new()
	alias_edit.placeholder_text = "e.g. the mounting face"
	alias_edit.text_submitted.connect(func(t: String) -> void: _save_card_text(t, notes_edit.text))
	card_vbox.add_child(alias_edit)
	var notes_label := Label.new()
	notes_label.text = "Notes (intent, constraints, context)"
	notes_label.add_theme_font_size_override("font_size", 11)
	card_vbox.add_child(notes_label)
	notes_edit = TextEdit.new()
	notes_edit.custom_minimum_size = Vector2(290, 60)
	notes_edit.add_theme_font_size_override("font_size", 11)
	card_vbox.add_child(notes_edit)
	var save_card := UIIcons.button("save", "Save card text",
		"Save the aliases and notes onto the selection's semantic card")
	save_card.pressed.connect(func() -> void: _save_card_text(alias_edit.text, notes_edit.text))
	card_vbox.add_child(save_card)

	# Right, below card panel: context operations for the selection.
	ops_panel = OpsPanel.new()
	ops_panel.name = "OpsPanel"
	ops_panel.view = view
	ops_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ops_panel.anchor_left = 1.0
	ops_panel.anchor_right = 1.0
	ops_panel.offset_left = -320
	ops_panel.offset_right = -12
	ops_panel.offset_top = 480
	ops_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ui.add_child(ops_panel)
	ops_panel.status.connect(_on_status)

	# Right, second column: assembly browser (auto-hides when no instances).
	assembly_panel = AssemblyPanel.new()
	assembly_panel.name = "AssemblyPanel"
	assembly_panel.view = view
	assembly_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	assembly_panel.anchor_left = 1.0
	assembly_panel.anchor_right = 1.0
	assembly_panel.offset_left = -652
	assembly_panel.offset_right = -332
	assembly_panel.offset_top = 480
	assembly_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ui.add_child(assembly_panel)
	assembly_panel.status.connect(_on_status)
	assembly_panel.instance_selected.connect(func(id: String) -> void:
		var node := view.instance_node(id)
		if node != null:
			camera.pivot = model_space.to_global(node.position)
			camera._update_transform()
			_on_status("Instance focused"))

	# Top-right corner: clickable view widget (left of the card panel).
	view_widget = ViewWidget.new()
	view_widget.name = "ViewWidget"
	view_widget.camera = camera
	view_widget.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	view_widget.anchor_left = 1.0
	view_widget.anchor_right = 1.0
	view_widget.offset_left = -436
	view_widget.offset_right = -344
	view_widget.offset_top = 52
	view_widget.offset_bottom = 144
	view_widget.tooltip_text = "Click a face, edge, or corner to snap the view"
	ui.add_child(view_widget)

	# Left, below palette: feature timeline + variables.
	timeline = TimelinePanel.new()
	timeline.name = "Timeline"
	timeline.view = view
	timeline.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	timeline.anchor_top = 1.0
	timeline.offset_left = 12
	timeline.offset_top = -420
	timeline.offset_bottom = -42
	ui.add_child(timeline)
	timeline.status.connect(_on_status)

	variables_panel = VariablesPanel.new()
	variables_panel.name = "Variables"
	variables_panel.view = view
	variables_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	variables_panel.anchor_top = 1.0
	variables_panel.offset_left = 280
	variables_panel.offset_right = 540
	variables_panel.offset_top = -420
	variables_panel.offset_bottom = -42
	ui.add_child(variables_panel)
	variables_panel.status.connect(_on_status)

	# Bottom: status bar.
	var status_bar := PanelContainer.new()
	status_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status_bar.anchor_top = 1.0
	status_bar.offset_top = -30
	ui.add_child(status_bar)
	status_label = Label.new()
	status_label.text = "middle-drag orbit · shift+middle pan · wheel zoom · F fit · 1/2/3/7 views · click select (again for face/edge) · drag to move · drag face to push/pull · Del delete · Ctrl+Z/Y undo · Ctrl+S save"
	status_label.add_theme_font_size_override("font_size", 12)
	status_bar.add_child(status_label)

	# Sketch toolbar (visible only in sketch mode): tools + extrude distance.
	sketch_toolbar = PanelContainer.new()
	sketch_toolbar.name = "SketchToolbar"
	sketch_toolbar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sketch_toolbar.anchor_left = 0.5
	sketch_toolbar.anchor_right = 0.5
	sketch_toolbar.offset_left = -260
	sketch_toolbar.offset_right = 260
	sketch_toolbar.offset_top = 8
	# The toolbar's content is wider than its nominal offsets; grow evenly so
	# it stays centered instead of spilling off to one side.
	sketch_toolbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sketch_toolbar.visible = false
	ui.add_child(sketch_toolbar)
	var hbox := HBoxContainer.new()
	sketch_toolbar.add_child(hbox)
	for entry in [[SketchMode.Tool.SELECT, "select", "Select tool (S)"],
			[SketchMode.Tool.LINE, "line", "Line tool (L)"],
			[SketchMode.Tool.RECT, "rect", "Rectangle tool (R)"],
			[SketchMode.Tool.CIRCLE, "circle", "Circle tool (C)"]]:
		var b := UIIcons.button(entry[1], "", entry[2])
		b.pressed.connect(sketch_mode.set_tool.bind(entry[0]))
		hbox.add_child(b)
	hbox.add_child(VSeparator.new())
	# Constraints (act on the SELECT tool's selection).
	for entry in [["horizontal", "Horizontal constraint"],
			["vertical", "Vertical constraint"],
			["parallel", "Parallel constraint (two lines)"],
			["perpendicular", "Perpendicular constraint (two lines)"],
			["equal", "Equal length/radius constraint"],
			["coincident", "Coincident constraint (two points)"]]:
		var cb := UIIcons.button(entry[0], "", entry[1])
		cb.pressed.connect(_apply_constraint.bind(entry[0], 0.0))
		hbox.add_child(cb)
	dim_value = SpinBox.new()
	dim_value.min_value = 0.01
	dim_value.max_value = 10000
	dim_value.step = 0.5
	dim_value.value = 10
	hbox.add_child(dim_value)
	var dim_btn := UIIcons.button("dimension", "",
		"Apply dimension: distance (line/two points) or radius (circle)")
	dim_btn.pressed.connect(_apply_dimension)
	hbox.add_child(dim_btn)
	hbox.add_child(VSeparator.new())
	var dist_label := Label.new()
	dist_label.text = "Extrude:"
	hbox.add_child(dist_label)
	extrude_distance = SpinBox.new()
	extrude_distance.min_value = -1000
	extrude_distance.max_value = 1000
	extrude_distance.step = 1
	extrude_distance.value = 20
	extrude_distance.suffix = "mm"
	hbox.add_child(extrude_distance)
	finish_op = OptionButton.new()
	for op_name in ["New", "Cut", "Fuse"]:
		finish_op.add_item(op_name)
	finish_op.tooltip_text = "How the result combines with the body sketched on"
	hbox.add_child(finish_op)
	var finish_btn := UIIcons.button("extrude", "Extrude",
		"Extrude the sketch profile by the distance")
	finish_btn.pressed.connect(func() -> void:
		sketch_mode.finish_extrude(extrude_distance.value, _finish_op_name()))
	hbox.add_child(finish_btn)
	var revolve_btn := UIIcons.button("revolve", "Revolve",
		"Full revolve around the selected line (or sketch Y axis)")
	revolve_btn.pressed.connect(func() -> void:
		sketch_mode.finish_revolve(TAU, _finish_op_name()))
	hbox.add_child(revolve_btn)
	var cancel_btn := UIIcons.button("cancel", "", "Cancel sketch (Esc)")
	cancel_btn.pressed.connect(sketch_mode.cancel)
	hbox.add_child(cancel_btn)

	view.selection_changed.connect(_on_selection_changed)
	view.document_changed.connect(_on_document_changed)
	_update_panel_visibility()
	interaction.status.connect(_on_status)
	sketch_mode.status.connect(_on_status)
	sketch_mode.finished.connect(func(_id: String) -> void: sketch_toolbar.visible = false)
	sketch_mode.cancelled.connect(func() -> void: sketch_toolbar.visible = false)
	sketch_mode.selection_changed.connect(_on_sketch_selection)


func _apply_constraint(type: String, value: float) -> void:
	var result := sketch_mode.constrain(type, value)
	if result == "":
		_on_status("Select entities with the Sel tool first (%s)" % type)
	else:
		_on_status("%s: %s" % [type, result])


func _apply_dimension() -> void:
	var kind := "distance"
	if sketch_mode.selected.size() == 1:
		var t: String = sketch_mode.sketch.entity_info(sketch_mode.selected[0]).get("type", "")
		if t == "circle" or t == "arc":
			kind = "radius"
	_apply_constraint(kind, dim_value.value)


func _on_sketch_selection(ids: Array) -> void:
	var v := sketch_mode.measured_value()
	if v > 0.0:
		dim_value.value = v
	if ids.is_empty():
		_on_status("Sketch selection cleared")
	else:
		_on_status("%d sketch entities selected" % ids.size())


func _build_autosave() -> void:
	autosave_timer = Timer.new()
	autosave_timer.wait_time = 60.0
	autosave_timer.autostart = true
	autosave_timer.timeout.connect(_autosave)
	add_child(autosave_timer)


func _autosave() -> void:
	if view.doc.revision() == _last_saved_revision:
		return
	var path := ProjectSettings.globalize_path("user://autosave.sxp")
	if view.save(path):
		_last_saved_revision = view.doc.revision()


func _start_sketch() -> void:
	# Sketch on the selected axis-aligned planar face if there is one, else ground.
	if sketch_mode.active:
		return
	var origin := Vector3.ZERO
	var normal := Vector3(0, 0, 1)
	var plane_msg := "Sketch on ground (XY)"
	sketch_mode.target_fid = ""
	if view.selected_face != "":
		# Keep cut/fuse target even when the face is not axis-aligned (ground fallback).
		sketch_mode.target_fid = view.feature_of_body(view.selected_body)
		var plane: Dictionary = SketchMode.derive_face_plane(
			view.doc, view.selected_face, view.selected_body)
		plane_msg = plane["message"]
		if plane["ok"]:
			origin = plane["origin"]
			normal = plane["normal"]
	sketch_mode.begin(origin, normal)
	sketch_toolbar.visible = true
	_on_status(plane_msg)


func _selected_entity() -> String:
	return view.selected_face if view.selected_face != "" else view.selected_body


func _save_card_text(alias_text: String, notes_text: String) -> void:
	var target := _selected_entity()
	if target == "":
		return
	view.doc.set_card_alias(target, alias_text)
	view.doc.set_card_notes(target, notes_text)
	card_panel.text = view.selection_card()
	_on_status("Card text saved")


func _on_selection_changed(_body: String, _face: String) -> void:
	var md := view.selection_card()
	card_panel.text = md if md != "" else "[i]nothing selected[/i]"
	var target := _selected_entity()
	alias_edit.text = view.doc.get_card_alias(target) if target != "" else ""
	notes_edit.text = view.doc.get_card_notes(target) if target != "" else ""
	alias_edit.editable = target != ""
	notes_edit.editable = target != ""
	_update_panel_visibility()


func _on_document_changed() -> void:
	_on_selection_changed(view.selected_body, view.selected_face)


## Context panels only occupy screen space while they have content: the
## selection card follows the selection, the timeline appears with the first
## feature, and the variables table shows once a variable exists (or is
## forced on from the View menu so there's an entry point to create one).
func _update_panel_visibility() -> void:
	card_box.visible = _selected_entity() != ""
	timeline.visible = view.doc.graph_features().size() > 0
	variables_panel.visible = show_variables or view.doc.list_variables().size() > 0
	# Keep the variables table flush against whatever is to its left.
	variables_panel.offset_left = 280 if timeline.visible else 12
	variables_panel.offset_right = variables_panel.offset_left + 260


func _on_status(text: String) -> void:
	if text != "":
		status_label.text = text


func _on_file_menu(id: int) -> void:
	match id:
		0:  # New
			_confirm_discard(_do_new)
		1:
			_confirm_discard(_do_open_dialog)
		2:
			_save_current()
		3:
			_show_file_dialog(FileAction.SAVE_AS, FileDialog.FILE_MODE_SAVE_FILE, "*.sxp ; SolidExpress")
		4:
			_show_file_dialog(FileAction.IMPORT_STEP, FileDialog.FILE_MODE_OPEN_FILE, "*.step, *.stp ; STEP")
		5:
			_show_file_dialog(FileAction.EXPORT_STEP, FileDialog.FILE_MODE_SAVE_FILE, "*.step, *.stp ; STEP")
		6:
			_show_file_dialog(FileAction.EXPORT_STL, FileDialog.FILE_MODE_SAVE_FILE, "*.stl ; STL")
		7:
			_show_file_dialog(FileAction.EXPORT_CONTEXT, FileDialog.FILE_MODE_SAVE_FILE, "*.md ; Markdown")
		8:
			_show_file_dialog(FileAction.EXPORT_DRAWING, FileDialog.FILE_MODE_SAVE_FILE, "*.svg ; SVG drawing")


func _do_new() -> void:
	view.new_document()
	current_path = ""
	_last_saved_revision = view.doc.revision()
	_on_status("New document")


func _do_open_dialog() -> void:
	_show_file_dialog(FileAction.OPEN, FileDialog.FILE_MODE_OPEN_FILE, "*.sxp ; SolidExpress")


func _document_is_dirty() -> bool:
	if view.doc.revision() == _last_saved_revision:
		return false
	return view.doc.body_ids().size() > 0 or view.doc.graph_features().size() > 0


func _confirm_discard(action: Callable) -> void:
	if not _document_is_dirty():
		action.call()
		return
	_pending_discard = action
	confirm_dialog.popup_centered()


func _on_discard_confirmed() -> void:
	var action := _pending_discard
	_pending_discard = Callable()
	if action.is_valid():
		action.call()


func _load_recent() -> void:
	_recent.clear()
	var cfg := ConfigFile.new()
	if cfg.load(_RECENT_CFG) != OK:
		return
	var files: Variant = cfg.get_value("recent", "files", [])
	if files is Array:
		for p in files:
			if typeof(p) == TYPE_STRING and str(p) != "":
				_recent.append(str(p))
		if _recent.size() > 8:
			_recent.resize(8)


func _save_recent() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("recent", "files", _recent)
	cfg.save(_RECENT_CFG)


func _push_recent(path: String) -> void:
	if path == "":
		return
	_recent.erase(path)
	_recent.push_front(path)
	while _recent.size() > 8:
		_recent.pop_back()
	_save_recent()
	_rebuild_recent_menu()


func _rebuild_recent_menu() -> void:
	if _recent_menu == null:
		return
	_recent_menu.clear()
	for i in range(_recent.size()):
		_recent_menu.add_item(str(_recent[i]), i)
	if _recent.size() > 0:
		_recent_menu.add_separator()
	_recent_menu.add_item("Clear Recent", _RECENT_CLEAR_ID)


func _on_recent_menu(id: int) -> void:
	if id == _RECENT_CLEAR_ID:
		_recent.clear()
		_save_recent()
		_rebuild_recent_menu()
		return
	if id < 0 or id >= _recent.size():
		return
	var path: String = str(_recent[id])
	if not FileAccess.file_exists(path):
		_recent.remove_at(id)
		_save_recent()
		_rebuild_recent_menu()
		_on_status("Missing file removed from recent: " + path)
		return
	_confirm_discard(func() -> void: _open_document(path))


func _open_document(path: String) -> void:
	if view.load_from(path):
		current_path = path
		_last_saved_revision = view.doc.revision()
		_push_recent(path)
		_on_status("Opened " + path)
	else:
		_on_status("Open failed: " + path)


func _on_insert_menu(id: int) -> void:
	var did := ""
	match id:
		0: did = view.doc.add_datum_plane(Vector3.ZERO, Vector3(0, 0, 1))
		1: did = view.doc.add_datum_plane(Vector3.ZERO, Vector3(0, 1, 0))
		2: did = view.doc.add_datum_plane(Vector3.ZERO, Vector3(1, 0, 0))
		3: did = view.doc.add_datum_axis(Vector3.ZERO, Vector3(1, 0, 0))
		4: did = view.doc.add_datum_axis(Vector3.ZERO, Vector3(0, 1, 0))
		5: did = view.doc.add_datum_axis(Vector3.ZERO, Vector3(0, 0, 1))
		6: did = view.doc.add_datum_point(Vector3.ZERO)
	if did != "":
		view.graph_changed()
		_on_status("Datum added")
	else:
		_on_status("Datum creation failed")


func _show_file_dialog(action: FileAction, mode: FileDialog.FileMode, filter: String) -> void:
	_file_action = action
	file_dialog.file_mode = mode
	file_dialog.filters = PackedStringArray([filter])
	file_dialog.popup_centered()


func _save_current() -> void:
	if current_path == "":
		_show_file_dialog(FileAction.SAVE_AS, FileDialog.FILE_MODE_SAVE_FILE, "*.sxp ; SolidExpress")
		return
	if view.save(current_path):
		_last_saved_revision = view.doc.revision()
		_push_recent(current_path)
		_on_status("Saved " + current_path)
	else:
		_on_status("Save FAILED: " + current_path)


func _on_file_selected(path: String) -> void:
	var action := _file_action
	_file_action = FileAction.NONE
	match action:
		FileAction.OPEN:
			_open_document(path)
		FileAction.SAVE_AS:
			if not path.ends_with(".sxp"):
				path += ".sxp"
			current_path = path
			_save_current()
		FileAction.IMPORT_STEP:
			var ids: PackedStringArray = view.doc.import_step(path)
			view.graph_changed()
			_on_status("%d bodies imported" % ids.size() if ids.size() > 0 else "Import failed")
		FileAction.EXPORT_STEP:
			_on_status("Exported STEP" if view.doc.export_step(path) else "STEP export failed")
		FileAction.EXPORT_STL:
			_on_status("Exported STL" if view.doc.export_stl(path, true) else "STL export failed")
		FileAction.EXPORT_CONTEXT:
			if not path.ends_with(".md"):
				path += ".md"
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f:
				f.store_string(view.doc.export_context())
				f.close()
				_on_status("Exported AI context: " + path)
			else:
				_on_status("Context export failed: " + path)
		FileAction.EXPORT_DRAWING:
			if not path.ends_with(".svg"):
				path += ".svg"
			if view.doc.export_drawing_svg(path, 1.0):
				_on_status("Exported drawing: " + path)
			else:
				_on_status("Drawing export failed (empty document?)")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_confirm_discard(func() -> void: get_tree().quit())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.ctrl_pressed:
		match event.keycode:
			KEY_S:
				_save_current()
			KEY_O:
				_confirm_discard(_do_open_dialog)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		help_overlay.toggle()
		get_viewport().set_input_as_handled()
