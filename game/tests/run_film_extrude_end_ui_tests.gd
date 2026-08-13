# DI film_extrude_through_all into a visual suite; assert volume drop + end param.
# Run: tools/godot/godot --headless --path game --script tests/run_film_extrude_end_ui_tests.gd
extends SceneTree

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   - " + msg)
	else:
		failures += 1
		printerr("  FAIL - " + msg)


func _init() -> void:
	print("film extrude end ui tests (DI films)")
	await _run_one("res://tests/films/film_extrude_through_all.gd")
	print("%d failures" % failures)
	quit(1 if failures > 0 else 0)


func _run_one(script_path: String) -> void:
	print("- DI %s" % script_path.get_file())
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
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
	check(film_script != null, "load film")
	var film: Object = film_script.new()
	var state := {"done": false}
	_exec(film, ctx, state)
	var frames := 0
	while not state.done and frames < 5000:
		await process_frame
		frames += 1
	check(state.done, "film finished (%d frames)" % frames)
	if state.done:
		var doc: SxDocument = main.view.doc
		check(not doc.body_ids().is_empty(), "body remains after cut")
		if not doc.body_ids().is_empty():
			var vol := doc.body_volume(doc.body_ids()[0])
			# Default box ~5³=125; through hole should remove measurable volume.
			check(vol > 1.0 and vol < 124.0, "volume reduced by through hole (vol=%.2f)" % vol)
		var chrome: SketchContextChrome = main.sketch_chrome
		check(chrome != null and chrome.has_method("extrude_end"), "chrome exposes extrude_end")
	main.queue_free()
	await process_frame


func _exec(film: Object, ctx: FilmContext, state: Dictionary) -> void:
	await film.run_film(ctx)
	state.done = true
