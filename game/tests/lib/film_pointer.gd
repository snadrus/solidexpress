class_name FilmPointer
extends Control

## Large yellow ring pointer for UI movies; flashes white on click.

const DIAM := 72.0
const RING := 7.0

var _flash := 0.0
var _flash_tween: Tween
var _moving := false


func set_moving(v: bool) -> void:
	_moving = v
	queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(DIAM, DIAM)
	size = Vector2(DIAM, DIAM)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := size * 0.5
	if _moving:
		draw_arc(center, DIAM * 0.5 + 10.0, 0, TAU, 64, Color(1.0, 0.88, 0.12, 0.28), 5.0, true)
	var ring_col := Color(1.0, 0.88, 0.12, 0.95).lerp(Color(1, 1, 1, 1), _flash)
	draw_arc(center, DIAM * 0.5 - RING * 0.5, 0, TAU, 72, ring_col, RING, true)
	draw_circle(center, 5.0, Color(1, 1, 1, 0.95))


func play_click_flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash, 0.0, 1.0, 0.07)
	_flash_tween.tween_method(_set_flash, 1.0, 0.0, 0.2)
	await _flash_tween.finished


func _set_flash(v: float) -> void:
	_flash = v
	queue_redraw()
