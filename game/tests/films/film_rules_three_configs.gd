extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("If width > 100, suppress the rib — a rule, not a dock", 1.5)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var fid := FilmUI.last_feature_id(doc, "primitive")
	if fid != "":
		doc.graph_add_rib(fid, 2.0, 8.0, Vector3(9, 0, 4))
		await ctx.after_regen()
	doc.set_variable("width", "120")
	var n: int = doc.apply_rule("width > 100", "suppress rib")
	await ctx.beat("Rule fired %d time(s) — wide config drops the rib" % n, 0.8)
	await ctx.camera.showcase_smooth(0.8, 18.0)
