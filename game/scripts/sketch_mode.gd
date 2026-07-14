class_name SketchMode
extends Node3D
## In-viewport sketch editing. Owns an SxSketch, renders its entities on the
## sketch plane, and converts viewport rays to sketch 2D coordinates.
## Tools: line chain, rectangle, circle. Finish extrudes the profile.

signal finished(body_id: String)
signal cancelled
signal status(text: String)

enum Tool { NONE, LINE, RECT, CIRCLE }

var sketch: SxSketch
var view: DocumentView
var tool: Tool = Tool.NONE
var active := false

# Sketch plane frame in model space.
var plane_origin := Vector3.ZERO
var plane_x := Vector3.RIGHT
var plane_y := Vector3.UP  # model-space Y (kernel), set on begin()

var _draw_node: MeshInstance3D
var _preview_node: MeshInstance3D
var _tool_points: Array[Vector2] = []  # committed anchor points of current tool
var _hover: Vector2 = Vector2.ZERO
var _line_material: StandardMaterial3D
var _preview_material: StandardMaterial3D


func _ready() -> void:
	_line_material = StandardMaterial3D.new()
	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.albedo_color = Color(0.95, 0.95, 1.0)
	_preview_material = StandardMaterial3D.new()
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_material.albedo_color = Color(0.5, 0.8, 1.0, 0.8)
	_draw_node = MeshInstance3D.new()
	_draw_node.material_override = _line_material
	add_child(_draw_node)
	_preview_node = MeshInstance3D.new()
	_preview_node.material_override = _preview_material
	add_child(_preview_node)


## Begin a sketch on the model-space plane (origin + normal). x_hint picks the
## in-plane X direction; pass ZERO for an automatic perpendicular.
func begin(origin: Vector3, normal: Vector3, x_hint: Vector3 = Vector3.ZERO) -> void:
	plane_origin = origin
	var n := normal.normalized()
	var x := x_hint
	if x == Vector3.ZERO or absf(x.dot(n)) > 0.99:
		x = Vector3.RIGHT if absf(n.dot(Vector3.RIGHT)) < 0.9 else Vector3(0, 1, 0)
	plane_x = (x - n * x.dot(n)).normalized()
	plane_y = n.cross(plane_x).normalized()
	sketch = SxSketch.new()
	sketch.set_plane(origin, plane_x, plane_y)
	active = true
	tool = Tool.LINE
	_tool_points.clear()
	_redraw()
	status.emit("Sketch: L line · R rect · C circle · Enter finish+extrude · Esc cancel")


func cancel() -> void:
	active = false
	_tool_points.clear()
	_clear_meshes()
	cancelled.emit()


## Finish the sketch and extrude by `distance` (model units).
func finish_extrude(distance: float) -> void:
	if not active:
		return
	var body_id: String = view.doc.extrude_sketch(sketch, distance, false)
	active = false
	_tool_points.clear()
	_clear_meshes()
	if body_id == "":
		status.emit("Extrude failed — is the profile closed?")
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
	_update_preview()


func click(pos2: Vector2) -> void:
	if not active:
		return
	match tool:
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
	_update_preview()


## Double-click or right-click ends a line chain.
func end_chain() -> void:
	_tool_points.clear()
	_update_preview()


func hover(pos2: Vector2) -> void:
	_hover = pos2
	_update_preview()


func _to3(p: Vector2) -> Vector3:
	return plane_origin + plane_x * p.x + plane_y * p.y


func _clear_meshes() -> void:
	_draw_node.mesh = null
	_preview_node.mesh = null


func _redraw() -> void:
	if sketch == null:
		return
	var im := ImmediateMesh.new()
	var has := false
	for id in sketch.entity_ids():
		var info: Dictionary = sketch.entity_info(id)
		match info.get("type", ""):
			"line":
				if not has:
					im.surface_begin(Mesh.PRIMITIVE_LINES)
					has = true
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
					im.surface_add_vertex(_to3(c2 + Vector2(cos(a0), sin(a0)) * r2))
					im.surface_add_vertex(_to3(c2 + Vector2(cos(a1), sin(a1)) * r2))
	if has:
		im.surface_end()
		_draw_node.mesh = im
	else:
		_draw_node.mesh = null


func _update_preview() -> void:
	var im := ImmediateMesh.new()
	var has := false
	if _tool_points.size() > 0:
		var last := _tool_points[_tool_points.size() - 1]
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		has = true
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
	if has:
		im.surface_end()
		_preview_node.mesh = im
	else:
		_preview_node.mesh = null
