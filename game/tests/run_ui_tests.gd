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
