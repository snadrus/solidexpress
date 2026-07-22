class_name FilmUI
extends RefCounted

const FilmUICues = preload("res://tests/lib/film_ui_cues.gd")

## Drive real UI for movies: pointer + shortcuts mirror what users do with mouse and keys.


static func wait_frames(tree: SceneTree, n: int = 1) -> void:
	for _i in n:
		await tree.process_frame


static func find_button(root: Node, text: String) -> Button:
	for c in root.find_children("*", "Button", true, false):
		if str(c.text) == text:
			return c as Button
	# Icon-only buttons keep the label in the tooltip.
	for c in root.find_children("*", "Button", true, false):
		var tip := str(c.tooltip_text)
		if tip == text or tip.begins_with(text):
			return c as Button
	return null


static func _cue_click(ctx: FilmContext, screen_pos: Vector2, cue: Dictionary) -> void:
	var keys := str(cue.get("keys", "Click"))
	var desc := str(cue.get("desc", ""))
	await ctx.chrome.animate_pointer_click(screen_pos, keys, desc)


static func click_button(ctx: FilmContext, text: String, cue: Dictionary = {}) -> void:
	var b := find_button(ctx.main, text)
	if b == null:
		push_warning("FilmUI: button not found: %s" % text)
		return
	var c := cue if not cue.is_empty() else FilmUICues.alert(text, text)
	await _cue_click(ctx, b.get_global_rect().get_center(), c)
	b.pressed.emit()
	await wait_frames(ctx.tree, 2)


static func select_sketch_tool(ctx: FilmContext, sm: SketchMode, tool: int) -> void:
	var label := ""
	match tool:
		SketchMode.Tool.LINE:
			label = "Line"
		SketchMode.Tool.CIRCLE:
			label = "Circle"
		SketchMode.Tool.SPLINE:
			label = "Spline"
		SketchMode.Tool.SMART_DIM:
			label = "Smart Dimension"
		SketchMode.Tool.EXTEND:
			label = "Extend"
		_:
			sm.set_tool(tool)
			return
	var b := find_button(ctx.main, label)
	if b != null:
		await _cue_click(ctx, b.get_global_rect().get_center(), FilmUICues.tool_keys(tool))
		b.pressed.emit()
	else:
		sm.set_tool(tool)
	await wait_frames(ctx.tree, 2)


static func click_sketch(ctx: FilmContext, sm: SketchMode, uv: Vector2, desc: String = "Place sketch point") -> void:
	await _cue_click(ctx, _sketch_uv_to_screen(ctx, uv), FilmUICues.sketch_click(desc))
	sm.click(uv)
	await wait_frames(ctx.tree, 3)


static func set_sketch_dim(ctx: FilmContext, value: float) -> void:
	var chrome = ctx.main.sketch_chrome
	if chrome != null and chrome.has_method("set_dim_value"):
		chrome.set_dim_value(value)
	var cue := FilmUICues.dim_value(value)
	ctx.chrome.show_action_alert(str(cue.keys), str(cue.desc))
	await wait_frames(ctx.tree, 2)
	if chrome != null and chrome.has_signal("action_chosen"):
		chrome.action_chosen.emit("dimension")
	await wait_frames(ctx.tree, 2)


static func enter_sketch(ctx: FilmContext) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm != null and sm.active:
		await wait_frames(ctx.tree, 2)
		return
	var b := find_button(ctx.main, "Sketch")
	if b != null:
		await _cue_click(ctx, b.get_global_rect().get_center(), FilmUICues.toolbar_sketch())
		await wait_frames(ctx.tree, 1)
	if ctx.main.has_method("_start_sketch"):
		ctx.main._start_sketch()
	elif ctx.main.has_method("_start_sketch_on_ground"):
		ctx.main._start_sketch_on_ground()
	await wait_frames(ctx.tree, 4)
	if ctx.main.sketch_chrome != null:
		ctx.main.sketch_chrome.show_for_session(true)


static func enter_sketch_on_plane(ctx: FilmContext, origin: Vector3, x_dir: Vector3, y_dir: Vector3) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	if sm == null:
		return
	if sm.active:
		sm.exit_sketch()
		await wait_frames(ctx.tree, 3)
	if sm.has_method("begin_on_plane"):
		sm.begin_on_plane(origin, x_dir, y_dir)
	else:
		push_warning("FilmUI: begin_on_plane missing - vertical leg may fail")
		return
	await wait_frames(ctx.tree, 4)
	if ctx.main.sketch_chrome != null:
		ctx.main.sketch_chrome.show_for_session(true)


static func exit_sketch(ctx: FilmContext) -> String:
	var sm: SketchMode = ctx.main.sketch_mode
	var fid := ""
	if sm != null and sm.active:
		fid = sm.exit_sketch()
	await click_button(ctx, "Exit Sketch", FilmUICues.exit_sketch())
	await wait_frames(ctx.tree, 3)
	if fid == "":
		fid = last_feature_id(ctx.view.doc, "sketch")
	return fid


static func merge_sketches_ui(ctx: FilmContext, mode: String) -> void:
	var action := "merge_join"
	match mode:
		"join_endpoints", "merge_join":
			action = "merge_join"
		"bridge_spline", "merge_spline":
			action = "merge_spline"
		"composite", "merge_composite":
			action = "merge_composite"
	var sk_chrome: SketchContextChrome = ctx.main.sketch_chrome
	var chip_label := action.capitalize().replace("_", " ")
	if sk_chrome != null:
		var vp := ctx.tree.root.get_viewport().get_visible_rect()
		sk_chrome.show_merge_menu(vp.size * Vector2(0.52, 0.48))
		await wait_frames(ctx.tree, 3)
		var merge_btn := find_button(sk_chrome, chip_label)
		if merge_btn != null:
			await _cue_click(ctx, merge_btn.get_global_rect().get_center(), FilmUICues.merge_join())
			merge_btn.pressed.emit()
			await wait_frames(ctx.tree, 4)
			ctx.chrome.clear_keys()
			return
	if ctx.main.has_method("_on_sketch_action"):
		ctx.chrome.show_action_alert("Click", FilmUICues.merge_join().desc)
		ctx.main._on_sketch_action(action)
	await wait_frames(ctx.tree, 4)
	ctx.chrome.clear_keys()


static func select_sketch_pad_ctrl(ctx: FilmContext, feature_id: String) -> void:
	if feature_id.is_empty():
		return
	var screen_pos := pad_screen_center(ctx, feature_id)
	if screen_pos != Vector2.ZERO:
		await _cue_click(ctx, screen_pos, FilmUICues.ctrl_pad())
	var pads: Array = ctx.main.selected_sketch_pads
	if feature_id not in pads:
		pads.append(feature_id)
	ctx.main.selected_sketch_pads = pads
	if ctx.main.has_method("_refresh_merge_chrome"):
		ctx.main._refresh_merge_chrome()
	await wait_frames(ctx.tree, 3)


static func clear_pad_selection(ctx: FilmContext) -> void:
	ctx.main.selected_sketch_pads.clear()
	if ctx.main.has_method("_refresh_merge_chrome"):
		ctx.main._refresh_merge_chrome()


static func last_feature_id(doc: SxDocument, type_filter: String = "") -> String:
	var feats: Array = doc.graph_features()
	for i in range(feats.size() - 1, -1, -1):
		var f: Dictionary = feats[i]
		var ty := str(f.get("type", ""))
		if type_filter == "" or ty == type_filter:
			return str(f.get("id", ""))
	return ""


static func draw_line(ctx: FilmContext, sm: SketchMode, a: Vector2, b: Vector2) -> void:
	await select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await click_sketch(ctx, sm, a, "Line — first point")
	await click_sketch(ctx, sm, b, "Line — second point")


static func draw_polyline(ctx: FilmContext, sm: SketchMode, points: PackedVector2Array) -> void:
	if points.size() < 2:
		return
	await select_sketch_tool(ctx, sm, SketchMode.Tool.LINE)
	await click_sketch(ctx, sm, points[0], "Line — start")
	for i in range(1, points.size()):
		await click_sketch(ctx, sm, points[i], "Line — next point")


static func draw_spline_through(ctx: FilmContext, sm: SketchMode, points: PackedVector2Array) -> void:
	if points.size() < 2:
		return
	await select_sketch_tool(ctx, sm, SketchMode.Tool.SPLINE)
	for i in range(points.size()):
		var hint := "Spline — point %d" % (i + 1)
		await click_sketch(ctx, sm, points[i], hint)
	if sm.has_method("end_chain"):
		sm.end_chain()
	await wait_frames(ctx.tree, 3)


static func draw_circle(ctx: FilmContext, sm: SketchMode, center: Vector2, rim: Vector2) -> void:
	await select_sketch_tool(ctx, sm, SketchMode.Tool.CIRCLE)
	await click_sketch(ctx, sm, center, "Circle — center")
	await click_sketch(ctx, sm, rim, "Circle — radius")


static func apply_extrude(ctx: FilmContext, depth: float) -> void:
	var sm: SketchMode = ctx.main.sketch_mode
	var chrome: SketchContextChrome = ctx.main.sketch_chrome
	if chrome != null:
		chrome.show_for_session(true)
		if chrome.has_method("set_extrude_distance"):
			chrome.set_extrude_distance(depth)
	var cue := FilmUICues.extrude(depth)
	await wait_frames(ctx.tree, 2)
	var ex: Button = null
	if chrome != null and chrome.has_method("extrude_button"):
		ex = chrome.extrude_button()
	if ex != null:
		await _cue_click(ctx, ex.get_global_rect().get_center(), cue)
		await wait_frames(ctx.tree, 2)
		ex.pressed.emit()
	elif sm != null and sm.active:
		ctx.chrome.show_action_alert(str(cue.keys), str(cue.desc))
		sm.finish_extrude(depth, "new")
	await ctx.after_regen()
	ctx.chrome.clear_keys()


static func pad_screen_center(ctx: FilmContext, fid: String) -> Vector2:
	var doc: SxDocument = ctx.view.doc
	if doc == null or fid.is_empty():
		return Vector2.ZERO
	var sk: SxSketch = doc.graph_get_sketch(fid)
	if sk == null:
		return Vector2.ZERO
	var pi: Dictionary = sk.plane_info()
	if pi.is_empty():
		return Vector2.ZERO
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for id in sk.entity_ids():
		var info: Dictionary = sk.entity_info(id)
		match str(info.get("type", "")):
			"line":
				var a: Vector2 = info["start"]
				var b: Vector2 = info["end"]
				mn = mn.min(a).min(b)
				mx = mx.max(a).max(b)
			"circle", "arc":
				var c: Vector2 = info["center"]
				var r: float = float(info.get("radius", 0.0))
				mn = mn.min(c - Vector2(r, r))
				mx = mx.max(c + Vector2(r, r))
			"point":
				var p: Vector2 = info["position"]
				mn = mn.min(p)
				mx = mx.max(p)
			_:
				pass
	if not is_finite(mn.x):
		return Vector2.ZERO
	var center2 := (mn + mx) * 0.5
	var origin: Vector3 = pi["origin"]
	var x_dir: Vector3 = (pi["x_dir"] as Vector3).normalized()
	var y_dir: Vector3 = (pi["y_dir"] as Vector3).normalized()
	var world := origin + x_dir * center2.x + y_dir * center2.y
	var cam = ctx.main.camera
	if cam == null:
		return Vector2.ZERO
	return cam.unproject_position(world)


static func _sketch_uv_to_screen(ctx: FilmContext, uv: Vector2) -> Vector2:
	var r := ctx.tree.root.get_viewport().get_visible_rect()
	return Vector2(
		r.position.x + r.size.x * clampf(0.22 + uv.x / 50.0, 0.15, 0.85),
		r.position.y + r.size.y * clampf(0.30 + uv.y / 50.0, 0.15, 0.80)
	)
