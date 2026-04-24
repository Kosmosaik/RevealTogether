extends RefCounted
class_name RoleContentCatalog

static func build_role_list() -> Array[RoleDef]:
	var role_list: Array[RoleDef] = []
	var content_id_list: Array[StringName] = ContentRegistry.get_all_content_ids()

	for content_id in content_id_list:
		var content_def: Resource = ContentRegistry.get_content(content_id)
		if content_def is RoleDef:
			role_list.append(content_def as RoleDef)

	return role_list

static func build_role_by_id() -> Dictionary:
	var role_by_id: Dictionary = {}
	var role_list: Array[RoleDef] = build_role_list()

	for role_def in role_list:
		role_by_id[role_def.id] = role_def

	return role_by_id

static func build_sorted_role_list() -> Array[RoleDef]:
	var unsorted_role_list: Array[RoleDef] = build_role_list()
	var sorted_role_list: Array[RoleDef] = []

	for role_def in unsorted_role_list:
		if role_def == null:
			continue

		var insert_index: int = sorted_role_list.size()
		var scan_index: int = 0
		while scan_index < sorted_role_list.size():
			var existing_role_def: RoleDef = sorted_role_list[scan_index]
			if String(role_def.id) < String(existing_role_def.id):
				insert_index = scan_index
				break
			scan_index += 1

		sorted_role_list.insert(insert_index, role_def)

	return sorted_role_list
