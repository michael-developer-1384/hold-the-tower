class_name VisualSockets
extends RefCounted

## Semantic sockets on a visual scene. Runtime combat should resolve these
## names instead of baking unique NodePaths per mesh revision.
##
## Canonical names (Sentry):
##   Base, Turret, WeaponPitch, RecoilAssembly, Weapon,
##   Muzzle, MuzzleLeft, MuzzleRight, Sensor, VFXSocket, HitSocket
## Aliases keep older Godot-native visuals working (Pedestal, TurretYaw, Recoil).

static func names_for(socket: String) -> PackedStringArray:
	match socket:
		"base":
			return PackedStringArray(["Base", "Pedestal"])
		"turret":
			return PackedStringArray(["Turret", "TurretYaw"])
		"weapon_pitch":
			return PackedStringArray(["WeaponPitch", "Weapon"])
		"recoil":
			return PackedStringArray(["RecoilAssembly", "Recoil"])
		"weapon":
			return PackedStringArray(["Weapon"])
		"muzzle":
			return PackedStringArray(["Muzzle", "MuzzleLeft"])
		"muzzle_left":
			return PackedStringArray(["MuzzleLeft", "Muzzle"])
		"muzzle_right":
			return PackedStringArray(["MuzzleRight", "Muzzle"])
		"sensor":
			return PackedStringArray(["Sensor"])
		"vfx":
			return PackedStringArray(["VFXSocket", "Muzzle"])
		"hit":
			return PackedStringArray(["HitSocket", "Turret", "Base"])
		_:
			return PackedStringArray([socket])


static func resolve(visual_root: Node, socket: String) -> Node3D:
	if visual_root == null:
		return null
	for n in names_for(socket):
		var found := _find_named(visual_root, n)
		if found is Node3D:
			return found as Node3D
	return null


static func require(visual_root: Node, socket: String) -> Node3D:
	var node := resolve(visual_root, socket)
	if node == null:
		push_error("VisualSockets: missing socket '%s' under %s" % [socket, visual_root])
	return node


static func _find_named(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	if root.has_node(NodePath(node_name)):
		return root.get_node(NodePath(node_name))
	return root.find_child(node_name, true, false)
