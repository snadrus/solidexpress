extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## Film: block + fit spline (sketch parity blocks_and_spline).


func run_film(ctx: FilmContext) -> void:
	var main = ctx.main
	var sm: SketchMode = main.sketch_mode

	await ctx.beat("Enter sketch mode", 0.5)
	await FilmUI.enter_sketch(ctx)

	await ctx.beat("Create a line and save it as a block", 0.4)
	var a: String = sm.sketch.add_line(0, 0, 5, 0)
	sm._set_selected([a])
	sm.create_block("Blk1")
	sm.place_block("Blk1", Vector2(0, 10))
	await ctx.camera.showcase_smooth(0.8, 0.0)

	await ctx.beat("Fit a spline through successive clicks", 0.4)
	var sketch_pts := PackedVector2Array([
		Vector2(0, 20), Vector2(5, 25), Vector2(10, 20),
	])
	await FilmUI.draw_spline_through(ctx, sm, sketch_pts)
	await ctx.clock.wait_sec(ctx.tree, 0.5)

	await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	await ctx.beat("Spline densified to editable lines", 1.0)
	await ctx.camera.showcase_smooth(1.0, 32.0)
