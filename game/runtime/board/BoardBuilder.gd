extends RefCounted
class_name BoardBuilder

static func build_board_state_from_map_preset(map_preset_def: MapPresetDef) -> BoardState:
	var board_state: BoardState = BoardState.new()
	board_state.configure_dimensions(
		map_preset_def.board_width,
		map_preset_def.board_height,
		map_preset_def.chunk_width,
		map_preset_def.chunk_height
	)

	board_state.remaining_uncleared_tiles = board_state.get_total_tile_count()

	if map_preset_def.reveal_image != null:
		board_state.reveal_image_id = StringName(map_preset_def.reveal_image.resource_path)
	else:
		board_state.reveal_image_id = &""

	var tile_count: int = board_state.get_total_tile_count()
	var default_tile_hp: int = max(RuntimeConfig.get_int("board_actions", "default_tile_hp", 1), 1)

	for tile_index in range(tile_count):
		var tile_coords: Vector2i = board_state.get_coords_from_tile_index(tile_index)

		var tile_record: TileRecord = TileRecord.new()
		tile_record.tile_index = tile_index
		tile_record.tile_id = tile_index
		tile_record.grid_x = tile_coords.x
		tile_record.grid_y = tile_coords.y
		_register_tile_with_chunk(board_state, tile_record)
		tile_record.max_hp = default_tile_hp
		tile_record.current_hp = default_tile_hp
		tile_record.uv_rect = _build_full_board_uv_rect(board_state, tile_record.grid_x, tile_record.grid_y)

		board_state.set_tile(tile_record)

	_assign_procedural_tile_content(board_state, map_preset_def)
	_apply_start_unlock_outer_edge_tiles(
		board_state,
		map_preset_def.start_unlock_outer_edge_ratio,
		map_preset_def.start_unlock_outer_edge_depth,
		map_preset_def.start_unlock_outer_edge_randomness
	)

	return board_state

static func _register_tile_with_chunk(board_state: BoardState, tile_record: TileRecord) -> void:
	if board_state == null:
		return
	if tile_record == null:
		return

	var chunk_coords: Vector2i = board_state.get_chunk_coords_from_grid(tile_record.grid_x, tile_record.grid_y)
	if chunk_coords.x < 0 or chunk_coords.y < 0:
		tile_record.chunk_index = -1
		return

	var chunk_state: ChunkState = board_state.ensure_chunk_state(chunk_coords.x, chunk_coords.y)
	if chunk_state == null:
		tile_record.chunk_index = -1
		return

	tile_record.chunk_index = chunk_state.chunk_index
	chunk_state.add_tile_index(tile_record.tile_index)

static func _build_full_board_uv_rect(board_state: BoardState, grid_x: int, grid_y: int) -> Rect2:
	if board_state.board_width <= 0 or board_state.board_height <= 0:
		return Rect2(0.0, 0.0, 1.0, 1.0)

	var uv_width: float = 1.0 / float(board_state.board_width)
	var uv_height: float = 1.0 / float(board_state.board_height)
	var uv_x: float = float(grid_x) * uv_width
	var uv_y: float = float(grid_y) * uv_height
	return Rect2(uv_x, uv_y, uv_width, uv_height)

static func _assign_procedural_tile_content(board_state: BoardState, map_preset_def: MapPresetDef) -> void:
	var family_list: Array[TileFamilyDef] = BoardTileContentCatalog.build_family_list()
	if family_list.is_empty():
		return

	var variant_list_by_family_id: Dictionary = BoardTileContentCatalog.build_variant_list_by_family_id()
	var variant_by_id: Dictionary = BoardTileContentCatalog.build_variant_by_id()
	var chunk_seed_by_chunk_index: Dictionary = _build_chunk_seed_by_chunk_index(board_state, family_list)
	if chunk_seed_by_chunk_index.is_empty():
		return

	var family_region_noise_bundle: Dictionary = _build_family_region_noise_bundle(board_state, map_preset_def)
	var seed_search_radius_chunks: int = max(map_preset_def.family_region_seed_search_radius_chunks, 0)

	for tile_record in board_state.tiles:
		if tile_record == null:
			continue

		var selected_family_id: StringName = _select_family_id_for_tile(
			tile_record,
			board_state,
			chunk_seed_by_chunk_index,
			seed_search_radius_chunks,
			family_region_noise_bundle
		)
		var selected_variant_id: StringName = _select_variant_id_for_tile(tile_record, selected_family_id, variant_list_by_family_id)

		tile_record.family_id = selected_family_id
		tile_record.variant_id = selected_variant_id
		tile_record.behavior_id = _resolve_behavior_id_for_variant(selected_variant_id, variant_by_id)

static func _resolve_behavior_id_for_variant(variant_id: StringName, variant_by_id: Dictionary) -> StringName:
	if String(variant_id).is_empty():
		return &""

	if not variant_by_id.has(variant_id):
		return &""

	var tile_variant_def: TileVariantDef = variant_by_id[variant_id] as TileVariantDef
	if tile_variant_def == null:
		return &""

	return tile_variant_def.behavior_id

static func _build_chunk_seed_by_chunk_index(board_state: BoardState, family_list: Array[TileFamilyDef]) -> Dictionary:
	var chunk_seed_by_chunk_index: Dictionary = {}
	if board_state == null:
		return chunk_seed_by_chunk_index
	if family_list.is_empty():
		return chunk_seed_by_chunk_index

	for chunk_y in range(board_state.get_chunk_rows()):
		for chunk_x in range(board_state.get_chunk_columns()):
			var chunk_seed_key: String = "%s:%s:%s:%s:%s:%s" % [
				str(board_state.board_width),
				str(board_state.board_height),
				str(board_state.chunk_width),
				str(board_state.chunk_height),
				str(chunk_x),
				str(chunk_y)
			]

			var selected_family_id: StringName = _select_weighted_content_id_from_hash(
				family_list,
				_build_deterministic_hash("%s:family" % chunk_seed_key)
			)

			var chunk_min_grid_x: int = chunk_x * board_state.chunk_width
			var chunk_min_grid_y: int = chunk_y * board_state.chunk_height
			var chunk_max_grid_x: int = min(chunk_min_grid_x + board_state.chunk_width - 1, board_state.board_width - 1)
			var chunk_max_grid_y: int = min(chunk_min_grid_y + board_state.chunk_height - 1, board_state.board_height - 1)

			var chunk_span_x: int = max(chunk_max_grid_x - chunk_min_grid_x + 1, 1)
			var chunk_span_y: int = max(chunk_max_grid_y - chunk_min_grid_y + 1, 1)

			var seed_grid_x: int = chunk_min_grid_x + _positive_mod(
				_build_deterministic_hash("%s:x" % chunk_seed_key),
				chunk_span_x
			)
			var seed_grid_y: int = chunk_min_grid_y + _positive_mod(
				_build_deterministic_hash("%s:y" % chunk_seed_key),
				chunk_span_y
			)

			var chunk_index: int = board_state.get_chunk_index_from_coords(chunk_x, chunk_y)
			if chunk_index == -1:
				continue

			chunk_seed_by_chunk_index[chunk_index] = {
				"family_id": selected_family_id,
				"grid_position": Vector2(seed_grid_x, seed_grid_y),
				"chunk_x": chunk_x,
				"chunk_y": chunk_y
			}

	return chunk_seed_by_chunk_index

static func _build_family_region_noise_bundle(board_state: BoardState, map_preset_def: MapPresetDef) -> Dictionary:
	var family_region_noise_bundle: Dictionary = {}
	if board_state == null:
		return family_region_noise_bundle
	if map_preset_def == null:
		return family_region_noise_bundle
	if map_preset_def.family_region_warp_frequency <= 0.0:
		return family_region_noise_bundle
	if map_preset_def.family_region_warp_strength <= 0.0:
		return family_region_noise_bundle

	var base_noise_key: String = "%s:%s:%s:%s:%s" % [
		String(map_preset_def.id),
		str(board_state.board_width),
		str(board_state.board_height),
		str(board_state.chunk_width),
		str(board_state.chunk_height)
	]

	var warp_x_noise: FastNoiseLite = FastNoiseLite.new()
	warp_x_noise.seed = _build_deterministic_hash("%s:family_region_warp_x" % base_noise_key)
	warp_x_noise.frequency = map_preset_def.family_region_warp_frequency

	var warp_y_noise: FastNoiseLite = FastNoiseLite.new()
	warp_y_noise.seed = _build_deterministic_hash("%s:family_region_warp_y" % base_noise_key)
	warp_y_noise.frequency = map_preset_def.family_region_warp_frequency

	family_region_noise_bundle["warp_x_noise"] = warp_x_noise
	family_region_noise_bundle["warp_y_noise"] = warp_y_noise
	family_region_noise_bundle["warp_strength"] = map_preset_def.family_region_warp_strength
	return family_region_noise_bundle

static func _select_family_id_for_tile(
	tile_record: TileRecord,
	board_state: BoardState,
	chunk_seed_by_chunk_index: Dictionary,
	seed_search_radius_chunks: int,
	family_region_noise_bundle: Dictionary
) -> StringName:
	var closest_distance_squared: float = INF
	var closest_family_id: StringName = &""
	var tile_sample_position: Vector2 = _build_family_region_sample_position(tile_record, family_region_noise_bundle)
	var tile_chunk_coords: Vector2i = board_state.get_chunk_coords_from_grid(tile_record.grid_x, tile_record.grid_y)

	var min_chunk_x: int = max(tile_chunk_coords.x - seed_search_radius_chunks, 0)
	var max_chunk_x: int = min(tile_chunk_coords.x + seed_search_radius_chunks, board_state.get_chunk_columns() - 1)
	var min_chunk_y: int = max(tile_chunk_coords.y - seed_search_radius_chunks, 0)
	var max_chunk_y: int = min(tile_chunk_coords.y + seed_search_radius_chunks, board_state.get_chunk_rows() - 1)

	for chunk_y in range(min_chunk_y, max_chunk_y + 1):
		for chunk_x in range(min_chunk_x, max_chunk_x + 1):
			var chunk_index: int = board_state.get_chunk_index_from_coords(chunk_x, chunk_y)
			if chunk_index == -1:
				continue
			if not chunk_seed_by_chunk_index.has(chunk_index):
				continue

			var chunk_seed: Dictionary = chunk_seed_by_chunk_index[chunk_index] as Dictionary
			var seed_position: Vector2 = chunk_seed.get("grid_position", Vector2.ZERO)
			var family_id: StringName = chunk_seed.get("family_id", &"")

			var delta_x: float = tile_sample_position.x - seed_position.x
			var delta_y: float = tile_sample_position.y - seed_position.y
			var distance_squared: float = (delta_x * delta_x) + (delta_y * delta_y)

			if distance_squared < closest_distance_squared:
				closest_distance_squared = distance_squared
				closest_family_id = family_id

	return closest_family_id

static func _build_family_region_sample_position(tile_record: TileRecord, family_region_noise_bundle: Dictionary) -> Vector2:
	var tile_sample_position: Vector2 = Vector2(float(tile_record.grid_x), float(tile_record.grid_y))
	if family_region_noise_bundle.is_empty():
		return tile_sample_position

	var warp_x_noise: FastNoiseLite = family_region_noise_bundle.get("warp_x_noise", null) as FastNoiseLite
	var warp_y_noise: FastNoiseLite = family_region_noise_bundle.get("warp_y_noise", null) as FastNoiseLite
	var warp_strength: float = float(family_region_noise_bundle.get("warp_strength", 0.0))
	if warp_x_noise == null or warp_y_noise == null:
		return tile_sample_position
	if warp_strength <= 0.0:
		return tile_sample_position

	var warp_offset_x: float = warp_x_noise.get_noise_2d(tile_sample_position.x, tile_sample_position.y) * warp_strength
	var warp_offset_y: float = warp_y_noise.get_noise_2d(tile_sample_position.x, tile_sample_position.y) * warp_strength
	return tile_sample_position + Vector2(warp_offset_x, warp_offset_y)

static func _select_variant_id_for_tile(
	tile_record: TileRecord,
	family_id: StringName,
	variant_list_by_family_id: Dictionary
) -> StringName:
	if String(family_id).is_empty():
		return &""

	if not variant_list_by_family_id.has(family_id):
		return &""

	var family_variant_list: Array = variant_list_by_family_id[family_id] as Array
	if family_variant_list.is_empty():
		return &""

	var variant_hash_key: String = "%s:%s:%s" % [
		String(family_id),
		str(tile_record.grid_x),
		str(tile_record.grid_y)
	]

	return _select_weighted_content_id_from_hash(
		family_variant_list,
		_build_deterministic_hash(variant_hash_key)
	)

static func _select_weighted_content_id_from_hash(content_def_list: Array, hash_value: int) -> StringName:
	if content_def_list.is_empty():
		return &""

	var total_weight: float = 0.0
	for content_def_variant in content_def_list:
		var assignment_weight: float = float(content_def_variant.assignment_weight)
		if assignment_weight <= 0.0:
			continue
		total_weight += assignment_weight

	if total_weight <= 0.0:
		return &""

	var normalized_hash: int = _positive_mod(hash_value, 1000000)
	var pick_ratio: float = float(normalized_hash) / 1000000.0
	var target_weight: float = pick_ratio * total_weight

	var traversed_weight: float = 0.0
	for content_def_variant in content_def_list:
		var assignment_weight: float = float(content_def_variant.assignment_weight)
		if assignment_weight <= 0.0:
			continue

		traversed_weight += assignment_weight
		if target_weight <= traversed_weight:
			return content_def_variant.id

	return content_def_list[content_def_list.size() - 1].id

static func _build_deterministic_hash(source_text: String) -> int:
	var hash_value: int = 5381
	var utf8_buffer: PackedByteArray = source_text.to_utf8_buffer()

	for utf8_byte in utf8_buffer:
		hash_value = ((hash_value << 5) + hash_value) + int(utf8_byte)

	return hash_value

static func _positive_mod(value: int, divisor: int) -> int:
	if divisor <= 0:
		return 0

	var remainder: int = value % divisor
	if remainder < 0:
		remainder += divisor

	return remainder

static func _apply_start_unlock_outer_edge_tiles(
	board_state: BoardState,
	start_unlock_outer_edge_ratio: float,
	start_unlock_outer_edge_depth: int,
	start_unlock_outer_edge_randomness: float
) -> void:
	if board_state == null:
		return
	if start_unlock_outer_edge_ratio <= 0.0:
		return
	if start_unlock_outer_edge_depth <= 0:
		return

	var seed_tile_indices: PackedInt32Array = _build_start_unlock_outer_edge_tile_indices(
		board_state,
		start_unlock_outer_edge_ratio,
		start_unlock_outer_edge_depth,
		start_unlock_outer_edge_randomness
	)

	for seed_tile_index in seed_tile_indices:
		var tile_record: TileRecord = board_state.get_tile_by_index(seed_tile_index)
		if tile_record == null:
			continue

		tile_record.is_unlocked = true
		tile_record.last_damage_at_ms = 0
		board_state.mark_tile_dirty(seed_tile_index)

static func _build_start_unlock_outer_edge_tile_indices(
	board_state: BoardState,
	start_unlock_outer_edge_ratio: float,
	start_unlock_outer_edge_depth: int,
	start_unlock_outer_edge_randomness: float
) -> PackedInt32Array:
	var chosen_tile_indices: PackedInt32Array = PackedInt32Array()
	var candidate_tile_indices: PackedInt32Array = _build_outer_edge_tile_indices(board_state, start_unlock_outer_edge_depth)
	if candidate_tile_indices.is_empty():
		return chosen_tile_indices

	var desired_seed_count: int = int(ceil(float(candidate_tile_indices.size()) * start_unlock_outer_edge_ratio))
	desired_seed_count = clampi(desired_seed_count, 0, candidate_tile_indices.size())
	if desired_seed_count <= 0:
		return chosen_tile_indices

	var clamped_randomness: float = clampf(start_unlock_outer_edge_randomness, 0.0, 1.0)
	var selection_offset: int = _positive_mod(
		_build_deterministic_hash("%s:%s:%s:%s:%s:start_unlock_outer_edge" % [
			str(board_state.board_width),
			str(board_state.board_height),
			str(start_unlock_outer_edge_depth),
			str(start_unlock_outer_edge_ratio),
			str(clamped_randomness)
		]),
		candidate_tile_indices.size()
	)

	for selection_index in range(desired_seed_count):
		var segment_start: int = int(floor((float(selection_index) * float(candidate_tile_indices.size())) / float(desired_seed_count)))
		var segment_end_exclusive: int = int(floor((float(selection_index + 1) * float(candidate_tile_indices.size())) / float(desired_seed_count)))
		var segment_length: int = max(segment_end_exclusive - segment_start, 1)
		var max_random_offset: int = int(floor(float(segment_length - 1) * clamped_randomness))
		var random_offset: int = 0

		if max_random_offset > 0:
			random_offset = _positive_mod(
				_build_deterministic_hash("%s:%s:%s:%s:%s:random_offset" % [
					str(board_state.board_width),
					str(board_state.board_height),
					str(start_unlock_outer_edge_depth),
					str(selection_index),
					str(clamped_randomness)
				]),
				max_random_offset + 1
			)

		var candidate_list_index: int = (segment_start + random_offset + selection_offset) % candidate_tile_indices.size()
		chosen_tile_indices.append(candidate_tile_indices[candidate_list_index])

	return chosen_tile_indices

static func _build_outer_edge_tile_indices(board_state: BoardState, outer_edge_depth: int) -> PackedInt32Array:
	var candidate_tile_indices: PackedInt32Array = PackedInt32Array()
	if board_state == null:
		return candidate_tile_indices
	if outer_edge_depth <= 0:
		return candidate_tile_indices

	var max_supported_depth: int = int(ceil(float(min(board_state.board_width, board_state.board_height)) * 0.5))
	var clamped_outer_edge_depth: int = clampi(outer_edge_depth, 1, max_supported_depth)
	var appended_tile_lookup: Dictionary = {}

	for edge_band_index in range(clamped_outer_edge_depth):
		_append_outer_edge_band_tile_indices(candidate_tile_indices, appended_tile_lookup, board_state, edge_band_index)

	return candidate_tile_indices

static func _append_outer_edge_band_tile_indices(
	candidate_tile_indices: PackedInt32Array,
	appended_tile_lookup: Dictionary,
	board_state: BoardState,
	edge_band_index: int
) -> void:
	var min_grid_x: int = edge_band_index
	var min_grid_y: int = edge_band_index
	var max_grid_x: int = board_state.board_width - 1 - edge_band_index
	var max_grid_y: int = board_state.board_height - 1 - edge_band_index

	if min_grid_x > max_grid_x or min_grid_y > max_grid_y:
		return

	for grid_x in range(min_grid_x, max_grid_x + 1):
		_append_tile_index_if_valid(candidate_tile_indices, appended_tile_lookup, board_state, grid_x, min_grid_y)

	for grid_y in range(min_grid_y + 1, max_grid_y):
		_append_tile_index_if_valid(candidate_tile_indices, appended_tile_lookup, board_state, max_grid_x, grid_y)

	if max_grid_y > min_grid_y:
		for grid_x in range(max_grid_x, min_grid_x - 1, -1):
			_append_tile_index_if_valid(candidate_tile_indices, appended_tile_lookup, board_state, grid_x, max_grid_y)

	if max_grid_x > min_grid_x:
		for grid_y in range(max_grid_y - 1, min_grid_y, -1):
			_append_tile_index_if_valid(candidate_tile_indices, appended_tile_lookup, board_state, min_grid_x, grid_y)

static func _append_tile_index_if_valid(
	candidate_tile_indices: PackedInt32Array,
	appended_tile_lookup: Dictionary,
	board_state: BoardState,
	grid_x: int,
	grid_y: int
) -> void:
	if not board_state.is_in_bounds(grid_x, grid_y):
		return

	var tile_index: int = board_state.get_tile_index(grid_x, grid_y)
	if tile_index == -1:
		return
	if appended_tile_lookup.has(tile_index):
		return

	appended_tile_lookup[tile_index] = true
	candidate_tile_indices.append(tile_index)
