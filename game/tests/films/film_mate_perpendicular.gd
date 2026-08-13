extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## Peer: SolidWorks Essential Training — Perpendicular mate (Assembly Video 11).


func run_film(ctx: FilmContext) -> void:
	var view: DocumentView = ctx.view
	var doc: SxDocument = view.doc

	await ctx.movie_toast("Perpendicular mate — faces at 90°", 1.6)

	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var bodies: Array = doc.body_ids()
	if bodies.size() < 2:
		await ctx.beat("Need two boxes", 1.0)
		return
	var base: String = bodies[0]
	var block: String = bodies[bodies.size() - 1]
	var side := FilmUI.find_face_by_normal(view, block, Vector3(1, 0, 0))
	await FilmUI.pick_body_face(ctx, block, side, "Select block")
	if not await FilmUI.place_instance_of_selection(ctx):
		await ctx.beat("Instance failed", 1.0)
		return
	await ctx.after_regen()

	var base_top := FilmUI.find_face_by_normal(view, base, Vector3(0, 0, 1))
	# Prefer a side face that still exists after place; fall back to +Y.
	if side.is_empty():
		side = FilmUI.find_face_by_normal(view, block, Vector3(0, 1, 0))
	await ctx.beat("Add Perpendicular mate", 0.45)
	if not await FilmUI.add_mate_ui(ctx, "perpendicular", base, base_top, block, side):
		await ctx.beat("Perpendicular mate UI failed", 1.0)
		return
	await ctx.after_regen()

	var ok := false
	for m in doc.mate_list():
		if str(m.get("type", "")) == "perpendicular":
			ok = true
	if not ok:
		await ctx.beat("Perpendicular mate missing", 1.0)
		return
	await ctx.beat("Side face is perpendicular to the base", 0.6)
	if ctx.camera != null:
		await ctx.camera.showcase_smooth(1.2, 35.0)
