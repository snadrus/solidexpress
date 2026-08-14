extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Chain a pocket — one variable fillet commit", 1.6)

	await ctx.beat("Place a block", 0.4)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var box_fid := FilmUI.last_feature_id(doc, "primitive")
	var body := ""
	for f in doc.graph_features():
		if str(f.get("id", "")) == box_fid:
			body = str(f.get("output_body", ""))
	var vol0 := doc.body_volume(body) if body != "" else 0.0
	ctx.view.select_entity(body, "")

	await ctx.beat("Fillet the chain with r1 / r2", 0.45)
	await FilmUI.click_button(ctx, "Fillet")
	if box_fid != "" and body != "":
		var edges: PackedStringArray = doc.get_edge_ids(body) if doc.has_method("get_edge_ids") else PackedStringArray()
		if edges.size() > 0:
			doc.graph_add_fillet_var(box_fid, PackedStringArray([edges[0]]), 2.0, 5.0)
			await ctx.after_regen()
	var vol1 := doc.body_volume(body) if body != "" else 0.0
	await ctx.beat("Variable fillet — volume %.0f → %.0f mm³" % [vol0, vol1], 0.8)
	await ctx.camera.showcase_smooth(1.2, 34.0)
