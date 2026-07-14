# Headless integration tests for the sxcore GDExtension.
# Run: tools/godot/godot --headless --path game --script tests/run_tests.gd
# Exits 0 if all tests pass, 1 otherwise.
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
	print("sxcore integration tests")
	test_document_lifecycle()
	test_mesh()
	test_pick()
	test_push_pull()
	test_cards()
	test_save_load()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_document_lifecycle() -> void:
	print("- document lifecycle")
	var doc := SxDocument.new()
	var box_id: String = doc.add_box(10, 10, 10, Vector3.ZERO)
	check(box_id.length() == 36, "add_box returns uuid")
	check(doc.body_ids().size() == 1, "one body present")
	check(abs(doc.body_volume(box_id) - 1000.0) < 1e-6, "box volume is 1000")

	check(doc.undo(), "undo works")
	check(doc.body_ids().size() == 0, "body gone after undo")
	check(doc.redo(), "redo works")
	check(doc.body_ids().size() == 1, "body back after redo")
	check(doc.body_ids()[0] == box_id, "same uuid after redo")

	check(doc.delete_body(box_id), "delete works")
	check(doc.body_ids().size() == 0, "empty after delete")


func test_mesh() -> void:
	print("- tessellation to ArrayMesh")
	var doc := SxDocument.new()
	var box_id: String = doc.add_box(10, 10, 10, Vector3.ZERO)
	var mesh: ArrayMesh = doc.get_mesh(box_id)
	check(mesh != null, "mesh returned")
	check(mesh.get_surface_count() == 6, "box mesh has 6 surfaces (one per face)")
	var face_ids: PackedStringArray = doc.get_face_ids(box_id)
	check(face_ids.size() == 6, "6 face ids")
	var edges: Dictionary = doc.get_edge_lines(box_id)
	check(edges.size() == 12, "12 edge polylines")

	var cyl_id: String = doc.add_cylinder(5, 10, Vector3(50, 0, 0))
	var cyl_mesh: ArrayMesh = doc.get_mesh(cyl_id)
	check(cyl_mesh.get_surface_count() == 3, "cylinder mesh has 3 surfaces")


func test_pick() -> void:
	print("- exact picking")
	var doc := SxDocument.new()
	var box_id: String = doc.add_box(10, 10, 10, Vector3.ZERO)
	var hit: Dictionary = doc.pick(Vector3(5, 5, 100), Vector3(0, 0, -1))
	check(not hit.is_empty(), "ray hits box")
	check(hit["body"] == box_id, "hit reports correct body")
	check(doc.get_face_ids(box_id).has(hit["face"]), "hit face id is a known face")
	check(abs(hit["point"].z - 10.0) < 1e-4, "hit point on top face")

	var miss: Dictionary = doc.pick(Vector3(5, 5, 100), Vector3(0, 0, 1))
	check(miss.is_empty(), "ray pointing away misses")


func test_push_pull() -> void:
	print("- push/pull")
	var doc := SxDocument.new()
	var box_id: String = doc.add_box(10, 10, 10, Vector3.ZERO)
	var hit: Dictionary = doc.pick(Vector3(5, 5, 100), Vector3(0, 0, -1))
	check(doc.push_pull(hit["face"], 5.0), "pull top face by 5")
	check(abs(doc.body_volume(box_id) - 1500.0) < 1e-4, "volume 1500 after pull")
	check(doc.undo(), "undo pull")
	check(abs(doc.body_volume(box_id) - 1000.0) < 1e-4, "volume back to 1000")


func test_cards() -> void:
	print("- semantic cards")
	var doc := SxDocument.new()
	var box_id: String = doc.add_box(10, 10, 10, Vector3.ZERO)
	var md: String = doc.card_markdown(box_id)
	check(md.contains("- uuid: " + box_id), "body card has uuid")
	check(md.contains("## Digest"), "body card has digest")

	var face_id: String = doc.get_face_ids(box_id)[0]
	doc.set_card_alias(face_id, "the front face")
	check(doc.card_markdown(face_id).contains("the front face"), "alias stored in card")


func test_save_load() -> void:
	print("- save/load .sxp")
	var path := "/tmp/sx_godot_test.sxp"
	var doc := SxDocument.new()
	var box_id: String = doc.add_box(10, 20, 30, Vector3.ZERO)
	doc.set_card_alias(box_id, "the housing")
	check(doc.save(path), "save succeeds")

	var doc2 := SxDocument.new()
	check(doc2.load(path), "load succeeds")
	check(doc2.body_ids().size() == 1, "one body loaded")
	check(doc2.body_ids()[0] == box_id, "uuid preserved")
	check(abs(doc2.body_volume(box_id) - 6000.0) < 1e-4, "volume preserved")
	check(doc2.card_markdown(box_id).contains("the housing"), "card alias preserved")
	DirAccess.remove_absolute(path)
