extends CharacterBody3D

@export var max_health = 50.0
@export var move_speed = 5.0
@export var attack_damage = 10.0
@export var knockback_recovery = 10.0 # Hoe snel de knockback webtbt

var health = max_health
var player = null
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var knockback_velocity = Vector3.ZERO

# Preload your blood effect scene
const BLOOD_EFFECT_SCENE = preload("res://BloodEffect.tscn")

@onready var mesh = $MeshInstance3D # Zorg dat je mesh zo heet, of pas dit aan naar jouw node naam

func _ready() -> void:
	health = max_health
	await get_tree().process_frame
	if get_tree().has_group("player"):
		player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	# 1. Zwaartekracht toepassen
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	# 2. Verwerk knockback (als de vijand is geraakt of geslammed)
	if knockback_velocity.length() > 0.1:
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, knockback_recovery * delta)
	elif player:
		# 3. Normale movement: Loop direct naar de speler toe
		var direction = (player.global_position - global_position)
		direction.y = 0 # Houd beweging plat op de grond
		direction = direction.normalized()
		
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		
		# Draai de vijand naar de speler toe
		if direction.length() > 0.1:
			look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)

	move_and_slide()

# Functie die wordt aangeroepen door jouw kogel
func take_damage(amount, bullet_direction = Vector3.ZERO, hit_position = global_position):
	health -= amount
	
	spawn_blood(hit_position, 15, 2.0)
	
	# Geef de vijand een lichte knockback in de schietrichting
	knockback_velocity = bullet_direction * 8.0
	knockback_velocity.y = 3.0 # Kleine pop omhoog
	
	# Visuele hit-flash (maak de mesh tijdelijk rood of fel)
	flash_hit()
	
	if health <= 0:
		die()

# Functie voor de Slam Attack van de speler
func take_slam(slam_global_pos):
	health -= 35.0
	
	# Bereken knockback van de slam af (duw vijand naar buiten vanaf het slam-punt)
	var push_dir = (global_position - slam_global_pos).normalized()
	push_dir.y = 0.5 # Lanceer ze een beetje de lucht in!
	knockback_velocity = push_dir * 18.0
	
	flash_hit()
	if health <= 0:
		die()

func flash_hit():
	if mesh:
		# Schaal alleen de mesh visueel op, de CharacterBody3D blijft onaangeroerd!
		mesh.scale = Vector3(1.2, 0.8, 1.2)
		await get_tree().create_timer(0.1).timeout
		if mesh:
			mesh.scale = Vector3.ONE

func die():
	spawn_blood(global_position + Vector3(0, 1, 0), 80, 5.0)
	# Speel eventueel een doods-effect of spawn loot/particles
	queue_free()
	
func spawn_blood(pos: Vector3, amount: int, speed: float) -> void:
	var blood = BLOOD_EFFECT_SCENE.instantiate()
	get_tree().current_scene.add_child(blood)
	blood.global_position = pos
	
	# Optionally tweak particle amount/speed dynamically if needed
	blood.amount = amount
	if blood.process_material is ParticleProcessMaterial:
		blood.process_material.initial_velocity_min = speed * 0.5
		blood.process_material.initial_velocity_max = speed
