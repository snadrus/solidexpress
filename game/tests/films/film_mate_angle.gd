extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## Peer: SolidWorks Essential Training — Angle mate (Assembly Video 10).


func run_film(ctx: FilmContext) -> void:
	var view: DocumentView = ctx.view
	var doc: SxDocument = view.doc

	await ctx.movie_toast("Angle mate — 45° between faces", 1.7)

	await ctx.beat("Place base and block, then instance the block", 0.45)
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
	var top := FilmUI.find_face_by_normal(view, block, Vector3(0, 0, 1))
	await FilmUI.pick_body_face(ctx, block, top, "Select block")
	if not await FilmUI.place_instance_of_selection(ctx):
		await ctx.beat("Instance failed", 1.0)
		return
	await ctx.after_regen()

	var base_top := FilmUI.find_face_by_normal(view, base, Vector3(0, 0, 1))
	var block_top := FilmUI.find_face_by_normal(view, block, Vector3(0, 0, 1))
	await ctx.beat("Add Angle mate at 45°", 0.5)
	if not await FilmUI.add_mate_ui(ctx, "angle", base, base_top, block, block_top, 45.0):
		await ctx.beat("Angle mate UI failed", 1.0)
		return
	await ctx.after_regen()

	var ok := false
	for m in doc.mate_list():
		if str(m.get("type", "")) == "angle":
			ok = true
	if not ok:
		await ctx.beat("Angle mate missing", 1.0)
		return
	await ctx.beat("Faces meet at 45°", 0.65)
	if ctx.camera != null:
		await ctx.camera.showcase_smooth(1.3, 35.0)
