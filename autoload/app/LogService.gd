extends Node

enum LogLevel {
	DEBUG,
	INFO,
	WARN,
	ERROR,
}

var _minimum_log_level: LogLevel = LogLevel.INFO

func initialize_from_runtime_config(runtime_config) -> void:
	var configured_level: String = runtime_config.get_string("logging", "level", "info").to_lower()
	_minimum_log_level = _string_to_log_level(configured_level)
	info("CONFIG", "Log level initialized as '%s'." % _log_level_to_string(_minimum_log_level))

func debug(channel_name: String, message: String) -> void:
	_write(LogLevel.DEBUG, channel_name, message)

func info(channel_name: String, message: String) -> void:
	_write(LogLevel.INFO, channel_name, message)

func warn(channel_name: String, message: String) -> void:
	_write(LogLevel.WARN, channel_name, message)

func error(channel_name: String, message: String) -> void:
	_write(LogLevel.ERROR, channel_name, message)

func _write(log_level: LogLevel, channel_name: String, message: String) -> void:
	if log_level < _minimum_log_level:
		return

	var timestamp: String = Time.get_datetime_string_from_system(false, true)
	var formatted_message: String = "[%s] [%s] [%s] %s" % [
		timestamp,
		_log_level_to_string(log_level),
		channel_name,
		message,
	]

	match log_level:
		LogLevel.ERROR:
			push_error(formatted_message)
		LogLevel.WARN:
			push_warning(formatted_message)
		_:
			print(formatted_message)

func _string_to_log_level(level_name: String) -> LogLevel:
	match level_name:
		"debug":
			return LogLevel.DEBUG
		"info":
			return LogLevel.INFO
		"warn":
			return LogLevel.WARN
		"warning":
			return LogLevel.WARN
		"error":
			return LogLevel.ERROR
	return LogLevel.INFO

func _log_level_to_string(log_level: LogLevel) -> String:
	match log_level:
		LogLevel.DEBUG:
			return "DEBUG"
		LogLevel.INFO:
			return "INFO"
		LogLevel.WARN:
			return "WARN"
		LogLevel.ERROR:
			return "ERROR"
	return "INFO"
