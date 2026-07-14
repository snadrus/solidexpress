class_name DocumentView
extends Node3D
## View-model bridging SxDocument (kernel, Z-up) to the scene tree.
## Lives under ModelSpace (rotated so kernel +Z is world up). One
## MeshInstance3D child per body; one ArrayMesh surface per B-rep face,
## surface index order matching get_face_ids().

signal document_changed
signal selection_changed(body_id: String, face_id: String)

const BODY_COLOR := Color(0.72, 0.74, 0.78)
const SELECTED_BODY_COLOR := Color(0.55, 0.68, 0.9)
const SELECTED_FACE_COLOR := Color(1.0, 0.62, 0.15)
const EDGE_COLOR := Color(0.12, 0.13, 0.16)

var doc: SxDocument = SxDocument.new()
var selected_body := ""
var selected_face := ""
var selected_edge := ""

const EDGE_PICK_TOLERANCE := 2.5  # model units (mm)

var _body_nodes := {}  # body_id -> MeshInstance3D
var _face_ids := {}    # body_id -> PackedStringArray
var _edge_highlight: MeshInstance3D
var _base_material: StandardMaterial3D
var _selected_body_material: StandardMaterial3D
var _selected_face_material: StandardMaterial3D
var _edge_material: StandardMaterial3D


func _ready() -> void:
	_base_material = _make_material(BODY_COLOR)
	_selected_body_material = _make_material(SELECTED_BODY_COLOR)
	_selected_face_material = _make_material(SELECTED_FACE_COLOR)
	_selected_face_material.emission_enabled = true
	_selected_face_material.emission = SELECTED_FACE_COLOR * 0.35
	_edge_material = StandardMaterial3D.new()
	_edge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_edge_material.albedo_color = EDGE_COLOR
	var hl_mat := StandardMaterial3D.new()
	hl_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hl_mat.albedo_color = SELECTED_FACE_COLOR
	hl_mat.no_depth_test = true
	_edge_highlight = MeshInstance3D.new()
	_edge_highlight.name = "EdgeHighlight"
	_edge_highlight.material_override = hl_mat
	add_child(_edge_highlight)
	refresh()


func _make_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.1
	m.roughness = 0.55
	return m


# --- creation (palette drop / click-to-place) ---

func insert_primitive(kind: String, world_point: Vector3) -> String:
	# world_point is in model (kernel) space; primitives sit on the XY plane.
	# Inserted through the feature graph so it appears on the timeline and
	# stays parametrically editable.
	var p := Vector3(world_point.x, world_point.y, 0.0)
	var fid := ""
	match kind:
		"box":
			fid = doc.graph_add_primitive("box", 50, 50, 50, p - Vector3(25, 25, 0))
		"cylinder":
			fid = doc.graph_add_primitive("cylinder", 25, 50, 0, p)
		"sphere":
			fid = doc.graph_add_primitive("sphere", 25, 0, 0, p + Vector3(0, 0, 25))
		"cone":
			fid = doc.graph_add_primitive("cone", 25, 10, 50, p)
		"torus":
			fid = doc.graph_add_primitive("torus", 30, 8, 0, p + Vector3(0, 0, 8))
		_:
			push_error("unknown primitive kind: " + kind)
			return ""
	var id := body_of_feature(fid)
	_after_mutation()
	if id != "":
		select_entity(id, "")
	return id


# --- feature graph helpers ---

func body_of_feature(fid: String) -> String:
	if fid == "":
		return ""
	for f in doc.graph_features():
		if f["id"] == fid:
			return f["output_body"]
	return ""


func feature_of_body(body_id: String) -> String:
	for f in doc.graph_features():
		if f["output_body"] == body_id:
			return f["id"]
	return ""


func graph_changed() -> void:
	clear_selection()
	_after_mutation()


# --- selection ---

## Ray in model space. Returns true on hit.
func select_ray(origin: Vector3, direction: Vector3) -> bool:
	var hit: Dictionary = doc.pick(origin, direction)
	if hit.is_empty():
		clear_selection()
		return false
	# First click on a body selects the body; clicking again refines to an
	# edge (when the hit point is within tolerance of one) or the hit face.
	if selected_body == hit["body"]:
		var edge := _edge_near_point(hit["body"], hit["point"])
		if edge != "" and edge != selected_edge:
			select_edge(hit["body"], edge)
			return true
		if selected_face != hit["face"]:
			select_entity(hit["body"], hit["face"])
			return true
	select_entity(hit["body"], "")
	return true


## Closest edge of `body_id` to a model-space point, "" when none in tolerance.
func _edge_near_point(body_id: String, point: Vector3) -> String:
	var lines: Dictionary = doc.get_edge_lines(body_id)
	var best_id := ""
	var best_d := EDGE_PICK_TOLERANCE
	for edge_id in lines:
		var pts: PackedVector3Array = lines[edge_id]
		for i in range(pts.size() - 1):
			var d := _point_segment_distance3(point, pts[i], pts[i + 1])
			if d < best_d:
				best_d = d
				best_id = edge_id
	return best_id


func _point_segment_distance3(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := 0.0 if ab.length_squared() < 1e-12 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func select_edge(body_id: String, edge_id: String) -> void:
	selected_body = body_id
	selected_face = ""
	selected_edge = edge_id
	_apply_selection_materials()
	_highlight_edge()
	selection_changed.emit(selected_body, selected_face)


func pick_info(origin: Vector3, direction: Vector3) -> Dictionary:
	return doc.pick(origin, direction)


func select_entity(body_id: String, face_id: String) -> void:
	selected_body = body_id
	selected_face = face_id
	selected_edge = ""
	_apply_selection_materials()
	_highlight_edge()
	selection_changed.emit(selected_body, selected_face)


func clear_selection() -> void:
	select_entity("", "")


## Card markdown of the innermost selected entity ("" if nothing selected).
func selection_card() -> String:
	if selected_edge != "":
		var md := doc.card_markdown(selected_edge)
		if md != "":
			return md
		return "## Edge\n`%s`\nlength %.2f mm" % [selected_edge, doc.measure_edge_length(selected_edge)]
	if selected_face != "":
		return doc.card_markdown(selected_face)
	if selected_body != "":
		return doc.card_markdown(selected_body)
	return ""


## Outward normal (model space) of the selected face, from its tessellation.
func selected_face_normal() -> Vector3:
	if selected_body == "" or selected_face == "":
		return Vector3.ZERO
	var node: MeshInstance3D = _body_nodes.get(selected_body)
	var faces: PackedStringArray = _face_ids.get(selected_body, PackedStringArray())
	var idx := faces.find(selected_face)
	if node == null or idx < 0:
		return Vector3.ZERO
	var arrays: Array = node.mesh.surface_get_arrays(idx)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	return normals[0] if normals.size() > 0 else Vector3.ZERO


func body_center(body_id: String) -> Vector3:
	var node: MeshInstance3D = _body_nodes.get(body_id)
	if node == null:
		return Vector3.ZERO
	var aabb := node.get_aabb()
	return aabb.get_center()


# --- editing ---

func move_selected(delta: Vector3) -> bool:
	if selected_body == "":
		return false
	var ok := doc.translate_body(selected_body, delta)
	_after_mutation()
	return ok


func push_pull_selected(distance: float) -> bool:
	if selected_face == "":
		return false
	var face := selected_face
	var body := selected_body
	var ok := doc.push_pull(face, distance)
	_after_mutation()
	if ok:
		# Face ids are reassigned after a shape change (naming v0); keep the
		# body selected so the user can continue working.
		select_entity(body, "")
	return ok


func delete_selected() -> bool:
	if selected_body == "":
		return false
	# Bodies owned by a timeline feature are deleted by removing the feature
	# (fails if later features depend on it); free bodies delete directly.
	var fid := feature_of_body(selected_body)
	var ok: bool
	if fid != "":
		ok = doc.graph_remove(fid)
	else:
		ok = doc.delete_body(selected_body)
	clear_selection()
	_after_mutation()
	return ok


func set_selection_alias(text: String) -> void:
	var target := selected_face if selected_face != "" else selected_body
	if target != "":
		doc.set_card_alias(target, text)


func set_selection_notes(text: String) -> void:
	var target := selected_face if selected_face != "" else selected_body
	if target != "":
		doc.set_card_notes(target, text)


func undo() -> bool:
	var ok := doc.undo()
	clear_selection()
	_after_mutation()
	return ok


func redo() -> bool:
	var ok := doc.redo()
	clear_selection()
	_after_mutation()
	return ok


func save(path: String) -> bool:
	return doc.save(path)


func load_from(path: String) -> bool:
	var ok := doc.load(path)
	clear_selection()
	_after_mutation()
	return ok


func new_document() -> void:
	doc = SxDocument.new()
	clear_selection()
	_after_mutation()


# --- rendering ---

func refresh() -> void:
	var live := {}
	for body_id in doc.body_ids():
		live[body_id] = true
		_rebuild_body(body_id)
	for body_id in _body_nodes.keys().duplicate():
		if not live.has(body_id):
			_body_nodes[body_id].queue_free()
			_body_nodes.erase(body_id)
			_face_ids.erase(body_id)


func body_node(body_id: String) -> MeshInstance3D:
	return _body_nodes.get(body_id)


func _after_mutation() -> void:
	refresh()
	_apply_selection_materials()
	_highlight_edge()
	document_changed.emit()


func _rebuild_body(body_id: String) -> void:
	var node: MeshInstance3D = _body_nodes.get(body_id)
	if node == null:
		node = MeshInstance3D.new()
		node.name = "Body_" + body_id.left(8)
		add_child(node)
		_body_nodes[body_id] = node
		var edges := MeshInstance3D.new()
		edges.name = "Edges"
		node.add_child(edges)
	node.transform = Transform3D.IDENTITY
	node.mesh = doc.get_mesh(body_id)
	_face_ids[body_id] = doc.get_face_ids(body_id)
	_rebuild_edges(node.get_node("Edges") as MeshInstance3D, body_id)


func _rebuild_edges(edge_node: MeshInstance3D, body_id: String) -> void:
	var lines: Dictionary = doc.get_edge_lines(body_id)
	var im := ImmediateMesh.new()
	var have_any := false
	for edge_id in lines:
		var pts: PackedVector3Array = lines[edge_id]
		if pts.size() < 2:
			continue
		if not have_any:
			im.surface_begin(Mesh.PRIMITIVE_LINES)
			have_any = true
		for i in range(pts.size() - 1):
			im.surface_add_vertex(pts[i])
			im.surface_add_vertex(pts[i + 1])
	if have_any:
		im.surface_end()
	edge_node.mesh = im
	edge_node.material_override = _edge_material


func _highlight_edge() -> void:
	if selected_edge == "" or selected_body == "":
		_edge_highlight.mesh = null
		return
	var lines: Dictionary = doc.get_edge_lines(selected_body)
	if not lines.has(selected_edge):
		_edge_highlight.mesh = null
		return
	var pts: PackedVector3Array = lines[selected_edge]
	if pts.size() < 2:
		_edge_highlight.mesh = null
		return
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(pts.size() - 1):
		im.surface_add_vertex(pts[i])
		im.surface_add_vertex(pts[i + 1])
	im.surface_end()
	_edge_highlight.mesh = im


func _apply_selection_materials() -> void:
	for body_id in _body_nodes:
		var node: MeshInstance3D = _body_nodes[body_id]
		var faces: PackedStringArray = _face_ids.get(body_id, PackedStringArray())
		var body_selected: bool = body_id == selected_body
		for i in range(node.mesh.get_surface_count() if node.mesh else 0):
			var mat := _base_material
			if body_selected and selected_face == "":
				mat = _selected_body_material
			elif body_selected and i < faces.size() and faces[i] == selected_face:
				mat = _selected_face_material
			node.set_surface_override_material(i, mat)
