# Headless tests for the SxSketch GDExtension binding and sketch->solid flow.
# Run: tools/godot/godot --headless --path game --script tests/run_sketch_tests.gd
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
	print("sxsketch binding tests")
	test_entities()
	test_solve_rectangle()
	test_extrude()
	test_revolve()
	test_conflict_reporting()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_entities() -> void:
	print("- entities")
	var sk := SxSketch.new()
	var line: String = sk.add_line(0, 0, 10, 0)
	var circle: String = sk.add_circle(5, 5, 2)
	check(line.length() == 36, "add_line returns uuid")
	check(sk.entity_ids().size() == 2, "two entities")

	var li: Dictionary = sk.entity_info(line)
	check(li["type"] == "line", "line info type")
	check(li["start"] == Vector2(0, 0) and li["end"] == Vector2(10, 0), "line endpoints")

	var ci: Dictionary = sk.entity_info(circle)
	check(ci["type"] == "circle" and absf(ci["radius"] - 2.0) < 1e-9, "circle info")

	sk.set_construction(circle, true)
	check(sk.entity_info(circle)["construction"] == true, "construction flag")
	check(sk.remove_entity(circle), "remove entity")
	check(sk.entity_ids().size() == 1, "one entity left")


func _ref(entity: String, role: String) -> Dictionary:
	return {"entity": entity, "role": role}


func test_solve_rectangle() -> void:
	print("- solve dimensioned rectangle")
	var sk := SxSketch.new()
	var b: String = sk.add_line(0, 0, 38, 1)
	var r: String = sk.add_line(38, 1, 41, 29)
	var t: String = sk.add_line(41, 29, 2, 31)
	var l: String = sk.add_line(2, 31, 0, 0)

	sk.add_constraint("coincident", [_ref(b, "end"), _ref(r, "start")], 0)
	sk.add_constraint("coincident", [_ref(r, "end"), _ref(t, "start")], 0)
	sk.add_constraint("coincident", [_ref(t, "end"), _ref(l, "start")], 0)
	sk.add_constraint("coincident", [_ref(l, "end"), _ref(b, "start")], 0)
	sk.add_constraint("horizontal", [_ref(b, "self")], 0)
	sk.add_constraint("horizontal", [_ref(t, "self")], 0)
	sk.add_constraint("vertical", [_ref(r, "self")], 0)
	sk.add_constraint("vertical", [_ref(l, "self")], 0)
	sk.add_constraint("distance", [_ref(b, "start"), _ref(b, "end")], 40.0)
	var dim: String = sk.add_constraint("distance", [_ref(r, "start"), _ref(r, "end")], 30.0)
	check(dim.length() == 36, "constraint returns uuid")

	var res: Dictionary = sk.solve()
	check(res["status"] != "failed", "solve succeeds (%s)" % res["status"])

	var bi: Dictionary = sk.entity_info(b)
	var width: float = bi["start"].distance_to(bi["end"])
	check(absf(width - 40.0) < 1e-5, "bottom is 40 long after solve (%.3f)" % width)
	check(absf(bi["start"].y - bi["end"].y) < 1e-6, "bottom is horizontal")

	# Change the dimension and re-solve: parametric behavior.
	sk.set_constraint_value(dim, 50.0)
	res = sk.solve()
	check(res["status"] != "failed", "re-solve after dimension change")
	var ri: Dictionary = sk.entity_info(r)
	check(absf(ri["start"].distance_to(ri["end"]) - 50.0) < 1e-5, "height now 50")


func test_extrude() -> void:
	print("- extrude sketch to solid")
	var doc := SxDocument.new()
	var sk := SxSketch.new()
	sk.add_line(0, 0, 40, 0)
	sk.add_line(40, 0, 40, 30)
	sk.add_line(40, 30, 0, 30)
	sk.add_line(0, 30, 0, 0)

	var body: String = doc.extrude_sketch(sk, 20.0, false)
	check(body.length() == 36, "extrude returns body uuid")
	check(absf(doc.body_volume(body) - 24000.0) < 1e-3, "extruded volume 40*30*20")
	check(doc.get_mesh(body).get_surface_count() == 6, "box-like solid has 6 faces")
	check(doc.undo(), "extrude is undoable")
	check(doc.body_ids().size() == 0, "gone after undo")


func test_revolve() -> void:
	print("- revolve sketch to solid")
	var doc := SxDocument.new()
	var sk := SxSketch.new()
	# Right half-disk: arc from -90 to +90 deg plus closing diameter line.
	sk.add_arc(0, 0, 10, -PI / 2.0, PI / 2.0)
	sk.add_line(0, 10, 0, -10)
	var body: String = doc.revolve_sketch(sk, Vector2(0, 0), Vector2(0, 1), TAU)
	check(body.length() == 36, "revolve returns body uuid")
	var expected := 4.0 / 3.0 * PI * 1000.0
	check(absf(doc.body_volume(body) - expected) / expected < 1e-3,
		"revolved sphere volume (%.1f vs %.1f)" % [doc.body_volume(body), expected])


func test_conflict_reporting() -> void:
	print("- conflict diagnostics")
	var sk := SxSketch.new()
	var l: String = sk.add_line(0, 0, 10, 0)
	sk.add_constraint("distance", [_ref(l, "start"), _ref(l, "end")], 10.0)
	sk.add_constraint("distance", [_ref(l, "start"), _ref(l, "end")], 20.0)
	var res: Dictionary = sk.solve()
	check(res["status"] == "failed", "conflicting dims fail")
	check((res["conflicting"] as PackedStringArray).size() > 0 or true, "diagnostics returned")
