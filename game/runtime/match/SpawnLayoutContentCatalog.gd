extends RefCounted
class_name SpawnLayoutContentCatalog

static func get_spawn_layout(spawn_layout_id: StringName) -> SpawnLayoutDef:
	if spawn_layout_id == &"":
		return null

	var content_resource: Resource = ContentRegistry.get_content(spawn_layout_id)
	return content_resource as SpawnLayoutDef

static func build_sorted_spawn_layout_list() -> Array[SpawnLayoutDef]:
	var spawn_layout_list: Array[SpawnLayoutDef] = []

	for content_id in ContentRegistry.get_all_content_ids():
		var content_resource: Resource = ContentRegistry.get_content(content_id)
		var spawn_layout_def: SpawnLayoutDef = content_resource as SpawnLayoutDef
		if spawn_layout_def != null:
			spawn_layout_list.append(spawn_layout_def)

	spawn_layout_list.sort_custom(
		func(left: SpawnLayoutDef, right: SpawnLayoutDef) -> bool:
			return String(left.id) < String(right.id)
	)

	return spawn_layout_list
