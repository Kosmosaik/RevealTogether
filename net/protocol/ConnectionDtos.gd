extends RefCounted
class_name ConnectionDtos

static func build_hello_payload(player_display_name: String) -> Dictionary:
	return {
		"protocol_version": NetProtocol.PROTOCOL_VERSION,
		"player_display_name": player_display_name,
		"client_content_hash": ContentRegistry.get_manifest_hash()
	}

static func build_hello_ack_payload(server_content_hash: String) -> Dictionary:
	return {
		"protocol_version": NetProtocol.PROTOCOL_VERSION,
		"server_content_hash": server_content_hash
	}

static func build_hello_reject_payload(
	reject_reason: StringName,
	server_content_hash: String = "",
	server_protocol_version: String = NetProtocol.PROTOCOL_VERSION,
	message: String = ""
) -> Dictionary:
	return {
		"server_protocol_version": server_protocol_version,
		"server_content_hash": server_content_hash,
		"reject_reason": String(reject_reason),
		"message": message
	}

static func build_join_request_payload(match_id: String) -> Dictionary:
	return {
		"match_id": match_id
	}
	
static func build_reveal_tile_request_payload(match_id: String, tile_index: int) -> Dictionary:
	return {
		"match_id": match_id,
		"tile_index": tile_index,
	}


static func build_board_delta_payload(match_state: MatchState, changed_tile_indices: Array, cause: StringName = &"", actor_peer_id: int = 0) -> Dictionary:
	var board_state: BoardState = match_state.board_state
	var changed_tiles: Array = []
	var seen_tile_indices: Dictionary = {}

	for changed_tile_index_variant in changed_tile_indices:
		var changed_tile_index: int = int(changed_tile_index_variant)
		if seen_tile_indices.has(changed_tile_index):
			continue

		seen_tile_indices[changed_tile_index] = true

		var tile_record: TileRecord = board_state.get_tile_by_index(changed_tile_index)
		if tile_record == null:
			continue

		changed_tiles.append(_build_board_tile_delta_payload(tile_record))

	return {
		"match_id": match_state.match_id,
		"cause": String(cause),
		"actor_peer_id": actor_peer_id,
		"board_summary": board_state.to_summary_dto(),
		"changed_tiles": changed_tiles,
	}

static func build_join_reject_payload(match_id: String, reject_reason: StringName, message: String = "") -> Dictionary:
	return {
		"match_id": match_id,
		"server_time_unix_ms": int(Time.get_unix_time_from_system() * 1000),
		"reject_reason": String(reject_reason),
		"message": message
	}

static func build_join_snapshot_payload(match_state: MatchState, accepted_peer_id: int) -> Dictionary:
	var board_summary: Dictionary = {}
	var board_snapshot: Dictionary = {}

	if match_state.board_state != null:
		board_summary = match_state.board_state.to_summary_dto()
		board_snapshot = match_state.board_state.to_snapshot_dto()

	return {
		"match_id": match_state.match_id,
		"match_state": String(match_state.state),
		"map_preset_id": String(match_state.map_preset_id),
		"accepted_peer_id": accepted_peer_id,
		"server_time_unix_ms": int(Time.get_unix_time_from_system() * 1000),
		"players": match_state.build_player_snapshot_list(),
		"board_summary": board_summary,
		"board_snapshot": board_snapshot
	}

static func build_player_spawn_payload(match_state: MatchState, player_state: MatchPlayerState) -> Dictionary:
	return {
		"match_id": match_state.match_id,
		"server_time_unix_ms": int(Time.get_unix_time_from_system() * 1000),
		"player": player_state.to_snapshot_dto()
	}

static func build_player_despawn_payload(match_state: MatchState, peer_id: int) -> Dictionary:
	return {
		"match_id": match_state.match_id,
		"server_time_unix_ms": int(Time.get_unix_time_from_system() * 1000),
		"peer_id": peer_id
	}

static func build_player_transform_replication_payload(match_state: MatchState) -> Dictionary:
	return {
		"match_id": match_state.match_id,
		"server_time_unix_ms": int(Time.get_unix_time_from_system() * 1000),
		"player_transforms": match_state.build_player_transform_snapshot_list()
	}
	
static func _build_board_tile_delta_payload(tile_record: TileRecord) -> Dictionary:
	return {
		"tile_index": tile_record.tile_index,
		"grid_x": tile_record.grid_x,
		"grid_y": tile_record.grid_y,
		"state_flags": tile_record.state_flags,
		"current_hp": tile_record.current_hp,
		"is_unlocked": tile_record.is_unlocked,
		"is_cleared": tile_record.is_cleared,
		"claim_owner_peer_id": tile_record.claim_owner_peer_id,
		"claim_expires_at_ms": tile_record.claim_expires_at_ms,
		"last_damage_at_ms": tile_record.last_damage_at_ms,
		"rare_signal_state": tile_record.rare_signal_state,
	}
