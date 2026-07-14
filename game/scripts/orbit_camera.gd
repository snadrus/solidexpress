class_name OrbitCamera
extends Camera3D
## Turntable orbit camera: middle-drag orbits, shift+middle-drag pans,
## wheel zooms toward the pivot. F frames the scene contents;
## 1/2/3/7 jump to front/right/top/isometric standard views.

var pivot := Vector3.ZERO
var distance := 400.0
var yaw := deg_to_rad(-35.0)
var pitch := deg_to_rad(30.0)
## Set by main; used by frame_contents (F) to fit all bodies.
var view: DocumentView
var model_space: Node3D

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
		if not k.pressed or k.ctrl_pressed:
			return false
		match k.keycode:
			KEY_F:
				frame_contents()
				return true
			KEY_1:  # front: looking along -Y in model space (Z-up kernel)
				set_view(deg_to_rad(0.0), deg_to_rad(0.0))
				return true
			KEY_2:  # right: looking along -X
				set_view(deg_to_rad(90.0), deg_to_rad(0.0))
				return true
			KEY_3:  # top: looking down model +Z (world +Y)
				set_view(deg_to_rad(0.0), deg_to_rad(89.0))
				return true
			KEY_7:  # isometric
				set_view(deg_to_rad(-35.0), deg_to_rad(30.0))
				return true
	return false


func set_view(new_yaw: float, new_pitch: float) -> void:
	yaw = new_yaw
	pitch = clampf(new_pitch, MIN_PITCH, MAX_PITCH)
	_update_transform()


## Frames all bodies (world-space AABB union); origin fallback when empty.
func frame_contents() -> void:
	if view == null or view.doc.body_ids().is_empty():
		pivot = Vector3.ZERO
		distance = 400.0
		_update_transform()
		return
	var united := AABB()
	var first := true
	for id in view.doc.body_ids():
		var node := view.body_node(id)
		if node == null:
			continue
		var aabb := node.get_aabb()
		# Transform into world space through ModelSpace.
		var world_aabb: AABB = node.global_transform * aabb
		united = world_aabb if first else united.merge(world_aabb)
		first = false
	if first:
		return
	pivot = united.get_center()
	var radius: float = united.size.length() / 2.0
	distance = clampf(radius / tan(deg_to_rad(fov) / 2.0) * 1.2, MIN_DISTANCE, MAX_DISTANCE)
	_update_transform()


func _update_transform() -> void:
	var offset := Vector3(
		cos(pitch) * sin(yaw),
		sin(pitch),
		cos(pitch) * cos(yaw)
	) * distance
	global_position = pivot + offset
	look_at(pivot, Vector3.UP)
