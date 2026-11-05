extends GPUParticles3D

const BLOOD_DECAL_SCENE = preload("res://BloodDecal.tscn")
@export var spawn_decals: bool = true

func _ready() -> void:
	emitting = true
	
	if spawn_decals:
		# Cast a quick ray downward or outward to find a surface to stick a decal on
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3(0, -2.0, 0))
		var result = space_state.intersect_ray(query)
		
		if result:
			var decal = BLOOD_DECAL_SCENE.instantiate()
			get_tree().current_scene.add_child(decal)
			decal.global_position = result.position
			# Orient the decal to match the surface normal (walls/floors)
			decal.global_basis = Basis.looking_at(result.normal)

	# Clean up after particles finish
	await get_tree().create_timer(lifetime + 1.0).timeout
	queue_free()
