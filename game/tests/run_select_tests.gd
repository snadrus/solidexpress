# Headless tests for multi-select (Ctrl+click semantics via select_ray additive).
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
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_additive_bodies(main)
	test_additive_faces(main)
	test_additive_edges_and_fillet(main)
	test_single_select_resets(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _ray_at(x: float, y: float) -> Array:
	return [Vector3(x, y, 200), Vector3(0, 0, -1)]


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
	check(view.select_ray(r[0], r[1], true), "ctrl+click adds body B")
	check(view.selected_bodies.has(a) and view.selected_bodies.has(b), "both bodies in set")
	check(view.selected_body == b, "primary follows last added")
	check(view.selection_size() == 2, "selection size 2")

	# Ctrl+click B again toggles it off.
	check(view.select_ray(r[0], r[1], true), "ctrl+click toggles B off")
	check(not view.selected_bodies.has(b), "B removed")
	check(view.selected_body == a, "primary falls back to A")


func test_additive_faces(main) -> void:
	print("- additive face selection")
	var view: DocumentView = main.view
	view.new_document()
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	view.select_entity(a, "")
	# Ctrl+click the top face of the already-selected body refines to a face.
	var r := _ray_at(0, 0)
	check(view.select_ray(r[0], r[1], true), "ctrl+click on selected body picks face")
	check(view.selected_faces.size() == 1, "one face in set")
	check(view.selected_face != "", "primary face set")
	# Ctrl+click a side face adds a second face.
	var side := [Vector3(200, 0, 25), Vector3(-1, 0, 0)]
	check(view.select_ray(side[0], side[1], true), "ctrl+click side face")
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
	var a: String = view.insert_primitive("box", Vector3.ZERO)
	view.select_entity(a, "")
	# Box spans -25..25 in x/y, 0..50 in z. Vertical edge at (25, 25) and (25, -25):
	# aim rays at two vertical edges (diagonal direction hits the corner line).
	var hits := 0
	for corner in [Vector3(25, 25, 25), Vector3(25, -25, 25)]:
		var origin: Vector3 = corner + Vector3(30, 30.0 if corner.y > 0 else -30.0, 0)
		var dir: Vector3 = (corner - origin).normalized()
		if view.select_ray(origin, dir, true):
			hits += 1
	check(hits == 2, "two ctrl+clicks near corners hit")
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
