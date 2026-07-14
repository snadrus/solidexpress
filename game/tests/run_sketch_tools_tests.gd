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
	test_fillet_selected(main)
	test_offset_selected_circle(main)
	test_construction_binding()
	test_toggle_construction_selected(main)
	test_toggle_section(main)
	test_snap_endpoint(main)
	test_snap_midpoint(main)
	test_snap_circle_center(main)
	test_snap_axis_horizontal(main)
	test_snap_disabled(main)
	test_dimension_distance_label(main)
	test_dimension_radius_label(main)
	test_dimensions_visible_toggle(main)
	test_dimension_labels_cleared_on_exit(main)

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


func test_fillet_selected(main) -> void:
	print("- fillet_selected on perpendicular L")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.SELECT)

	var la: String = sm.sketch.add_line(0, 0, 10, 0)
	var lb: String = sm.sketch.add_line(10, 0, 10, 10)
	var n_before: int = sm.sketch.entity_ids().size()
	sm._set_selected([la, lb])

	var arc_id: String = sm.fillet_selected(2.0)
	check(arc_id != "", "fillet_selected returned non-empty arc id")
	check(sm.sketch.entity_ids().size() == n_before + 1, "fillet grew entity count by 1")
	var info: Dictionary = sm.sketch.entity_info(arc_id)
	check(info.get("type", "") == "arc", "fillet entity is an arc")
	check(absf(info["radius"] - 2.0) < 1e-4, "fillet arc radius is 2")
	sm.cancel()


func test_offset_selected_circle(main) -> void:
	print("- offset_selected on a circle")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.SELECT)

	var cid: String = sm.sketch.add_circle(0, 0, 10)
	var n_before: int = sm.sketch.entity_ids().size()
	sm._set_selected([cid])

	var dist := 3.0
	var new_ids: Array = sm.offset_selected(dist)
	check(new_ids.size() == 1, "offset_selected returned 1 new id")
	check(sm.sketch.entity_ids().size() == n_before + 1, "offset grew entity count by 1")
	var info: Dictionary = sm.sketch.entity_info(new_ids[0])
	check(info.get("type", "") == "circle", "offset entity is a circle")
	check(absf(info["radius"] - (10.0 + dist)) < 1e-4,
		"offset circle radius differs by distance (%.6f)" % info["radius"])
	sm.cancel()


func test_construction_binding() -> void:
	print("- SxSketch set_construction / is_construction round-trip")
	var sk := SxSketch.new()
	var lid: String = sk.add_line(0, 0, 10, 0)
	var cid: String = sk.add_circle(0, 0, 5)
	check(not sk.is_construction(lid), "line not construction by default")
	check(not sk.is_construction(cid), "circle not construction by default")
	sk.set_construction(lid, true)
	check(sk.is_construction(lid), "line is_construction after set true")
	check(not sk.is_construction(cid), "circle unchanged when sibling toggled")
	check(sk.entity_info(lid).get("construction", false) == true,
		"entity_info.construction reflects flag")
	sk.set_construction(lid, false)
	check(not sk.is_construction(lid), "line is_construction after set false")


func test_toggle_construction_selected(main) -> void:
	print("- toggle_construction_selected flips selected entities")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.SELECT)
	var a: String = sm.sketch.add_line(0, 0, 5, 0)
	var b: String = sm.sketch.add_line(0, 5, 5, 5)
	sm._set_selected([a, b])
	check(not sm.sketch.is_construction(a), "a not construction before toggle")
	check(not sm.sketch.is_construction(b), "b not construction before toggle")
	sm.toggle_construction_selected()
	check(sm.sketch.is_construction(a), "a construction after first toggle")
	check(sm.sketch.is_construction(b), "b construction after first toggle")
	sm.toggle_construction_selected()
	check(not sm.sketch.is_construction(a), "a cleared after second toggle")
	check(not sm.sketch.is_construction(b), "b cleared after second toggle")
	sm.cancel()


func test_toggle_section(main) -> void:
	print("- toggle_section flips section_enabled")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.clear_selection()
	if view.section_enabled:
		view.clear_section_plane()
	var body: String = view.insert_primitive("box", Vector3(50, 50, 0))
	check(body != "", "box inserted for section test")
	check(not view.section_enabled, "section off before toggle")
	vi.toggle_section()
	check(view.section_enabled, "section_enabled true after first toggle")
	vi.toggle_section()
	check(not view.section_enabled, "section_enabled false after second toggle")


func test_snap_endpoint(main) -> void:
	print("- snap to existing line endpoint")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_snap(true)
	sm.set_tool(SketchMode.Tool.LINE)
	var a := Vector2(0, 0)
	var b := Vector2(40, 0)
	sm.click(a)
	sm.click(b)
	sm.end_chain()
	# Start a second line near the first line's end endpoint.
	var near_end := b + Vector2(2.0, 1.5)  # within SNAP_RADIUS (5)
	sm.click(near_end)
	sm.click(Vector2(40, 30))
	var ids: PackedStringArray = sm.sketch.entity_ids()
	check(ids.size() == 2, "endpoint snap: two lines created")
	var info: Dictionary = sm.sketch.entity_info(ids[1])
	check(info["start"].distance_to(b) < 1e-6,
		"second line start snaps to first line endpoint")
	sm.cancel()


func test_snap_midpoint(main) -> void:
	print("- snap to line midpoint")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_snap(true)
	sm.set_tool(SketchMode.Tool.LINE)
	sm.sketch.add_line(0, 0, 20, 0)
	var mid := Vector2(10, 0)
	var near_mid := mid + Vector2(1.0, 2.0)
	var snapped: Vector2 = sm.snap_point(near_mid)
	check(snapped.distance_to(mid) < 1e-6, "snap_point hits exact midpoint")
	sm.click(near_mid)
	sm.click(Vector2(10, 25))
	var ids: PackedStringArray = sm.sketch.entity_ids()
	check(ids.size() == 2, "midpoint snap: line from midpoint created")
	var info: Dictionary = sm.sketch.entity_info(ids[1])
	check(info["start"].distance_to(mid) < 1e-6, "new line starts at midpoint")
	sm.cancel()


func test_snap_circle_center(main) -> void:
	print("- snap to circle center")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_snap(true)
	sm.set_tool(SketchMode.Tool.LINE)
	var center := Vector2(15, 15)
	sm.sketch.add_circle(center.x, center.y, 10.0)
	var near_c := center + Vector2(3.0, -2.0)
	var snapped: Vector2 = sm.snap_point(near_c)
	check(snapped.distance_to(center) < 1e-6, "snap_point hits circle center")
	sm.click(near_c)
	sm.click(Vector2(40, 15))
	var ids: PackedStringArray = sm.sketch.entity_ids()
	check(ids.size() == 2, "center snap: circle + line")
	var line_info: Dictionary = {}
	for id in ids:
		var info: Dictionary = sm.sketch.entity_info(id)
		if info.get("type", "") == "line":
			line_info = info
			break
	check(not line_info.is_empty(), "found line after center snap click")
	check(line_info["start"].distance_to(center) < 1e-6, "line starts at circle center")
	sm.cancel()


func test_snap_axis_horizontal(main) -> void:
	print("- snap axis: almost-horizontal second click")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_snap(true)
	sm.set_tool(SketchMode.Tool.LINE)
	var p0 := Vector2(0, 10)
	sm.click(p0)
	# y offset within SNAP_RADIUS → should snap to same y (exact horizontal)
	sm.click(Vector2(50, 10 + 3.0))
	var ids: PackedStringArray = sm.sketch.entity_ids()
	check(ids.size() == 1, "axis snap created one line")
	var info: Dictionary = sm.sketch.entity_info(ids[0])
	check(absf(info["start"].y - info["end"].y) < 1e-6, "line is exactly horizontal")
	check(absf(info["end"].y - p0.y) < 1e-6, "end y matches first point y")
	check(absf(info["end"].x - 50.0) < 1e-6, "end x kept (not snapped away)")
	sm.cancel()


func test_snap_disabled(main) -> void:
	print("- set_snap(false) passes raw positions")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.LINE)
	sm.sketch.add_line(0, 0, 40, 0)
	sm.set_snap(false)
	var raw := Vector2(40 + 2.0, 1.5)
	var out: Vector2 = sm.snap_point(raw)
	check(out.distance_to(raw) < 1e-9, "snap_point returns raw when disabled")
	sm.click(raw)
	sm.click(Vector2(40, 30))
	var ids: PackedStringArray = sm.sketch.entity_ids()
	check(ids.size() == 2, "disabled snap: two lines")
	var info: Dictionary = sm.sketch.entity_info(ids[1])
	check(info["start"].distance_to(raw) < 1e-6, "new line start stays at raw click")
	check(info["start"].distance_to(Vector2(40, 0)) > 1e-3, "did not snap to endpoint")
	sm.set_snap(true)
	sm.cancel()


func _dimension_label_texts(sm: SketchMode) -> Array[String]:
	var texts: Array[String] = []
	if sm._dimension_labels == null:
		return texts
	for child in sm._dimension_labels.get_children():
		if child is Label3D:
			texts.append((child as Label3D).text)
	return texts


func test_dimension_distance_label(main) -> void:
	print("- distance dimension creates Label3D")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.SELECT)
	var lid: String = sm.sketch.add_line(0, 0, 40, 0)
	sm._set_selected([lid])
	check(sm.constrain("distance", 50.0) == "success", "distance constraint solves")
	check(sm.dimensions.size() == 1, "dimensions array has one entry")
	check(sm.dimensions[0]["type"] == "distance", "stored type is distance")
	var texts := _dimension_label_texts(sm)
	check(texts.size() == 1, "one Label3D under dimension labels")
	var expected := sm._format_dimension(50.0)
	check(texts[0] == expected, "distance label text is '%s' (got '%s')" % [expected, texts[0]])
	sm.cancel()


func test_dimension_radius_label(main) -> void:
	print("- radius dimension creates Label3D")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.SELECT)
	var cid: String = sm.sketch.add_circle(0, 0, 10)
	sm._set_selected([cid])
	check(sm.constrain("radius", 15.0) == "success", "radius constraint solves")
	check(sm.dimensions.size() == 1, "dimensions array has one radius entry")
	var texts := _dimension_label_texts(sm)
	check(texts.size() == 1, "one Label3D for radius dimension")
	var expected := sm._format_dimension(15.0)
	check(texts[0] == expected, "radius label text is '%s' (got '%s')" % [expected, texts[0]])
	sm.cancel()


func test_dimensions_visible_toggle(main) -> void:
	print("- set_dimensions_visible hides label container")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.SELECT)
	var lid: String = sm.sketch.add_line(0, 0, 20, 0)
	sm._set_selected([lid])
	sm.constrain("distance", 25.0)
	check(sm._dimension_labels.visible, "dimension labels visible by default")
	sm.set_dimensions_visible(false)
	check(not sm.dimensions_visible, "dimensions_visible flag false")
	check(not sm._dimension_labels.visible, "label container hidden")
	sm.set_dimensions_visible(true)
	check(sm._dimension_labels.visible, "label container shown again")
	sm.cancel()


func test_dimension_labels_cleared_on_exit(main) -> void:
	print("- leaving sketch mode frees dimension labels")
	var sm: SketchMode = main.sketch_mode
	main.view.clear_selection()
	main._start_sketch()
	sm.set_tool(SketchMode.Tool.SELECT)
	var lid: String = sm.sketch.add_line(0, 0, 30, 0)
	sm._set_selected([lid])
	sm.constrain("distance", 30.0)
	check(_dimension_label_texts(sm).size() == 1, "label present before exit")
	check(sm.dimensions.size() == 1, "dimensions stored before exit")
	sm.cancel()
	check(sm.dimensions.is_empty(), "dimensions cleared on cancel")
	check(sm._dimension_labels.get_child_count() == 0, "label nodes freed on cancel")
