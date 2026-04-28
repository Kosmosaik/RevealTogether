extends Node3D
class_name BoardGridView3D

const DEFAULT_BOARD_BASE_COLOR := Color(0.10, 0.13, 0.16, 1.0)
const DEFAULT_CHUNK_LINE_COLOR := Color(0.58, 0.64, 0.72, 1.0)
const DEFAULT_CLAIMED_TILE_COLOR := Color(0.90, 0.76, 0.35, 1.0)
const TILE_VISUAL_ROOT_NODE_NAME := "TileVisuals"
const CLAIMED_TILES_MULTIMESH_NODE_NAME := "ClaimedTiles"
const MULTIMESH_GROUP_LOCKED := "locked"
const MULTIMESH_GROUP_UNLOCKED := "unlocked"
const MULTIMESH_GROUP_CLAIMED := "claimed"
const MULTIMESH_GROUP_CLEARED := "cleared"

const DETAIL_CANDIDATE_PRIORITY_IMPORTANT := 0
const DETAIL_CANDIDATE_PRIORITY_HOVERED := 1
const DETAIL_CANDIDATE_PRIORITY_FOCUS := 2
const DETAIL_CANDIDATE_PRIORITY_NEARBY := 10

signal board_visual_build_started(total_tile_count: int)
signal board_visual_build_progress(processed_tile_count: int, total_tile_count: int)
signal board_visual_build_completed(total_tile_count: int)

@onready var _board_base_mesh_instance: MeshInstance3D = $BoardBase
@onready var _locked_tiles_multimesh_instance: MultiMeshInstance3D = $LockedTiles
@onready var _unlocked_tiles_multimesh_instance: MultiMeshInstance3D = $UnlockedTiles
@onready var _cleared_tiles_multimesh_instance: MultiMeshInstance3D = $ClearedTiles
@onready var _chunk_line_container: Node3D = $ChunkLines

var _current_board_summary: Dictionary = {}
var _current_board_world_size: Vector2 = Vector2.ZERO
var _tile_snapshot_by_index: Dictionary = {}
var _tile_visual_by_index: Dictionary = {}
var _reveal_underlay_mesh_instance: MeshInstance3D = null
var _tile_visual_root: Node3D = null
var _tile_variant_def_by_id: Dictionary = {}
var _claimed_tiles_multimesh_instance: MultiMeshInstance3D = null
var _indexed_multimesh_tile_capacity: int = 0
var _hidden_multimesh_tile_transform: Transform3D = Transform3D.IDENTITY

var _detail_focus_tile_index: int = -1
var _detail_hovered_tile_index: int = -1
var _next_detail_overlay_refresh_ticks_msec: int = 0
var _important_detail_tile_expire_time_by_index: Dictionary = {}
var _detail_overlay_tile_indices: Dictionary = {}

var _board_visuals_ready_for_interaction: bool = true
var _progressive_multimesh_build_active: bool = false
var _progressive_multimesh_pending_tile_indices: Array[int] = []
var _progressive_multimesh_next_pending_index: int = 0
var _progressive_multimesh_last_logged_processed_count: int = 0

func _ready() -> void:
	_tile_variant_def_by_id = BoardTileContentCatalog.build_variant_by_id()
	_ensure_tile_visual_root()
	_ensure_claimed_tiles_multimesh_instance()
	_locked_tiles_multimesh_instance.visible = false
	_unlocked_tiles_multimesh_instance.visible = false
	_cleared_tiles_multimesh_instance.visible = false
	_claimed_tiles_multimesh_instance.visible = false
	clear_board_visuals()
	
func _process(_delta: float) -> void:
	_process_progressive_multimesh_build()

func apply_board_snapshot(board_snapshot: Dictionary) -> void:
	clear_board_visuals()
	_board_visuals_ready_for_interaction = false

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
	var board_layout_changed: bool = false
	var reveal_underlay_changed: bool = false

	var previous_reveal_image_id: String = String(_current_board_summary.get("reveal_image_id", ""))
	var board_summary: Dictionary = board_delta_payload.get("board_summary", {})
	if not board_summary.is_empty():
		_current_board_summary = board_summary.duplicate(true)

		var updated_board_world_size: Vector2 = _calculate_board_world_size(
			int(_current_board_summary.get("board_width", 0)),
			int(_current_board_summary.get("board_height", 0))
		)

		if updated_board_world_size != _current_board_world_size:
			_current_board_world_size = updated_board_world_size
			board_layout_changed = true
			_rebuild_board_base()
			_rebuild_chunk_lines()
		else:
			_current_board_world_size = updated_board_world_size

		var current_reveal_image_id: String = String(_current_board_summary.get("reveal_image_id", ""))
		if current_reveal_image_id != previous_reveal_image_id:
			reveal_underlay_changed = true

	if board_layout_changed or reveal_underlay_changed:
		_rebuild_reveal_underlay()

	var changed_tiles: Array = board_delta_payload.get("changed_tiles", [])
	if changed_tiles.is_empty():
		if board_layout_changed:
			_rebuild_tiles(_build_sorted_tile_snapshot_list())
		return

	_store_tile_snapshots(changed_tiles, false)

	var cached_changed_tile_snapshot_list: Array[Dictionary] = _build_cached_tile_snapshot_list(changed_tiles)

	if board_layout_changed:
		_rebuild_tiles(_build_sorted_tile_snapshot_list())
		if _progressive_multimesh_build_active:
			return
		_mark_detail_tiles_important_from_snapshot_list(cached_changed_tile_snapshot_list)
		_refresh_large_board_detail_overlay()
		return

	if _should_use_multimesh_tile_rendering():
		_apply_multimesh_tile_visuals(cached_changed_tile_snapshot_list)
		if _progressive_multimesh_build_active:
			return
		_mark_detail_tiles_important_from_snapshot_list(cached_changed_tile_snapshot_list)
		_refresh_large_board_detail_overlay()
		return

	_apply_tile_visuals(cached_changed_tile_snapshot_list)

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

func set_detail_focus_world_position(focus_world_position: Vector3, hovered_tile_index: int) -> void:
	if _progressive_multimesh_build_active:
		return

	if not _should_use_multimesh_tile_rendering():
		return

	var focus_tile_index: int = get_tile_index_from_world_position(focus_world_position)

	var sanitized_hovered_tile_index: int = hovered_tile_index
	if not _is_tile_index_inside_board(sanitized_hovered_tile_index):
		sanitized_hovered_tile_index = -1

	var current_ticks_msec: int = Time.get_ticks_msec()
	var focus_is_unchanged: bool = focus_tile_index == _detail_focus_tile_index
	var hover_is_unchanged: bool = sanitized_hovered_tile_index == _detail_hovered_tile_index

	if focus_is_unchanged and hover_is_unchanged:
		if current_ticks_msec < _next_detail_overlay_refresh_ticks_msec:
			return

	_detail_focus_tile_index = focus_tile_index
	_detail_hovered_tile_index = sanitized_hovered_tile_index
	_next_detail_overlay_refresh_ticks_msec = current_ticks_msec + _get_detail_overlay_refresh_interval_msec()

	_refresh_large_board_detail_overlay()

func mark_detail_tile_important(tile_index: int) -> void:
	if _progressive_multimesh_build_active:
		return

	if not _should_use_multimesh_tile_rendering():
		return

	if not _is_tile_index_inside_board(tile_index):
		return

	if not _tile_snapshot_by_index.has(tile_index):
		return

	var hold_duration_msec: int = max(
		RuntimeConfig.get_int("board_view", "detail_overlay_changed_tile_hold_ms", 1500),
		0
	)
	if hold_duration_msec <= 0:
		return

	var expire_time_msec: int = Time.get_ticks_msec() + hold_duration_msec
	_important_detail_tile_expire_time_by_index[tile_index] = expire_time_msec
	_refresh_large_board_detail_overlay()

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

func _build_cached_tile_snapshot_list(tile_delta_payload_list: Array) -> Array[Dictionary]:
	var tile_snapshot_list: Array[Dictionary] = []

	for tile_delta_payload_variant in tile_delta_payload_list:
		var tile_delta_payload: Dictionary = tile_delta_payload_variant
		if tile_delta_payload.is_empty():
			continue

		var tile_index: int = int(tile_delta_payload.get("tile_index", -1))
		if tile_index < 0:
			continue
		if not _tile_snapshot_by_index.has(tile_index):
			continue

		var tile_snapshot: Dictionary = _tile_snapshot_by_index[tile_index]
		tile_snapshot_list.append(tile_snapshot)

	return tile_snapshot_list

func clear_board_visuals() -> void:
	_cancel_progressive_multimesh_build()
	_clear_all_tile_multimeshes()
	_clear_chunk_lines()
	_clear_reveal_underlay()
	_clear_tile_visuals()

	_board_base_mesh_instance.mesh = null
	_current_board_summary.clear()
	_current_board_world_size = Vector2.ZERO
	_tile_snapshot_by_index.clear()

	_detail_focus_tile_index = -1
	_detail_hovered_tile_index = -1
	_next_detail_overlay_refresh_ticks_msec = 0
	_important_detail_tile_expire_time_by_index.clear()
	_detail_overlay_tile_indices.clear()

	_board_visuals_ready_for_interaction = true

func get_board_world_size() -> Vector2:
	return _current_board_world_size
	
func is_board_ready_for_interaction() -> bool:
	return _board_visuals_ready_for_interaction

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

	var board_base_color: Color = RuntimeConfig.get_color(
		"board_view",
		"base_color",
		DEFAULT_BOARD_BASE_COLOR
	)
	var board_base_material: StandardMaterial3D = _build_material(board_base_color)
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
	_cancel_progressive_multimesh_build()
	_board_visuals_ready_for_interaction = false

	if _should_use_multimesh_tile_rendering():
		_clear_tile_visuals()

		if _should_use_progressive_multimesh_tile_build(tile_snapshot_list.size()):
			_begin_progressive_multimesh_tile_build()
			return

		_rebuild_multimesh_tile_visuals(tile_snapshot_list)
		_refresh_large_board_detail_overlay()
		_board_visuals_ready_for_interaction = true
		return

	_clear_all_tile_multimeshes()
	_rebuild_tile_visuals(tile_snapshot_list)
	_board_visuals_ready_for_interaction = true

func _should_use_multimesh_tile_rendering() -> bool:
	if RuntimeConfig.get_bool("board_view", "use_multimesh_tiles", false):
		return true

	var tile_count: int = int(_current_board_summary.get("tile_count", _tile_snapshot_by_index.size()))
	var large_board_threshold: int = max(RuntimeConfig.get_int("board_view", "large_board_multimesh_threshold", 4096), 1)
	return tile_count > large_board_threshold

func _should_use_progressive_multimesh_tile_build(tile_snapshot_count: int) -> bool:
	if not RuntimeConfig.get_bool("board_view", "progressive_multimesh_build_enabled", true):
		return false

	var tile_count: int = int(_current_board_summary.get("tile_count", tile_snapshot_count))
	if tile_count <= 0:
		return false

	var progressive_threshold: int = max(
		RuntimeConfig.get_int("board_view", "progressive_multimesh_build_threshold", 16384),
		1
	)

	return tile_count >= progressive_threshold


func _begin_progressive_multimesh_tile_build() -> void:
	_cancel_progressive_multimesh_build()

	_board_visuals_ready_for_interaction = false
	_detail_overlay_tile_indices.clear()
	_important_detail_tile_expire_time_by_index.clear()

	_ensure_indexed_multimesh_tile_visuals(false, false)

	if _indexed_multimesh_tile_capacity <= 0:
		_board_visuals_ready_for_interaction = true
		return

	_progressive_multimesh_pending_tile_indices = _build_progressive_multimesh_tile_index_list()
	_progressive_multimesh_next_pending_index = 0
	_progressive_multimesh_last_logged_processed_count = 0
	_progressive_multimesh_build_active = true

	emit_signal("board_visual_build_started", _progressive_multimesh_pending_tile_indices.size())

	LogService.info(
		"WORLD",
		"Started progressive multimesh board visual build for %s tile(s)." % _progressive_multimesh_pending_tile_indices.size()
	)


func _cancel_progressive_multimesh_build() -> void:
	_progressive_multimesh_build_active = false
	_progressive_multimesh_pending_tile_indices.clear()
	_progressive_multimesh_next_pending_index = 0
	_progressive_multimesh_last_logged_processed_count = 0


func _build_progressive_multimesh_tile_index_list() -> Array[int]:
	var tile_index_list: Array[int] = []

	for tile_index in range(_indexed_multimesh_tile_capacity):
		tile_index_list.append(tile_index)

	return tile_index_list


func _process_progressive_multimesh_build() -> void:
	if not _progressive_multimesh_build_active:
		return

	var batch_size: int = max(
		RuntimeConfig.get_int("board_view", "progressive_multimesh_build_batch_size", 4096),
		1
	)

	var processed_this_frame: int = 0
	var total_tile_count: int = _progressive_multimesh_pending_tile_indices.size()

	while processed_this_frame < batch_size:
		if _progressive_multimesh_next_pending_index >= total_tile_count:
			break

		var tile_index: int = _progressive_multimesh_pending_tile_indices[_progressive_multimesh_next_pending_index]

		if _tile_snapshot_by_index.has(tile_index):
			var tile_snapshot: Dictionary = _tile_snapshot_by_index[tile_index]
			_apply_multimesh_tile_visual(tile_snapshot)
		else:
			_clear_indexed_multimesh_tile(tile_index)

		_progressive_multimesh_next_pending_index += 1
		processed_this_frame += 1

	_emit_progressive_multimesh_build_progress_if_needed()

	if _progressive_multimesh_next_pending_index >= total_tile_count:
		_finish_progressive_multimesh_tile_build()


func _emit_progressive_multimesh_build_progress_if_needed() -> void:
	var total_tile_count: int = _progressive_multimesh_pending_tile_indices.size()
	var processed_tile_count: int = _progressive_multimesh_next_pending_index

	emit_signal("board_visual_build_progress", processed_tile_count, total_tile_count)

	var log_interval_tiles: int = max(
		RuntimeConfig.get_int("board_view", "progressive_multimesh_build_log_interval_tiles", 32768),
		0
	)
	if log_interval_tiles <= 0:
		return

	var tiles_since_last_log: int = processed_tile_count - _progressive_multimesh_last_logged_processed_count
	if tiles_since_last_log < log_interval_tiles and processed_tile_count < total_tile_count:
		return

	_progressive_multimesh_last_logged_processed_count = processed_tile_count

	LogService.info(
		"WORLD",
		"Progressive multimesh board visual build: %s/%s tile(s)." % [
			processed_tile_count,
			total_tile_count
		]
	)


func _finish_progressive_multimesh_tile_build() -> void:
	var total_tile_count: int = _progressive_multimesh_pending_tile_indices.size()

	_progressive_multimesh_build_active = false
	_progressive_multimesh_pending_tile_indices.clear()
	_progressive_multimesh_next_pending_index = 0
	_progressive_multimesh_last_logged_processed_count = 0

	_set_all_indexed_multimesh_groups_visible(true)
	_board_visuals_ready_for_interaction = true
	_refresh_large_board_detail_overlay()

	emit_signal("board_visual_build_completed", total_tile_count)

	LogService.info(
		"WORLD",
		"Completed progressive multimesh board visual build for %s tile(s)." % total_tile_count
	)

func _rebuild_multimesh_tile_visuals(tile_snapshot_list: Array) -> void:
	_ensure_indexed_multimesh_tile_visuals()
	_clear_indexed_multimesh_tile_visuals()
	_apply_multimesh_tile_visuals(tile_snapshot_list)

func _apply_multimesh_tile_visuals(tile_snapshot_list: Array) -> void:
	_ensure_indexed_multimesh_tile_visuals()

	for tile_snapshot_variant in tile_snapshot_list:
		var tile_snapshot: Dictionary = tile_snapshot_variant as Dictionary
		if tile_snapshot.is_empty():
			continue

		_apply_multimesh_tile_visual(tile_snapshot)

func _apply_multimesh_tile_visual(tile_snapshot: Dictionary) -> void:
	var tile_index: int = int(tile_snapshot.get("tile_index", -1))
	if tile_index < 0:
		return
	if tile_index >= _indexed_multimesh_tile_capacity:
		return

	_clear_indexed_multimesh_tile(tile_index)

	if _detail_overlay_tile_indices.has(tile_index):
		return

	var multimesh_group: String = _get_multimesh_group_for_tile_snapshot(tile_snapshot)
	if multimesh_group.is_empty():
		return

	var target_multimesh_instance: MultiMeshInstance3D = _get_multimesh_instance_for_group(multimesh_group)
	if target_multimesh_instance == null:
		return
	if target_multimesh_instance.multimesh == null:
		return

	var tile_transform: Transform3D = _build_tile_cover_transform(tile_snapshot)
	target_multimesh_instance.multimesh.set_instance_transform(tile_index, tile_transform)

func _ensure_indexed_multimesh_tile_visuals(
	initialize_hidden_transforms: bool = true,
	make_visible_after_configure: bool = true
) -> void:
	var tile_capacity: int = _resolve_multimesh_tile_capacity()
	if tile_capacity <= 0:
		_clear_all_tile_multimeshes()
		return

	if _indexed_multimesh_tile_capacity == tile_capacity:
		if _is_indexed_multimesh_group_ready(_locked_tiles_multimesh_instance, tile_capacity):
			if _is_indexed_multimesh_group_ready(_unlocked_tiles_multimesh_instance, tile_capacity):
				if _is_indexed_multimesh_group_ready(_claimed_tiles_multimesh_instance, tile_capacity):
					if _is_indexed_multimesh_group_ready(_cleared_tiles_multimesh_instance, tile_capacity):
						_set_all_indexed_multimesh_groups_visible(make_visible_after_configure)
						return

	_indexed_multimesh_tile_capacity = tile_capacity
	_hidden_multimesh_tile_transform = _build_hidden_multimesh_tile_transform()

	var tile_mesh: BoxMesh = BoxMesh.new()
	var tile_size: float = _get_tile_size()
	var tile_height: float = _get_multimesh_tile_cover_height()
	tile_mesh.size = Vector3(tile_size, tile_height, tile_size)

	_configure_indexed_multimesh_group(
		_locked_tiles_multimesh_instance,
		tile_mesh,
		tile_capacity,
		RuntimeConfig.get_color("board_view", "hidden_tile_color", Color(0.19, 0.27, 0.20, 1.0)),
		initialize_hidden_transforms,
		make_visible_after_configure
	)
	_configure_indexed_multimesh_group(
		_unlocked_tiles_multimesh_instance,
		tile_mesh,
		tile_capacity,
		RuntimeConfig.get_color("board_view", "unlocked_tile_color", Color(0.32, 0.48, 0.36, 1.0)),
		initialize_hidden_transforms,
		make_visible_after_configure
	)
	_configure_indexed_multimesh_group(
		_claimed_tiles_multimesh_instance,
		tile_mesh,
		tile_capacity,
		RuntimeConfig.get_color("board_view", "claimed_tile_color", DEFAULT_CLAIMED_TILE_COLOR),
		initialize_hidden_transforms,
		make_visible_after_configure
	)
	_configure_indexed_multimesh_group(
		_cleared_tiles_multimesh_instance,
		tile_mesh,
		tile_capacity,
		RuntimeConfig.get_color("board_view", "revealed_tile_color", Color(0.55, 0.62, 0.52, 1.0)),
		initialize_hidden_transforms,
		make_visible_after_configure
	)

func _resolve_multimesh_tile_capacity() -> int:
	var tile_count: int = int(_current_board_summary.get("tile_count", 0))
	if tile_count > 0:
		return tile_count

	var board_width: int = int(_current_board_summary.get("board_width", 0))
	var board_height: int = int(_current_board_summary.get("board_height", 0))
	if board_width > 0 and board_height > 0:
		return board_width * board_height

	return _tile_snapshot_by_index.size()

func _configure_indexed_multimesh_group(
	target_multimesh_instance: MultiMeshInstance3D,
	tile_mesh: Mesh,
	tile_capacity: int,
	albedo_color: Color,
	initialize_hidden_transforms: bool = true,
	make_visible_after_configure: bool = true
) -> void:
	if target_multimesh_instance == null:
		return

	var tile_multimesh: MultiMesh = MultiMesh.new()
	tile_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	tile_multimesh.mesh = tile_mesh
	tile_multimesh.instance_count = tile_capacity

	if initialize_hidden_transforms:
		for tile_index in range(tile_capacity):
			tile_multimesh.set_instance_transform(tile_index, _hidden_multimesh_tile_transform)

	target_multimesh_instance.multimesh = tile_multimesh
	target_multimesh_instance.material_override = _build_material(albedo_color)
	target_multimesh_instance.visible = make_visible_after_configure

func _is_indexed_multimesh_group_ready(target_multimesh_instance: MultiMeshInstance3D, tile_capacity: int) -> bool:
	if target_multimesh_instance == null:
		return false
	if target_multimesh_instance.multimesh == null:
		return false

	return target_multimesh_instance.multimesh.instance_count == tile_capacity

func _set_all_indexed_multimesh_groups_visible(is_visible: bool) -> void:
	if _locked_tiles_multimesh_instance != null:
		_locked_tiles_multimesh_instance.visible = is_visible

	if _unlocked_tiles_multimesh_instance != null:
		_unlocked_tiles_multimesh_instance.visible = is_visible

	if _claimed_tiles_multimesh_instance != null:
		_claimed_tiles_multimesh_instance.visible = is_visible

	if _cleared_tiles_multimesh_instance != null:
		_cleared_tiles_multimesh_instance.visible = is_visible

func _clear_indexed_multimesh_tile_visuals() -> void:
	for tile_index in range(_indexed_multimesh_tile_capacity):
		_clear_indexed_multimesh_tile(tile_index)

func _clear_indexed_multimesh_tile(tile_index: int) -> void:
	_set_indexed_multimesh_tile_transform(_locked_tiles_multimesh_instance, tile_index, _hidden_multimesh_tile_transform)
	_set_indexed_multimesh_tile_transform(_unlocked_tiles_multimesh_instance, tile_index, _hidden_multimesh_tile_transform)
	_set_indexed_multimesh_tile_transform(_claimed_tiles_multimesh_instance, tile_index, _hidden_multimesh_tile_transform)
	_set_indexed_multimesh_tile_transform(_cleared_tiles_multimesh_instance, tile_index, _hidden_multimesh_tile_transform)

func _set_indexed_multimesh_tile_transform(
	target_multimesh_instance: MultiMeshInstance3D,
	tile_index: int,
	tile_transform: Transform3D
) -> void:
	if target_multimesh_instance == null:
		return
	if target_multimesh_instance.multimesh == null:
		return
	if tile_index < 0:
		return
	if tile_index >= target_multimesh_instance.multimesh.instance_count:
		return

	target_multimesh_instance.multimesh.set_instance_transform(tile_index, tile_transform)

func _get_multimesh_instance_for_group(multimesh_group: String) -> MultiMeshInstance3D:
	if multimesh_group == MULTIMESH_GROUP_LOCKED:
		return _locked_tiles_multimesh_instance
	if multimesh_group == MULTIMESH_GROUP_UNLOCKED:
		return _unlocked_tiles_multimesh_instance
	if multimesh_group == MULTIMESH_GROUP_CLAIMED:
		return _claimed_tiles_multimesh_instance
	if multimesh_group == MULTIMESH_GROUP_CLEARED:
		return _cleared_tiles_multimesh_instance

	return null

func _get_multimesh_group_for_tile_snapshot(tile_snapshot: Dictionary) -> String:
	var is_cleared: bool = bool(tile_snapshot.get("is_cleared", false))
	if is_cleared:
		if _should_render_cleared_tile_cover():
			return MULTIMESH_GROUP_CLEARED
		return ""

	var claim_owner_peer_id: int = int(tile_snapshot.get("claim_owner_peer_id", 0))
	if claim_owner_peer_id > 0:
		return MULTIMESH_GROUP_CLAIMED

	var is_unlocked: bool = bool(tile_snapshot.get("is_unlocked", false))
	if is_unlocked:
		return MULTIMESH_GROUP_UNLOCKED

	return MULTIMESH_GROUP_LOCKED

func _should_render_cleared_tile_cover() -> bool:
	var show_reveal_underlay: bool = RuntimeConfig.get_bool("board_view", "show_reveal_underlay", true)
	if show_reveal_underlay:
		return RuntimeConfig.get_bool("board_view", "show_cleared_tiles_with_underlay", false)
	return RuntimeConfig.get_bool("board_view", "show_cleared_tiles_without_underlay", true)

func _build_tile_cover_transform(tile_snapshot: Dictionary) -> Transform3D:
	var grid_x: int = int(tile_snapshot.get("grid_x", 0))
	var grid_y: int = int(tile_snapshot.get("grid_y", 0))
	var tile_center_world_position: Vector3 = _build_tile_center_world_position(grid_x, grid_y)
	var tile_height: float = _get_multimesh_tile_cover_height()
	return Transform3D(Basis(), tile_center_world_position + Vector3(0.0, tile_height * 0.5, 0.0))

func _build_hidden_multimesh_tile_transform() -> Transform3D:
	var hidden_transform: Transform3D = Transform3D.IDENTITY
	hidden_transform.origin = Vector3.ZERO
	hidden_transform.basis = hidden_transform.basis.scaled(Vector3.ZERO)
	return hidden_transform

func _get_multimesh_tile_cover_height() -> float:
	var tile_size: float = _get_tile_size()
	var height_ratio: float = RuntimeConfig.get_float("board_view", "multimesh_tile_cover_height_ratio", 0.08)
	return max(tile_size * max(height_ratio, 0.001), 0.001)

func _clear_all_tile_multimeshes() -> void:
	_clear_multimesh_instance(_locked_tiles_multimesh_instance)
	_clear_multimesh_instance(_unlocked_tiles_multimesh_instance)
	_clear_multimesh_instance(_cleared_tiles_multimesh_instance)
	_clear_multimesh_instance(_claimed_tiles_multimesh_instance)
	_indexed_multimesh_tile_capacity = 0
	_hidden_multimesh_tile_transform = Transform3D.IDENTITY
	_detail_overlay_tile_indices.clear()

func _ensure_claimed_tiles_multimesh_instance() -> void:
	if _claimed_tiles_multimesh_instance != null and is_instance_valid(_claimed_tiles_multimesh_instance):
		return

	var existing_claimed_tiles_multimesh_instance: MultiMeshInstance3D = get_node_or_null(CLAIMED_TILES_MULTIMESH_NODE_NAME) as MultiMeshInstance3D
	if existing_claimed_tiles_multimesh_instance != null:
		_claimed_tiles_multimesh_instance = existing_claimed_tiles_multimesh_instance
		return

	_claimed_tiles_multimesh_instance = MultiMeshInstance3D.new()
	_claimed_tiles_multimesh_instance.name = CLAIMED_TILES_MULTIMESH_NODE_NAME
	add_child(_claimed_tiles_multimesh_instance)

func _rebuild_tile_visuals(tile_snapshot_list: Array) -> void:
	var tile_indices_to_keep: Dictionary = {}

	for tile_snapshot_variant in tile_snapshot_list:
		var tile_snapshot: Dictionary = tile_snapshot_variant as Dictionary
		if tile_snapshot.is_empty():
			continue

		var tile_index: int = int(tile_snapshot.get("tile_index", -1))
		if tile_index < 0:
			continue

		tile_indices_to_keep[tile_index] = true
		_apply_tile_visual(tile_snapshot)

	var existing_tile_indices: Array = _tile_visual_by_index.keys()
	for tile_index_variant in existing_tile_indices:
		var tile_index: int = int(tile_index_variant)
		if tile_indices_to_keep.has(tile_index):
			continue
		_remove_tile_visual(tile_index)

func _apply_tile_visuals(tile_snapshot_list: Array) -> void:
	for tile_snapshot_variant in tile_snapshot_list:
		var tile_snapshot: Dictionary = tile_snapshot_variant as Dictionary
		if tile_snapshot.is_empty():
			continue
		_apply_tile_visual(tile_snapshot)

func _apply_tile_visual(tile_snapshot: Dictionary) -> void:
	var tile_visual: BoardTileVisual = _ensure_tile_visual_for_tile_snapshot(tile_snapshot)
	if tile_visual == null:
		return

	var tile_center_world_position: Vector3 = _build_tile_center_world_position(
		int(tile_snapshot.get("grid_x", 0)),
		int(tile_snapshot.get("grid_y", 0))
	)
	var tile_size: float = _get_tile_size()

	tile_visual.position = tile_center_world_position + Vector3(0.0, tile_size * 0.5, 0.0)
	tile_visual.scale = Vector3.ONE * tile_size
	tile_visual.apply_tile_snapshot(tile_snapshot)

func _ensure_tile_visual_for_tile_snapshot(tile_snapshot: Dictionary) -> BoardTileVisual:
	_ensure_tile_visual_root()

	var tile_index: int = int(tile_snapshot.get("tile_index", -1))
	if tile_index < 0:
		return null

	var variant_id_text: String = String(tile_snapshot.get("variant_id", ""))
	var existing_tile_visual: BoardTileVisual = _tile_visual_by_index.get(tile_index) as BoardTileVisual
	if existing_tile_visual != null:
		if variant_id_text.is_empty():
			return existing_tile_visual

		var existing_variant_id_text: String = String(existing_tile_visual.get_meta("variant_id", ""))
		if existing_variant_id_text == variant_id_text:
			return existing_tile_visual

		_remove_tile_visual(tile_index)

	if variant_id_text.is_empty():
		return null

	var tile_visual_scene: PackedScene = _resolve_tile_visual_scene(StringName(variant_id_text))
	if tile_visual_scene == null:
		return null

	var tile_visual: BoardTileVisual = tile_visual_scene.instantiate() as BoardTileVisual
	if tile_visual == null:
		return null

	tile_visual.name = "TileVisual_%s" % str(tile_index)
	tile_visual.set_meta("variant_id", variant_id_text)
	_tile_visual_root.add_child(tile_visual)
	_tile_visual_by_index[tile_index] = tile_visual
	return tile_visual

func _resolve_tile_visual_scene(variant_id: StringName) -> PackedScene:
	if _tile_variant_def_by_id.is_empty():
		_tile_variant_def_by_id = BoardTileContentCatalog.build_variant_by_id()

	var tile_variant_def: TileVariantDef = _tile_variant_def_by_id.get(variant_id) as TileVariantDef
	if tile_variant_def == null:
		return null

	return tile_variant_def.visual_scene

func _ensure_tile_visual_root() -> void:
	if _tile_visual_root != null and is_instance_valid(_tile_visual_root):
		return

	var existing_tile_visual_root: Node3D = get_node_or_null(TILE_VISUAL_ROOT_NODE_NAME) as Node3D
	if existing_tile_visual_root != null:
		_tile_visual_root = existing_tile_visual_root
		return

	_tile_visual_root = Node3D.new()
	_tile_visual_root.name = TILE_VISUAL_ROOT_NODE_NAME
	add_child(_tile_visual_root)

func _clear_tile_visuals() -> void:
	_ensure_tile_visual_root()

	for child_node in _tile_visual_root.get_children():
		child_node.free()

	_tile_visual_by_index.clear()

func _remove_tile_visual(tile_index: int) -> void:
	if not _tile_visual_by_index.has(tile_index):
		return

	var tile_visual: BoardTileVisual = _tile_visual_by_index[tile_index] as BoardTileVisual
	if tile_visual != null and is_instance_valid(tile_visual):
		tile_visual.free()

	_tile_visual_by_index.erase(tile_index)

func _mark_detail_tiles_important_from_snapshot_list(tile_snapshot_list: Array[Dictionary]) -> void:
	if _progressive_multimesh_build_active:
		return

	if not _should_use_multimesh_tile_rendering():
		return

	var hold_duration_msec: int = max(
		RuntimeConfig.get_int("board_view", "detail_overlay_changed_tile_hold_ms", 1500),
		0
	)
	if hold_duration_msec <= 0:
		return

	var expire_time_msec: int = Time.get_ticks_msec() + hold_duration_msec

	for tile_snapshot in tile_snapshot_list:
		if tile_snapshot.is_empty():
			continue

		var tile_index: int = int(tile_snapshot.get("tile_index", -1))
		if not _is_tile_index_inside_board(tile_index):
			continue

		_important_detail_tile_expire_time_by_index[tile_index] = expire_time_msec

func _refresh_large_board_detail_overlay() -> void:
	if _progressive_multimesh_build_active:
		return

	if not _should_use_multimesh_tile_rendering():
		return

	if not RuntimeConfig.get_bool("board_view", "large_board_detail_overlay_enabled", true):
		_sync_detail_overlay_multimesh_masks({})
		_clear_tile_visuals()
		return

	var detail_tile_snapshot_list: Array[Dictionary] = _build_large_board_detail_tile_snapshot_list()
	var next_detail_overlay_tile_indices: Dictionary = _build_detail_overlay_tile_index_set(detail_tile_snapshot_list)

	_sync_detail_overlay_multimesh_masks(next_detail_overlay_tile_indices)
	_rebuild_tile_visuals(detail_tile_snapshot_list)

func _build_detail_overlay_tile_index_set(tile_snapshot_list: Array[Dictionary]) -> Dictionary:
	var detail_overlay_tile_indices: Dictionary = {}

	for tile_snapshot in tile_snapshot_list:
		if tile_snapshot.is_empty():
			continue

		var tile_index: int = int(tile_snapshot.get("tile_index", -1))
		if not _is_tile_index_inside_board(tile_index):
			continue

		detail_overlay_tile_indices[tile_index] = true

	return detail_overlay_tile_indices


func _sync_detail_overlay_multimesh_masks(next_detail_overlay_tile_indices: Dictionary) -> void:
	if not _should_use_multimesh_tile_rendering():
		_detail_overlay_tile_indices.clear()
		return

	var previous_detail_tile_indices: Array = _detail_overlay_tile_indices.keys()
	_detail_overlay_tile_indices = next_detail_overlay_tile_indices.duplicate()

	for previous_tile_index_variant in previous_detail_tile_indices:
		var previous_tile_index: int = int(previous_tile_index_variant)
		if _detail_overlay_tile_indices.has(previous_tile_index):
			continue
		if not _tile_snapshot_by_index.has(previous_tile_index):
			continue

		var previous_tile_snapshot: Dictionary = _tile_snapshot_by_index[previous_tile_index]
		_apply_multimesh_tile_visual(previous_tile_snapshot)

	for current_tile_index_variant in _detail_overlay_tile_indices.keys():
		var current_tile_index: int = int(current_tile_index_variant)
		_clear_indexed_multimesh_tile(current_tile_index)

func _build_large_board_detail_tile_snapshot_list() -> Array[Dictionary]:
	var max_detail_tiles: int = max(RuntimeConfig.get_int("board_view", "detail_overlay_max_tiles", 96), 0)
	if max_detail_tiles <= 0:
		return []

	var candidate_by_index: Dictionary = {}

	_prune_expired_important_detail_tiles()

	for important_tile_index_variant in _important_detail_tile_expire_time_by_index.keys():
		var important_tile_index: int = int(important_tile_index_variant)
		_add_detail_candidate(
			candidate_by_index,
			important_tile_index,
			DETAIL_CANDIDATE_PRIORITY_IMPORTANT,
			0
		)

	if _is_tile_index_inside_board(_detail_hovered_tile_index):
		_add_detail_candidate(
			candidate_by_index,
			_detail_hovered_tile_index,
			DETAIL_CANDIDATE_PRIORITY_HOVERED,
			0
		)

	if _is_tile_index_inside_board(_detail_focus_tile_index):
		_add_detail_candidate(
			candidate_by_index,
			_detail_focus_tile_index,
			DETAIL_CANDIDATE_PRIORITY_FOCUS,
			0
		)
		_add_nearby_detail_candidates(candidate_by_index, _detail_focus_tile_index)

	var detail_candidate_list: Array = candidate_by_index.values()
	detail_candidate_list.sort_custom(_sort_detail_candidate_entries)

	var detail_tile_snapshot_list: Array[Dictionary] = []
	for detail_candidate_variant in detail_candidate_list:
		if detail_tile_snapshot_list.size() >= max_detail_tiles:
			break

		var detail_candidate: Dictionary = detail_candidate_variant as Dictionary
		var tile_index: int = int(detail_candidate.get("tile_index", -1))
		if not _tile_snapshot_by_index.has(tile_index):
			continue

		var tile_snapshot: Dictionary = _tile_snapshot_by_index[tile_index]
		if _should_skip_large_board_detail_tile_snapshot(tile_snapshot):
			continue

		detail_tile_snapshot_list.append(tile_snapshot)

	return detail_tile_snapshot_list


func _add_nearby_detail_candidates(candidate_by_index: Dictionary, center_tile_index: int) -> void:
	var board_width: int = int(_current_board_summary.get("board_width", 0))
	var board_height: int = int(_current_board_summary.get("board_height", 0))
	if board_width <= 0 or board_height <= 0:
		return

	var detail_radius_tiles: int = max(RuntimeConfig.get_int("board_view", "detail_overlay_radius_tiles", 4), 0)
	if detail_radius_tiles <= 0:
		return

	var center_grid_x: int = center_tile_index % board_width
	var center_grid_y: int = int(floor(float(center_tile_index) / float(board_width)))

	var min_grid_x: int = max(center_grid_x - detail_radius_tiles, 0)
	var max_grid_x: int = min(center_grid_x + detail_radius_tiles, board_width - 1)
	var min_grid_y: int = max(center_grid_y - detail_radius_tiles, 0)
	var max_grid_y: int = min(center_grid_y + detail_radius_tiles, board_height - 1)

	var radius_squared: int = detail_radius_tiles * detail_radius_tiles

	for grid_y in range(min_grid_y, max_grid_y + 1):
		for grid_x in range(min_grid_x, max_grid_x + 1):
			var offset_x: int = grid_x - center_grid_x
			var offset_y: int = grid_y - center_grid_y
			var distance_squared: int = (offset_x * offset_x) + (offset_y * offset_y)
			if distance_squared > radius_squared:
				continue

			var tile_index: int = (grid_y * board_width) + grid_x
			_add_detail_candidate(
				candidate_by_index,
				tile_index,
				DETAIL_CANDIDATE_PRIORITY_NEARBY,
				distance_squared
			)


func _add_detail_candidate(
	candidate_by_index: Dictionary,
	tile_index: int,
	priority: int,
	distance_squared: int
) -> void:
	if not _is_tile_index_inside_board(tile_index):
		return
	if not _tile_snapshot_by_index.has(tile_index):
		return

	var tile_snapshot: Dictionary = _tile_snapshot_by_index[tile_index]
	if _should_skip_large_board_detail_tile_snapshot(tile_snapshot):
		return

	if candidate_by_index.has(tile_index):
		var existing_candidate: Dictionary = candidate_by_index[tile_index]
		var existing_priority: int = int(existing_candidate.get("priority", priority))
		var existing_distance_squared: int = int(existing_candidate.get("distance_squared", distance_squared))

		var should_replace: bool = priority < existing_priority
		if priority == existing_priority and distance_squared < existing_distance_squared:
			should_replace = true

		if not should_replace:
			return

	candidate_by_index[tile_index] = {
		"tile_index": tile_index,
		"priority": priority,
		"distance_squared": distance_squared
	}


func _sort_detail_candidate_entries(left_variant: Variant, right_variant: Variant) -> bool:
	var left_entry: Dictionary = left_variant as Dictionary
	var right_entry: Dictionary = right_variant as Dictionary

	var left_priority: int = int(left_entry.get("priority", 0))
	var right_priority: int = int(right_entry.get("priority", 0))
	if left_priority != right_priority:
		return left_priority < right_priority

	var left_distance_squared: int = int(left_entry.get("distance_squared", 0))
	var right_distance_squared: int = int(right_entry.get("distance_squared", 0))
	if left_distance_squared != right_distance_squared:
		return left_distance_squared < right_distance_squared

	var left_tile_index: int = int(left_entry.get("tile_index", 0))
	var right_tile_index: int = int(right_entry.get("tile_index", 0))
	return left_tile_index < right_tile_index


func _should_skip_large_board_detail_tile_snapshot(tile_snapshot: Dictionary) -> bool:
	if tile_snapshot.is_empty():
		return true

	var is_cleared: bool = bool(tile_snapshot.get("is_cleared", false))
	if is_cleared:
		return true

	var variant_id_text: String = String(tile_snapshot.get("variant_id", ""))
	return variant_id_text.is_empty()


func _prune_expired_important_detail_tiles() -> void:
	if _important_detail_tile_expire_time_by_index.is_empty():
		return

	var current_ticks_msec: int = Time.get_ticks_msec()
	var expired_tile_indices: Array[int] = []

	for tile_index_variant in _important_detail_tile_expire_time_by_index.keys():
		var tile_index: int = int(tile_index_variant)
		var expire_time_msec: int = int(_important_detail_tile_expire_time_by_index[tile_index])
		if current_ticks_msec >= expire_time_msec:
			expired_tile_indices.append(tile_index)

	for tile_index in expired_tile_indices:
		_important_detail_tile_expire_time_by_index.erase(tile_index)


func _is_tile_index_inside_board(tile_index: int) -> bool:
	if tile_index < 0:
		return false

	var board_width: int = int(_current_board_summary.get("board_width", 0))
	var board_height: int = int(_current_board_summary.get("board_height", 0))
	if board_width <= 0 or board_height <= 0:
		return false

	var tile_count: int = board_width * board_height
	return tile_index < tile_count


func _get_detail_overlay_refresh_interval_msec() -> int:
	return max(RuntimeConfig.get_int("board_view", "detail_overlay_refresh_interval_ms", 150), 16)

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
	var line_color: Color = RuntimeConfig.get_color(
		"board_view",
		"chunk_line_color",
		DEFAULT_CHUNK_LINE_COLOR
	)
	var line_material: StandardMaterial3D = _build_material(line_color)

	var world_left_edge: float = -(_current_board_world_size.x * 0.5)
	var world_top_edge: float = -(_current_board_world_size.y * 0.5)
	var tile_stride: float = _get_tile_stride()
	var line_center_y: float = _get_tile_size() + line_surface_lift + (line_height * 0.5)

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
	if target_multimesh_instance == null:
		return
	target_multimesh_instance.multimesh = null
	target_multimesh_instance.material_override = null
	target_multimesh_instance.visible = false

func _clear_chunk_lines() -> void:
	for child_node in _chunk_line_container.get_children():
		child_node.free()

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
