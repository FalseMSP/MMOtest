extends Node3D

@export var projectile_scene: PackedScene
@export var fire_rate: float = 0.15  # Time between shots
@export var muzzle_velocity: float = 50.0
@export var spread_angle: float = 1.0  # Degrees of spread
@export var recoil_strength: float = 2.0
@export var ammo_capacity: int = 30
@export var reload_time: float = 2.0

# Weapon positioning
@export var weapon_offset: Vector3 = Vector3(0.3, -0.2, -0.5)
@export var weapon_sway_amount: float = 0.02
@export var weapon_bob_amount: float = 0.05

@onready var muzzle_point: Marker3D = $MuzzlePoint
@onready var weapon_mesh: MeshInstance3D = $WeaponMesh

var player: CharacterBody3D
var camera: Camera3D
var can_shoot: bool = true
var current_ammo: int
var is_reloading: bool = false
var weapon_sway_time: float = 0.0
var last_mouse_position: Vector2

func _ready():
	# Get references
	player = get_parent()
	camera = player.get_node("Camera3D")
	
	# Initialize ammo
	current_ammo = ammo_capacity
	
	# Create a simple weapon mesh if none exists
	if not weapon_mesh:
		create_weapon_mesh()
	
	# Create muzzle point if none exists
	if not muzzle_point:
		muzzle_point = Marker3D.new()
		muzzle_point.name = "MuzzlePoint"
		add_child(muzzle_point)
		muzzle_point.position = Vector3(0, 0, -1)  # Forward from weapon

func _input(event):
	if event is InputEventMouseMotion:
		last_mouse_position = event.relative

func _process(delta):
	handle_weapon_sway(delta)
	handle_weapon_bob(delta)
	
	# Handle shooting
	if Input.is_action_pressed("shoot") and can_shoot and current_ammo > 0 and not is_reloading:
		shoot()
	
	# Handle reloading
	if Input.is_action_just_pressed("reload") and current_ammo < ammo_capacity and not is_reloading:
		reload()

func handle_weapon_sway(delta):
	# Weapon sway based on mouse movement
	var sway_x = last_mouse_position.x * weapon_sway_amount
	var sway_y = last_mouse_position.y * weapon_sway_amount
	
	# Apply sway with smoothing
	var target_rotation = Vector3(sway_y, -sway_x, 0)
	rotation = rotation.lerp(target_rotation, delta * 10.0)
	
	# Reset mouse movement
	last_mouse_position = Vector2.ZERO

func handle_weapon_bob(delta):
	# Weapon bob based on player movement
	if player.is_on_floor() and player.get_horizontal_velocity().length() > 0.1:
		weapon_sway_time += delta * 10.0
		var bob_offset = Vector3(
			sin(weapon_sway_time) * weapon_bob_amount * 0.5,
			sin(weapon_sway_time * 2.0) * weapon_bob_amount,
			0
		)
		position = weapon_offset + bob_offset
	else:
		position = position.lerp(weapon_offset, delta * 10.0)

func shoot():
	if not projectile_scene:
		print("No projectile scene assigned!")
		return
	
	# Create projectile
	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	
	# Calculate shoot direction with spread
	var shoot_direction = -camera.global_transform.basis.z  # Camera forward
	if spread_angle > 0:
		shoot_direction = apply_spread(shoot_direction)
	
	# Initialize projectile
	var muzzle_position = muzzle_point.global_position
	projectile.initialize(muzzle_position, shoot_direction)
	
	# Apply recoil
	apply_recoil()
	
	# Consume ammo
	current_ammo -= 1
	
	# Set fire rate cooldown
	can_shoot = false
	get_tree().create_timer(fire_rate).timeout.connect(func(): can_shoot = true)
	
	# Muzzle flash effect
	create_muzzle_flash()
	
	print("Shot fired! Ammo: ", current_ammo, "/", ammo_capacity)

func apply_spread(direction: Vector3) -> Vector3:
	var spread_rad = deg_to_rad(spread_angle)
	var random_x = randf_range(-spread_rad, spread_rad)
	var random_y = randf_range(-spread_rad, spread_rad)
	
	# Create spread using camera's basis
	var right = camera.global_transform.basis.x
	var up = camera.global_transform.basis.y
	
	return (direction + right * random_x + up * random_y).normalized()

func apply_recoil():
	# Apply camera recoil
	var recoil_pitch = randf_range(-recoil_strength, -recoil_strength * 0.5)
	var recoil_yaw = randf_range(-recoil_strength * 0.3, recoil_strength * 0.3)
	
	# Apply recoil to camera (you might need to modify your player script)
	if player.has_method("apply_recoil"):
		player.apply_recoil(recoil_pitch, recoil_yaw)

func reload():
	if is_reloading:
		return
	
	is_reloading = true
	print("Reloading...")
	
	# Wait for reload time
	await get_tree().create_timer(reload_time).timeout
	
	current_ammo = ammo_capacity
	is_reloading = false
	print("Reload complete!")

func create_muzzle_flash():
	# Simple muzzle flash effect
	var flash = MeshInstance3D.new()
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.1, 0.1)
	flash.mesh = quad_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.YELLOW
	material.emission_enabled = true
	material.emission = Color.YELLOW
	flash.material_override = material
	
	muzzle_point.add_child(flash)
	
	# Remove flash after short time
	get_tree().create_timer(0.05).timeout.connect(func(): flash.queue_free())

func create_weapon_mesh():
	weapon_mesh = MeshInstance3D.new()
	weapon_mesh.name = "WeaponMesh"
	add_child(weapon_mesh)
	
	# Create a simple box mesh for the weapon
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.1, 0.1, 0.5)
	weapon_mesh.mesh = box_mesh
	
	# Create material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.DARK_GRAY
	weapon_mesh.material_override = material
	
	weapon_mesh.position = Vector3(0, 0, -0.25)

func get_ammo_info() -> Dictionary:
	return {
		"current": current_ammo,
		"capacity": ammo_capacity,
		"is_reloading": is_reloading
	}
