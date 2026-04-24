extends Node

const MATCH_SESSION_SERVICE_SCRIPT_PATH: String = "res://net/session/MatchSessionService.gd"
const MATCH_SESSION_SERVICE_NODE_NAME: String = "MatchSessionService"

var _active_bootstrap_root: Node = null

func _ready() -> void:
	# Initialize config first because everything else depends on it.
	RuntimeConfig.initialize()

	# Logging comes next so all later systems can report clearly.
	LogService.initialize_from_runtime_config(RuntimeConfig)
	LogService.info("BOOT", "Runtime mode resolved to '%s'." % String(RuntimeConfig.get_runtime_mode_name()))
	LogService.debug("BOOT", "Resolved config path: %s" % RuntimeConfig.resolved_config_path)

	# Load content early so validation can inspect the filesystem now.
	ContentRegistry.initialize(RuntimeConfig)
	LogService.info("BOOT", "Registered content resources: %d" % ContentRegistry.get_registered_resource_paths_copy().size())
	LogService.info("BOOT", "Content manifest hash: %s" % ContentRegistry.get_manifest_hash())

	var startup_errors: PackedStringArray = StartupValidator.validate(RuntimeConfig)
	if startup_errors.size() > 0:
		_abort_startup(startup_errors)
		return

	_instantiate_bootstrap_scene()

func ensure_match_session_service() -> Node:
	if has_node(MATCH_SESSION_SERVICE_NODE_NAME):
		return get_node(MATCH_SESSION_SERVICE_NODE_NAME)

	var session_service_script: Script = load(MATCH_SESSION_SERVICE_SCRIPT_PATH)
	if session_service_script == null:
		LogService.error("BOOT", "Could not load MatchSessionService script at path: %s" % MATCH_SESSION_SERVICE_SCRIPT_PATH)
		return null

	var session_service: Node = session_service_script.new()
	session_service.name = MATCH_SESSION_SERVICE_NODE_NAME
	add_child(session_service, true)
	return session_service

func _instantiate_bootstrap_scene() -> void:
	var bootstrap_scene_path: String = RuntimeConfig.get_bootstrap_scene_path()
	var bootstrap_scene: PackedScene = load(bootstrap_scene_path) as PackedScene

	if bootstrap_scene == null:
		var scene_load_errors: PackedStringArray = PackedStringArray([
			"Could not load bootstrap scene at path: %s" % bootstrap_scene_path
		])
		_abort_startup(scene_load_errors)
		return

	_active_bootstrap_root = bootstrap_scene.instantiate()
	add_child(_active_bootstrap_root, true)

	LogService.info("BOOT", "Bootstrap scene instantiated: %s" % bootstrap_scene_path)

func _abort_startup(startup_errors: PackedStringArray) -> void:
	for startup_error in startup_errors:
		LogService.error("BOOT", startup_error)

	push_error("RevealTogether failed startup validation. Check the Output panel for details.")
	get_tree().quit(1)
