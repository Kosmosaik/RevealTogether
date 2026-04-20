extends RefCounted
class_name MatchState

var match_id: String = ""
var map_preset_id: StringName = &""
var board_state: RefCounted = null
var players_by_peer_id: Dictionary = {}
var started_at_unix_ms: int = 0
var state: StringName = NetProtocol.MATCH_STATE_WAITING_FOR_PLAYERS
var total_clears: int = 0
var final_rush_active: bool = false
var result_payload: Dictionary = {}

func add_player_state(player_state: MatchPlayerState) -> void:
	players_by_peer_id[player_state.peer_id] = player_state

func has_player_state(peer_id: int) -> bool:
	return players_by_peer_id.has(peer_id)

func get_player_state(peer_id: int) -> MatchPlayerState:
	if not players_by_peer_id.has(peer_id):
		return null
	return players_by_peer_id[peer_id] as MatchPlayerState

func remove_player_state(peer_id: int) -> MatchPlayerState:
	if not players_by_peer_id.has(peer_id):
		return null

	var removed_player_state: MatchPlayerState = players_by_peer_id[peer_id] as MatchPlayerState
	players_by_peer_id.erase(peer_id)
	return removed_player_state

func build_player_snapshot_list() -> Array[Dictionary]:
	var peer_ids: Array[int] = []
	for peer_id_variant in players_by_peer_id.keys():
		peer_ids.append(int(peer_id_variant))
	peer_ids.sort()

	var player_snapshots: Array[Dictionary] = []
	for peer_id in peer_ids:
		var player_state: MatchPlayerState = players_by_peer_id[peer_id] as MatchPlayerState
		player_snapshots.append(player_state.to_snapshot_dto())
	return player_snapshots

func build_player_transform_snapshot_list() -> Array[Dictionary]:
	var peer_ids: Array[int] = []
	for peer_id_variant in players_by_peer_id.keys():
		peer_ids.append(int(peer_id_variant))
	peer_ids.sort()

	var transform_snapshots: Array[Dictionary] = []
	for peer_id in peer_ids:
		var player_state: MatchPlayerState = players_by_peer_id[peer_id] as MatchPlayerState
		transform_snapshots.append(player_state.to_transform_snapshot_dto())
	return transform_snapshots
