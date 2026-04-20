extends Node

var _client_world_instance: Node = null

func _ready() -> void:
	var boot_message: String = RuntimeConfig.get_string("client", "boot_message", "Client bootstrap active.")
	LogService.info("BOOT", boot_message)

	_apply_window_title_from_config()

	var match_session_service = AppBootstrap.ensure_match_session_service()
	if match_session_service == null:
		push_error("ClientBootstrap could not acquire MatchSessionService.")
		return

	_instantiate_client_world()

	match_session_service.start_client_mode()
	LogService.info("BOOT", "Client networking bootstrap is now active.")

func _apply_window_title_from_config() -> void:
	if DisplayServer.get_name() == "headless":
		return

	var window_title: String = RuntimeConfig.get_string("window", "title", "")
	if window_title.is_empty():
		return

	var root_window: Window = get_window()
	if root_window != null:
		root_window.title = window_title

func _instantiate_client_world() -> void:
	if _client_world_instance != null:
		return

	var client_world_scene_path: String = RuntimeConfig.get_string("client_world", "scene_path", "")
	if client_world_scene_path.is_empty():
		push_error("ClientBootstrap requires [client_world] scene_path in the runtime config.")
		return

	if not ResourceLoader.exists(client_world_scene_path):
		push_error("ClientBootstrap could not find the client world scene at '%s'." % client_world_scene_path)
		return

	var client_world_scene: PackedScene = load(client_world_scene_path) as PackedScene
	if client_world_scene == null:
		push_error("ClientBootstrap could not load the client world scene at '%s'." % client_world_scene_path)
		return

	_client_world_instance = client_world_scene.instantiate()
	add_child(_client_world_instance)
	LogService.info("BOOT", "Client world scene instantiated: %s" % client_world_scene_path)
