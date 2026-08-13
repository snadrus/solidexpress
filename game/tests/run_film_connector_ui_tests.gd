# DI film_mate_connector_snap; assert a mate was created via connector snap.
extends SceneTree

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   - " + msg)
	else:
		failures += 1
		printerr("  FAIL - " + msg)


func _init() -> void:
	print("film connector snap ui tests (DI films)")
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
	var film = (load("res://tests/films/film_mate_connector_snap.gd") as GDScript).new()
	var state := {"done": false}
	_exec(film, ctx, state)
	var frames := 0
	while not state.done and frames < 5000:
		await process_frame
		frames += 1
	check(state.done, "film finished (%d frames)" % frames)
	if state.done:
		var doc: SxDocument = main.view.doc
		check(doc.list_connectors().size() >= 6, "implicit connectors listed")
		check(not doc.mate_list().is_empty(), "snap created a mate")
		var found := false
		for c in main.assembly_panel.find_children("*", "Button", true, false):
			if str((c as Button).text) == "Snap to connector":
				found = true
		check(found, "Snap to connector button present")
	print("%d failures" % failures)
	main.queue_free()
	quit(1 if failures > 0 else 0)


func _exec(film: Object, ctx: FilmContext, state: Dictionary) -> void:
	await film.run_film(ctx)
	state.done = true
