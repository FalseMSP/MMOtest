extends CharacterBody3D

# Movement variables
@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var acceleration: float = 10.0
@export var friction: float = 10.0
@export var air_acceleration: float = 2.0
@export var mouse_sensitivity: float = 0.002

# Camera variables
@export var camera_min_pitch: float = -89.0
@export var camera_max_pitch: float = 89.0

# Node references
@onready var camera_3d: Camera3D = $Camera3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

# Internal variables
var camera_pitch: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	# Capture mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	# Handle mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		handle_mouse_look(event)
	
	# Toggle mouse capture
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func handle_mouse_look(event: InputEventMouseMotion):
	# Rotate the character body horizontally
	rotate_y(-event.relative.x * mouse_sensitivity)
	
	# Rotate the camera vertically
	camera_pitch -= event.relative.y * mouse_sensitivity
	camera_pitch = clamp(camera_pitch, deg_to_rad(camera_min_pitch), deg_to_rad(camera_max_pitch))
	camera_3d.rotation.x = camera_pitch

func _physics_process(delta):
	handle_gravity(delta)
	handle_jump()
	handle_movement(delta)
	move_and_slide()

func handle_gravity(delta):
	# Add gravity when not on floor
	if not is_on_floor():
		velocity.y -= gravity * delta

func handle_jump():
	# Handle jumping
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

func handle_movement(delta):
	# Get input direction relative to the character's orientation
	var input_dir = Vector2.ZERO
	
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_backward"):
		input_dir.y += 1
	
	# Normalize diagonal movement
	input_dir = input_dir.normalized()
	
	# Convert 2D input to 3D direction relative to character rotation
	var direction = Vector3.ZERO
	if input_dir != Vector2.ZERO:
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Apply movement
	if is_on_floor():
		# Ground movement with acceleration and friction
		if direction:
			velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
			velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, friction * delta)
			velocity.z = move_toward(velocity.z, 0, friction * delta)
	else:
		# Air movement with reduced acceleration
		if direction:
			velocity.x = move_toward(velocity.x, direction.x * speed, air_acceleration * delta)
			velocity.z = move_toward(velocity.z, direction.z * speed, air_acceleration * delta)

# Optional: Add a method to check if the character is moving
func is_moving() -> bool:
	return velocity.length() > 0.1

# Optional: Add a method to get horizontal velocity
func get_horizontal_velocity() -> Vector3:
	return Vector3(velocity.x, 0, velocity.z)

# Optional: Add a method to get movement speed
func get_movement_speed() -> float:
	return get_horizontal_velocity().length()

# Optional: Add coyote time for more forgiving jumping
var coyote_time: float = 0.1
var coyote_timer: float = 0.0

func _physics_process_with_coyote(delta):
	# Update coyote timer
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta
	
	handle_gravity(delta)
	handle_jump_with_coyote()
	handle_movement(delta)
	move_and_slide()

func handle_jump_with_coyote():
	# Handle jumping with coyote time
	if Input.is_action_just_pressed("ui_accept") and (is_on_floor() or coyote_timer > 0):
		velocity.y = jump_velocity
		coyote_timer = 0.0  # Reset coyote timer after jumping
