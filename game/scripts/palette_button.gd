class_name PaletteButton
extends Button
## Palette entry that starts a drag carrying {"sx_primitive": kind}.
## Clicking (without dragging) arms click-to-place mode; drag still drops directly.

var kind := ""

signal insert_requested(kind: String)


func _init(p_kind: String, label: String) -> void:
	kind = p_kind
	text = ""
	icon = UIIcons.get_icon(p_kind, 20)
	tooltip_text = "Insert %s: drag into the scene, or click then place" % label.to_lower()
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	custom_minimum_size = Vector2(36, 36)


func _get_drag_data(_at: Vector2) -> Variant:
	var preview := Button.new()
	preview.icon = icon
	preview.custom_minimum_size = Vector2(36, 36)
	preview.modulate.a = 0.7
	set_drag_preview(preview)
	return {"sx_primitive": kind}


func _pressed() -> void:
	insert_requested.emit(kind)
