# Common-workflow tests: build canonical parts end-to-end the way a user
# would (palette, selection, ops panel, sketch mode), assert on resulting
# geometry, and count the user gestures each part needs. Gesture ceilings are
# generous — they catch regressions without over-optimizing for these parts.
# UI gaps (steps impossible without direct doc calls) are recorded per part.
# Run: tools/godot/godot --headless --path game --script tests/run_workflow_tests.gd
extends SceneTree

var failures := 0
var checks := 0

var _gestures := 0
var _gaps: Array[String] = []
var _report: Array = []

var main
var view: DocumentView
var ops: OpsPanel
var sk: SketchMode


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


# n = user gestures this step would take (clicks, key presses, drags).
func gesture(n: int) -> void:
	_gestures += n


func gap(what: String) -> void:
	_gaps.append(what)


func begin_workflow(name: String) -> void:
	print("- " + name)
	_gestures = 0
	_gaps = []
	view.new_document()


func end_workflow(name: String, ceiling: int) -> void:
	check(_gestures <= ceiling, "%s within gesture ceiling (%d <= %d)" % [name, _gestures, ceiling])
	_report.append({"name": name, "gestures": _gestures, "ceiling": ceiling, "gaps": _gaps.duplicate()})


func _init() -> void:
	print("workflow tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	view = main.view
	ops = main.ops_panel
	sk = main.sketch_mode

	workflow_chamfered_plate()
	workflow_bracket()
	workflow_hollow_box()
	workflow_washer()
	workflow_flanged_cylinder()
	workflow_funnel()

	print("\ngesture audit:")
	for r in _report:
		var gaps_txt: String = "" if r["gaps"].is_empty() else "  GAPS: " + ", ".join(r["gaps"])
		print("  %-28s %2d / ceiling %2d%s" % [r["name"], r["gestures"], r["ceiling"], gaps_txt])

	print("\n%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _volume(body: String) -> float:
	return view.doc.body_volume(body)


func _only_body() -> String:
	var ids: PackedStringArray = view.doc.body_ids()
	return ids[0] if ids.size() == 1 else ""


## 1. Chamfered plate with holes at the 4 corners.
func workflow_chamfered_plate() -> void:
	begin_workflow("chamfered plate, 4 corner holes")
	# Plate 100 x 80 x 10. Palette can't set dimensions at insert yet.
	var fid: String = view.doc.graph_add_primitive("box", 100, 80, 10, Vector3.ZERO)
	view.graph_changed()
	gesture(2)
	gap("primitive dimensions not settable at insert (needs property panel)")
	var body := view.body_of_feature(fid)
	check(body != "", "plate created")
	check(absf(_volume(body) - 80000.0) < 1.0, "plate volume 80000")

	# Chamfer all edges: select body, set distance, click Chamfer.
	view.select_entity(body, "")
	gesture(1)
	ops._radius_spin.value = 2.0
	gesture(1)
	ops._chamfer_all()
	gesture(1)
	var vol_chamfer := _volume(body)
	check(vol_chamfer > 76000.0 and vol_chamfer < 79500.0,
		"chamfer removed material (vol %.0f)" % vol_chamfer)

	# 4 corner holes, Ø6 through. UI hole only places at face center today.
	var target := view.feature_of_body(body)
	var hole_positions := [Vector3(15, 15, 10), Vector3(85, 15, 10), Vector3(15, 65, 10), Vector3(85, 65, 10)]
	for pos in hole_positions:
		var hf: String = view.doc.graph_add_hole(target, "simple", pos, Vector3(0, 0, -1),
			6.0, 12.0, 9.6, 3.0, 12.0, 90.0)
		check(hf != "", "hole added at %s" % str(pos))
	view.graph_changed()
	gesture(8)  # ideal: position click + apply per hole
	gap("hole placement at clicked point not exposed (ops panel drills face center only)")

	var expected_drop := 4.0 * PI * 9.0 * 10.0  # 4 x pi r^2 t
	var drop := vol_chamfer - _volume(body)
	check(absf(drop - expected_drop) < expected_drop * 0.03,
		"holes removed ~%.0f mm^3 (got %.0f)" % [expected_drop, drop])
	end_workflow("chamfered plate", 16)


## 2. L-bracket: sketch profile, extrude, fillet the inner vertical edge.
func workflow_bracket() -> void:
	begin_workflow("L-bracket with inner fillet")
	sk.begin(Vector3.ZERO, Vector3(0, 0, 1))
	gesture(1)
	sk.set_tool(SketchMode.Tool.LINE)
	gesture(1)
	for p in [Vector2(0, 0), Vector2(60, 0), Vector2(60, 20), Vector2(20, 20),
			Vector2(20, 50), Vector2(0, 50), Vector2(0, 0)]:
		sk.click(p)
	gesture(7)
	sk.end_chain()
	gesture(1)
	sk.finish_extrude(30.0, "new")
	gesture(2)  # distance + button
	var body := _only_body()
	check(body != "", "bracket body created")
	check(absf(_volume(body) - 54000.0) < 540.0, "L volume ~54000 (got %.0f)" % _volume(body))

	# Find the concave inner vertical edge at (20, 20): bbox is a point column.
	var inner := ""
	for eid in view.doc.get_edge_ids(body):
		var bb: Dictionary = view.doc.measure_bbox(eid)
		if bb.is_empty():
			continue
		var mn: Vector3 = bb["min"]
		var mx: Vector3 = bb["max"]
		if mn.distance_to(Vector3(20, 20, 0)) < 0.5 and mx.distance_to(Vector3(20, 20, 30)) < 0.5:
			inner = eid
			break
	check(inner != "", "inner vertical edge found")
	view.select_edge(body, inner)
	gesture(2)  # click body, click edge
	ops._radius_spin.value = 3.0
	gesture(1)
	ops._fillet_all()  # selected edge only
	gesture(1)
	# Concave fillet ADDS material: (r^2 - pi r^2/4) * L
	var added := (9.0 - PI * 9.0 / 4.0) * 30.0
	check(absf(_volume(body) - (54000.0 + added)) < 60.0,
		"inner fillet added ~%.0f mm^3 (vol %.0f)" % [added, _volume(body)])
	end_workflow("L-bracket", 20)


## 3. Hollow box: shell a cube through its top face.
func workflow_hollow_box() -> void:
	begin_workflow("hollow box (shell)")
	view.insert_primitive("box", Vector3.ZERO)
	gesture(2)
	var body := _only_body()
	check(body != "", "box created")
	# Box is selected after insert; one more click from above refines to top face.
	view.select_ray(Vector3(0, 0, 200), Vector3(0, 0, -1))
	gesture(1)
	check(view.selected_face != "", "top face selected")
	ops._thickness_spin.value = 2.0
	gesture(1)
	ops._shell()
	gesture(1)
	# 50^3 with 2mm walls, open top: outer - inner(46 x 46 x 48).
	var expected := 125000.0 - 46.0 * 46.0 * 48.0
	check(absf(_volume(body) - expected) < expected * 0.05,
		"shelled volume ~%.0f (got %.0f)" % [expected, _volume(body)])
	end_workflow("hollow box", 8)


## 4. Washer: revolve a rectangle offset from the sketch Y axis.
func workflow_washer() -> void:
	begin_workflow("washer (revolve)")
	sk.begin(Vector3.ZERO, Vector3(0, 0, 1))
	gesture(1)
	sk.set_tool(SketchMode.Tool.RECT)
	gesture(1)
	# Snap off: at this small scale the axis-snap would collapse the rect.
	sk.set_snap(false)
	sk.click(Vector2(10, 0))
	sk.click(Vector2(14, 4))
	sk.set_snap(true)
	gesture(2)
	sk.finish_revolve(TAU, "new")
	gesture(1)
	var body := _only_body()
	check(body != "", "washer body created")
	var expected := PI * (14.0 * 14.0 - 10.0 * 10.0) * 4.0
	check(absf(_volume(body) - expected) < expected * 0.02,
		"washer volume ~%.0f (got %.0f)" % [expected, _volume(body)])
	end_workflow("washer", 8)


## 5. Flanged cylinder: shaft + flange disc fused via the armed boolean flow.
func workflow_flanged_cylinder() -> void:
	begin_workflow("flanged cylinder (fuse)")
	view.insert_primitive("cylinder", Vector3.ZERO)  # r25 h50
	gesture(2)
	var shaft := _only_body()
	check(shaft != "", "shaft created")
	var ffid: String = view.doc.graph_add_primitive("cylinder", 40, 10, 0, Vector3.ZERO)
	view.graph_changed()
	gesture(2)
	gap("flange radius not settable at insert (needs property panel)")
	var flange := view.body_of_feature(ffid)
	check(flange != "", "flange created")

	view.select_entity(shaft, "")
	gesture(1)
	ops._arm_boolean("fuse")
	gesture(1)
	view.select_entity(flange, "")  # armed flow consumes this click
	gesture(1)
	check(view.doc.body_ids().size() == 1, "fuse consumed the tool body")
	var expected := PI * 625.0 * 50.0 + PI * 1600.0 * 10.0 - PI * 625.0 * 10.0
	check(absf(_volume(shaft) - expected) < expected * 0.02,
		"fused volume ~%.0f (got %.0f)" % [expected, _volume(shaft)])
	end_workflow("flanged cylinder", 10)


## 6. Funnel: loft between two circles on parallel planes.
func workflow_funnel() -> void:
	begin_workflow("funnel (loft)")
	var bottom := SxSketch.new()
	bottom.add_circle(0, 0, 30.0)
	var bfid: String = view.doc.graph_add_sketch(bottom)
	gesture(4)  # ideal: sketch + tool + 2 clicks
	var top := SxSketch.new()
	top.set_plane(Vector3(0, 0, 60), Vector3(1, 0, 0), Vector3(0, 1, 0))
	top.add_circle(0, 0, 8.0)
	var tfid: String = view.doc.graph_add_sketch(top)
	gesture(5)  # ideal: plane pick + sketch + tool + 2 clicks
	var lfid: String = view.doc.graph_add_loft(PackedStringArray([bfid, tfid]), true)
	view.graph_changed()
	gesture(1)
	gap("sketch mode cannot exit without extrude/revolve; loft not reachable from UI")
	check(lfid != "", "loft feature created")
	var body := view.body_of_feature(lfid)
	check(body != "", "loft body exists")
	# Cone frustum: pi h/3 (R^2 + R r + r^2)
	var expected := PI * 60.0 / 3.0 * (900.0 + 240.0 + 64.0)
	check(absf(_volume(body) - expected) < expected * 0.03,
		"funnel volume ~%.0f (got %.0f)" % [expected, _volume(body)])
	end_workflow("funnel", 12)
