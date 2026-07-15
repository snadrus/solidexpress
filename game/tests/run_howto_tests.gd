# Headless tests that mirror docs/howto/*.md steps and assert the goals.
# Run: tools/godot/godot --headless --path game --script tests/run_howto_tests.gd
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
	print("howto goal tests (mirrors docs/howto/)")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	await howto_place_and_orbit(main)
	await howto_stack_three_blocks(main)
	await howto_extrude_s_shape(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _center(ix: ViewportInteraction) -> Vector2:
	return ix._screen_center()


func _lmb(ix: ViewportInteraction, pos: Vector2, pressed: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.position = pos
	ix._input(mb)


## docs/howto/place-and-orbit.md
func howto_place_and_orbit(main) -> void:
	print("- howto_place_and_orbit")
	var ix: ViewportInteraction = main.interaction
	var view: DocumentView = main.view
	var cam: OrbitCamera = main.camera
	view.new_document()

	# 1. Click Box on palette → arms place
	ix.insert_at_center("box")
	check(ix._place_kind == "box", "place armed")
	# 2. Move then click viewport ground → insert (via _input path)
	var center := _center(ix)
	var mm_move := InputEventMouseMotion.new()
	mm_move.position = center
	ix._input(mm_move)
	_lmb(ix, center, true)
	_lmb(ix, center, false)
	await process_frame
	check(view.doc.body_ids().size() == 1, "one body placed")
	check(view.selected_body != "", "body stays selected")
	main._update_panel_visibility()
	check(not main.palette.visible, "primitives hidden after select")
	check(main.ops_panel.offset_left == 12.0, "modify tools in left rail")
	check(ix.transform_hud.visible, "transform HUD after place")
	var id: String = view.doc.body_ids()[0]
	var bb: Dictionary = view.doc.measure_bbox(id)
	check(absf(float(bb["min"].z)) < 1e-2, "box sits on ground (z=0)")
	# 3. Alt+left-drag orbits (touchpad-friendly; works over docks)
	var yaw0: float = cam.yaw
	var mm := InputEventMouseMotion.new()
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	mm.alt_pressed = true
	mm.relative = Vector2(55, 0)
	mm.position = Vector2(1400, 420)
	ix._input(mm)
	check(absf(cam.yaw - yaw0) > 1e-4, "camera yaw changed after Alt-orbit")


## docs/howto/stack-three-blocks.md
func howto_stack_three_blocks(main) -> void:
	print("- howto_stack_three_blocks")
	var view: DocumentView = main.view
	view.new_document()

	var s := DocumentView.DEFAULT_PRIMITIVE_MM
	# Place first on ground, then each next on prior top.
	var a: String = view.insert_primitive("box", Vector3(0, 0, 0))
	var b: String = view.insert_primitive("box", Vector3(0, 0, s))
	var c: String = view.insert_primitive("box", Vector3(0, 0, s * 2.0))
	check(a != "" and b != "" and c != "", "three boxes placed")
	check(view.doc.body_ids().size() == 3, "document has 3 bodies")

	var mn := 1e9
	var mx := -1e9
	for id in [a, b, c]:
		var bb: Dictionary = view.doc.measure_bbox(id)
		mn = minf(mn, float(bb["min"].z))
		mx = maxf(mx, float(bb["max"].z))
	check(absf(mn) < 1e-2, "stack starts at ground")
	check(absf(mx - s * 3.0) < 1e-2, "stack total height %.0f (got %s)" % [s * 3.0, mx])

	var ix: ViewportInteraction = main.interaction
	ix.insert_at_center("box")
	view.insert_primitive("box", Vector3(0, 0, s * 3.0))
	ix._disarm_place(false)
	await process_frame
	check(view.doc.body_ids().size() == 4, "optional fourth via same rule")


## docs/howto/extrude-s-shape.md
func howto_extrude_s_shape(main) -> void:
	print("- howto_extrude_s_shape")
	var view: DocumentView = main.view
	var sk: SketchMode = main.sketch_mode
	view.new_document()

	# Sketch closed S-channel polyline (matches howto coordinates).
	sk.begin(Vector3.ZERO, Vector3(0, 0, 1))
	sk.set_snap(false)
	sk.infer_enabled = false
	sk.set_tool(SketchMode.Tool.LINE)
	var pts: Array[Vector2] = [
		Vector2(0, 0), Vector2(20, 0), Vector2(20, 15), Vector2(5, 15),
		Vector2(5, 25), Vector2(20, 25), Vector2(20, 40), Vector2(0, 40),
		Vector2(0, 25), Vector2(15, 25), Vector2(15, 15), Vector2(0, 15),
		Vector2(0, 0),
	]
	for p in pts:
		sk.click(p)
	sk.end_chain()
	check(sk.sketch.entity_ids().size() >= 12, "S outline has many line entities")
	sk.finish_extrude(10.0, "new")
	await process_frame
	check(view.doc.body_ids().size() == 1, "one solid after S extrude")
	var id: String = view.doc.body_ids()[0]
	var mp: Dictionary = view.doc.measure_mass(id)
	var vol: float = float(mp.get("volume", 0.0))
	check(vol > 100.0, "S extrusion has substantial volume (got %s)" % vol)
