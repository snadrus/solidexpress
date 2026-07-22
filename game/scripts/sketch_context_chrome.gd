class_name SketchContextChrome
extends Control
## On-canvas chips for sketch tool variants and selection actions.
## Sits above the 3D view; positions follow the pointer or selection.

signal variant_chosen(kind: String, variant: String)
signal action_chosen(action: String)
signal finish_requested(op: String, distance: float)

const CHIP_H := 28
const CHIP_PAD := 6

var sketch_mode: SketchMode
var _variant_bar: HBoxContainer
var _action_bar: HBoxContainer
var _finish_bar: HBoxContainer
var _extrude_spin: SpinBox
var _finish_op: OptionButton
var _dim_spin: SpinBox
var _active_kind := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_variant_bar = _make_bar()
	_action_bar = _make_bar()
	_finish_bar = _make_bar()
	_build_finish_bar()
	_finish_bar.visible = false
	_variant_bar.visible = false
	_action_bar.visible = false


func _make_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bar)
	return bar


func _build_finish_bar() -> void:
	_dim_spin = SpinBox.new()
	_dim_spin.min_value = 0.01
	_dim_spin.max_value = 10000
	_dim_spin.step = 0.5
	_dim_spin.value = 10
	_dim_spin.custom_minimum_size = Vector2(72, CHIP_H)
	_dim_spin.tooltip_text = "Dimension value"
	_finish_bar.add_child(_dim_spin)
	var dim_btn := Button.new()
	dim_btn.text = "Dim"
	dim_btn.custom_minimum_size = Vector2(44, CHIP_H)
	dim_btn.pressed.connect(func() -> void: action_chosen.emit("dimension"))
	_finish_bar.add_child(dim_btn)
	_extrude_spin = SpinBox.new()
	_extrude_spin.min_value = -1000
	_extrude_spin.max_value = 1000
	_extrude_spin.step = 1
	_extrude_spin.value = 20
	_extrude_spin.suffix = "mm"
	_extrude_spin.custom_minimum_size = Vector2(88, CHIP_H)
	_finish_bar.add_child(_extrude_spin)
	_finish_op = OptionButton.new()
	for n in ["New", "Cut", "Fuse"]:
		_finish_op.add_item(n)
	_finish_op.custom_minimum_size = Vector2(64, CHIP_H)
	_finish_bar.add_child(_finish_op)
	var ex := Button.new()
	ex.text = "Extrude"
	ex.custom_minimum_size = Vector2(72, CHIP_H)
	ex.pressed.connect(func() -> void:
		finish_requested.emit(["new", "cut", "fuse"][_finish_op.selected], _extrude_spin.value))
	_finish_bar.add_child(ex)
	var rv := Button.new()
	rv.text = "Revolve"
	rv.custom_minimum_size = Vector2(72, CHIP_H)
	rv.pressed.connect(func() -> void: action_chosen.emit("revolve"))
	_finish_bar.add_child(rv)


func dim_value() -> float:
	return _dim_spin.value if _dim_spin else 10.0


func set_dim_value(v: float) -> void:
	if _dim_spin:
		_dim_spin.value = v


func set_extrude_distance(v: float) -> void:
	if _extrude_spin:
		_extrude_spin.value = v


func extrude_button() -> Button:
	for c in _finish_bar.get_children():
		if c is Button and str(c.text) == "Extrude":
			return c as Button
	return null


func show_for_session(on: bool) -> void:
	_finish_bar.visible = on
	if on:
		# Sit to the right of the icon sketch rail, under the top chrome row.
		_place_bar(_finish_bar, Vector2(60, 42))
	else:
		_variant_bar.visible = false
		_action_bar.visible = false


func show_variants(kind: String, variants: Array, screen_pos: Vector2) -> void:
	_active_kind = kind
	_clear_bar(_variant_bar)
	for v in variants:
		var label: String = str(v)
		var b := Button.new()
		b.text = label.capitalize().replace("_", " ")
		b.custom_minimum_size = Vector2(0, CHIP_H)
		b.pressed.connect(func() -> void: variant_chosen.emit(kind, label))
		_variant_bar.add_child(b)
	_variant_bar.visible = not variants.is_empty()
	_place_bar(_variant_bar, screen_pos + Vector2(12, -CHIP_H - CHIP_PAD))


func hide_variants() -> void:
	_variant_bar.visible = false
	_active_kind = ""


func show_selection_actions(actions: Array, screen_pos: Vector2) -> void:
	_clear_bar(_action_bar)
	for a in actions:
		var label: String = str(a)
		var b := Button.new()
		b.text = label.capitalize().replace("_", " ")
		b.custom_minimum_size = Vector2(0, CHIP_H)
		b.pressed.connect(func() -> void: action_chosen.emit(label))
		_action_bar.add_child(b)
	_action_bar.visible = not actions.is_empty()
	_place_bar(_action_bar, screen_pos + Vector2(12, CHIP_PAD))


func hide_selection_actions() -> void:
	_action_bar.visible = false


## Merge-sketches option strip (2+ pads selected outside sketch mode).
func show_merge_menu(screen_pos: Vector2) -> void:
	show_selection_actions(
			["merge_join", "merge_spline", "merge_composite", "merge_clear"], screen_pos)


func _clear_bar(bar: HBoxContainer) -> void:
	while bar.get_child_count() > 0:
		var c := bar.get_child(0)
		bar.remove_child(c)
		c.queue_free()


func _place_bar(bar: Control, pos: Vector2) -> void:
	bar.reset_size()
	var sz := bar.get_combined_minimum_size()
	var vp := get_viewport_rect().size
	bar.position = Vector2(
		clampf(pos.x, 8, maxf(8, vp.x - sz.x - 8)),
		clampf(pos.y, 8, maxf(8, vp.y - sz.y - 8)))
