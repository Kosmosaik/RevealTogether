extends RefCounted
class_name StartupValidator

static func validate(runtime_config) -> PackedStringArray:
	var validation_errors: PackedStringArray = PackedStringArray()

	_validate_required_autoloads(validation_errors)
	_validate_runtime_configuration(runtime_config, validation_errors)
	_validate_content_manifest(validation_errors)
	_validate_phase_one_runtime_assets(runtime_config, validation_errors)
	_validate_phase_two_content(runtime_config, validation_errors)

	if validation_errors.is_empty():
		LogService.info("BOOT", "Startup validation completed successfully.")

	return validation_errors

static func _validate_required_autoloads(validation_errors: PackedStringArray) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		validation_errors.append("StartupValidator requires an active SceneTree.")
		return

	var required_autoload_node_names: Array[String] = [
		"RuntimeConfig",
		"LogService",
		"ContentRegistry",
		"AppBootstrap"
	]

	for required_autoload_node_name in required_autoload_node_names:
		if tree.root.get_node_or_null(required_autoload_node_name) == null:
			validation_errors.append(
				"Missing required autoload node at '/root/%s'." % required_autoload_node_name
			)

static func _validate_runtime_configuration(runtime_config, validation_errors: PackedStringArray) -> void:
	if runtime_config == null:
		validation_errors.append("Startup validation received a null RuntimeConfig reference.")
		return

	if not runtime_config.has_method("get_runtime_mode_name"):
		validation_errors.append("RuntimeConfig is missing method get_runtime_mode_name().")
		return

	if not runtime_config.has_method("get_bootstrap_scene_path"):
		validation_errors.append("RuntimeConfig is missing method get_bootstrap_scene_path().")
		return

	var runtime_mode_name: StringName = runtime_config.get_runtime_mode_name()
	var resolved_config_path: String = str(runtime_config.get("resolved_config_path"))

	if String(runtime_mode_name).is_empty():
		validation_errors.append("Runtime mode could not be resolved during startup validation.")

	if resolved_config_path.is_empty():
		validation_errors.append("Resolved runtime config path is empty.")
	elif not FileAccess.file_exists(resolved_config_path):
		validation_errors.append("Runtime config file does not exist at '%s'." % resolved_config_path)

	var bootstrap_scene_path: String = str(runtime_config.get_bootstrap_scene_path())
	if bootstrap_scene_path.is_empty():
		validation_errors.append("Bootstrap scene path is empty for runtime mode '%s'." % String(runtime_mode_name))
	elif not ResourceLoader.exists(bootstrap_scene_path):
		validation_errors.append("Bootstrap scene does not exist at '%s'." % bootstrap_scene_path)

static func _validate_content_manifest(validation_errors: PackedStringArray) -> void:
	var manifest_hash: String = ContentRegistry.get_manifest_hash()
	if manifest_hash.is_empty():
		validation_errors.append("Content manifest hash was not initialized.")

static func _validate_phase_one_runtime_assets(runtime_config, validation_errors: PackedStringArray) -> void:
	if runtime_config == null:
		return

	var runtime_mode_name: StringName = runtime_config.get_runtime_mode_name()

	if runtime_mode_name == &"client" or runtime_mode_name == &"local_debug":
		_validate_client_world_assets(runtime_config, validation_errors)

	if runtime_mode_name == &"dedicated_server":
		_validate_replication_settings(runtime_config, validation_errors)
		_validate_spawn_layout_settings(runtime_config, validation_errors)

static func _validate_client_world_assets(runtime_config, validation_errors: PackedStringArray) -> void:
	if runtime_config == null:
		validation_errors.append("Startup validation received a null RuntimeConfig reference for client world validation.")
		return

	var client_world_scene_path: String = runtime_config.get_string("client_world", "scene_path", "")
	if client_world_scene_path.is_empty():
		validation_errors.append("Missing [client_world] scene_path.")
	elif not ResourceLoader.exists(client_world_scene_path):
		validation_errors.append("Client world scene is missing at '%s'." % client_world_scene_path)

	var player_avatar_scene_path: String = runtime_config.get_string("client_world", "player_avatar_scene_path", "")
	if player_avatar_scene_path.is_empty():
		validation_errors.append("Missing [client_world] player_avatar_scene_path.")
	elif not ResourceLoader.exists(player_avatar_scene_path):
		validation_errors.append("Player avatar scene is missing at '%s'." % player_avatar_scene_path)

	var board_view_scene_path: String = runtime_config.get_string("client_world", "board_view_scene_path", "")
	if board_view_scene_path.is_empty():
		validation_errors.append("Missing [client_world] board_view_scene_path.")
	elif not ResourceLoader.exists(board_view_scene_path):
		validation_errors.append("Board view scene is missing at '%s'." % board_view_scene_path)
	
static func _validate_replication_settings(runtime_config, validation_errors: PackedStringArray) -> void:
	var transform_interval_sec: float = runtime_config.get_float("replication", "player_transform_interval_sec", 0.0)
	if transform_interval_sec <= 0.0:
		validation_errors.append(
			"Runtime config key [replication] player_transform_interval_sec must be greater than zero."
		)

static func _validate_spawn_layout_settings(runtime_config, validation_errors: PackedStringArray) -> void:
	var base_radius: float = runtime_config.get_float("spawn_layout", "base_radius", -1.0)
	if base_radius < 0.0:
		validation_errors.append("Runtime config key [spawn_layout] base_radius must be zero or greater.")

	var ring_spacing: float = runtime_config.get_float("spawn_layout", "ring_spacing", 0.0)
	if ring_spacing <= 0.0:
		validation_errors.append("Runtime config key [spawn_layout] ring_spacing must be greater than zero.")

	var slots_in_inner_ring: int = runtime_config.get_int("spawn_layout", "slots_in_inner_ring", 0)
	if slots_in_inner_ring <= 0:
		validation_errors.append("Runtime config key [spawn_layout] slots_in_inner_ring must be greater than zero.")

static func _validate_phase_two_content(runtime_config, validation_errors: PackedStringArray) -> void:
	if runtime_config == null:
		return

	var content_directories: Dictionary = runtime_config.get_section_copy("content_directories")
	if content_directories.is_empty():
		validation_errors.append("Runtime config section [content_directories] must contain at least one resource directory.")
		return

	var resolved_map_preset_id: StringName = _resolve_runtime_map_preset_id(runtime_config)
	if String(resolved_map_preset_id).is_empty():
		validation_errors.append("Runtime config must resolve a non-empty map preset id.")
		return

	if not ContentRegistry.has_content(resolved_map_preset_id):
		validation_errors.append("ContentRegistry is missing required map preset '%s'." % String(resolved_map_preset_id))
		return

	var map_preset_resource: Resource = ContentRegistry.get_content(resolved_map_preset_id)
	var map_preset_def: MapPresetDef = map_preset_resource as MapPresetDef
	if map_preset_def == null:
		validation_errors.append("Content '%s' is not a MapPresetDef resource." % String(resolved_map_preset_id))
		return

	_validate_map_preset_def(map_preset_def, validation_errors)

static func _resolve_runtime_map_preset_id(runtime_config) -> StringName:
	var default_map_preset_id: String = runtime_config.get_string("match", "default_map_preset_id", "")
	var runtime_mode_name: StringName = runtime_config.get_runtime_mode_name()

	if runtime_mode_name == &"dedicated_server":
		var configured_server_map_preset_id: String = runtime_config.get_string("server", "map_preset_id", default_map_preset_id)
		if not configured_server_map_preset_id.is_empty():
			return StringName(configured_server_map_preset_id)

	return StringName(default_map_preset_id)

static func _validate_map_preset_def(map_preset_def: MapPresetDef, validation_errors: PackedStringArray) -> void:
	if map_preset_def.board_width <= 0:
		validation_errors.append("Map preset '%s' must define board_width greater than zero." % String(map_preset_def.id))

	if map_preset_def.board_height <= 0:
		validation_errors.append("Map preset '%s' must define board_height greater than zero." % String(map_preset_def.id))

	if map_preset_def.chunk_width <= 0:
		validation_errors.append("Map preset '%s' must define chunk_width greater than zero." % String(map_preset_def.id))

	if map_preset_def.chunk_height <= 0:
		validation_errors.append("Map preset '%s' must define chunk_height greater than zero." % String(map_preset_def.id))

	if map_preset_def.start_unlock_seed_count < 0:
		validation_errors.append("Map preset '%s' must define start_unlock_seed_count zero or greater." % String(map_preset_def.id))

	if map_preset_def.final_rush_remaining_tiles_threshold < 0:
		validation_errors.append(
			"Map preset '%s' must define final_rush_remaining_tiles_threshold zero or greater." % String(map_preset_def.id)
		)
