extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## Peer: SolidWorks / Fusion — Extrude To Face / To Object.


func run_film(ctx: FilmContext) -> void:
	var main = ctx.main
	var view: DocumentView = ctx.view
	var doc: SxDocument = view.doc

	await ctx.movie_toast("Extrude To Face — boss stops at a face", 1.7)

	await ctx.beat("Place a box (the stopping face)", 0.4)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var bodies: Array = doc.body_ids()
	if bodies.is_empty():
		await ctx.beat("Place failed", 1.0)
		return
	var body: String = bodies[0]
	var top := FilmUI.find_face_by_normal(view, body, Vector3(0, 0, 1))
	if top.is_empty():
		await ctx.beat("Top face missing", 1.0)
		return

	await ctx.beat("Sketch a circle on the ground under the box", 0.5)
	await FilmUI.enter_sketch(ctx)
	var sm: SketchMode = main.sketch_mode
	# Ground UV ≈ model XY; center the circle under the box footprint.
	var bb: Dictionary = doc.measure_bbox(body) if doc.has_method("measure_bbox") else {}
	var cx := 0.0
	var cy := 0.0
	if not bb.is_empty():
		var mn: Vector3 = bb["min"]
		var mx: Vector3 = bb["max"]
		cx = (mn.x + mx.x) * 0.5
		cy = (mn.y + mx.y) * 0.5
	# Keep radius outside snap pull-to-center (see film_extrude_cylinder).
	await FilmUI.draw_circle(ctx, sm, Vector2(cx, cy), Vector2(cx + 8.0, cy))

	await ctx.beat("Extrude New → To Face (pick box top)", 0.55)
	await FilmUI.apply_extrude(ctx, 999.0, "new", "to_face", body, top)
	await ctx.after_regen()

	var boss_vol := 0.0
	var has_to_face := false
	for f in doc.graph_features():
		if str(f.get("type", "")) != "extrude":
			continue
		var end := ""
		var p: Variant = f.get("params", null)
		if typeof(p) == TYPE_DICTIONARY:
			end = str(p.get("end", ""))
		elif typeof(p) == TYPE_STRING:
			var parsed: Variant = JSON.parse_string(str(p))
			if typeof(parsed) == TYPE_DICTIONARY:
				end = str(parsed.get("end", ""))
		if end == "to_face":
			has_to_face = true
			var out_body := str(f.get("output_body", ""))
			if out_body != "":
				boss_vol = doc.body_volume(out_body)
	if not has_to_face:
		await ctx.beat("To Face extrude missing on timeline", 1.0)
		return
	if boss_vol <= 0.0:
		await ctx.beat("To Face boss has no volume", 1.0)
		return

	await ctx.beat("Boss stopped at face — %.1f mm³" % boss_vol, 0.7)
	if ctx.camera != null:
		await ctx.camera.showcase_smooth(1.3, 45.0)
