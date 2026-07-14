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

## Applied dimensional constraints: {type, ids, value}. Rebuilt into Label3Ds.
var dimensions: Array = []
## When false, dimension label container is hidden (labels still rebuilt).
var dimensions_visible := true

var _draw_node: MeshInstance3D
var _preview_node: MeshInstance3D
var _selected_node: MeshInstance3D
var _dimension_labels: Node3D
var _selected_material: StandardMaterial3D
var _tool_points: Array[Vector2] = []  # committed anchor points of current tool
var _hover: Vector2 = Vector2.ZERO
## Set by snap_point when a snap applied; drawn as a small cross in preview.
var _snap_marker: Variant = null  # Vector2 | null
var _line_material: StandardMaterial3D
var _preview_material: StandardMaterial3D

const DIM_LABEL_OFFSET := 4.0  # sketch-plane units perpendicular to a distance dim
const COLOR_ENTITY := Color(0.95, 0.95, 1.0)
const COLOR_CONSTRUCTION := Color(0.45, 0.45, 0.48)  # dimmer/desaturated


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
	dimensions.clear()
	_clear_dimension_labels()
	_redraw()
	status.emit("Sketch: L line · R rect · C circle · Enter finish+extrude · Esc cancel")


func cancel() -> void:
	active = false
	_tool_points.clear()
	_snap_marker = null
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
	tool = t
	_tool_points.clear()
	if t != Tool.SELECT:
		_set_selected([])
	_update_preview()


func set_snap(on: bool) -> void:
	snap_enabled = on
	if not on:
		_snap_marker = null


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
	match type:
		"horizontal", "vertical":
			for id in selected:
				if sketch.entity_info(id).get("type", "") == "line":
					sketch.add_constraint(type, [{"entity": id, "role": "self"}], 0.0)
					added = true
		"parallel", "perpendicular", "equal":
			if selected.size() == 2:
				sketch.add_constraint(type, [
					{"entity": selected[0], "role": "self"},
					{"entity": selected[1], "role": "self"}], 0.0)
				added = true
		"coincident":
			if selected.size() == 2:
				var pair := _closest_endpoints(selected[0], selected[1])
				if pair.size() == 2:
					sketch.add_constraint("coincident", [
						{"entity": selected[0], "role": pair[0]},
						{"entity": selected[1], "role": pair[1]}], 0.0)
					added = true
		"distance":
			if selected.size() == 1 and sketch.entity_info(selected[0]).get("type", "") == "line":
				sketch.add_constraint("distance", [
					{"entity": selected[0], "role": "start"},
					{"entity": selected[0], "role": "end"}], value)
				added = true
			elif selected.size() == 2:
				var pair2 := _closest_endpoints(selected[0], selected[1])
				if pair2.size() == 2:
					sketch.add_constraint("distance", [
						{"entity": selected[0], "role": pair2[0]},
						{"entity": selected[1], "role": pair2[1]}], value)
					added = true
		"radius":
			for id in selected:
				var k: String = sketch.entity_info(id).get("type", "")
				if k == "circle" or k == "arc":
					sketch.add_constraint("radius", [{"entity": id, "role": "self"}], value)
					added = true
	if not added:
		return ""
	# Record dimensional constraints (distance/radius, or any with a numeric value).
	if type == "distance" or type == "radius" or absf(value) > 0.0:
		_record_dimension(type, selected.duplicate(), value)
	var res: Dictionary = sketch.solve()
	_redraw()
	_redraw_selected()
	return res["status"]


func _record_dimension(type: String, ids: Array, value: float) -> void:
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
				dimensions[i] = {"type": type, "ids": id_list, "value": value}
				return
	dimensions.append({"type": type, "ids": id_list, "value": value})


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
	sketch.solve()
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
	sketch.solve()
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
			_select_at(pos2)
		Tool.TRIM:
			trim_at(pos2)
		Tool.LINE:
			_tool_points.append(pos2)
			if _tool_points.size() >= 2:
				var a := _tool_points[_tool_points.size() - 2]
				var b := _tool_points[_tool_points.size() - 1]
				sketch.add_line(a.x, a.y, b.x, b.y)
				_redraw()
		Tool.RECT:
			_tool_points.append(pos2)
			if _tool_points.size() == 2:
				var a := _tool_points[0]
				var b := _tool_points[1]
				sketch.add_line(a.x, a.y, b.x, a.y)
				sketch.add_line(b.x, a.y, b.x, b.y)
				sketch.add_line(b.x, b.y, a.x, b.y)
				sketch.add_line(a.x, b.y, a.x, a.y)
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


## Double-click or right-click ends a line chain.
func end_chain() -> void:
	_tool_points.clear()
	_update_preview()


func hover(pos2: Vector2) -> void:
	_hover = snap_point(pos2)
	_update_preview()


func _to3(p: Vector2) -> Vector3:
	return plane_origin + plane_x * p.x + plane_y * p.y


func _clear_meshes() -> void:
	_draw_node.mesh = null
	_preview_node.mesh = null
	_selected_node.mesh = null
	selected = []
	dimensions.clear()
	_clear_dimension_labels()


func _clear_dimension_labels() -> void:
	if _dimension_labels == null:
		return
	while _dimension_labels.get_child_count() > 0:
		var child := _dimension_labels.get_child(0)
		_dimension_labels.remove_child(child)
		child.free()


func _entity_draw_color(info: Dictionary) -> Color:
	return COLOR_CONSTRUCTION if info.get("construction", false) else COLOR_ENTITY


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
		var col := _entity_draw_color(info)
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


func _update_preview() -> void:
	var im := ImmediateMesh.new()
	var has := false
	if _tool_points.size() > 0 or _snap_marker != null:
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		has = true
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
