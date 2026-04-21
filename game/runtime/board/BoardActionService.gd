extends RefCounted
class_name BoardActionService


static func try_reveal_tile(match_state: MatchState, peer_id: int, tile_index: int, action_timestamp_ms: int = 0) -> Dictionary:
	if match_state == null:
		return _reject_action("match_state_missing", peer_id, tile_index)

	if match_state.state == NetProtocol.MATCH_STATE_FINISHED:
		return _reject_action("match_finished", peer_id, tile_index)

	var board_state: BoardState = match_state.board_state
	if board_state == null:
		return _reject_action("board_state_missing", peer_id, tile_index)

	# Keep runtime state consistent if the board is already fully cleared.
	if board_state.remaining_uncleared_tiles <= 0:
		match_state.state = NetProtocol.MATCH_STATE_FINISHED
		match_state.final_rush_active = false
		board_state.final_rush_active = false
		return _reject_action("match_finished", peer_id, tile_index)

	var tile_record: TileRecord = board_state.get_tile_by_index(tile_index)
	if tile_record == null:
		return _reject_action("tile_not_found", peer_id, tile_index)

	if not tile_record.is_unlocked:
		return _reject_action("tile_locked", peer_id, tile_index)

	if tile_record.is_cleared:
		return _reject_action("tile_already_cleared", peer_id, tile_index)

	if action_timestamp_ms <= 0:
		action_timestamp_ms = int(Time.get_unix_time_from_system() * 1000.0)

	if tile_record.claim_owner_peer_id > 0 \
	and tile_record.claim_expires_at_ms > 0 \
	and tile_record.claim_expires_at_ms <= action_timestamp_ms:
		tile_record.claim_owner_peer_id = 0
		tile_record.claim_expires_at_ms = 0
		board_state.mark_tile_dirty(tile_index)

	if tile_record.claim_owner_peer_id > 0 and tile_record.claim_owner_peer_id != peer_id:
		return _reject_action("tile_claimed_by_other_player", peer_id, tile_index)

	tile_record.claim_owner_peer_id = peer_id
	tile_record.claim_expires_at_ms = action_timestamp_ms + _get_claim_duration_ms()

	var reveal_damage_per_tick: int = _get_reveal_damage_per_tick(board_state)
	tile_record.current_hp = max(tile_record.current_hp - reveal_damage_per_tick, 0)
	tile_record.last_damage_at_ms = action_timestamp_ms
	board_state.mark_tile_dirty(tile_index)

	var changed_tile_indices: Array = []
	var changed_tile_lookup: Dictionary = {}
	_append_changed_tile_index(changed_tile_indices, changed_tile_lookup, tile_index)

	if tile_record.current_hp > 0:
		return {
			"accepted": true,
			"reason": "tile_damaged",
			"peer_id": peer_id,
			"tile_index": tile_index,
			"action_should_continue": true,
			"changed_tile_indices": changed_tile_indices,
		}

	tile_record.current_hp = 0
	tile_record.is_cleared = true
	tile_record.claim_owner_peer_id = 0
	tile_record.claim_expires_at_ms = 0
	tile_record.last_damage_at_ms = action_timestamp_ms
	board_state.remaining_uncleared_tiles = max(board_state.remaining_uncleared_tiles - 1, 0)
	match_state.total_clears += 1
	board_state.mark_tile_dirty(tile_index)
	_append_changed_tile_index(changed_tile_indices, changed_tile_lookup, tile_index)

	var unlocked_neighbor_tile_indices: Array = _unlock_neighbor_tiles(board_state, tile_record)
	for unlocked_tile_index_variant in unlocked_neighbor_tile_indices:
		var unlocked_tile_index: int = int(unlocked_tile_index_variant)
		_append_changed_tile_index(changed_tile_indices, changed_tile_lookup, unlocked_tile_index)

	# Completion takes priority over final-rush activation.
	if board_state.remaining_uncleared_tiles <= 0:
		match_state.state = NetProtocol.MATCH_STATE_FINISHED
		match_state.final_rush_active = false
		board_state.final_rush_active = false

		LogService.info("BOARD", "Match finished for match '%s'. Cleared by peer %d on tile %d. Total clears: %d." % [
			match_state.match_id,
			peer_id,
			tile_index,
			match_state.total_clears,
		])

		return {
			"accepted": true,
			"reason": "tile_cleared",
			"peer_id": peer_id,
			"tile_index": tile_index,
			"action_should_continue": false,
			"changed_tile_indices": changed_tile_indices,
		}

	var final_rush_activated: bool = _activate_final_rush_if_needed(match_state, changed_tile_indices, changed_tile_lookup)
	if final_rush_activated:
		match_state.state = NetProtocol.MATCH_STATE_FINAL_RUSH

	return {
		"accepted": true,
		"reason": "tile_cleared",
		"peer_id": peer_id,
		"tile_index": tile_index,
		"action_should_continue": false,
		"changed_tile_indices": changed_tile_indices,
	}

static func _unlock_neighbor_tiles(board_state: BoardState, source_tile_record: TileRecord) -> Array:
	var newly_unlocked_tile_indices: Array = []
	var neighbor_tile_indices: Array = board_state.get_neighbor_tile_indices(source_tile_record.tile_index)

	for neighbor_tile_index_variant in neighbor_tile_indices:
		var neighbor_tile_index: int = int(neighbor_tile_index_variant)
		var neighbor_tile_record: TileRecord = board_state.get_tile_by_index(neighbor_tile_index)
		if neighbor_tile_record == null:
			continue
		if neighbor_tile_record.is_unlocked:
			continue
		if neighbor_tile_record.is_cleared:
			continue

		neighbor_tile_record.is_unlocked = true
		board_state.mark_tile_dirty(neighbor_tile_record.tile_index)
		newly_unlocked_tile_indices.append(neighbor_tile_record.tile_index)

	return newly_unlocked_tile_indices


static func _append_changed_tile_index(changed_tile_indices: Array, changed_tile_lookup: Dictionary, tile_index: int) -> void:
	if changed_tile_lookup.has(tile_index):
		return

	changed_tile_lookup[tile_index] = true
	changed_tile_indices.append(tile_index)


static func _reject_action(reason: String, peer_id: int, tile_index: int) -> Dictionary:
	return {
		"accepted": false,
		"reason": reason,
		"actor_peer_id": peer_id,
		"tile_index": tile_index,
		"changed_tile_indices": [],
		"newly_unlocked_tile_indices": [],
		"tile_cleared": false,
		"action_should_continue": false,
		"final_rush_activated": false,
	}


static func _get_claim_duration_ms() -> int:
	return max(RuntimeConfig.get_int("board_actions", "claim_duration_ms", 3000), 250)


static func _get_reveal_damage_per_tick(board_state: BoardState) -> int:
	var base_damage_per_tick: int = max(RuntimeConfig.get_int("board_actions", "reveal_damage_per_tick", 1), 1)

	if not board_state.final_rush_active:
		return base_damage_per_tick

	var final_rush_damage_multiplier: float = max(RuntimeConfig.get_float("board_actions", "final_rush_damage_multiplier", 2.0), 1.0)
	return max(int(ceil(float(base_damage_per_tick) * final_rush_damage_multiplier)), 1)


static func _activate_final_rush_if_needed(match_state: MatchState, changed_tile_indices: Array, changed_tile_lookup: Dictionary) -> bool:
	var board_state: BoardState = match_state.board_state
	if board_state == null:
		return false

	if board_state.final_rush_active:
		return false

	var map_preset_def: MapPresetDef = _resolve_map_preset_def(match_state)
	if map_preset_def == null:
		return false

	if board_state.remaining_uncleared_tiles > map_preset_def.final_rush_remaining_tiles_threshold:
		return false

	board_state.final_rush_active = true
	match_state.final_rush_active = true
	_clear_all_tile_claims(board_state, changed_tile_indices, changed_tile_lookup)

	LogService.info("BOARD", "Final Rush activated for match '%s'. Remaining uncleared tiles: %d. Threshold: %d." % [
		match_state.match_id,
		board_state.remaining_uncleared_tiles,
		map_preset_def.final_rush_remaining_tiles_threshold,
	])

	return true

static func _resolve_map_preset_def(match_state: MatchState) -> MapPresetDef:
	if match_state.map_preset_id == StringName():
		return null

	if not ContentRegistry.has_content(match_state.map_preset_id):
		return null

	var content_resource: Resource = ContentRegistry.get_content(match_state.map_preset_id)
	return content_resource as MapPresetDef


static func _clear_all_tile_claims(board_state: BoardState, changed_tile_indices: Array, changed_tile_lookup: Dictionary) -> void:
	for tile_record_variant in board_state.tiles:
		var tile_record: TileRecord = tile_record_variant as TileRecord
		if tile_record == null:
			continue

		if tile_record.claim_owner_peer_id == 0 and tile_record.claim_expires_at_ms == 0:
			continue

		tile_record.claim_owner_peer_id = 0
		tile_record.claim_expires_at_ms = 0
		board_state.mark_tile_dirty(tile_record.tile_index)
		_append_changed_tile_index(changed_tile_indices, changed_tile_lookup, tile_record.tile_index)
