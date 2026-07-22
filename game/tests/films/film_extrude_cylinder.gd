extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## UI: circle sketch, smart dim rescale, extrude to solid cylinder.


func run_film(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode

	await ctx.beat("Enter sketch and choose the circle tool", 0.5)
	await FilmUI.enter_sketch(ctx)
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(8, 0))
	await ctx.beat("Rescale the diameter with a smart dimension", 0.35)
	await FilmUI.set_sketch_dim(ctx, 16.0)
	await ctx.beat("Extrude the profile into a cylinder", 0.4)
	await FilmUI.apply_extrude(ctx, 25.0)
	await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	await ctx.beat("Extruded solid cylinder", 0.6)
	await ctx.camera.showcase_smooth(1.4, 38.0)
