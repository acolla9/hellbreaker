extends Area3D

@export var speed = 70.0
var direction = Vector3.ZERO
const IMPACT_EFFECT = preload("res://ImpactEffect.tscn")
var lifetime = 3.0
var has_hit = false

func _physics_process(delta):
	if has_hit:
		return
		
	# Bereken hoeveel afstand de kogel DIT frame gaat afleggen
	var move_distance = speed * delta
	var next_position = global_position + (direction * move_distance)
	
	# Doe een handmatige raycast van de huidige plek naar de volgende plek
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, next_position)
	query.exclude = [self] # Negeer de kogel zelf
	
	var result = space_state.intersect_ray(query)
	
	if result:
		# Er zat iets tussen deze en de volgende frame!
		global_position = result.position # Zet kogel exact op het raakpunt
		_on_hit(result.collider)
	else:
		# Geen obstakel, beweeg gewoon door
		global_position = next_position

	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_hit(body):
	if has_hit:
		return
	has_hit = true
	
	if IMPACT_EFFECT:
		var effect = IMPACT_EFFECT.instantiate()
		get_tree().current_scene.add_child(effect)
		effect.global_position = global_position
		
		if body.has_method("take_damage"):
			# Pass damage amount, the bullet's travel direction for knockback, and the exact global hit position
			body.take_damage(25, direction, global_position)
	
	$MeshInstance3D.visible = false
	if has_node("CollisionShape3D"):
		$CollisionShape3D.set_deferred("disabled", true)
		
	await get_tree().create_timer(0.2).timeout
	queue_free()
