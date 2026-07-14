# Headless tests for DocumentView display modes (shaded / edges / wireframe).
# Run: tools/godot/godot --headless --path game --script tests/run_display_tests.gd
extends SceneTree

var failures := 0
var checks := 0


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("display mode tests")
	var view := DocumentView.new()
	root.add_child(view)
	await process_frame
	await process_frame

	test_default_mode(view)
	test_mode_visibilities(view)
	test_cycle_wraps(view)
	test_wireframe_selection(view)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _edges_of(view: DocumentView, body_id: String) -> MeshInstance3D:
	var node := view.body_node(body_id)
	return node.get_node("Edges") as MeshInstance3D


func _surface_mat(view: DocumentView, body_id: String) -> Material:
	var node := view.body_node(body_id)
	return node.get_surface_override_material(0)


func test_default_mode(view: DocumentView) -> void:
	print("- default display mode")
	check(view.display_mode == DocumentView.DisplayMode.SHADED_EDGES, "default is SHADED_EDGES")


func test_mode_visibilities(view: DocumentView) -> void:
	print("- set_display_mode visibility")
	var a: String = view.insert_primitive("box", Vector3(0, 0, 0))
	var b: String = view.insert_primitive("box", Vector3(100, 0, 0))
	check(view.doc.body_ids().size() == 2, "two boxes in document")

	view.set_display_mode(DocumentView.DisplayMode.SHADED)
	check(view.display_mode == DocumentView.DisplayMode.SHADED, "mode is SHADED")
	for id in [a, b]:
		check(not _edges_of(view, id).visible, "SHADED hides edges for " + id.left(8))
		check(_surface_mat(view, id) != view._wireframe_hidden_material, "SHADED keeps body material for " + id.left(8))

	view.set_display_mode(DocumentView.DisplayMode.SHADED_EDGES)
	check(view.display_mode == DocumentView.DisplayMode.SHADED_EDGES, "mode is SHADED_EDGES")
	for id in [a, b]:
		check(_edges_of(view, id).visible, "SHADED_EDGES shows edges for " + id.left(8))
		check(_surface_mat(view, id) != view._wireframe_hidden_material, "SHADED_EDGES keeps body material for " + id.left(8))
		check(_edges_of(view, id).material_override == view._edge_material, "SHADED_EDGES uses edge material for " + id.left(8))

	view.set_display_mode(DocumentView.DisplayMode.WIREFRAME)
	check(view.display_mode == DocumentView.DisplayMode.WIREFRAME, "mode is WIREFRAME")
	for id in [a, b]:
		check(_edges_of(view, id).visible, "WIREFRAME shows edges for " + id.left(8))
		check(_surface_mat(view, id) == view._wireframe_hidden_material, "WIREFRAME hides body mesh for " + id.left(8))


func test_cycle_wraps(view: DocumentView) -> void:
	print("- cycle_display_mode")
	view.set_display_mode(DocumentView.DisplayMode.SHADED)
	check(view.cycle_display_mode() == DocumentView.DisplayMode.SHADED_EDGES, "cycle SHADED -> SHADED_EDGES")
	check(view.cycle_display_mode() == DocumentView.DisplayMode.WIREFRAME, "cycle SHADED_EDGES -> WIREFRAME")
	check(view.cycle_display_mode() == DocumentView.DisplayMode.SHADED, "cycle WIREFRAME -> SHADED")
	check(view.display_mode == DocumentView.DisplayMode.SHADED, "display_mode matches last cycle")


func test_wireframe_selection(view: DocumentView) -> void:
	print("- wireframe selection highlight")
	var ids: PackedStringArray = view.doc.body_ids()
	check(ids.size() == 2, "still two bodies")
	var a: String = ids[0]
	var b: String = ids[1]

	view.set_display_mode(DocumentView.DisplayMode.WIREFRAME)
	view.select_entity(a, "")
	check(view.selected_body == a, "body A selected")
	check(_edges_of(view, a).material_override == view._selected_edge_material, "selected body edges use selection color")
	check(_edges_of(view, b).material_override == view._edge_material, "unselected body edges stay dark")
	check(_surface_mat(view, a) == view._wireframe_hidden_material, "selected body mesh still hidden in wireframe")
	check(_surface_mat(view, b) == view._wireframe_hidden_material, "unselected body mesh still hidden in wireframe")

	# Selection highlight still works when returning to shaded modes.
	view.set_display_mode(DocumentView.DisplayMode.SHADED_EDGES)
	check(_surface_mat(view, a) == view._selected_body_material, "selected body tinted in SHADED_EDGES")
	check(_edges_of(view, a).visible, "edges visible again in SHADED_EDGES")
	check(_edges_of(view, a).material_override == view._edge_material, "edge tint cleared outside wireframe")
