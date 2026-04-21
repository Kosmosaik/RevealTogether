extends RefCounted
class_name ChunkState

var chunk_index: int = -1
var chunk_x: int = 0
var chunk_y: int = 0
var tile_indices: PackedInt32Array = PackedInt32Array()
var dirty_tile_indices: PackedInt32Array = PackedInt32Array()
var has_visual_subscribers: bool = false

func add_tile_index(tile_index: int) -> void:
	tile_indices.append(tile_index)

func mark_tile_dirty(tile_index: int) -> void:
	if dirty_tile_indices.has(tile_index):
		return
	dirty_tile_indices.append(tile_index)

func clear_dirty_tile_indices() -> void:
	dirty_tile_indices = PackedInt32Array()
