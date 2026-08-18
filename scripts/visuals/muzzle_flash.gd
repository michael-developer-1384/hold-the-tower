extends Node3D

## Short kinetic muzzle burst. Combat parents this at a muzzle and calls play().

const SimContextScript := preload("res://scripts/sim/sim_context.gd")


func _ready() -> void:
	_build()


func play() -> void:
	if SimContextScript.skip_presentation():
		queue_free()
		return
	visible = true
	var flash := get_node_or_null("Flash") as Node3D
	if flash:
		flash.scale = Vector3(1.15, 1.15, 1.6)
		var tw := create_tween()
		tw.tween_property(flash, "scale", Vector3(0.05, 0.05, 0.2), 0.05)
		tw.tween_callback(func() -> void:
			if is_instance_valid(flash):
				flash.visible = false
		)
	var sparks := get_node_or_null("Sparks") as GPUParticles3D
	if sparks:
		sparks.restart()
		sparks.emitting = true
	var smoke := get_node_or_null("Smoke") as GPUParticles3D
	if smoke:
		smoke.restart()
		smoke.emitting = true
	var tree := get_tree()
	if tree:
		tree.create_timer(0.28).timeout.connect(queue_free)
	else:
		queue_free()


func _build() -> void:
	if has_node("Flash"):
		return
	var flash := MeshInstance3D.new()
	flash.name = "Flash"
	var cap := CapsuleMesh.new()
	cap.radius = 0.035
	cap.height = 0.16
	flash.mesh = cap
	flash.rotation_degrees = Vector3(90, 0, 0)
	flash.position = Vector3(0, 0, -0.06)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.92, 0.55)
	mat.emission_energy_multiplier = 8.0
	mat.albedo_color = Color(1.0, 0.95, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.95
	flash.material_override = mat
	add_child(flash)

	var sparks := GPUParticles3D.new()
	sparks.name = "Sparks"
	sparks.amount = 10
	sparks.lifetime = 0.16
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, -1)
	pm.spread = 28.0
	pm.initial_velocity_min = 2.2
	pm.initial_velocity_max = 4.8
	pm.gravity = Vector3(0, -2.0, 0)
	pm.scale_min = 0.02
	pm.scale_max = 0.045
	pm.color = Color(1.0, 0.85, 0.4)
	sparks.process_material = pm
	var sm := SphereMesh.new()
	sm.radius = 0.018
	sm.height = 0.036
	sm.radial_segments = 6
	sm.rings = 3
	sparks.draw_pass_1 = sm
	add_child(sparks)

	var smoke := GPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.amount = 4
	smoke.lifetime = 0.28
	smoke.one_shot = true
	smoke.explosiveness = 0.85
	smoke.emitting = false
	var spm := ParticleProcessMaterial.new()
	spm.direction = Vector3(0, 0.4, -1)
	spm.spread = 18.0
	spm.initial_velocity_min = 0.35
	spm.initial_velocity_max = 0.7
	spm.gravity = Vector3(0, 0.4, 0)
	spm.scale_min = 0.04
	spm.scale_max = 0.08
	spm.color = Color(0.45, 0.48, 0.5, 0.35)
	smoke.process_material = spm
	var box := BoxMesh.new()
	box.size = Vector3(0.04, 0.04, 0.04)
	smoke.draw_pass_1 = box
	add_child(smoke)
