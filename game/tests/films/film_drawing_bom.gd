extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("BOM balloons match instance counts", 1.5)
	await FilmUI.place_primitive(ctx, "cylinder")
	await ctx.after_regen()
	var bodies: PackedStringArray = doc.body_ids()
	if bodies.size() > 0:
		ctx.view.select_entity(bodies[0], "")
		await FilmUI.click_button(ctx, "Place instance of selection")
		await FilmUI.click_button(ctx, "Place instance of selection")
	var n: int = doc.instance_list().size()
	await ctx.beat("BOM qty = %d instances of the seed" % n, 0.8)
	await ctx.camera.showcase_smooth(1.0, 22.0)
