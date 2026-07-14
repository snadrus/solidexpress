# Headless tests for AssemblyPanel: instance list, place/remove, armed mate
# flow, mate delete, and solve. Panel is not in main.tscn — mounted here.
# Run: tools/godot/godot --headless --path game --script tests/run_assembly_tests.gd
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
	print("assembly panel tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	await test_place_and_remove(main)
	await test_armed_mate_flow(main)
	await test_mate_delete(main)
	await test_solve_button(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _mount_panel(main) -> AssemblyPanel:
	var panel := AssemblyPanel.new()
	panel.view = main.view
	main.add_child(panel)
	return panel


## Face of `body` whose bbox center matches a predicate; "" when none.
func _face_where(doc: SxDocument, body: String, pred: Callable) -> String:
	for fid in doc.get_face_ids(body):
		var bb: Dictionary = doc.measure_bbox(fid)
		if not bb.is_empty() and pred.call(bb):
			return fid
	return ""


func test_place_and_remove(main) -> void:
	print("- place instance shows panel; remove hides it")
	var view: DocumentView = main.view
	view.new_document()
	var panel := _mount_panel(main)
	await process_frame
	check(not panel.visible, "starts hidden (no instances)")

	var id: String = view.insert_primitive("box", Vector3.ZERO)
	check(id != "", "box inserted")
	view.select_entity(id, "")
	panel._place_instance()
	await process_frame

	check(view.doc.instance_list().size() == 1, "instance exists")
	check(panel.visible, "panel visible after place")
	check(panel._instances_list.get_child_count() == 1, "instance row present")

	var iid: String = view.doc.instance_list()[0]["id"]
	panel._remove_instance(iid)
	await process_frame
	check(view.doc.instance_list().is_empty(), "instance removed")
	check(not panel.visible, "panel hides after last instance removed")
	panel.queue_free()


func test_armed_mate_flow(main) -> void:
	print("- armed plane_coincident mate stacks instance on base")
	var view: DocumentView = main.view
	view.new_document()
	var doc: SxDocument = view.doc
	var panel := _mount_panel(main)
	await process_frame

	var base: String = doc.add_box(100, 100, 20, Vector3.ZERO)
	var block: String = doc.add_box(30, 30, 30, Vector3(200, 0, 0))
	var inst: String = doc.add_instance(block, Vector3(50, 50, 90), Vector3(0, 0, 1), 45.0, "Blk-1")
	check(inst != "", "instance placed")
	view.refresh()
	panel.refresh_lists()

	var base_top := _face_where(doc, base, func(bb): return absf(bb["min"].z - 20.0) < 1e-6 and absf(bb["max"].z - 20.0) < 1e-6)
	var block_bottom := _face_where(doc, block, func(bb): return absf(bb["min"].z) < 1e-6 and absf(bb["max"].z) < 1e-6)
	check(base_top != "", "base top face found")
	check(block_bottom != "", "block bottom face found")

	# Select plane_coincident and arm the two-click flow.
	for i in panel._type_option.item_count:
		if panel._type_option.get_item_text(i) == "plane_coincident":
			panel._type_option.select(i)
			break
	panel._arm_mate()
	check(panel.visible, "panel visible while armed")

	view.select_entity(base, base_top)
	view.select_entity(block, block_bottom)

	check(doc.mate_list().size() == 1, "mate exists in mate_list")
	var placed: Dictionary = doc.instance_list()[0]
	check(absf(placed["translation"].z - 20.0) < 1e-4,
		"instance dropped to base top (tz %.2f)" % placed["translation"].z)
	check(not panel._mate_armed, "mate flow disarmed after success")
	panel.queue_free()


func test_mate_delete(main) -> void:
	print("- mate row delete removes mate")
	var view: DocumentView = main.view
	view.new_document()
	var doc: SxDocument = view.doc
	var panel := _mount_panel(main)
	await process_frame

	var base: String = doc.add_box(100, 100, 20, Vector3.ZERO)
	var block: String = doc.add_box(30, 30, 30, Vector3(200, 0, 0))
	var inst: String = doc.add_instance(block, Vector3(50, 50, 90), Vector3(0, 0, 1), 0.0, "Blk-1")
	var base_top := _face_where(doc, base, func(bb): return absf(bb["min"].z - 20.0) < 1e-6 and absf(bb["max"].z - 20.0) < 1e-6)
	var block_bottom := _face_where(doc, block, func(bb): return absf(bb["min"].z) < 1e-6 and absf(bb["max"].z) < 1e-6)
	var mid: String = doc.add_mate("plane_coincident", "", base_top, inst, block_bottom, 0.0, false, "on base")
	check(mid != "", "mate seeded")
	view.refresh()
	panel.refresh_lists()
	check(panel._mates_list.get_child_count() == 1, "mate row present")

	panel._remove_mate(mid)
	await process_frame
	check(doc.mate_list().is_empty(), "mate removed from doc")
	check(panel._mates_list.get_child_count() == 0, "mate row gone")
	panel.queue_free()


func test_solve_button(main) -> void:
	print("- solve mates button emits status")
	var view: DocumentView = main.view
	view.new_document()
	var doc: SxDocument = view.doc
	var panel := _mount_panel(main)
	await process_frame

	var block: String = doc.add_box(30, 30, 30, Vector3.ZERO)
	doc.add_instance(block, Vector3(30, 0, 0), Vector3(0, 0, 1), 0.0, "Blk-1")
	view.refresh()
	panel.refresh_lists()

	var got_status := [false]
	panel.status.connect(func(_t: String) -> void: got_status[0] = true)
	panel._solve_mates()
	check(got_status[0], "status emitted")
	check(panel.visible, "panel still visible with instance")
	panel.queue_free()
