# Visual tests: DI each assembly-mate film (same script as sx-movies) and assert
# postconditions. Run:
#   tools/godot/godot --headless --path game --script tests/run_film_mate_ui_tests.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   - " + msg)
	else:
		failures += 1
		printerr("  FAIL - " + msg)


func _init() -> void:
	print("film mate ui tests (DI films)")
	await _run_film("res://tests/films/film_mate_distance.gd", _assert_distance)
	await _run_film("res://tests/films/film_mate_angle.gd", _assert_angle)
	await _run_film("res://tests/films/film_mate_perpendicular.gd", _assert_perpendicular)
	await _run_film("res://tests/films/film_mate_tangent.gd", _assert_tangent)
	print("%d failures" % failures)
	quit(1 if failures > 0 else 0)


func _run_film(script_path: String, assert_fn: Callable) -> void:
	print("- DI %s" % script_path.get_file())
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.camera = FilmCamera.new(main.camera)
	ctx.clock = FilmClock.new()
	ctx.tree = self

	main.view.new_document()

	var film_script: GDScript = load(script_path) as GDScript
	check(film_script != null, "%s loads" % script_path.get_file())
	if film_script == null:
		main.queue_free()
		await process_frame
		return
	var film: Object = film_script.new()
	check(film.has_method("run_film"), "%s has run_film" % script_path.get_file())

	var state := {"done": false}
	_exec(film, ctx, state)
	var frames := 0
	var budget := 4000
	while not state.done and frames < budget:
		await process_frame
		frames += 1
	check(state.done, "%s finished (%d frames)" % [script_path.get_file(), frames])
	if state.done:
		assert_fn.call(main.view.doc, main)
	main.queue_free()
	await process_frame


func _exec(film: Object, ctx: FilmContext, state: Dictionary) -> void:
	await film.run_film(ctx)
	state.done = true


func _assert_distance(doc: SxDocument, main) -> void:
	var panel: AssemblyPanel = main.assembly_panel
	check(panel != null and panel.visible, "assembly panel visible after distance film")
	var has := false
	for m in doc.mate_list():
		if str(m.get("type", "")) == "distance" and absf(float(m.get("offset", -1))) > 9.0:
			has = true
	check(has, "distance mate with ~10 mm offset present")
	check(not doc.instance_list().is_empty(), "instance exists after distance mate")
	# MateType list must expose distance for discoverability.
	var found_type := false
	for i in panel._type_option.item_count:
		if panel._type_option.get_item_text(i) == "distance":
			found_type = true
	check(found_type, "MateType lists distance")


func _assert_angle(doc: SxDocument, _main) -> void:
	var has := false
	for m in doc.mate_list():
		if str(m.get("type", "")) == "angle" and absf(float(m.get("offset", 0.0)) - 45.0) < 1e-3:
			has = true
	check(has, "angle mate at 45° present")


func _assert_perpendicular(doc: SxDocument, _main) -> void:
	var has := false
	for m in doc.mate_list():
		if str(m.get("type", "")) == "perpendicular":
			has = true
	check(has, "perpendicular mate present")


func _assert_tangent(doc: SxDocument, _main) -> void:
	var has := false
	for m in doc.mate_list():
		if str(m.get("type", "")) == "tangent":
			has = true
	check(has, "tangent mate present")
