extends RefCounted

const FilmUI = preload("res://tests/lib/film_ui.gd")

## Peer: Onshape mate connectors / Fusion magnetic joint snap (Assembly Video 12).


func run_film(ctx: FilmContext) -> void:
	var view: DocumentView = ctx.view
	var doc: SxDocument = view.doc

	await ctx.movie_toast("Mate connector snap — instance → ground face", 1.7)

	await ctx.beat("Place a base box", 0.4)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	var bodies: Array = doc.body_ids()
	if bodies.is_empty():
		await ctx.beat("Place failed", 1.0)
		return
	var base: String = bodies[0]

	await ctx.beat("Place a second box and instance it (floating)", 0.45)
	await FilmUI.place_primitive(ctx, "box")
	await ctx.after_regen()
	bodies = doc.body_ids()
	if bodies.size() < 2:
		await ctx.beat("Second box failed", 1.0)
		return
	var block: String = bodies[bodies.size() - 1]
	var top := FilmUI.find_face_by_normal(view, block, Vector3(0, 0, 1))
	await FilmUI.pick_body_face(ctx, block, top, "Select block")
	if not await FilmUI.place_instance_of_selection(ctx):
		await ctx.beat("Instance failed", 1.0)
		return
	await ctx.after_regen()
	if doc.instance_list().is_empty():
		await ctx.beat("No instance", 1.0)
		return

	var cons: Array = doc.list_connectors()
	if cons.size() < 6:
		await ctx.beat("Expected implicit connectors (got %d)" % cons.size(), 1.0)
		return

	await ctx.beat("Snap instance to nearest mate connector", 0.55)
	var panel := FilmUI.assembly_panel(ctx)
	panel.refresh_lists()
	# Highlight the instance via its AssemblyPanel select button (user path).
	var sel_btn: Button = null
	for row in panel._instances_list.get_children():
		for c in row.get_children():
			if c is Button and str((c as Button).tooltip_text).findn("Highlight") >= 0:
				sel_btn = c as Button
				break
		if sel_btn != null:
			break
	if sel_btn != null:
		await FilmUI.click_control(ctx, sel_btn,
				FilmUICues.alert("Select", "Highlight instance for snap"))
	var snap_btn := FilmUI.find_button(panel, "Snap to connector")
	if not await FilmUI.click_control(ctx, snap_btn,
			FilmUICues.alert("Snap", "Snap to nearest mate connector")):
		await ctx.beat("Snap button missing", 1.0)
		return
	await FilmUI.wait_frames(ctx.tree, 4)

	if doc.mate_list().is_empty():
		await ctx.beat("Snap did not create a mate", 1.0)
		return
	await ctx.beat("Connector snap seated the instance", 0.7)
	if ctx.camera != null:
		await ctx.camera.showcase_smooth(1.3, 40.0)
