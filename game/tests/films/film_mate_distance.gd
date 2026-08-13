extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## Peer: SolidWorks Essential Training / CSWP — Distance mate between two faces
## (Assembly Video 9). Place base + block, instance the block, Distance=10 mm.


func run_film(ctx: FilmContext) -> void:
	var main = ctx.main
	var view: DocumentView = ctx.view
	var doc: SxDocument = view.doc

	await ctx.movie_toast("Distance mate — 10 mm gap (SolidWorks standard mate)", 1.8)

	await ctx.beat("Place a base box on the ground", 0.45)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var bodies: Array = doc.body_ids()
	if bodies.is_empty():
		await ctx.beat("Base place failed", 1.0)
		return
	var base: String = bodies[0]

	await ctx.beat("Place a second box, then instance it", 0.5)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	bodies = doc.body_ids()
	if bodies.size() < 2:
		await ctx.beat("Second box place failed", 1.0)
		return
	var block: String = bodies[bodies.size() - 1]

	# Select the block body via a face click so Place instance sees selection.
	var block_any := FilmUI.find_face_by_normal(view, block, Vector3(0, 0, 1))
	if block_any.is_empty():
		await ctx.beat("Block face missing", 1.0)
		return
	await FilmUI.pick_body_face(ctx, block, block_any, "Select block to instance")
	if not await FilmUI.place_instance_of_selection(ctx):
		await ctx.beat("Place instance failed", 1.0)
		return
	await ctx.after_regen()
	if doc.instance_list().is_empty():
		await ctx.beat("No instance created", 1.0)
		return

	# Mate base top ↔ block top (opposed normals). Bottom-face picks are
	# unreliable under the orbit camera; opposing tops is the usual SW demo.
	var base_top := FilmUI.find_face_by_normal(view, base, Vector3(0, 0, 1))
	var block_top := FilmUI.find_face_by_normal(view, block, Vector3(0, 0, 1))
	if base_top.is_empty() or block_top.is_empty():
		await ctx.beat("Mate faces not found", 1.0)
		return

	await ctx.beat("Add Distance mate with Offset 10 mm", 0.55)
	if not await FilmUI.add_mate_ui(ctx, "distance", base, base_top, block, block_top, 10.0):
		await ctx.beat("Distance mate UI failed", 1.0)
		return
	await ctx.after_regen()

	var mates: Array = doc.mate_list()
	var found := false
	for m in mates:
		if str(m.get("type", "")) == "distance" and absf(float(m.get("offset", 0.0)) - 10.0) < 1e-6:
			found = true
			break
	if not found:
		await ctx.beat("Distance mate missing from list", 1.0)
		return

	var tz := float(doc.instance_list()[0]["translation"].z)
	await ctx.beat("Instance seated with 10 mm gap (tz≈%.1f)" % tz, 0.7)
	if ctx.camera != null:
		await ctx.camera.showcase_smooth(1.4, 40.0)
