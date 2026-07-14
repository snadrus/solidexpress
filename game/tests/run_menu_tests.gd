# Headless tests for the File/Insert menus (AI context export, datum insertion)
# and camera projection toggle.
# Run: tools/godot/godot --headless --path game --script tests/run_menu_tests.gd
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
	print("menu tests")
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	test_insert_datums(main)
	test_export_context(main)
	test_projection_toggle(main)

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_insert_datums(main) -> void:
	print("- insert menu datums")
	check(main.view.doc.datum_list().size() == 0, "no datums initially")
	main._on_insert_menu(0)  # plane XY
	main._on_insert_menu(3)  # axis X
	main._on_insert_menu(6)  # point at origin
	var datums: Array = main.view.doc.datum_list()
	check(datums.size() == 3, "three datums after inserts")
	var kinds := {}
	for d in datums:
		kinds[d["kind"]] = true
		check(main.view.datum_node(d["id"]) != null, "datum rendered: " + str(d["kind"]))
	check(kinds.has("plane") and kinds.has("axis") and kinds.has("point"),
		"plane, axis, and point kinds present")


func test_export_context(main) -> void:
	print("- export AI context via file menu")
	main.view.insert_primitive("box", Vector3.ZERO)
	var path := OS.get_user_data_dir() + "/context_test.md"
	main._file_action = main.FileAction.EXPORT_CONTEXT
	main._on_file_selected(path)
	check(FileAccess.file_exists(path), "context markdown written")
	var text := FileAccess.get_file_as_string(path)
	check(text.contains("# Model context"), "has context header")
	check(text.contains("## Datums"), "includes datums section")
	check(text.contains("## Bodies"), "includes bodies section")
	DirAccess.remove_absolute(path)


func test_projection_toggle(main) -> void:
	print("- camera projection toggle")
	var cam: OrbitCamera = main.camera
	check(cam.projection == Camera3D.PROJECTION_PERSPECTIVE, "starts perspective")
	cam.toggle_projection()
	check(cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "toggles to orthographic")
	var expected := 2.0 * cam.distance * tan(deg_to_rad(cam.fov) / 2.0)
	check(absf(cam.size - expected) < 0.01, "ortho size matches perspective frustum at pivot")
	var size_before: float = cam.size
	cam.distance *= 0.5
	cam._update_transform()
	check(cam.size < size_before, "wheel zoom shrinks ortho frustum")
	cam.toggle_projection()
	check(cam.projection == Camera3D.PROJECTION_PERSPECTIVE, "toggles back to perspective")
