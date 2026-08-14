extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("A rib joins faces — volume grows, no extra dock", 1.5)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var fid := FilmUI.last_feature_id(doc, "primitive")
	var body := ""
	for f in doc.graph_features():
		if str(f.get("id", "")) == fid:
			body = str(f.get("output_body", ""))
	var v0 := 0.0
	if body != "":
		v0 = float(doc.measure_mass(body).get("volume", 0.0))
	if fid != "":
		doc.graph_add_rib(fid, 2.0, 8.0, Vector3(9, 0, 4))
		await ctx.after_regen()
	var v1 := v0
	if body != "":
		v1 = float(doc.measure_mass(body).get("volume", 0.0))
	await ctx.beat("Volume %.0f → %.0f mm³ — rib fused" % [v0, v1], 0.8)
	await ctx.camera.showcase_smooth(1.0, 24.0)
