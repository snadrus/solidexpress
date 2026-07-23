class_name PathOverlay
extends Node3D
## Vivid 3D polyline tubes for Path features (merged sketch rails).
## SolidWorks analogue: visible 3D sketch / composite curve preview.

const PATH_COLOR := Color(0.12, 0.82, 1.0, 1.0)
const PATH_RADIUS := 0.32

var view: Node
var _nodes: Array = []


func refresh(doc: SxDocument) -> void:
	_clear()
	if doc == null:
		return
	for feat in doc.graph_features():
		if str(feat.get("type", "")) != "path":
			continue
		var pts := _path_points_from_feature(feat)
		if pts.size() >= 2:
			_add_path(str(feat.get("id", "")), pts)


func _path_points_from_feature(feat: Dictionary) -> PackedVector3Array:
	var out := PackedVector3Array()
	var parsed: Variant = JSON.parse_string(str(feat.get("params", "{}")))
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	var path_arr: Array = parsed.get("path", [])
	for pt in path_arr:
		if typeof(pt) == TYPE_ARRAY and pt.size() >= 3:
			out.append(Vector3(float(pt[0]), float(pt[1]), float(pt[2])))
	return out


func _add_path(fid: String, pts: PackedVector3Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(pts.size() - 1):
		_add_tube_segment(st, pts[i], pts[i + 1], PATH_RADIUS)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "Path_%s" % fid.substr(0, 8)
	mesh_inst.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = PATH_COLOR
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.material_override = mat
	add_child(mesh_inst)
	_nodes.append(mesh_inst)


func _add_tube_segment(st: SurfaceTool, a: Vector3, b: Vector3, radius: float) -> void:
	var along := b - a
	if along.length_squared() < 1e-10:
		return
	var dir := along.normalized()
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.92:
		up = Vector3.RIGHT
	var side := dir.cross(up).normalized()
	var up2 := side.cross(dir).normalized()
	const SEGS := 8
	for s in range(SEGS):
		var ang0 := TAU * float(s) / float(SEGS)
		var ang1 := TAU * float(s + 1) / float(SEGS)
		var o0 := side * cos(ang0) * radius + up2 * sin(ang0) * radius
		var o1 := side * cos(ang1) * radius + up2 * sin(ang1) * radius
		var p0a := a + o0
		var p1a := a + o1
		var p0b := b + o0
		var p1b := b + o1
		st.set_normal(o0.normalized())
		st.add_vertex(p0a)
		st.add_vertex(p0b)
		st.add_vertex(p1b)
		st.add_vertex(p0a)
		st.add_vertex(p1b)
		st.add_vertex(p1a)


func _clear() -> void:
	for n in _nodes:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
