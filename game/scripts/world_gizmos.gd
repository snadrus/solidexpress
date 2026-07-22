class_name WorldGizmos
extends Node3D
## Reference grid on the active move plane (default: model XY / Z = 0).
## RGB origin sticks live on the ViewHud (OriginTriadHud), not on this plate.
## Sibling of DocumentView under ModelSpace.

## Match place-snap (0.1 mm): minor every 0.1, major every 1.0, ±50 mm sheet.
const GRID_HALF := 50.0
const GRID_STEP := 0.1
const GRID_MAJOR := 1.0

const COLOR_GRID := Color(0.32, 0.33, 0.36)
const COLOR_GRID_MAJOR := Color(0.48, 0.49, 0.54)
const COLOR_GRID_CENTER_X := Color(0.72, 0.28, 0.26)
const COLOR_GRID_CENTER_Y := Color(0.28, 0.68, 0.32)

var gizmos_visible := true
var grid_visible := true

var _grid: MeshInstance3D
## Stash if set_active_plane runs before _ready builds the grid.
var _pending_plane: Dictionary = {}


func _ready() -> void:
	_grid = MeshInstance3D.new()
	_grid.name = "Grid"
	_grid.mesh = _make_grid_mesh()
	_grid.material_override = _unshaded_vertex_color_material()
	add_child(_grid)
	if not _pending_plane.is_empty():
		set_active_plane(_pending_plane["origin"], _pending_plane["normal"])
		_pending_plane.clear()

	_apply_visibility()


func set_gizmos_visible(on: bool) -> void:
	gizmos_visible = on
	_apply_visibility()


func set_grid_visible(on: bool) -> void:
	grid_visible = on
	_apply_visibility()


## Place the white reference grid on `origin` with in-plane axes derived from
## `normal` (mesh is authored on local XY).
func set_active_plane(origin: Vector3, normal: Vector3) -> void:
	var n := normal.normalized()
	if n.length_squared() < 1e-12:
		n = Vector3(0, 0, 1)
	var x := n.cross(Vector3(0, 0, 1))
	if x.length_squared() < 1e-12:
		x = Vector3.RIGHT
	else:
		x = x.normalized()
	var y := n.cross(x).normalized()
	if _grid == null:
		# Called before _ready in some headless setups — stash for _ready.
		_pending_plane = {"origin": origin, "normal": n}
		return
	_grid.transform = Transform3D(Basis(x, y, n), origin)


func _apply_visibility() -> void:
	if _grid:
		_grid.visible = gizmos_visible and grid_visible


func _unshaded_vertex_color_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	return m


## Reference grid on local XY (Z = 0); transform places it on the active plane.
func _make_grid_mesh() -> ImmediateMesh:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	# Integer indices avoid float drift so major lines land on GRID_MAJOR.
	var n := int(round(GRID_HALF / GRID_STEP))
	var major_every := maxi(int(round(GRID_MAJOR / GRID_STEP)), 1)
	for k in range(-n, n + 1):
		var i := float(k) * GRID_STEP
		var is_center := k == 0
		var is_major := not is_center and (k % major_every) == 0
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
	im.surface_end()
	return im
