extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## Peer: SolidWorks Rib / Fusion web — open-profile stiffener on a face.


func run_film(ctx: FilmContext) -> void:
	var main = ctx.main
	var view: DocumentView = ctx.view
	var doc: SxDocument = view.doc

	await ctx.movie_toast("Rib stiffener — open line into the solid", 1.7)

	await ctx.beat("Place a box", 0.4)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var bodies: Array = doc.body_ids()
	if bodies.is_empty():
		await ctx.beat("Place failed", 1.0)
		return
	var body: String = bodies[0]
	var top := FilmUI.find_face_by_normal(view, body, Vector3(0, 0, 1))

	await ctx.beat("Sketch an open line on the top face", 0.45)
	await FilmUI.enter_sketch_on_face(ctx, body, top)
	var sm: SketchMode = main.sketch_mode
	await FilmUI.select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await FilmUI.click_sketch(ctx, sm, Vector2(-2, 0), "Rib line start")
	await FilmUI.click_sketch(ctx, sm, Vector2(2, 0), "Rib line end")
	# End line chain
	var screen := FilmUI.sketch_uv_to_screen(ctx, Vector2(2, 0))
	await FilmUI.viewport_click(ctx, screen, FilmUICues.alert("RMB", "End line chain"),
			false, MOUSE_BUTTON_RIGHT)

	await ctx.beat("Rib into the host", 0.5)
	var chrome: SketchContextChrome = main.sketch_chrome
	var rib_btn := FilmUI.find_button(chrome, "Rib")
	if not await FilmUI.click_control(ctx, rib_btn, FilmUICues.alert("Rib", "Create rib stiffener")):
		await ctx.beat("Rib button missing", 1.0)
		return
	await ctx.after_regen()

	var vol := doc.body_volume(body)
	var has_rib := false
	for f in doc.graph_features():
		if str(f.get("type", "")) == "rib":
			has_rib = true
	if not has_rib and vol <= 0.0:
		await ctx.beat("Rib failed", 1.0)
		return
	await ctx.beat("Rib fused — volume %.1f mm³" % vol, 0.7)
	if ctx.camera != null:
		await ctx.camera.showcase_smooth(1.3, 40.0)
