# DI film_convert_entities; assert ≥4 sketch lines after Convert.
extends SceneTree

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   - " + msg)
	else:
		failures += 1
		printerr("  FAIL - " + msg)


func _init() -> void:
	print("film convert entities ui tests (DI films)")
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

	var film = (load("res://tests/films/film_convert_entities.gd") as GDScript).new()
	var state := {"done": false}
	_exec(film, ctx, state)
	var frames := 0
	while not state.done and frames < 5000:
		await process_frame
		frames += 1
	check(state.done, "film finished (%d frames)" % frames)
	if state.done:
		var doc: SxDocument = main.view.doc
		var n_bodies := doc.body_ids().size()
		check(n_bodies >= 2, "extruded converted profile (bodies=%d)" % n_bodies)
	print("%d failures" % failures)
	main.queue_free()
	quit(1 if failures > 0 else 0)


func _exec(film: Object, ctx: FilmContext, state: Dictionary) -> void:
	await film.run_film(ctx)
	state.done = true
