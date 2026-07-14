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
	test_dirty_guard(main)
	test_recent_files(main)

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


func test_dirty_guard(main) -> void:
	print("- unsaved changes discard guard")
	# Fresh empty document is not dirty.
	main.view.new_document()
	main.current_path = ""
	main._last_saved_revision = main.view.doc.revision()
	var ran := {"ok": false}
	main._confirm_discard(func() -> void: ran["ok"] = true)
	check(ran["ok"], "confirm_discard runs immediately when clean")
	check(not main.confirm_dialog.visible, "dialog hidden when not dirty")

	main.view.insert_primitive("box", Vector3.ZERO)
	check(main.view.doc.revision() != main._last_saved_revision, "insert marks document dirty")
	check(main.view.doc.body_ids().size() > 0, "document has a body")

	main._on_file_menu(0)  # guarded New
	check(main.confirm_dialog.visible, "dirty New shows confirm dialog")
	check(main.view.doc.body_ids().size() > 0, "document not cleared before confirm")

	main.confirm_dialog.confirmed.emit()
	check(main.view.doc.body_ids().size() == 0, "document cleared after confirm")
	check(main.current_path == "", "New clears path after confirm")


func test_recent_files(main) -> void:
	print("- recent files list")
	main.view.new_document()
	main.current_path = ""
	main._last_saved_revision = main.view.doc.revision()
	main._recent.clear()
	main._save_recent()
	main._rebuild_recent_menu()

	main.view.insert_primitive("box", Vector3.ZERO)
	var path_a := OS.get_user_data_dir() + "/recent_a.sxp"
	var path_b := OS.get_user_data_dir() + "/recent_b.sxp"
	main._file_action = main.FileAction.SAVE_AS
	main._on_file_selected(path_a)
	check(main._recent.has(path_a), "recent list contains first save")
	var item_texts: PackedStringArray = []
	for i in range(main._recent_menu.item_count):
		if not main._recent_menu.is_item_separator(i):
			item_texts.append(main._recent_menu.get_item_text(i))
	check(item_texts.has(path_a), "recent submenu lists first save")

	main._file_action = main.FileAction.SAVE_AS
	main._on_file_selected(path_b)
	check(main._recent.size() >= 2, "recent has two entries")
	check(main._recent[0] == path_b, "most recent save is first")
	check(main._recent[1] == path_a, "older save is second")

	main._on_recent_menu(main._RECENT_CLEAR_ID)
	check(main._recent.is_empty(), "clear recent empties list")
	var only_clear := true
	for i in range(main._recent_menu.item_count):
		if main._recent_menu.is_item_separator(i):
			continue
		if main._recent_menu.get_item_id(i) != main._RECENT_CLEAR_ID:
			only_clear = false
	check(only_clear, "submenu only has Clear Recent after clear")

	DirAccess.remove_absolute(path_a)
	DirAccess.remove_absolute(path_b)
