extends CanvasLayer
class_name LoadingProgressOverlay

var _root_control: Control = null
var _background_rect: ColorRect = null
var _title_label: Label = null
var _detail_label: Label = null
var _progress_bar: ProgressBar = null
var _percent_label: Label = null


func _ready() -> void:
	layer = RuntimeConfig.get_int("loading_progress_ui", "canvas_layer", 50)
	_build_ui()
	hide_overlay()


func show_indeterminate(title_text: String, detail_text: String = "") -> void:
	if not RuntimeConfig.get_bool("loading_progress_ui", "enabled", true):
		return

	_ensure_ui_ready()

	_title_label.text = title_text
	_detail_label.text = detail_text
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_percent_label.text = "Waiting..."

	visible = true


func show_progress(title_text: String, detail_text: String, current_value: int, max_value: int) -> void:
	if not RuntimeConfig.get_bool("loading_progress_ui", "enabled", true):
		return

	_ensure_ui_ready()

	var safe_max_value: int = max(max_value, 1)
	var safe_current_value: int = clamp(current_value, 0, safe_max_value)
	var progress_percent: float = (float(safe_current_value) / float(safe_max_value)) * 100.0

	_title_label.text = title_text
	_detail_label.text = detail_text
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = float(safe_max_value)
	_progress_bar.value = float(safe_current_value)
	_percent_label.text = "%s / %s  ·  %s%%" % [
		safe_current_value,
		safe_max_value,
		int(round(progress_percent))
	]

	visible = true


func hide_overlay() -> void:
	visible = false


func _ensure_ui_ready() -> void:
	if _root_control == null:
		_build_ui()


func _build_ui() -> void:
	if _root_control != null:
		return

	_root_control = Control.new()
	_root_control.name = "LoadingProgressRoot"
	_root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root_control)

	_background_rect = ColorRect.new()
	_background_rect.name = "BackgroundDim"
	_background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background_rect.color = RuntimeConfig.get_color(
		"loading_progress_ui",
		"overlay_color",
		Color(0.0, 0.0, 0.0, 0.35)
	)
	_background_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_control.add_child(_background_rect)

	var center_container: CenterContainer = CenterContainer.new()
	center_container.name = "CenterContainer"
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_control.add_child(center_container)

	var panel_container: PanelContainer = PanelContainer.new()
	panel_container.name = "Panel"
	panel_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_container.custom_minimum_size = Vector2(
		max(RuntimeConfig.get_float("loading_progress_ui", "minimum_panel_width", 420.0), 240.0),
		0.0
	)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = RuntimeConfig.get_color(
		"loading_progress_ui",
		"panel_color",
		Color(0.06, 0.08, 0.12, 0.92)
	)
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	panel_style.set_content_margin(SIDE_LEFT, 24.0)
	panel_style.set_content_margin(SIDE_RIGHT, 24.0)
	panel_style.set_content_margin(SIDE_TOP, 20.0)
	panel_style.set_content_margin(SIDE_BOTTOM, 20.0)
	panel_container.add_theme_stylebox_override("panel", panel_style)

	center_container.add_child(panel_container)

	var vertical_container: VBoxContainer = VBoxContainer.new()
	vertical_container.name = "Content"
	vertical_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vertical_container.add_theme_constant_override("separation", 10)
	panel_container.add_child(vertical_container)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.text = "Loading"
	_title_label.add_theme_color_override(
		"font_color",
		RuntimeConfig.get_color("loading_progress_ui", "title_text_color", Color(0.95, 0.97, 1.0, 1.0))
	)
	_title_label.add_theme_font_size_override(
		"font_size",
		max(RuntimeConfig.get_int("loading_progress_ui", "title_font_size", 20), 8)
	)
	vertical_container.add_child(_title_label)

	_detail_label = Label.new()
	_detail_label.name = "Detail"
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.text = ""
	_detail_label.add_theme_color_override(
		"font_color",
		RuntimeConfig.get_color("loading_progress_ui", "detail_text_color", Color(0.78, 0.84, 0.92, 1.0))
	)
	_detail_label.add_theme_font_size_override(
		"font_size",
		max(RuntimeConfig.get_int("loading_progress_ui", "detail_font_size", 14), 8)
	)
	vertical_container.add_child(_detail_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.name = "ProgressBar"
	_progress_bar.custom_minimum_size = Vector2(0.0, 18.0)
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	vertical_container.add_child(_progress_bar)

	_percent_label = Label.new()
	_percent_label.name = "Percent"
	_percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_percent_label.text = ""
	_percent_label.add_theme_color_override(
		"font_color",
		RuntimeConfig.get_color("loading_progress_ui", "detail_text_color", Color(0.78, 0.84, 0.92, 1.0))
	)
	_percent_label.add_theme_font_size_override(
		"font_size",
		max(RuntimeConfig.get_int("loading_progress_ui", "percent_font_size", 13), 8)
	)
	vertical_container.add_child(_percent_label)
