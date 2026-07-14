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
const DATUM_PLANE_COLOR := Color(0.35, 0.55, 0.85, 0.22)
const DATUM_AXIS_COLOR := Color(0.85, 0.35, 0.2)
const DATUM_POINT_COLOR := Color(0.2, 0.7, 0.45)

enum DisplayMode { SHADED, SHADED_EDGES, WIREFRAME }

var doc: SxDocument = SxDocument.new()
## Primary (most recent) selection — single-select API, kept for panels/tests.
var selected_body := ""
var selected_face := ""
var selected_edge := ""
## Multi-select sets (Ctrl+click). Always contain the primary selection too:
## whole bodies, individual faces, and individual edges respectively.
var selected_bodies: Array[String] = []
var selected_faces: Array[String] = []
var selected_edges: Array[String] = []
var display_mode := DisplayMode.SHADED_EDGES
## True while a section (clipping) plane is active on body meshes.
## Edge overlay lines are not clipped in v1.
var section_enabled := false
## Body ids currently hidden from view / picking (id -> true).
var hidden_bodies := {}

const EDGE_PICK_TOLERANCE := 2.5  # model units (mm)
const DATUM_PLANE_HALF := 20.0  # ~40 unit square
const DATUM_AXIS_HALF_LEN := 100.0
const DATUM_POINT_RADIUS := 1.5

var _body_nodes := {}  # body_id -> MeshInstance3D
var _datum_nodes := {}  # datum_id -> Node3D
var _instance_nodes := {}  # instance_id -> MeshInstance3D
var _face_ids := {}    # body_id -> PackedStringArray
var _body_materials := {}  # body_id -> StandardMaterial3D (tinted by body color)
var _instance_materials := {}  # instance_id -> StandardMaterial3D (lightened source tint)
var _edge_highlight: MeshInstance3D
var _base_material: StandardMaterial3D
var _selected_body_material: StandardMaterial3D
var _selected_face_material: StandardMaterial3D
var _edge_material: StandardMaterial3D
var _selected_edge_material: StandardMaterial3D
var _wireframe_hidden_material: StandardMaterial3D
var _datum_plane_material: StandardMaterial3D
var _datum_axis_material: StandardMaterial3D
var _datum_point_material: StandardMaterial3D
var _section_shader: Shader
var _section_point := Vector3.ZERO
var _section_normal := Vector3.RIGHT


func _ready() -> void:
	_base_material = _make_material(BODY_COLOR)
	_selected_body_material = _make_material(SELECTED_BODY_COLOR)
	_selected_face_material = _make_material(SELECTED_FACE_COLOR)
	_selected_face_material.emission_enabled = true
	_selected_face_material.emission = SELECTED_FACE_COLOR * 0.35
	_edge_material = StandardMaterial3D.new()
	_edge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_edge_material.albedo_color = EDGE_COLOR
	_selected_edge_material = StandardMaterial3D.new()
	_selected_edge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_selected_edge_material.albedo_color = SELECTED_BODY_COLOR
	_wireframe_hidden_material = StandardMaterial3D.new()
	_wireframe_hidden_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wireframe_hidden_material.albedo_color = Color(0, 0, 0, 0)
	_datum_plane_material = StandardMaterial3D.new()
	_datum_plane_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_datum_plane_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_datum_plane_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_datum_plane_material.albedo_color = DATUM_PLANE_COLOR
	_datum_axis_material = StandardMaterial3D.new()
	_datum_axis_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_datum_axis_material.albedo_color = DATUM_AXIS_COLOR
	_datum_point_material = StandardMaterial3D.new()
	_datum_point_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_datum_point_material.albedo_color = DATUM_POINT_COLOR
	_section_shader = _make_section_shader()
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


func _make_section_shader() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec4 albedo_color : source_color = vec4(0.72, 0.74, 0.78, 1.0);
uniform vec3 section_point = vec3(0.0);
uniform vec3 section_normal = vec3(1.0, 0.0, 0.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.1;
uniform float roughness : hint_range(0.0, 1.0) = 0.55;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 2.0) = 0.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Discard the half-space in front of the section plane.
	if (dot(world_position - section_point, section_normal) > 0.0) {
		discard;
	}
	// Wireframe mode hides solid faces via transparent albedo.
	if (albedo_color.a < 0.01) {
		discard;
	}
	ALBEDO = albedo_color.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	EMISSION = emission_color.rgb * emission_energy;
}
"""
	return s


func _make_section_material(albedo: Color, emission: Color = Color(0, 0, 0), emission_energy: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _section_shader
	m.set_shader_parameter("albedo_color", albedo)
	m.set_shader_parameter("section_point", _section_point)
	m.set_shader_parameter("section_normal", _section_normal)
	m.set_shader_parameter("metallic", 0.1)
	m.set_shader_parameter("roughness", 0.55)
	m.set_shader_parameter("emission_color", emission)
	m.set_shader_parameter("emission_energy", emission_energy)
	return m


## Enable section-view clipping. Fragments with
## `dot(world_pos - point, normal) > 0` are discarded on body meshes.
## Edge overlay lines are left unclipped in v1.
func set_section_plane(point: Vector3, normal: Vector3) -> void:
	_section_point = point
	_section_normal = normal.normalized() if normal.length_squared() > 1e-12 else Vector3.RIGHT
	section_enabled = true
	_apply_selection_materials()


## Disable section-view clipping and restore StandardMaterial3D body materials.
func clear_section_plane() -> void:
	section_enabled = false
	_apply_selection_materials()


func set_display_mode(mode: int) -> void:
	display_mode = mode
	_apply_selection_materials()


func cycle_display_mode() -> int:
	set_display_mode((display_mode + 1) % 3)
	return display_mode


# --- creation (palette drop / click-to-place) ---

## Insert a palette primitive sitting on a horizontal floor through `world_point`.
## `world_point` is model (kernel Z-up) space: x/y = footprint center, z = floor
## height (0 = ground plane; top of another body = stack).
func insert_primitive(kind: String, world_point: Vector3) -> String:
	var p := world_point
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

## Ray in model space. Returns true on hit. With `additive` (Ctrl+click) the
## hit entity is toggled into the multi-select sets instead of replacing the
## selection: a face (or edge) when the hit body is already selected, else
## the whole body. Hidden bodies are skipped (pick-through).
func select_ray(origin: Vector3, direction: Vector3, additive := false) -> bool:
	var hit: Dictionary = _pick_visible(origin, direction)
	if hit.is_empty():
		if not additive:
			clear_selection()
		return false
	if additive:
		_toggle_hit(hit)
		return true
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


## Kernel pick that advances past hidden bodies so the next solid can be hit.
func _pick_visible(origin: Vector3, direction: Vector3) -> Dictionary:
	var d := direction.normalized() if direction.length_squared() > 1e-12 else direction
	var o := origin
	for _i in range(32):
		var hit: Dictionary = doc.pick(o, d)
		if hit.is_empty():
			return {}
		if not hidden_bodies.has(hit["body"]):
			return hit
		var pt: Vector3 = hit["point"]
		o = pt + d * 0.05
	return {}


func _toggle_hit(hit: Dictionary) -> void:
	var body: String = hit["body"]
	var body_selected := body == selected_body or selected_bodies.has(body)
	# In a multi-body set, ctrl+click on a member deselects it (SolidWorks
	# behavior); refinement to faces/edges applies to single-body selections.
	if selected_bodies.size() > 1 and selected_bodies.has(body):
		selected_bodies.erase(body)
	elif body_selected:
		# Refine within an already-selected body: edge first, then face.
		var edge := _edge_near_point(body, hit["point"])
		if edge != "":
			_toggle_in(selected_edges, edge)
		else:
			_toggle_in(selected_faces, hit["face"])
		# Keep the body's whole-body tint only if it has no sub-selection left.
		if selected_faces.is_empty() and selected_edges.is_empty():
			if not selected_bodies.has(body):
				selected_bodies.append(body)
		else:
			selected_bodies.erase(body)
	else:
		_toggle_in(selected_bodies, body)
	_sync_primary_from_sets()
	_apply_selection_materials()
	_highlight_edge()
	selection_changed.emit(selected_body, selected_face)


func _toggle_in(arr: Array[String], id: String) -> void:
	if arr.has(id):
		arr.erase(id)
	else:
		arr.append(id)


## Primary selection mirrors the most recently added set entry so existing
## single-select consumers (panels, cards) keep working during multi-select.
func _sync_primary_from_sets() -> void:
	if not selected_edges.is_empty():
		selected_edge = selected_edges.back()
		selected_body = _owner_body_of(selected_edge)
		selected_face = ""
	elif not selected_faces.is_empty():
		selected_face = selected_faces.back()
		selected_edge = ""
		selected_body = _owner_body_of(selected_face)
	elif not selected_bodies.is_empty():
		selected_body = selected_bodies.back()
		selected_face = ""
		selected_edge = ""
	else:
		selected_body = ""
		selected_face = ""
		selected_edge = ""


func _owner_body_of(subshape_id: String) -> String:
	for body_id in _face_ids:
		var faces: PackedStringArray = _face_ids[body_id]
		if faces.has(subshape_id):
			return body_id
	# Not a face: check edges per body.
	for body_id in _body_nodes:
		var lines: Dictionary = doc.get_edge_lines(body_id)
		if lines.has(subshape_id):
			return body_id
	return selected_body


## Number of selected entities across all sets (0 when nothing selected).
func selection_size() -> int:
	var n := selected_bodies.size() + selected_faces.size() + selected_edges.size()
	if n == 0 and selected_body != "":
		n = 1
	return n


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
	selected_bodies.clear()
	selected_faces.clear()
	selected_edges.assign([edge_id] if edge_id != "" else [])
	_apply_selection_materials()
	_highlight_edge()
	selection_changed.emit(selected_body, selected_face)


func pick_info(origin: Vector3, direction: Vector3) -> Dictionary:
	return _pick_visible(origin, direction)


## Select every visible body whose center unprojects inside `rect` (screen space).
## With `additive` false, replaces the selection; with true, unions into
## `selected_bodies`. Primary selection syncs to the last body in the set.
func select_in_rect(rect: Rect2, camera: Camera3D, model_space: Node3D, additive := false) -> void:
	var hits: Array[String] = []
	for id in _body_nodes:
		if hidden_bodies.has(id):
			continue
		var world: Vector3 = model_space.to_global(body_center(id))
		if camera.is_position_behind(world):
			continue
		var screen: Vector2 = camera.unproject_position(world)
		if rect.has_point(screen):
			hits.append(id)
	if not additive:
		selected_bodies.assign(hits)
		selected_faces.clear()
		selected_edges.clear()
	else:
		for id in hits:
			if not selected_bodies.has(id):
				selected_bodies.append(id)
	_sync_primary_from_sets()
	_apply_selection_materials()
	_highlight_edge()
	selection_changed.emit(selected_body, selected_face)


# --- visibility (hide / isolate) ---

func set_body_hidden(id: String, hidden: bool) -> void:
	if id == "":
		return
	if hidden:
		hidden_bodies[id] = true
		_remove_body_from_selection(id)
	else:
		hidden_bodies.erase(id)
	_apply_selection_materials()


## Hide every body not in `ids`. Empty `ids` unhides all (same as unhide_all).
func isolate(ids: Array) -> void:
	if ids.is_empty():
		unhide_all()
		return
	for body_id in _body_nodes.keys():
		if ids.has(body_id):
			hidden_bodies.erase(body_id)
		else:
			hidden_bodies[body_id] = true
			_remove_body_from_selection(body_id)
	_apply_selection_materials()


func unhide_all() -> void:
	if hidden_bodies.is_empty():
		_apply_selection_materials()
		return
	hidden_bodies.clear()
	_apply_selection_materials()


func _remove_body_from_selection(body_id: String) -> void:
	selected_bodies.erase(body_id)
	var drop_faces: Array[String] = []
	for f in selected_faces:
		if _owner_body_of(f) == body_id:
			drop_faces.append(f)
	for f in drop_faces:
		selected_faces.erase(f)
	var drop_edges: Array[String] = []
	for e in selected_edges:
		if _owner_body_of(e) == body_id:
			drop_edges.append(e)
	for e in drop_edges:
		selected_edges.erase(e)
	_sync_primary_from_sets()
	_highlight_edge()
	selection_changed.emit(selected_body, selected_face)


func select_entity(body_id: String, face_id: String) -> void:
	selected_body = body_id
	selected_face = face_id
	selected_edge = ""
	selected_bodies.assign([body_id] if body_id != "" and face_id == "" else [])
	selected_faces.assign([face_id] if face_id != "" else [])
	selected_edges.clear()
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
	hidden_bodies.clear()
	_after_mutation()
	return ok


func new_document() -> void:
	doc = SxDocument.new()
	clear_selection()
	hidden_bodies.clear()
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
			_body_materials.erase(body_id)
			hidden_bodies.erase(body_id)
	_refresh_datums()
	_refresh_instances()


func body_node(body_id: String) -> MeshInstance3D:
	return _body_nodes.get(body_id)


func datum_node(datum_id: String) -> Node3D:
	return _datum_nodes.get(datum_id)


func instance_node(instance_id: String) -> MeshInstance3D:
	return _instance_nodes.get(instance_id)


func _refresh_datums() -> void:
	var live := {}
	for d in doc.datum_list():
		var id: String = d["id"]
		live[id] = true
		_rebuild_datum(d)
	for id in _datum_nodes.keys().duplicate():
		if not live.has(id):
			_datum_nodes[id].queue_free()
			_datum_nodes.erase(id)


func _rebuild_datum(d: Dictionary) -> void:
	var id: String = d["id"]
	var kind: String = d["kind"]
	var node: Node3D = _datum_nodes.get(id)
	if node == null:
		node = MeshInstance3D.new()
		node.name = "Datum_" + id.left(8)
		add_child(node)
		_datum_nodes[id] = node
	var mi := node as MeshInstance3D
	match kind:
		"plane":
			mi.mesh = _make_datum_plane_mesh(d)
			mi.material_override = _datum_plane_material
			mi.transform = Transform3D.IDENTITY
		"axis":
			mi.mesh = _make_datum_axis_mesh(d)
			mi.material_override = _datum_axis_material
			mi.transform = Transform3D.IDENTITY
		"point":
			var sphere := SphereMesh.new()
			sphere.radius = DATUM_POINT_RADIUS
			sphere.height = DATUM_POINT_RADIUS * 2.0
			sphere.radial_segments = 12
			sphere.rings = 6
			mi.mesh = sphere
			mi.material_override = _datum_point_material
			var pos: Vector3 = d["position"]
			mi.transform = Transform3D(Basis.IDENTITY, pos)
		_:
			mi.mesh = null


func _make_datum_plane_mesh(d: Dictionary) -> ArrayMesh:
	var origin: Vector3 = d["origin"]
	var normal: Vector3 = d["normal"]
	var x_dir: Vector3 = d["x_dir"]
	var y_dir := normal.cross(x_dir).normalized()
	if y_dir.length_squared() < 1e-12:
		y_dir = Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		y_dir = normal.cross(y_dir).normalized()
	x_dir = y_dir.cross(normal).normalized()
	var hx := x_dir * DATUM_PLANE_HALF
	var hy := y_dir * DATUM_PLANE_HALF
	var c0 := origin - hx - hy
	var c1 := origin + hx - hy
	var c2 := origin + hx + hy
	var c3 := origin - hx + hy
	var verts := PackedVector3Array([c0, c1, c2, c0, c2, c3])
	var norms := PackedVector3Array()
	for _i in range(6):
		norms.append(normal)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _make_datum_axis_mesh(d: Dictionary) -> ImmediateMesh:
	var point: Vector3 = d["point"]
	var direction: Vector3 = d["direction"].normalized()
	var a := point - direction * DATUM_AXIS_HALF_LEN
	var b := point + direction * DATUM_AXIS_HALF_LEN
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(a)
	im.surface_add_vertex(b)
	im.surface_end()
	return im


# Instances reuse the source body's ArrayMesh with a node-local transform.
# Display modes / section shader are skipped in v1 (except WIREFRAME mesh hide).
func _refresh_instances() -> void:
	var live := {}
	for inst in doc.instance_list():
		var id: String = inst["id"]
		live[id] = true
		_rebuild_instance(inst)
	for id in _instance_nodes.keys().duplicate():
		if not live.has(id):
			_instance_nodes[id].queue_free()
			_instance_nodes.erase(id)
			_instance_materials.erase(id)


func _rebuild_instance(inst: Dictionary) -> void:
	var id: String = inst["id"]
	var source: String = inst["source_body"]
	var node: MeshInstance3D = _instance_nodes.get(id)
	if node == null:
		node = MeshInstance3D.new()
		node.name = "Instance_" + id.left(8)
		add_child(node)
		_instance_nodes[id] = node
	# Prefer sharing the already-tessellated body mesh; fall back to get_mesh.
	var src_node: MeshInstance3D = _body_nodes.get(source)
	if src_node != null and src_node.mesh != null:
		node.mesh = src_node.mesh
	else:
		node.mesh = doc.get_mesh(source)
	var translation: Vector3 = inst["translation"]
	var axis: Vector3 = inst["rotation_axis"]
	var angle_deg: float = inst["rotation_angle_deg"]
	var basis := Basis.IDENTITY
	if axis.length_squared() > 1e-12 and absf(angle_deg) > 1e-9:
		basis = Basis(axis.normalized(), deg_to_rad(angle_deg))
	node.transform = Transform3D(basis, translation)
	var tint: Color = doc.get_body_color(source).lightened(0.28)
	_instance_materials[id] = _make_material(tint)
	node.material_override = _instance_materials[id]
	# WIREFRAME: hide solid mesh (no instance edge overlay in v1).
	node.visible = display_mode != DisplayMode.WIREFRAME


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
	_body_materials[body_id] = _make_material(doc.get_body_color(body_id))
	_rebuild_edges(node.get_node("Edges") as MeshInstance3D, body_id)
	var shown := not hidden_bodies.has(body_id)
	node.visible = shown
	var edges_child: MeshInstance3D = node.get_node_or_null("Edges") as MeshInstance3D
	if edges_child != null:
		edges_child.visible = shown and display_mode != DisplayMode.SHADED


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
	# Highlight all selected edges (multi-select) in one overlay mesh.
	var targets: Array[String] = selected_edges.duplicate()
	if targets.is_empty() and selected_edge != "":
		targets.append(selected_edge)
	if targets.is_empty():
		_edge_highlight.mesh = null
		return
	var im := ImmediateMesh.new()
	var have_any := false
	for body_id in _body_nodes:
		var lines: Dictionary = doc.get_edge_lines(body_id)
		for edge_id in targets:
			if not lines.has(edge_id):
				continue
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
		_edge_highlight.mesh = im
	else:
		_edge_highlight.mesh = null


func _apply_selection_materials() -> void:
	for body_id in _body_nodes:
		var node: MeshInstance3D = _body_nodes[body_id]
		var faces: PackedStringArray = _face_ids.get(body_id, PackedStringArray())
		var body_selected: bool = body_id == selected_body or selected_bodies.has(body_id)
		var whole_body_selected: bool = selected_bodies.has(body_id) \
			or (body_id == selected_body and selected_face == "" and selected_edge == "")
		var base: StandardMaterial3D = _body_materials.get(body_id, _base_material)
		var body_shown := not hidden_bodies.has(body_id)
		node.visible = body_shown
		var edges: MeshInstance3D = node.get_node_or_null("Edges") as MeshInstance3D
		if edges != null:
			edges.visible = body_shown and display_mode != DisplayMode.SHADED
			if display_mode == DisplayMode.WIREFRAME and body_selected:
				edges.material_override = _selected_edge_material
			else:
				edges.material_override = _edge_material
		for i in range(node.mesh.get_surface_count() if node.mesh else 0):
			var face_here := faces[i] if i < faces.size() else ""
			var face_selected: bool = face_here != "" \
				and (face_here == selected_face or selected_faces.has(face_here))
			var mat: Material
			if display_mode == DisplayMode.WIREFRAME:
				if section_enabled:
					mat = _make_section_material(Color(0, 0, 0, 0))
				else:
					mat = _wireframe_hidden_material
			elif face_selected:
				if section_enabled:
					mat = _make_section_material(
						SELECTED_FACE_COLOR, SELECTED_FACE_COLOR, 0.35
					)
				else:
					mat = _selected_face_material
			elif whole_body_selected:
				if section_enabled:
					mat = _make_section_material(SELECTED_BODY_COLOR)
				else:
					mat = _selected_body_material
			else:
				if section_enabled:
					mat = _make_section_material(base.albedo_color)
				else:
					mat = base
			node.set_surface_override_material(i, mat)
	# Instances: v1 skips section/display shading; only honor WIREFRAME hide.
	for iid in _instance_nodes:
		var inode: MeshInstance3D = _instance_nodes[iid]
		inode.visible = display_mode != DisplayMode.WIREFRAME
		if _instance_materials.has(iid):
			inode.material_override = _instance_materials[iid]
