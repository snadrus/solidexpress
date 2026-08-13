# DI film_rib_stiffener; assert a rib feature exists.
extends SceneTree

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   - " + msg)
	else:
		failures += 1
		printerr("  FAIL - " + msg)


func _init() -> void:
	print("film rib ui tests (DI films)")
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
	var film = (load("res://tests/films/film_rib_stiffener.gd") as GDScript).new()
	var state := {"done": false}
	_exec(film, ctx, state)
	var frames := 0
	while not state.done and frames < 5000:
		await process_frame
		frames += 1
	check(state.done, "film finished (%d frames)" % frames)
	if state.done:
		var has_rib := false
		for f in main.view.doc.graph_features():
			if str(f.get("type", "")) == "rib":
				has_rib = true
		check(has_rib, "rib feature on timeline")
	print("%d failures" % failures)
	main.queue_free()
	quit(1 if failures > 0 else 0)


func _exec(film: Object, ctx: FilmContext, state: Dictionary) -> void:
	await film.run_film(ctx)
	state.done = true
