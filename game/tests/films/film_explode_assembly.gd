extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## Peer: SolidWorks / Fusion exploded view toggle.


func run_film(ctx: FilmContext) -> void:
	var view: DocumentView = ctx.view
	var doc: SxDocument = view.doc

	await ctx.movie_toast("Exploded view — offset instances along +Z", 1.6)

	await ctx.beat("Place a box and two instances", 0.45)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var bodies: Array = doc.body_ids()
	if bodies.is_empty():
		await ctx.beat("Place failed", 1.0)
		return
	var body: String = bodies[0]
	var top := FilmUI.find_face_by_normal(view, body, Vector3(0, 0, 1))
	await FilmUI.pick_body_face(ctx, body, top, "Select box")
	if not await FilmUI.place_instance_of_selection(ctx):
		await ctx.beat("Instance 1 failed", 1.0)
		return
	await FilmUI.pick_body_face(ctx, body, top, "Select again")
	if not await FilmUI.place_instance_of_selection(ctx):
		await ctx.beat("Instance 2 failed", 1.0)
		return
	await ctx.after_regen()
	if doc.instance_list().size() < 2:
		await ctx.beat("Need two instances", 1.0)
		return

	await ctx.beat("Explode the assembly", 0.5)
	var panel := FilmUI.assembly_panel(ctx)
	panel.refresh_lists()
	var btn := FilmUI.find_button(panel, "Explode")
	if not await FilmUI.click_control(ctx, btn, FilmUICues.alert("Explode", "Toggle exploded view")):
		await ctx.beat("Explode button missing", 1.0)
		return
	await FilmUI.wait_frames(ctx.tree, 3)
	if not doc.explode_active():
		await ctx.beat("Explode did not activate", 1.0)
		return
	var zsum := 0.0
	for inst in doc.instance_list():
		zsum += float(inst.get("explode_offset", Vector3.ZERO).z)
	if zsum < 1.0:
		await ctx.beat("Explode offsets missing", 1.0)
		return

	await ctx.beat("Exploded — Σ offset Z ≈ %.0f mm" % zsum, 0.7)
	if ctx.camera != null:
		await ctx.camera.showcase_smooth(1.3, 45.0)
