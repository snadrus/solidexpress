# Run: tools/godot/godot --headless --path game --script tests/run_sketch_to_3d_ui_tests.gd
extends SceneTree

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   - " + msg)
	else:
		failures += 1
		printerr("  FAIL - " + msg)


func _init() -> void:
	print("sketch to 3d ui workflow tests")
	var doc := SxDocument.new()

	# Path merge: two open rails
	var sk_a := SxSketch.new()
	sk_a.add_line(0, 0, 20, 0)
	var fid_a: String = doc.graph_add_sketch(sk_a)
	var sk_b := SxSketch.new()
	sk_b.set_plane(Vector3(20, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
	sk_b.add_line(0, 0, 0, 30)
	var fid_b: String = doc.graph_add_sketch(sk_b)
	var path_fid: String = doc.graph_add_path(PackedStringArray([fid_a, fid_b]), "join_endpoints")
	check(path_fid != "", "path from merged rails")

	# Sweep profile along path
	var prof := SxSketch.new()
	prof.add_circle(0, 0, 2.0)
	var prof_fid: String = doc.graph_add_sketch(prof)
	var sw_fid: String = doc.graph_add_sweep_along_path(prof_fid, path_fid)
	check(sw_fid != "", "sweep along path")
	var sw_body := ""
	for f in doc.graph_features():
		if str(f.get("id", "")) == sw_fid:
			sw_body = str(f.get("output_body", ""))
	check(sw_body != "", "sweep output body")
	check(doc.body_volume(sw_body) > 200.0, "sweep volume plausible")

	# Loft two circles on parallel planes
	doc = SxDocument.new()
	var bot := SxSketch.new()
	bot.add_circle(0, 0, 10)
	var bfid: String = doc.graph_add_sketch(bot)
	var top := SxSketch.new()
	top.set_plane(Vector3(0, 0, 40), Vector3(1, 0, 0), Vector3(0, 1, 0))
	top.add_circle(0, 0, 5)
	var tfid: String = doc.graph_add_sketch(top)
	var loft_fid: String = doc.graph_add_loft(PackedStringArray([bfid, tfid]), true)
	check(loft_fid != "", "loft ruled")
	var loft_body := ""
	for f in doc.graph_features():
		if str(f.get("id", "")) == loft_fid:
			loft_body = str(f.get("output_body", ""))
	check(loft_body != "", "loft output body")
	check(doc.body_volume(loft_body) > 1000.0, "loft volume plausible")

	print("%d failures" % failures)
	quit(1 if failures > 0 else 0)
