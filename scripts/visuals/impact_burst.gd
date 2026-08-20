extends Node3D

## Compact hit pop. Spawned at hit position; does not affect combat.

const SimContextScript := preload("res://scripts/sim/sim_context.gd")


func _ready() -> void:
	_build()
	if SimContextScript.skip_presentation():
		queue_free()
		return
	_play()


func _play() -> void:
	var core := get_node_or_null("Core") as MeshInstance3D
	if core:
		core.scale = Vector3(0.55, 0.55, 0.55)
		var cmat := core.material_override as StandardMaterial3D
		var tw := create_tween()
		tw.tween_property(core, "scale", Vector3(1.35, 1.35, 1.35), 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(core, "scale", Vector3(0.1, 0.1, 0.1), 0.12)
		if cmat:
			tw.parallel().tween_property(cmat, "emission_energy_multiplier", 0.6, 0.14)
			tw.parallel().tween_property(cmat, "albedo_color:a", 0.0, 0.14)

	var ring := get_node_or_null("Ring") as MeshInstance3D
	if ring:
		ring.scale = Vector3(0.4, 0.4, 0.4)
		var rmat := ring.material_override as StandardMaterial3D
		var twr := create_tween()
		twr.tween_property(ring, "scale", Vector3(1.8, 1.8, 1.8), 0.14)
		if rmat:
			twr.parallel().tween_property(rmat, "albedo_color:a", 0.0, 0.14)
			twr.parallel().tween_property(rmat, "emission_energy_multiplier", 0.3, 0.14)

	var light := get_node_or_null("BoomLight") as OmniLight3D
	if light:
		light.light_energy = 2.8
		light.visible = true
		var twl := create_tween()
		twl.tween_property(light, "light_energy", 0.0, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	var sparks := get_node_or_null("Sparks") as GPUParticles3D
	if sparks:
		sparks.restart()
		sparks.emitting = true

	var tree := get_tree()
	if tree:
		tree.create_timer(0.3).timeout.connect(queue_free)
	else:
		queue_free()


func _build() -> void:
	if has_node("Core"):
		return

	var core := MeshInstance3D.new()
	core.name = "Core"
	var sph := SphereMesh.new()
	sph.radius = 0.07
	sph.height = 0.14
	sph.radial_segments = 10
	sph.rings = 5
	core.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.4)
	mat.emission_energy_multiplier = 12.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.92, 0.6, 0.95)
	core.material_override = mat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)

	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var tor := TorusMesh.new()
	tor.inner_radius = 0.04
	tor.outer_radius = 0.1
	tor.rings = 10
	tor.ring_segments = 12
	ring.mesh = tor
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.emission_enabled = true
	rmat.emission = Color(1.0, 0.6, 0.22)
	rmat.emission_energy_multiplier = 7.0
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color = Color(1.0, 0.75, 0.3, 0.8)
	ring.material_override = rmat
	ring.rotation.x = PI * 0.5
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

	var light := OmniLight3D.new()
	light.name = "BoomLight"
	light.light_color = Color(1.0, 0.7, 0.3)
	light.light_energy = 0.0
	light.omni_range = 2.8
	light.shadow_enabled = false
	add_child(light)

	var sparks := GPUParticles3D.new()
	sparks.name = "Sparks"
	sparks.amount = 16
	sparks.lifetime = 0.22
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 140.0
	pm.initial_velocity_min = 2.2
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -7.0, 0)
	pm.scale_min = 0.02
	pm.scale_max = 0.05
	pm.color = Color(1.0, 0.8, 0.35)
	sparks.process_material = pm
	var sm := SphereMesh.new()
	sm.radius = 0.016
	sm.height = 0.032
	sm.radial_segments = 6
	sm.rings = 3
	sparks.draw_pass_1 = sm
	add_child(sparks)
