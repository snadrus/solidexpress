class_name OrbitCamera
extends Camera3D
## Turntable orbit camera: middle-drag orbits, shift+middle-drag pans,
## wheel zooms toward the pivot. F frames the origin.

var pivot := Vector3.ZERO
var distance := 400.0
var yaw := deg_to_rad(-35.0)
var pitch := deg_to_rad(30.0)

const MIN_DISTANCE := 5.0
const MAX_DISTANCE := 20000.0
const ORBIT_SPEED := 0.008
const MIN_PITCH := deg_to_rad(-89.0)
const MAX_PITCH := deg_to_rad(89.0)


func _ready() -> void:
	far = 100000.0
	_update_transform()


func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			distance = clampf(distance * 0.9, MIN_DISTANCE, MAX_DISTANCE)
			_update_transform()
			return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			distance = clampf(distance / 0.9, MIN_DISTANCE, MAX_DISTANCE)
			_update_transform()
			return true
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			if mm.shift_pressed:
				var pan_scale := distance * 0.0012
				pivot += global_transform.basis.x * (-mm.relative.x * pan_scale)
				pivot += global_transform.basis.y * (mm.relative.y * pan_scale)
			else:
				yaw -= mm.relative.x * ORBIT_SPEED
				pitch = clampf(pitch + mm.relative.y * ORBIT_SPEED, MIN_PITCH, MAX_PITCH)
			_update_transform()
			return true
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and k.keycode == KEY_F:
			pivot = Vector3.ZERO
			distance = 400.0
			_update_transform()
			return true
	return false


func _update_transform() -> void:
	var offset := Vector3(
		cos(pitch) * sin(yaw),
		sin(pitch),
		cos(pitch) * cos(yaw)
	) * distance
	global_position = pivot + offset
	look_at(pivot, Vector3.UP)
