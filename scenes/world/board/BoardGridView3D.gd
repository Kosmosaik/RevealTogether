extends Node3D
class_name BoardGridView3D

const DEFAULT_BOARD_BASE_COLOR := Color(0.10, 0.13, 0.16, 1.0)
const DEFAULT_LOCKED_TILE_COLOR := Color(0.18, 0.22, 0.27, 1.0)
const DEFAULT_UNLOCKED_TILE_COLOR := Color(0.41, 0.67, 0.36, 1.0)
const DEFAULT_CLEARED_TILE_COLOR := Color(0.28, 0.31, 0.36, 1.0)
const DEFAULT_CHUNK_LINE_COLOR := Color(0.58, 0.64, 0.72, 1.0)

@onready var _board_base_mesh_instance: MeshInstance3D = $BoardBase
@onready var _locked_tiles_multimesh_instance: MultiMeshInstance3D = $LockedTiles
@onready var _unlocked_tiles_multimesh_instance: MultiMeshInstance3D = $UnlockedTiles
@onready var _cleared_tiles_multimesh_instance: MultiMeshInstance3D = $ClearedTiles
@onready var _chunk_line_container: Node3D = $ChunkLines

var _current_board_summary: Dictionary = {}
var _current_board_world_size: Vector2 = Vector2.ZERO
var _tile_snapshot_by_index: Dictionary = {}
var _reveal_underlay_mesh_instance: MeshInstance3D = null

func _ready() -> void:
	clear_board_visuals()

func apply_board_snapshot(board_snapshot: Dictionary) -> void:
	clear_board_visuals()

	var board_summary: Dictionary = board_snapshot.get("summary", {})
	_current_board_summary = board_summary.duplicate(true)
	_current_board_world_size = _calculate_board_world_size(
		int(_current_board_summary.get("board_width", 0)),
		int(_current_board_summary.get("board_height", 0))
	)

	var tile_snapshot_list: Array = board_snapshot.get("tiles", [])
	_store_tile_snapshots(tile_snapshot_list, true)

	_rebuild_board_base()
	_rebuild_reveal_underlay()
	_rebuild_tiles(_build_sorted_tile_snapshot_list())
	_rebuild_chunk_lines()

func apply_board_delta_payload(board_delta_payload: Dictionary) -> void:
	var board_summary_changed: bool = false

	var board_summary: Dictionary = board_delta_payload.get("board_summary", {})
	if not board_summary.is_empty():
		_current_board_summary = board_summary.duplicate(true)
		board_summary_changed = true

		var updated_board_world_size: Vector2 = _calculate_board_world_size(
			int(_current_board_summary.get("board_width", 0)),
			int(_current_board_summary.get("board_height", 0))
		)

		if updated_board_world_size != _current_board_world_size:
			_current_board_world_size = updated_board_world_size
			_rebuild_board_base()
			_rebuild_chunk_lines()
		else:
			_current_board_world_size = updated_board_world_size

	if board_summary_changed:
		_rebuild_reveal_underlay()

	var changed_tiles: Array = board_delta_payload.get("changed_tiles", [])
	if changed_tiles.is_empty():
		return

	_store_tile_snapshots(changed_tiles, false)
	_rebuild_tiles(_build_sorted_tile_snapshot_list())

func get_tile_index_from_world_position(world_position: Vector3) -> int:
	if _current_board_summary.is_empty():
		return -1

	var board_width: int = int(_current_board_summary.get("board_width", 0))
	var board_height: int = int(_current_board_summary.get("board_height", 0))
	if board_width <= 0 or board_height <= 0:
		return -1

	var tile_size: float = _get_tile_size()
	var tile_stride: float = _get_tile_stride()

	var local_x: float = world_position.x + (_current_board_world_size.x * 0.5)
	var local_z: float = world_position.z + (_current_board_world_size.y * 0.5)

	if local_x < 0.0 or local_z < 0.0:
		return -1
	if local_x >= _current_board_world_size.x or local_z >= _current_board_world_size.y:
		return -1

	var grid_x: int = int(floor(local_x / tile_stride))
	var grid_y: int = int(floor(local_z / tile_stride))

	if grid_x < 0 or grid_x >= board_width:
		return -1
	if grid_y < 0 or grid_y >= board_height:
		return -1

	var offset_within_cell_x: float = local_x - (float(grid_x) * tile_stride)
	var offset_within_cell_z: float = local_z - (float(grid_y) * tile_stride)

	if offset_within_cell_x > tile_size:
		return -1
	if offset_within_cell_z > tile_size:
		return -1

	return (grid_y * board_width) + grid_x

func _store_tile_snapshots(tile_snapshot_list: Array, replace_existing: bool) -> void:
	if replace_existing:
		_tile_snapshot_by_index.clear()

	for tile_snapshot_variant in tile_snapshot_list:
		var tile_snapshot: Dictionary = tile_snapshot_variant
		if tile_snapshot.is_empty():
			continue

		var tile_index: int = int(tile_snapshot.get("tile_index", -1))
		if tile_index < 0:
			continue

		var cached_tile_snapshot: Dictionary = {}
		if not replace_existing and _tile_snapshot_by_index.has(tile_index):
			cached_tile_snapshot = (_tile_snapshot_by_index[tile_index] as Dictionary).duplicate(true)

		for key_variant in tile_snapshot.keys():
			cached_tile_snapshot[key_variant] = tile_snapshot[key_variant]

		_tile_snapshot_by_index[tile_index] = cached_tile_snapshot


func _build_sorted_tile_snapshot_list() -> Array[Dictionary]:
	var tile_indices: Array = _tile_snapshot_by_index.keys()
	tile_indices.sort()

	var sorted_tile_snapshot_list: Array[Dictionary] = []
	for tile_index_variant in tile_indices:
		var tile_index: int = int(tile_index_variant)
		if not _tile_snapshot_by_index.has(tile_index):
			continue

		var tile_snapshot: Dictionary = _tile_snapshot_by_index[tile_index]
		sorted_tile_snapshot_list.append(tile_snapshot)

	return sorted_tile_snapshot_list

func clear_board_visuals() -> void:
	_clear_multimesh_instance(_locked_tiles_multimesh_instance)
	_clear_multimesh_instance(_unlocked_tiles_multimesh_instance)
	_clear_multimesh_instance(_cleared_tiles_multimesh_instance)
	_clear_chunk_lines()
	_clear_reveal_underlay()

	_board_base_mesh_instance.mesh = null
	_current_board_summary.clear()
	_current_board_world_size = Vector2.ZERO
	_tile_snapshot_by_index.clear()

func get_board_world_size() -> Vector2:
	return _current_board_world_size

func _rebuild_board_base() -> void:
	var board_base_height: float = max(
		RuntimeConfig.get_float(
			"board_view",
			"base_thickness",
			RuntimeConfig.get_float("board_view", "board_base_height", 0.30)
		),
		0.05
	)
	var board_base_margin: float = max(RuntimeConfig.get_float("board_view", "board_base_margin", 1.0), 0.0)
	var board_base_surface_drop: float = max(RuntimeConfig.get_float("board_view", "board_base_surface_drop", 0.02), 0.0)

	var board_base_mesh: BoxMesh = BoxMesh.new()
	board_base_mesh.size = Vector3(
		max(_current_board_world_size.x + (board_base_margin * 2.0), 1.0),
		board_base_height,
		max(_current_board_world_size.y + (board_base_margin * 2.0), 1.0)
	)
	_board_base_mesh_instance.mesh = board_base_mesh

	var board_base_material: StandardMaterial3D = _build_material(DEFAULT_BOARD_BASE_COLOR)
	_board_base_mesh_instance.material_override = board_base_material
	_board_base_mesh_instance.position = Vector3(0.0, -board_base_surface_drop - (board_base_height * 0.5), 0.0)

func _clear_reveal_underlay() -> void:
	if _reveal_underlay_mesh_instance == null:
		return

	_reveal_underlay_mesh_instance.mesh = null
	_reveal_underlay_mesh_instance.material_override = null
	_reveal_underlay_mesh_instance.visible = false


func _rebuild_reveal_underlay() -> void:
	var show_reveal_underlay: bool = RuntimeConfig.get_bool("board_view", "show_reveal_underlay", true)
	if not show_reveal_underlay:
		_clear_reveal_underlay()
		return

	if _current_board_summary.is_empty():
		_clear_reveal_underlay()
		return

	var reveal_image_id: String = String(_current_board_summary.get("reveal_image_id", ""))
	if reveal_image_id.is_empty():
		_clear_reveal_underlay()
		return

	var reveal_texture: Texture2D = load(reveal_image_id) as Texture2D
	if reveal_texture == null:
		_clear_reveal_underlay()
		return

	if _reveal_underlay_mesh_instance == null:
		_reveal_underlay_mesh_instance = MeshInstance3D.new()
		_reveal_underlay_mesh_instance.name = "RevealUnderlay"
		add_child(_reveal_underlay_mesh_instance)

	var reveal_underlay_mesh: PlaneMesh = PlaneMesh.new()
	reveal_underlay_mesh.size = _current_board_world_size
	reveal_underlay_mesh.subdivide_width = RuntimeConfig.get_int("board_view", "reveal_underlay_subdivide_width", 4)
	reveal_underlay_mesh.subdivide_depth = RuntimeConfig.get_int("board_view", "reveal_underlay_subdivide_depth", 4)

	var reveal_underlay_material: StandardMaterial3D = StandardMaterial3D.new()
	reveal_underlay_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	reveal_underlay_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	reveal_underlay_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	reveal_underlay_material.albedo_texture = reveal_texture
	reveal_underlay_material.albedo_color = Color.WHITE
	reveal_underlay_material.roughness = 1.0

	if RuntimeConfig.get_bool("board_view", "reveal_underlay_flip_v", true):
		reveal_underlay_material.uv1_scale = Vector3(1.0, -1.0, 1.0)
		reveal_underlay_material.uv1_offset = Vector3(0.0, 1.0, 0.0)

	var board_base_surface_drop: float = RuntimeConfig.get_float("board_view", "board_base_surface_drop", 0.02)
	var reveal_underlay_surface_lift: float = RuntimeConfig.get_float("board_view", "reveal_underlay_surface_lift", 0.005)

	_reveal_underlay_mesh_instance.mesh = reveal_underlay_mesh
	_reveal_underlay_mesh_instance.material_override = reveal_underlay_material
	_reveal_underlay_mesh_instance.position = Vector3(
		0.0,
		-board_base_surface_drop + reveal_underlay_surface_lift,
		0.0
	)
	_reveal_underlay_mesh_instance.visible = true

func _rebuild_tiles(tile_snapshot_list: Array) -> void:
	var locked_tile_positions: Array[Vector3] = []
	var unlocked_tile_positions: Array[Vector3] = []
	var cleared_tile_positions: Array[Vector3] = []

	for tile_snapshot_variant: Variant in tile_snapshot_list:
		var tile_snapshot: Dictionary = tile_snapshot_variant as Dictionary
		var tile_center_world_position: Vector3 = _build_tile_center_world_position(
			int(tile_snapshot.get("grid_x", 0)),
			int(tile_snapshot.get("grid_y", 0))
		)

		var is_cleared: bool = bool(tile_snapshot.get("is_cleared", false))
		var is_unlocked: bool = bool(tile_snapshot.get("is_unlocked", false))

		if is_cleared:
			cleared_tile_positions.append(tile_center_world_position)
		elif is_unlocked:
			unlocked_tile_positions.append(tile_center_world_position)
		else:
			locked_tile_positions.append(tile_center_world_position)

	var tile_height: float = _get_tile_size()
	var cleared_tile_height: float = tile_height * 0.1
	var reveal_underlay_is_visible: bool = _reveal_underlay_mesh_instance != null and _reveal_underlay_mesh_instance.visible

	var show_cleared_tiles: bool = false
	if reveal_underlay_is_visible:
		show_cleared_tiles = RuntimeConfig.get_bool("board_view", "show_cleared_tiles_with_underlay", false)
	else:
		show_cleared_tiles = RuntimeConfig.get_bool("board_view", "show_cleared_tiles_without_underlay", true)

	_apply_tile_group(
		_locked_tiles_multimesh_instance,
		locked_tile_positions,
		tile_height,
		DEFAULT_LOCKED_TILE_COLOR
	)
	_apply_tile_group(
		_unlocked_tiles_multimesh_instance,
		unlocked_tile_positions,
		tile_height,
		DEFAULT_UNLOCKED_TILE_COLOR
	)

	if show_cleared_tiles:
		_apply_tile_group(
			_cleared_tiles_multimesh_instance,
			cleared_tile_positions,
			cleared_tile_height,
			DEFAULT_CLEARED_TILE_COLOR
		)
	else:
		_clear_multimesh_instance(_cleared_tiles_multimesh_instance)

func _apply_tile_group(
	target_multimesh_instance: MultiMeshInstance3D,
	tile_center_positions: Array[Vector3],
	tile_height: float,
	tile_color: Color
) -> void:
	if tile_center_positions.is_empty():
		_clear_multimesh_instance(target_multimesh_instance)
		return

	var tile_size: float = _get_tile_size()
	var tile_mesh: BoxMesh = BoxMesh.new()
	tile_mesh.size = Vector3(tile_size, tile_height, tile_size)

	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.mesh = tile_mesh
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = tile_center_positions.size()
	multimesh.visible_instance_count = tile_center_positions.size()
	multimesh.custom_aabb = _build_multimesh_aabb(tile_height)

	for instance_index in tile_center_positions.size():
		var tile_center: Vector3 = tile_center_positions[instance_index]
		var tile_transform: Transform3D = Transform3D(
			Basis.IDENTITY,
			tile_center + Vector3(0.0, -(tile_height * 0.5), 0.0)
		)
		multimesh.set_instance_transform(instance_index, tile_transform)

	target_multimesh_instance.multimesh = multimesh
	target_multimesh_instance.material_override = _build_material(tile_color)

func _rebuild_chunk_lines() -> void:
	_clear_chunk_lines()

	if not RuntimeConfig.get_bool("board_view", "show_chunk_lines", true):
		return

	if _current_board_summary.is_empty():
		return

	var chunk_columns: int = int(_current_board_summary.get("chunk_columns", 0))
	var chunk_rows: int = int(_current_board_summary.get("chunk_rows", 0))
	var chunk_width: int = int(_current_board_summary.get("chunk_width", 1))
	var chunk_height: int = int(_current_board_summary.get("chunk_height", 1))

	var line_width: float = max(RuntimeConfig.get_float("board_view", "chunk_line_width", 0.06), 0.01)
	var line_height: float = max(RuntimeConfig.get_float("board_view", "chunk_line_height", 0.03), 0.01)
	var line_surface_lift: float = max(
		RuntimeConfig.get_float("board_view", "chunk_line_surface_lift", 0.0),
		0.0
	)
	var line_material: StandardMaterial3D = _build_material(DEFAULT_CHUNK_LINE_COLOR)

	var world_left_edge: float = -(_current_board_world_size.x * 0.5)
	var world_top_edge: float = -(_current_board_world_size.y * 0.5)
	var tile_stride: float = _get_tile_stride()
	var line_center_y: float = line_surface_lift + (line_height * 0.5)

	for chunk_column_index in range(1, chunk_columns):
		var crossed_tile_count_x: int = chunk_column_index * chunk_width
		var boundary_x: float = world_left_edge + (float(crossed_tile_count_x) * tile_stride) - (_get_tile_gap() * 0.5)

		var vertical_line_node: MeshInstance3D = _build_chunk_line_instance(
			Vector3(line_width, line_height, _current_board_world_size.y + line_width),
			Vector3(boundary_x, line_center_y, 0.0),
			line_material
		)
		_chunk_line_container.add_child(vertical_line_node)

	for chunk_row_index in range(1, chunk_rows):
		var crossed_tile_count_y: int = chunk_row_index * chunk_height
		var boundary_z: float = world_top_edge + (float(crossed_tile_count_y) * tile_stride) - (_get_tile_gap() * 0.5)

		var horizontal_line_node: MeshInstance3D = _build_chunk_line_instance(
			Vector3(_current_board_world_size.x + line_width, line_height, line_width),
			Vector3(0.0, line_center_y, boundary_z),
			line_material
		)
		_chunk_line_container.add_child(horizontal_line_node)

func _build_chunk_line_instance(
	line_size: Vector3,
	line_position: Vector3,
	line_material: StandardMaterial3D
) -> MeshInstance3D:
	var line_mesh: BoxMesh = BoxMesh.new()
	line_mesh.size = line_size

	var line_mesh_instance: MeshInstance3D = MeshInstance3D.new()
	line_mesh_instance.mesh = line_mesh
	line_mesh_instance.material_override = line_material
	line_mesh_instance.position = line_position
	return line_mesh_instance

func _clear_multimesh_instance(target_multimesh_instance: MultiMeshInstance3D) -> void:
	target_multimesh_instance.multimesh = null
	target_multimesh_instance.material_override = null

func _clear_chunk_lines() -> void:
	for child_node in _chunk_line_container.get_children():
		child_node.queue_free()

func _calculate_board_world_size(board_width: int, board_height: int) -> Vector2:
	return Vector2(
		_calculate_axis_world_span(board_width),
		_calculate_axis_world_span(board_height)
	)

func _calculate_axis_world_span(cell_count: int) -> float:
	if cell_count <= 0:
		return 0.0

	return (float(cell_count) * _get_tile_size()) + (float(cell_count - 1) * _get_tile_gap())

func _build_tile_center_world_position(grid_x: int, grid_y: int) -> Vector3:
	var first_tile_center_x: float = -(_current_board_world_size.x * 0.5) + (_get_tile_size() * 0.5)
	var first_tile_center_z: float = -(_current_board_world_size.y * 0.5) + (_get_tile_size() * 0.5)
	var tile_stride: float = _get_tile_stride()

	return Vector3(
		first_tile_center_x + (float(grid_x) * tile_stride),
		0.0,
		first_tile_center_z + (float(grid_y) * tile_stride)
	)

func _build_multimesh_aabb(tile_height: float) -> AABB:
	return AABB(
		Vector3(
			-(_current_board_world_size.x * 0.5),
			-tile_height - 0.25,
			-(_current_board_world_size.y * 0.5)
		),
		Vector3(
			max(_current_board_world_size.x, 0.1),
			tile_height + 0.5,
			max(_current_board_world_size.y, 0.1)
		)
	)

func _build_material(albedo_color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = albedo_color
	material.roughness = 1.0
	material.metallic = 0.0
	return material

func _get_tile_size() -> float:
	return max(RuntimeConfig.get_float("board_view", "tile_size", 1.0), 0.1)

func _get_tile_gap() -> float:
	return max(RuntimeConfig.get_float("board_view", "tile_gap", 0.04), 0.0)

func _get_tile_stride() -> float:
	return _get_tile_size() + _get_tile_gap()
