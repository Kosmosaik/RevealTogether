extends RefCounted
class_name BoardTileContentCatalog

static func build_family_list() -> Array[TileFamilyDef]:
	var family_by_id: Dictionary = {}
	var sorted_family_id_list: Array[String] = []
	var content_id_list: Array[StringName] = ContentRegistry.get_all_content_ids()

	for content_id in content_id_list:
		var content_resource: Resource = ContentRegistry.get_content(content_id)
		var tile_family_def: TileFamilyDef = content_resource as TileFamilyDef
		if tile_family_def == null:
			continue

		if String(tile_family_def.id).is_empty():
			continue

		if tile_family_def.assignment_weight <= 0.0:
			continue

		family_by_id[tile_family_def.id] = tile_family_def
		sorted_family_id_list.append(String(tile_family_def.id))

	sorted_family_id_list.sort()

	var family_list: Array[TileFamilyDef] = []
	for sorted_family_id in sorted_family_id_list:
		var family_id: StringName = StringName(sorted_family_id)
		var tile_family_def: TileFamilyDef = family_by_id[family_id] as TileFamilyDef
		if tile_family_def == null:
			continue
		family_list.append(tile_family_def)

	return family_list

static func build_family_by_id() -> Dictionary:
	var family_by_id: Dictionary = {}
	var family_list: Array[TileFamilyDef] = build_family_list()

	for tile_family_def in family_list:
		family_by_id[tile_family_def.id] = tile_family_def

	return family_by_id

static func build_variant_list() -> Array[TileVariantDef]:
	var variant_by_id: Dictionary = {}
	var sorted_variant_id_list: Array[String] = []
	var content_id_list: Array[StringName] = ContentRegistry.get_all_content_ids()

	for content_id in content_id_list:
		var content_resource: Resource = ContentRegistry.get_content(content_id)
		var tile_variant_def: TileVariantDef = content_resource as TileVariantDef
		if tile_variant_def == null:
			continue

		if String(tile_variant_def.id).is_empty():
			continue

		if tile_variant_def.assignment_weight <= 0.0:
			continue

		if String(tile_variant_def.family_id).is_empty():
			continue

		variant_by_id[tile_variant_def.id] = tile_variant_def
		sorted_variant_id_list.append(String(tile_variant_def.id))

	sorted_variant_id_list.sort()

	var variant_list: Array[TileVariantDef] = []
	for sorted_variant_id in sorted_variant_id_list:
		var variant_id: StringName = StringName(sorted_variant_id)
		var tile_variant_def: TileVariantDef = variant_by_id[variant_id] as TileVariantDef
		if tile_variant_def == null:
			continue
		variant_list.append(tile_variant_def)

	return variant_list

static func build_variant_by_id() -> Dictionary:
	var variant_by_id: Dictionary = {}
	var variant_list: Array[TileVariantDef] = build_variant_list()

	for tile_variant_def in variant_list:
		variant_by_id[tile_variant_def.id] = tile_variant_def

	return variant_by_id

static func build_variant_list_by_family_id() -> Dictionary:
	var variant_list_by_family_id: Dictionary = {}
	var variant_list: Array[TileVariantDef] = build_variant_list()

	for tile_variant_def in variant_list:
		if not variant_list_by_family_id.has(tile_variant_def.family_id):
			variant_list_by_family_id[tile_variant_def.family_id] = []

		var family_variant_list: Array = variant_list_by_family_id[tile_variant_def.family_id] as Array
		family_variant_list.append(tile_variant_def)
		variant_list_by_family_id[tile_variant_def.family_id] = family_variant_list

	return variant_list_by_family_id
