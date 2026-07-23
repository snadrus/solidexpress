extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## UI: two open rail pads on the ground → merge path → profile → sweep.


func run_film(ctx: FilmContext) -> void:
	var main = ctx.main
	var doc: SxDocument = ctx.view.doc
	var sm: SketchMode = main.sketch_mode

	await ctx.beat("Draw a spline rail on the ground plane", 0.55)
	await FilmUI.enter_sketch(ctx)
	var rail := PackedVector2Array([
		Vector2(0, 0), Vector2(5, 2), Vector2(10, 4), Vector2(15, 2), Vector2(20, 0),
	])
	await FilmUI.draw_spline_through(ctx, sm, rail)
	var fid_a := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	if fid_a.is_empty():
		await ctx.beat("Rail sketch failed", 1.0)
		return

	await ctx.beat("Sketch a second open leg that meets the rail end", 0.55)
	await FilmUI.enter_sketch(ctx)
	await FilmUI.draw_line(ctx, sm, Vector2(20, 0), Vector2(20, 15))
	var fid_b := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	if fid_b.is_empty():
		await ctx.beat("Leg sketch failed", 1.0)
		return

	await ctx.beat("Ctrl+click both sketch pads to multi-select", 0.5)
	await FilmUI.clear_pad_selection(ctx)
	await FilmUI.select_sketch_pad_ctrl(ctx, fid_a)
	await FilmUI.select_sketch_pad_ctrl(ctx, fid_b)

	await ctx.beat("Merge pads into one path (join endpoints)", 0.55)
	await FilmUI.merge_sketches_ui(ctx, "join_endpoints")
	await ctx.after_regen()
	var path_fid := FilmUI.last_feature_id(doc, "path")
	if path_fid.is_empty():
		await ctx.beat("Path merge failed", 1.0)
		return

	await ctx.beat("Draw a circle profile for the sweep", 0.5)
	await FilmUI.enter_sketch(ctx)
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(2, 0))
	await FilmUI.set_sketch_dim(ctx, 4.0)
	var prof_fid := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	if prof_fid.is_empty():
		await ctx.beat("Profile sketch failed", 1.0)
		return

	await ctx.beat("Ctrl+click the profile pad, then Sweep along path", 0.5)
	await FilmUI.clear_pad_selection(ctx)
	await FilmUI.select_sketch_pad_ctrl(ctx, prof_fid)
	await FilmUI.sweep_along_path_ui(ctx)
	await ctx.after_regen()

	var sw := FilmUI.last_feature_id(doc, "sweep")
	var vol := 0.0
	for f in doc.graph_features():
		if str(f.get("id", "")) == sw:
			var body := str(f.get("output_body", ""))
			if body != "":
				vol = doc.body_volume(body)
	await ctx.beat("Solid path sweep — %.0f mm³" % vol, 0.8)
	await ctx.camera.showcase_smooth(1.5, 48.0)
