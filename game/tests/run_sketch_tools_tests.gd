# Headless tests for SketchMode ARC and POLYGON drawing tools.
# Run: tools/godot/godot --headless --path game --script tests/run_sketch_tools_tests.gd
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
	print("sketch tools tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_arc_tool(main)
	test_polygon_tool(main)
	test_polygon_sides_clamp(main)
	test_polygon_extrude(main)
	test_tool_switch_mid_arc(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_arc_tool(main) -> void:
	print("- arc tool: three clicks")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.ARC)

	var center := Vector2(0, 0)
	var start_pt := Vector2(10, 0)
	var end_pt := Vector2(0, 10)
	sm.click(center)
	sm.click(start_pt)
	sm.click(end_pt)

	var ids: PackedStringArray = sm.sketch.entity_ids()
	check(ids.size() == 1, "arc tool created exactly 1 entity")
	var info: Dictionary = sm.sketch.entity_info(ids[0])
	check(info.get("type", "") == "arc", "entity is an arc")
	var expected_r := center.distance_to(start_pt)
	var expected_start := (start_pt - center).angle()
	var expected_end := (end_pt - center).angle()
	check(absf(info["radius"] - expected_r) < 1e-4, "arc radius matches (%.6f)" % info["radius"])
	check(absf(info["start_angle"] - expected_start) < 1e-4,
		"arc start_angle matches (%.6f)" % info["start_angle"])
	check(absf(info["end_angle"] - expected_end) < 1e-4,
		"arc end_angle matches (%.6f)" % info["end_angle"])
	sm.cancel()


func test_polygon_tool(main) -> void:
	print("- polygon tool: hexagon")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.polygon_sides = 6
	sm.set_tool(SketchMode.Tool.POLYGON)

	var center := Vector2(0, 0)
	var vertex := Vector2(20, 0)
	sm.click(center)
	sm.click(vertex)

	var ids: PackedStringArray = sm.sketch.entity_ids()
	check(ids.size() == 6, "hexagon created 6 line entities")

	var r := center.distance_to(vertex)
	var ends: Array[Vector2] = []
	for id in ids:
		var info: Dictionary = sm.sketch.entity_info(id)
		check(info.get("type", "") == "line", "polygon entity is a line")
		var s: Vector2 = info["start"]
		var e: Vector2 = info["end"]
		check(absf(s.distance_to(center) - r) < 1e-4, "start vertex on circle")
		check(absf(e.distance_to(center) - r) < 1e-4, "end vertex on circle")
		ends.append(s)
		ends.append(e)

	# Consecutive lines share endpoints: each endpoint appears exactly twice.
	var unmatched := 0
	for i in range(ends.size()):
		var matches := 0
		for j in range(ends.size()):
			if i != j and ends[i].distance_to(ends[j]) < 1e-4:
				matches += 1
		if matches != 1:
			unmatched += 1
	check(unmatched == 0, "consecutive lines share endpoints (closed chain)")
	sm.cancel()


func test_polygon_sides_clamp(main) -> void:
	print("- polygon_sides clamp")
	var sm: SketchMode = main.sketch_mode
	sm.polygon_sides = 2
	check(sm.polygon_sides == 3, "polygon_sides=2 clamps to 3")
	sm.polygon_sides = 6


func test_polygon_extrude(main) -> void:
	print("- polygon extrude volume")
	var view: DocumentView = main.view
	var sm: SketchMode = main.sketch_mode
	view.clear_selection()
	main._start_sketch()
	sm.polygon_sides = 6
	sm.set_tool(SketchMode.Tool.POLYGON)

	var center := Vector2(0, 0)
	var r := 10.0
	sm.click(center)
	sm.click(Vector2(r, 0))

	var n := 6
	var expected := 0.5 * float(n) * r * r * sin(TAU / float(n)) * 10.0
	var count0: int = view.doc.body_ids().size()
	sm.finish_extrude(10.0, "new")
	check(view.doc.body_ids().size() == count0 + 1, "polygon extrude created a body")
	var body: String = view.selected_body
	check(body != "", "extruded body selected")
	var vol: float = view.doc.body_volume(body)
	check(absf(vol - expected) / expected < 0.01,
		"hexagon prism volume within 1%% (%.3f vs %.3f)" % [vol, expected])


func test_tool_switch_mid_arc(main) -> void:
	print("- tool switch mid-arc leaves no stray entities")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.ARC)
	sm.click(Vector2(5, 5))
	check(sm.sketch.entity_ids().size() == 0, "no entity after first arc click")
	sm.set_tool(SketchMode.Tool.LINE)
	check(sm.sketch.entity_ids().size() == 0, "no entity after switching away")
	sm.set_tool(SketchMode.Tool.ARC)
	check(sm.sketch.entity_ids().size() == 0, "no entity after switching back to arc")
	check(sm._tool_points.is_empty(), "tool points cleared on switch")
	sm.cancel()
