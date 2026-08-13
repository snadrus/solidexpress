extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## Peer: SolidWorks Convert Entities — project face edges into a sketch.


func run_film(ctx: FilmContext) -> void:
	var main = ctx.main
	var view: DocumentView = ctx.view
	var doc: SxDocument = view.doc

	await ctx.movie_toast("Convert Entities — face edges → sketch", 1.7)

	await ctx.beat("Place a box", 0.4)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var bodies: Array = doc.body_ids()
	if bodies.is_empty():
		await ctx.beat("Place failed", 1.0)
		return
	var body: String = bodies[0]
	var top := FilmUI.find_face_by_normal(view, body, Vector3(0, 0, 1))

	await ctx.beat("Sketch on the top face", 0.45)
	await FilmUI.enter_sketch_on_face(ctx, body, top)
	var sm: SketchMode = main.sketch_mode

	await ctx.beat("Convert Entities (project face edges)", 0.5)
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.CONVERT)
	# Tool.CONVERT converts on click — click once in the sketch.
	await FilmUI.click_sketch(ctx, sm, Vector2(0, 0), "Convert Entities")
	await ctx.after_regen()

	var n_lines := 0
	for id in sm.sketch.entity_ids():
		var info: Dictionary = sm.sketch.entity_info(id)
		if str(info.get("type", "")) == "line":
			n_lines += 1
	if n_lines < 4:
		await ctx.beat("Convert produced %d lines (want ≥4)" % n_lines, 1.0)
		return

	await ctx.beat("Four edges converted — extrude the profile", 0.55)
	await FilmUI.apply_extrude(ctx, 8.0, "new", "blind")
	await ctx.after_regen()

	await ctx.beat("Converted rectangle extruded", 0.65)
	if ctx.camera != null:
		await ctx.camera.showcase_smooth(1.2, 40.0)
