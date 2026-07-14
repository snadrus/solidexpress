class_name WorldGizmos
extends Node3D
## Origin triad (RGB XYZ) and reference grid on the model XY ground plane
## (kernel Z-up). Sibling of DocumentView under ModelSpace.

const TRIAD_LEN := 20.0
const TRIAD_RADIUS := 0.35
const GRID_HALF := 100.0
const GRID_STEP := 10.0
const GRID_MAJOR := 50.0

const COLOR_X := Color(0.92, 0.22, 0.18)
const COLOR_Y := Color(0.22, 0.82, 0.28)
const COLOR_Z := Color(0.22, 0.42, 0.95)
const COLOR_GRID := Color(0.32, 0.33, 0.36)
const COLOR_GRID_MAJOR := Color(0.48, 0.49, 0.54)
const COLOR_GRID_CENTER_X := Color(0.72, 0.28, 0.26)
const COLOR_GRID_CENTER_Y := Color(0.28, 0.68, 0.32)

var gizmos_visible := true
var triad_visible := true
var grid_visible := true

var _triad: Node3D
var _grid: MeshInstance3D


func _ready() -> void:
	_triad = Node3D.new()
	_triad.name = "Triad"
	add_child(_triad)
	_triad.add_child(_make_axis_cylinder(Vector3.RIGHT, COLOR_X, "AxisX"))
	_triad.add_child(_make_axis_cylinder(Vector3.UP, COLOR_Y, "AxisY"))
	_triad.add_child(_make_axis_cylinder(Vector3(0, 0, 1), COLOR_Z, "AxisZ"))

	_grid = MeshInstance3D.new()
	_grid.name = "Grid"
	_grid.mesh = _make_grid_mesh()
	_grid.material_override = _unshaded_vertex_color_material()
	add_child(_grid)

	_apply_visibility()


func set_gizmos_visible(on: bool) -> void:
	gizmos_visible = on
	_apply_visibility()


func set_triad_visible(on: bool) -> void:
	triad_visible = on
	_apply_visibility()


func set_grid_visible(on: bool) -> void:
	grid_visible = on
	_apply_visibility()


func _apply_visibility() -> void:
	if _triad:
		_triad.visible = gizmos_visible and triad_visible
	if _grid:
		_grid.visible = gizmos_visible and grid_visible


func _unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m


func _unshaded_vertex_color_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	return m


## Thin cylinder from origin along +dir, length TRIAD_LEN.
func _make_axis_cylinder(dir: Vector3, color: Color, node_name: String) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = TRIAD_RADIUS
	cyl.bottom_radius = TRIAD_RADIUS
	cyl.height = TRIAD_LEN
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = cyl
	mi.material_override = _unshaded(color)
	# CylinderMesh height is local +Y; map local Y onto dir.
	var y := dir.normalized()
	var x := y.cross(Vector3(0, 0, 1))
	if x.length_squared() < 1e-8:
		x = y.cross(Vector3(1, 0, 0))
	x = x.normalized()
	var z := x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x, y, z), y * (TRIAD_LEN * 0.5))
	return mi


## Reference grid on the model XY plane (Z = 0).
func _make_grid_mesh() -> ImmediateMesh:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var i := -GRID_HALF
	while i <= GRID_HALF + 0.001:
		var is_center := absf(i) < 0.001
		var is_major := not is_center and absf(fmod(absf(i), GRID_MAJOR)) < 0.001
		# Lines parallel to Y (constant X).
		if is_center:
			im.surface_set_color(COLOR_GRID_CENTER_Y)
		elif is_major:
			im.surface_set_color(COLOR_GRID_MAJOR)
		else:
			im.surface_set_color(COLOR_GRID)
		im.surface_add_vertex(Vector3(i, -GRID_HALF, 0))
		im.surface_add_vertex(Vector3(i, GRID_HALF, 0))
		# Lines parallel to X (constant Y).
		if is_center:
			im.surface_set_color(COLOR_GRID_CENTER_X)
		elif is_major:
			im.surface_set_color(COLOR_GRID_MAJOR)
		else:
			im.surface_set_color(COLOR_GRID)
		im.surface_add_vertex(Vector3(-GRID_HALF, i, 0))
		im.surface_add_vertex(Vector3(GRID_HALF, i, 0))
		i += GRID_STEP
	im.surface_end()
	return im
