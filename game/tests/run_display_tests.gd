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
	test_section_plane(view)

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


func test_section_plane(view: DocumentView) -> void:
	print("- section plane clipping")
	view.clear_selection()
	view.set_display_mode(DocumentView.DisplayMode.SHADED_EDGES)
	var ids: PackedStringArray = view.doc.body_ids()
	check(ids.size() == 2, "section test starts with two boxes")
	check(not view.section_enabled, "section disabled before set")

	view.set_section_plane(Vector3.ZERO, Vector3(1, 0, 0))
	check(view.section_enabled, "section_enabled after set_section_plane")
	for id in ids:
		var mat := _surface_mat(view, id)
		check(mat is ShaderMaterial, "section uses ShaderMaterial on " + id.left(8))
		if mat is ShaderMaterial:
			var sm := mat as ShaderMaterial
			check(
				sm.get_shader_parameter("section_normal").is_equal_approx(Vector3(1, 0, 0)),
				"section normal +X for " + id.left(8)
			)

	view.clear_section_plane()
	check(not view.section_enabled, "section_enabled false after clear")
	for id in ids:
		check(
			_surface_mat(view, id) is StandardMaterial3D,
			"clear restores StandardMaterial3D on " + id.left(8)
		)

	view.set_section_plane(Vector3.ZERO, Vector3(1, 0, 0))
	check(view.section_enabled, "section re-enabled")
	var c: String = view.insert_primitive("box", Vector3(200, 0, 0))
	check(c != "", "third box inserted while section active")
	check(_surface_mat(view, c) is ShaderMaterial, "new body gets section ShaderMaterial")
	for id in view.doc.body_ids():
		check(_surface_mat(view, id) is ShaderMaterial, "all bodies sectioned after rebuild " + id.left(8))

	# Display-mode cycling with section active must not error.
	view.cycle_display_mode()
	view.cycle_display_mode()
	view.cycle_display_mode()
	check(view.section_enabled, "section still enabled after display-mode cycles")
	for id in view.doc.body_ids():
		check(_surface_mat(view, id) is ShaderMaterial, "section material survives cycle on " + id.left(8))

	view.clear_section_plane()
	check(not view.section_enabled, "final clear disables section")
	for id in view.doc.body_ids():
		check(
			_surface_mat(view, id) is StandardMaterial3D,
			"final clear restores StandardMaterial3D on " + id.left(8)
		)
