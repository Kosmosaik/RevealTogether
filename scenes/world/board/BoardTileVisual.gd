extends Node3D
class_name BoardTileVisual

@export var content_root_path: NodePath
@export var locked_overlay_path: NodePath
@export var claimed_overlay_path: NodePath

var _content_root: Node3D = null
var _locked_overlay: Node3D = null
var _claimed_overlay: Node3D = null

func _ready() -> void:
	_resolve_visual_nodes()

func apply_tile_snapshot(tile_snapshot: Dictionary) -> void:
	_resolve_visual_nodes()

	var is_cleared: bool = bool(tile_snapshot.get("is_cleared", false))
	var is_unlocked: bool = bool(tile_snapshot.get("is_unlocked", false))
	var claim_owner_peer_id: int = int(tile_snapshot.get("claim_owner_peer_id", 0))

	visible = not is_cleared

	if _content_root != null:
		_content_root.visible = not is_cleared
	if _locked_overlay != null:
		_locked_overlay.visible = (not is_cleared) and (not is_unlocked) and claim_owner_peer_id <= 0
	if _claimed_overlay != null:
		_claimed_overlay.visible = (not is_cleared) and claim_owner_peer_id > 0

func _resolve_visual_nodes() -> void:
	if _content_root == null and not content_root_path.is_empty():
		_content_root = get_node_or_null(content_root_path) as Node3D
	if _locked_overlay == null and not locked_overlay_path.is_empty():
		_locked_overlay = get_node_or_null(locked_overlay_path) as Node3D
	if _claimed_overlay == null and not claimed_overlay_path.is_empty():
		_claimed_overlay = get_node_or_null(claimed_overlay_path) as Node3D
