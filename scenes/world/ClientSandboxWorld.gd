extends Node3D

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
var _player_avatar_by_peer_id: Dictionary = {}
var _local_peer_id: int = 0

func _ready() -> void:
	_configure_environment()
	_configure_ground()
	_configure_camera()

	_player_avatar_scene = _load_player_avatar_scene()
	_match_session_service = AppBootstrap.ensure_match_session_service()
	_connect_match_session_signals()

func _process(delta: float) -> void:
	_update_camera_follow(delta)

func _configure_environment() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.07, 0.09, 0.11, 1.0)
	environment.ambient_light_color = Color(0.82, 0.85, 0.90, 1.0)
	environment.ambient_light_energy = 1.0
	_world_environment.environment = environment

	_sun_light.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	_sun_light.light_energy = 1.4
	_sun_light.shadow_enabled = true

func _configure_ground() -> void:
	var ground_size_x: float = max(RuntimeConfig.get_float("client_world", "ground_size_x", 64.0), 8.0)
	var ground_size_z: float = max(RuntimeConfig.get_float("client_world", "ground_size_z", 64.0), 8.0)
	var ground_height: float = max(RuntimeConfig.get_float("client_world", "ground_height", 0.5), 0.1)

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

	_ground_body.position = Vector3(0.0, -ground_height * 0.5, 0.0)

func _configure_camera() -> void:
	var camera_height: float = max(RuntimeConfig.get_float("client_world", "camera_height", 26.0), 6.0)
	var camera_distance: float = max(RuntimeConfig.get_float("client_world", "camera_distance", 18.0), 4.0)

	_camera_rig.position = Vector3.ZERO
	_camera.position = Vector3(0.0, camera_height, camera_distance)
	_camera.make_current()
	_camera.look_at(_camera_rig.global_position, Vector3.UP)

func _load_player_avatar_scene() -> PackedScene:
	var scene_path: String = RuntimeConfig.get_string("client_world", "player_avatar_scene_path", "res://scenes/world/replicas/PlayerReplicaAvatar.tscn")
	if not ResourceLoader.exists(scene_path):
		LogService.error("BOOT", "Player avatar scene is missing at '%s'." % scene_path)
		return null
	return load(scene_path) as PackedScene

func _connect_match_session_signals() -> void:
	if _match_session_service == null:
		return

	if not _match_session_service.joined_match.is_connected(_on_joined_match):
		_match_session_service.joined_match.connect(_on_joined_match)

	if not _match_session_service.player_spawned.is_connected(_on_player_spawned):
		_match_session_service.player_spawned.connect(_on_player_spawned)

	if not _match_session_service.player_despawned.is_connected(_on_player_despawned):
		_match_session_service.player_despawned.connect(_on_player_despawned)

	if not _match_session_service.player_transforms_replicated.is_connected(_on_player_transforms_replicated):
		_match_session_service.player_transforms_replicated.connect(_on_player_transforms_replicated)

func _on_joined_match(snapshot_payload: Dictionary) -> void:
	_local_peer_id = int(snapshot_payload.get("accepted_peer_id", 0))
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

func _update_camera_follow(delta: float) -> void:
	if _local_peer_id <= 0:
		return

	if not _player_avatar_by_peer_id.has(_local_peer_id):
		return

	var avatar_node: Node3D = _player_avatar_by_peer_id[_local_peer_id] as Node3D
	if avatar_node == null:
		return

	var target_height: float = RuntimeConfig.get_float("client_world", "camera_target_height", 0.0)
	var follow_lerp_rate: float = max(RuntimeConfig.get_float("client_world", "camera_follow_lerp_rate", 8.0), 0.1)
	var desired_rig_position: Vector3 = avatar_node.global_position + Vector3(0.0, target_height, 0.0)

	_camera_rig.global_position = _camera_rig.global_position.lerp(desired_rig_position, clamp(delta * follow_lerp_rate, 0.0, 1.0))
	_camera.look_at(_camera_rig.global_position, Vector3.UP)
