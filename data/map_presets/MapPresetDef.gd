extends GameContentDef
class_name MapPresetDef

@export var board_width: int = 64
@export var board_height: int = 64
@export var chunk_width: int = 16
@export var chunk_height: int = 16
@export var start_unlock_outer_edge_ratio: float = 0.2
@export var start_unlock_outer_edge_depth: int = 1
@export var start_unlock_outer_edge_randomness: float = 0.35
@export var final_rush_remaining_tiles_threshold: int = 50
@export var reveal_image: Texture2D = null
@export var reveal_mapping_mode: StringName = &"full_board_uv"
@export var family_region_warp_frequency: float = 0.08
@export var family_region_warp_strength: float = 3.0
@export var family_region_seed_search_radius_chunks: int = 2
@export var spawn_layout_id: StringName = &""
