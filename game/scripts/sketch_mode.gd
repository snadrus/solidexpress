class_name SketchMode
extends Node3D
## In-viewport sketch editing. Owns an SxSketch, renders its entities on the
## sketch plane, and converts viewport rays to sketch 2D coordinates.
## Tools: line chain, rectangle, circle. Finish extrudes the profile.

signal finished(body_id: String)
signal cancelled
signal status(text: String)

enum Tool { NONE, LINE, RECT, CIRCLE, ARC, POLYGON, SELECT, TRIM }

signal selection_changed(ids: Array)

const PICK_TOLERANCE := 5.0  # model units (mm)
const SNAP_RADIUS := PICK_TOLERANCE
const GLYPH_PICK_RADIUS := 2.0  # constraint badges are small, precise targets

var sketch: SxSketch
var view: DocumentView
var tool: Tool = Tool.NONE
var active := false
## When true, click/hover positions pass through snap_point().
var snap_enabled := true
## Regular N-gon side count for the POLYGON tool (clamped 3..24).
var polygon_sides := 6:
	set(v):
		polygon_sides = clampi(v, 3, 24)
## Feature id of the body being sketched on ("" when on the ground plane);
## used as the boolean target for cut/fuse finishes.
var target_fid := ""

# Sketch plane frame in model space.
var plane_origin := Vector3.ZERO
var plane_x := Vector3.RIGHT
var plane_y := Vector3.UP  # model-space Y (kernel), set on begin()

## Selected entity ids (SELECT tool), most recent last, max 2.
var selected: Array[String] = []
## Selected constraint id (click its glyph with the SELECT tool); Del removes.
var selected_constraint := ""

## Applied dimensional constraints: {type, ids, value}. Rebuilt into Label3Ds.
var dimensions: Array = []
## When false, dimension label container is hidden (labels still rebuilt).
var dimensions_visible := true

var _draw_node: MeshInstance3D
var _preview_node: MeshInstance3D
var _selected_node: MeshInstance3D
var _dimension_labels: Node3D
var _constraint_glyphs: Node3D
## Anchors of the drawn glyphs: Array of {cid: String, pos: Vector2}.
var _glyph_anchors: Array = []
## Live inference hint while drawing (shows H/V/coincident before commit).
var _infer_label: Label3D
var _selected_material: StandardMaterial3D
var _tool_points: Array[Vector2] = []  # committed anchor points of current tool
var _hover: Vector2 = Vector2.ZERO
## Set by snap_point when a snap applied; drawn as a small cross in preview.
var _snap_marker: Variant = null  # Vector2 | null
## Active SELECT-tool geometry drag. Empty when idle. Keys when dragging:
## id, part ("start"|"end"|"whole"|"center"|"radius"), grab_pos, orig_info,
## preview_info. Commits live via SxSketch.set_entity_geometry + re-solve.
var _drag: Dictionary = {}
var _line_material: StandardMaterial3D
var _preview_material: StandardMaterial3D

const DIM_LABEL_OFFSET := 4.0  # sketch-plane units perpendicular to a distance dim
const COLOR_ENTITY := Color(0.95, 0.95, 1.0)
const COLOR_CONSTRUCTION := Color(0.45, 0.45, 0.48)  # dimmer/desaturated
const COLOR_CONSTRAINED := Color(0.35, 0.85, 0.45)  # fully constrained sketch
const COLOR_CONFLICT := Color(0.95, 0.3, 0.25)  # entities in conflicting constraints
const COLOR_GLYPH := Color(0.65, 0.8, 1.0)
const COLOR_GLYPH_SELECTED := Color(1.0, 0.62, 0.15)
## SolidWorks-style relation badges drawn next to the owning geometry.
## Dimensional constraints (distance/radius/angle) use the dim labels instead.
const GLYPH_SYMBOLS := {
	"horizontal": "H",
	"vertical": "V",
	"parallel": "∥",
	"perpendicular": "⊥",
	"equal": "=",
	"coincident": "◉",
	"point_on_line": "◇",
	"tangent": "⌒",
}
## Geometry within this distance of exact H/V or an existing endpoint gets an
## inferred constraint on creation (SolidWorks-style automatic relations).
const INFER_TOL := 0.5

## Automatic constraint inference on entity creation (H/V + coincident).
var infer_enabled := true
## Diagnostics from the most recent solve: -1 until first solve.
var last_dofs := -1
var last_solve_status := ""
## Constraint ids the solver reported as conflicting / redundant.
var last_conflicting: Array = []
var last_redundant: Array = []
## Entity ids involved in conflicting constraints (drawn red).
var _conflict_entities := {}

## Emitted after every solve so the toolbar DOF chip stays current.
signal solve_updated(dofs: int, solve_status: String, conflicts: int)
## Emitted when the SELECT tool clicks a dimension label (in-viewport edit).
signal dimension_edit_requested(index: int)


func _ready() -> void:
	_line_material = StandardMaterial3D.new()
	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.albedo_color = Color.WHITE
	_line_material.vertex_color_use_as_albedo = true
	_preview_material = StandardMaterial3D.new()
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_material.albedo_color = Color(0.5, 0.8, 1.0, 0.8)
	_draw_node = MeshInstance3D.new()
	_draw_node.material_override = _line_material
	add_child(_draw_node)
	_preview_node = MeshInstance3D.new()
	_preview_node.material_override = _preview_material
	add_child(_preview_node)
	_selected_material = StandardMaterial3D.new()
	_selected_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_selected_material.albedo_color = Color(1.0, 0.62, 0.15)
	_selected_node = MeshInstance3D.new()
	_selected_node.material_override = _selected_material
	add_child(_selected_node)
	_dimension_labels = Node3D.new()
	_dimension_labels.name = "DimensionLabels"
	add_child(_dimension_labels)
	_constraint_glyphs = Node3D.new()
	_constraint_glyphs.name = "ConstraintGlyphs"
	add_child(_constraint_glyphs)
	_infer_label = Label3D.new()
	_infer_label.name = "InferHint"
	_infer_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_infer_label.fixed_size = true
	_infer_label.pixel_size = 0.004
	_infer_label.font_size = 24
	_infer_label.modulate = Color(1.0, 0.85, 0.3)
	_infer_label.visible = false
	add_child(_infer_label)


## Derive a sketch plane from an axis-aligned planar face via bbox heuristics.
## Returns {ok, origin, normal, message}. ok=false → caller should fall back to
## ground (v1: non-axis-aligned faces are not supported).
static func derive_face_plane(doc: SxDocument, face_id: String, body_id: String) -> Dictionary:
	var ground := {
		"ok": false,
		"origin": Vector3.ZERO,
		"normal": Vector3(0, 0, 1),
		"message": "Sketch on ground (XY)",
	}
	if face_id == "" or body_id == "":
		return ground
	var face_bb: Dictionary = doc.measure_bbox(face_id)
	if face_bb.is_empty():
		ground["message"] = "Could not measure face — sketching on ground"
		return ground
	var fmn: Vector3 = face_bb["min"]
	var fmx: Vector3 = face_bb["max"]
	var extent := fmx - fmn
	var origin := (fmn + fmx) * 0.5
	const EPS := 1e-6
	var axis := -1
	if extent.x < EPS:
		axis = 0
	elif extent.y < EPS:
		axis = 1
	elif extent.z < EPS:
		axis = 2
	else:
		ground["message"] = "Face not axis-aligned — sketching on ground (v1 limitation)"
		return ground
	var normal := Vector3.ZERO
	normal[axis] = 1.0
	var body_bb: Dictionary = doc.measure_bbox(body_id)
	if not body_bb.is_empty():
		var body_center: Vector3 = (body_bb["min"] + body_bb["max"]) * 0.5
		# Outward: pointing away from the body bbox center.
		if (origin - body_center).dot(normal) < 0.0:
			normal = -normal
	var axis_name: String
	if normal[axis] > 0.0:
		axis_name = ["+X", "+Y", "+Z"][axis]
	else:
		axis_name = ["-X", "-Y", "-Z"][axis]
	return {
		"ok": true,
		"origin": origin,
		"normal": normal,
		"message": "Sketch on face (plane %s @ origin %.1f,%.1f,%.1f)" % [
			axis_name, origin.x, origin.y, origin.z],
	}


## Unit normal of the current sketch plane (model space).
func plane_normal() -> Vector3:
	return plane_x.cross(plane_y).normalized()


## Begin a sketch on the model-space plane (origin + normal). x_hint picks the
## in-plane X direction; pass ZERO for an automatic perpendicular (n × world-Z,
## or world-X when the normal is parallel to Z). Extrude follows this normal.
func begin(origin: Vector3, normal: Vector3, x_hint: Vector3 = Vector3.ZERO) -> void:
	last_dofs = -1
	last_solve_status = ""
	plane_origin = origin
	var n := normal.normalized()
	var x := x_hint
	if x == Vector3.ZERO or absf(x.dot(n)) > 0.99:
		x = n.cross(Vector3(0, 0, 1))
		if x.length_squared() < 1e-12:
			x = Vector3.RIGHT
	plane_x = (x - n * x.dot(n)).normalized()
	plane_y = n.cross(plane_x).normalized()
	sketch = SxSketch.new()
	sketch.set_plane(origin, plane_x, plane_y)
	active = true
	tool = Tool.LINE
	_tool_points.clear()
	_drag.clear()
	dimensions.clear()
	_clear_dimension_labels()
	_redraw()
	status.emit("Sketch: L line · R rect · C circle · Enter finish+extrude · Esc cancel")


func cancel() -> void:
	active = false
	_tool_points.clear()
	_snap_marker = null
	_drag.clear()
	_clear_meshes()
	cancelled.emit()


func set_dimensions_visible(on: bool) -> void:
	dimensions_visible = on
	if _dimension_labels != null:
		_dimension_labels.visible = on


## Finish the sketch and extrude by `distance` (model units). Routed through
## the feature graph: adds a sketch feature plus an extrude feature so both
## appear on the timeline and stay editable. op: "new" | "cut" | "fuse";
## cut/fuse require a target body (the one sketched on) and cut extrudes
## into the body (negated distance).
func finish_extrude(distance: float, op: String = "new") -> void:
	if not active:
		return
	if op != "new" and target_fid == "":
		status.emit("No target body — sketch on a face to cut/fuse")
		return
	if op == "cut":
		distance = -absf(distance)
	var sk_fid: String = view.doc.graph_add_sketch(sketch)
	var ex_fid: String = view.doc.graph_add_extrude(
		sk_fid, distance, false, op, target_fid if op != "new" else "")
	_finish_feature(sk_fid, ex_fid, op, "Extrude failed — is the profile closed?")


## Finish the sketch and revolve. The axis is the selected line when one is
## selected (select tool), otherwise the sketch Y axis through the origin.
func finish_revolve(angle: float = TAU, op: String = "new") -> void:
	if not active:
		return
	if op != "new" and target_fid == "":
		status.emit("No target body — sketch on a face to cut/fuse")
		return
	var axis_point := Vector2.ZERO
	var axis_dir := Vector2(0, 1)
	if selected.size() == 1:
		var info: Dictionary = sketch.entity_info(selected[0])
		if info.get("type", "") == "line":
			axis_point = info["start"]
			axis_dir = (info["end"] - info["start"]).normalized()
			sketch.set_construction(selected[0], true)
	var sk_fid: String = view.doc.graph_add_sketch(sketch)
	var rv_fid: String = view.doc.graph_add_revolve(
		sk_fid, axis_point, axis_dir, angle, op, target_fid if op != "new" else "")
	_finish_feature(sk_fid, rv_fid, op, "Revolve failed — closed profile on one side of the axis?")


func _finish_feature(sk_fid: String, feat_fid: String, op: String, fail_msg: String) -> void:
	if feat_fid == "":
		view.doc.graph_remove(sk_fid)
	var body_id: String
	if op == "new":
		body_id = view.body_of_feature(feat_fid)
	else:
		# Modifying feature: the target body was updated in place.
		body_id = view.body_of_feature(target_fid) if feat_fid != "" else ""
	active = false
	_tool_points.clear()
	_clear_meshes()
	if feat_fid == "":
		status.emit(fail_msg)
		cancelled.emit()
	else:
		view.refresh()
		view.document_changed.emit()
		view.select_entity(body_id, "")
		finished.emit(body_id)


## Model-space ray -> sketch 2D coords (null if parallel to plane).
func ray_to_sketch(origin: Vector3, direction: Vector3) -> Variant:
	var n := plane_x.cross(plane_y)
	var denom := direction.dot(n)
	if absf(denom) < 1e-9:
		return null
	var t := (plane_origin - origin).dot(n) / denom
	if t < 0:
		return null
	var p := origin + direction * t - plane_origin
	return Vector2(p.dot(plane_x), p.dot(plane_y))


func set_tool(t: Tool) -> void:
	if not _drag.is_empty():
		end_drag()
	tool = t
	_tool_points.clear()
	if t != Tool.SELECT:
		_set_selected([])
	_update_preview()


func set_snap(on: bool) -> void:
	snap_enabled = on
	if not on:
		_snap_marker = null


func set_infer(on: bool) -> void:
	infer_enabled = on
	if not on and _infer_label != null:
		_infer_label.visible = false


## Snap sketch-plane point to nearby geometry / axis. Priority:
## (a) entity endpoints, (b) line midpoints & circle/arc centers, (c) H/V
## alignment to the last in-progress tool point. When snap_enabled is false,
## returns p unchanged.
func snap_point(p: Vector2) -> Vector2:
	_snap_marker = null
	if not snap_enabled or sketch == null:
		return p
	# (a) endpoints
	var best_d := SNAP_RADIUS
	var best_pt := p
	var found := false
	for id in sketch.entity_ids():
		for ep in _snap_endpoints(id):
			var d := p.distance_to(ep)
			if d <= best_d:
				best_d = d
				best_pt = ep
				found = true
	if found:
		_snap_marker = best_pt
		return best_pt
	# (b) midpoints and centers
	best_d = SNAP_RADIUS
	found = false
	for id in sketch.entity_ids():
		for mp in _snap_mid_centers(id):
			var d2 := p.distance_to(mp)
			if d2 <= best_d:
				best_d = d2
				best_pt = mp
				found = true
	if found:
		_snap_marker = best_pt
		return best_pt
	# (c) axis alignment from last committed tool point
	if not _tool_points.is_empty():
		var last: Vector2 = _tool_points[_tool_points.size() - 1]
		var out := p
		var snapped_axis := false
		if absf(p.x - last.x) <= SNAP_RADIUS:
			out.x = last.x
			snapped_axis = true
		if absf(p.y - last.y) <= SNAP_RADIUS:
			out.y = last.y
			snapped_axis = true
		if snapped_axis:
			_snap_marker = out
			return out
	return p


func _snap_endpoints(id: String) -> Array[Vector2]:
	var info: Dictionary = sketch.entity_info(id)
	var out: Array[Vector2] = []
	match info.get("type", ""):
		"line":
			out.append(info["start"])
			out.append(info["end"])
		"arc":
			var c: Vector2 = info["center"]
			var r: float = info["radius"]
			out.append(c + Vector2.from_angle(info["start_angle"]) * r)
			out.append(c + Vector2.from_angle(info["end_angle"]) * r)
		"point":
			out.append(info["position"])
	return out


func _snap_mid_centers(id: String) -> Array[Vector2]:
	var info: Dictionary = sketch.entity_info(id)
	var out: Array[Vector2] = []
	match info.get("type", ""):
		"line":
			out.append((info["start"] + info["end"]) * 0.5)
		"circle", "arc":
			out.append(info["center"])
	return out


# --- selection & constraints ---

func _set_selected(ids: Array[String]) -> void:
	selected = ids
	_redraw_selected()
	selection_changed.emit(selected)


## Nearest entity id within PICK_TOLERANCE of pos2, or "" if none.
func _nearest_entity_at(pos2: Vector2) -> String:
	var best_id := ""
	var best_d := PICK_TOLERANCE
	for id in sketch.entity_ids():
		var d := _entity_distance(sketch.entity_info(id), pos2)
		if d < best_d:
			best_d = d
			best_id = id
	return best_id


func _select_at(pos2: Vector2) -> void:
	var best_id := _nearest_entity_at(pos2)
	if best_id == "":
		_set_selected([])
		return
	var ids := selected.duplicate()
	if ids.has(best_id):
		ids.erase(best_id)  # click again to deselect
	else:
		ids.append(best_id)
		while ids.size() > 2:
			ids.pop_front()
	_set_selected(ids)


func _entity_distance(info: Dictionary, p: Vector2) -> float:
	match info.get("type", ""):
		"line":
			return _point_segment_distance(p, info["start"], info["end"])
		"circle", "arc":
			return absf(p.distance_to(info["center"]) - info["radius"])
		"point":
			return p.distance_to(info["position"])
	return INF


func _point_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0 if ab.length_squared() < 1e-12 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# --- drag-to-edit (SELECT tool) ---

## Hit-test for drag handles. Returns {} or {id, part} where part is
## "start"|"end"|"whole"|"center"|"radius". Endpoints/centers win within
## PICK_TOLERANCE; otherwise the nearest curve within tolerance ("whole" /
## "radius").
func drag_hit(pos2: Vector2) -> Dictionary:
	if sketch == null:
		return {}
	var best_id := ""
	var best_part := ""
	var best_d := PICK_TOLERANCE
	# Pass 1: endpoints / centers
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		match info.get("type", ""):
			"line":
				for pair in [["start", info["start"]], ["end", info["end"]]]:
					var d: float = pos2.distance_to(pair[1])
					if d <= best_d:
						best_d = d
						best_id = id
						best_part = pair[0]
			"circle", "arc":
				var d2: float = pos2.distance_to(info["center"])
				if d2 <= best_d:
					best_d = d2
					best_id = id
					best_part = "center"
	if best_id != "":
		return {"id": best_id, "part": best_part}
	# Pass 2: whole entity / rim
	best_d = PICK_TOLERANCE
	for id in sketch.entity_ids():
		var info2: Dictionary = sketch.entity_info(id)
		var d3 := _entity_distance(info2, pos2)
		if d3 <= best_d:
			best_d = d3
			best_id = id
			match info2.get("type", ""):
				"line":
					best_part = "whole"
				"circle", "arc":
					best_part = "radius"
				_:
					best_part = "whole"
	if best_id == "":
		return {}
	return {"id": best_id, "part": best_part}


## Start a SELECT-tool drag at pos2. No-op when inactive, wrong tool, or miss.
func begin_drag(pos2: Vector2) -> void:
	if not active or tool != Tool.SELECT or sketch == null:
		return
	var hit := drag_hit(pos2)
	if hit.is_empty():
		return
	var info: Dictionary = sketch.entity_info(hit["id"])
	if info.is_empty():
		return
	_drag = {
		"id": hit["id"],
		"part": hit["part"],
		"grab_pos": pos2,
		"orig_info": info.duplicate(true),
		"preview_info": info.duplicate(true),
	}
	_update_preview()


## Update an active drag: write the new geometry into the kernel and re-solve
## so constraints pull the rest of the sketch along live. The dragged shape is
## also drawn in the preview color as a "grabbed" highlight.
func update_drag(pos2: Vector2) -> void:
	if _drag.is_empty():
		return
	var target := _drag_preview_at(pos2)
	_drag["preview_info"] = target
	sketch.set_entity_geometry(_drag["id"], target)
	run_solve()
	_redraw()
	_rebuild_dimension_labels()
	_update_preview()


## End the active drag. A failed solve reverts to the pre-drag geometry.
func end_drag() -> void:
	if _drag.is_empty():
		return
	if last_solve_status == "failed":
		sketch.set_entity_geometry(_drag["id"], _drag["orig_info"])
		run_solve()
		status.emit("Drag reverted: constraints could not be satisfied")
	_drag.clear()
	_redraw()
	_rebuild_dimension_labels()
	_update_preview()


func _drag_preview_at(pos2: Vector2) -> Dictionary:
	var orig: Dictionary = _drag["orig_info"]
	var part: String = _drag["part"]
	var grab: Vector2 = _drag["grab_pos"]
	var delta := pos2 - grab
	var out: Dictionary = orig.duplicate(true)
	match part:
		"start":
			out["start"] = orig["start"] + delta
		"end":
			out["end"] = orig["end"] + delta
		"whole", "center":
			if orig.get("type", "") == "line":
				out["start"] = orig["start"] + delta
				out["end"] = orig["end"] + delta
			else:
				out["center"] = orig["center"] + delta
				# Arcs carry explicit start/end points; keep them attached.
				if orig.has("start"):
					out["start"] = orig["start"] + delta
				if orig.has("end"):
					out["end"] = orig["end"] + delta
		"radius":
			var c: Vector2 = orig["center"]
			out["radius"] = maxf(c.distance_to(pos2), 1e-6)
	return out


func _append_entity_lines(im: ImmediateMesh, info: Dictionary) -> void:
	match info.get("type", ""):
		"line":
			im.surface_add_vertex(_to3(info["start"]))
			im.surface_add_vertex(_to3(info["end"]))
		"circle":
			var c: Vector2 = info["center"]
			var r: float = info["radius"]
			var steps := 48
			for i in range(steps):
				var a0 := TAU * i / steps
				var a1 := TAU * (i + 1) / steps
				im.surface_add_vertex(_to3(c + Vector2(cos(a0), sin(a0)) * r))
				im.surface_add_vertex(_to3(c + Vector2(cos(a1), sin(a1)) * r))
		"arc":
			var c2: Vector2 = info["center"]
			var r2: float = info["radius"]
			var s: float = info["start_angle"]
			var e: float = info["end_angle"]
			if e < s:
				e += TAU
			var steps2 := 32
			for i in range(steps2):
				var a0 := s + (e - s) * i / steps2
				var a1 := s + (e - s) * (i + 1) / steps2
				im.surface_add_vertex(_to3(c2 + Vector2(cos(a0), sin(a0)) * r2))
				im.surface_add_vertex(_to3(c2 + Vector2(cos(a1), sin(a1)) * r2))


## Length of a line / radius of a circle/arc / distance between two entities.
## Uses `ids` when non-empty; otherwise the current selection. 0 when N/A.
func measured_value(ids: Array = []) -> float:
	if sketch == null:
		return 0.0
	var sel: Array = ids if not ids.is_empty() else selected
	if sel.size() == 1:
		var info: Dictionary = sketch.entity_info(str(sel[0]))
		match info.get("type", ""):
			"line":
				return (info["end"] - info["start"]).length()
			"circle", "arc":
				return info["radius"]
	elif sel.size() == 2:
		var pair := _closest_endpoints(str(sel[0]), str(sel[1]))
		if pair.size() == 2:
			return _endpoint_pos(str(sel[0]), pair[0]).distance_to(
				_endpoint_pos(str(sel[1]), pair[1]))
	return 0.0


## Applies a constraint to the current selection. Supported types:
## horizontal/vertical (each selected line), parallel/perpendicular/equal
## (two entities), coincident (nearest endpoints of two lines), distance
## (line length, or nearest endpoints of two entities), radius (circle/arc).
## Solves afterwards; returns the solve status string ("" when nothing done).
func constrain(type: String, value: float = 0.0) -> String:
	if not active or selected.is_empty():
		return ""
	var added := false
	var cid := ""  # id of the (last) constraint added, kept for editable dims
	match type:
		"horizontal", "vertical":
			for id in selected:
				if sketch.entity_info(id).get("type", "") == "line":
					cid = sketch.add_constraint(type, [{"entity": id, "role": "self"}], 0.0)
					added = true
		"parallel", "perpendicular", "equal":
			if selected.size() == 2:
				cid = sketch.add_constraint(type, [
					{"entity": selected[0], "role": "self"},
					{"entity": selected[1], "role": "self"}], 0.0)
				added = true
		"coincident":
			if selected.size() == 2:
				var pair := _closest_endpoints(selected[0], selected[1])
				if pair.size() == 2:
					cid = sketch.add_constraint("coincident", [
						{"entity": selected[0], "role": pair[0]},
						{"entity": selected[1], "role": pair[1]}], 0.0)
					added = true
		"distance":
			if selected.size() == 1 and sketch.entity_info(selected[0]).get("type", "") == "line":
				cid = sketch.add_constraint("distance", [
					{"entity": selected[0], "role": "start"},
					{"entity": selected[0], "role": "end"}], value)
				added = true
			elif selected.size() == 2:
				var pair2 := _closest_endpoints(selected[0], selected[1])
				if pair2.size() == 2:
					cid = sketch.add_constraint("distance", [
						{"entity": selected[0], "role": pair2[0]},
						{"entity": selected[1], "role": pair2[1]}], value)
					added = true
		"radius":
			for id in selected:
				var k: String = sketch.entity_info(id).get("type", "")
				if k == "circle" or k == "arc":
					cid = sketch.add_constraint("radius", [{"entity": id, "role": "self"}], value)
					added = true
	if not added:
		return ""
	# Record dimensional constraints (distance/radius, or any with a numeric value).
	if type == "distance" or type == "radius" or absf(value) > 0.0:
		_record_dimension(type, selected.duplicate(), value, cid)
	var res: Dictionary = run_solve()
	_redraw()
	_redraw_selected()
	return res["status"]


func _record_dimension(type: String, ids: Array, value: float, cid: String = "") -> void:
	var id_list: Array = []
	for id in ids:
		id_list.append(str(id))
	for i in range(dimensions.size()):
		var d: Dictionary = dimensions[i]
		if d.get("type", "") != type:
			continue
		var existing: Array = d.get("ids", [])
		if existing.size() == id_list.size():
			var same := true
			for j in range(id_list.size()):
				if str(existing[j]) != id_list[j]:
					same = false
					break
			if same:
				dimensions[i] = {"type": type, "ids": id_list, "value": value,
					"cid": cid if cid != "" else d.get("cid", "")}
				return
	dimensions.append({"type": type, "ids": id_list, "value": value, "cid": cid})


## Fillet the corner shared by two selected lines. Requires exactly two selected
## line entities. Returns the new arc id, or "" on failure (emits status).
func fillet_selected(radius: float) -> String:
	if not active or selected.size() != 2:
		status.emit("Fillet needs exactly 2 selected lines")
		return ""
	for id in selected:
		if sketch.entity_info(id).get("type", "") != "line":
			status.emit("Fillet needs exactly 2 selected lines")
			return ""
	var arc_id: String = sketch.fillet_corner(selected[0], selected[1], radius)
	if arc_id == "":
		status.emit("Fillet failed")
		return ""
	run_solve()
	_redraw()
	_redraw_selected()
	return arc_id


## Offset all selected entities by signed distance. Returns new entity ids.
func offset_selected(distance: float) -> Array:
	if not active or selected.is_empty():
		status.emit("Offset needs a selection")
		return []
	var ids := PackedStringArray()
	for id in selected:
		ids.append(id)
	var new_ids: PackedStringArray = sketch.offset_entities(ids, distance)
	if new_ids.is_empty():
		status.emit("Offset failed")
		return []
	_redraw()
	_redraw_selected()
	var out: Array = []
	for id in new_ids:
		out.append(id)
	return out


## Trim the entity nearest to pos2 at its intersections. Returns true on success.
func trim_at(pos2: Vector2) -> bool:
	if not active or sketch == null:
		status.emit("Trim failed")
		return false
	var id := _nearest_entity_at(pos2)
	if id == "":
		status.emit("Trim failed")
		return false
	if not sketch.trim_entity(id, pos2.x, pos2.y):
		status.emit("Trim failed")
		return false
	run_solve()
	# Drop selection entries that no longer exist after a replace-style trim.
	var alive: Array[String] = []
	for sid in selected:
		if not sketch.entity_info(sid).is_empty():
			alive.append(sid)
	if alive.size() != selected.size():
		_set_selected(alive)
	_redraw()
	_redraw_selected()
	status.emit("Trimmed")
	return true


## Flip construction flag on all selected entities and redraw (construction
## entities use a dimmer gray so the style persists across redraws).
func toggle_construction_selected() -> void:
	if not active or selected.is_empty():
		status.emit("Select entities to toggle construction")
		return
	var any_on := false
	for id in selected:
		var on := not sketch.is_construction(id)
		sketch.set_construction(id, on)
		if on:
			any_on = true
	_redraw()
	_redraw_selected()
	status.emit("Construction " + ("on" if any_on else "off"))


func _endpoint_pos(id: String, role: String) -> Vector2:
	var info: Dictionary = sketch.entity_info(id)
	match info.get("type", ""):
		"line":
			return info["start"] if role == "start" else info["end"]
		"circle", "arc":
			return info["center"]
	return info.get("position", Vector2.ZERO)


## Roles of the closest endpoint pair between two entities (["end","start"]...).
func _closest_endpoints(id_a: String, id_b: String) -> Array[String]:
	var roles_for := func(id: String) -> Array[String]:
		var k: String = sketch.entity_info(id).get("type", "")
		var out: Array[String] = []
		if k == "line":
			out.assign(["start", "end"])
		elif k == "circle" or k == "arc":
			out.assign(["center"])
		else:
			out.assign(["self"])
		return out
	var best := INF
	var pair: Array[String] = []
	for ra: String in roles_for.call(id_a):
		for rb: String in roles_for.call(id_b):
			var d := _endpoint_pos(id_a, ra).distance_to(_endpoint_pos(id_b, rb))
			if d < best:
				best = d
				pair = [ra, rb]
	return pair


func _redraw_selected() -> void:
	if sketch == null or selected.is_empty():
		_selected_node.mesh = null
		return
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for id in selected:
		var info: Dictionary = sketch.entity_info(id)
		match info.get("type", ""):
			"line":
				im.surface_add_vertex(_to3(info["start"]))
				im.surface_add_vertex(_to3(info["end"]))
			"circle", "arc":
				var c: Vector2 = info["center"]
				var r: float = info["radius"]
				for i in range(48):
					im.surface_add_vertex(_to3(c + Vector2.from_angle(TAU * i / 48.0) * r))
					im.surface_add_vertex(_to3(c + Vector2.from_angle(TAU * (i + 1) / 48.0) * r))
	im.surface_end()
	_selected_node.mesh = im


func click(pos2: Vector2) -> void:
	if not active:
		return
	# TRIM needs the raw pick along the curve; snap would pull toward midpoints.
	if tool != Tool.TRIM:
		pos2 = snap_point(pos2)
	match tool:
		Tool.SELECT:
			# Priority: constraint glyphs, then dimension labels, then geometry.
			var chit := constraint_hit(pos2)
			if chit != "":
				select_constraint(chit)
				return
			if selected_constraint != "":
				select_constraint("")
			var dhit := dimension_hit(pos2)
			if dhit >= 0:
				dimension_edit_requested.emit(dhit)
				return
			_select_at(pos2)
		Tool.TRIM:
			trim_at(pos2)
		Tool.LINE:
			_tool_points.append(pos2)
			if _tool_points.size() >= 2:
				var a := _tool_points[_tool_points.size() - 2]
				var b := _tool_points[_tool_points.size() - 1]
				var lid: String = sketch.add_line(a.x, a.y, b.x, b.y)
				_infer_line(lid, a, b)
				_redraw()
		Tool.RECT:
			_tool_points.append(pos2)
			if _tool_points.size() == 2:
				var a := _tool_points[0]
				var b := _tool_points[1]
				var l1: String = sketch.add_line(a.x, a.y, b.x, a.y)
				var l2: String = sketch.add_line(b.x, a.y, b.x, b.y)
				var l3: String = sketch.add_line(b.x, b.y, a.x, b.y)
				var l4: String = sketch.add_line(a.x, b.y, a.x, a.y)
				_infer_rect(l1, l2, l3, l4)
				_tool_points.clear()
				_redraw()
		Tool.CIRCLE:
			_tool_points.append(pos2)
			if _tool_points.size() == 2:
				var c := _tool_points[0]
				var r := c.distance_to(_tool_points[1])
				if r > 1e-6:
					sketch.add_circle(c.x, c.y, r)
				_tool_points.clear()
				_redraw()
		Tool.ARC:
			_tool_points.append(pos2)
			if _tool_points.size() == 3:
				var c := _tool_points[0]
				var start_pt := _tool_points[1]
				var end_pt := _tool_points[2]
				var r := c.distance_to(start_pt)
				if r > 1e-6:
					var start_angle := (start_pt - c).angle()
					var end_angle := (end_pt - c).angle()
					sketch.add_arc(c.x, c.y, r, start_angle, end_angle)
				_tool_points.clear()
				_redraw()
		Tool.POLYGON:
			_tool_points.append(pos2)
			if _tool_points.size() == 2:
				var c := _tool_points[0]
				var vertex := _tool_points[1]
				var r := c.distance_to(vertex)
				if r > 1e-6:
					var n := polygon_sides
					var start_angle := (vertex - c).angle()
					var verts: Array[Vector2] = []
					for i in range(n):
						var a := start_angle + TAU * float(i) / float(n)
						verts.append(c + Vector2(cos(a), sin(a)) * r)
					for i in range(n):
						var a := verts[i]
						var b := verts[(i + 1) % n]
						sketch.add_line(a.x, a.y, b.x, b.y)
				_tool_points.clear()
				_redraw()
	_update_preview()


# --- constraint inference (automatic relations on creation) ---

## Solve and remember diagnostics; all sketch-mode solves go through here so
## DOF coloring stays current.
func run_solve() -> Dictionary:
	var res: Dictionary = sketch.solve()
	last_dofs = res["dofs"]
	last_solve_status = res["status"]
	last_conflicting = Array(res.get("conflicting", PackedStringArray()))
	last_redundant = Array(res.get("redundant", PackedStringArray()))
	_conflict_entities.clear()
	for cid in last_conflicting:
		var cinfo: Dictionary = sketch.constraint_info(str(cid))
		for ref in cinfo.get("refs", []):
			_conflict_entities[str(ref["entity"])] = true
	solve_updated.emit(last_dofs, last_solve_status, last_conflicting.size())
	return res


## New line: add horizontal/vertical when near axis-aligned, and coincident
## constraints where its endpoints land on existing line endpoints.
func _infer_line(lid: String, a: Vector2, b: Vector2) -> void:
	if not infer_enabled or lid == "":
		return
	var added := false
	var d := b - a
	if d.length() > INFER_TOL:
		if absf(d.y) <= INFER_TOL:
			sketch.add_constraint("horizontal", [{"entity": lid, "role": "self"}], 0.0)
			added = true
		elif absf(d.x) <= INFER_TOL:
			sketch.add_constraint("vertical", [{"entity": lid, "role": "self"}], 0.0)
			added = true
	for role_pos in [["start", a], ["end", b]]:
		var hit := _endpoint_hit(role_pos[1], lid)
		if hit.size() == 2:
			sketch.add_constraint("coincident", [
				{"entity": lid, "role": role_pos[0]},
				{"entity": hit[0], "role": hit[1]}], 0.0)
			added = true
	if added:
		run_solve()


## Existing line endpoint within INFER_TOL of `p` (excluding `exclude_id`),
## as [entity_id, role]; [] when none.
func _endpoint_hit(p: Vector2, exclude_id: String) -> Array:
	for id in sketch.entity_ids():
		if id == exclude_id:
			continue
		var info: Dictionary = sketch.entity_info(id)
		if info.get("type", "") != "line":
			continue
		if p.distance_to(info["start"]) <= INFER_TOL:
			return [id, "start"]
		if p.distance_to(info["end"]) <= INFER_TOL:
			return [id, "end"]
	return []


## Rectangle: H/V on the four sides plus coincident corners, so the rect
## stays rectangular under later edits.
func _infer_rect(l1: String, l2: String, l3: String, l4: String) -> void:
	if not infer_enabled or "" in [l1, l2, l3, l4]:
		return
	for lid in [l1, l3]:
		sketch.add_constraint("horizontal", [{"entity": lid, "role": "self"}], 0.0)
	for lid in [l2, l4]:
		sketch.add_constraint("vertical", [{"entity": lid, "role": "self"}], 0.0)
	var corners := [[l1, "end", l2, "start"], [l2, "end", l3, "start"],
		[l3, "end", l4, "start"], [l4, "end", l1, "start"]]
	for c in corners:
		sketch.add_constraint("coincident", [
			{"entity": c[0], "role": c[1]},
			{"entity": c[2], "role": c[3]}], 0.0)
	run_solve()


## Change the value of a recorded dimensional constraint (by index into
## `dimensions`) and re-solve. Returns the solve status ("" on bad index).
func set_dimension_value(index: int, value: float) -> String:
	if index < 0 or index >= dimensions.size():
		return ""
	var dim: Dictionary = dimensions[index]
	var cid: String = dim.get("cid", "")
	if cid == "":
		return ""
	if not sketch.set_constraint_value(cid, value):
		return ""
	dim["value"] = value
	dimensions[index] = dim
	var res := run_solve()
	_redraw()
	_redraw_selected()
	_rebuild_dimension_labels()
	return res["status"]


## Double-click or right-click ends a line chain.
func end_chain() -> void:
	_tool_points.clear()
	_update_preview()


func hover(pos2: Vector2) -> void:
	_hover = snap_point(pos2)
	if _infer_label != null:
		var hint := _infer_hint_text(_hover)
		_infer_label.visible = hint != ""
		if hint != "":
			_infer_label.text = hint
			_infer_label.position = _to3(_hover + Vector2(2.0, 2.0))
	_update_preview()


func _to3(p: Vector2) -> Vector3:
	return plane_origin + plane_x * p.x + plane_y * p.y


func _clear_meshes() -> void:
	_draw_node.mesh = null
	_preview_node.mesh = null
	_selected_node.mesh = null
	selected = []
	selected_constraint = ""
	dimensions.clear()
	_clear_dimension_labels()
	_rebuild_constraint_glyphs()
	if _infer_label != null:
		_infer_label.visible = false


func _clear_dimension_labels() -> void:
	if _dimension_labels == null:
		return
	while _dimension_labels.get_child_count() > 0:
		var child := _dimension_labels.get_child(0)
		_dimension_labels.remove_child(child)
		child.free()


func _entity_draw_color(info: Dictionary, id: String = "") -> Color:
	if id != "" and _conflict_entities.has(id):
		return COLOR_CONFLICT
	if info.get("construction", false):
		return COLOR_CONSTRUCTION
	# Fully-constrained sketches draw green (per-entity DOF isn't reported by
	# the solver yet, so the whole sketch flips together).
	if last_dofs == 0 and last_solve_status != "failed":
		return COLOR_CONSTRAINED
	return COLOR_ENTITY


func _dimension_display_value(dim: Dictionary) -> float:
	var ids: Array = dim.get("ids", [])
	var measured := measured_value(ids)
	if measured > 1e-12:
		return measured
	return float(dim.get("value", 0.0))


func _dimension_label_pos2(dim: Dictionary) -> Variant:
	## Sketch-plane 2D position for a dimension label, or null if unresolvable.
	var ids: Array = dim.get("ids", [])
	var type: String = dim.get("type", "")
	if ids.is_empty() or sketch == null:
		return null
	if type == "radius" or (ids.size() == 1 and sketch.entity_info(str(ids[0])).get("type", "") in ["circle", "arc"]):
		var info: Dictionary = sketch.entity_info(str(ids[0]))
		if info.get("type", "") != "circle" and info.get("type", "") != "arc":
			return null
		var c: Vector2 = info["center"]
		var r: float = info["radius"]
		return c + Vector2(r * 0.7071, r * 0.7071)
	# Distance (or other): midpoint of the two reference points, offset perpendicular.
	var a: Vector2
	var b: Vector2
	if ids.size() == 1:
		var li: Dictionary = sketch.entity_info(str(ids[0]))
		if li.get("type", "") != "line":
			return null
		a = li["start"]
		b = li["end"]
	elif ids.size() >= 2:
		var pair := _closest_endpoints(str(ids[0]), str(ids[1]))
		if pair.size() != 2:
			return null
		a = _endpoint_pos(str(ids[0]), pair[0])
		b = _endpoint_pos(str(ids[1]), pair[1])
	else:
		return null
	var mid := (a + b) * 0.5
	var ab := b - a
	var perp := Vector2(-ab.y, ab.x)
	if perp.length_squared() < 1e-12:
		perp = Vector2(0, 1)
	else:
		perp = perp.normalized()
	return mid + perp * DIM_LABEL_OFFSET


func _rebuild_dimension_labels() -> void:
	_clear_dimension_labels()
	if _dimension_labels == null or sketch == null:
		return
	_dimension_labels.visible = dimensions_visible
	for dim in dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		var pos2: Variant = _dimension_label_pos2(dim)
		if pos2 == null:
			continue
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.fixed_size = true
		label.pixel_size = 0.004
		label.font_size = 28
		label.text = _format_dimension(_dimension_display_value(dim))
		label.position = _to3(pos2)
		_dimension_labels.add_child(label)


# --- constraint glyphs (visible relations, SolidWorks-style) ---

## Sketch-plane position of a constraint reference point. Role "self" means
## the entity itself: line midpoint, circle/arc center, point position.
func _ref_pos(ref: Dictionary) -> Variant:
	var info: Dictionary = sketch.entity_info(str(ref["entity"]))
	if info.is_empty():
		return null
	var role := str(ref.get("role", "self"))
	match info.get("type", ""):
		"line":
			if role == "start":
				return info["start"]
			if role == "end":
				return info["end"]
			return (info["start"] + info["end"]) * 0.5
		"circle", "arc":
			return info["center"]
		"point":
			return info["position"]
	return null


## Glyph anchor for a constraint: mean of its reference points, nudged
## perpendicular for single-line relations so the badge sits beside the line.
func _constraint_anchor(cinfo: Dictionary) -> Variant:
	var refs: Array = cinfo.get("refs", [])
	if refs.is_empty():
		return null
	var sum := Vector2.ZERO
	var n := 0
	for ref in refs:
		var p: Variant = _ref_pos(ref)
		if p == null:
			continue
		sum += p as Vector2
		n += 1
	if n == 0:
		return null
	var anchor := sum / float(n)
	if refs.size() == 1:
		var info: Dictionary = sketch.entity_info(str(refs[0]["entity"]))
		if info.get("type", "") == "line":
			var d: Vector2 = info["end"] - info["start"]
			if d.length_squared() > 1e-12:
				anchor += Vector2(-d.y, d.x).normalized() * 2.5
	return anchor


func _rebuild_constraint_glyphs() -> void:
	_glyph_anchors.clear()
	if _constraint_glyphs == null:
		return
	while _constraint_glyphs.get_child_count() > 0:
		var child := _constraint_glyphs.get_child(0)
		_constraint_glyphs.remove_child(child)
		child.free()
	if sketch == null or not active:
		return
	if selected_constraint != "" and sketch.constraint_info(selected_constraint).is_empty():
		selected_constraint = ""
	var taken: Array[Vector2] = []
	for cid in sketch.constraint_ids():
		var cinfo: Dictionary = sketch.constraint_info(cid)
		var type := str(cinfo.get("type", ""))
		if not GLYPH_SYMBOLS.has(type):
			continue
		var anchor: Variant = _constraint_anchor(cinfo)
		if anchor == null:
			continue
		var pos := anchor as Vector2
		# Stack overlapping badges instead of drawing them on top of each other.
		var guard := 0
		while guard < 8 and taken.any(func(t: Vector2) -> bool: return t.distance_to(pos) < 2.0):
			pos += Vector2(0, 2.5)
			guard += 1
		taken.append(pos)
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.fixed_size = true
		label.pixel_size = 0.004
		label.font_size = 22
		label.text = GLYPH_SYMBOLS[type]
		if str(cid) == selected_constraint:
			label.modulate = COLOR_GLYPH_SELECTED
		elif last_conflicting.has(str(cid)):
			label.modulate = COLOR_CONFLICT
		else:
			label.modulate = COLOR_GLYPH
		label.position = _to3(pos)
		label.set_meta("cid", str(cid))
		_constraint_glyphs.add_child(label)
		_glyph_anchors.append({"cid": str(cid), "pos": pos})


## Constraint whose glyph is within GLYPH_PICK_RADIUS of pos2, or "".
## Geometry wins ties: a click closer to an entity than to the badge selects
## the entity, so badges beside a line never steal clicks aimed at it.
func constraint_hit(pos2: Vector2) -> String:
	var best := ""
	var best_d := GLYPH_PICK_RADIUS
	for a in _glyph_anchors:
		var d: float = pos2.distance_to(a["pos"])
		if d < best_d:
			best_d = d
			best = a["cid"]
	if best == "":
		return ""
	var eid := _nearest_entity_at(pos2)
	if eid != "" and _entity_distance(sketch.entity_info(eid), pos2) < best_d:
		return ""
	return best


func select_constraint(cid: String) -> void:
	selected_constraint = cid
	_rebuild_constraint_glyphs()
	if cid != "":
		var type := str(sketch.constraint_info(cid).get("type", ""))
		status.emit("Constraint selected: %s — Del removes it" % type)


## Remove the selected constraint (glyph click + Del). Returns true on success.
func delete_selected_constraint() -> bool:
	if selected_constraint == "" or sketch == null:
		return false
	var cid := selected_constraint
	if not sketch.remove_constraint(cid):
		return false
	selected_constraint = ""
	# Drop any recorded dimension driven by this constraint.
	for i in range(dimensions.size() - 1, -1, -1):
		if str(dimensions[i].get("cid", "")) == cid:
			dimensions.remove_at(i)
	run_solve()
	_redraw()
	_redraw_selected()
	status.emit("Constraint removed")
	return true


## Index of the dimension whose label sits within PICK_TOLERANCE of pos2 (-1 = none).
func dimension_hit(pos2: Vector2) -> int:
	var best := -1
	var best_d := PICK_TOLERANCE
	for i in range(dimensions.size()):
		var lp: Variant = _dimension_label_pos2(dimensions[i])
		if lp == null:
			continue
		var d: float = pos2.distance_to(lp as Vector2)
		if d < best_d:
			best_d = d
			best = i
	return best


## Live inference hint while drawing: which constraint the LINE tool would add
## for a segment from the last tool point to `p` ("H", "V", coincident glyph).
func _infer_hint_text(p: Vector2) -> String:
	if not infer_enabled or tool != Tool.LINE or _tool_points.is_empty():
		return ""
	if not _endpoint_hit(p, "").is_empty():
		return GLYPH_SYMBOLS["coincident"]
	var d := p - _tool_points[_tool_points.size() - 1]
	if d.length() <= INFER_TOL:
		return ""
	if absf(d.y) <= INFER_TOL:
		return "H"
	if absf(d.x) <= INFER_TOL:
		return "V"
	return ""


## Approximate "%.4g" (GDScript's % operator has no g specifier).
func _format_dimension(v: float) -> String:
	if not is_finite(v):
		return str(v)
	if absf(v) < 1e-12:
		return "0"
	var s := "%.6f" % v
	if s.contains("."):
		while s.ends_with("0"):
			s = s.substr(0, s.length() - 1)
		if s.ends_with("."):
			s = s.substr(0, s.length() - 1)
	return s


## Drop dimension annotations whose entity ids no longer exist (e.g. after trim).
func _prune_orphan_dimensions() -> void:
	if sketch == null:
		dimensions.clear()
		return
	var alive := {}
	for id in sketch.entity_ids():
		alive[str(id)] = true
	var kept: Array = []
	for dim in dimensions:
		if typeof(dim) != TYPE_DICTIONARY:
			continue
		var ids: Array = dim.get("ids", [])
		var ok := not ids.is_empty()
		for eid in ids:
			if not alive.has(str(eid)):
				ok = false
				break
		if ok:
			kept.append(dim)
	dimensions = kept


func _redraw() -> void:
	if sketch == null:
		return
	_prune_orphan_dimensions()
	var im := ImmediateMesh.new()
	var has := false
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		var col := _entity_draw_color(info, str(id))
		match info.get("type", ""):
			"line":
				if not has:
					im.surface_begin(Mesh.PRIMITIVE_LINES)
					has = true
				im.surface_set_color(col)
				im.surface_add_vertex(_to3(info["start"]))
				im.surface_add_vertex(_to3(info["end"]))
			"circle":
				if not has:
					im.surface_begin(Mesh.PRIMITIVE_LINES)
					has = true
				var c: Vector2 = info["center"]
				var r: float = info["radius"]
				var steps := 48
				for i in range(steps):
					var a0 := TAU * i / steps
					var a1 := TAU * (i + 1) / steps
					im.surface_set_color(col)
					im.surface_add_vertex(_to3(c + Vector2(cos(a0), sin(a0)) * r))
					im.surface_add_vertex(_to3(c + Vector2(cos(a1), sin(a1)) * r))
			"arc":
				if not has:
					im.surface_begin(Mesh.PRIMITIVE_LINES)
					has = true
				var c2: Vector2 = info["center"]
				var r2: float = info["radius"]
				var s: float = info["start_angle"]
				var e: float = info["end_angle"]
				if e < s:
					e += TAU
				var steps2 := 32
				for i in range(steps2):
					var a0 := s + (e - s) * i / steps2
					var a1 := s + (e - s) * (i + 1) / steps2
					im.surface_set_color(col)
					im.surface_add_vertex(_to3(c2 + Vector2(cos(a0), sin(a0)) * r2))
					im.surface_add_vertex(_to3(c2 + Vector2(cos(a1), sin(a1)) * r2))
	if has:
		im.surface_end()
		_draw_node.mesh = im
	else:
		_draw_node.mesh = null
	_rebuild_dimension_labels()
	_rebuild_constraint_glyphs()


func _update_preview() -> void:
	var im := ImmediateMesh.new()
	var has := false
	var dragging := not _drag.is_empty()
	if _tool_points.size() > 0 or _snap_marker != null or dragging:
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		has = true
	if dragging:
		_append_entity_lines(im, _drag["preview_info"])
	if _tool_points.size() > 0:
		var last := _tool_points[_tool_points.size() - 1]
		match tool:
			Tool.LINE:
				im.surface_add_vertex(_to3(last))
				im.surface_add_vertex(_to3(_hover))
			Tool.RECT:
				var a := _tool_points[0]
				var b := _hover
				im.surface_add_vertex(_to3(a)); im.surface_add_vertex(_to3(Vector2(b.x, a.y)))
				im.surface_add_vertex(_to3(Vector2(b.x, a.y))); im.surface_add_vertex(_to3(b))
				im.surface_add_vertex(_to3(b)); im.surface_add_vertex(_to3(Vector2(a.x, b.y)))
				im.surface_add_vertex(_to3(Vector2(a.x, b.y))); im.surface_add_vertex(_to3(a))
			Tool.CIRCLE:
				var c := _tool_points[0]
				var r := c.distance_to(_hover)
				var steps := 48
				for i in range(steps):
					var a0 := TAU * i / steps
					var a1 := TAU * (i + 1) / steps
					im.surface_add_vertex(_to3(c + Vector2(cos(a0), sin(a0)) * r))
					im.surface_add_vertex(_to3(c + Vector2(cos(a1), sin(a1)) * r))
			Tool.ARC:
				var c := _tool_points[0]
				if _tool_points.size() == 1:
					im.surface_add_vertex(_to3(c))
					im.surface_add_vertex(_to3(_hover))
				else:
					var start_pt := _tool_points[1]
					var r := c.distance_to(start_pt)
					var s := (start_pt - c).angle()
					var e := (_hover - c).angle()
					if e < s:
						e += TAU
					var steps2 := 32
					for i in range(steps2):
						var a0 := s + (e - s) * i / steps2
						var a1 := s + (e - s) * (i + 1) / steps2
						im.surface_add_vertex(_to3(c + Vector2(cos(a0), sin(a0)) * r))
						im.surface_add_vertex(_to3(c + Vector2(cos(a1), sin(a1)) * r))
			Tool.POLYGON:
				var c := _tool_points[0]
				var r := c.distance_to(_hover)
				var n := polygon_sides
				var start_angle := (_hover - c).angle()
				var steps := 48
				for i in range(steps):
					var a0 := TAU * i / steps
					var a1 := TAU * (i + 1) / steps
					im.surface_add_vertex(_to3(c + Vector2(cos(a0), sin(a0)) * r))
					im.surface_add_vertex(_to3(c + Vector2(cos(a1), sin(a1)) * r))
				var verts: Array[Vector2] = []
				for i in range(n):
					var a := start_angle + TAU * float(i) / float(n)
					verts.append(c + Vector2(cos(a), sin(a)) * r)
				for i in range(n):
					im.surface_add_vertex(_to3(verts[i]))
					im.surface_add_vertex(_to3(verts[(i + 1) % n]))
	if _snap_marker != null:
		var m: Vector2 = _snap_marker
		const MARK := 1.5
		im.surface_add_vertex(_to3(m + Vector2(-MARK, 0)))
		im.surface_add_vertex(_to3(m + Vector2(MARK, 0)))
		im.surface_add_vertex(_to3(m + Vector2(0, -MARK)))
		im.surface_add_vertex(_to3(m + Vector2(0, MARK)))
	if has:
		im.surface_end()
		_preview_node.mesh = im
	else:
		_preview_node.mesh = null
