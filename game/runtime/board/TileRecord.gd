extends RefCounted
class_name TileRecord

var tile_index: int = -1
var tile_id: int = -1
var grid_x: int = 0
var grid_y: int = 0
var chunk_index: int = -1
var family_id: StringName = &""
var variant_id: StringName = &""
var behavior_id: StringName = &""
var state_flags: int = 0
var max_hp: int = 0
var current_hp: int = 0
var is_unlocked: bool = false
var is_cleared: bool = false
var claim_owner_peer_id: int = 0
var claim_expires_at_ms: int = 0
var last_damage_at_ms: int = 0
var rare_signal_state: int = 0
var uv_rect: Rect2 = Rect2()
var runtime_tags: PackedStringArray = []

func to_snapshot_dto() -> Dictionary:
	return {
		"tile_index": tile_index,
		"tile_id": tile_id,
		"grid_x": grid_x,
		"grid_y": grid_y,
		"chunk_index": chunk_index,
		"family_id": String(family_id),
		"variant_id": String(variant_id),
		"behavior_id": String(behavior_id),
		"state_flags": state_flags,
		"max_hp": max_hp,
		"current_hp": current_hp,
		"is_unlocked": is_unlocked,
		"is_cleared": is_cleared,
		"claim_owner_peer_id": claim_owner_peer_id,
		"claim_expires_at_ms": claim_expires_at_ms,
		"last_damage_at_ms": last_damage_at_ms,
		"rare_signal_state": rare_signal_state,
		"uv_rect": uv_rect,
		"runtime_tags": runtime_tags
	}
