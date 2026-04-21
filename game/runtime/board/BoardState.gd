extends RefCounted
class_name BoardState

var board_width: int = 0
var board_height: int = 0
var chunk_width: int = 0
var chunk_height: int = 0
var tiles: Array[TileRecord] = []
var remaining_uncleared_tiles: int = 0
var chunk_states: Dictionary = {}
var reveal_image_id: StringName = &""
var final_rush_active: bool = false
var milestone_progress: Dictionary = {}

var _chunk_columns: int = 0
var _chunk_rows: int = 0

func configure_dimensions(next_board_width: int, next_board_height: int, next_chunk_width: int, next_chunk_height: int) -> void:
	board_width = max(next_board_width, 1)
	board_height = max(next_board_height, 1)
	chunk_width = max(next_chunk_width, 1)
	chunk_height = max(next_chunk_height, 1)
	_chunk_columns = int(ceili(float(board_width) / float(chunk_width)))
	_chunk_rows = int(ceili(float(board_height) / float(chunk_height)))
	tiles.resize(board_width * board_height)
	chunk_states.clear()

func get_total_tile_count() -> int:
	return board_width * board_height

func is_in_bounds(grid_x: int, grid_y: int) -> bool:
	return grid_x >= 0 and grid_x < board_width and grid_y >= 0 and grid_y < board_height

func get_tile_index(grid_x: int, grid_y: int) -> int:
	if not is_in_bounds(grid_x, grid_y):
		return -1
	return (grid_y * board_width) + grid_x

func get_coords_from_tile_index(tile_index: int) -> Vector2i:
	if tile_index < 0 or tile_index >= tiles.size():
		return Vector2i(-1, -1)
	var grid_y: int = tile_index / board_width
	var grid_x: int = tile_index - (grid_y * board_width)
	return Vector2i(grid_x, grid_y)

func get_tile_by_index(tile_index: int) -> TileRecord:
	if tile_index < 0 or tile_index >= tiles.size():
		return null
	return tiles[tile_index]

func get_tile_by_coords(grid_x: int, grid_y: int) -> TileRecord:
	var tile_index: int = get_tile_index(grid_x, grid_y)
	if tile_index == -1:
		return null
	return get_tile_by_index(tile_index)

func set_tile(tile_record: TileRecord) -> void:
	if tile_record == null:
		return
	if tile_record.tile_index < 0 or tile_record.tile_index >= tiles.size():
		return
	tiles[tile_record.tile_index] = tile_record

func get_chunk_columns() -> int:
	return _chunk_columns

func get_chunk_rows() -> int:
	return _chunk_rows

func get_total_chunk_count() -> int:
	return _chunk_columns * _chunk_rows

func count_unlocked_tiles() -> int:
	var unlocked_tile_count: int = 0
	for tile_record in tiles:
		if tile_record == null:
			continue
		if tile_record.is_unlocked:
			unlocked_tile_count += 1
	return unlocked_tile_count

func get_chunk_index_from_coords(chunk_x: int, chunk_y: int) -> int:
	if chunk_x < 0 or chunk_x >= _chunk_columns or chunk_y < 0 or chunk_y >= _chunk_rows:
		return -1
	return (chunk_y * _chunk_columns) + chunk_x

func get_chunk_coords_from_grid(grid_x: int, grid_y: int) -> Vector2i:
	if not is_in_bounds(grid_x, grid_y):
		return Vector2i(-1, -1)
	return Vector2i(grid_x / chunk_width, grid_y / chunk_height)

func get_chunk_index_for_grid(grid_x: int, grid_y: int) -> int:
	var chunk_coords: Vector2i = get_chunk_coords_from_grid(grid_x, grid_y)
	if chunk_coords.x < 0:
		return -1
	return get_chunk_index_from_coords(chunk_coords.x, chunk_coords.y)

func get_chunk_state(chunk_index: int) -> ChunkState:
	if not chunk_states.has(chunk_index):
		return null
	return chunk_states[chunk_index] as ChunkState

func ensure_chunk_state(chunk_x: int, chunk_y: int) -> ChunkState:
	var chunk_index: int = get_chunk_index_from_coords(chunk_x, chunk_y)
	if chunk_index == -1:
		return null
	if chunk_states.has(chunk_index):
		return chunk_states[chunk_index] as ChunkState

	var chunk_state: ChunkState = ChunkState.new()
	chunk_state.chunk_index = chunk_index
	chunk_state.chunk_x = chunk_x
	chunk_state.chunk_y = chunk_y
	chunk_states[chunk_index] = chunk_state
	return chunk_state

func mark_tile_dirty(tile_index: int) -> void:
	var tile_record: TileRecord = get_tile_by_index(tile_index)
	if tile_record == null:
		return
	var chunk_state: ChunkState = get_chunk_state(tile_record.chunk_index)
	if chunk_state == null:
		return
	chunk_state.mark_tile_dirty(tile_index)

func clear_all_chunk_dirty_sets() -> void:
	for chunk_state_variant in chunk_states.values():
		var chunk_state: ChunkState = chunk_state_variant as ChunkState
		if chunk_state == null:
			continue
		chunk_state.clear_dirty_tile_indices()

func get_neighbor_tile_indices(tile_index: int) -> PackedInt32Array:
	var tile_record: TileRecord = get_tile_by_index(tile_index)
	if tile_record == null:
		return PackedInt32Array()

	var neighbor_tile_indices: PackedInt32Array = PackedInt32Array()
	var cardinal_offsets: Array[Vector2i] = [
		Vector2i(0, -1),
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(-1, 0)
	]

	for cardinal_offset in cardinal_offsets:
		var neighbor_grid_x: int = tile_record.grid_x + cardinal_offset.x
		var neighbor_grid_y: int = tile_record.grid_y + cardinal_offset.y
		var neighbor_tile_index: int = get_tile_index(neighbor_grid_x, neighbor_grid_y)
		if neighbor_tile_index == -1:
			continue
		neighbor_tile_indices.append(neighbor_tile_index)

	return neighbor_tile_indices

func build_tile_snapshot_list() -> Array:
	var tile_snapshot_list: Array = []
	for tile_record in tiles:
		if tile_record == null:
			continue
		tile_snapshot_list.append(tile_record.to_snapshot_dto())
	return tile_snapshot_list

func to_snapshot_dto() -> Dictionary:
	return {
		"summary": to_summary_dto(),
		"tiles": build_tile_snapshot_list()
	}

func to_summary_dto() -> Dictionary:
	return {
		"board_width": board_width,
		"board_height": board_height,
		"chunk_width": chunk_width,
		"chunk_height": chunk_height,
		"chunk_columns": _chunk_columns,
		"chunk_rows": _chunk_rows,
		"chunk_count": get_total_chunk_count(),
		"tile_count": tiles.size(),
		"unlocked_tile_count": count_unlocked_tiles(),
		"remaining_uncleared_tiles": remaining_uncleared_tiles,
		"final_rush_active": final_rush_active,
		"reveal_image_id": String(reveal_image_id)
	}
