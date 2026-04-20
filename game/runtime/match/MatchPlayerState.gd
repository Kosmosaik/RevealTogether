extends RefCounted
class_name MatchPlayerState

var peer_id: int = 0
var player_display_name: String = ""
var role_id: StringName = &""
var world_position: Vector3 = Vector3.ZERO
var world_yaw_radians: float = 0.0
var inventory_component: RefCounted = null
var equipped_tool_item_instance_id: String = ""
var equipped_charm_item_instance_id: String = ""
var current_action_state: StringName = NetProtocol.ACTION_STATE_IDLE
var current_targeted_tile_index: int = -1
var last_input_tick: int = 0
var connection_state: StringName = NetProtocol.CONNECTION_STATE_CONNECTED

func to_snapshot_dto() -> Dictionary:
	return {
		"peer_id": peer_id,
		"player_display_name": player_display_name,
		"role_id": String(role_id),
		"world_position": world_position,
		"world_yaw_radians": world_yaw_radians,
		"current_action_state": String(current_action_state),
		"current_targeted_tile_index": current_targeted_tile_index,
		"connection_state": String(connection_state)
	}

func to_transform_snapshot_dto() -> Dictionary:
	return {
		"peer_id": peer_id,
		"world_position": world_position,
		"world_yaw_radians": world_yaw_radians,
		"current_action_state": String(current_action_state),
		"current_targeted_tile_index": current_targeted_tile_index,
		"connection_state": String(connection_state)
	}
