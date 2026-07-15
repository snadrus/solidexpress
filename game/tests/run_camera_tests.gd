# Headless tests for OrbitCamera zoom-toward-cursor.
# Run: tools/godot/godot --headless --path game --script tests/run_camera_tests.gd
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
	print("orbit camera zoom tests")
	root.size = Vector2i(800, 600)
	var cam := OrbitCamera.new()
	cam.name = "OrbitCamera"
	root.add_child(cam)
	await process_frame
	await process_frame
	check(is_equal_approx(cam.distance, OrbitCamera.DEFAULT_DISTANCE),
		"empty scene starts at DEFAULT_DISTANCE (%.1f mm)" % OrbitCamera.DEFAULT_DISTANCE)

	test_zoom_at_center(cam)
	test_zoom_off_center_moves_pivot(cam)
	test_repeated_zoom_converges(cam)
	test_distance_clamp(cam)
	test_orthographic_zoom(cam)
	test_zero_viewport_guard()
	test_scroll_gestures_gated(cam)
	test_nav_presets_and_fit(cam)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _reset_cam(cam: OrbitCamera) -> void:
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.pivot = Vector3.ZERO
	cam.distance = 400.0
	cam.yaw = deg_to_rad(-35.0)
	cam.pitch = deg_to_rad(30.0)
	cam._update_transform()


func test_zoom_at_center(cam: OrbitCamera) -> void:
	print("- zoom at viewport center leaves pivot ~unchanged")
	_reset_cam(cam)
	var center := root.size * 0.5
	var pivot_before := cam.pivot
	cam.zoom_at(center, 0.9)
	check(cam.pivot.distance_to(pivot_before) < 1e-3, "center zoom-in pivot unchanged")
	check(is_equal_approx(cam.distance, 400.0 * 0.9), "center zoom-in scales distance")
	cam.zoom_at(center, 1.0 / 0.9)
	check(cam.pivot.distance_to(pivot_before) < 1e-3, "center zoom-out pivot unchanged")
	check(is_equal_approx(cam.distance, 400.0), "center zoom-out restores distance")


func test_zoom_off_center_moves_pivot(cam: OrbitCamera) -> void:
	print("- zoom-in off-center moves pivot toward anchor")
	_reset_cam(cam)
	var screen := Vector2(root.size.x * 0.8, root.size.y * 0.3)
	var anchor_before := cam._zoom_anchor(screen)
	var pivot_before := cam.pivot
	var to_anchor := anchor_before - pivot_before
	check(to_anchor.length() > 1.0, "off-center screen has non-trivial anchor offset")
	cam.zoom_at(screen, 0.9)
	var expected := pivot_before + (1.0 - 0.9) * to_anchor
	check(cam.pivot.distance_to(expected) < 1e-2, "pivot shifted by (1-k)*to_anchor")
	var moved_toward := (cam.pivot - pivot_before).dot(to_anchor.normalized())
	check(moved_toward > 0.0, "pivot moved toward anchor on zoom-in")
	check(is_equal_approx(cam.distance, 400.0 * 0.9), "off-center zoom scales distance")


func test_repeated_zoom_converges(cam: OrbitCamera) -> void:
	print("- repeated zoom-in converges toward anchor / MIN_DISTANCE")
	_reset_cam(cam)
	var screen := Vector2(root.size.x * 0.75, root.size.y * 0.25)
	var first_anchor := cam._zoom_anchor(screen)
	var prev_dist_to_anchor := cam.pivot.distance_to(first_anchor)
	for i in 80:
		cam.zoom_at(screen, 0.9)
	check(is_equal_approx(cam.distance, OrbitCamera.MIN_DISTANCE), "distance clamped at MIN_DISTANCE")
	check(cam.pivot.distance_to(first_anchor) < prev_dist_to_anchor, "pivot closer to original anchor region")
	# Further zooms at the same point should not push distance below MIN.
	var d_at_min := cam.distance
	cam.zoom_at(screen, 0.9)
	check(is_equal_approx(cam.distance, d_at_min), "further zoom stays at MIN_DISTANCE")


func test_distance_clamp(cam: OrbitCamera) -> void:
	print("- zoom respects MIN/MAX distance clamp")
	_reset_cam(cam)
	var center := root.size * 0.5
	cam.distance = OrbitCamera.MIN_DISTANCE
	cam._update_transform()
	cam.zoom_at(center, 0.9)
	check(is_equal_approx(cam.distance, OrbitCamera.MIN_DISTANCE), "cannot zoom below MIN_DISTANCE")

	cam.distance = OrbitCamera.MAX_DISTANCE
	cam._update_transform()
	cam.zoom_at(center, 1.0 / 0.9)
	check(is_equal_approx(cam.distance, OrbitCamera.MAX_DISTANCE), "cannot zoom above MAX_DISTANCE")


func test_orthographic_zoom(cam: OrbitCamera) -> void:
	print("- zoom toward cursor works in orthographic")
	_reset_cam(cam)
	cam.toggle_projection()
	check(cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "projection is orthographic")
	var screen := Vector2(root.size.x * 0.2, root.size.y * 0.7)
	var pivot_before := cam.pivot
	var anchor := cam._zoom_anchor(screen)
	var to_anchor := anchor - pivot_before
	check(to_anchor.length() > 1.0, "ortho off-center anchor offset non-trivial")
	var dist_before := cam.distance
	cam.zoom_at(screen, 0.9)
	check(is_equal_approx(cam.distance, dist_before * 0.9), "ortho zoom scales distance")
	var expected := pivot_before + (1.0 - 0.9) * to_anchor
	check(cam.pivot.distance_to(expected) < 1e-2, "ortho pivot shifted toward anchor")
	# size tracks distance in ortho.
	var expected_size := 2.0 * cam.distance * tan(deg_to_rad(cam.fov) / 2.0)
	check(is_equal_approx(cam.size, expected_size), "ortho size matches distance")


func test_zero_viewport_guard() -> void:
	print("- missing / zero viewport defaults anchor to pivot (no shift)")
	# Headless Godot clamps Window size to a minimum (~64), so size (0,0) cannot
	# be forced via root.size. An orphan camera has no viewport → same guard path.
	var orphan := OrbitCamera.new()
	orphan.pivot = Vector3(10.0, 20.0, 30.0)
	orphan.distance = 400.0
	orphan.yaw = 0.0
	orphan.pitch = 0.0
	orphan._update_transform()
	check(
		orphan._zoom_anchor(Vector2(100, 100)).is_equal_approx(orphan.pivot),
		"anchor defaults to pivot without viewport"
	)
	var pivot_before := orphan.pivot
	orphan.zoom_at(Vector2(100, 100), 0.9)
	check(orphan.pivot.is_equal_approx(pivot_before), "no pivot shift without viewport")
	check(is_equal_approx(orphan.distance, 400.0 * 0.9), "distance still scales without viewport")
	orphan.free()


func test_scroll_gestures_gated(cam: OrbitCamera) -> void:
	print("- wheel / pan ignored when allow_scroll_gestures=false")
	_reset_cam(cam)
	var yaw0 := cam.yaw
	var dist0 := cam.distance
	var pan := InputEventPanGesture.new()
	pan.delta = Vector2(25, 0)
	check(not cam.is_nav_event(pan, false), "pan gesture not nav over scroll UI")
	check(not cam.handle_input(pan, false), "pan gesture not handled over scroll UI")
	check(is_equal_approx(cam.yaw, yaw0), "yaw unchanged after blocked pan")

	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(100, 100)
	check(not cam.is_nav_event(wheel, false), "wheel not nav over scroll UI")
	check(not cam.handle_input(wheel, false), "wheel not handled over scroll UI")
	check(is_equal_approx(cam.distance, dist0), "distance unchanged after blocked wheel")

	check(cam.is_nav_event(pan, true), "pan gesture is nav when scroll allowed")
	check(cam.handle_input(pan, true), "pan gesture handled when scroll allowed")
	check(absf(cam.yaw - yaw0) > 1e-4, "yaw changes when pan allowed")

	# Pinch-zoom must keep working even when pan/wheel are gated for docks.
	_reset_cam(cam)
	dist0 = cam.distance
	var pinch := InputEventMagnifyGesture.new()
	pinch.factor = 1.1  # pinch out → zoom in
	check(cam.is_nav_event(pinch, false), "magnify is nav even over scroll UI")
	check(cam.handle_input(pinch, false), "magnify handled even over scroll UI")
	check(cam.distance < dist0, "pinch-out zooms in (distance %.1f → %.1f)" % [dist0, cam.distance])

	# Ctrl+pan is a Linux fallback when MagnifyGesture is absent (XWayland).
	_reset_cam(cam)
	dist0 = cam.distance
	var ctrl_pan := InputEventPanGesture.new()
	ctrl_pan.ctrl_pressed = true
	ctrl_pan.delta = Vector2(0, -40)  # drag up → zoom in
	check(cam.is_nav_event(ctrl_pan, false), "ctrl+pan is nav even over scroll UI")
	check(cam.handle_input(ctrl_pan, false), "ctrl+pan zoom handled")
	check(cam.distance < dist0, "ctrl+pan zooms in (distance %.1f → %.1f)" % [dist0, cam.distance])


func test_nav_presets_and_fit(cam: OrbitCamera) -> void:
	print("- nav presets + selection fit helpers")
	check(cam._want_pan(false) == false, "SX: middle without shift = orbit")
	check(cam._want_pan(true) == true, "SX: Shift+middle = pan")
	cam.nav_preset = OrbitCamera.NavPreset.FUSION
	check(cam._want_pan(false) == true, "Fusion: middle without shift = pan")
	check(cam._want_pan(true) == false, "Fusion: Shift+middle = orbit")
	cam.nav_preset = OrbitCamera.NavPreset.SOLIDWORKS
	check(cam._want_pan(false) == false, "SW: middle = orbit")
	cam.nav_preset = OrbitCamera.NavPreset.SOLIDEXPRESS

	# Double-middle is claimed as a nav event.
	var dbl := InputEventMouseButton.new()
	dbl.button_index = MOUSE_BUTTON_MIDDLE
	dbl.pressed = true
	dbl.double_click = true
	dbl.position = Vector2(100, 100)
	check(cam.is_nav_event(dbl, true), "double-middle is a nav event")
	check(cam.handle_input(dbl, true), "double-middle handled (empty scene fit)")

	# frame_selection returns false without a selection/view.
	check(not cam.frame_selection(), "frame_selection false without selection")
