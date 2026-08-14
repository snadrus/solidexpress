extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Crank-slider — analytic slider position", 1.5)
	await ctx.beat("Crank 20 mm, rod 80 mm, θ = 0 → x = 100 mm", 0.5)
	var x0: float = doc.crank_slider_x(20.0, 80.0, 0.0)
	var x90: float = doc.crank_slider_x(20.0, 80.0, PI / 2.0)
	await ctx.beat("x(0)=%.1f  x(90°)=%.1f" % [x0, x90], 0.8)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.camera.showcase_smooth(1.0, 24.0)
