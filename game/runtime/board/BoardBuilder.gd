extends RefCounted
class_name BoardBuilder

static func build_board_state_from_map_preset(map_preset_def: MapPresetDef) -> BoardState:
	if map_preset_def == null:
		return null

	var board_state: BoardState = BoardState.new()
	board_state.configure_dimensions(
		map_preset_def.board_width,
		map_preset_def.board_height,
		map_preset_def.chunk_width,
		map_preset_def.chunk_height
	)

	if map_preset_def.reveal_image != null and not map_preset_def.reveal_image.resource_path.is_empty():
		board_state.reveal_image_id = StringName(map_preset_def.reveal_image.resource_path)

	var default_tile_hp: int = max(RuntimeConfig.get_int("board_actions", "default_tile_hp", 5), 1)
	var tile_count: int = board_state.get_total_tile_count()

	for tile_index in range(tile_count):
		var tile_coords: Vector2i = board_state.get_coords_from_tile_index(tile_index)
		var tile_record: TileRecord = TileRecord.new()
		tile_record.tile_index = tile_index
		tile_record.tile_id = tile_index
		tile_record.grid_x = tile_coords.x
		tile_record.grid_y = tile_coords.y
		tile_record.chunk_index = board_state.get_chunk_index_for_grid(tile_record.grid_x, tile_record.grid_y)
		tile_record.max_hp = default_tile_hp
		tile_record.current_hp = default_tile_hp
		tile_record.uv_rect = _build_full_board_uv_rect(board_state, tile_record.grid_x, tile_record.grid_y)
		board_state.set_tile(tile_record)

		var chunk_coords: Vector2i = board_state.get_chunk_coords_from_grid(tile_record.grid_x, tile_record.grid_y)
		var chunk_state: ChunkState = board_state.ensure_chunk_state(chunk_coords.x, chunk_coords.y)
		if chunk_state != null:
			chunk_state.add_tile_index(tile_index)

	board_state.remaining_uncleared_tiles = tile_count
	_apply_start_unlock_seeds(board_state, map_preset_def.start_unlock_seed_count)
	return board_state

static func _build_full_board_uv_rect(board_state: BoardState, grid_x: int, grid_y: int) -> Rect2:
	var uv_size: Vector2 = Vector2(1.0 / float(board_state.board_width), 1.0 / float(board_state.board_height))
	var uv_position: Vector2 = Vector2(uv_size.x * float(grid_x), uv_size.y * float(grid_y))
	return Rect2(uv_position, uv_size)

static func _apply_start_unlock_seeds(board_state: BoardState, start_unlock_seed_count: int) -> void:
	var resolved_seed_count: int = clampi(start_unlock_seed_count, 0, board_state.get_total_tile_count())
	if resolved_seed_count <= 0:
		return

	var seed_tile_indices: PackedInt32Array = _build_seed_tile_indices(board_state, resolved_seed_count)
	for seed_tile_index in seed_tile_indices:
		var tile_record: TileRecord = board_state.get_tile_by_index(seed_tile_index)
		if tile_record == null:
			continue
		tile_record.is_unlocked = true
		board_state.mark_tile_dirty(seed_tile_index)

static func _build_seed_tile_indices(board_state: BoardState, desired_seed_count: int) -> PackedInt32Array:
	var seed_tile_indices: PackedInt32Array = PackedInt32Array()
	var center_x: int = board_state.board_width / 2
	var center_y: int = board_state.board_height / 2
	var ring_radius: int = 0

	while seed_tile_indices.size() < desired_seed_count:
		var ring_positions: Array[Vector2i] = _build_ring_positions(center_x, center_y, ring_radius)
		for ring_position in ring_positions:
			var tile_index: int = board_state.get_tile_index(ring_position.x, ring_position.y)
			if tile_index == -1:
				continue
			if seed_tile_indices.has(tile_index):
				continue
			seed_tile_indices.append(tile_index)
			if seed_tile_indices.size() >= desired_seed_count:
				break
		ring_radius += 1

	return seed_tile_indices

static func _build_ring_positions(center_x: int, center_y: int, ring_radius: int) -> Array[Vector2i]:
	if ring_radius <= 0:
		return [Vector2i(center_x, center_y)]

	return [
		Vector2i(center_x, center_y - ring_radius),
		Vector2i(center_x + ring_radius, center_y),
		Vector2i(center_x, center_y + ring_radius),
		Vector2i(center_x - ring_radius, center_y)
	]
