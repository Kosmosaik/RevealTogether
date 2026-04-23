extends GameContentDef
class_name TileVariantDef

# The family this variant belongs to.
@export var family_id: StringName = &""

# Relative weight used when choosing a variant inside a family.
@export var assignment_weight: float = 1.0

# Optional authored scene. When null, the board view falls back to batched placeholders.
@export var visual_scene: PackedScene = null
