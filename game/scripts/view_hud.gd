class_name ViewHud
extends PanelContainer
## Compact view controls beside the ViewWidget: display mode, section, fit,
## and a CAD mouse-navigation preset (SolidWorks / Fusion / SolidExpress).

signal display_cycle_requested
signal section_toggle_requested
signal fit_requested
signal nav_preset_changed(preset: int)
signal save_view_requested

var _display_btn: Button
var _section_btn: Button
var _fit_btn: Button
var _nav_option: OptionButton
var _save_view_btn: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(96, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	_display_btn = Button.new()
	_display_btn.text = "Shade"
	_display_btn.tooltip_text = "Cycle display mode (W)"
	_display_btn.pressed.connect(func() -> void: display_cycle_requested.emit())
	col.add_child(_display_btn)
	_section_btn = Button.new()
	_section_btn.text = "Section"
	_section_btn.toggle_mode = true
	_section_btn.tooltip_text = "Toggle section view (K)"
	_section_btn.toggled.connect(func(_on: bool) -> void: section_toggle_requested.emit())
	col.add_child(_section_btn)
	_fit_btn = Button.new()
	_fit_btn.text = "Fit"
	_fit_btn.tooltip_text = "Frame selection, or all if nothing selected (F). Shift+F = always all."
	_fit_btn.pressed.connect(func() -> void: fit_requested.emit())
	col.add_child(_fit_btn)
	_nav_option = OptionButton.new()
	_nav_option.tooltip_text = (
		"Mouse nav preset:\n"
		+ "SX/SW — middle orbit, Shift+middle pan\n"
		+ "Fusion — middle pan, Shift+middle orbit"
	)
	_nav_option.add_item("Nav: SX", OrbitCamera.NavPreset.SOLIDEXPRESS)
	_nav_option.add_item("Nav: SW", OrbitCamera.NavPreset.SOLIDWORKS)
	_nav_option.add_item("Nav: Fusion", OrbitCamera.NavPreset.FUSION)
	_nav_option.item_selected.connect(_on_nav_selected)
	col.add_child(_nav_option)
	_save_view_btn = Button.new()
	_save_view_btn.text = "Save view"
	_save_view_btn.tooltip_text = "Save current camera as named view “User”"
	_save_view_btn.pressed.connect(func() -> void: save_view_requested.emit())
	col.add_child(_save_view_btn)


func _on_nav_selected(idx: int) -> void:
	nav_preset_changed.emit(_nav_option.get_item_id(idx))


func sync_from_view(view: DocumentView) -> void:
	if view == null:
		return
	var labels := ["Shade", "Edges", "Wire"]
	var i: int = clampi(int(view.display_mode), 0, 2)
	_display_btn.text = labels[i]
	_section_btn.set_pressed_no_signal(view.section_enabled)


func sync_nav_preset(preset: int) -> void:
	for i in _nav_option.item_count:
		if _nav_option.get_item_id(i) == preset:
			_nav_option.select(i)
			return
