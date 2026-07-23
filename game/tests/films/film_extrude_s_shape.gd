extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## UI: closed S-channel profile from howto/extrude-s-shape.md → extrude 10 mm.


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	var sm: SketchMode = ctx.main.sketch_mode

	await ctx.movie_toast("Extrude a closed S-shaped profile", 1.8)

	await ctx.beat("Draw the closed S outline with the line tool", 0.55)
	await FilmUI.enter_sketch(ctx)
	var pts := PackedVector2Array([
		Vector2(0, 0), Vector2(20, 0), Vector2(20, 15), Vector2(5, 15),
		Vector2(5, 25), Vector2(20, 25), Vector2(20, 40), Vector2(0, 40),
		Vector2(0, 25), Vector2(15, 25), Vector2(15, 15), Vector2(0, 15),
		Vector2(0, 0),
	])
	await FilmUI.draw_polyline(ctx, sm, pts)
	await ctx.beat("Extrude the closed profile 10 mm", 0.45)
	await FilmUI.apply_extrude(ctx, 10.0)
	await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()

	var ex_fid := FilmUI.last_feature_id(doc, "extrude")
	var vol := 0.0
	for f in doc.graph_features():
		if str(f.get("id", "")) == ex_fid:
			var body := str(f.get("output_body", ""))
			if body != "":
				vol = doc.body_volume(body)
	if vol <= 0.0:
		await ctx.beat("Extrude failed — profile must be closed", 1.0)
		return

	await ctx.beat("S-channel solid — %.0f mm³" % vol, 0.7)
	await ctx.camera.showcase_smooth(1.3, 36.0)
