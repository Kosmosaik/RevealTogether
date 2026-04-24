extends RefCounted
class_name MatchSpawnPlanner

static func build_spawn_position_for_slot(map_preset_def: MapPresetDef, spawn_layout_def: SpawnLayoutDef, spawn_slot_index: int) -> Vector3:
	if map_preset_def == null or spawn_layout_def == null:
		return Vector3.ZERO

	var normalized_spawn_slot_index: int = max(spawn_slot_index, 0)
	var sides_per_lane: int = 4
	var slots_per_side: int = max(spawn_layout_def.slots_per_side, 1)
	var slots_per_lane: int = slots_per_side * sides_per_lane
	var lane_index: int = normalized_spawn_slot_index / slots_per_lane
	var slot_index_in_lane: int = normalized_spawn_slot_index % slots_per_lane
	var side_index: int = slot_index_in_lane % sides_per_lane
	var slot_index_on_side: int = slot_index_in_lane / sides_per_lane

	var board_world_size: Vector2 = _calculate_board_world_size(map_preset_def)
	var half_board_width: float = board_world_size.x * 0.5
	var half_board_height: float = board_world_size.y * 0.5
	var outside_offset: float = spawn_layout_def.outside_margin + (spawn_layout_def.lane_spacing * float(lane_index))

	var x_min: float = -half_board_width - outside_offset
	var x_max: float = half_board_width + outside_offset
	var z_min: float = -half_board_height - outside_offset
	var z_max: float = half_board_height + outside_offset

	var side_x_min: float = -half_board_width + spawn_layout_def.corner_padding
	var side_x_max: float = half_board_width - spawn_layout_def.corner_padding
	var side_z_min: float = -half_board_height + spawn_layout_def.corner_padding
	var side_z_max: float = half_board_height - spawn_layout_def.corner_padding

	if side_x_min > side_x_max:
		side_x_min = -half_board_width
		side_x_max = half_board_width

	if side_z_min > side_z_max:
		side_z_min = -half_board_height
		side_z_max = half_board_height

	var side_lerp_t: float = _build_side_lerp_t(slot_index_on_side, slots_per_side)

	match side_index:
		0:
			return Vector3(
				lerpf(side_x_min, side_x_max, side_lerp_t),
				spawn_layout_def.vertical_offset,
				z_min
			)
		1:
			return Vector3(
				x_max,
				spawn_layout_def.vertical_offset,
				lerpf(side_z_min, side_z_max, side_lerp_t)
			)
		2:
			return Vector3(
				lerpf(side_x_max, side_x_min, side_lerp_t),
				spawn_layout_def.vertical_offset,
				z_max
			)
		_:
			return Vector3(
				x_min,
				spawn_layout_def.vertical_offset,
				lerpf(side_z_max, side_z_min, side_lerp_t)
			)

static func build_spawn_yaw_for_slot(map_preset_def: MapPresetDef, spawn_layout_def: SpawnLayoutDef, spawn_slot_index: int) -> float:
	var spawn_position: Vector3 = build_spawn_position_for_slot(map_preset_def, spawn_layout_def, spawn_slot_index)
	var direction_to_board_center: Vector3 = Vector3.ZERO - spawn_position
	direction_to_board_center.y = 0.0

	if direction_to_board_center.length_squared() <= 0.0001:
		return PI

	var normalized_direction: Vector3 = direction_to_board_center.normalized()
	return atan2(-normalized_direction.x, -normalized_direction.z)

static func _calculate_board_world_size(map_preset_def: MapPresetDef) -> Vector2:
	return Vector2(
		_calculate_axis_world_span(map_preset_def.board_width),
		_calculate_axis_world_span(map_preset_def.board_height)
	)

static func _calculate_axis_world_span(cell_count: int) -> float:
	if cell_count <= 0:
		return 0.0

	return (float(cell_count) * _get_tile_size()) + (float(cell_count - 1) * _get_tile_gap())

static func _build_side_lerp_t(slot_index_on_side: int, slots_per_side: int) -> float:
	var normalized_slot_index_on_side: int = clampi(slot_index_on_side, 0, max(slots_per_side - 1, 0))
	return float(normalized_slot_index_on_side + 1) / float(slots_per_side + 1)

static func _get_tile_size() -> float:
	return max(RuntimeConfig.get_float("board_view", "tile_size", 1.0), 0.1)

static func _get_tile_gap() -> float:
	return max(RuntimeConfig.get_float("board_view", "tile_gap", 0.001), 0.0)
