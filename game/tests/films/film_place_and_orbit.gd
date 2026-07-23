extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## UI: arm Box from palette, place on ground, orbit the camera.


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc

	await ctx.movie_toast("Place a box and orbit the view", 1.4)

	await ctx.beat("Click Box in the Primitives palette", 0.4)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()

	var bodies: Array = doc.body_ids()
	if bodies.is_empty():
		await ctx.beat("Place failed — click ground to commit", 0.8)
		return

	await ctx.beat("Orbit to inspect the new solid", 0.35)
	await ctx.camera.orbit_smooth(55.0, 0.9)
	await ctx.beat("Box placed and selected — Alt-drag to orbit", 0.5)
	await ctx.camera.showcase_smooth(0.8, 18.0)
