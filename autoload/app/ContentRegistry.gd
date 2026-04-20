extends Node

var _runtime_config = null
var _content_by_id: Dictionary = {}
var _content_path_by_id: Dictionary = {}
var _warnings: PackedStringArray = []
var _manifest_hash: String = ""
var _registered_resource_paths_sorted: PackedStringArray = []

func initialize(runtime_config) -> void:
	_runtime_config = runtime_config
	reload_all_content()

func reload_all_content() -> void:
	_content_by_id.clear()
	_content_path_by_id.clear()
	_warnings.clear()
	_manifest_hash = ""
	_registered_resource_paths_sorted.clear()

	if _runtime_config == null:
		return

	var directory_section: Dictionary = _runtime_config.get_section_copy("content_directories")
	var directory_keys: Array = directory_section.keys()
	directory_keys.sort()

	for directory_key_variant in directory_keys:
		var directory_key: String = str(directory_key_variant)
		var directory_path: String = str(directory_section[directory_key_variant])
		_scan_directory_for_resources(directory_key, directory_path)

	_registered_resource_paths_sorted.sort()
	_manifest_hash = _build_manifest_hash_from_resource_paths(_registered_resource_paths_sorted)

	LogService.info("CONTENT", "Loaded %d content resource(s). Manifest hash: %s" % [
		_content_by_id.size(),
		_manifest_hash,
	])

	for warning_message in _warnings:
		LogService.warn("CONTENT", warning_message)

func has_content(content_id: StringName) -> bool:
	return _content_by_id.has(content_id)

func get_content(content_id: StringName) -> Resource:
	if not _content_by_id.has(content_id):
		return null
	return _content_by_id[content_id]

func get_content_path(content_id: StringName) -> String:
	if not _content_path_by_id.has(content_id):
		return ""
	return str(_content_path_by_id[content_id])

func get_all_content_ids() -> Array[StringName]:
	var content_ids: Array[StringName] = []
	for content_id_variant in _content_by_id.keys():
		content_ids.append(content_id_variant)
	return content_ids

func get_warning_list_copy() -> PackedStringArray:
	return _warnings.duplicate()

func get_manifest_hash() -> String:
	return _manifest_hash

func get_registered_resource_paths_copy() -> PackedStringArray:
	return _registered_resource_paths_sorted.duplicate()

func _scan_directory_for_resources(directory_label: String, directory_path: String) -> void:
	if not DirAccess.dir_exists_absolute(directory_path):
		_warnings.append("Content directory '%s' does not exist: %s" % [directory_label, directory_path])
		return

	var resource_paths: PackedStringArray = []
	_collect_resource_paths_recursive(directory_path, resource_paths)

	for resource_path in resource_paths:
		var loaded_resource: Resource = load(resource_path)
		if loaded_resource == null:
			_warnings.append("Could not load resource at path: %s" % resource_path)
			continue

		_register_resource(resource_path, loaded_resource)

func _collect_resource_paths_recursive(directory_path: String, resource_paths: PackedStringArray) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		_warnings.append("Could not open directory: %s" % directory_path)
		return

	directory.list_dir_begin()
	var next_name: String = directory.get_next()

	while next_name != "":
		if next_name.begins_with("."):
			next_name = directory.get_next()
			continue

		var next_path: String = directory_path.path_join(next_name)

		if directory.current_is_dir():
			_collect_resource_paths_recursive(next_path, resource_paths)
		else:
			var extension: String = next_name.get_extension().to_lower()
			if extension == "tres" or extension == "res":
				resource_paths.append(next_path)

		next_name = directory.get_next()

	directory.list_dir_end()

func _register_resource(resource_path: String, loaded_resource: Resource) -> void:
	# First-pass registry: require a stable exported "id".
	# Later we will upgrade this to typed definition validation.
	var id_value: Variant = loaded_resource.get("id")

	if id_value == null:
		_warnings.append("Resource has no exported 'id' property and was skipped: %s" % resource_path)
		return

	var content_id_text: String = str(id_value).strip_edges()
	if content_id_text == "":
		_warnings.append("Resource has an empty 'id' property and was skipped: %s" % resource_path)
		return

	var content_id: StringName = StringName(content_id_text)

	if _content_by_id.has(content_id):
		var existing_path: String = str(_content_path_by_id[content_id])
		_warnings.append("Duplicate content id '%s' found at '%s' and '%s'." % [
			String(content_id),
			existing_path,
			resource_path,
		])
		return

	_content_by_id[content_id] = loaded_resource
	_content_path_by_id[content_id] = resource_path
	_registered_resource_paths_sorted.append(resource_path)

func _build_manifest_hash_from_resource_paths(resource_paths: PackedStringArray) -> String:
	var hashing_context: HashingContext = HashingContext.new()
	var start_error: Error = hashing_context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		_warnings.append("Could not start SHA-256 hashing context for content manifest.")
		return ""

	for resource_path in resource_paths:
		hashing_context.update(resource_path.to_utf8_buffer())

		var resource_bytes: PackedByteArray = FileAccess.get_file_as_bytes(resource_path)
		if resource_bytes.is_empty() and not FileAccess.file_exists(resource_path):
			_warnings.append("Could not read resource bytes for content manifest: %s" % resource_path)
			continue

		hashing_context.update(resource_bytes)

	return hashing_context.finish().hex_encode()
