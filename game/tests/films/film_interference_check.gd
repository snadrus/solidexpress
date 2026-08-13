extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## Peer: SolidWorks Interference Detection — overlapping component instances.


func run_film(ctx: FilmContext) -> void:
	var view: DocumentView = ctx.view
	var doc: SxDocument = view.doc

	await ctx.movie_toast("Check Interference — overlapping instances", 1.6)

	await ctx.beat("Place a box", 0.4)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var bodies: Array = doc.body_ids()
	if bodies.is_empty():
		await ctx.beat("Place failed", 1.0)
		return
	var body: String = bodies[0]
	var top := FilmUI.find_face_by_normal(view, body, Vector3(0, 0, 1))
	await FilmUI.pick_body_face(ctx, body, top, "Select box")

	await ctx.beat("Place two instances at the same offset (overlap)", 0.5)
	if not await FilmUI.place_instance_of_selection(ctx):
		await ctx.beat("First instance failed", 1.0)
		return
	# Re-select source (place may change selection).
	await FilmUI.pick_body_face(ctx, body, top, "Select source again")
	if not await FilmUI.place_instance_of_selection(ctx):
		await ctx.beat("Second instance failed", 1.0)
		return
	await ctx.after_regen()
	if doc.instance_list().size() < 2:
		await ctx.beat("Need two instances", 1.0)
		return

	await ctx.beat("Check Interference", 0.5)
	var panel := FilmUI.assembly_panel(ctx)
	panel.refresh_lists()
	var btn := FilmUI.find_button(panel, "Check Interference")
	if not await FilmUI.click_control(ctx, btn, FilmUICues.alert("Check", "Check Interference")):
		await ctx.beat("Check Interference button missing", 1.0)
		return
	await FilmUI.wait_frames(ctx.tree, 3)

	var hits: Array = doc.check_interferences()
	if hits.is_empty():
		await ctx.beat("Expected a clash — none reported", 1.0)
		return
	var vol := 0.0
	for h in hits:
		vol += float(h.get("volume", 0.0))
	await ctx.beat("Clash found — ΣV ≈ %.1f mm³" % vol, 0.75)
	if ctx.camera != null:
		await ctx.camera.showcase_smooth(1.2, 35.0)
