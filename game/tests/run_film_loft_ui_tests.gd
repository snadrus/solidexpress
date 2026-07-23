# Loft UI path smoke: ground circle + box-top circle via real clicks → ruled loft.
# Run: tools/godot/godot --headless --path game --script tests/run_film_loft_ui_tests.gd
extends SceneTree

const FilmUI = preload("res://tests/lib/film_ui.gd")

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   - " + msg)
	else:
		failures += 1
		printerr("  FAIL - " + msg)


func _init() -> void:
	print("film loft ui tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	ctx.clock = FilmClock.new()

	var sm: SketchMode = main.sketch_mode
	main.view.new_document()
	var doc: SxDocument = main.view.doc

	await FilmUI.enter_sketch(ctx)
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(10, 0))
	var fid_a := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	check(not fid_a.is_empty(), "bottom profile pad")

	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var bodies: Array = doc.body_ids()
	check(not bodies.is_empty(), "box placed for top host face")
	var body: String = "" if bodies.is_empty() else bodies[bodies.size() - 1]
	var top_face := FilmUI.find_face_by_normal(main.view, body, Vector3(0, 0, 1))
	check(top_face != "", "top face on box")
	await FilmUI.enter_sketch_on_face(ctx, body, top_face)
	sm = main.sketch_mode
	await FilmUI.draw_circle(ctx, sm, Vector2(0, 0), Vector2(2, 0))
	var fid_b := await FilmUI.exit_sketch(ctx)
	await ctx.after_regen()
	check(not fid_b.is_empty(), "top profile pad")

	await FilmUI.clear_pad_selection(ctx)
	# Hide the host solid so face-pad and ground-pad aren't stacked under the mesh.
	if not bodies.is_empty():
		var host: String = bodies[bodies.size() - 1]
		var any_face := FilmUI.find_face_by_normal(main.view, host, Vector3(0, 0, 1))
		if any_face != "":
			await FilmUI.viewport_click(ctx, FilmUI.model_to_screen(ctx,
					FilmUI.face_pick_point(main.view, host, any_face)),
					{"keys": "Click", "desc": "Select solid to hide"})
		var hide_btn := FilmUI.find_button(main, "Hide")
		if hide_btn != null and hide_btn.is_visible_in_tree():
			await FilmUI.click_control(ctx, hide_btn, {"keys": "Hide", "desc": "Hide solid to reach pads"})
	await FilmUI.select_sketch_pad_ctrl(ctx, fid_a)
	await FilmUI.select_sketch_pad_ctrl(ctx, fid_b)
	check(main.selected_sketch_pads.size() >= 2, "two pads selected")

	await FilmUI.loft_profiles_ui(ctx, true)
	await ctx.after_regen()

	var loft_fid := FilmUI.last_feature_id(doc, "loft")
	check(loft_fid != "", "loft feature from UI")
	var loft_body := ""
	for f in doc.graph_features():
		if str(f.get("id", "")) == loft_fid:
			loft_body = str(f.get("output_body", ""))
	check(loft_body != "", "loft output body")
	if loft_body != "":
		check(doc.body_volume(loft_body) > 10.0, "loft volume plausible")

	print("%d failures" % failures)
	quit(1 if failures > 0 else 0)
