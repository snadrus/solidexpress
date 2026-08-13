# DI film_explode_assembly; assert explode_active and offsets.
extends SceneTree

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   - " + msg)
	else:
		failures += 1
		printerr("  FAIL - " + msg)


func _init() -> void:
	print("film explode ui tests (DI films)")
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
	var film = (load("res://tests/films/film_explode_assembly.gd") as GDScript).new()
	var state := {"done": false}
	_exec(film, ctx, state)
	var frames := 0
	while not state.done and frames < 5000:
		await process_frame
		frames += 1
	check(state.done, "film finished (%d frames)" % frames)
	if state.done:
		var doc: SxDocument = main.view.doc
		check(doc.explode_active(), "explode active after film")
		var zsum := 0.0
		for inst in doc.instance_list():
			zsum += float(inst.get("explode_offset", Vector3.ZERO).z)
		check(zsum > 10.0, "explode offsets applied (ΣZ=%.1f)" % zsum)
	print("%d failures" % failures)
	main.queue_free()
	quit(1 if failures > 0 else 0)


func _exec(film: Object, ctx: FilmContext, state: Dictionary) -> void:
	await film.run_film(ctx)
	state.done = true
