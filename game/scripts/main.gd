# Application composition root: 3D world (camera, light, grid, DocumentView
# inside a Z-up ModelSpace) plus the 2D UI shell (palette, card panel, status
# bar). Phase 1 drag-and-drop experience.
extends Node3D

const SAVE_PATH := "user://untitled.sxp"

var model_space: Node3D
var view: DocumentView
var camera: OrbitCamera
var interaction: ViewportInteraction
var card_panel: RichTextLabel
var status_label: Label
var autosave_timer: Timer
var _last_saved_revision := 0


func _ready() -> void:
	_build_world()
	_build_ui()
	_build_autosave()


func _build_world() -> void:
	camera = OrbitCamera.new()
	camera.name = "Camera"
	add_child(camera)

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

	model_space.add_child(_make_grid())


func _make_grid() -> MeshInstance3D:
	# 1000x1000 mm grid on the model XY plane, 50 mm pitch, brighter axes.
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var half := 500.0
	var step := 50.0
	var i := -half
	while i <= half:
		im.surface_set_color(Color(0.3, 0.3, 0.34))
		im.surface_add_vertex(Vector3(i, -half, 0))
		im.surface_add_vertex(Vector3(i, half, 0))
		im.surface_add_vertex(Vector3(-half, i, 0))
		im.surface_add_vertex(Vector3(half, i, 0))
		i += step
	# Axes: X red, Y green.
	im.surface_set_color(Color(0.8, 0.3, 0.3))
	im.surface_add_vertex(Vector3.ZERO)
	im.surface_add_vertex(Vector3(half, 0, 0))
	im.surface_set_color(Color(0.3, 0.8, 0.3))
	im.surface_add_vertex(Vector3.ZERO)
	im.surface_add_vertex(Vector3(0, half, 0))
	im.surface_end()

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	var node := MeshInstance3D.new()
	node.name = "Grid"
	node.mesh = im
	node.material_override = mat
	return node


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
	ui.add_child(interaction)

	# Left: primitive palette.
	var palette := PanelContainer.new()
	palette.name = "Palette"
	palette.set_anchors_preset(Control.PRESET_TOP_LEFT)
	palette.position = Vector2(12, 12)
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
	var hint := Label.new()
	hint.text = "drag into scene\nor click to insert"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(hint)

	# Right: semantic card panel.
	var card_box := PanelContainer.new()
	card_box.name = "CardPanel"
	card_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	card_box.anchor_left = 1.0
	card_box.offset_left = -320
	card_box.offset_right = -12
	card_box.offset_top = 12
	card_box.offset_bottom = 420
	ui.add_child(card_box)
	var card_vbox := VBoxContainer.new()
	card_box.add_child(card_vbox)
	var card_title := Label.new()
	card_title.text = "Selection"
	card_vbox.add_child(card_title)
	card_panel = RichTextLabel.new()
	card_panel.fit_content = false
	card_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_panel.custom_minimum_size = Vector2(290, 360)
	card_panel.add_theme_font_size_override("normal_font_size", 12)
	card_vbox.add_child(card_panel)

	# Bottom: status bar.
	var status_bar := PanelContainer.new()
	status_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status_bar.anchor_top = 1.0
	status_bar.offset_top = -30
	ui.add_child(status_bar)
	status_label = Label.new()
	status_label.text = "middle-drag orbit · shift+middle pan · wheel zoom · click select (again for face) · drag selection to move · drag selected face to push/pull · Del delete · Ctrl+Z/Y undo/redo · Ctrl+S save"
	status_label.add_theme_font_size_override("font_size", 12)
	status_bar.add_child(status_label)

	view.selection_changed.connect(_on_selection_changed)
	view.document_changed.connect(_on_document_changed)
	interaction.status.connect(_on_status)


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


func _on_selection_changed(_body: String, _face: String) -> void:
	var md := view.selection_card()
	card_panel.text = md if md != "" else "[i]nothing selected[/i]"


func _on_document_changed() -> void:
	_on_selection_changed(view.selected_body, view.selected_face)


func _on_status(text: String) -> void:
	if text != "":
		status_label.text = text


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.ctrl_pressed:
		match event.keycode:
			KEY_S:
				var path := ProjectSettings.globalize_path(SAVE_PATH)
				_on_status("Saved to " + path if view.save(path) else "Save FAILED")
			KEY_O:
				var path := ProjectSettings.globalize_path(SAVE_PATH)
				_on_status("Loaded " + path if view.load_from(path) else "Load failed (no file?)")
