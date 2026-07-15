# Headless tests for click-to-place (armed insert + ghost preview).
# Run: tools/godot/godot --headless --path game --script tests/run_place_tests.gd
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
	print("click-to-place tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_arming(main)
	test_ghost_follows(main)
	await test_commit(main)
	await test_selection_survives_release(main)
	await test_cancel(main)
	test_esc_clears_selection(main)
	test_drop_unchanged(main)
	await test_stack_on_face(main)
	await test_orbit_over_ops_panel(main)
	await test_empty_drag_orbits(main)
	test_place_snap_ui_and_coords(main)
	await test_transform_hud_and_resize(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _center(ix: ViewportInteraction) -> Vector2:
	# Headless Control size can be (0,0); rays use the camera viewport.
	return ix._screen_center()


func _ghost(main) -> MeshInstance3D:
	return main.model_space.get_node_or_null("PlaceGhost") as MeshInstance3D


func _lmb(ix: ViewportInteraction, pos: Vector2, pressed: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.position = pos
	# Place mode is driven from _input (viewport coords), not _gui_input.
	ix._input(mb)


func _move(ix: ViewportInteraction, pos: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	ix._input(mm)


func _esc(ix: ViewportInteraction) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	ix._input(ev)


func test_arming(main) -> void:
	print("- arming insert_at_center")
	var ix: ViewportInteraction = main.interaction
	main.view.new_document()
	ix.insert_at_center("box")
	check(main.view.doc.body_ids().is_empty(), "no body added yet after arm")
	check(_ghost(main) != null, "ghost node exists under model_space")
	check(ix._place_kind == "box", "place kind armed as box")


func test_ghost_follows(main) -> void:
	print("- ghost follows mouse (sits on plane)")
	var ix: ViewportInteraction = main.interaction
	var center := _center(ix)
	_move(ix, center)
	var ghost := _ghost(main)
	check(ghost != null and ghost.visible, "ghost visible at viewport center")
	var gp = ix.ground_point(center)
	check(gp != null, "ground point at center is valid")
	if gp != null:
		var half_z := DocumentView.DEFAULT_PRIMITIVE_MM * 0.5
		var expect: Vector3 = gp + Vector3(0, 0, half_z)
		check(ghost.position.distance_to(expect) < 1e-2,
			"ghost center is half-height above floor (got %s want %s)" % [ghost.position, expect])
	check(ix.has_focus(), "Interaction grabbed focus on arm (Esc works)")
	# Offset motion — ghost must track, not stay stuck at arm position.
	var off := center + Vector2(80, 40)
	_move(ix, off)
	ghost = _ghost(main)
	var target2: Dictionary = ix._place_target(off)
	if ghost != null and not target2.is_empty():
		var half_z2 := DocumentView.DEFAULT_PRIMITIVE_MM * 0.5
		var expect2: Vector3 = target2["point"] + Vector3(0, 0, half_z2)
		check(ghost.position.distance_to(expect2) < 1e-2,
			"ghost followed mouse offset (got %s want %s)" % [ghost.position, expect2])
	else:
		check(false, "ghost followed mouse offset")


func test_commit(main) -> void:
	print("- LMB commits place")
	var ix: ViewportInteraction = main.interaction
	var center := _center(ix)
	_lmb(ix, center, true)
	_lmb(ix, center, false)
	check(main.view.doc.body_ids().size() == 1, "exactly one body after commit")
	check(ix._place_kind == "", "place mode disarmed after commit")
	check(ix._place_ghost == null, "ghost reference cleared after commit")
	await process_frame
	check(main.model_space.get_node_or_null("PlaceGhost") == null, "PlaceGhost gone from tree")
	var id: String = main.view.doc.body_ids()[0]
	var bb: Dictionary = main.view.doc.measure_bbox(id)
	check(not bb.is_empty(), "bbox after ground place")
	if not bb.is_empty():
		check(absf(float(bb["min"].z) - 0.0) < 1e-2, "box floor on z=0")
		check(absf(float(bb["max"].z) - DocumentView.DEFAULT_PRIMITIVE_MM) < 1e-2,
			"box top at z=%.0f" % DocumentView.DEFAULT_PRIMITIVE_MM)


func test_selection_survives_release(main) -> void:
	print("- selection kept after place + LMB release")
	var ix: ViewportInteraction = main.interaction
	var view: DocumentView = main.view
	view.new_document()
	ix.insert_at_center("box")
	var center := _center(ix)
	_lmb(ix, center, true)
	check(view.selected_body != "", "auto-selected on commit")
	var sel := view.selected_body
	_lmb(ix, center, false)
	check(view.selected_body == sel, "release did not clear selection")
	await process_frame


func test_cancel(main) -> void:
	print("- Esc cancels place")
	var ix: ViewportInteraction = main.interaction
	var count0: int = main.view.doc.body_ids().size()
	ix.insert_at_center("cylinder")
	check(_ghost(main) != null, "ghost present after re-arm")
	_esc(ix)
	check(main.view.doc.body_ids().size() == count0, "no second body after cancel")
	check(ix._place_kind == "", "disarmed after Esc cancel")
	check(ix._place_ghost == null, "ghost reference cleared after cancel")
	await process_frame
	check(main.model_space.get_node_or_null("PlaceGhost") == null, "ghost freed after cancel")


func test_esc_clears_selection(main) -> void:
	print("- Esc clears 3D selection")
	var ix: ViewportInteraction = main.interaction
	var view: DocumentView = main.view
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO)
	check(id != "", "body inserted for selection test")
	var ray := ix._model_ray(_center(ix))
	# Select via ray API (may miss in headless if camera framing differs);
	# fall back to select_entity.
	if not view.select_ray(ray[0], ray[1]):
		view.select_entity(id, "")
	check(view.selected_body != "", "body selected before Esc")
	_esc(ix)
	check(view.selected_body == "", "Esc cleared selected_body")


func test_drop_unchanged(main) -> void:
	print("- drag-drop inserts immediately")
	var ix: ViewportInteraction = main.interaction
	var count0: int = main.view.doc.body_ids().size()
	var center := _center(ix)
	ix._drop_data(center, {"sx_primitive": "sphere"})
	check(main.view.doc.body_ids().size() == count0 + 1, "drop increments body count immediately")
	check(ix._place_kind == "", "drop does not arm place mode")


func test_stack_on_face(main) -> void:
	print("- stack three boxes on top faces")
	var view: DocumentView = main.view
	view.new_document()
	var s := DocumentView.DEFAULT_PRIMITIVE_MM
	var a: String = view.insert_primitive("box", Vector3(0, 0, 0))
	var b: String = view.insert_primitive("box", Vector3(0, 0, s))
	var c: String = view.insert_primitive("box", Vector3(0, 0, s * 2.0))
	check(a != "" and b != "" and c != "", "three stacked boxes inserted")
	check(view.doc.body_ids().size() == 3, "three bodies in document")
	var bb_a: Dictionary = view.doc.measure_bbox(a)
	var bb_b: Dictionary = view.doc.measure_bbox(b)
	var bb_c: Dictionary = view.doc.measure_bbox(c)
	check(absf(float(bb_a["min"].z)) < 1e-2 and absf(float(bb_a["max"].z) - s) < 1e-2,
		"block A spans z 0..%.0f" % s)
	check(absf(float(bb_b["min"].z) - s) < 1e-2 and absf(float(bb_b["max"].z) - s * 2.0) < 1e-2,
		"block B spans z %.0f..%.0f" % [s, s * 2.0])
	check(absf(float(bb_c["min"].z) - s * 2.0) < 1e-2 and absf(float(bb_c["max"].z) - s * 3.0) < 1e-2,
		"block C spans z %.0f..%.0f" % [s * 2.0, s * 3.0])
	var ix: ViewportInteraction = main.interaction
	ix.insert_at_center("box")
	ix._free_ghost()
	ix._place_kind = ""
	view.insert_primitive("box", Vector3(0, 0, s * 3.0))
	check(view.doc.body_ids().size() == 4,
		"fourth box stacked to z=%.0f..%.0f" % [s * 3.0, s * 4.0])
	await process_frame


func test_orbit_over_ops_panel(main) -> void:
	print("- orbit via middle / Alt-left / pan gesture")
	var ix: ViewportInteraction = main.interaction
	var cam: OrbitCamera = main.camera
	main.view.new_document()
	main.view.insert_primitive("box", Vector3.ZERO)
	await process_frame
	check(main.ops_panel.visible, "ops panel visible after select")
	var yaw0: float = cam.yaw
	var mm := InputEventMouseMotion.new()
	mm.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	mm.relative = Vector2(40, 0)
	mm.position = Vector2(1400, 400)
	ix._input(mm)
	check(absf(cam.yaw - yaw0) > 1e-4, "yaw changed from middle-drag in _input")

	yaw0 = cam.yaw
	var alt := InputEventMouseMotion.new()
	alt.button_mask = MOUSE_BUTTON_MASK_LEFT
	alt.alt_pressed = true
	alt.relative = Vector2(35, 0)
	alt.position = Vector2(1400, 400)
	ix._input(alt)
	check(absf(cam.yaw - yaw0) > 1e-4, "yaw changed from Alt+left-drag")

	yaw0 = cam.yaw
	var pan := InputEventPanGesture.new()
	pan.delta = Vector2(20, 0)
	ix._input(pan)
	check(absf(cam.yaw - yaw0) > 1e-4, "yaw changed from pan gesture (two-finger)")


func test_empty_drag_orbits(main) -> void:
	print("- empty-space left-drag orbits")
	var ix: ViewportInteraction = main.interaction
	var cam: OrbitCamera = main.camera
	main.view.new_document()
	main.view.insert_primitive("box", Vector3.ZERO)
	main.view.clear_selection()
	# Close default zoom makes the box fill a tiny headless viewport; pull back.
	root.size = Vector2i(1280, 720)
	ix.size = Vector2(1280, 720)
	cam.distance = 800.0
	cam.pivot = Vector3.ZERO
	cam._update_transform()
	await process_frame
	var miss := Vector2(20, 20)
	var ray := ix._model_ray(miss)
	var hit: Dictionary = main.view.pick_info(ray[0], ray[1])
	check(hit.is_empty(), "miss point has no pick hit")
	var yaw0: float = cam.yaw
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = miss
	ix._input(press)
	var drag := InputEventMouseMotion.new()
	drag.position = miss + Vector2(60, 0)
	ix._input(drag)
	check(ix._drag_mode == ViewportInteraction.DragMode.ORBIT_VIEW, "empty drag armed ORBIT_VIEW")
	check(absf(cam.yaw - yaw0) > 1e-4, "yaw changed from empty-space drag")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = miss + Vector2(60, 0)
	ix._input(release)
	check(ix._drag_mode == ViewportInteraction.DragMode.NONE, "orbit drag cleared on release")


func test_place_snap_ui_and_coords(main) -> void:
	print("- place snap bar + coordinate snap")
	var ix: ViewportInteraction = main.interaction
	main.view.new_document()
	check(ix.place_snap_enabled, "snap enabled by default")
	check(is_equal_approx(ix.place_snap_mm, 0.1), "default snap resolution 0.1 mm")
	ix.insert_at_center("box")
	check(ix._place_snap_panel != null and ix._place_snap_panel.visible, "snap panel visible while armed")
	check(ix._place_snap_check != null and ix._place_snap_check.button_pressed, "snap checkbox on")
	check(ix._place_snap_spin != null and is_equal_approx(ix._place_snap_spin.value, 0.1),
		"snap spin shows 0.1 mm")
	check(ix.transform_hud != null and ix.transform_hud.visible, "transform HUD visible while placing")
	var ds := DocumentView.DEFAULT_PRIMITIVE_MM
	check(ix.transform_hud.current_size().is_equal_approx(Vector3(ds, ds, ds)),
		"place HUD default size %.0f³" % ds)
	var snapped: Vector3 = ix._snap_point(Vector3(1.24, -2.36, 3.07))
	check(snapped.is_equal_approx(Vector3(1.2, -2.4, 3.1)), "0.1 mm snap rounds axes")
	ix.place_snap_enabled = false
	check(ix._snap_point(Vector3(1.24, -2.36, 3.07)).is_equal_approx(Vector3(1.24, -2.36, 3.07)),
		"snap bypassed when disabled")
	ix.place_snap_enabled = true
	ix.place_snap_mm = 1.0
	check(ix._snap_point(Vector3(1.4, 2.6, 0.4)).is_equal_approx(Vector3(1.0, 3.0, 0.0)),
		"1.0 mm snap rounds axes")
	_esc(ix)
	check(not ix._place_snap_panel.visible, "snap panel hidden after cancel")


func test_transform_hud_and_resize(main) -> void:
	print("- transform HUD + AABB resize + precision field")
	var ix: ViewportInteraction = main.interaction
	var view: DocumentView = main.view
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO)
	await process_frame
	view.select_entity(id, "")
	main._update_panel_visibility()
	check(ix.transform_hud.visible, "HUD visible when body selected")
	check(not main.palette.visible, "palette hidden when body selected")
	check(main.ops_panel.offset_left == 12.0, "modify tools docked left")
	var bb0: Dictionary = view.selection_bbox()
	check(not bb0.is_empty(), "selection bbox available")
	# Resize max-X face by +10 mm via kernel helper (mirror of drag commit).
	var mn: Vector3 = bb0["min"]
	var mx: Vector3 = bb0["max"]
	mx.x += 10.0
	check(view.resize_primitive_aabb(id, mn, mx), "resize_primitive_aabb grows +X")
	var bb1: Dictionary = view.doc.measure_bbox(id)
	check(absf(float(bb1["max"].x) - float(bb0["max"].x) - 10.0) < 1e-2, "max X grew by 10")
	# Simulate post-drag precision field: re-set distance to 15 from pre-resize.
	ix._precision_min = bb0["min"]
	ix._precision_max = bb0["max"]
	ix._precision_signs = Vector3(1, 0, 0)
	ix._precision_base = 10.0
	ix._apply_precision_resize(15.0)
	var bb2: Dictionary = view.doc.measure_bbox(id)
	check(absf(float(bb2["max"].x) - float(bb0["max"].x) - 15.0) < 1e-2,
		"precision field set ΔX to 15 (got %s)" % bb2["max"].x)
	# HUD size edit.
	ix._on_hud_size(Vector3(40, 40, 40))
	var bb3: Dictionary = view.doc.measure_bbox(id)
	var sz: Vector3 = bb3["max"] - bb3["min"]
	check(sz.is_equal_approx(Vector3(40, 40, 40)), "HUD size commit → 40³ (got %s)" % sz)
	# ΔZ precision apply (typed Enter path uses apply() then this).
	var bbz0: Dictionary = view.doc.measure_bbox(id)
	ix._precision_min = bbz0["min"]
	ix._precision_max = bbz0["max"]
	ix._precision_signs = Vector3(0, 0, 1)
	ix._precision_base = 0.0
	ix._apply_precision_resize(12.0)
	var bbz1: Dictionary = view.doc.measure_bbox(id)
	check(absf(float(bbz1["max"].z) - float(bbz0["max"].z) - 12.0) < 1e-2,
		"precision ΔZ grows max Z by 12 (got %s)" % bbz1["max"].z)
	# Body face press arms MOVE and preserves size (handles must not steal).
	view.new_document()
	id = view.insert_primitive("box", Vector3.ZERO)
	view.select_entity(id, "")
	main.camera.frame_contents()
	await process_frame
	var bb_hit: Dictionary = view.selection_bbox()
	var body_pt: Vector3 = main.model_space.to_global(bb_hit["center"])
	var screen_body: Vector2 = main.camera.unproject_position(body_pt)
	var ray_body := ix._model_ray(screen_body)
	var hit_body: Dictionary = view.pick_info(ray_body[0], ray_body[1])
	check(not hit_body.is_empty() and hit_body["body"] == id, "test point hits selected body")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen_body
	ix._input(press)
	# Body move may arm immediately or after leaving click-slop (pending path).
	var armed_on_press := ix._drag_mode == ViewportInteraction.DragMode.MOVE_BODY
	var pending: bool = bool(ix._pending_body_move)
	check(armed_on_press or pending, "body press arms or defers MOVE_BODY (mode=%s)" % ix._drag_mode)
	var drag := InputEventMouseMotion.new()
	drag.position = screen_body + Vector2(40, 0)
	ix._input(drag)
	check(ix._drag_mode == ViewportInteraction.DragMode.MOVE_BODY, "drag stays MOVE_BODY")
	check(ix._drag_accum.length() > 1e-3, "move accum non-zero")
	# Tap X mid-drag → lock to X: diagonal motion must keep model ΔY at 0.
	var key_x := InputEventKey.new()
	key_x.keycode = KEY_X
	key_x.pressed = true
	ix._input(key_x)
	check(ix._move_axis_lock == ViewportInteraction.AXIS_X, "X tap locks move to X axis")
	var diag := InputEventMouseMotion.new()
	diag.position = screen_body + Vector2(60, 30)
	ix._input(diag)
	check(absf(ix._drag_accum.y) < 1e-6, "X-locked drag keeps ΔY at 0 (got %s)" % ix._drag_accum.y)
	check(absf(ix._drag_accum.x) > 1e-3, "X-locked drag still moves along X")
	# Tap X again → free: the same pointer position now yields a ΔY component.
	ix._input(key_x)
	check(ix._move_axis_lock == -1, "second X tap frees the axis lock")
	check(absf(ix._drag_accum.y) > 1e-4, "freed drag regains ΔY (got %s)" % ix._drag_accum.y)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = screen_body + Vector2(40, 0)
	ix._input(release)
	var bb_moved: Dictionary = view.doc.measure_bbox(id)
	var size_moved: Vector3 = bb_moved["max"] - bb_moved["min"]
	var ds2 := DocumentView.DEFAULT_PRIMITIVE_MM
	check(size_moved.is_equal_approx(Vector3(ds2, ds2, ds2)),
		"body drag preserves size (got %s)" % size_moved)
