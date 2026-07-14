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
	test_modeling_ops()
	test_interop()
	test_feature_graph()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_modeling_ops() -> void:
	print("- booleans, fillet, chamfer")
	var doc := SxDocument.new()
	var a: String = doc.add_box(10, 10, 10, Vector3.ZERO)
	var b: String = doc.add_box(10, 10, 10, Vector3(5, 0, 0))
	check(doc.boolean_op(a, b, "fuse", false), "fuse succeeds")
	check(doc.body_ids().size() == 1, "tool consumed by fuse")
	check(absf(doc.body_volume(a) - 1500.0) < 1e-4, "fused volume 1500")
	check(doc.undo(), "boolean undo")
	check(doc.body_ids().size() == 2, "both bodies restored")

	var c: String = doc.add_box(20, 20, 20, Vector3(100, 0, 0))
	var edges: PackedStringArray = doc.get_edge_ids(c)
	check(edges.size() == 12, "box has 12 edge ids")
	var vol0: float = doc.body_volume(c)
	check(doc.fillet_edges(PackedStringArray([edges[0]]), 3.0), "fillet one edge")
	check(doc.body_volume(c) < vol0, "fillet removed material")
	check(doc.undo(), "fillet undo")
	check(absf(doc.body_volume(c) - vol0) < 1e-6, "volume restored")
	check(doc.chamfer_edges(PackedStringArray([doc.get_edge_ids(c)[0]]), 2.0), "chamfer one edge")
	check(doc.body_volume(c) < vol0, "chamfer removed material")


func test_feature_graph() -> void:
	print("- feature graph bindings")
	var doc := SxDocument.new()
	var fid: String = doc.graph_add_primitive("box", 10, 20, 30, Vector3.ZERO)
	check(fid != "", "graph primitive added")
	check(doc.body_ids().size() == 1, "graph produced a body")
	var feats: Array = doc.graph_features()
	check(feats.size() == 1, "one feature in timeline")
	var body0: String = feats[0]["output_body"]
	check(doc.body_volume(body0) > 5999.0, "box volume ~6000")

	# Parametric edit: change size, body id stays stable.
	var params: Dictionary = JSON.parse_string(feats[0]["params"])
	params["a"] = 20.0
	check(doc.graph_set_params(fid, JSON.stringify(params)), "set_params + regen ok")
	check(absf(doc.body_volume(body0) - 12000.0) < 1e-4, "edited volume 12000, id stable")

	# Suppress hides the body; unsuppress restores it.
	check(doc.graph_set_suppressed(fid, true), "suppress ok")
	check(doc.body_ids().size() == 0, "suppressed body removed")
	check(doc.graph_set_suppressed(fid, false), "unsuppress ok")
	check(doc.body_ids().size() == 1, "body restored")

	# Sketch feature + extrude referencing it.
	var sk := SxSketch.new()
	sk.add_line(0, 0, 30, 0)
	sk.add_line(30, 0, 30, 15)
	sk.add_line(30, 15, 0, 15)
	sk.add_line(0, 15, 0, 0)
	var sk_fid: String = doc.graph_add_sketch(sk)
	check(sk_fid != "", "sketch feature added")
	var ex_fid: String = doc.graph_add_extrude(sk_fid, 8.0, false, "new", "")
	check(ex_fid != "", "extrude feature added")
	check(doc.body_ids().size() == 2, "extrude created second body")

	# Dependency protection: sketch removal blocked while extrude exists.
	check(not doc.graph_remove(sk_fid), "sketch removal blocked by dependent")
	check(doc.graph_remove(ex_fid), "extrude removed")
	check(doc.graph_remove(sk_fid), "sketch removable after dependent gone")
	check(doc.body_ids().size() == 1, "only primitive body remains")

	# Graph persists through save/load.
	var path := "/tmp/sx_graph_roundtrip.sxp"
	check(doc.save(path), "save with graph")
	var doc2 := SxDocument.new()
	check(doc2.load(path), "load with graph")
	check(doc2.graph_features().size() == 1, "timeline survives round-trip")
	var regen: Dictionary = doc2.graph_regenerate()
	check(regen["ok"], "loaded graph regenerates")
	DirAccess.remove_absolute(path)


func test_interop() -> void:
	print("- STEP export/import")
	var path := "/tmp/sx_godot_interop.step"
	var doc := SxDocument.new()
	doc.add_box(10, 20, 30, Vector3.ZERO)
	check(doc.export_step(path), "export_step succeeds")

	var doc2 := SxDocument.new()
	var imported: PackedStringArray = doc2.import_step(path)
	check(imported.size() == 1, "one body imported")
	if imported.size() == 1:
		check(absf(doc2.body_volume(imported[0]) - 6000.0) < 1.0, "imported volume matches")
	check(doc.export_stl("/tmp/sx_godot_interop.stl", true), "export_stl succeeds")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute("/tmp/sx_godot_interop.stl")


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
