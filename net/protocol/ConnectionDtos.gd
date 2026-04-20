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

static func build_join_reject_payload(match_id: String, reject_reason: StringName, message: String = "") -> Dictionary:
	return {
		"match_id": match_id,
		"server_time_unix_ms": int(Time.get_unix_time_from_system() * 1000),
		"reject_reason": String(reject_reason),
		"message": message
	}

static func build_join_snapshot_payload(match_state: MatchState, accepted_peer_id: int) -> Dictionary:
	return {
		"match_id": match_state.match_id,
		"match_state": String(match_state.state),
		"map_preset_id": String(match_state.map_preset_id),
		"accepted_peer_id": accepted_peer_id,
		"server_time_unix_ms": int(Time.get_unix_time_from_system() * 1000),
		"players": match_state.build_player_snapshot_list()
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
