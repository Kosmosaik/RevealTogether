extends RefCounted
class_name StartupValidator

static func validate(runtime_config) -> PackedStringArray:
	var validation_errors: PackedStringArray = PackedStringArray()

	_validate_required_autoloads(validation_errors)
	_validate_runtime_configuration(runtime_config, validation_errors)
	_validate_content_manifest(validation_errors)
	_validate_phase_one_runtime_assets(runtime_config, validation_errors)
	_validate_client_world_assets(runtime_config, validation_errors)
	_validate_replication_settings(runtime_config, validation_errors)
	_validate_spawn_layout_settings(runtime_config, validation_errors)
	_validate_phase_two_content(runtime_config, validation_errors)

	return validation_errors

static func _validate_required_autoloads(validation_errors: PackedStringArray) -> void:
	if RuntimeConfig == null:
		validation_errors.append("RuntimeConfig autoload is missing.")
	if LogService == null:
		validation_errors.append("LogService autoload is missing.")
	if ContentRegistry == null:
		validation_errors.append("ContentRegistry autoload is missing.")
	if AppBootstrap == null:
		validation_errors.append("AppBootstrap autoload is missing.")

static func _validate_runtime_configuration(runtime_config, validation_errors: PackedStringArray) -> void:
	if runtime_config == null:
		validation_errors.append("RuntimeConfig failed to initialize.")
		return

	var runtime_mode_name: String = String(runtime_config.get_runtime_mode_name())
	var valid_runtime_modes: PackedStringArray = PackedStringArray([
		"client",
		"dedicated_server",
		"local_debug",
	])

	if not valid_runtime_modes.has(runtime_mode_name):
		validation_errors.append("Unsupported runtime mode '%s'." % runtime_mode_name)

	var bootstrap_scene_path: String = runtime_config.get_bootstrap_scene_path()
	if bootstrap_scene_path.is_empty():
		validation_errors.append("Bootstrap scene path is empty.")
	elif not ResourceLoader.exists(bootstrap_scene_path):
		validation_errors.append("Bootstrap scene path does not exist: %s" % bootstrap_scene_path)

static func _validate_content_manifest(validation_errors: PackedStringArray) -> void:
	var manifest_hash: String = ContentRegistry.get_manifest_hash()
	if manifest_hash.is_empty():
		validation_errors.append("ContentRegistry manifest hash is empty.")

	var registry_warnings: PackedStringArray = ContentRegistry.get_warning_list_copy()
	for warning_message in registry_warnings:
		validation_errors.append(warning_message)

static func _validate_phase_one_runtime_assets(runtime_config, validation_errors: PackedStringArray) -> void:
	var client_scene_path: String = runtime_config.get_string("bootstrap", "client_scene", "")
	if not client_scene_path.is_empty() and not ResourceLoader.exists(client_scene_path):
		validation_errors.append("Configured bootstrap scene path does not exist for 'client_scene': %s" % client_scene_path)

	var server_scene_path: String = runtime_config.get_string("bootstrap", "server_scene", "")
	if not server_scene_path.is_empty() and not ResourceLoader.exists(server_scene_path):
		validation_errors.append("Configured bootstrap scene path does not exist for 'server_scene': %s" % server_scene_path)

	var local_debug_scene_path: String = runtime_config.get_string("bootstrap", "local_debug_scene", "")
	if not local_debug_scene_path.is_empty() and not ResourceLoader.exists(local_debug_scene_path):
		validation_errors.append("Configured bootstrap scene path does not exist for 'local_debug_scene': %s" % local_debug_scene_path)

static func _validate_client_world_assets(runtime_config, validation_errors: PackedStringArray) -> void:
	var runtime_mode_name: String = String(runtime_config.get_runtime_mode_name())
	if runtime_mode_name == "dedicated_server":
		return

	var client_world_scene_path: String = runtime_config.get_string("client_world", "scene_path", "")
	if client_world_scene_path.is_empty():
		validation_errors.append("Client world scene path is empty.")
	elif not ResourceLoader.exists(client_world_scene_path):
		validation_errors.append("Client world scene path does not exist: %s" % client_world_scene_path)

	var player_avatar_scene_path: String = runtime_config.get_string("client_world", "player_avatar_scene_path", "")
	if player_avatar_scene_path.is_empty():
		validation_errors.append("Player avatar scene path is empty.")
	elif not ResourceLoader.exists(player_avatar_scene_path):
		validation_errors.append("Player avatar scene path does not exist: %s" % player_avatar_scene_path)

	var board_view_scene_path: String = runtime_config.get_string("client_world", "board_view_scene_path", "")
	if board_view_scene_path.is_empty():
		validation_errors.append("Board view scene path is empty.")
	elif not ResourceLoader.exists(board_view_scene_path):
		validation_errors.append("Board view scene path does not exist: %s" % board_view_scene_path)

static func _validate_replication_settings(runtime_config, validation_errors: PackedStringArray) -> void:
	var player_transform_interval_sec: float = runtime_config.get_float("replication", "player_transform_interval_sec", 0.0)
	if player_transform_interval_sec <= 0.0:
		validation_errors.append("Replication setting 'player_transform_interval_sec' must be greater than zero.")

static func _validate_spawn_layout_settings(_runtime_config, validation_errors: PackedStringArray) -> void:
	var spawn_layout_def_count: int = 0

	for content_id in ContentRegistry.get_all_content_ids():
		var content_def: Resource = ContentRegistry.get_content(content_id)
		if content_def is SpawnLayoutDef:
			spawn_layout_def_count += 1
			_validate_spawn_layout_def(content_def as SpawnLayoutDef, validation_errors)

	if spawn_layout_def_count <= 0:
		validation_errors.append("No SpawnLayoutDef resources are registered in ContentRegistry.")

static func _validate_phase_two_content(runtime_config, validation_errors: PackedStringArray) -> void:
	var resolved_map_preset_id: StringName = _resolve_runtime_map_preset_id(runtime_config)
	if resolved_map_preset_id == &"":
		validation_errors.append("Configured runtime map preset id is empty.")
	else:
		var resolved_map_preset_resource: Resource = ContentRegistry.get_content(resolved_map_preset_id)
		if resolved_map_preset_resource == null:
			validation_errors.append("Configured runtime map preset id is missing: %s" % String(resolved_map_preset_id))
		elif resolved_map_preset_resource is MapPresetDef:
			_validate_map_preset_def(resolved_map_preset_resource as MapPresetDef, validation_errors)
		else:
			validation_errors.append("Configured runtime map preset id does not resolve to MapPresetDef: %s" % String(resolved_map_preset_id))

	_validate_tile_content_defs(validation_errors)
	_validate_role_defs(validation_errors)

static func _resolve_runtime_map_preset_id(runtime_config) -> StringName:
	var default_map_preset_id: String = runtime_config.get_string("match", "default_map_preset_id", "")

	var runtime_mode_name: String = String(runtime_config.get_runtime_mode_name())
	if runtime_mode_name == "dedicated_server":
		var configured_map_preset_id: String = runtime_config.get_string("server", "map_preset_id", default_map_preset_id)
		if configured_map_preset_id.is_empty():
			configured_map_preset_id = default_map_preset_id
		if configured_map_preset_id.is_empty():
			return &""
		return StringName(configured_map_preset_id)

	if default_map_preset_id.is_empty():
		return &""
	return StringName(default_map_preset_id)

static func _validate_content_def_base_fields(content_def: GameContentDef, content_type_name: String, validation_errors: PackedStringArray) -> void:
	if content_def == null:
		validation_errors.append("%s resource is null." % content_type_name)
		return

	if content_def.id == &"":
		validation_errors.append("%s has an empty id." % content_type_name)

	if content_def.schema_version < 1:
		validation_errors.append("%s has invalid schema_version %d." % [content_type_name, content_def.schema_version])

static func _validate_map_preset_def(map_preset_def: MapPresetDef, validation_errors: PackedStringArray) -> void:
	_validate_content_def_base_fields(map_preset_def, "MapPresetDef '%s'" % String(map_preset_def.id), validation_errors)

	if map_preset_def.board_width <= 0:
		validation_errors.append("Map preset '%s' has invalid board_width %d." % [String(map_preset_def.id), map_preset_def.board_width])
	if map_preset_def.board_height <= 0:
		validation_errors.append("Map preset '%s' has invalid board_height %d." % [String(map_preset_def.id), map_preset_def.board_height])
	if map_preset_def.chunk_width <= 0:
		validation_errors.append("Map preset '%s' has invalid chunk_width %d." % [String(map_preset_def.id), map_preset_def.chunk_width])
	if map_preset_def.chunk_height <= 0:
		validation_errors.append("Map preset '%s' has invalid chunk_height %d." % [String(map_preset_def.id), map_preset_def.chunk_height])
	if map_preset_def.board_width % map_preset_def.chunk_width != 0:
		validation_errors.append("Map preset '%s' board_width must divide evenly by chunk_width." % String(map_preset_def.id))
	if map_preset_def.board_height % map_preset_def.chunk_height != 0:
		validation_errors.append("Map preset '%s' board_height must divide evenly by chunk_height." % String(map_preset_def.id))
	if map_preset_def.start_unlock_outer_edge_ratio < 0.0 or map_preset_def.start_unlock_outer_edge_ratio > 1.0:
		validation_errors.append("Map preset '%s' start_unlock_outer_edge_ratio must be between 0.0 and 1.0." % String(map_preset_def.id))
	if map_preset_def.start_unlock_outer_edge_depth < 0:
		validation_errors.append("Map preset '%s' start_unlock_outer_edge_depth must be zero or greater." % String(map_preset_def.id))
	if map_preset_def.start_unlock_outer_edge_ratio > 0.0 and map_preset_def.start_unlock_outer_edge_depth <= 0:
		validation_errors.append("Map preset '%s' must set start_unlock_outer_edge_depth greater than zero when start_unlock_outer_edge_ratio is enabled." % String(map_preset_def.id))
	if map_preset_def.start_unlock_outer_edge_randomness < 0.0 or map_preset_def.start_unlock_outer_edge_randomness > 1.0:
		validation_errors.append("Map preset '%s' start_unlock_outer_edge_randomness must be between 0.0 and 1.0." % String(map_preset_def.id))
	if map_preset_def.family_region_warp_frequency < 0.0:
		validation_errors.append("Map preset '%s' family_region_warp_frequency must be zero or greater." % String(map_preset_def.id))
	if map_preset_def.family_region_warp_strength < 0.0:
		validation_errors.append("Map preset '%s' family_region_warp_strength must be zero or greater." % String(map_preset_def.id))
	if map_preset_def.final_rush_remaining_tiles_threshold < 0:
		validation_errors.append("Map preset '%s' final_rush_remaining_tiles_threshold must be zero or greater." % String(map_preset_def.id))

	if map_preset_def.reveal_image == null:
		validation_errors.append("Map preset '%s' is missing reveal_image." % String(map_preset_def.id))

	if map_preset_def.spawn_layout_id == &"":
		validation_errors.append("Map preset '%s' has an empty spawn_layout_id." % String(map_preset_def.id))
	elif not ContentRegistry.has_content(map_preset_def.spawn_layout_id):
		validation_errors.append(
			"Map preset '%s' references missing spawn layout '%s'." % [
				String(map_preset_def.id),
				String(map_preset_def.spawn_layout_id)
			]
		)
	else:
		var spawn_layout_resource: Resource = ContentRegistry.get_content(map_preset_def.spawn_layout_id)
		if not (spawn_layout_resource is SpawnLayoutDef):
			validation_errors.append(
				"Map preset '%s' references content '%s' that is not a SpawnLayoutDef resource." % [
					String(map_preset_def.id),
					String(map_preset_def.spawn_layout_id)
				]
			)

static func _validate_spawn_layout_def(spawn_layout_def: SpawnLayoutDef, validation_errors: PackedStringArray) -> void:
	_validate_content_def_base_fields(spawn_layout_def, "SpawnLayoutDef '%s'" % String(spawn_layout_def.id), validation_errors)

	if spawn_layout_def.outside_margin <= 0.0:
		validation_errors.append("Spawn layout '%s' must have outside_margin > 0." % String(spawn_layout_def.id))

	if spawn_layout_def.lane_spacing < 0.0:
		validation_errors.append("Spawn layout '%s' must have lane_spacing >= 0." % String(spawn_layout_def.id))

	if spawn_layout_def.slots_per_side <= 0:
		validation_errors.append("Spawn layout '%s' must have slots_per_side > 0." % String(spawn_layout_def.id))

	if spawn_layout_def.corner_padding < 0.0:
		validation_errors.append("Spawn layout '%s' must have corner_padding >= 0." % String(spawn_layout_def.id))

static func _validate_tile_content_defs(validation_errors: PackedStringArray) -> void:
	var family_id_list: Array[StringName] = []
	var family_ids_with_variants: Dictionary = {}
	var tile_behavior_def_count: int = 0

	for content_id in ContentRegistry.get_all_content_ids():
		var content_def: Resource = ContentRegistry.get_content(content_id)

		if content_def is TileFamilyDef:
			var tile_family_def: TileFamilyDef = content_def as TileFamilyDef
			family_id_list.append(tile_family_def.id)
			family_ids_with_variants[tile_family_def.id] = false
			_validate_tile_family_def(tile_family_def, validation_errors)
			continue

		if content_def is TileBehaviorDef:
			tile_behavior_def_count += 1
			_validate_tile_behavior_def(content_def as TileBehaviorDef, validation_errors)
			continue

		if content_def is TileVariantDef:
			var tile_variant_def: TileVariantDef = content_def as TileVariantDef
			_validate_tile_variant_def(tile_variant_def, validation_errors)

			if family_ids_with_variants.has(tile_variant_def.family_id):
				family_ids_with_variants[tile_variant_def.family_id] = true

	_validate_tile_family_variant_links(family_id_list, family_ids_with_variants, validation_errors)

	if tile_behavior_def_count <= 0:
		validation_errors.append("At least one TileBehaviorDef resource must be registered.")

static func _validate_tile_family_def(tile_family_def: TileFamilyDef, validation_errors: PackedStringArray) -> void:
	_validate_content_def_base_fields(tile_family_def, "TileFamilyDef '%s'" % String(tile_family_def.id), validation_errors)

	if tile_family_def.assignment_weight <= 0.0:
		validation_errors.append("Tile family '%s' must have assignment_weight > 0." % String(tile_family_def.id))

static func _validate_tile_behavior_def(tile_behavior_def: TileBehaviorDef, validation_errors: PackedStringArray) -> void:
	_validate_content_def_base_fields(tile_behavior_def, "TileBehaviorDef '%s'" % String(tile_behavior_def.id), validation_errors)

static func _validate_tile_variant_def(tile_variant_def: TileVariantDef, validation_errors: PackedStringArray) -> void:
	_validate_content_def_base_fields(tile_variant_def, "TileVariantDef '%s'" % String(tile_variant_def.id), validation_errors)

	if tile_variant_def.family_id == &"":
		validation_errors.append("Tile variant '%s' has empty family_id." % String(tile_variant_def.id))
	elif not ContentRegistry.has_content(tile_variant_def.family_id):
		validation_errors.append("Tile variant '%s' references missing family '%s'." % [String(tile_variant_def.id), String(tile_variant_def.family_id)])

	if tile_variant_def.behavior_id == &"":
		validation_errors.append("Tile variant '%s' has empty behavior_id." % String(tile_variant_def.id))
	elif not ContentRegistry.has_content(tile_variant_def.behavior_id):
		validation_errors.append("Tile variant '%s' references missing behavior '%s'." % [String(tile_variant_def.id), String(tile_variant_def.behavior_id)])
	else:
		var tile_behavior_resource: Resource = ContentRegistry.get_content(tile_variant_def.behavior_id)
		if not (tile_behavior_resource is TileBehaviorDef):
			validation_errors.append(
				"Tile variant '%s' references content '%s' that is not a TileBehaviorDef resource." % [
					String(tile_variant_def.id),
					String(tile_variant_def.behavior_id)
				]
			)

	if tile_variant_def.assignment_weight <= 0.0:
		validation_errors.append("Tile variant '%s' must have assignment_weight > 0." % String(tile_variant_def.id))

static func _validate_tile_family_variant_links(family_id_list: Array[StringName], family_ids_with_variants: Dictionary, validation_errors: PackedStringArray) -> void:
	for family_id in family_id_list:
		if not family_ids_with_variants.get(family_id, false):
			validation_errors.append("Tile family '%s' has no valid TileVariantDef entries." % String(family_id))

static func _validate_role_defs(validation_errors: PackedStringArray) -> void:
	var role_def_count: int = 0

	for content_id in ContentRegistry.get_all_content_ids():
		var content_def: Resource = ContentRegistry.get_content(content_id)
		if not (content_def is RoleDef):
			continue

		role_def_count += 1
		var role_def: RoleDef = content_def as RoleDef
		_validate_role_def(role_def, validation_errors)

	if role_def_count <= 0:
		validation_errors.append("At least one RoleDef resource must be registered.")

static func _validate_role_def(role_def: RoleDef, validation_errors: PackedStringArray) -> void:
	_validate_content_def_base_fields(role_def, "RoleDef '%s'" % String(role_def.id), validation_errors)
