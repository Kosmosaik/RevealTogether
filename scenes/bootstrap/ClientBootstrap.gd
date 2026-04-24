extends Node

const CONTENT_INSPECTION_OVERLAY_SCRIPT := preload("res://scenes/debug/ContentInspectionOverlay.gd")
const CONTENT_OVERLAY_TOGGLE_ACTION := "toggle_content_overlay"
const CONTENT_OVERLAY_TOGGLE_KEY_NAME := "F3"

var _client_world_instance: Node = null
var _content_inspection_overlay: CanvasLayer = null

func _ready() -> void:
	var boot_message: String = RuntimeConfig.get_string("client", "boot_message", "Client bootstrap active.")
	LogService.info("BOOT", boot_message)

	_apply_window_title_from_config()

	var match_session_service = AppBootstrap.ensure_match_session_service()
	if match_session_service == null:
		push_error("ClientBootstrap could not acquire MatchSessionService.")
		return

	_ensure_content_overlay_toggle_action()
	_instantiate_client_world()
	_apply_configured_content_inspection_overlay_state()

	match_session_service.start_client_mode()
	LogService.info("BOOT", "Client networking bootstrap is now active.")

func _unhandled_input(_event: InputEvent) -> void:
	if not Input.is_action_just_pressed(CONTENT_OVERLAY_TOGGLE_ACTION):
		return

	_toggle_content_inspection_overlay()
	get_viewport().set_input_as_handled()

func _apply_window_title_from_config() -> void:
	if DisplayServer.get_name() == "headless":
		return

	var window_title: String = RuntimeConfig.get_string("window", "title", "")
	if window_title.is_empty():
		return

	var root_window: Window = get_window()
	if root_window != null:
		root_window.title = window_title

func _ensure_content_overlay_toggle_action() -> void:
	if InputMap.has_action(CONTENT_OVERLAY_TOGGLE_ACTION):
		return

	InputMap.add_action(CONTENT_OVERLAY_TOGGLE_ACTION)

	var toggle_key_event: InputEventKey = InputEventKey.new()
	toggle_key_event.keycode = OS.find_keycode_from_string(CONTENT_OVERLAY_TOGGLE_KEY_NAME)

	if toggle_key_event.keycode == 0:
		LogService.warn("BOOT", "Could not resolve keycode for content overlay toggle key '%s'." % CONTENT_OVERLAY_TOGGLE_KEY_NAME)
		return

	InputMap.action_add_event(CONTENT_OVERLAY_TOGGLE_ACTION, toggle_key_event)
	LogService.info(
		"BOOT",
		"Registered runtime input action '%s' on key '%s'." % [
			CONTENT_OVERLAY_TOGGLE_ACTION,
			CONTENT_OVERLAY_TOGGLE_KEY_NAME
		]
	)

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

func _apply_configured_content_inspection_overlay_state() -> void:
	var content_overlay_enabled: bool = RuntimeConfig.get_bool("debug", "content_overlay_enabled", false)
	if not content_overlay_enabled:
		return

	_ensure_content_inspection_overlay()
	if _content_inspection_overlay == null:
		return

	_content_inspection_overlay.visible = true
	LogService.info("BOOT", "Content inspection overlay shown from runtime config.")

func _toggle_content_inspection_overlay() -> void:
	_ensure_content_inspection_overlay()
	if _content_inspection_overlay == null:
		LogService.warn("BOOT", "Content inspection overlay could not be toggled because instantiation failed.")
		return

	_content_inspection_overlay.visible = not _content_inspection_overlay.visible
	LogService.info(
		"BOOT",
		"Content inspection overlay %s." % ("shown" if _content_inspection_overlay.visible else "hidden")
	)

func _ensure_content_inspection_overlay() -> void:
	if _content_inspection_overlay != null:
		return

	var overlay_instance: CanvasLayer = CONTENT_INSPECTION_OVERLAY_SCRIPT.new()
	if overlay_instance == null:
		push_error("ClientBootstrap could not instantiate ContentInspectionOverlay.")
		return

	overlay_instance.visible = false
	_content_inspection_overlay = overlay_instance
	add_child(_content_inspection_overlay)
	LogService.info("BOOT", "Content inspection overlay instantiated.")
