# Headless tests for sketch constraint inference (automatic H/V + coincident
# relations), DOF-based coloring, and editable dimension values.
# Run: tools/godot/godot --headless --path game --script tests/run_infer_tests.gd
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
	print("sketch inference tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_line_inference(main.sketch_mode)
	test_rect_inference(main.sketch_mode)
	test_infer_toggle(main.sketch_mode)
	test_dof_coloring(main.sketch_mode)
	test_editable_dimension(main.sketch_mode)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _constraint_types(sk: SketchMode) -> Dictionary:
	# type -> count, via constraint ids (no info binding; count only).
	return {"n": sk.sketch.constraint_ids().size()}


func test_line_inference(sk: SketchMode) -> void:
	print("- line H/V + coincident inference")
	sk.begin(Vector3.ZERO, Vector3(0, 0, 1))
	sk.set_snap(false)
	sk.set_tool(SketchMode.Tool.LINE)
	# Slightly off-horizontal line: inference should snap it flat via solve.
	sk.click(Vector2(0, 0))
	sk.click(Vector2(40, 0.3))
	var ids: Array = sk.sketch.entity_ids()
	check(ids.size() == 1, "one line created")
	var info: Dictionary = sk.sketch.entity_info(ids[0])
	check(absf(info["start"].y - info["end"].y) < 1e-6,
		"horizontal inferred and solved flat (dy=%f)" % absf(info["start"].y - info["end"].y))
	# Chained second line: coincident inference joins the shared endpoint.
	var n_before: int = sk.sketch.constraint_ids().size()
	sk.click(Vector2(40.2, 30))
	check(sk.sketch.constraint_ids().size() > n_before, "chain click added constraints")
	sk.end_chain()
	sk.cancel()


func test_rect_inference(sk: SketchMode) -> void:
	print("- rect inference fully constrains shape topology")
	sk.begin(Vector3.ZERO, Vector3(0, 0, 1))
	sk.set_snap(false)
	sk.set_tool(SketchMode.Tool.RECT)
	sk.click(Vector2(0, 0))
	sk.click(Vector2(30, 20))
	check(sk.sketch.entity_ids().size() == 4, "four rect lines")
	# 4 H/V + 4 coincident corners = 8 inferred constraints.
	check(sk.sketch.constraint_ids().size() == 8,
		"8 inferred constraints (got %d)" % sk.sketch.constraint_ids().size())
	# Rect topology survives a solve after constraining one side's length.
	sk.set_tool(SketchMode.Tool.SELECT)
	var first: String = sk.sketch.entity_ids()[0]
	sk._set_selected([first])
	var st: String = sk.constrain("distance", 50.0)
	check(st != "failed" and st != "", "distance dim solves (%s)" % st)
	var info: Dictionary = sk.sketch.entity_info(first)
	check(absf((info["end"] - info["start"]).length() - 50.0) < 1e-4, "side resized to 50")
	sk.cancel()


func test_infer_toggle(sk: SketchMode) -> void:
	print("- inference can be disabled")
	sk.begin(Vector3.ZERO, Vector3(0, 0, 1))
	sk.infer_enabled = false
	sk.set_snap(false)
	sk.set_tool(SketchMode.Tool.LINE)
	sk.click(Vector2(0, 0))
	sk.click(Vector2(40, 0.3))
	check(sk.sketch.constraint_ids().size() == 0, "no constraints when disabled")
	var info: Dictionary = sk.sketch.entity_info(sk.sketch.entity_ids()[0])
	check(absf(info["end"].y - 0.3) < 1e-4, "geometry untouched")
	sk.infer_enabled = true
	sk.cancel()


func test_dof_coloring(sk: SketchMode) -> void:
	print("- DOF tracking and constrained color")
	sk.begin(Vector3.ZERO, Vector3(0, 0, 1))
	check(sk.last_dofs == -1, "no solve yet after begin")
	sk.set_snap(false)
	sk.set_tool(SketchMode.Tool.CIRCLE)
	sk.click(Vector2(0, 0))
	sk.click(Vector2(10, 0))
	check(sk._entity_draw_color({}) == sk.COLOR_ENTITY, "unconstrained draws default")
	# Fully constrain the circle: radius + center pinned by two distance dims
	# is overkill; PlaneGCS reports dofs after any solve — pin radius and check
	# dofs drop.
	sk.set_tool(SketchMode.Tool.SELECT)
	var cid_e: String = sk.sketch.entity_ids()[0]
	sk._set_selected([cid_e])
	sk.constrain("radius", 10.0)
	check(sk.last_dofs >= 0, "dofs tracked after solve (got %d)" % sk.last_dofs)
	if sk.last_dofs == 0:
		check(sk._entity_draw_color({}) == sk.COLOR_CONSTRAINED, "fully constrained draws green")
	else:
		check(sk._entity_draw_color({}) == sk.COLOR_ENTITY, "partially constrained stays default")
	sk.cancel()


func test_editable_dimension(sk: SketchMode) -> void:
	print("- dimension value edit re-solves")
	sk.begin(Vector3.ZERO, Vector3(0, 0, 1))
	sk.set_snap(false)
	sk.set_tool(SketchMode.Tool.CIRCLE)
	sk.click(Vector2(0, 0))
	sk.click(Vector2(8, 0))
	sk.set_tool(SketchMode.Tool.SELECT)
	var eid: String = sk.sketch.entity_ids()[0]
	sk._set_selected([eid])
	sk.constrain("radius", 8.0)
	check(sk.dimensions.size() == 1, "dimension recorded")
	check(sk.dimensions[0].get("cid", "") != "", "dimension keeps constraint id")
	var st: String = sk.set_dimension_value(0, 12.0)
	check(st == "success" or st == "converged", "edited dim solves (%s)" % st)
	var info: Dictionary = sk.sketch.entity_info(eid)
	check(absf(info["radius"] - 12.0) < 1e-6, "circle radius follows edited dim")
	check(sk.dimensions[0]["value"] == 12.0, "dimension record updated")
	sk.cancel()
