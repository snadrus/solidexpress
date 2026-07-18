# Hover measure pair + selection bound dimensions.
# Run: tools/godot/godot --headless --path game --script tests/run_measure_overlay_tests.gd
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
	print("measure overlay tests")
	root.size = Vector2i(1280, 720)
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_closest_edge_point(main)
	await test_selection_bound_labels(main)
	test_hover_pair_pins_on_leave(main)
	test_esc_clears_pair(main)
	test_screen_frac_constant()
	await test_place_ghost_nearest_corner(main)
	await test_move_uses_transport_measure(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_closest_edge_point(main) -> void:
	print("- closest_edge_point / closest_corner_point")
	var view: DocumentView = main.view
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO)
	var bb: Dictionary = view.doc.measure_bbox(id)
	check(not bb.is_empty(), "box has bbox")
	var center: Vector3 = (bb["min"] + bb["max"]) * 0.5
	var top := Vector3(center.x, center.y, bb["max"].z)
	var snapped := view.closest_edge_point(id, top)
	check(snapped.z == bb["max"].z or is_equal_approx(snapped.z, bb["max"].z),
			"snap stays on top z (%.3f)" % snapped.z)
	var outside: Vector3 = bb["max"] as Vector3 + Vector3(10, 10, 10)
	var edge_pt := view.closest_edge_point(id, outside)
	check(edge_pt.distance_to(outside) < outside.distance_to(center),
			"outside point snaps closer to the solid than the center")
	# Face-center hit should plant X on a corner of that face, not mid-edge.
	var face_hit := Vector3(center.x, center.y, bb["max"].z)
	var corner := view.closest_corner_point(id, face_hit)
	var mn: Vector3 = bb["min"]
	var mx: Vector3 = bb["max"]
	var on_corner := false
	for x in [mn.x, mx.x]:
		for y in [mn.y, mx.y]:
			if corner.distance_to(Vector3(x, y, mx.z)) < 1e-4:
				on_corner = true
	check(on_corner, "closest_corner_point lands on a top-face corner")
	check(corner.distance_to(face_hit) > 0.5, "corner ≠ face center")


func test_selection_bound_labels(main) -> void:
	print("- selection shows bound dimension labels")
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction
	view.new_document()
	var id: String = view.insert_primitive("box", Vector3.ZERO)
	view.select_entity(id, "")
	await process_frame
	var mo: MeasureOverlay = ix.measure_overlay
	check(mo != null, "measure overlay mounted")
	if mo != null:
		mo.refresh_bounds()
	var n: int = mo.labels.size() if mo != null else 0
	check(n >= 3, "three bound size labels (%d)" % n)
	check(mo != null and mo.segments.size() >= 3, "bound dimension segments present")


func test_hover_pair_pins_on_leave(main) -> void:
	print("- leave A pins X; B compares; only one pair")
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3(-40, 0, 0))
	var b: String = view.insert_primitive("box", Vector3(40, 0, 0))
	var c: String = view.insert_primitive("box", Vector3(0, 40, 0))
	var mo: MeasureOverlay = ix.measure_overlay
	mo.clear_all()

	var bb_a: Dictionary = view.doc.measure_bbox(a)
	var pt_a: Vector3 = bb_a["max"]
	mo.update_hover(a, pt_a)
	check(mo.has_anchor(), "touch A sets anchor X")
	check(mo.following, "still following on A")
	var pinned: Vector3 = mo.anchor_point as Vector3

	# Leave A into empty space — X must stick for B to compare against.
	mo.update_hover("", Vector3.ZERO)
	check(mo.has_anchor(), "X pinned after leaving A")
	check(not mo.following, "not following after leave")
	check(mo.anchor_point == pinned, "pinned point unchanged on leave")
	check(mo._last_b == null, "no B dims while in empty space")
	check(mo.marks.size() >= 1, "pinned X still in draw list")

	var bb_b: Dictionary = view.doc.measure_bbox(b)
	mo.update_hover(b, bb_b["min"] as Vector3)
	check(mo.anchor_body == a, "anchor stays on A")
	check(mo._last_b != null, "live B point set")
	var labels_ab: int = mo.labels.size()
	check(labels_ab >= 1, "pair shows measure labels (%d)" % labels_ab)

	var bb_c: Dictionary = view.doc.measure_bbox(c)
	mo.update_hover(c, bb_c["min"] as Vector3)
	check(mo.anchor_body == a, "third body does not grow a second anchor")
	check(mo.labels.size() <= labels_ab + 2, "still a single pair of labels")

	mo.update_hover("", Vector3.ZERO)
	check(mo.has_anchor(), "pinned X survives miss after B")
	check(mo._last_b == null, "live B dims hidden on miss")
	var has_delta := false
	for lab in mo.labels:
		if str(lab["text"]).begins_with("Δ"):
			has_delta = true
			break
	check(not has_delta, "no Δ cardinal labels after leaving B")

	# Dragging / mod hides measure chrome entirely.
	mo.update_hover(b, bb_b["min"] as Vector3)
	check(mo.is_showing_pair(), "pair armed again on B")
	ix._drag_mode = ViewportInteraction.DragMode.MOVE_BODY
	check(ix._is_modifying(), "move counts as modifying")
	ix._drag_mode = ViewportInteraction.DragMode.NONE


func test_esc_clears_pair(main) -> void:
	print("- Esc clears measure pair before selection")
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3(-30, 0, 0))
	var b: String = view.insert_primitive("box", Vector3(30, 0, 0))
	view.select_entity(a, "")
	var mo: MeasureOverlay = ix.measure_overlay
	mo.update_hover(a, view.doc.measure_bbox(a)["max"] as Vector3)
	mo.update_hover("", Vector3.ZERO)
	mo.update_hover(b, view.doc.measure_bbox(b)["min"] as Vector3)
	check(mo.has_anchor(), "pair armed")

	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	ix._gui_key(esc)
	check(not mo.has_anchor(), "Esc cleared measure pair")
	check(view.selected_body == a, "Esc cleared measure before selection")


func test_screen_frac_constant() -> void:
	print("- screen size fraction is 1/40")
	check(is_equal_approx(MeasureOverlay.SCREEN_FRAC, 1.0 / 40.0), "SCREEN_FRAC == 1/40")
	var h := 900.0
	var px := int(round(h * MeasureOverlay.SCREEN_FRAC))
	check(px == 23 or px == 22, "900px viewport → ~22–23px labels (%d)" % px)


func test_place_ghost_nearest_corner(main) -> void:
	print("- place measure uses nearest ghost corner")
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3(-40, 0, 0))
	var side: String = view.insert_primitive("box", Vector3(0, 40, 0))
	var mo: MeasureOverlay = ix.measure_overlay
	mo.clear_all()
	var bb_a: Dictionary = view.doc.measure_bbox(a)
	mo.update_hover(a, bb_a["max"] as Vector3)
	mo.update_hover("", Vector3.ZERO)
	check(mo.has_anchor(), "anchor pinned before place")

	ix.insert_at_center("box")
	await process_frame
	check(ix.is_placing(), "place armed")
	# Put the ghost well to the +X of the anchor (empty ground).
	ix._update_ghost(ix._model_to_screen(Vector3(40, 0, 0)))
	check(mo.is_showing_pair(), "pair dims while placing with anchor")
	var b: Vector3 = mo._last_b as Vector3
	var corners: Array[Vector3] = ix._ghost_corners()
	check(corners.size() == 8, "ghost has 8 corners")
	var nearest: Vector3 = ix._closest_ghost_corner(mo.anchor_point as Vector3)
	check(b.distance_to(nearest) < 1e-4, "live B is the nearest ghost corner")
	# Not the ghost center (unless degenerate).
	var center: Vector3 = ix._place_ghost.position
	check(b.distance_to(center) > 0.5, "corner ≠ ghost center")
	# Hover another solid while placing — X relocates onto that target.
	var bb_side: Dictionary = view.doc.measure_bbox(side)
	var side_center: Vector3 = (bb_side["min"] as Vector3 + bb_side["max"] as Vector3) * 0.5
	var side_screen: Vector2 = ix._model_to_screen(side_center)
	ix._update_ghost(side_screen)
	check(mo.anchor_body == side, "place hover relocates X onto target body")
	check(mo.following, "following X on target while hovering it")
	# Move ghost to empty ground — pin X and dim to nearest corner again.
	ix._update_ghost(ix._model_to_screen(Vector3(40, 0, 0)))
	check(mo.anchor_body == side, "X stays on last target after leaving it")
	check(mo.is_showing_pair(), "ghost corner dims resume after leave target")
	ix._disarm_place(false)
	check(mo.has_anchor(), "anchor survives disarm")
	check(not mo.is_showing_pair(), "live dims cleared on disarm")


func test_move_uses_transport_measure(main) -> void:
	print("- move uses place-like measure marks")
	var view: DocumentView = main.view
	var ix: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3(-40, 0, 0))
	var b: String = view.insert_primitive("box", Vector3(40, 0, 0))
	var mo: MeasureOverlay = ix.measure_overlay
	mo.clear_all()
	# Plant X on B, select A (the body we'll move).
	var bb_b: Dictionary = view.doc.measure_bbox(b)
	mo.relocate_anchor(b, (bb_b["min"] as Vector3 + bb_b["max"] as Vector3) * 0.5)
	mo.update_hover("", Vector3.ZERO)
	view.select_entity(a, "")
	await process_frame
	ix._update_transport_measure(ix._model_to_screen(Vector3(0, 0, 0)))
	check(mo.has_anchor(), "anchor kept with selection")
	check(mo.is_showing_pair(), "idle selection dims to moved body's corner")
	var idle_b: Vector3 = mo._last_b as Vector3
	var a_corners: Array[Vector3] = ix._transport_subject_corners()
	check(a_corners.size() == 8, "selected body has 8 corners")
	check(idle_b.distance_to(ix._closest_corner_of(a_corners, mo.anchor_point as Vector3) as Vector3) < 1e-3,
			"idle B is nearest corner of selected body")

	# Begin move and drag — measure stays visible; dims track live corners.
	ix._begin_move_body(ix._model_to_screen(Vector3(-40, 0, 2.5)), Vector3(-40, 0, 2.5))
	check(ix._drag_mode == ViewportInteraction.DragMode.MOVE_BODY, "move armed")
	check(not ix._hide_measure_chrome(), "measure chrome visible during move")
	ix._apply_live_move(Vector3(10, 0, 0))
	ix._update_transport_measure(ix._model_to_screen(Vector3(0, 0, 0)))
	check(mo.is_showing_pair(), "pair dims while moving")
	var live_corners: Array[Vector3] = ix._transport_subject_corners()
	var live_b: Vector3 = mo._last_b as Vector3
	check(live_b.distance_to(ix._closest_corner_of(live_corners, mo.anchor_point as Vector3) as Vector3) < 1e-3,
			"live B tracks moved corners")
	check(live_b.x > idle_b.x + 1.0, "moved corner advanced in +X")

	# Touch B again during move — X replants on B (skipped body is A).
	var b_center: Vector3 = (bb_b["min"] as Vector3 + bb_b["max"] as Vector3) * 0.5
	ix._update_transport_measure(ix._model_to_screen(b_center))
	check(mo.anchor_body == b, "touch during move relocates X onto other body")
	check(mo.following, "following X on other body during move")
	ix._drag_mode = ViewportInteraction.DragMode.NONE
	view.refresh()
