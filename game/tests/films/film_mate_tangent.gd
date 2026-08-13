extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## Peer: SolidWorks Essential Training — Tangent mate (plane + cylinder).


func run_film(ctx: FilmContext) -> void:
	var view: DocumentView = ctx.view
	var doc: SxDocument = view.doc

	await ctx.movie_toast("Tangent mate — cylinder on a face", 1.7)

	await ctx.beat("Place a base box", 0.4)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var bodies: Array = doc.body_ids()
	if bodies.is_empty():
		await ctx.beat("Base failed", 1.0)
		return
	var base: String = bodies[0]

	await ctx.beat("Place a cylinder and instance it", 0.45)
	await FilmUI.place_primitive(ctx, "cylinder")
	await ctx.after_regen()
	bodies = doc.body_ids()
	if bodies.size() < 2:
		await ctx.beat("Cylinder place failed", 1.0)
		return
	var pin: String = bodies[bodies.size() - 1]
	# Prefer a side face for selection; fall back to any face.
	var pin_face := ""
	for fid in doc.get_face_ids(pin):
		var n: Vector3 = view.face_normal(pin, fid)
		if absf(n.normalized().dot(Vector3(0, 0, 1))) < 0.5:
			pin_face = fid
			break
	if pin_face.is_empty() and not doc.get_face_ids(pin).is_empty():
		pin_face = doc.get_face_ids(pin)[0]
	await FilmUI.pick_body_face(ctx, pin, pin_face, "Select cylinder")
	if not await FilmUI.place_instance_of_selection(ctx):
		await ctx.beat("Instance failed", 1.0)
		return
	await ctx.after_regen()

	var base_top := FilmUI.find_face_by_normal(view, base, Vector3(0, 0, 1))
	await ctx.beat("Add Tangent mate (plane ↔ cylinder)", 0.5)
	if not await FilmUI.add_mate_ui(ctx, "tangent", base, base_top, pin, pin_face):
		await ctx.beat("Tangent mate UI failed", 1.0)
		return
	await ctx.after_regen()

	var ok := false
	for m in doc.mate_list():
		if str(m.get("type", "")) == "tangent":
			ok = true
	if not ok:
		await ctx.beat("Tangent mate missing", 1.0)
		return
	await ctx.beat("Cylinder rests tangent on the base", 0.65)
	if ctx.camera != null:
		await ctx.camera.showcase_smooth(1.3, 40.0)
