class_name FilmCamera
extends RefCounted

const SHOWCASE_PITCH_DEG := -34.0

var _cam: OrbitCamera


func _init(camera: OrbitCamera) -> void:
	_cam = camera


func frame_all_smooth(duration: float = 1.0) -> void:
	await showcase_smooth(duration, 0.0)


func orbit_smooth(delta_yaw_deg: float, duration: float = 1.2) -> void:
	if _cam == null or not _cam.is_inside_tree():
		return
	var start_yaw := _cam.yaw
	var end_yaw := start_yaw + deg_to_rad(delta_yaw_deg)
	var tween := _cam.create_tween()
	tween.tween_method(
		func(t: float) -> void:
			_cam.yaw = lerpf(start_yaw, end_yaw, t)
			_cam._update_transform(),
		0.0, 1.0, duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


## Single end shot: fit, oblique pitch (not sketch top-down), optional orbit — avoids double jump.
func showcase_smooth(duration: float = 1.35, orbit_deg: float = 42.0) -> void:
	if _cam == null or not _cam.is_inside_tree():
		return
	if _cam.sketch_orientation_locked:
		_cam.sketch_orientation_locked = false
	var start_p := _cam.pivot
	var start_d := _cam.distance
	var start_pitch := _cam.pitch
	var start_yaw := _cam.yaw
	_cam.frame_contents()
	var end_p := _cam.pivot
	var end_d := _cam.distance
	var end_pitch := deg_to_rad(SHOWCASE_PITCH_DEG)
	var end_yaw := start_yaw + deg_to_rad(orbit_deg)
	_cam.pivot = start_p
	_cam.distance = start_d
	_cam.pitch = start_pitch
	_cam.yaw = start_yaw
	_cam._update_transform()
	if duration <= 0.0:
		_cam.pivot = end_p
		_cam.distance = end_d
		_cam.pitch = end_pitch
		_cam.yaw = end_yaw
		_cam._update_transform()
		return
	var tween := _cam.create_tween()
	tween.set_parallel(true)
	tween.tween_property(_cam, "pivot", end_p, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		func(t: float) -> void:
			_cam.distance = lerpf(start_d, end_d, t)
			_cam.pitch = lerpf(start_pitch, end_pitch, t)
			_cam.yaw = lerpf(start_yaw, end_yaw, t)
			_cam._update_transform(),
		0.0, 1.0, duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished