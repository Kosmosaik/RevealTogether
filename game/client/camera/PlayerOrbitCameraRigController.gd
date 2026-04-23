extends RefCounted

var _camera_rig: Node3D = null
var _camera: Camera3D = null

var _yaw_radians: float = 0.0
var _pitch_radians: float = 0.0
var _pitch_min_radians: float = 0.0
var _pitch_max_radians: float = 0.0

var _current_zoom_distance: float = 0.0
var _target_zoom_distance: float = 0.0
var _zoom_min_distance: float = 0.0
var _zoom_max_distance: float = 0.0
var _zoom_step: float = 0.0

var _look_at_height: float = 0.0
var _follow_lerp_speed: float = 0.0
var _rotation_drag_sensitivity: float = 0.0
var _pitch_drag_sensitivity: float = 0.0

var _is_rotating_camera: bool = false


func configure(camera_rig: Node3D, camera: Camera3D) -> void:
	_camera_rig = camera_rig
	_camera = camera

	var camera_height: float = max(
		RuntimeConfig.get_float(
			"camera_rig",
			"camera_height",
			RuntimeConfig.get_float("client_world", "camera_height", 26.0)
		),
		6.0
	)
	var camera_distance: float = max(
		RuntimeConfig.get_float(
			"camera_rig",
			"camera_distance",
			RuntimeConfig.get_float("client_world", "camera_distance", 18.0)
		),
		4.0
	)

	var initial_zoom_distance: float = sqrt((camera_height * camera_height) + (camera_distance * camera_distance))
	if initial_zoom_distance <= 0.0:
		initial_zoom_distance = 1.0

	var initial_pitch_radians: float = atan2(camera_height, camera_distance)

	_current_zoom_distance = initial_zoom_distance
	_target_zoom_distance = initial_zoom_distance

	_zoom_min_distance = max(
		RuntimeConfig.get_float("camera_rig", "zoom_min_distance", initial_zoom_distance * 0.7),
		1.0
	)
	_zoom_max_distance = max(
		RuntimeConfig.get_float("camera_rig", "zoom_max_distance", initial_zoom_distance * 1.2),
		_zoom_min_distance
	)
	_zoom_step = max(
		RuntimeConfig.get_float("camera_rig", "zoom_step", 1.0),
		0.05
	)

	_yaw_radians = deg_to_rad(RuntimeConfig.get_float("camera_rig", "yaw_degrees", 35.0))
	_pitch_min_radians = deg_to_rad(
		RuntimeConfig.get_float("camera_rig", "pitch_min_degrees", rad_to_deg(initial_pitch_radians))
	)
	_pitch_max_radians = deg_to_rad(
		RuntimeConfig.get_float("camera_rig", "pitch_max_degrees", 89.0)
	)
	_pitch_radians = clamp(initial_pitch_radians, _pitch_min_radians, _pitch_max_radians)

	_rotation_drag_sensitivity = max(
		RuntimeConfig.get_float("camera_rig", "rotation_drag_sensitivity", 0.01),
		0.0001
	)
	_pitch_drag_sensitivity = max(
		RuntimeConfig.get_float("camera_rig", "pitch_drag_sensitivity", 0.01),
		0.0001
	)

	_look_at_height = RuntimeConfig.get_float(
		"camera_rig",
		"look_at_height",
		RuntimeConfig.get_float("client_world", "camera_target_height", 0.0)
	)
	_follow_lerp_speed = max(
		RuntimeConfig.get_float(
			"camera_rig",
			"follow_lerp_speed",
			RuntimeConfig.get_float("client_world", "camera_follow_lerp_rate", 8.0)
		),
		0.1
	)

	_camera.near = max(RuntimeConfig.get_float("camera_rig", "camera_near", 0.05), 0.01)
	_camera.far = max(
		RuntimeConfig.get_float("camera_rig", "camera_far", 4000.0),
		_camera.near + 1.0
	)
	_camera.make_current()

	_clamp_zoom_target()
	_clamp_pitch()
	_current_zoom_distance = _target_zoom_distance
	_apply_camera_transform()


func handle_input(event: InputEvent) -> bool:
	var mouse_button_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button_event != null:
		if mouse_button_event.button_index == MOUSE_BUTTON_RIGHT:
			_is_rotating_camera = mouse_button_event.pressed
			return true

		if mouse_button_event.pressed and not mouse_button_event.is_echo():
			if mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_target_zoom_distance -= _zoom_step
				_clamp_zoom_target()
				return true

			if mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_target_zoom_distance += _zoom_step
				_clamp_zoom_target()
				return true

	var mouse_motion_event: InputEventMouseMotion = event as InputEventMouseMotion
	if mouse_motion_event != null and _is_rotating_camera:
		_yaw_radians -= mouse_motion_event.relative.x * _rotation_drag_sensitivity
		_pitch_radians += mouse_motion_event.relative.y * _pitch_drag_sensitivity
		_clamp_pitch()
		_apply_camera_transform()
		return true

	return false


func update_follow(target_global_position: Vector3, delta: float) -> void:
	if _camera_rig == null:
		return

	if _camera == null:
		return

	var desired_rig_position: Vector3 = target_global_position + Vector3(0.0, _look_at_height, 0.0)
	var lerp_weight: float = clamp(delta * _follow_lerp_speed, 0.0, 1.0)

	_camera_rig.global_position = _camera_rig.global_position.lerp(desired_rig_position, lerp_weight)
	_current_zoom_distance = lerpf(_current_zoom_distance, _target_zoom_distance, lerp_weight)

	_apply_camera_transform()

func get_planar_right_vector() -> Vector3:
	var planar_right: Vector3 = Vector3.RIGHT.rotated(Vector3.UP, _yaw_radians)
	planar_right.y = 0.0

	if planar_right.length_squared() <= 0.0001:
		return Vector3.RIGHT

	return planar_right.normalized()

func get_planar_forward_vector() -> Vector3:
	var planar_forward: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, _yaw_radians)
	planar_forward.y = 0.0

	if planar_forward.length_squared() <= 0.0001:
		return Vector3.FORWARD

	return planar_forward.normalized()

func _clamp_zoom_target() -> void:
	_target_zoom_distance = clamp(_target_zoom_distance, _zoom_min_distance, _zoom_max_distance)


func _clamp_pitch() -> void:
	_pitch_radians = clamp(_pitch_radians, _pitch_min_radians, _pitch_max_radians)


func _apply_camera_transform() -> void:
	if _camera_rig == null:
		return

	if _camera == null:
		return

	var vertical_distance: float = sin(_pitch_radians) * _current_zoom_distance
	var horizontal_distance: float = cos(_pitch_radians) * _current_zoom_distance
	var local_camera_offset: Vector3 = Vector3(0.0, vertical_distance, horizontal_distance)
	local_camera_offset = local_camera_offset.rotated(Vector3.UP, _yaw_radians)

	_camera.position = local_camera_offset
	_camera.look_at(_camera_rig.global_position, Vector3.UP)
