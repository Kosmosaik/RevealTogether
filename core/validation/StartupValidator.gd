extends RefCounted
class_name StartupValidator

static func validate(runtime_config) -> PackedStringArray:
	var validation_errors: PackedStringArray = PackedStringArray()

	_validate_required_autoloads(validation_errors)
	_validate_runtime_configuration(runtime_config, validation_errors)
	_validate_content_manifest(validation_errors)
	_validate_phase_one_runtime_assets(runtime_config, validation_errors)

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
	var client_world_scene_path: String = runtime_config.get_string("client_world", "scene_path", "")
	if client_world_scene_path.is_empty():
		validation_errors.append("Runtime config key [client_world] scene_path must be set.")
	elif not ResourceLoader.exists(client_world_scene_path):
		validation_errors.append("Client world scene does not exist at '%s'." % client_world_scene_path)

	var player_avatar_scene_path: String = runtime_config.get_string("client_world", "player_avatar_scene_path", "")
	if player_avatar_scene_path.is_empty():
		validation_errors.append("Runtime config key [client_world] player_avatar_scene_path must be set.")
	elif not ResourceLoader.exists(player_avatar_scene_path):
		validation_errors.append("Player avatar scene does not exist at '%s'." % player_avatar_scene_path)

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
