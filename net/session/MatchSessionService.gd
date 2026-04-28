extends Node

signal hello_acknowledged(ack_payload: Dictionary)
signal hello_rejected(reject_payload: Dictionary)
signal joined_match(snapshot_payload: Dictionary)
signal join_match_rejected(reject_payload: Dictionary)
signal player_spawned(player_payload: Dictionary)
signal player_despawned(player_payload: Dictionary)
signal player_transforms_replicated(replication_payload: Dictionary)
signal board_delta_replicated(replication_payload: Dictionary)
signal join_snapshot_stream_started(progress_payload: Dictionary)
signal join_snapshot_stream_progressed(progress_payload: Dictionary)
signal join_snapshot_stream_completed(progress_payload: Dictionary)

var _service_mode: StringName = &"none"
var _network_peer: ENetMultiplayerPeer = null
var _handshake_approved_by_peer_id: Dictionary = {}
var _match_state: MatchState = null
var _local_player_snapshot_by_peer_id: Dictionary = {}
var _local_peer_id: int = 0
var _local_joined_match_id: String = ""
var _server_spawn_slot_by_peer_id: Dictionary = {}
var _server_replication_accumulator_sec: float = 0.0
var _server_reveal_tick_accumulator_sec: float = 0.0

var _pending_join_snapshot_payload: Dictionary = {}
var _pending_join_board_tile_snapshot_list: Array = []
var _pending_join_board_snapshot_chunk_count: int = 0
var _pending_join_board_snapshot_received_chunk_count: int = 0
var _pending_join_board_snapshot_received_chunk_indices: Dictionary = {}

func _ready() -> void:
	# This shared RPC node must live at the same path on client and server.
	# AppBootstrap creates it under /root/AppBootstrap/MatchSessionService.
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	set_process(false)

func start_server_mode() -> void:
	shutdown_session()

	_service_mode = &"server"
	_network_peer = ENetMultiplayerPeer.new()

	var listen_port: int = RuntimeConfig.get_int("network", "listen_port", NetProtocol.DEFAULT_SERVER_PORT)

	var default_max_clients: int = RuntimeConfig.get_int("network", "max_clients", 8)
	var configured_max_players: int = RuntimeConfig.get_int("server", "max_players", default_max_clients)
	var max_clients: int = max(configured_max_players, 1)

	var create_server_error: int = _network_peer.create_server(listen_port, max_clients)
	if create_server_error != OK:
		LogService.error("NET", "Failed to start dedicated server on port %s. Error code: %s" % [listen_port, create_server_error])
		push_error("MatchSessionService could not create the dedicated server peer.")
		return

	multiplayer.multiplayer_peer = _network_peer
	_server_replication_accumulator_sec = 0.0
	_server_reveal_tick_accumulator_sec = 0.0
	set_process(true)

	LogService.info("NET", "Dedicated server listening on UDP port %s for up to %s client(s)." % [listen_port, max_clients])

	_match_state = MatchState.new()
	_match_state.match_id = RuntimeConfig.get_string("match", "default_match_id", "main")
	_match_state.map_preset_id = _resolve_server_map_preset_id()
	_match_state.started_at_unix_ms = int(Time.get_unix_time_from_system() * 1000)
	_match_state.board_state = _build_board_state_for_map_preset(_match_state.map_preset_id)

	if _match_state.board_state == null:
		LogService.error("NET", "Server could not build board state for map preset '%s'." % String(_match_state.map_preset_id))
		push_error("MatchSessionService could not build the server board state.")
		shutdown_session()
		return

	var board_summary: Dictionary = _match_state.board_state.to_summary_dto()
	LogService.info("NET", "Server match '%s' is using map preset '%s'." % [_match_state.match_id, String(_match_state.map_preset_id)])
	LogService.info(
		"NET",
		"Board initialized: %sx%s tiles, %s chunk(s), %s unlocked seed tile(s)." % [
			board_summary.get("board_width", 0),
			board_summary.get("board_height", 0),
			board_summary.get("chunk_count", 0),
			board_summary.get("unlocked_tile_count", 0)
		]
	)
	
func start_client_mode() -> void:
	shutdown_session()

	_service_mode = &"client"
	_network_peer = ENetMultiplayerPeer.new()

	var server_host: String = RuntimeConfig.get_string("network", "server_host", "127.0.0.1")
	var server_port: int = RuntimeConfig.get_int("network", "server_port", NetProtocol.DEFAULT_SERVER_PORT)
	var create_client_error: int = _network_peer.create_client(server_host, server_port)
	if create_client_error != OK:
		LogService.error("NET", "Failed to connect to %s:%s. Error code: %s" % [server_host, server_port, create_client_error])
		push_error("MatchSessionService could not create the client peer.")
		return

	multiplayer.multiplayer_peer = _network_peer
	LogService.info("NET", "Client is connecting to %s:%s." % [server_host, server_port])

func start_local_debug_mode() -> void:
	shutdown_session()
	_service_mode = &"local_debug"
	LogService.info("NET", "Local debug mode active. Network peer is not started yet.")

func _resolve_server_map_preset_id() -> StringName:
	var default_map_preset_id: String = RuntimeConfig.get_string("match", "default_map_preset_id", "map_preset.sandbox_64")
	var configured_map_preset_id: String = RuntimeConfig.get_string("server", "map_preset_id", default_map_preset_id)
	if configured_map_preset_id.is_empty():
		configured_map_preset_id = default_map_preset_id
	return StringName(configured_map_preset_id)

func _get_map_preset_def(map_preset_id: StringName) -> MapPresetDef:
	if map_preset_id == &"":
		LogService.error("NET", "Map preset id is empty.")
		return null

	if not ContentRegistry.has_content(map_preset_id):
		LogService.error("NET", "Map preset '%s' is missing from ContentRegistry." % String(map_preset_id))
		return null

	var map_preset_resource: Resource = ContentRegistry.get_content(map_preset_id)
	var map_preset_def: MapPresetDef = map_preset_resource as MapPresetDef
	if map_preset_def == null:
		LogService.error("NET", "Content '%s' is not a MapPresetDef resource." % String(map_preset_id))
		return null

	return map_preset_def

func _get_server_map_preset_def() -> MapPresetDef:
	var map_preset_id: StringName = &""
	if _match_state != null:
		map_preset_id = _match_state.map_preset_id

	if map_preset_id == &"":
		map_preset_id = _resolve_server_map_preset_id()

	return _get_map_preset_def(map_preset_id)

func _get_server_spawn_layout_def() -> SpawnLayoutDef:
	var map_preset_def: MapPresetDef = _get_server_map_preset_def()
	if map_preset_def == null:
		return null

	if map_preset_def.spawn_layout_id == &"":
		LogService.error("NET", "Map preset '%s' has an empty spawn_layout_id." % String(map_preset_def.id))
		return null

	var spawn_layout_resource: Resource = ContentRegistry.get_content(map_preset_def.spawn_layout_id)
	if spawn_layout_resource == null:
		LogService.error(
			"NET",
			"Map preset '%s' references missing spawn layout '%s'." % [
				String(map_preset_def.id),
				String(map_preset_def.spawn_layout_id)
			]
		)
		return null

	var spawn_layout_def: SpawnLayoutDef = spawn_layout_resource as SpawnLayoutDef
	if spawn_layout_def == null:
		LogService.error(
			"NET",
			"Map preset '%s' references content '%s' that is not a SpawnLayoutDef resource." % [
				String(map_preset_def.id),
				String(map_preset_def.spawn_layout_id)
			]
		)
		return null

	return spawn_layout_def

func _build_board_state_for_map_preset(map_preset_id: StringName) -> BoardState:
	var map_preset_def: MapPresetDef = _get_map_preset_def(map_preset_id)
	if map_preset_def == null:
		return null

	return BoardBuilder.build_board_state_from_map_preset(map_preset_def)

func shutdown_session() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	_network_peer = null
	_service_mode = &"none"
	_handshake_approved_by_peer_id.clear()
	_match_state = null
	_local_player_snapshot_by_peer_id.clear()
	_local_peer_id = 0
	_local_joined_match_id = ""
	_server_spawn_slot_by_peer_id.clear()
	_server_replication_accumulator_sec = 0.0
	_server_reveal_tick_accumulator_sec = 0.0
	_clear_pending_join_snapshot_stream()
	set_process(false)

func get_local_peer_id() -> int:
	return _local_peer_id

func get_joined_match_id() -> String:
	return _local_joined_match_id

func get_player_snapshot_by_peer_id_copy(peer_id: int) -> Dictionary:
	if not _local_player_snapshot_by_peer_id.has(peer_id):
		return {}
	return (_local_player_snapshot_by_peer_id[peer_id] as Dictionary).duplicate(true)
	
func request_reveal_tile(tile_index: int) -> void:
	if _service_mode != &"client":
		return

	if tile_index < 0:
		return

	if _local_joined_match_id.is_empty():
		LogService.debug("NET", "Reveal tile request ignored because no match has been joined yet.")
		return

	var request_payload: Dictionary = ConnectionDtos.build_reveal_tile_request_payload(_local_joined_match_id, tile_index)
	rpc_id(NetProtocol.SERVER_PEER_ID, "rpc_receive_reveal_tile_request", request_payload)

func request_player_transform(
	world_position: Vector3,
	world_yaw_radians: float,
	current_action_state: StringName,
	current_targeted_tile_index: int = -1
) -> void:
	if _service_mode != &"client":
		return

	if _local_joined_match_id.is_empty():
		LogService.debug("NET", "Player transform request ignored because no match has been joined yet.")
		return

	var request_payload: Dictionary = ConnectionDtos.build_player_transform_request_payload(
		_local_joined_match_id,
		world_position,
		world_yaw_radians,
		current_action_state,
		current_targeted_tile_index
	)
	rpc_id(NetProtocol.SERVER_PEER_ID, "rpc_receive_player_transform_request", request_payload)

func _process(delta: float) -> void:
	if _service_mode != &"server":
		return

	if _match_state == null:
		return

	if _match_state.board_state == null:
		return

	var reveal_tick_interval_sec: float = _get_server_reveal_tick_interval_sec()
	_server_reveal_tick_accumulator_sec += delta

	while _server_reveal_tick_accumulator_sec >= reveal_tick_interval_sec:
		_server_reveal_tick_accumulator_sec -= reveal_tick_interval_sec
		_process_server_reveal_actions()

	if _match_state.players_by_peer_id.is_empty():
		return

	var replication_interval_sec: float = _get_server_replication_interval_sec()
	_server_replication_accumulator_sec += delta

	while _server_replication_accumulator_sec >= replication_interval_sec:
		_server_replication_accumulator_sec -= replication_interval_sec
		_broadcast_player_transform_replication_to_connected_clients()

func _on_connected_to_server() -> void:
	_local_peer_id = multiplayer.get_unique_id()
	LogService.info("NET", "Connected to server as peer %s. Starting hello handshake." % _local_peer_id)

	var default_display_name: String = RuntimeConfig.get_string("player", "display_name", "DevClient")
	var configured_display_name: String = RuntimeConfig.get_string("client", "player_display_name", default_display_name)
	var player_display_name: String = configured_display_name
	if player_display_name.is_empty():
		player_display_name = default_display_name

	rpc_id(
		NetProtocol.SERVER_PEER_ID,
		"rpc_receive_hello_payload",
		ConnectionDtos.build_hello_payload(player_display_name)
	)

func _on_connection_failed() -> void:
	LogService.warn("NET", "Connection to the dedicated server failed.")
	shutdown_session()

func _on_server_disconnected() -> void:
	LogService.warn("NET", "Disconnected from the dedicated server.")
	shutdown_session()

func _on_peer_connected(peer_id: int) -> void:
	if _service_mode == &"server":
		LogService.info("NET", "Peer connected: %s" % peer_id)
		return

	if _service_mode == &"client":
		LogService.info("NET", "Peer connected: %s" % peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	LogService.info("NET", "Peer disconnected: %s" % peer_id)

	if _service_mode == &"server":
		_handshake_approved_by_peer_id.erase(peer_id)
		_server_spawn_slot_by_peer_id.erase(peer_id)

		if _match_state != null and _match_state.has_player_state(peer_id):
			_match_state.remove_player_state(peer_id)
			var despawn_payload: Dictionary = ConnectionDtos.build_player_despawn_payload(_match_state, peer_id)
			for approved_peer_id_variant in _handshake_approved_by_peer_id.keys():
				var approved_peer_id: int = int(approved_peer_id_variant)
				rpc_id(approved_peer_id, "rpc_receive_player_despawn", despawn_payload)
			LogService.info("NET", "Peer %s was removed from match '%s'." % [peer_id, _match_state.match_id])
		return

	if _service_mode == &"client" and _local_player_snapshot_by_peer_id.has(peer_id):
		_local_player_snapshot_by_peer_id.erase(peer_id)
		player_despawned.emit({
			"match_id": _local_joined_match_id,
			"peer_id": peer_id
		})

@rpc("any_peer", "call_remote", "reliable", NetProtocol.HANDSHAKE_CHANNEL)
func rpc_receive_hello_payload(hello_payload: Dictionary) -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	var requested_protocol_version: String = str(hello_payload.get("protocol_version", ""))
	var player_display_name: String = str(hello_payload.get("player_display_name", "Player"))
	var client_content_hash: String = str(hello_payload.get("client_content_hash", ""))

	if requested_protocol_version != NetProtocol.PROTOCOL_VERSION:
		LogService.warn(
			"NET",
			"Rejected peer %s due to protocol mismatch. Client='%s' Server='%s'." % [
				sender_peer_id,
				requested_protocol_version,
				NetProtocol.PROTOCOL_VERSION
			]
		)
		_send_hello_reject_to_peer(
			sender_peer_id,
			NetProtocol.HELLO_REJECT_REASON_PROTOCOL_MISMATCH,
			"Protocol version mismatch.",
			""
		)
		return

	var server_content_hash: String = ContentRegistry.get_manifest_hash()
	if client_content_hash != server_content_hash:
		LogService.warn(
			"NET",
			"Rejected peer %s due to content hash mismatch. Client='%s' Server='%s'." % [
				sender_peer_id,
				client_content_hash,
				server_content_hash
			]
		)
		_send_hello_reject_to_peer(
			sender_peer_id,
			NetProtocol.HELLO_REJECT_REASON_CONTENT_HASH_MISMATCH,
			"Content manifest hash mismatch.",
			server_content_hash
		)
		return

	_handshake_approved_by_peer_id[sender_peer_id] = {
		"player_display_name": player_display_name
	}

	var hello_ack_payload: Dictionary = ConnectionDtos.build_hello_ack_payload(server_content_hash)
	rpc_id(sender_peer_id, "rpc_receive_hello_ack", hello_ack_payload)
	LogService.info("NET", "Peer %s passed hello validation." % sender_peer_id)

@rpc("authority", "call_remote", "reliable", NetProtocol.HANDSHAKE_CHANNEL)
func rpc_receive_hello_ack(ack_payload: Dictionary) -> void:
	if multiplayer.is_server():
		return

	var approved_protocol_version: String = str(ack_payload.get("protocol_version", ""))
	if approved_protocol_version != NetProtocol.PROTOCOL_VERSION:
		LogService.warn("NET", "Server replied with incompatible protocol '%s'." % approved_protocol_version)
		shutdown_session()
		return

	LogService.info(
		"NET",
		"Server accepted protocol '%s' and content hash '%s'." % [
			approved_protocol_version,
			ack_payload.get("server_content_hash", "")
		]
	)
	hello_acknowledged.emit(ack_payload)

	var requested_match_id: String = RuntimeConfig.get_string("match", "default_match_id", "main")
	rpc_id(
		NetProtocol.SERVER_PEER_ID,
		"rpc_receive_join_match_request",
		ConnectionDtos.build_join_request_payload(requested_match_id)
	)

@rpc("authority", "call_remote", "reliable", NetProtocol.HANDSHAKE_CHANNEL)
func rpc_receive_hello_reject(reject_payload: Dictionary) -> void:
	if multiplayer.is_server():
		return

	var reject_reason: String = str(reject_payload.get("reject_reason", "unknown"))
	var server_protocol_version: String = str(reject_payload.get("server_protocol_version", ""))
	var reject_message: String = str(reject_payload.get("message", ""))

	LogService.warn(
		"NET",
		"Server rejected hello. Reason='%s' ServerProtocol='%s'. %s" % [
			reject_reason,
			server_protocol_version,
			reject_message
		]
	)

	hello_rejected.emit(reject_payload)
	shutdown_session()

@rpc("any_peer", "call_remote", "reliable", NetProtocol.HANDSHAKE_CHANNEL)

func rpc_receive_join_match_request(join_request_payload: Dictionary) -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	var requested_match_id: String = str(join_request_payload.get("match_id", ""))

	if not _handshake_approved_by_peer_id.has(sender_peer_id):
		LogService.warn("NET", "Peer %s attempted to join a match before passing hello validation." % sender_peer_id)
		_send_join_reject_to_peer(
			sender_peer_id,
			requested_match_id,
			NetProtocol.JOIN_REJECT_REASON_NOT_HANDSHAKEN,
			"Join request arrived before hello validation."
		)
		return

	if _match_state == null:
		LogService.error("NET", "Join request arrived before the server match state was initialized.")
		_send_join_reject_to_peer(
			sender_peer_id,
			requested_match_id,
			NetProtocol.JOIN_REJECT_REASON_MATCH_UNAVAILABLE,
			"Server match state is not initialized."
		)
		return

	if requested_match_id != _match_state.match_id:
		LogService.warn("NET", "Peer %s requested unknown match '%s'." % [sender_peer_id, requested_match_id])
		_send_join_reject_to_peer(
			sender_peer_id,
			requested_match_id,
			NetProtocol.JOIN_REJECT_REASON_MATCH_NOT_FOUND,
			"Requested match does not exist on the server."
		)
		return

	if _match_state.has_player_state(sender_peer_id):
		LogService.warn("NET", "Peer %s attempted to join match '%s' twice." % [sender_peer_id, requested_match_id])
		_send_join_reject_to_peer(
			sender_peer_id,
			requested_match_id,
			NetProtocol.JOIN_REJECT_REASON_ALREADY_JOINED,
			"Peer is already joined to the requested match."
		)
		return

	var map_preset_def: MapPresetDef = _get_server_map_preset_def()
	if map_preset_def == null:
		LogService.error("NET", "Join request could not resolve a valid MapPresetDef for the active match.")
		_send_join_reject_to_peer(
			sender_peer_id,
			requested_match_id,
			NetProtocol.JOIN_REJECT_REASON_MATCH_UNAVAILABLE,
			"Server map preset content is invalid."
		)
		return

	var spawn_layout_def: SpawnLayoutDef = _get_server_spawn_layout_def()
	if spawn_layout_def == null:
		LogService.error("NET", "Join request could not resolve a valid SpawnLayoutDef for the active map preset.")
		_send_join_reject_to_peer(
			sender_peer_id,
			requested_match_id,
			NetProtocol.JOIN_REJECT_REASON_MATCH_UNAVAILABLE,
			"Server spawn layout content is invalid."
		)
		return

	var approved_handshake_payload: Dictionary = _handshake_approved_by_peer_id[sender_peer_id] as Dictionary
	var spawn_slot_index: int = _allocate_spawn_slot_for_peer(sender_peer_id)
	var spawn_position: Vector3 = MatchSpawnPlanner.build_spawn_position_for_slot(map_preset_def, spawn_layout_def, spawn_slot_index)
	var sorted_role_list: Array[RoleDef] = RoleContentCatalog.build_sorted_role_list()

	var player_state: MatchPlayerState = MatchPlayerState.new()
	player_state.peer_id = sender_peer_id
	player_state.player_display_name = str(approved_handshake_payload.get("player_display_name", "Player"))

	if not sorted_role_list.is_empty():
		var assigned_role_index: int = spawn_slot_index % sorted_role_list.size()
		var assigned_role_def: RoleDef = sorted_role_list[assigned_role_index]
		if assigned_role_def != null:
			player_state.role_id = assigned_role_def.id

	player_state.world_position = spawn_position
	player_state.world_yaw_radians = MatchSpawnPlanner.build_spawn_yaw_for_slot(map_preset_def, spawn_layout_def, spawn_slot_index)
	_match_state.add_player_state(player_state)

	_send_join_snapshot_to_peer(sender_peer_id)

	var spawn_payload: Dictionary = ConnectionDtos.build_player_spawn_payload(_match_state, player_state)
	for approved_peer_id_variant in _handshake_approved_by_peer_id.keys():
		var approved_peer_id: int = int(approved_peer_id_variant)
		if approved_peer_id == sender_peer_id:
			continue
		rpc_id(approved_peer_id, "rpc_receive_player_spawn", spawn_payload)

	LogService.info(
		"NET",
		"Peer %s joined match '%s' as '%s' with role '%s'." % [
			sender_peer_id,
			requested_match_id,
			player_state.player_display_name,
			String(player_state.role_id)
		]
	)

@rpc("authority", "call_remote", "reliable", NetProtocol.HANDSHAKE_CHANNEL)

func rpc_receive_join_match_snapshot(snapshot_payload: Dictionary) -> void:
	if multiplayer.is_server():
		return

	var board_snapshot_stream_expected: bool = bool(snapshot_payload.get("board_snapshot_stream_expected", false))
	if board_snapshot_stream_expected:
		_clear_pending_join_snapshot_stream()
		_pending_join_snapshot_payload = snapshot_payload.duplicate(true)

		var board_summary: Dictionary = _get_pending_join_board_summary()
		var expected_tile_count: int = int(board_summary.get("tile_count", 0))
		var expected_chunk_count: int = int(board_summary.get("stream_snapshot_chunk_count", 0))

		join_snapshot_stream_started.emit({
			"match_id": str(snapshot_payload.get("match_id", "")),
			"received_chunk_count": 0,
			"expected_chunk_count": expected_chunk_count,
			"received_tile_count": 0,
			"expected_tile_count": expected_tile_count
		})

		LogService.info(
			"NET",
			"Received streamed join snapshot header for match '%s'. Waiting for board snapshot chunks." % str(snapshot_payload.get("match_id", ""))
		)
		return

	_accept_join_match_snapshot(snapshot_payload)

@rpc("authority", "call_remote", "reliable", NetProtocol.HANDSHAKE_CHANNEL)

func rpc_receive_join_board_snapshot_chunk(chunk_payload: Dictionary) -> void:
	if multiplayer.is_server():
		return

	if _pending_join_snapshot_payload.is_empty():
		LogService.warn("NET", "Received board snapshot chunk without a pending streamed join snapshot.")
		return

	var pending_match_id: String = str(_pending_join_snapshot_payload.get("match_id", ""))
	var chunk_match_id: String = str(chunk_payload.get("match_id", ""))
	if chunk_match_id != pending_match_id:
		LogService.warn(
			"NET",
			"Ignored board snapshot chunk for match '%s' while waiting for match '%s'." % [
				chunk_match_id,
				pending_match_id
			]
		)
		return

	var snapshot_chunk_index: int = int(chunk_payload.get("snapshot_chunk_index", -1))
	var snapshot_chunk_count: int = int(chunk_payload.get("snapshot_chunk_count", 0))
	if snapshot_chunk_index < 0:
		LogService.warn("NET", "Received board snapshot chunk with an invalid chunk index.")
		return
	if snapshot_chunk_count <= 0:
		LogService.warn("NET", "Received board snapshot chunk with an invalid chunk count.")
		return

	if _pending_join_board_snapshot_chunk_count == 0:
		_pending_join_board_snapshot_chunk_count = snapshot_chunk_count
	elif _pending_join_board_snapshot_chunk_count != snapshot_chunk_count:
		LogService.warn("NET", "Received board snapshot chunk with mismatched chunk count.")
		return

	if _pending_join_board_snapshot_received_chunk_indices.has(snapshot_chunk_index):
		return

	var tile_snapshot_list: Array[Dictionary] = _build_tile_snapshot_list_from_join_board_snapshot_chunk(chunk_payload)
	var expected_tile_count: int = int(chunk_payload.get("tile_count", tile_snapshot_list.size()))
	if tile_snapshot_list.is_empty() and expected_tile_count > 0:
		LogService.warn(
			"NET",
			"Received board snapshot chunk %s, but no tile snapshots could be decoded." % snapshot_chunk_index
		)
		return

	for tile_snapshot in tile_snapshot_list:
		if tile_snapshot.is_empty():
			continue

		_pending_join_board_tile_snapshot_list.append(tile_snapshot)

	_pending_join_board_snapshot_received_chunk_indices[snapshot_chunk_index] = true
	_pending_join_board_snapshot_received_chunk_count += 1

	_emit_pending_join_snapshot_stream_progress()

func _emit_pending_join_snapshot_stream_progress() -> void:
	if _pending_join_snapshot_payload.is_empty():
		return

	var board_summary: Dictionary = _get_pending_join_board_summary()
	var expected_tile_count: int = int(board_summary.get("tile_count", 0))
	if expected_tile_count <= 0:
		expected_tile_count = _pending_join_board_tile_snapshot_list.size()

	join_snapshot_stream_progressed.emit({
		"match_id": str(_pending_join_snapshot_payload.get("match_id", "")),
		"received_chunk_count": _pending_join_board_snapshot_received_chunk_count,
		"expected_chunk_count": _pending_join_board_snapshot_chunk_count,
		"received_tile_count": _pending_join_board_tile_snapshot_list.size(),
		"expected_tile_count": expected_tile_count
	})

func _build_tile_snapshot_list_from_join_board_snapshot_chunk(chunk_payload: Dictionary) -> Array[Dictionary]:
	var snapshot_format: String = str(chunk_payload.get(
		"snapshot_format",
		ConnectionDtos.JOIN_BOARD_SNAPSHOT_FORMAT_LEGACY
	))

	if snapshot_format == ConnectionDtos.JOIN_BOARD_SNAPSHOT_FORMAT_COMPACT_V1:
		return _expand_compact_join_board_snapshot_chunk(chunk_payload)

	var raw_tile_snapshot_list: Array = chunk_payload.get("tiles", [])
	var tile_snapshot_list: Array[Dictionary] = []

	for tile_snapshot_variant in raw_tile_snapshot_list:
		if not (tile_snapshot_variant is Dictionary):
			continue

		var tile_snapshot: Dictionary = tile_snapshot_variant
		if tile_snapshot.is_empty():
			continue

		tile_snapshot_list.append(tile_snapshot)

	return tile_snapshot_list


func _expand_compact_join_board_snapshot_chunk(chunk_payload: Dictionary) -> Array[Dictionary]:
	var board_summary: Dictionary = _get_pending_join_board_summary()
	if board_summary.is_empty():
		LogService.warn("NET", "Cannot expand compact board snapshot chunk without a pending board summary.")
		return []

	var board_width: int = int(board_summary.get("board_width", 0))
	var board_height: int = int(board_summary.get("board_height", 0))
	if board_width <= 0 or board_height <= 0:
		LogService.warn("NET", "Cannot expand compact board snapshot chunk with invalid board dimensions.")
		return []

	var chunk_width: int = max(int(board_summary.get("chunk_width", 1)), 1)
	var chunk_height: int = max(int(board_summary.get("chunk_height", 1)), 1)
	var chunk_columns: int = max(int(board_summary.get("chunk_columns", 1)), 1)
	var total_tile_count: int = board_width * board_height

	var compact_tiles: Dictionary = chunk_payload.get("compact_tiles", {})
	if compact_tiles.is_empty():
		return []

	var first_tile_index: int = int(chunk_payload.get("first_tile_index", 0))
	var tile_count: int = int(chunk_payload.get("tile_count", 0))
	if first_tile_index < 0 or tile_count <= 0:
		return []

	var variant_palette: Array = compact_tiles.get("variant_palette", [])
	var variant_palette_indices: Variant = compact_tiles.get("variant_palette_indices", PackedInt32Array())
	var state_flags_values: Variant = compact_tiles.get("state_flags", PackedInt32Array())
	var max_hp_values: Variant = compact_tiles.get("max_hp_values", PackedInt32Array())
	var current_hp_values: Variant = compact_tiles.get("current_hp_values", PackedInt32Array())
	var unlocked_flags: Variant = compact_tiles.get("unlocked_flags", PackedByteArray())
	var cleared_flags: Variant = compact_tiles.get("cleared_flags", PackedByteArray())

	var claimed_tile_states: Array = compact_tiles.get("claimed_tile_states", [])
	var last_damage_tile_states: Array = compact_tiles.get("last_damage_tile_states", [])
	var rare_signal_tile_states: Array = compact_tiles.get("rare_signal_tile_states", [])

	var claim_state_by_relative_index: Dictionary = _build_relative_compact_state_map(claimed_tile_states, 3)
	var last_damage_state_by_relative_index: Dictionary = _build_relative_compact_state_map(last_damage_tile_states, 2)
	var rare_signal_state_by_relative_index: Dictionary = _build_relative_compact_state_map(rare_signal_tile_states, 2)
	var variant_metadata_by_id: Dictionary = _build_compact_snapshot_variant_metadata_by_id(variant_palette)

	var tile_snapshot_list: Array[Dictionary] = []

	for relative_tile_index in range(tile_count):
		var tile_index: int = first_tile_index + relative_tile_index
		if tile_index < 0 or tile_index >= total_tile_count:
			continue

		var grid_x: int = tile_index % board_width
		var grid_y: int = tile_index / board_width
		var chunk_x: int = grid_x / chunk_width
		var chunk_y: int = grid_y / chunk_height
		var chunk_index: int = (chunk_y * chunk_columns) + chunk_x

		var variant_palette_index: int = _get_indexed_int_value(variant_palette_indices, relative_tile_index, -1)
		var variant_id_text: String = ""
		if variant_palette_index >= 0 and variant_palette_index < variant_palette.size():
			variant_id_text = str(variant_palette[variant_palette_index])

		var family_id_text: String = ""
		var behavior_id_text: String = ""
		if variant_metadata_by_id.has(variant_id_text):
			var variant_metadata: Dictionary = variant_metadata_by_id[variant_id_text]
			family_id_text = str(variant_metadata.get("family_id", ""))
			behavior_id_text = str(variant_metadata.get("behavior_id", ""))

		var claim_owner_peer_id: int = 0
		var claim_expires_at_ms: int = 0
		if claim_state_by_relative_index.has(relative_tile_index):
			var claim_state: Array = claim_state_by_relative_index[relative_tile_index]
			claim_owner_peer_id = int(claim_state[1])
			claim_expires_at_ms = int(claim_state[2])

		var last_damage_at_ms: int = 0
		if last_damage_state_by_relative_index.has(relative_tile_index):
			var last_damage_state: Array = last_damage_state_by_relative_index[relative_tile_index]
			last_damage_at_ms = int(last_damage_state[1])

		var rare_signal_state: int = 0
		if rare_signal_state_by_relative_index.has(relative_tile_index):
			var rare_signal_state_entry: Array = rare_signal_state_by_relative_index[relative_tile_index]
			rare_signal_state = int(rare_signal_state_entry[1])

		var uv_rect: Rect2 = _build_compact_snapshot_uv_rect(board_width, board_height, grid_x, grid_y)

		var tile_snapshot: Dictionary = {
			"tile_index": tile_index,
			"tile_id": tile_index,
			"grid_x": grid_x,
			"grid_y": grid_y,
			"chunk_index": chunk_index,
			"family_id": family_id_text,
			"variant_id": variant_id_text,
			"behavior_id": behavior_id_text,
			"state_flags": _get_indexed_int_value(state_flags_values, relative_tile_index, 0),
			"max_hp": _get_indexed_int_value(max_hp_values, relative_tile_index, 0),
			"current_hp": _get_indexed_int_value(current_hp_values, relative_tile_index, 0),
			"is_unlocked": _get_indexed_bool_value(unlocked_flags, relative_tile_index, false),
			"is_cleared": _get_indexed_bool_value(cleared_flags, relative_tile_index, false),
			"claim_owner_peer_id": claim_owner_peer_id,
			"claim_expires_at_ms": claim_expires_at_ms,
			"last_damage_at_ms": last_damage_at_ms,
			"rare_signal_state": rare_signal_state,
			"uv_rect": uv_rect
		}

		tile_snapshot_list.append(tile_snapshot)

	return tile_snapshot_list


func _get_pending_join_board_summary() -> Dictionary:
	var board_summary: Dictionary = _pending_join_snapshot_payload.get("board_summary", {})
	if not board_summary.is_empty():
		return board_summary

	var board_snapshot: Dictionary = _pending_join_snapshot_payload.get("board_snapshot", {})
	return board_snapshot.get("summary", {})


func _build_relative_compact_state_map(state_list: Array, expected_entry_size: int) -> Dictionary:
	var state_by_relative_index: Dictionary = {}

	for state_variant in state_list:
		if not (state_variant is Array):
			continue

		var state_entry: Array = state_variant
		if state_entry.size() < expected_entry_size:
			continue

		var relative_tile_index: int = int(state_entry[0])
		if relative_tile_index < 0:
			continue

		state_by_relative_index[relative_tile_index] = state_entry

	return state_by_relative_index


func _build_compact_snapshot_variant_metadata_by_id(variant_palette: Array) -> Dictionary:
	var metadata_by_variant_id: Dictionary = {}
	var variant_def_by_id: Dictionary = BoardTileContentCatalog.build_variant_by_id()

	for variant_id_variant in variant_palette:
		var variant_id_text: String = str(variant_id_variant)
		var family_id_text: String = ""
		var behavior_id_text: String = ""

		var variant_id: StringName = StringName(variant_id_text)
		if variant_def_by_id.has(variant_id):
			var tile_variant_def: TileVariantDef = variant_def_by_id[variant_id] as TileVariantDef
			if tile_variant_def != null:
				family_id_text = String(tile_variant_def.family_id)
				behavior_id_text = String(tile_variant_def.behavior_id)

		metadata_by_variant_id[variant_id_text] = {
			"family_id": family_id_text,
			"behavior_id": behavior_id_text
		}

	return metadata_by_variant_id


func _build_compact_snapshot_uv_rect(board_width: int, board_height: int, grid_x: int, grid_y: int) -> Rect2:
	if board_width <= 0 or board_height <= 0:
		return Rect2()

	var uv_width: float = 1.0 / float(board_width)
	var uv_height: float = 1.0 / float(board_height)

	return Rect2(
		float(grid_x) * uv_width,
		float(grid_y) * uv_height,
		uv_width,
		uv_height
	)


func _get_indexed_int_value(indexed_values: Variant, value_index: int, default_value: int) -> int:
	if value_index < 0:
		return default_value

	if indexed_values is PackedInt32Array:
		var packed_int32_values: PackedInt32Array = indexed_values
		if value_index >= packed_int32_values.size():
			return default_value
		return int(packed_int32_values[value_index])

	if indexed_values is PackedByteArray:
		var packed_byte_values: PackedByteArray = indexed_values
		if value_index >= packed_byte_values.size():
			return default_value
		return int(packed_byte_values[value_index])

	if indexed_values is Array:
		var array_values: Array = indexed_values
		if value_index >= array_values.size():
			return default_value
		return int(array_values[value_index])

	return default_value


func _get_indexed_bool_value(indexed_values: Variant, value_index: int, default_value: bool) -> bool:
	var default_int_value: int = 0
	if default_value:
		default_int_value = 1

	return _get_indexed_int_value(indexed_values, value_index, default_int_value) != 0

@rpc("authority", "call_remote", "reliable", NetProtocol.HANDSHAKE_CHANNEL)
func rpc_receive_join_board_snapshot_complete(complete_payload: Dictionary) -> void:
	if multiplayer.is_server():
		return

	if _pending_join_snapshot_payload.is_empty():
		LogService.warn("NET", "Received board snapshot stream completion without a pending streamed join snapshot.")
		return

	var pending_match_id: String = str(_pending_join_snapshot_payload.get("match_id", ""))
	var complete_match_id: String = str(complete_payload.get("match_id", ""))
	if complete_match_id != pending_match_id:
		LogService.warn(
			"NET",
			"Ignored board snapshot stream completion for match '%s' while waiting for match '%s'." % [
				complete_match_id,
				pending_match_id
			]
		)
		return

	var expected_chunk_count: int = int(complete_payload.get("snapshot_chunk_count", 0))
	if expected_chunk_count <= 0:
		LogService.warn("NET", "Received board snapshot stream completion with invalid chunk count.")
		return

	if _pending_join_board_snapshot_chunk_count != expected_chunk_count:
		LogService.warn(
			"NET",
			"Board snapshot stream completion expected %s chunk(s), but client expected %s." % [
				expected_chunk_count,
				_pending_join_board_snapshot_chunk_count
			]
		)
		return

	if _pending_join_board_snapshot_received_chunk_count != expected_chunk_count:
		LogService.warn(
			"NET",
			"Board snapshot stream incomplete. Received %s of %s chunk(s)." % [
				_pending_join_board_snapshot_received_chunk_count,
				expected_chunk_count
			]
		)
		return

	var completed_snapshot_payload: Dictionary = _pending_join_snapshot_payload.duplicate(true)
	var board_snapshot: Dictionary = completed_snapshot_payload.get("board_snapshot", {}).duplicate(true)
	var board_summary: Dictionary = complete_payload.get("board_summary", {})

	if not board_summary.is_empty():
		board_snapshot["summary"] = board_summary

	board_snapshot["tiles"] = _pending_join_board_tile_snapshot_list.duplicate(true)
	board_snapshot.erase("is_streamed")

	completed_snapshot_payload["board_snapshot"] = board_snapshot
	completed_snapshot_payload["board_snapshot_stream_expected"] = false

	var expected_tile_count: int = int(board_summary.get("tile_count", _pending_join_board_tile_snapshot_list.size()))
	join_snapshot_stream_completed.emit({
		"match_id": pending_match_id,
		"received_chunk_count": expected_chunk_count,
		"expected_chunk_count": expected_chunk_count,
		"received_tile_count": _pending_join_board_tile_snapshot_list.size(),
		"expected_tile_count": expected_tile_count
	})

	LogService.info(
		"NET",
		"Completed streamed board snapshot for match '%s' with %s tile snapshot(s) across %s chunk(s)." % [
			pending_match_id,
			_pending_join_board_tile_snapshot_list.size(),
			expected_chunk_count
		]
	)

	_clear_pending_join_snapshot_stream()
	_accept_join_match_snapshot(completed_snapshot_payload)

func _accept_join_match_snapshot(snapshot_payload: Dictionary) -> void:
	_local_joined_match_id = str(snapshot_payload.get("match_id", ""))
	_local_peer_id = int(snapshot_payload.get("accepted_peer_id", _local_peer_id))
	_local_player_snapshot_by_peer_id.clear()

	var player_snapshot_list: Array = snapshot_payload.get("players", [])
	var role_summary_list: Array[String] = []

	for player_snapshot_variant in player_snapshot_list:
		var player_snapshot: Dictionary = player_snapshot_variant
		var peer_id: int = int(player_snapshot.get("peer_id", 0))
		if peer_id <= 0:
			continue

		_local_player_snapshot_by_peer_id[peer_id] = player_snapshot.duplicate(true)

		var player_display_name: String = str(player_snapshot.get("player_display_name", ""))
		var player_role_id: String = str(player_snapshot.get("role_id", ""))
		role_summary_list.append("%s='%s' (%s)" % [peer_id, player_role_id, player_display_name])

	LogService.info(
		"NET",
		"Joined match '%s' with %s player snapshot(s). Roles: %s" % [
			_local_joined_match_id,
			player_snapshot_list.size(),
			role_summary_list
		]
	)

	joined_match.emit(snapshot_payload)


func _clear_pending_join_snapshot_stream() -> void:
	_pending_join_snapshot_payload.clear()
	_pending_join_board_tile_snapshot_list.clear()
	_pending_join_board_snapshot_chunk_count = 0
	_pending_join_board_snapshot_received_chunk_count = 0
	_pending_join_board_snapshot_received_chunk_indices.clear()

@rpc("authority", "call_remote", "reliable", NetProtocol.HANDSHAKE_CHANNEL)
func rpc_receive_join_match_reject(reject_payload: Dictionary) -> void:
	if multiplayer.is_server():
		return

	var rejected_match_id: String = str(reject_payload.get("match_id", ""))
	var reject_reason: String = str(reject_payload.get("reject_reason", "unknown"))
	var reject_message: String = str(reject_payload.get("message", ""))

	LogService.warn(
		"NET",
		"Server rejected join request for match '%s'. Reason='%s'. %s" % [
			rejected_match_id,
			reject_reason,
			reject_message
		]
	)

	join_match_rejected.emit(reject_payload)
	shutdown_session()

@rpc("authority", "call_remote", "reliable", NetProtocol.HANDSHAKE_CHANNEL)
func rpc_receive_player_spawn(spawn_payload: Dictionary) -> void:
	if multiplayer.is_server():
		return

	var player_payload: Dictionary = spawn_payload.get("player", {})
	var peer_id: int = int(player_payload.get("peer_id", 0))
	if peer_id <= 0:
		return

	_local_player_snapshot_by_peer_id[peer_id] = player_payload.duplicate(true)

	LogService.info(
		"NET",
		"Player spawn replicated for peer %s ('%s', role='%s')." % [
			peer_id,
			player_payload.get("player_display_name", ""),
			player_payload.get("role_id", "")
		]
	)

	player_spawned.emit(spawn_payload)

@rpc("authority", "call_remote", "reliable", NetProtocol.HANDSHAKE_CHANNEL)
func rpc_receive_player_despawn(despawn_payload: Dictionary) -> void:
	if multiplayer.is_server():
		return

	var peer_id: int = int(despawn_payload.get("peer_id", 0))
	if peer_id <= 0:
		return

	_local_player_snapshot_by_peer_id.erase(peer_id)
	LogService.info("NET", "Player despawn replicated for peer %s." % peer_id)
	player_despawned.emit(despawn_payload)

@rpc("authority", "call_remote", "unreliable_ordered", NetProtocol.GAMEPLAY_CHANNEL)
func rpc_receive_player_transform_replication(replication_payload: Dictionary) -> void:
	if multiplayer.is_server():
		return

	var player_transform_list: Array = replication_payload.get("player_transforms", [])
	for player_transform_variant in player_transform_list:
		var player_transform: Dictionary = player_transform_variant
		var peer_id: int = int(player_transform.get("peer_id", 0))
		if peer_id <= 0:
			continue

		var merged_snapshot: Dictionary = {}
		if _local_player_snapshot_by_peer_id.has(peer_id):
			merged_snapshot = (_local_player_snapshot_by_peer_id[peer_id] as Dictionary).duplicate(true)

		merged_snapshot["peer_id"] = peer_id
		merged_snapshot["world_position"] = player_transform.get("world_position", Vector3.ZERO)
		merged_snapshot["world_yaw_radians"] = float(player_transform.get("world_yaw_radians", 0.0))
		merged_snapshot["current_action_state"] = str(player_transform.get("current_action_state", String(NetProtocol.ACTION_STATE_IDLE)))
		merged_snapshot["current_targeted_tile_index"] = int(player_transform.get("current_targeted_tile_index", -1))
		merged_snapshot["connection_state"] = str(player_transform.get("connection_state", String(NetProtocol.CONNECTION_STATE_CONNECTED)))
		_local_player_snapshot_by_peer_id[peer_id] = merged_snapshot

	player_transforms_replicated.emit(replication_payload)

@rpc("any_peer", "call_remote", "unreliable_ordered", NetProtocol.GAMEPLAY_CHANNEL)
func rpc_receive_player_transform_request(request_payload: Dictionary) -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	if sender_peer_id <= 0:
		return

	if _match_state == null:
		return

	if not _handshake_approved_by_peer_id.has(sender_peer_id):
		LogService.warn("NET", "Rejected player transform request from peer %s before handshake approval." % sender_peer_id)
		return

	var requested_match_id: String = str(request_payload.get("match_id", ""))
	if requested_match_id != _match_state.match_id:
		LogService.warn("NET", "Rejected player transform request from peer %s for unexpected match '%s'." % [sender_peer_id, requested_match_id])
		return

	if not _match_state.has_player_state(sender_peer_id):
		LogService.warn("NET", "Rejected player transform request from unknown player peer %s." % sender_peer_id)
		return

	var player_state: MatchPlayerState = _match_state.get_player_state(sender_peer_id)
	if player_state == null:
		return

	var requested_world_position: Vector3 = request_payload.get("world_position", player_state.world_position)
	var requested_world_yaw_radians: float = float(request_payload.get("world_yaw_radians", player_state.world_yaw_radians))
	var requested_action_state: StringName = StringName(
		str(request_payload.get("current_action_state", String(NetProtocol.ACTION_STATE_IDLE)))
	)

	var authoritative_timestamp_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	var elapsed_sec: float = _get_server_movement_request_window_sec()
	if player_state.last_input_tick > 0:
		elapsed_sec = clampf(
			float(authoritative_timestamp_ms - player_state.last_input_tick) / 1000.0,
			0.016,
			_get_server_movement_request_window_sec()
		)

	var move_delta: Vector3 = requested_world_position - player_state.world_position
	move_delta.y = 0.0

	var max_move_distance: float = (
		_get_player_move_speed_units_per_sec()
		* elapsed_sec
		* _get_server_speed_tolerance_multiplier()
	)
	if move_delta.length() > max_move_distance and max_move_distance >= 0.0:
		move_delta = move_delta.normalized() * max_move_distance

	var next_world_position: Vector3 = player_state.world_position + move_delta
	next_world_position.y = player_state.world_position.y
	next_world_position = _clamp_world_position_to_match_bounds(next_world_position)

	player_state.world_position = next_world_position

	var did_move_this_request: bool = move_delta.length_squared() > 0.000001
	if requested_action_state == NetProtocol.ACTION_STATE_MOVING:
		player_state.current_targeted_tile_index = -1

		if did_move_this_request:
			player_state.world_yaw_radians = requested_world_yaw_radians
			player_state.current_action_state = NetProtocol.ACTION_STATE_MOVING

			if _match_state.state == NetProtocol.MATCH_STATE_WAITING_FOR_PLAYERS:
				_match_state.state = NetProtocol.MATCH_STATE_ACTIVE
		else:
			player_state.current_action_state = NetProtocol.ACTION_STATE_IDLE
	elif player_state.current_action_state == NetProtocol.ACTION_STATE_MOVING:
		player_state.current_action_state = NetProtocol.ACTION_STATE_IDLE
		player_state.current_targeted_tile_index = -1

	player_state.last_input_tick = authoritative_timestamp_ms

@rpc("any_peer", "call_remote", "reliable", NetProtocol.GAMEPLAY_CHANNEL)
func rpc_receive_reveal_tile_request(request_payload: Dictionary) -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	if sender_peer_id <= 0:
		return

	if _match_state == null:
		return

	if _match_state.board_state == null:
		return

	if not _handshake_approved_by_peer_id.has(sender_peer_id):
		LogService.warn("NET", "Rejected reveal tile request from peer %s before handshake approval." % sender_peer_id)
		return

	var requested_match_id: String = str(request_payload.get("match_id", ""))
	if requested_match_id != _match_state.match_id:
		LogService.warn("NET", "Rejected reveal tile request from peer %s for unexpected match '%s'." % [sender_peer_id, requested_match_id])
		return

	if not _match_state.has_player_state(sender_peer_id):
		LogService.warn("NET", "Rejected reveal tile request from unknown player peer %s." % sender_peer_id)
		return

	var tile_index: int = int(request_payload.get("tile_index", -1))
	var action_timestamp_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	var player_state: MatchPlayerState = _match_state.get_player_state(sender_peer_id)
	var action_result: Dictionary = BoardActionService.try_reveal_tile(_match_state, sender_peer_id, tile_index, action_timestamp_ms)

	if not bool(action_result.get("accepted", false)):
		LogService.debug("NET", "Reveal tile request rejected for peer %s: %s." % [sender_peer_id, str(action_result.get("reason", "unknown"))])
		return

	if _match_state.state == NetProtocol.MATCH_STATE_WAITING_FOR_PLAYERS:
		_match_state.state = NetProtocol.MATCH_STATE_ACTIVE

	player_state.last_input_tick = action_timestamp_ms

	if bool(action_result.get("action_should_continue", false)):
		player_state.current_action_state = NetProtocol.ACTION_STATE_REVEALING
		player_state.current_targeted_tile_index = tile_index
	else:
		player_state.current_action_state = NetProtocol.ACTION_STATE_IDLE
		player_state.current_targeted_tile_index = -1

	var changed_tile_indices: Array = action_result.get("changed_tile_indices", [])
	_broadcast_board_delta_to_connected_clients(changed_tile_indices, &"reveal_tile", sender_peer_id)

@rpc("authority", "call_remote", "reliable", NetProtocol.GAMEPLAY_CHANNEL)
func rpc_receive_board_delta(replication_payload: Dictionary) -> void:
	if multiplayer.is_server():
		return

	var match_id: String = str(replication_payload.get("match_id", ""))
	if match_id != _local_joined_match_id:
		return

	board_delta_replicated.emit(replication_payload)

func _get_player_move_speed_units_per_sec() -> float:
	return max(RuntimeConfig.get_float("movement", "move_speed_units_per_sec", 6.0), 0.1)

func _get_server_movement_request_window_sec() -> float:
	return max(RuntimeConfig.get_float("movement", "server_max_request_window_sec", 0.20), 0.016)

func _get_server_speed_tolerance_multiplier() -> float:
	return max(RuntimeConfig.get_float("movement", "server_speed_tolerance_multiplier", 1.25), 1.0)

func _clamp_world_position_to_match_bounds(world_position: Vector3) -> Vector3:
	var clamped_world_position: Vector3 = world_position
	var half_extents: Vector2 = _get_match_ground_half_extents()
	var body_radius: float = max(RuntimeConfig.get_float("client_world", "player_body_radius", 0.45), 0.1)

	var clamp_limit_x: float = max(half_extents.x - body_radius, 0.0)
	var clamp_limit_z: float = max(half_extents.y - body_radius, 0.0)

	clamped_world_position.x = clampf(clamped_world_position.x, -clamp_limit_x, clamp_limit_x)
	clamped_world_position.z = clampf(clamped_world_position.z, -clamp_limit_z, clamp_limit_z)
	return clamped_world_position

func _get_match_ground_half_extents() -> Vector2:
	var default_ground_size: float = max(RuntimeConfig.get_float("client_world", "ground_size", 64.0), 8.0)
	var ground_size_x: float = max(
		RuntimeConfig.get_float("client_world", "ground_size_x", default_ground_size),
		8.0
	)
	var ground_size_z: float = max(
		RuntimeConfig.get_float("client_world", "ground_size_z", default_ground_size),
		8.0
	)

	if _match_state != null and _match_state.board_state != null:
		var tile_size: float = max(RuntimeConfig.get_float("board_view", "tile_size", 1.0), 0.01)
		var tile_gap: float = max(RuntimeConfig.get_float("board_view", "tile_gap", 0.0), 0.0)
		var ground_margin: float = max(RuntimeConfig.get_float("board_view", "ground_margin", 8.0), 0.0)
		var tile_stride: float = tile_size + tile_gap

		var minimum_world_size_x: float = max(
			(float(_match_state.board_state.board_width) * tile_stride) - tile_gap,
			0.0
		) + ground_margin
		var minimum_world_size_z: float = max(
			(float(_match_state.board_state.board_height) * tile_stride) - tile_gap,
			0.0
		) + ground_margin

		ground_size_x = max(ground_size_x, minimum_world_size_x)
		ground_size_z = max(ground_size_z, minimum_world_size_z)

	return Vector2(ground_size_x * 0.5, ground_size_z * 0.5)

func _allocate_spawn_slot_for_peer(peer_id: int) -> int:
	if _server_spawn_slot_by_peer_id.has(peer_id):
		return int(_server_spawn_slot_by_peer_id[peer_id])

	var occupied_slot_lookup: Dictionary = {}
	for spawn_slot_variant in _server_spawn_slot_by_peer_id.values():
		occupied_slot_lookup[int(spawn_slot_variant)] = true

	var candidate_spawn_slot: int = 0
	while occupied_slot_lookup.has(candidate_spawn_slot):
		candidate_spawn_slot += 1

	_server_spawn_slot_by_peer_id[peer_id] = candidate_spawn_slot
	return candidate_spawn_slot

func _get_server_replication_interval_sec() -> float:
	return max(RuntimeConfig.get_float("replication", "player_transform_interval_sec", 0.100), 0.020)

func _get_server_reveal_tick_interval_sec() -> float:
	return max(RuntimeConfig.get_float("board_actions", "reveal_tick_interval_sec", 0.20), 0.050)

func _process_server_reveal_actions() -> void:
	if _match_state == null:
		return

	if _match_state.board_state == null:
		return

	var changed_tile_indices: Array = []
	var changed_tile_lookup: Dictionary = {}
	var action_timestamp_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	var did_process_reveal_tick: bool = false

	for tile_record_variant in _match_state.board_state.tiles:
		var tile_record: TileRecord = tile_record_variant as TileRecord
		if tile_record == null:
			continue

		if tile_record.claim_owner_peer_id <= 0:
			continue

		if tile_record.claim_expires_at_ms <= 0:
			continue

		if tile_record.claim_expires_at_ms > action_timestamp_ms:
			continue

		tile_record.claim_owner_peer_id = 0
		tile_record.claim_expires_at_ms = 0
		_match_state.board_state.mark_tile_dirty(tile_record.tile_index)

		if not changed_tile_lookup.has(tile_record.tile_index):
			changed_tile_lookup[tile_record.tile_index] = true
			changed_tile_indices.append(tile_record.tile_index)

	var player_peer_id_list: Array = _match_state.players_by_peer_id.keys()

	for peer_id_variant in player_peer_id_list:
		var peer_id: int = int(peer_id_variant)
		var player_state: MatchPlayerState = _match_state.get_player_state(peer_id)
		if player_state == null:
			continue

		if player_state.current_action_state != NetProtocol.ACTION_STATE_REVEALING:
			continue

		if player_state.current_targeted_tile_index < 0:
			player_state.current_action_state = NetProtocol.ACTION_STATE_IDLE
			player_state.current_targeted_tile_index = -1
			continue

		did_process_reveal_tick = true

		var action_result: Dictionary = BoardActionService.try_reveal_tile(
			_match_state,
			peer_id,
			player_state.current_targeted_tile_index,
			action_timestamp_ms
		)

		if not bool(action_result.get("accepted", false)):
			player_state.current_action_state = NetProtocol.ACTION_STATE_IDLE
			player_state.current_targeted_tile_index = -1
			continue

		if _match_state.state == NetProtocol.MATCH_STATE_WAITING_FOR_PLAYERS:
			_match_state.state = NetProtocol.MATCH_STATE_ACTIVE

		player_state.last_input_tick = action_timestamp_ms

		if not bool(action_result.get("action_should_continue", false)):
			player_state.current_action_state = NetProtocol.ACTION_STATE_IDLE
			player_state.current_targeted_tile_index = -1

		var action_changed_tile_indices: Array = action_result.get("changed_tile_indices", [])
		for changed_tile_index_variant in action_changed_tile_indices:
			var changed_tile_index: int = int(changed_tile_index_variant)
			if changed_tile_lookup.has(changed_tile_index):
				continue

			changed_tile_lookup[changed_tile_index] = true
			changed_tile_indices.append(changed_tile_index)

	if changed_tile_indices.is_empty():
		return

	var cause: StringName = &"claim_timeout"
	if did_process_reveal_tick:
		cause = &"reveal_tick"

	_broadcast_board_delta_to_connected_clients(changed_tile_indices, cause, 0)

func _broadcast_player_transform_replication_to_connected_clients() -> void:
	if _match_state == null:
		return

	var replication_payload: Dictionary = ConnectionDtos.build_player_transform_replication_payload(_match_state)
	for approved_peer_id_variant in _handshake_approved_by_peer_id.keys():
		var approved_peer_id: int = int(approved_peer_id_variant)
		if not _match_state.has_player_state(approved_peer_id):
			continue
		rpc_id(approved_peer_id, "rpc_receive_player_transform_replication", replication_payload)

func _send_join_snapshot_to_peer(peer_id: int) -> void:
	if _match_state == null:
		return

	if _match_state.board_state == null:
		return

	var stream_join_board_snapshot: bool = _should_stream_join_board_snapshot()
	var join_snapshot_payload: Dictionary = ConnectionDtos.build_join_snapshot_payload(
		_match_state,
		peer_id,
		not stream_join_board_snapshot
	)

	rpc_id(peer_id, "rpc_receive_join_match_snapshot", join_snapshot_payload)

	if stream_join_board_snapshot:
		_send_join_board_snapshot_stream_to_peer(peer_id)


func _should_stream_join_board_snapshot() -> bool:
	if _match_state == null:
		return false

	if _match_state.board_state == null:
		return false

	var stream_tile_threshold: int = max(
		RuntimeConfig.get_int("replication", "join_snapshot_stream_tile_threshold", 32768),
		1
	)

	return _match_state.board_state.tiles.size() >= stream_tile_threshold


func _get_join_snapshot_stream_batch_size() -> int:
	return max(
		RuntimeConfig.get_int("replication", "join_snapshot_stream_batch_size", 2048),
		1
	)


func _send_join_board_snapshot_stream_to_peer(peer_id: int) -> void:
	if RuntimeConfig.get_bool("replication", "join_snapshot_stream_compact_enabled", true):
		_send_compact_join_board_snapshot_stream_to_peer(peer_id)
		return

	_send_legacy_join_board_snapshot_stream_to_peer(peer_id)


func _send_legacy_join_board_snapshot_stream_to_peer(peer_id: int) -> void:
	if _match_state == null:
		return

	if _match_state.board_state == null:
		return

	var tile_snapshot_list: Array = _match_state.board_state.build_tile_snapshot_list()
	var batch_size: int = _get_join_snapshot_stream_batch_size()
	var snapshot_chunk_count: int = int(ceil(float(tile_snapshot_list.size()) / float(batch_size)))

	for snapshot_chunk_index in range(snapshot_chunk_count):
		var start_index: int = snapshot_chunk_index * batch_size
		var end_index: int = min(start_index + batch_size, tile_snapshot_list.size())
		var tile_snapshot_batch: Array = tile_snapshot_list.slice(start_index, end_index)

		var chunk_payload: Dictionary = ConnectionDtos.build_join_board_snapshot_chunk_payload(
			_match_state,
			snapshot_chunk_index,
			snapshot_chunk_count,
			tile_snapshot_batch
		)

		rpc_id(peer_id, "rpc_receive_join_board_snapshot_chunk", chunk_payload)

	var complete_payload: Dictionary = ConnectionDtos.build_join_board_snapshot_complete_payload(
		_match_state,
		snapshot_chunk_count
	)

	rpc_id(peer_id, "rpc_receive_join_board_snapshot_complete", complete_payload)

	LogService.info(
		"NET",
		"Sent legacy streamed board snapshot to peer %s with %s tile snapshot(s) across %s chunk(s)." % [
			peer_id,
			tile_snapshot_list.size(),
			snapshot_chunk_count
		]
	)


func _send_compact_join_board_snapshot_stream_to_peer(peer_id: int) -> void:
	if _match_state == null:
		return

	if _match_state.board_state == null:
		return

	var board_state: BoardState = _match_state.board_state
	var total_tile_count: int = board_state.tiles.size()
	if total_tile_count <= 0:
		return

	var batch_size: int = _get_join_snapshot_stream_batch_size()
	var snapshot_chunk_count: int = int(ceil(float(total_tile_count) / float(batch_size)))

	for snapshot_chunk_index in range(snapshot_chunk_count):
		var first_tile_index: int = snapshot_chunk_index * batch_size
		var exclusive_end_tile_index: int = min(first_tile_index + batch_size, total_tile_count)
		var tile_count: int = exclusive_end_tile_index - first_tile_index

		var compact_tile_batch: Dictionary = _build_compact_join_board_snapshot_batch(
			board_state,
			first_tile_index,
			exclusive_end_tile_index
		)

		var chunk_payload: Dictionary = ConnectionDtos.build_join_board_snapshot_compact_chunk_payload(
			_match_state,
			snapshot_chunk_index,
			snapshot_chunk_count,
			first_tile_index,
			tile_count,
			compact_tile_batch
		)

		rpc_id(peer_id, "rpc_receive_join_board_snapshot_chunk", chunk_payload)

	var complete_payload: Dictionary = ConnectionDtos.build_join_board_snapshot_complete_payload(
		_match_state,
		snapshot_chunk_count
	)

	rpc_id(peer_id, "rpc_receive_join_board_snapshot_complete", complete_payload)

	LogService.info(
		"NET",
		"Sent compact streamed board snapshot to peer %s with %s tile snapshot(s) across %s chunk(s)." % [
			peer_id,
			total_tile_count,
			snapshot_chunk_count
		]
	)


func _build_compact_join_board_snapshot_batch(
	board_state: BoardState,
	first_tile_index: int,
	exclusive_end_tile_index: int
) -> Dictionary:
	var variant_palette: Array[String] = []
	var variant_index_by_id: Dictionary = {}
	var variant_palette_indices: PackedInt32Array = PackedInt32Array()
	var state_flags_values: PackedInt32Array = PackedInt32Array()
	var max_hp_values: PackedInt32Array = PackedInt32Array()
	var current_hp_values: PackedInt32Array = PackedInt32Array()
	var unlocked_flags: PackedByteArray = PackedByteArray()
	var cleared_flags: PackedByteArray = PackedByteArray()
	var claimed_tile_states: Array = []
	var last_damage_tile_states: Array = []
	var rare_signal_tile_states: Array = []

	for tile_index in range(first_tile_index, exclusive_end_tile_index):
		var relative_tile_index: int = tile_index - first_tile_index
		var tile_record: TileRecord = board_state.get_tile_by_index(tile_index)

		if tile_record == null:
			variant_palette_indices.append(_get_or_register_compact_variant_palette_index("", variant_palette, variant_index_by_id))
			state_flags_values.append(0)
			max_hp_values.append(0)
			current_hp_values.append(0)
			unlocked_flags.append(0)
			cleared_flags.append(0)
			continue

		var variant_id_text: String = String(tile_record.variant_id)
		var variant_palette_index: int = _get_or_register_compact_variant_palette_index(
			variant_id_text,
			variant_palette,
			variant_index_by_id
		)

		variant_palette_indices.append(variant_palette_index)
		state_flags_values.append(tile_record.state_flags)
		max_hp_values.append(tile_record.max_hp)
		current_hp_values.append(tile_record.current_hp)

		var unlocked_flag: int = 0
		if tile_record.is_unlocked:
			unlocked_flag = 1
		unlocked_flags.append(unlocked_flag)

		var cleared_flag: int = 0
		if tile_record.is_cleared:
			cleared_flag = 1
		cleared_flags.append(cleared_flag)

		if tile_record.claim_owner_peer_id != 0 or tile_record.claim_expires_at_ms != 0:
			claimed_tile_states.append([
				relative_tile_index,
				tile_record.claim_owner_peer_id,
				tile_record.claim_expires_at_ms
			])

		if tile_record.last_damage_at_ms != 0:
			last_damage_tile_states.append([
				relative_tile_index,
				tile_record.last_damage_at_ms
			])

		if tile_record.rare_signal_state != 0:
			rare_signal_tile_states.append([
				relative_tile_index,
				tile_record.rare_signal_state
			])

	return {
		"variant_palette": variant_palette,
		"variant_palette_indices": variant_palette_indices,
		"state_flags": state_flags_values,
		"max_hp_values": max_hp_values,
		"current_hp_values": current_hp_values,
		"unlocked_flags": unlocked_flags,
		"cleared_flags": cleared_flags,
		"claimed_tile_states": claimed_tile_states,
		"last_damage_tile_states": last_damage_tile_states,
		"rare_signal_tile_states": rare_signal_tile_states
	}


func _get_or_register_compact_variant_palette_index(
	variant_id_text: String,
	variant_palette: Array[String],
	variant_index_by_id: Dictionary
) -> int:
	if variant_index_by_id.has(variant_id_text):
		return int(variant_index_by_id[variant_id_text])

	var variant_palette_index: int = variant_palette.size()
	variant_palette.append(variant_id_text)
	variant_index_by_id[variant_id_text] = variant_palette_index
	return variant_palette_index

func _broadcast_board_delta_to_connected_clients(changed_tile_indices: Array, cause: StringName, actor_peer_id: int) -> void:
	if _match_state == null:
		return

	if _match_state.board_state == null:
		return

	if changed_tile_indices.is_empty():
		return

	var replication_payload: Dictionary = ConnectionDtos.build_board_delta_payload(_match_state, changed_tile_indices, cause, actor_peer_id)

	for approved_peer_id_variant in _handshake_approved_by_peer_id.keys():
		var approved_peer_id: int = int(approved_peer_id_variant)
		if not _match_state.has_player_state(approved_peer_id):
			continue

		rpc_id(approved_peer_id, "rpc_receive_board_delta", replication_payload)

	_match_state.board_state.clear_all_chunk_dirty_sets()

func _send_hello_reject_to_peer(
	peer_id: int,
	reject_reason: StringName,
	message: String,
	server_content_hash: String
) -> void:
	if peer_id <= 0:
		return

	var reject_payload: Dictionary = ConnectionDtos.build_hello_reject_payload(
		reject_reason,
		server_content_hash,
		NetProtocol.PROTOCOL_VERSION,
		message
	)

	rpc_id(peer_id, "rpc_receive_hello_reject", reject_payload)
	call_deferred("_disconnect_rejected_peer", peer_id)

func _send_join_reject_to_peer(
	peer_id: int,
	match_id: String,
	reject_reason: StringName,
	message: String
) -> void:
	if peer_id <= 0:
		return

	var reject_payload: Dictionary = ConnectionDtos.build_join_reject_payload(
		match_id,
		reject_reason,
		message
	)

	rpc_id(peer_id, "rpc_receive_join_match_reject", reject_payload)
	call_deferred("_disconnect_rejected_peer", peer_id)

func _disconnect_rejected_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	if multiplayer.multiplayer_peer == null:
		return

	multiplayer.multiplayer_peer.disconnect_peer(peer_id)
