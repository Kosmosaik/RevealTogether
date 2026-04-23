extends Node3D

const PlayerOrbitCameraRigControllerScript = preload("res://game/client/camera/PlayerOrbitCameraRigController.gd")
@onready var _world_environment: WorldEnvironment = $WorldEnvironment
@onready var _sun_light: DirectionalLight3D = $SunLight
@onready var _ground_body: StaticBody3D = $Ground
@onready var _ground_mesh_instance: MeshInstance3D = $Ground/GroundMesh
@onready var _ground_collision_shape: CollisionShape3D = $Ground/GroundCollisionShape
@onready var _player_replica_container: Node3D = $PlayerReplicas
@onready var _camera_rig: Node3D = $CameraRig
@onready var _camera: Camera3D = $CameraRig/Camera3D

var _match_session_service = null
var _player_avatar_scene: PackedScene = null
var _board_view_scene: PackedScene = null
var _board_view: BoardGridView3D = null
var _player_avatar_by_peer_id: Dictionary = {}
var _local_peer_id: int = 0
var _camera_controller: RefCounted = null

var _local_move_request_accumulator_sec: float = 0.0
var _local_last_submitted_action_state: StringName = NetProtocol.ACTION_STATE_IDLE

func _ready() -> void:
	_configure_environment()
	_configure_ground()
	_configure_camera()
	_configure_viewport_rendering()

	_board_view_scene = _load_board_view_scene()
	_instantiate_board_view()

	_player_avatar_scene = _load_player_avatar_scene()
	_match_session_service = AppBootstrap.ensure_match_session_service()
	_connect_match_session_signals()

func _process(delta: float) -> void:
	_update_local_player_movement(delta)
	_update_camera_follow(delta)
	
func _unhandled_input(event: InputEvent) -> void:
	if _camera_controller != null and _camera_controller.handle_input(event):
		return

	var mouse_button_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button_event == null:
		return
	if mouse_button_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not mouse_button_event.pressed:
		return
	if mouse_button_event.is_echo():
		return
	if _match_session_service == null:
		return
	if _board_view == null:
		return

	var hit_position_variant: Variant = _intersect_mouse_with_board_plane(mouse_button_event.position)
	if hit_position_variant == null:
		return

	var hit_position: Vector3 = hit_position_variant
	var tile_index: int = _board_view.get_tile_index_from_world_position(hit_position)
	if tile_index < 0:
		return

	_match_session_service.request_reveal_tile(tile_index)

func _configure_environment() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.07, 0.09, 0.11, 1.0)
	environment.ambient_light_color = Color(0.82, 0.85, 0.90, 1.0)
	environment.ambient_light_energy = max(
		RuntimeConfig.get_float("client_world", "ambient_light_energy", 1.0),
		0.0
	)
	_world_environment.environment = environment

	var sun_rotation_x_degrees: float = RuntimeConfig.get_float("client_world", "sun_rotation_x_degrees", -55.0)
	var sun_rotation_y_degrees: float = RuntimeConfig.get_float("client_world", "sun_rotation_y_degrees", 35.0)
	var sun_light_energy: float = max(
		RuntimeConfig.get_float("client_world", "sun_light_energy", 1.4),
		0.0
	)

	_sun_light.rotation_degrees = Vector3(sun_rotation_x_degrees, sun_rotation_y_degrees, 0.0)
	_sun_light.light_energy = sun_light_energy
	_sun_light.shadow_enabled = true

func _configure_ground(minimum_world_size: Vector2 = Vector2.ZERO) -> void:
	var default_ground_size: float = max(RuntimeConfig.get_float("client_world", "ground_size", 64.0), 8.0)
	var configured_ground_size_x: float = max(
		RuntimeConfig.get_float("client_world", "ground_size_x", default_ground_size),
		8.0
	)
	var configured_ground_size_z: float = max(
		RuntimeConfig.get_float("client_world", "ground_size_z", default_ground_size),
		8.0
	)

	var ground_size_x: float = max(configured_ground_size_x, minimum_world_size.x)
	var ground_size_z: float = max(configured_ground_size_z, minimum_world_size.y)
	var ground_height: float = max(RuntimeConfig.get_float("client_world", "ground_height", 0.5), 0.1)
	var ground_surface_clearance: float = max(
		RuntimeConfig.get_float("client_world", "ground_surface_clearance", 0.0),
		0.0
	)

	var ground_mesh: BoxMesh = BoxMesh.new()
	ground_mesh.size = Vector3(ground_size_x, ground_height, ground_size_z)
	_ground_mesh_instance.mesh = ground_mesh

	var ground_shape: BoxShape3D = BoxShape3D.new()
	ground_shape.size = Vector3(ground_size_x, ground_height, ground_size_z)
	_ground_collision_shape.shape = ground_shape

	var ground_material: StandardMaterial3D = StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.17, 0.22, 0.18, 1.0)
	ground_material.roughness = 1.0
	ground_material.metallic = 0.0
	_ground_mesh_instance.material_override = ground_material

	_ground_body.position = Vector3(0.0, -ground_surface_clearance - (ground_height * 0.5), 0.0)

func _configure_camera() -> void:
	if _camera_controller == null:
		_camera_controller = PlayerOrbitCameraRigControllerScript.new()

	_camera_rig.position = Vector3.ZERO
	_camera_controller.configure(_camera_rig, _camera)
	
func _configure_viewport_rendering() -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return

	var msaa_3d_setting: String = RuntimeConfig.get_string("rendering_3d", "msaa_3d", "disabled").to_lower()
	match msaa_3d_setting:
		"2x":
			viewport.msaa_3d = Viewport.MSAA_2X
		"4x":
			viewport.msaa_3d = Viewport.MSAA_4X
		"8x":
			viewport.msaa_3d = Viewport.MSAA_8X
		_:
			viewport.msaa_3d = Viewport.MSAA_DISABLED

	var screen_space_aa_setting: String = RuntimeConfig.get_string(
		"rendering_3d",
		"screen_space_aa",
		"disabled"
	).to_lower()
	match screen_space_aa_setting:
		"fxaa":
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		"smaa":
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
		_:
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED

	viewport.use_taa = RuntimeConfig.get_bool("rendering_3d", "use_taa", false)	

func _load_player_avatar_scene() -> PackedScene:
	var scene_path: String = RuntimeConfig.get_string(
		"client_world",
		"player_avatar_scene_path",
		"res://scenes/world/replicas/PlayerReplicaAvatar.tscn"
	)
	if not ResourceLoader.exists(scene_path):
		LogService.error("BOOT", "Player avatar scene is missing at '%s'." % scene_path)
		return null
	return load(scene_path) as PackedScene

func _load_board_view_scene() -> PackedScene:
	var scene_path: String = RuntimeConfig.get_string(
		"client_world",
		"board_view_scene_path",
		"res://scenes/world/board/BoardGridView3D.tscn"
	)
	if not ResourceLoader.exists(scene_path):
		LogService.error("BOOT", "Board view scene is missing at '%s'." % scene_path)
		return null
	return load(scene_path) as PackedScene

func _instantiate_board_view() -> void:
	if _board_view != null:
		return

	if _board_view_scene == null:
		return

	var board_view_instance: Node = _board_view_scene.instantiate()
	_board_view = board_view_instance as BoardGridView3D
	if _board_view == null:
		LogService.error("BOOT", "Board view scene failed to instantiate as BoardGridView3D.")
		return

	_board_view.name = "BoardView"
	add_child(_board_view)
	move_child(_board_view, _player_replica_container.get_index())

func _connect_match_session_signals() -> void:
	if not _match_session_service.joined_match.is_connected(_on_joined_match):
		_match_session_service.joined_match.connect(_on_joined_match)

	if not _match_session_service.player_spawned.is_connected(_on_player_spawned):
		_match_session_service.player_spawned.connect(_on_player_spawned)

	if not _match_session_service.player_despawned.is_connected(_on_player_despawned):
		_match_session_service.player_despawned.connect(_on_player_despawned)

	if not _match_session_service.player_transforms_replicated.is_connected(_on_player_transforms_replicated):
		_match_session_service.player_transforms_replicated.connect(_on_player_transforms_replicated)

	if not _match_session_service.board_delta_replicated.is_connected(_on_board_delta_replicated):
		_match_session_service.board_delta_replicated.connect(_on_board_delta_replicated)
		
func _on_joined_match(snapshot_payload: Dictionary) -> void:
	_local_peer_id = int(snapshot_payload.get("accepted_peer_id", 0))
	_reset_local_movement_state()

	var board_snapshot: Dictionary = snapshot_payload.get("board_snapshot", {})
	_apply_board_snapshot_to_world(board_snapshot)

	_clear_all_player_avatars()

	var player_snapshots: Array = snapshot_payload.get("players", [])
	for player_snapshot_variant in player_snapshots:
		var player_snapshot: Dictionary = player_snapshot_variant
		_upsert_player_avatar_from_snapshot(player_snapshot, true)

func _on_player_spawned(spawn_payload: Dictionary) -> void:
	var player_snapshot: Dictionary = spawn_payload.get("player", {})
	_upsert_player_avatar_from_snapshot(player_snapshot, true)

func _on_player_despawned(despawn_payload: Dictionary) -> void:
	var peer_id: int = int(despawn_payload.get("peer_id", 0))
	if peer_id <= 0:
		return

	if not _player_avatar_by_peer_id.has(peer_id):
		return

	var avatar_node = _player_avatar_by_peer_id[peer_id]
	_player_avatar_by_peer_id.erase(peer_id)
	avatar_node.queue_free()

func _on_player_transforms_replicated(replication_payload: Dictionary) -> void:
	var player_transform_list: Array = replication_payload.get("player_transforms", [])
	for player_transform_variant in player_transform_list:
		var player_transform: Dictionary = player_transform_variant
		var peer_id: int = int(player_transform.get("peer_id", 0))
		if peer_id <= 0:
			continue

		if not _player_avatar_by_peer_id.has(peer_id):
			var fallback_snapshot: Dictionary = _match_session_service.get_player_snapshot_by_peer_id_copy(peer_id)
			if not fallback_snapshot.is_empty():
				_upsert_player_avatar_from_snapshot(fallback_snapshot, true)

		if not _player_avatar_by_peer_id.has(peer_id):
			continue

		var avatar_node = _player_avatar_by_peer_id[peer_id]
		avatar_node.apply_player_snapshot(player_transform, false)

func _on_board_delta_replicated(replication_payload: Dictionary) -> void:
	if _board_view == null:
		return

	_board_view.apply_board_delta_payload(replication_payload)

func _apply_board_snapshot_to_world(board_snapshot: Dictionary) -> void:
	if _board_view == null:
		return

	_board_view.apply_board_snapshot(board_snapshot)

	var board_world_size: Vector2 = _board_view.get_board_world_size()
	if board_world_size == Vector2.ZERO:
		return

	var ground_margin: float = max(RuntimeConfig.get_float("board_view", "ground_margin", 8.0), 0.0)
	_configure_ground(board_world_size + Vector2(ground_margin, ground_margin))

	var board_summary: Dictionary = board_snapshot.get("summary", {})
	LogService.info(
		"WORLD",
		"Applied board snapshot: %sx%s tiles across %s chunk(s)." % [
			int(board_summary.get("board_width", 0)),
			int(board_summary.get("board_height", 0)),
			int(board_summary.get("chunk_count", 0))
		]
	)

func _upsert_player_avatar_from_snapshot(player_snapshot: Dictionary, snap_immediately: bool) -> void:
	var peer_id: int = int(player_snapshot.get("peer_id", 0))
	if peer_id <= 0:
		return

	var avatar_node = null
	if _player_avatar_by_peer_id.has(peer_id):
		avatar_node = _player_avatar_by_peer_id[peer_id]
	else:
		if _player_avatar_scene == null:
			return
		avatar_node = _player_avatar_scene.instantiate()
		avatar_node.name = "PlayerReplica_%s" % peer_id
		_player_replica_container.add_child(avatar_node)
		_player_avatar_by_peer_id[peer_id] = avatar_node

	var display_name: String = str(player_snapshot.get("player_display_name", "Player"))
	var is_local_player: bool = peer_id == _local_peer_id
	avatar_node.configure_identity(peer_id, display_name, is_local_player)
	avatar_node.apply_player_snapshot(player_snapshot, snap_immediately)

func _clear_all_player_avatars() -> void:
	for avatar_variant in _player_avatar_by_peer_id.values():
		var avatar_node = avatar_variant
		avatar_node.queue_free()
	_player_avatar_by_peer_id.clear()

func _intersect_mouse_with_board_plane(screen_position: Vector2) -> Variant:
	var ray_origin: Vector3 = _camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = _camera.project_ray_normal(screen_position)
	var board_plane: Plane = Plane(Vector3.UP, 0.0)
	return board_plane.intersects_ray(ray_origin, ray_direction)

func _update_local_player_movement(delta: float) -> void:
	if _match_session_service == null:
		return

	if _local_peer_id <= 0:
		return

	var avatar_node = _get_local_player_avatar()
	if avatar_node == null:
		return

	var move_input: Vector2 = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var has_move_input: bool = move_input.length_squared() > 0.0001

	if not has_move_input:
		if _local_last_submitted_action_state != NetProtocol.ACTION_STATE_MOVING:
			return

		_match_session_service.request_player_transform(
			avatar_node.global_position,
			avatar_node.rotation.y,
			NetProtocol.ACTION_STATE_IDLE,
			-1
		)
		_local_last_submitted_action_state = NetProtocol.ACTION_STATE_IDLE
		_local_move_request_accumulator_sec = 0.0
		return

	var planar_right: Vector3 = Vector3.RIGHT
	var planar_forward: Vector3 = Vector3.FORWARD

	if _camera_controller != null:
		planar_right = _camera_controller.get_planar_right_vector()
		planar_forward = _camera_controller.get_planar_forward_vector()

	var move_direction: Vector3 = (planar_right * move_input.x) + (planar_forward * move_input.y)
	if move_direction.length_squared() <= 0.0001:
		return
	move_direction = move_direction.normalized()

	var next_world_position: Vector3 = avatar_node.global_position + (
		move_direction * _get_move_speed_units_per_sec() * delta
	)
	next_world_position = _clamp_world_position_to_ground_bounds(next_world_position)
	next_world_position.y = avatar_node.global_position.y

	var next_world_yaw_radians: float = _build_yaw_from_move_direction(move_direction)

	avatar_node.apply_player_snapshot({
		"world_position": next_world_position,
		"world_yaw_radians": next_world_yaw_radians
	}, true)

	_local_move_request_accumulator_sec += delta

	var should_submit_now: bool = _local_last_submitted_action_state != NetProtocol.ACTION_STATE_MOVING
	if not should_submit_now and _local_move_request_accumulator_sec >= _get_move_request_interval_sec():
		should_submit_now = true

	if not should_submit_now:
		return

	_match_session_service.request_player_transform(
		next_world_position,
		next_world_yaw_radians,
		NetProtocol.ACTION_STATE_MOVING,
		-1
	)
	_local_last_submitted_action_state = NetProtocol.ACTION_STATE_MOVING
	_local_move_request_accumulator_sec = 0.0

func _get_local_player_avatar():
	if _local_peer_id <= 0:
		return null

	if not _player_avatar_by_peer_id.has(_local_peer_id):
		return null

	return _player_avatar_by_peer_id[_local_peer_id]

func _get_move_speed_units_per_sec() -> float:
	return max(RuntimeConfig.get_float("movement", "move_speed_units_per_sec", 6.0), 0.1)

func _get_move_request_interval_sec() -> float:
	return max(RuntimeConfig.get_float("movement", "request_interval_sec", 0.05), 0.016)

func _build_yaw_from_move_direction(move_direction: Vector3) -> float:
	return atan2(-move_direction.x, -move_direction.z)

func _clamp_world_position_to_ground_bounds(world_position: Vector3) -> Vector3:
	var clamped_world_position: Vector3 = world_position
	var body_radius: float = max(RuntimeConfig.get_float("client_world", "player_body_radius", 0.45), 0.1)

	var ground_shape: BoxShape3D = _ground_collision_shape.shape as BoxShape3D
	if ground_shape == null:
		return clamped_world_position

	var half_extents: Vector3 = ground_shape.size * 0.5
	var clamp_limit_x: float = max(half_extents.x - body_radius, 0.0)
	var clamp_limit_z: float = max(half_extents.z - body_radius, 0.0)

	clamped_world_position.x = clampf(clamped_world_position.x, -clamp_limit_x, clamp_limit_x)
	clamped_world_position.z = clampf(clamped_world_position.z, -clamp_limit_z, clamp_limit_z)
	return clamped_world_position

func _reset_local_movement_state() -> void:
	_local_move_request_accumulator_sec = 0.0
	_local_last_submitted_action_state = NetProtocol.ACTION_STATE_IDLE

func _update_camera_follow(delta: float) -> void:
	if _camera_controller == null:
		return

	if _local_peer_id <= 0:
		return

	if not _player_avatar_by_peer_id.has(_local_peer_id):
		return

	var avatar_node: Node3D = _player_avatar_by_peer_id[_local_peer_id] as Node3D
	if avatar_node == null:
		return

	_camera_controller.update_follow(avatar_node.global_position, delta)
