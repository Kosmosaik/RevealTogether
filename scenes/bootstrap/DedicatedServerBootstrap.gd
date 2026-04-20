extends Node

func _ready() -> void:
	var boot_message: String = RuntimeConfig.get_string("server", "boot_message", "Dedicated server bootstrap active.")
	LogService.info("BOOT", boot_message)

	var match_session_service = AppBootstrap.ensure_match_session_service()
	if match_session_service == null:
		LogService.error("BOOT", "Server bootstrap could not create MatchSessionService.")
		return

	match_session_service.start_server_mode()
	LogService.info("BOOT", "Dedicated server networking bootstrap is now active.")
