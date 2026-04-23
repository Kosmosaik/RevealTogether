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
	var default_tile_hp: int = 1

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

	_assign_procedural_tile_content(board_state)
	_apply_start_unlock_seeds(board_state, map_preset_def.start_unlock_seed_count)

	return board_state

static func _build_full_board_uv_rect(board_state: BoardState, grid_x: int, grid_y: int) -> Rect2:
	if board_state.board_width <= 0 or board_state.board_height <= 0:
		return Rect2(0.0, 0.0, 1.0, 1.0)

	var uv_width: float = 1.0 / float(board_state.board_width)
	var uv_height: float = 1.0 / float(board_state.board_height)
	var uv_x: float = float(grid_x) * uv_width
	var uv_y: float = float(grid_y) * uv_height
	return Rect2(uv_x, uv_y, uv_width, uv_height)

static func _assign_procedural_tile_content(board_state: BoardState) -> void:
	var family_list: Array[TileFamilyDef] = BoardTileContentCatalog.build_family_list()
	if family_list.is_empty():
		return

	var variant_list_by_family_id: Dictionary = BoardTileContentCatalog.build_variant_list_by_family_id()
	var chunk_seed_list: Array = _build_chunk_seed_list(board_state, family_list)
	if chunk_seed_list.is_empty():
		return

	for tile_record in board_state.tiles:
		if tile_record == null:
			continue

		var selected_family_id: StringName = _select_family_id_for_tile(tile_record, chunk_seed_list)
		tile_record.family_id = selected_family_id
		tile_record.variant_id = _select_variant_id_for_tile(tile_record, selected_family_id, variant_list_by_family_id)

static func _build_chunk_seed_list(board_state: BoardState, family_list: Array[TileFamilyDef]) -> Array:
	var chunk_seed_list: Array = []

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

			chunk_seed_list.append({
				"family_id": selected_family_id,
				"grid_position": Vector2(seed_grid_x, seed_grid_y)
			})

	return chunk_seed_list

static func _select_family_id_for_tile(tile_record: TileRecord, chunk_seed_list: Array) -> StringName:
	var closest_distance_squared: float = INF
	var closest_family_id: StringName = &""

	for chunk_seed_variant in chunk_seed_list:
		var chunk_seed: Dictionary = chunk_seed_variant as Dictionary
		var seed_position: Vector2 = chunk_seed.get("grid_position", Vector2.ZERO)
		var family_id: StringName = chunk_seed.get("family_id", &"")

		var delta_x: float = float(tile_record.grid_x) - seed_position.x
		var delta_y: float = float(tile_record.grid_y) - seed_position.y
		var distance_squared: float = (delta_x * delta_x) + (delta_y * delta_y)

		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest_family_id = family_id

	return closest_family_id

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

static func _apply_start_unlock_seeds(board_state: BoardState, start_unlock_seed_count: int) -> void:
	if board_state == null:
		return
	if start_unlock_seed_count <= 0:
		return

	var desired_seed_count: int = min(start_unlock_seed_count, board_state.get_total_tile_count())
	var seed_tile_indices: PackedInt32Array = _build_seed_tile_indices(board_state, desired_seed_count)

	for seed_tile_index in seed_tile_indices:
		var tile_record: TileRecord = board_state.get_tile_by_index(seed_tile_index)
		if tile_record == null:
			continue

		tile_record.is_unlocked = true
		tile_record.last_damage_at_ms = 0
		board_state.mark_tile_dirty(seed_tile_index)

static func _build_seed_tile_indices(board_state: BoardState, desired_seed_count: int) -> PackedInt32Array:
	var chosen_tile_indices: PackedInt32Array = PackedInt32Array()
	if desired_seed_count <= 0:
		return chosen_tile_indices

	var center_x: int = board_state.board_width / 2
	var center_y: int = board_state.board_height / 2

	var used_tile_index_lookup: Dictionary = {}
	var ring_radius: int = 0

	while chosen_tile_indices.size() < desired_seed_count:
		var ring_positions: Array[Vector2i] = _build_ring_positions(center_x, center_y, ring_radius)

		for ring_position in ring_positions:
			if not board_state.is_in_bounds(ring_position.x, ring_position.y):
				continue

			var tile_index: int = board_state.get_tile_index(ring_position.x, ring_position.y)
			if tile_index == -1:
				continue
			if used_tile_index_lookup.has(tile_index):
				continue

			used_tile_index_lookup[tile_index] = true
			chosen_tile_indices.append(tile_index)

			if chosen_tile_indices.size() >= desired_seed_count:
				break

		ring_radius += 1

	return chosen_tile_indices

static func _build_ring_positions(center_x: int, center_y: int, ring_radius: int) -> Array[Vector2i]:
	if ring_radius <= 0:
		return [Vector2i(center_x, center_y)]

	var ring_positions: Array[Vector2i] = []

	for offset_x in range(-ring_radius, ring_radius + 1):
		ring_positions.append(Vector2i(center_x + offset_x, center_y - ring_radius))
		ring_positions.append(Vector2i(center_x + offset_x, center_y + ring_radius))

	for offset_y in range(-ring_radius + 1, ring_radius):
		ring_positions.append(Vector2i(center_x - ring_radius, center_y + offset_y))
		ring_positions.append(Vector2i(center_x + ring_radius, center_y + offset_y))

	return ring_positions
