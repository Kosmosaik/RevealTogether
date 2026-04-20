extends Node3D

@onready var _body_root: Node3D = $BodyRoot
@onready var _body_mesh: MeshInstance3D = $BodyRoot/BodyMesh

var _peer_id: int = 0
var _display_name: String = ""
var _is_local_player: bool = false
var _target_world_position: Vector3 = Vector3.ZERO
var _target_world_yaw_radians: float = 0.0
var _position_lerp_rate: float = 12.0
var _rotation_lerp_rate: float = 14.0

func _ready() -> void:
	_build_visual_mesh()

func _process(delta: float) -> void:
	position = position.lerp(_target_world_position, clamp(delta * _position_lerp_rate, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, _target_world_yaw_radians, clamp(delta * _rotation_lerp_rate, 0.0, 1.0))

func configure_identity(peer_id: int, display_name: String, is_local_player: bool) -> void:
	_peer_id = peer_id
	_display_name = display_name
	_is_local_player = is_local_player

	if is_inside_tree():
		_apply_material_palette()

func apply_player_snapshot(player_snapshot: Dictionary, snap_immediately: bool) -> void:
	_target_world_position = player_snapshot.get("world_position", Vector3.ZERO)
	_target_world_yaw_radians = float(player_snapshot.get("world_yaw_radians", 0.0))

	if snap_immediately:
		position = _target_world_position
		rotation.y = _target_world_yaw_radians

func _build_visual_mesh() -> void:
	var body_height: float = max(RuntimeConfig.get_float("client_world", "player_body_height", 1.8), 0.5)
	var body_radius: float = max(RuntimeConfig.get_float("client_world", "player_body_radius", 0.45), 0.1)

	var body_mesh: CapsuleMesh = CapsuleMesh.new()
	body_mesh.height = body_height
	body_mesh.radius = body_radius
	_body_mesh.mesh = body_mesh
	_body_root.position = Vector3(0.0, body_height * 0.5, 0.0)

	_apply_material_palette()

func _apply_material_palette() -> void:
	var body_material: StandardMaterial3D = StandardMaterial3D.new()
	body_material.roughness = 0.9
	body_material.metallic = 0.0

	if _is_local_player:
		body_material.albedo_color = Color(0.95, 0.76, 0.29, 1.0)
	else:
		body_material.albedo_color = Color(0.35, 0.62, 0.96, 1.0)

	_body_mesh.material_override = body_material
