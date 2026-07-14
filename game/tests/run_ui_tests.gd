# Headless tests for the Phase 1 drag-and-drop shell (scene + view-model).
# Run: tools/godot/godot --headless --path game --script tests/run_ui_tests.gd
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
	print("phase 1 shell tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	# Let _ready run.
	await process_frame
	await process_frame

	test_scene_structure(main)
	test_insert_and_render(main)
	test_selection_and_cards(main)
	test_move(main)
	test_push_pull(main)
	test_undo_wiring(main)
	test_sketch_mode(main)
	await test_timeline(main)
	test_ops_panel(main)
	test_sketch_constraints(main)
	test_revolve_and_cut(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_scene_structure(main) -> void:
	print("- scene structure")
	check(main.camera is Camera3D, "camera exists")
	check(main.view is DocumentView, "document view exists")
	check(main.interaction is Control, "interaction overlay exists")
	var up: Vector3 = main.model_space.basis * Vector3(0, 0, 1)
	check(up.distance_to(Vector3(0, 1, 0)) < 0.01, "model space maps kernel +Z to world +Y")
	check(main.get_node("UI/Palette") != null, "palette panel exists")
	check(main.get_node("UI/CardPanel") != null, "card panel exists")


func test_insert_and_render(main) -> void:
	print("- insert primitives via palette path")
	var view: DocumentView = main.view
	var id: String = view.insert_primitive("box", Vector3(0, 0, 0))
	check(id.length() == 36, "insert box returns uuid")
	var id2: String = view.insert_primitive("cylinder", Vector3(100, 0, 0))
	check(id2.length() == 36, "insert cylinder returns uuid")
	check(view.doc.body_ids().size() == 2, "two bodies in document")
	var node := view.body_node(id)
	check(node != null and node.mesh != null, "box has a mesh node")
	check(node.mesh.get_surface_count() == 6, "box mesh has 6 face surfaces")
	check(view.selected_body == id2, "last inserted body is selected")


func test_selection_and_cards(main) -> void:
	print("- selection and semantic cards")
	var view: DocumentView = main.view
	var box_id: String = view.doc.body_ids()[0]
	# Ray straight down onto the box (model space, kernel Z-up).
	var hit := view.select_ray(Vector3(0, 0, 500), Vector3(0, 0, -1))
	check(hit, "ray selects box body")
	check(view.selected_body == box_id, "correct body selected")
	check(view.selected_face == "", "first click selects body, not face")
	view.select_ray(Vector3(0, 0, 500), Vector3(0, 0, -1))
	check(view.selected_face != "", "second click drills into face")
	var card := view.selection_card()
	check(card.contains("## Digest"), "card panel shows face digest")
	check(card.contains("planar"), "face card describes planar face")
	var n := view.selected_face_normal()
	check(n.distance_to(Vector3(0, 0, 1)) < 0.01, "top face normal is +Z (model space)")
	view.set_selection_alias("the lid face")
	check(view.selection_card().contains("the lid face"), "alias round-trips")


func test_move(main) -> void:
	print("- move body")
	var view: DocumentView = main.view
	var box_id: String = view.doc.body_ids()[0]
	view.select_entity(box_id, "")
	var vol0: float = view.doc.body_volume(box_id)
	check(view.move_selected(Vector3(30, 0, 0)), "move accepted")
	check(absf(view.doc.body_volume(box_id) - vol0) < 1e-6, "volume unchanged by move")
	var hit: Dictionary = view.pick_info(Vector3(30, 0, 500), Vector3(0, 0, -1))
	check(not hit.is_empty() and hit["body"] == box_id, "body pickable at new location")


func test_push_pull(main) -> void:
	print("- push/pull via view-model")
	var view: DocumentView = main.view
	var box_id: String = view.doc.body_ids()[0]
	var vol0: float = view.doc.body_volume(box_id)
	# Select top face (two clicks) then pull 10.
	view.clear_selection()
	view.select_ray(Vector3(30, 0, 500), Vector3(0, 0, -1))
	view.select_ray(Vector3(30, 0, 500), Vector3(0, 0, -1))
	check(view.selected_face != "", "top face selected")
	check(view.push_pull_selected(10.0), "push/pull applies")
	var vol1: float = view.doc.body_volume(box_id)
	check(vol1 > vol0 + 1.0, "volume grew after pull (%.0f -> %.0f)" % [vol0, vol1])
	check(view.selected_body == box_id, "body stays selected after push/pull")


func test_undo_wiring(main) -> void:
	print("- undo/redo wiring")
	var view: DocumentView = main.view
	var count0: int = view.doc.body_ids().size()
	view.insert_primitive("sphere", Vector3(200, 200, 0))
	check(view.doc.body_ids().size() == count0 + 1, "sphere added")
	check(view.undo(), "undo")
	check(view.doc.body_ids().size() == count0, "sphere gone after undo")
	check(view.redo(), "redo")
	check(view.doc.body_ids().size() == count0 + 1, "sphere back after redo")
	# View nodes track the document (refresh is synchronous).
	var live := 0
	for id in view.doc.body_ids():
		if view.body_node(id) != null:
			live += 1
	check(live == view.doc.body_ids().size(), "scene nodes exist for all bodies")


func test_timeline(main) -> void:
	print("- timeline panel")
	var view: DocumentView = main.view
	var tl: TimelinePanel = main.timeline
	check(tl != null, "timeline panel exists")

	tl.refresh()
	await process_frame
	var feats: Array = view.doc.graph_features()
	check(feats.size() > 0, "timeline has features")
	check(tl._rows.size() == feats.size(), "one row per feature")

	# Find a primitive feature and edit its params through the panel.
	var prim: Dictionary = {}
	for f in feats:
		if f["type"] == "primitive" and not f["suppressed"]:
			prim = f
			break
	check(not prim.is_empty(), "found a primitive feature")
	var body: String = prim["output_body"]
	var vol0: float = view.doc.body_volume(body)
	tl._select_feature(prim["id"])
	check(tl._editor_box.visible, "param editor opens on select")
	check(view.selected_body == body, "selecting feature selects its body")
	var params: Dictionary = JSON.parse_string(tl._params_edit.text)
	params["a"] = float(params["a"]) * 2.0
	tl._params_edit.text = JSON.stringify(params)
	tl._apply_params()
	var vol1: float = view.doc.body_volume(body)
	check(vol1 > vol0 * 1.5, "param edit grew the body (%.0f -> %.0f)" % [vol0, vol1])

	# Suppress removes the body from the scene; undo brings the edit back.
	tl._set_suppressed(prim["id"], true)
	check(view.doc.body_volume(body) == 0.0, "suppressed body gone")
	check(view.undo(), "undo suppress")
	check(absf(view.doc.body_volume(body) - vol1) < 1e-6, "body back after undo")
	check(view.undo(), "undo param edit")
	check(absf(view.doc.body_volume(body) - vol0) < 1e-6, "original size after second undo")


func test_sketch_constraints(main) -> void:
	print("- sketch select tool + constraints")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()

	# Rough quadrilateral, roughly axis-aligned.
	sm.set_tool(SketchMode.Tool.LINE)
	sm.click(Vector2(0, 0)); sm.click(Vector2(52, 3))
	sm.click(Vector2(51, 32)); sm.click(Vector2(-2, 29))
	sm.click(Vector2(0, 0))
	sm.end_chain()
	check(sm.sketch.entity_ids().size() == 4, "four lines drawn")

	# Select the bottom line, make it horizontal, dimension it to 50.
	sm.set_tool(SketchMode.Tool.SELECT)
	sm.click(Vector2(25, 1))
	check(sm.selected.size() == 1, "bottom line selected")
	check(sm.measured_value() > 40.0, "measured length pre-filled")
	check(sm.constrain("horizontal") == "success", "horizontal solves")
	check(sm.constrain("distance", 50.0) == "success", "length dim solves")
	var info: Dictionary = sm.sketch.entity_info(sm.selected[0])
	check(absf(info["start"].y - info["end"].y) < 1e-6, "line is horizontal")
	check(absf((info["end"] - info["start"]).length() - 50.0) < 1e-6, "line is 50 long")

	# Select two adjacent lines, apply perpendicular.
	sm.click(Vector2(51, 16))
	check(sm.selected.size() == 2, "two lines selected")
	check(sm.constrain("perpendicular") == "success", "perpendicular solves")

	# Empty click clears the selection; constraint without selection is a no-op.
	sm.click(Vector2(500, 500))
	check(sm.selected.is_empty(), "empty click clears selection")
	check(sm.constrain("horizontal") == "", "constrain with no selection is no-op")
	sm.cancel()


func test_revolve_and_cut(main) -> void:
	print("- revolve and extrude-cut via sketch finish")
	var view: DocumentView = main.view
	var sm: SketchMode = main.sketch_mode

	# Revolve: 20x20 rectangle centered at x=40, around the sketch Y axis.
	view.clear_selection()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.RECT)
	sm.click(Vector2(30, 0))
	sm.click(Vector2(50, 20))
	var count0: int = view.doc.body_ids().size()
	sm.finish_revolve(TAU, "new")
	check(view.doc.body_ids().size() == count0 + 1, "revolve created a body")
	var ring: String = view.selected_body
	# Pappus: V = 2*pi*R_centroid*A = 2*pi*40*400.
	check(absf(view.doc.body_volume(ring) - TAU * 40.0 * 400.0) < 300.0,
		"revolved volume matches Pappus")
	view.delete_selected()

	# Extrude-cut: sketch a circle on a box top face, cut 20 deep.
	var box: String = view.insert_primitive("box", Vector3(800, 800, 0))
	var vol0: float = view.doc.body_volume(box)
	view.select_entity(box, "")
	view.select_ray(Vector3(800, 800, 500), Vector3(0, 0, -1))
	check(view.selected_face != "", "top face selected for sketch")
	main._start_sketch()
	check(sm.target_fid != "", "cut target feature recorded")
	sm.set_tool(SketchMode.Tool.CIRCLE)
	sm.click(Vector2(0, 0))
	sm.click(Vector2(10, 0))
	sm.finish_extrude(20.0, "cut")
	var vol1: float = view.doc.body_volume(box)
	check(absf((vol0 - vol1) - PI * 100.0 * 20.0) < 50.0,
		"cut removed a 10x20 cylinder (%.0f removed)" % (vol0 - vol1))
	check(view.doc.body_ids().size() == count0 + 1, "cut did not add a body")

	# The cut is parametric: deepen it via the timeline params.
	var cut_fid := ""
	for f in view.doc.graph_features():
		if f["type"] == "extrude":
			cut_fid = f["id"]
	check(cut_fid != "", "cut feature on timeline")
	var params: Dictionary = {}
	for f in view.doc.graph_features():
		if f["id"] == cut_fid:
			params = JSON.parse_string(f["params"])
	params["distance"] = -40.0
	check(view.doc.graph_set_params(cut_fid, JSON.stringify(params)), "deepen cut")
	var vol2: float = view.doc.body_volume(box)
	check(vol1 - vol2 > PI * 100.0 * 15.0, "cut got deeper")


func test_ops_panel(main) -> void:
	print("- ops panel")
	var view: DocumentView = main.view
	var ops: OpsPanel = main.ops_panel
	check(ops != null, "ops panel exists")

	view.clear_selection()
	check(not ops.visible, "hidden with no selection")

	var a: String = view.insert_primitive("box", Vector3(400, 400, 0))
	check(ops.visible and ops._body_ops.visible, "body ops shown on body selection")

	# Fillet all edges shrinks volume.
	var vol0: float = view.doc.body_volume(a)
	ops._radius_spin.value = 2.0
	ops._fillet_all()
	check(view.doc.body_volume(a) < vol0, "fillet-all removed material")
	view.doc.undo()

	# Linear pattern makes count-1 copies.
	var bodies0: int = view.doc.body_ids().size()
	view.select_entity(a, "")
	ops._pattern_count.value = 3
	ops._pattern_spacing.value = 80.0
	ops._linear_pattern()
	check(view.doc.body_ids().size() == bodies0 + 2, "linear pattern added 2 copies")
	view.doc.undo()
	view.refresh()

	# Shell: select the top face (body already selected, so one click refines
	# to the face), open it, wall 2mm.
	view.select_entity(a, "")
	view.select_ray(Vector3(400, 400, 500), Vector3(0, 0, -1))
	check(view.selected_face != "" and ops._face_ops.visible, "face ops shown on face selection")
	var vol1: float = view.doc.body_volume(a)
	ops._thickness_spin.value = 2.0
	ops._shell()
	check(view.doc.body_volume(a) < vol1 * 0.6, "shell hollowed the body")

	# Measure between two bodies via the armed two-click flow.
	var b: String = view.insert_primitive("box", Vector3(600, 400, 0))
	view.select_entity(a, "")
	ops._arm_measure()
	view.select_entity(b, "")
	check(ops._pending == OpsPanel.Pending.NONE, "measure pending resolved")

	# Boolean fuse via armed flow: select a, arm fuse, click b.
	var bodies1: int = view.doc.body_ids().size()
	view.select_entity(a, "")
	ops._arm_boolean("fuse")
	view.select_entity(b, "")
	check(view.doc.body_ids().size() == bodies1 - 1, "fuse consumed tool body")
	view.doc.undo()
	view.refresh()


func test_sketch_mode(main) -> void:
	print("- sketch mode: rect on ground plane, extrude")
	var view: DocumentView = main.view
	var sm: SketchMode = main.sketch_mode
	var count0: int = view.doc.body_ids().size()

	view.clear_selection()
	main._start_sketch()
	check(sm.active, "sketch mode active")
	check(main.sketch_toolbar.visible, "sketch toolbar shown")

	# Draw a 60x40 rectangle with the rect tool via direct 2D clicks.
	sm.set_tool(SketchMode.Tool.RECT)
	sm.click(Vector2(200, 200))
	sm.hover(Vector2(260, 240))
	sm.click(Vector2(260, 240))
	check(sm.sketch.entity_ids().size() == 4, "rect tool created 4 lines")

	sm.finish_extrude(25.0)
	check(not sm.active, "sketch mode exits on finish")
	check(view.doc.body_ids().size() == count0 + 1, "extruded body added")
	var new_body: String = view.selected_body
	check(new_body != "", "new body selected")
	check(absf(view.doc.body_volume(new_body) - 60.0 * 40.0 * 25.0) < 1e-3,
		"extruded volume 60*40*25")

	# Ray through the middle of the new pad must hit it.
	var hit: Dictionary = view.pick_info(Vector3(230, 220, 500), Vector3(0, 0, -1))
	check(not hit.is_empty() and hit["body"] == new_body, "pad pickable from above")

	# Cancel path: start a sketch, draw, cancel; nothing added.
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.CIRCLE)
	sm.click(Vector2(0, 0))
	sm.click(Vector2(10, 0))
	check(sm.sketch.entity_ids().size() == 1, "circle drawn")
	sm.cancel()
	check(not sm.active, "cancel exits sketch mode")
	check(view.doc.body_ids().size() == count0 + 1, "cancel adds nothing")
