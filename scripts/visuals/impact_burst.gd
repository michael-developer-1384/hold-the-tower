extends Node3D

## Tiny kinetic impact. Spawned at hit position; does not affect combat.

const SimContextScript := preload("res://scripts/sim/sim_context.gd")


func _ready() -> void:
	_build()
	if SimContextScript.skip_presentation():
		queue_free()
		return
	var sparks := get_node_or_null("Sparks") as GPUParticles3D
	if sparks:
		sparks.restart()
		sparks.emitting = true
	var core := get_node_or_null("Core") as Node3D
	if core:
		var tw := create_tween()
		tw.tween_property(core, "scale", Vector3(0.02, 0.02, 0.02), 0.07)
	var tree := get_tree()
	if tree:
		tree.create_timer(0.22).timeout.connect(queue_free)
	else:
		queue_free()


func _build() -> void:
	if has_node("Core"):
		return
	var core := MeshInstance3D.new()
	core.name = "Core"
	var sph := SphereMesh.new()
	sph.radius = 0.045
	sph.height = 0.09
	sph.radial_segments = 8
	sph.rings = 4
	core.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.35)
	mat.emission_energy_multiplier = 6.0
	core.material_override = mat
	add_child(core)

	var sparks := GPUParticles3D.new()
	sparks.name = "Sparks"
	sparks.amount = 8
	sparks.lifetime = 0.18
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = 1.4
	pm.initial_velocity_max = 3.2
	pm.gravity = Vector3(0, -4.0, 0)
	pm.scale_min = 0.015
	pm.scale_max = 0.035
	pm.color = Color(1.0, 0.75, 0.3)
	sparks.process_material = pm
	var sm := SphereMesh.new()
	sm.radius = 0.014
	sm.height = 0.028
	sm.radial_segments = 6
	sm.rings = 3
	sparks.draw_pass_1 = sm
	add_child(sparks)
