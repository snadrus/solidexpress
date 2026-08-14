class_name DrawingSheet
extends Control
## Draw mode: the sheet *is* the viewport. Title-block fields live on the paper,
## not in a properties dock. Hidden in Model (layout suite stays green).

var title := "SOLIDEXPRESS"
var scale_text := "1:1"


func _ready() -> void:
	name = "DrawingSheet"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 80
	offset_top = 48
	offset_right = -80
	offset_bottom = -48


func show_sheet(on: bool) -> void:
	visible = on
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.93, 0.93, 0.90, 0.92))
	draw_rect(r.grow(-8), Color(0.15, 0.15, 0.16), false, 1.5)
	var block := Rect2(r.size.x - 220, r.size.y - 56, 204, 40)
	draw_rect(block, Color(0.98, 0.98, 0.96))
	draw_rect(block, Color(0.2, 0.2, 0.22), false, 1.0)
	draw_string(ThemeDB.fallback_font, block.position + Vector2(8, 16), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.1, 0.1, 0.12))
	draw_string(ThemeDB.fallback_font, block.position + Vector2(8, 34), "SCALE " + scale_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.25, 0.25, 0.28))
