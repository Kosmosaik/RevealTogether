extends Node

# Small runtime-mode enum for the bootstrap layer only.
enum RuntimeMode {
	CLIENT,
	DEDICATED_SERVER,
	LOCAL_DEBUG,
}

const DEFAULT_APP_CONFIG_PATH: String = "res://config/defaults/app.cfg"
const DEFAULT_CLIENT_CONFIG_PATH: String = "res://config/defaults/client.cfg"
const DEFAULT_SERVER_CONFIG_PATH: String = "res://config/defaults/server.cfg"
const DEFAULT_LOCAL_DEBUG_CONFIG_PATH: String = "res://config/defaults/local_debug.cfg"

const ARG_MODE: String = "mode"
const ARG_CONFIG: String = "config"
const ARG_SERVER: String = "server"
const ARG_LOCAL_DEBUG: String = "local-debug"

var current_runtime_mode: RuntimeMode = RuntimeMode.CLIENT
var current_runtime_mode_name: StringName = &"client"
var resolved_config_path: String = DEFAULT_CLIENT_CONFIG_PATH

var _user_arguments: Dictionary = {}
var _merged_config: Dictionary = {}

func initialize() -> void:
	# Parse user args first so they can influence mode and custom config.
	_user_arguments = _parse_user_arguments(OS.get_cmdline_user_args())

	current_runtime_mode = _resolve_runtime_mode()
	current_runtime_mode_name = _runtime_mode_to_name(current_runtime_mode)

	_merged_config.clear()

	# Load shared app defaults first.
	_load_config_file(DEFAULT_APP_CONFIG_PATH)

	# Then load the mode-specific defaults.
	var default_mode_config_path: String = _get_default_mode_config_path(current_runtime_mode)
	_load_config_file(default_mode_config_path)
	resolved_config_path = default_mode_config_path

	# Finally allow one explicit config override.
	var custom_config_path: String = get_user_argument_string(ARG_CONFIG, "")
	if custom_config_path != "":
		_load_config_file(custom_config_path)
		resolved_config_path = custom_config_path

func get_runtime_mode_name() -> StringName:
	return current_runtime_mode_name

func get_bootstrap_scene_path() -> String:
	match current_runtime_mode:
		RuntimeMode.CLIENT:
			return get_string("bootstrap", "client_scene", "")
		RuntimeMode.DEDICATED_SERVER:
			return get_string("bootstrap", "server_scene", "")
		RuntimeMode.LOCAL_DEBUG:
			return get_string("bootstrap", "local_debug_scene", "")
	return ""

func has_section(section_name: String) -> bool:
	return _merged_config.has(section_name)

func get_section_copy(section_name: String) -> Dictionary:
	if not _merged_config.has(section_name):
		return {}
	return (_merged_config[section_name] as Dictionary).duplicate(true)

func get_string(section_name: String, key_name: String, default_value: String = "") -> String:
	if not _merged_config.has(section_name):
		return default_value

	var section_dictionary: Dictionary = _merged_config[section_name]
	if not section_dictionary.has(key_name):
		return default_value

	return str(section_dictionary[key_name])

func get_int(section_name: String, key_name: String, default_value: int = 0) -> int:
	if not _merged_config.has(section_name):
		return default_value

	var section_dictionary: Dictionary = _merged_config[section_name]
	if not section_dictionary.has(key_name):
		return default_value

	return int(section_dictionary[key_name])

func get_float(section_name: String, key_name: String, default_value: float = 0.0) -> float:
	if not _merged_config.has(section_name):
		return default_value

	var section_dictionary: Dictionary = _merged_config[section_name]
	if not section_dictionary.has(key_name):
		return default_value

	return float(section_dictionary[key_name])

func get_bool(section_name: String, key_name: String, default_value: bool = false) -> bool:
	if not _merged_config.has(section_name):
		return default_value

	var section_dictionary: Dictionary = _merged_config[section_name]
	if not section_dictionary.has(key_name):
		return default_value

	return _variant_to_bool(section_dictionary[key_name], default_value)

func get_user_argument_string(argument_name: String, default_value: String = "") -> String:
	if not _user_arguments.has(argument_name):
		return default_value
	return str(_user_arguments[argument_name])

func get_user_argument_bool(argument_name: String, default_value: bool = false) -> bool:
	if not _user_arguments.has(argument_name):
		return default_value
	return _variant_to_bool(_user_arguments[argument_name], default_value)

func get_user_argument_map_copy() -> Dictionary:
	return _user_arguments.duplicate(true)

func _resolve_runtime_mode() -> RuntimeMode:
	# Highest priority: explicit mode argument.
	var explicit_mode_name: String = get_user_argument_string(ARG_MODE, "").to_lower()
	if explicit_mode_name != "":
		return _runtime_mode_from_string(explicit_mode_name)

	# Explicit flags come next.
	if get_user_argument_bool(ARG_SERVER, false):
		return RuntimeMode.DEDICATED_SERVER

	if get_user_argument_bool(ARG_LOCAL_DEBUG, false):
		return RuntimeMode.LOCAL_DEBUG

	# Then feature/headless checks for real dedicated server runs.
	if OS.has_feature("dedicated_server"):
		return RuntimeMode.DEDICATED_SERVER

	if DisplayServer.get_name() == "headless":
		return RuntimeMode.DEDICATED_SERVER

	return RuntimeMode.CLIENT

func _get_default_mode_config_path(runtime_mode: RuntimeMode) -> String:
	match runtime_mode:
		RuntimeMode.CLIENT:
			return DEFAULT_CLIENT_CONFIG_PATH
		RuntimeMode.DEDICATED_SERVER:
			return DEFAULT_SERVER_CONFIG_PATH
		RuntimeMode.LOCAL_DEBUG:
			return DEFAULT_LOCAL_DEBUG_CONFIG_PATH
	return DEFAULT_CLIENT_CONFIG_PATH

func _runtime_mode_to_name(runtime_mode: RuntimeMode) -> StringName:
	match runtime_mode:
		RuntimeMode.CLIENT:
			return &"client"
		RuntimeMode.DEDICATED_SERVER:
			return &"dedicated_server"
		RuntimeMode.LOCAL_DEBUG:
			return &"local_debug"
	return &"client"

func _runtime_mode_from_string(mode_name: String) -> RuntimeMode:
	match mode_name:
		"client":
			return RuntimeMode.CLIENT
		"server":
			return RuntimeMode.DEDICATED_SERVER
		"dedicated_server":
			return RuntimeMode.DEDICATED_SERVER
		"local_debug":
			return RuntimeMode.LOCAL_DEBUG
	return RuntimeMode.CLIENT

func _load_config_file(config_path: String) -> void:
	if not FileAccess.file_exists(config_path):
		return

	var config_file: ConfigFile = ConfigFile.new()
	var load_result: Error = config_file.load(config_path)
	if load_result != OK:
		push_error("RuntimeConfig could not load config file: %s" % config_path)
		return

	for section_name_variant in config_file.get_sections():
		var section_name: String = str(section_name_variant)

		if not _merged_config.has(section_name):
			_merged_config[section_name] = {}

		var section_dictionary: Dictionary = _merged_config[section_name]

		for key_name_variant in config_file.get_section_keys(section_name):
			var key_name: String = str(key_name_variant)
			section_dictionary[key_name] = config_file.get_value(section_name, key_name)

func _parse_user_arguments(raw_arguments: PackedStringArray) -> Dictionary:
	var parsed_arguments: Dictionary = {}

	for raw_argument in raw_arguments:
		if not raw_argument.begins_with("--"):
			continue

		var cleaned_argument: String = raw_argument.trim_prefix("--")
		var equals_index: int = cleaned_argument.find("=")

		if equals_index == -1:
			parsed_arguments[cleaned_argument] = true
			continue

		var argument_name: String = cleaned_argument.substr(0, equals_index)
		var argument_value: String = cleaned_argument.substr(equals_index + 1)
		parsed_arguments[argument_name] = argument_value

	return parsed_arguments

func _variant_to_bool(value: Variant, default_value: bool = false) -> bool:
	if value is bool:
		return value

	var normalized_value: String = str(value).strip_edges().to_lower()
	match normalized_value:
		"1", "true", "yes", "on":
			return true
		"0", "false", "no", "off":
			return false

	return default_value
