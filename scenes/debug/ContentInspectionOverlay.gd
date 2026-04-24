extends CanvasLayer

const PANEL_WIDTH: float = 460.0
const PANEL_HEIGHT: float = 320.0
const PANEL_MARGIN: float = 12.0
const PANEL_LAYER: int = 100

var _panel: PanelContainer = null
var _content_label: RichTextLabel = null

func _ready() -> void:
	layer = PANEL_LAYER
	_build_ui()
	refresh_overlay()

func refresh_overlay() -> void:
	if _content_label == null:
		return

	_content_label.clear()
	_content_label.append_text(_build_summary_text())

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.position = Vector2(PANEL_MARGIN, PANEL_MARGIN)
	_panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var margin_container: MarginContainer = MarginContainer.new()
	margin_container.name = "MarginContainer"
	margin_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin_container.add_theme_constant_override("margin_left", 10)
	margin_container.add_theme_constant_override("margin_top", 10)
	margin_container.add_theme_constant_override("margin_right", 10)
	margin_container.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin_container)

	var content_container: VBoxContainer = VBoxContainer.new()
	content_container.name = "ContentContainer"
	content_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin_container.add_child(content_container)

	var title_label: Label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "Content Inspection Overlay"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_container.add_child(title_label)

	_content_label = RichTextLabel.new()
	_content_label.name = "ContentLabel"
	_content_label.fit_content = true
	_content_label.scroll_active = true
	_content_label.selection_enabled = false
	_content_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_label.custom_minimum_size = Vector2(PANEL_WIDTH - 40.0, PANEL_HEIGHT - 60.0)
	content_container.add_child(_content_label)

func _build_summary_text() -> String:
	var lines: Array[String] = []

	var registered_resource_paths: PackedStringArray = ContentRegistry.get_registered_resource_paths_copy()
	var warning_list: PackedStringArray = ContentRegistry.get_warning_list_copy()
	var map_preset_ids: Array[String] = _build_map_preset_id_list()
	var tile_family_ids: Array[String] = _build_tile_family_id_list()
	var tile_variant_ids: Array[String] = _build_tile_variant_id_list()
	var tile_behavior_ids: Array[String] = _build_tile_behavior_id_list()
	var tile_behavior_links: Array[String] = _build_tile_behavior_link_list()
	var role_ids: Array[String] = _build_role_id_list()
	var role_summaries: Array[String] = _build_role_summary_list()

	lines.append("runtime_mode: %s" % String(RuntimeConfig.get_runtime_mode_name()))
	lines.append("config_path: %s" % RuntimeConfig.resolved_config_path)
	lines.append("bootstrap_scene: %s" % RuntimeConfig.get_bootstrap_scene_path())
	lines.append("default_map_preset_id: %s" % RuntimeConfig.get_string("match", "default_map_preset_id", ""))
	lines.append("manifest_hash: %s" % ContentRegistry.get_manifest_hash())
	lines.append("registered_resource_count: %d" % registered_resource_paths.size())
	lines.append("")

	lines.append("map_presets (%d): %s" % [map_preset_ids.size(), _format_string_list(map_preset_ids)])
	lines.append("tile_families (%d): %s" % [tile_family_ids.size(), _format_string_list(tile_family_ids)])
	lines.append("tile_variants (%d): %s" % [tile_variant_ids.size(), _format_string_list(tile_variant_ids)])
	lines.append("tile_behaviors (%d): %s" % [tile_behavior_ids.size(), _format_string_list(tile_behavior_ids)])

	if tile_behavior_links.is_empty():
		lines.append("tile_behavior_links: none")
	else:
		lines.append("tile_behavior_links (%d):" % tile_behavior_links.size())
		for tile_behavior_link in tile_behavior_links:
			lines.append("- %s" % tile_behavior_link)

	lines.append("roles (%d): %s" % [role_ids.size(), _format_string_list(role_ids)])

	if role_summaries.is_empty():
		lines.append("role_details: none")
	else:
		lines.append("role_details (%d):" % role_summaries.size())
		for role_summary in role_summaries:
			lines.append("- %s" % role_summary)

	lines.append("")

	lines.append("warnings (%d):" % warning_list.size())
	if warning_list.is_empty():
		lines.append("- none")
	else:
		for warning_message in warning_list:
			lines.append("- %s" % warning_message)

	return _join_lines(lines)

func _build_map_preset_id_list() -> Array[String]:
	var map_preset_ids: Array[String] = []

	for content_id in ContentRegistry.get_all_content_ids():
		var content_def: Resource = ContentRegistry.get_content(content_id)
		if content_def is MapPresetDef:
			map_preset_ids.append(String(content_id))

	map_preset_ids.sort()
	return map_preset_ids

func _build_tile_family_id_list() -> Array[String]:
	var tile_family_ids: Array[String] = []

	for tile_family_def in BoardTileContentCatalog.build_family_list():
		if tile_family_def != null:
			tile_family_ids.append(String(tile_family_def.id))

	tile_family_ids.sort()
	return tile_family_ids

func _build_tile_variant_id_list() -> Array[String]:
	var tile_variant_ids: Array[String] = []

	for tile_variant_def in BoardTileContentCatalog.build_variant_list():
		if tile_variant_def != null:
			tile_variant_ids.append(String(tile_variant_def.id))

	tile_variant_ids.sort()
	return tile_variant_ids

func _build_tile_behavior_id_list() -> Array[String]:
	var tile_behavior_ids: Array[String] = []

	for tile_behavior_def in BoardTileContentCatalog.build_behavior_list():
		if tile_behavior_def != null:
			tile_behavior_ids.append(String(tile_behavior_def.id))

	tile_behavior_ids.sort()
	return tile_behavior_ids

func _build_tile_behavior_link_list() -> Array[String]:
	var tile_behavior_links: Array[String] = []

	for tile_variant_def in BoardTileContentCatalog.build_variant_list():
		if tile_variant_def == null:
			continue

		tile_behavior_links.append(
			"%s => %s" % [
				String(tile_variant_def.id),
				String(tile_variant_def.behavior_id)
			]
		)

	tile_behavior_links.sort()
	return tile_behavior_links

func _build_role_id_list() -> Array[String]:
	var role_ids: Array[String] = []

	for role_def in RoleContentCatalog.build_sorted_role_list():
		if role_def != null:
			role_ids.append(String(role_def.id))

	return role_ids
	
func _build_role_summary_list() -> Array[String]:
	var role_summaries: Array[String] = []

	for role_def in RoleContentCatalog.build_sorted_role_list():
		if role_def == null:
			continue

		var tag_list: Array[String] = []
		for tag_value in role_def.tags:
			tag_list.append(String(tag_value))

		var tag_text: String = _format_string_list(tag_list)
		role_summaries.append("%s = %s [tags: %s]" % [String(role_def.id), role_def.display_name, tag_text])

	return role_summaries

func _format_string_list(values: Array[String]) -> String:
	if values.is_empty():
		return "none"

	var formatted_text: String = values[0]
	var value_index: int = 1
	while value_index < values.size():
		formatted_text += ", %s" % values[value_index]
		value_index += 1

	return formatted_text

func _join_lines(lines: Array[String]) -> String:
	if lines.is_empty():
		return ""

	var joined_text: String = lines[0]
	var line_index: int = 1
	while line_index < lines.size():
		joined_text += "\n%s" % lines[line_index]
		line_index += 1

	return joined_text
