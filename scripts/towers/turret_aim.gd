class_name TurretAim
extends RefCounted

## Shared yaw/pitch slewing for sentry-style turrets.
## Combat and lookdev both use this so lock timing stays consistent.


static func step_yaw(turret: Node3D, look: Vector3, rate_rad: float, delta: float) -> float:
	if turret == null or not is_instance_valid(turret):
		return INF
	var origin := turret.global_position
	var flat := Vector3(look.x - origin.x, 0.0, look.z - origin.z)
	if flat.length() < 0.05:
		return 0.0
	var desired := atan2(-flat.x, -flat.z)
	var gy := turret.global_rotation
	var err := absf(angle_difference(gy.y, desired))
	gy.y = rotate_toward(gy.y, desired, maxf(rate_rad, 0.0) * delta)
	gy.x = 0.0
	gy.z = 0.0
	turret.global_rotation = gy
	return err


static func step_pitch(
	pitch: Node3D,
	turret: Node3D,
	look: Vector3,
	rate_rad: float,
	delta: float,
	min_pitch: float = deg_to_rad(-55.0),
	max_pitch: float = deg_to_rad(75.0)
) -> float:
	if pitch == null or not is_instance_valid(pitch) or turret == null:
		return 0.0
	var to := look - pitch.global_position
	if to.length() < 0.05:
		return 0.0
	var local := turret.global_transform.basis.inverse() * to
	var desired := atan2(local.y, maxf(-local.z, 0.05))
	desired = clampf(desired, min_pitch, max_pitch)
	var err := absf(angle_difference(pitch.rotation.x, desired))
	pitch.rotation.x = rotate_toward(pitch.rotation.x, desired, maxf(rate_rad, 0.0) * delta)
	pitch.rotation.y = 0.0
	pitch.rotation.z = 0.0
	return err


static func is_aligned(yaw_err: float, pitch_err: float, lock_tol: float) -> bool:
	return yaw_err <= lock_tol and pitch_err <= lock_tol
