extends RefCounted
class_name MatchSpawnPlanner

static func build_spawn_position_for_slot(spawn_slot_index: int) -> Vector3:
	var base_radius: float = max(RuntimeConfig.get_float("spawn_layout", "base_radius", 6.0), 0.0)
	var ring_spacing: float = max(RuntimeConfig.get_float("spawn_layout", "ring_spacing", 4.0), 1.0)
	var vertical_offset: float = RuntimeConfig.get_float("spawn_layout", "vertical_offset", 0.0)
	var slots_in_inner_ring: int = max(RuntimeConfig.get_int("spawn_layout", "slots_in_inner_ring", 8), 1)

	var ring_index: int = 0
	var slot_index_in_ring: int = spawn_slot_index
	var slots_in_current_ring: int = slots_in_inner_ring

	while slot_index_in_ring >= slots_in_current_ring:
		slot_index_in_ring -= slots_in_current_ring
		ring_index += 1
		slots_in_current_ring += slots_in_inner_ring

	var radius: float = base_radius + (float(ring_index) * ring_spacing)
	var angle_step_radians: float = TAU / float(slots_in_current_ring)
	var angle_radians: float = float(slot_index_in_ring) * angle_step_radians

	return Vector3(
		cos(angle_radians) * radius,
		vertical_offset,
		sin(angle_radians) * radius
	)

static func build_spawn_yaw_for_slot(_spawn_slot_index: int) -> float:
	# Phase 1 only needs deterministic spawn placement.
	# Facing can stay neutral until the movement/controller layer owns yaw.
	return 0.0
