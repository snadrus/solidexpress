extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## UI: spline rail + vertical leg (drawn in sketch), pad merge, profile circle, sweep.


static func _ensure_path(doc: SxDocument, main, fid_a: String, fid_b: String) -> String:
	var path_fid := FilmUI.last_feature_id(doc, "path")
	if path_fid != "":
		return path_fid
	if main.has_method("_merge_selected_sketches"):
		main._merge_selected_sketches("join_endpoints")
		path_fid = FilmUI.last_feature_id(doc, "path")
	if path_fid != "":
		return path_fid
	return doc.graph_add_path(PackedStringArray([fid_a, fid_b]), "join_endpoints")


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

	await ctx.beat("Sketch a vertical leg on a plane at the rail end", 0.55)
	await FilmUI.enter_sketch_on_plane(
		ctx, Vector3(20, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
	await FilmUI.draw_line(ctx, sm, Vector2(0, 0), Vector2(0, 30))
	var fid_b := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	if fid_b.is_empty():
		await ctx.beat("Leg sketch failed", 1.0)
		return

	await ctx.beat("Ctrl+click both sketch pads to multi-select", 0.5)
	FilmUI.clear_pad_selection(ctx)
	await FilmUI.select_sketch_pad_ctrl(ctx, fid_a)
	await FilmUI.select_sketch_pad_ctrl(ctx, fid_b)
	if main.sketch_chrome != null:
		main.sketch_chrome.visible = true

	await ctx.beat("Merge pads into one path (join endpoints)", 0.55)
	await FilmUI.merge_sketches_ui(ctx, "join_endpoints")
	var path_fid := _ensure_path(doc, main, fid_a, fid_b)
	await ctx.after_regen()
	if path_fid.is_empty():
		await ctx.beat("Path merge failed", 1.0)
		return

	await ctx.beat("Draw a circle profile for the sweep", 0.5)
	await FilmUI.enter_sketch(ctx)
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(2, 0))
	await FilmUI.set_sketch_dim(ctx, 4.0)
	var prof_fid := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()

	await ctx.beat("Sweep the profile along the merged path", 0.5)
	var sw: String = doc.graph_add_sweep_along_path(prof_fid, path_fid)
	await ctx.after_regen()

	var vol := 0.0
	for f in doc.graph_features():
		if str(f.get("id", "")) == sw:
			var body := str(f.get("output_body", ""))
			if body != "":
				vol = doc.body_volume(body)
	await ctx.beat("Solid L-path sweep — %.0f mm³" % vol, 0.8)
	await ctx.camera.showcase_smooth(1.5, 48.0)
