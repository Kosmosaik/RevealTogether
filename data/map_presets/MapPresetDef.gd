extends GameContentDef
class_name MapPresetDef

@export var board_width: int = 64
@export var board_height: int = 64
@export var chunk_width: int = 16
@export var chunk_height: int = 16
@export var start_unlock_seed_count: int = 4
@export var final_rush_remaining_tiles_threshold: int = 50
@export var reveal_image: Texture2D = null
@export var reveal_mapping_mode: StringName = &"full_board_uv"
@export var family_distribution_table_id: StringName = &""
@export var variant_distribution_table_id: StringName = &""
@export var rare_tile_chance: float = 0.02
@export var spawn_layout_id: StringName = &""
@export var milestone_set_id: StringName = &""
@export var tuning_profile_id: StringName = &""
