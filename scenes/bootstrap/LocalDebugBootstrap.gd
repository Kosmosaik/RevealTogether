extends Node

func _ready() -> void:
	var boot_message: String = RuntimeConfig.get_string("local_debug", "boot_message", "Local debug bootstrap active.")
	LogService.info("BOOT", boot_message)
	LogService.info("BOOT", "Local debug mode remains a separate step. Use --mode=server and --mode=client for this dedicated-server milestone.")
