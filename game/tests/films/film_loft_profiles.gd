extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## UI: two circular profile pads (ground + box top face) → ruled loft solid.


func run_film(ctx: FilmContext) -> void:
	var main = ctx.main
	var doc: SxDocument = ctx.view.doc
	var sm: SketchMode = main.sketch_mode

	await ctx.movie_toast("Loft two circular profiles into a solid", 1.8)

	await ctx.beat("Sketch a large circle on the ground plane", 0.5)
	await FilmUI.enter_sketch(ctx)
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(10, 0))
	var fid_a := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	if fid_a.is_empty():
		await ctx.beat("Bottom profile failed", 1.0)
		return

	await ctx.beat("Place a box, then sketch a smaller circle on its top face", 0.55)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var bodies: Array = doc.body_ids()
	if bodies.is_empty():
		await ctx.beat("Place box failed", 1.0)
		return
	var body: String = bodies[bodies.size() - 1]
	var top_face := FilmUI.find_face_by_normal(ctx.view, body, Vector3(0, 0, 1))
	if top_face.is_empty():
		await ctx.beat("Top face not found", 1.0)
		return
	await FilmUI.enter_sketch_on_face(ctx, body, top_face)
	sm = main.sketch_mode
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(2, 0))
	var fid_b := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	if fid_b.is_empty():
		await ctx.beat("Top profile failed", 1.0)
		return

	await ctx.beat("Hide the box, then Ctrl+click both yellow pads", 0.5)
	await FilmUI.clear_pad_selection(ctx)
	var hide_btn := FilmUI.find_button(main, "Hide")
	if hide_btn != null and hide_btn.is_visible_in_tree():
		await FilmUI.click_control(ctx, hide_btn, FilmUICues.alert("Hide", "Hide solid to reach pads"))
	elif not doc.body_ids().is_empty():
		var host: String = doc.body_ids()[doc.body_ids().size() - 1]
		var face := FilmUI.find_face_by_normal(ctx.view, host, Vector3(0, 0, 1))
		if face != "":
			await FilmUI.viewport_click(ctx, FilmUI.model_to_screen(ctx,
					FilmUI.face_pick_point(ctx.view, host, face)),
					FilmUICues.alert("Click", "Select solid"))
			hide_btn = FilmUI.find_button(main, "Hide")
			if hide_btn != null:
				await FilmUI.click_control(ctx, hide_btn,
						FilmUICues.alert("Hide", "Hide solid to reach pads"))
	await FilmUI.select_sketch_pad_ctrl(ctx, fid_a)
	await FilmUI.select_sketch_pad_ctrl(ctx, fid_b)

	await ctx.beat("Loft the profiles (ruled surfaces)", 0.55)
	await FilmUI.loft_profiles_ui(ctx, true)
	await ctx.after_regen()

	var loft_fid := FilmUI.last_feature_id(doc, "loft")
	var vol := 0.0
	for f in doc.graph_features():
		if str(f.get("id", "")) == loft_fid:
			var out_body := str(f.get("output_body", ""))
			if out_body != "":
				vol = doc.body_volume(out_body)
	if loft_fid.is_empty() or vol <= 0.0:
		await ctx.beat("Loft failed — need closed profiles on separate planes", 1.0)
		return

	await ctx.beat("Ruled loft solid — %.0f mm³" % vol, 0.7)
	await ctx.camera.showcase_smooth(1.4, 40.0)
