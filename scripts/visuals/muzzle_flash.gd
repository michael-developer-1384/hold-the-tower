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

	var flash := get_node_or_null("Flash") as MeshInstance3D
	if flash:
		flash.visible = true
		flash.scale = Vector3(1.15, 1.15, 1.5)
		var fmat := flash.material_override as StandardMaterial3D
		var tw := create_tween()
		tw.tween_property(flash, "scale", Vector3(0.12, 0.12, 0.35), 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		if fmat:
			tw.parallel().tween_property(fmat, "emission_energy_multiplier", 1.0, 0.06)
			tw.parallel().tween_property(fmat, "albedo_color:a", 0.0, 0.06)

	var light := get_node_or_null("FlashLight") as OmniLight3D
	if light:
		light.light_energy = 2.2
		light.visible = true
		var twl := create_tween()
		twl.tween_property(light, "light_energy", 0.0, 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	var sparks := get_node_or_null("Sparks") as GPUParticles3D
	if sparks:
		sparks.restart()
		sparks.emitting = true

	var tree := get_tree()
	if tree:
		tree.create_timer(0.22).timeout.connect(queue_free)
	else:
		queue_free()


func _build() -> void:
	if has_node("Flash"):
		return

	var flash := MeshInstance3D.new()
	flash.name = "Flash"
	var cap := CapsuleMesh.new()
	cap.radius = 0.04
	cap.height = 0.18
	flash.mesh = cap
	flash.rotation_degrees = Vector3(90, 0, 0)
	flash.position = Vector3(0, 0, -0.07)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.55)
	mat.emission_energy_multiplier = 10.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.95, 0.75, 0.95)
	flash.material_override = mat
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flash)

	var light := OmniLight3D.new()
	light.name = "FlashLight"
	light.light_color = Color(1.0, 0.8, 0.45)
	light.light_energy = 0.0
	light.omni_range = 2.4
	light.shadow_enabled = false
	light.position = Vector3(0, 0, -0.06)
	add_child(light)

	var sparks := GPUParticles3D.new()
	sparks.name = "Sparks"
	sparks.amount = 10
	sparks.lifetime = 0.14
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, -1)
	pm.spread = 26.0
	pm.initial_velocity_min = 2.5
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -2.5, 0)
	pm.scale_min = 0.02
	pm.scale_max = 0.045
	pm.color = Color(1.0, 0.85, 0.4)
	sparks.process_material = pm
	var sm := SphereMesh.new()
	sm.radius = 0.016
	sm.height = 0.032
	sm.radial_segments = 6
	sm.rings = 3
	sparks.draw_pass_1 = sm
	add_child(sparks)
