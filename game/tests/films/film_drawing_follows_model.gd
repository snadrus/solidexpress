extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")


func run_film(ctx: FilmContext) -> void:
	var doc: SxDocument = ctx.view.doc
	await ctx.movie_toast("Drawing dim follows a parameter edit", 1.5)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var fid := FilmUI.last_feature_id(doc, "primitive")
	var body := ""
	for f in doc.graph_features():
		if str(f.get("id", "")) == fid:
			body = str(f.get("output_body", ""))
	var w0 := 0.0
	if body != "":
		var bb: Dictionary = doc.measure_bbox(body)
		w0 = (bb["max"] as Vector3).x - (bb["min"] as Vector3).x
	if fid != "":
		var p := {"kind": "box", "a": 55.0, "b": 50.0, "c": 50.0}
		for f in doc.graph_features():
			if str(f.get("id", "")) == fid:
				var parsed: Variant = JSON.parse_string(str(f.get("params", "{}")))
				if parsed is Dictionary:
					p = parsed
					p["a"] = 55.0
		doc.graph_set_params(fid, JSON.stringify(p))
		await ctx.after_regen()
	var w1 := w0
	if body != "":
		var bb2: Dictionary = doc.measure_bbox(body)
		w1 = (bb2["max"] as Vector3).x - (bb2["min"] as Vector3).x
	await ctx.beat("Associative width %.1f → %.1f mm" % [w0, w1], 0.8)
	await ctx.camera.showcase_smooth(1.0, 24.0)
