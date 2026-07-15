# Headless tests for multi-select (Shift/Ctrl+click via select_ray additive)
# and empty-click deselection.
# Run: tools/godot/godot --headless --path game --script tests/run_select_tests.gd
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
	print("multi-select tests")
	# Tiny default headless size makes stretch/rotate grips fill the viewport.
	root.size = Vector2i(1280, 720)
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_additive_bodies(main)
	test_additive_faces(main)
	test_additive_edges_and_fillet(main)
	test_single_select_resets(main)
	await test_shift_click_event_path(main)
	test_empty_click_deselect(main)
	test_jitter_reselect_after_deselect(main)
	await test_chrome_hover_does_not_block_empty_input(main)
	test_shift_empty_keeps_selection(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _ray_at(x: float, y: float) -> Array:
	return [Vector3(x, y, 200), Vector3(0, 0, -1)]


func _screen_miss(main) -> Vector2:
	# Far from bodies in screen space.
	return Vector2(20, 20)


func test_additive_bodies(main) -> void:
	print("- additive body selection")
	var view: DocumentView = main.view
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)          # -25..25
	var b: String = view.insert_primitive("box", Vector3(100, 0, 0))    # 75..125
	view.clear_selection()

	var r := _ray_at(0, 0)
	check(view.select_ray(r[0], r[1]), "click selects body A")
	check(view.selected_body == a, "primary is A")
	r = _ray_at(100, 0)
	check(view.select_ray(r[0], r[1], true), "additive click adds body B")
	check(view.selected_bodies.has(a) and view.selected_bodies.has(b), "both bodies in set")
	check(view.selected_body == b, "primary follows last added")
	check(view.selection_size() == 2, "selection size 2")

	# Additive click B again toggles it off.
	check(view.select_ray(r[0], r[1], true), "additive click toggles B off")
	check(not view.selected_bodies.has(b), "B removed")
	check(view.selected_body == a, "primary falls back to A")


func test_additive_faces(main) -> void:
	print("- additive face selection")
	var view: DocumentView = main.view
	view.new_document()
	# Explicit 50 mm box so side-face ray and shell volume stay stable.
	var a: String = view.insert_primitive("box", Vector3.ZERO, Vector3(50, 50, 50))
	view.select_entity(a, "")
	# Additive click the top face of the already-selected body refines to a face.
	var r := _ray_at(0, 0)
	check(view.select_ray(r[0], r[1], true), "additive click on selected body picks face")
	check(view.selected_faces.size() == 1, "one face in set")
	check(view.selected_face != "", "primary face set")
	# Additive click a side face adds a second face.
	var side := [Vector3(200, 0, 25), Vector3(-1, 0, 0)]
	check(view.select_ray(side[0], side[1], true), "additive click side face")
	check(view.selected_faces.size() == 2, "two faces in set")

	# Multi-face shell through the ops panel.
	main.ops_panel._thickness_spin.value = 2.0
	main.ops_panel._shell()
	var vol: float = view.doc.body_volume(a)
	# Two open faces: thinner than a one-face shell, thicker than empty.
	check(vol > 15000.0 and vol < 30000.0, "multi-face shell applied (vol %.0f)" % vol)


func test_additive_edges_and_fillet(main) -> void:
	print("- additive edge selection + multi-edge fillet")
	var view: DocumentView = main.view
	view.new_document()
	# Explicit 50 mm box so fillet volume math stays stable.
	var a: String = view.insert_primitive("box", Vector3.ZERO, Vector3(50, 50, 50))
	view.select_entity(a, "")
	# Box spans -25..25 in x/y, 0..50 in z. Vertical edge at (25, 25) and (25, -25):
	# aim rays at two vertical edges (diagonal direction hits the corner line).
	var hits := 0
	for corner in [Vector3(25, 25, 25), Vector3(25, -25, 25)]:
		var origin: Vector3 = corner + Vector3(30, 30.0 if corner.y > 0 else -30.0, 0)
		var dir: Vector3 = (corner - origin).normalized()
		if view.select_ray(origin, dir, true):
			hits += 1
	check(hits == 2, "two additive clicks near corners hit")
	check(view.selected_edges.size() == 2, "two edges in set (got %d)" % view.selected_edges.size())

	var vol_before: float = view.doc.body_volume(a)
	main.ops_panel._radius_spin.value = 3.0
	main.ops_panel._fillet_all()
	var vol_after: float = view.doc.body_volume(a)
	# Two convex vertical edges filleted r=3, h=50: removes 2 * (9 - pi 9/4) * 50.
	# OCCT rolls the fillet around the edge ends, removing slightly more than
	# the ideal prism formula — allow 10%.
	var expected := 2.0 * (9.0 - PI * 9.0 / 4.0) * 50.0
	check(absf((vol_before - vol_after) - expected) < expected * 0.10,
		"multi-edge fillet removed ~%.0f mm^3 (got %.0f)" % [expected, vol_before - vol_after])


func test_single_select_resets(main) -> void:
	print("- plain click resets multi-select")
	var view: DocumentView = main.view
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	var b: String = view.insert_primitive("box", Vector3(100, 0, 0))
	view.clear_selection()
	var ra := _ray_at(0, 0)
	var rb := _ray_at(100, 0)
	view.select_ray(ra[0], ra[1])
	view.select_ray(rb[0], rb[1], true)
	check(view.selection_size() == 2, "two selected before plain click")
	view.select_ray(ra[0], ra[1])
	check(view.selection_size() == 1 and view.selected_body == a, "plain click collapses to A")
	view.clear_selection()
	check(view.selection_size() == 0 and view.selected_bodies.is_empty(), "clear empties sets")
	check(b != "", "b silences unused warning")


## Shift+click through the real input path (`_input`) toggles additive selection
## and never arms a body drag.
func test_shift_click_event_path(main) -> void:
	print("- shift+click via viewport input")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	var b: String = view.insert_primitive("box", Vector3(100, 0, 0))
	view.clear_selection()
	view.select_entity(a, "")
	root.size = Vector2i(1280, 720)
	vi.size = Vector2(1280, 720)
	main.camera.frame_contents()
	await process_frame

	# Screen position of body B's center, then a synthetic Shift+LMB click.
	var half_b := DocumentView.DEFAULT_PRIMITIVE_MM * 0.5
	var center_b: Vector3 = main.model_space.to_global(Vector3(100, 0, half_b))
	var screen_b: Vector2 = main.camera.unproject_position(center_b)
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.shift_pressed = true
		mb.position = screen_b
		vi._input(mb)
	check(view.selection_size() == 2, "shift+click added B (size %d)" % view.selection_size())
	check(view.selected_bodies.has(a) and view.selected_bodies.has(b), "both bodies selected")


func _find_empty_screen(main, view: DocumentView, vi: ViewportInteraction) -> Vector2:
	# Headless Interaction can stay 64² unless forced; back the camera off so
	# stretch/rotate grips don't cover the viewport corners.
	root.size = Vector2i(1280, 720)
	vi.size = Vector2(1280, 720)
	main.camera.distance = 800.0
	main.camera.pivot = Vector3.ZERO
	main.camera._update_transform()
	var sz := Vector2(1280, 720)
	var candidates: Array[Vector2] = []
	for x in [8.0, 32.0, sz.x * 0.5, sz.x - 32.0, sz.x - 8.0]:
		for y in [8.0, 32.0, sz.y - 32.0, sz.y - 8.0]:
			candidates.append(Vector2(x, y))
	for candidate in candidates:
		var ray := vi._model_ray(candidate)
		if not view.pick_info(ray[0], ray[1]).is_empty():
			continue
		if not vi._pick_rotate_grip(candidate).is_empty():
			continue
		if not vi._pick_resize_handle(candidate).is_empty():
			continue
		return candidate
	push_error("no empty screen point found")
	return Vector2(-1, -1)


func test_empty_click_deselect(main) -> void:
	print("- empty click clears selection")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	view.select_entity(a, "")
	check(view.selected_body == a, "body selected before empty click")
	var miss := _find_empty_screen(main, view, vi)
	check(miss.x >= 0.0, "found empty screen point for deselect")
	var ray_miss := vi._model_ray(miss)
	check(view.pick_info(ray_miss[0], ray_miss[1]).is_empty(), "miss is empty space")
	check(vi._pick_rotate_grip(miss).is_empty(), "miss not on rotate grip")
	check(vi._pick_resize_handle(miss).is_empty(), "miss not on stretch grip")
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.position = miss
		vi._gui_input(mb)
	check(view.selected_body == "", "empty click cleared selection")
	check(view.selection_size() == 0, "selection size 0 after empty click")


func test_jitter_reselect_after_deselect(main) -> void:
	print("- trackpad-jitter click still selects / deselects")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	view.clear_selection()
	var half := DocumentView.DEFAULT_PRIMITIVE_MM * 0.5
	var center: Vector3 = main.model_space.to_global(Vector3(0, 0, half))
	var screen: Vector2 = main.camera.unproject_position(center)
	# Drive via `_input` (live app path) — press on body, release with jitter.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen
	vi._input(press)
	var mm := InputEventMouseMotion.new()
	mm.position = screen + Vector2(10, 4)
	vi._input(mm)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = screen + Vector2(10, 4)
	vi._input(release)
	check(view.selected_body == a, "jittered click still selected body via _input")

	# Soft empty orbit (12–20px) should still deselect.
	var miss := _find_empty_screen(main, view, vi)
	press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = miss
	vi._input(press)
	mm = InputEventMouseMotion.new()
	mm.position = miss + Vector2(16, 0)
	vi._input(mm)
	release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = miss + Vector2(16, 0)
	vi._input(release)
	check(view.selected_body == "", "soft empty orbit still deselects via _input")

	# Empty-space drag via `_input` should arm ORBIT_VIEW.
	view.select_entity(a, "")
	press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = miss
	vi._input(press)
	mm = InputEventMouseMotion.new()
	mm.position = miss + Vector2(40, 0)
	vi._input(mm)
	check(vi._drag_mode == ViewportInteraction.DragMode.ORBIT_VIEW, "empty drag via _input arms orbit")
	release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = miss + Vector2(40, 0)
	vi._input(release)
	check(vi._drag_mode == ViewportInteraction.DragMode.NONE, "orbit cleared on release")


## Regression: stale TransformHud / SelectionStrip hover must not block empty-space
## LMB via `_input` when the click is outside chrome rects.
func test_chrome_hover_does_not_block_empty_input(main) -> void:
	print("- chrome hover does not block empty _input")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	view.select_entity(a, "")
	root.size = Vector2i(1280, 720)
	vi.size = Vector2(1280, 720)
	main.camera.frame_contents()
	await process_frame
	check(vi._selection_strip.visible, "selection strip visible after select")
	var miss := _find_empty_screen(main, view, vi)
	check(miss.x >= 0.0, "found empty screen point")
	check(not vi._over_chrome(miss), "miss is outside chrome rects")
	# Park the cursor over the strip so gui hover is our chrome, not empty space.
	var strip_center := vi._selection_strip.get_global_rect().get_center()
	var hover := InputEventMouseMotion.new()
	hover.position = strip_center
	vi.get_viewport().push_input(hover)
	await process_frame
	var h: Control = vi.get_viewport().gui_get_hovered_control()
	check(h != null and vi.is_ancestor_of(h), "cursor hover is interaction chrome")
	check(vi._viewport_owns_pointer(miss), "empty miss still owns pointer despite chrome hover")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = miss
	vi._input(press)
	var mm := InputEventMouseMotion.new()
	mm.position = miss + Vector2(16, 0)
	vi._input(mm)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = miss + Vector2(16, 0)
	vi._input(release)
	check(view.selected_body == "", "soft empty orbit deselects with chrome hover")


func test_shift_empty_keeps_selection(main) -> void:
	print("- shift+empty click keeps selection")
	var view: DocumentView = main.view
	var vi: ViewportInteraction = main.interaction
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	view.select_entity(a, "")
	var miss := _screen_miss(main)
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.shift_pressed = true
		mb.position = miss
		vi._gui_input(mb)
	check(view.selected_body == a, "shift+empty kept selection")
	check(view.selection_size() == 1, "selection size still 1")
