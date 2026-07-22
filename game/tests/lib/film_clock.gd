class_name FilmClock
extends RefCounted


func wait_sec(tree: SceneTree, sec: float) -> void:
	if sec <= 0.0:
		await tree.process_frame
		return
	await tree.create_timer(sec).timeout
