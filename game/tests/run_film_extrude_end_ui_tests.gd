# DI through-all + to-face extrude films; assert geometry outcomes.
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
	await _run_through_all()
	await _run_to_face()
	print("%d failures" % failures)
	quit(1 if failures > 0 else 0)


func _run_through_all() -> void:
	print("- DI film_extrude_through_all.gd")
	var main = await _boot()
	var ctx := _ctx(main)
	await _run_film(ctx, "res://tests/films/film_extrude_through_all.gd")
	var doc: SxDocument = main.view.doc
	check(not doc.body_ids().is_empty(), "through_all: body remains")
	if not doc.body_ids().is_empty():
		var vol := doc.body_volume(doc.body_ids()[0])
		check(vol > 1.0 and vol < 124.0, "through_all: volume reduced (vol=%.2f)" % vol)
	check(main.sketch_chrome != null and main.sketch_chrome.has_method("extrude_end"),
		"chrome exposes extrude_end")
	main.queue_free()
	await process_frame


func _run_to_face() -> void:
	print("- DI film_extrude_to_face.gd")
	var main = await _boot()
	var ctx := _ctx(main)
	await _run_film(ctx, "res://tests/films/film_extrude_to_face.gd")
	var doc: SxDocument = main.view.doc
	var has_to_face := false
	var boss_vol := 0.0
	for f in doc.graph_features():
		if str(f.get("type", "")) != "extrude":
			continue
		var end := _param_end(f.get("params", null))
		if end == "to_face":
			has_to_face = true
			var out_body := str(f.get("output_body", ""))
			if out_body != "":
				boss_vol = doc.body_volume(out_body)
	check(has_to_face, "to_face: extrude feature present")
	check(boss_vol > 1.0, "to_face: boss volume > 0 (%.2f)" % boss_vol)
	# Box height ~5 mm; r=8 → V ≈ π·64·5 ≈ 1005 (not blind 999 mm tall).
	check(boss_vol < 5000.0, "to_face: boss height bounded (%.2f)" % boss_vol)


func _param_end(p: Variant) -> String:
	if typeof(p) == TYPE_DICTIONARY:
		return str(p.get("end", ""))
	if typeof(p) == TYPE_STRING:
		var parsed: Variant = JSON.parse_string(str(p))
		if typeof(parsed) == TYPE_DICTIONARY:
			return str(parsed.get("end", ""))
	return ""
	main.queue_free()
	await process_frame


func _boot():
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.view.new_document()
	return main


func _ctx(main) -> FilmContext:
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.camera = FilmCamera.new(main.camera)
	ctx.clock = FilmClock.new()
	ctx.tree = self
	return ctx


func _run_film(ctx: FilmContext, script_path: String) -> void:
	var film_script: GDScript = load(script_path) as GDScript
	check(film_script != null, "load %s" % script_path.get_file())
	var film: Object = film_script.new()
	var state := {"done": false}
	_exec(film, ctx, state)
	var frames := 0
	while not state.done and frames < 5000:
		await process_frame
		frames += 1
	check(state.done, "%s finished (%d frames)" % [script_path.get_file(), frames])


func _exec(film: Object, ctx: FilmContext, state: Dictionary) -> void:
	await film.run_film(ctx)
	state.done = true
