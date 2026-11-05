extends CharacterBody3D

# --- MOVEMENT CONFIG ---
@export var WALK_SPEED = 12.0
@export var DASH_SPEED = 35.0
@export var SLIDE_SPEED = 24.0
@export var JUMP_VELOCITY = 6.5

# --- WALL JUMP & SLAM CONFIG ---
@export var WALL_JUMP_VELOCITY = 8.0
@export var WALL_JUMP_PUSH = 14.0
@export var SLAM_SPEED = 40.0

@export var MOMENTUM_RETENTION = 0.98
@export var GROUND_FRICTION = 0.15
@export var MOUSE_SENSITIVITY = 0.002

# --- WEAPON BOB & SWAY CONFIG ---
@export var SWAY_LEAN = 0.005
@export var SWAY_SNAP = 10.0
@export var BOB_SPEED = 12.0
@export var BOB_AMOUNT = Vector2(0.04, 0.02)

# --- SHOOTING CONFIG ---
const BULLET_SCENE = preload("res://Bullet.tscn")
@export var FIRE_RATE = 0.15

# --- INTERNAL VARIABLES ---
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_sliding = false
var is_slamming = false
var waiting_for_slide_release = false 
var dash_timer = 0.0
var dash_direction = Vector3.ZERO
var mouse_input = Vector2.ZERO
var bob_time = 0.0
var fire_cooldown = 0.0
var air_lockout_timer = 0.0 # <--- Voeg deze toe!

# --- NODE REFERENCES ---
@onready var neck = $Neck
@onready var camera = $Neck/Camera3D
@onready var weapon_pivot = $Neck/Camera3D/WeaponPivot
@onready var weapon = $Neck/Camera3D/WeaponPivot/Weapon
var default_weapon_pos : Vector3

@onready var muzzle_flash = $Neck/Camera3D/WeaponPivot/Weapon/MuzzleFlash

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	default_weapon_pos = weapon.position
	
	# Voeg de speler toe aan een globale, persistente groep die blijft bestaan over scenes heen
	add_to_group("player", true)

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		neck.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		neck.rotation.x = clamp(neck.rotation.x, deg_to_rad(-89), deg_to_rad(89))
		mouse_input = event.relative

func _physics_process(delta):
	# Check of de speler de slide-knop loslaat na een slam
	if waiting_for_slide_release and not Input.is_action_pressed("slide"):
		waiting_for_slide_release = false
		
	if air_lockout_timer > 0:
		air_lockout_timer -= delta

	# Reset slam status bij landing
	if is_on_floor() and is_slamming:
		perform_slam_impact()

	# 1. ZWAARTEKRACHT
	if not is_on_floor() and not is_slamming:
		velocity.y -= gravity * delta

	# 2. INPUT OPHALEN
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# 3. SLAM ATTACK
	if Input.is_action_just_pressed("slide") and not is_on_floor() and not is_slamming:
		is_slamming = true
		waiting_for_slide_release = true # Blokkeer slides tot de knop wordt losgelaten
		velocity.x = 0
		velocity.z = 0

	if is_slamming:
		velocity.y = -SLAM_SPEED

	# 4. DASH MECHANIEK
	elif Input.is_action_just_pressed("dash") and dash_timer <= 0:
		dash_timer = 0.2
		dash_direction = direction if direction != Vector3.ZERO else -transform.basis.z

	if dash_timer > 0:
		dash_timer -= delta
		velocity.x = dash_direction.x * DASH_SPEED
		velocity.z = dash_direction.z * DASH_SPEED

	# 5. SLIDE MECHANIEK (Alleen als we NIET wachten op het loslaten van de knop)
	elif Input.is_action_pressed("slide") and is_on_floor() and not waiting_for_slide_release:
		if not is_sliding:
			is_sliding = true
			if velocity.length() > WALK_SPEED:
				velocity = velocity * 1.2
			else:
				velocity = direction * SLIDE_SPEED if direction != Vector3.ZERO else -transform.basis.z * SLIDE_SPEED

		velocity.x *= MOMENTUM_RETENTION
		velocity.z *= MOMENTUM_RETENTION

		if Vector3(velocity.x, 0, velocity.z).length() < WALK_SPEED * 0.8:
			is_sliding = false

		camera.position.y = lerp(camera.position.y, -0.5, delta * 10)

	# 6. STANDAARD BEWEGING
	elif not is_slamming:
		is_sliding = false
		camera.position.y = lerp(camera.position.y, 0.0, delta * 10)

		if direction != Vector3.ZERO:
			var current_horizontal_vel = Vector3(velocity.x, 0, velocity.z)
			if current_horizontal_vel.length() > WALK_SPEED:
				velocity.x *= MOMENTUM_RETENTION
				velocity.z *= MOMENTUM_RETENTION
				velocity += direction * WALK_SPEED * delta * 2
			else:
				velocity.x = direction.x * WALK_SPEED
				velocity.z = direction.z * WALK_SPEED
		else:
			velocity.x = lerp(velocity.x, 0.0, GROUND_FRICTION)
			velocity.z = lerp(velocity.z, 0.0, GROUND_FRICTION)

# 7. JUMP & WALL JUMP
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			if dash_timer > 0 or is_sliding:
				velocity.x *= 1.3
				velocity.z *= 1.3
				dash_timer = 0.0
				is_sliding = false
		
		elif is_on_wall_only(): # Gebruik is_on_wall_only() zodat je niet in de lucht blijft wall-jumpen
			var wall_normal = get_wall_normal()
			
			# Geef een flinke boost weg van de muur EN naar voren in de richting van je camera/input
			var push_dir = (wall_normal + -transform.basis.z).normalized()
			
			velocity.y = WALL_JUMP_VELOCITY * 1.3 # Maak het hoger
			velocity.x = push_dir.x * (WALL_JUMP_PUSH * 1.5)
			velocity.z = push_dir.z * (WALL_JUMP_PUSH * 1.5)
			
			# Voorkom dat je direct nog een keer kunt wall-jumpen aan dezelfde muur
			# Door kort de beweging te dwingen
			air_lockout_timer = 0.15

	move_and_slide()

func perform_slam_impact():
	is_slamming = false
	is_sliding = false
	camera.position.y = -0.3

func _process(delta):
	handle_weapon_sway(delta)
	handle_weapon_bob(delta)

	if fire_cooldown > 0:
		fire_cooldown -= delta

	if Input.is_action_pressed("shoot") and fire_cooldown <= 0:
		shoot_weapon()

func handle_weapon_sway(delta):
	var target_x = -mouse_input.x * SWAY_LEAN
	var target_y = mouse_input.y * SWAY_LEAN
	mouse_input = Vector2.ZERO

	weapon.position.x = lerp(weapon.position.x, default_weapon_pos.x + target_x, delta * SWAY_SNAP)
	weapon.position.y = lerp(weapon.position.y, default_weapon_pos.y + target_y, delta * SWAY_SNAP)

func handle_weapon_bob(delta):
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z).length()

	if is_on_floor() and horizontal_velocity > 0.1:
		bob_time += delta * horizontal_velocity
		var bob_x = sin(bob_time * 0.5) * BOB_AMOUNT.x
		var bob_y = abs(sin(bob_time)) * BOB_AMOUNT.y

		weapon_pivot.position.x = lerp(weapon_pivot.position.x, bob_x, delta * 15.0)
		weapon_pivot.position.y = lerp(weapon_pivot.position.y, bob_y, delta * 15.0)
	else:
		bob_time = 0.0
		weapon_pivot.position = weapon_pivot.position.lerp(Vector3.ZERO, delta * 10.0)

func shoot_weapon():
	fire_cooldown = FIRE_RATE

	muzzle_flash.visible = true
	await get_tree().create_timer(0.05).timeout
	muzzle_flash.visible = false

	# 1. Instantieer de kogel
	var bullet = BULLET_SCENE.instantiate()
	
	# 2. Bepaal de schietrichting vooraf
	var shoot_dir = -camera.global_transform.basis.z
	
	# 3. Voeg hem EERST toe aan de hoofdscene (dit lost de 'not in a scene tree' fout op!)
	get_tree().current_scene.add_child(bullet)
	
	# 4. Stel pas daarna de positie en richting in
	bullet.global_position = muzzle_flash.global_position + (shoot_dir * 0.5)
	bullet.direction = shoot_dir
