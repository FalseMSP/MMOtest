extends CharacterBody3D

# Movement variables - Phantom Forces style
@export var walk_speed: float = 16.0
@export var run_speed: float = 20.0
@export var crouch_speed: float = 6.0
@export var jump_velocity: float = 16.0
@export var ground_acceleration: float = 100.0  # Very fast acceleration
@export var ground_friction: float = 50.0
@export var air_acceleration: float = 20.0
@export var air_friction: float = 2.0
@export var mouse_sensitivity: float = 0.003

# Phantom Forces specific variables
@export var slide_speed: float = 24.0
@export var slide_duration: float = 0.8
@export var slide_friction: float = 15.0
@export var slide_cooldown: float = 0.3
@export var max_fall_speed: float = 50.0
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1

# Diving variables
@export var dive_force: float = 25.0
@export var dive_downward_force: float = 15.0
@export var dive_min_height: float = 2.0  # Minimum height to perform dive
@export var dive_cooldown: float = 0.5
@export var dive_recovery_time: float = 0.3
@export var roll_speed: float = 18.0
@export var roll_duration: float = 0.4
@export var dive_to_roll_height_threshold: float = 3.0  # Height threshold for auto-roll

# Wall jump variables
@export var wall_jump_velocity: float = 18.0
@export var wall_jump_push_force: float = 12.0
@export var wall_detection_distance: float = 0.8
@export var wall_jump_cooldown: float = 0.2
@export var wall_slide_speed: float = 3.0
@export var wall_stick_time: float = 0.15
@export var wall_jump_angle: float = 45.0  # Angle in degrees for wall jump direction
@export var momentum_preservation: float = 1.0  # How much momentum to preserve (0.0 - 1.0)
@export var momentum_redirect_threshold: float = 0.3  # Dot product threshold for momentum redirection

# Camera variables
@export var camera_min_pitch: float = -90.0
@export var camera_max_pitch: float = 90.0
@export var camera_bob_enabled: bool = true
@export var camera_bob_frequency: float = 2.0
@export var camera_bob_amplitude: float = 0.08
@export var camera_tilt_amount: float = 1.0

# Height variables
@export var standing_height: float = 1.8
@export var crouching_height: float = 1.0
@export var diving_height: float = 0.6
@export var height_transition_speed: float = 15.0

# Node references
@onready var camera_3d: Camera3D = $Camera3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# Internal variables
var camera_pitch: float = 0.0
var gravity: float = 50.0  # Higher gravity for snappier feel
var current_height: float
var original_camera_y: float
var camera_bob_time: float = 0.0

# Movement state
var is_sprinting: bool = false
var is_crouching: bool = false
var is_sliding: bool = false
var slide_timer: float = 0.0
var slide_direction: Vector3 = Vector3.ZERO
var can_slide: bool = true

# Diving state
var is_diving: bool = false
var is_rolling: bool = false
var dive_direction: Vector3 = Vector3.ZERO
var dive_start_height: float = 0.0
var can_dive: bool = true
var dive_recovery_timer: float = 0.0
var roll_timer: float = 0.0
var roll_direction: Vector3 = Vector3.ZERO

# Jump mechanics
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var was_on_floor: bool = false

# Wall jump mechanics
var is_wall_sliding: bool = false
var wall_normal: Vector3 = Vector3.ZERO
var wall_jump_timer: float = 0.0
var wall_stick_timer: float = 0.0
var last_wall_normal: Vector3 = Vector3.ZERO
var can_wall_jump: bool = true

# Camera effects
var camera_tilt: float = 0.0
var target_camera_tilt: float = 0.0

func _ready():
	# Capture mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Store original values
	current_height = standing_height
	original_camera_y = camera_3d.position.y
	
	# Set up collision shape
	update_collision_shape()

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
	handle_timers(delta)
	handle_gravity(delta)
	handle_wall_detection()
	handle_jump()
	handle_movement_states()
	handle_movement(delta)
	handle_camera_effects(delta)
	move_and_slide()
	
	# Handle dive landing and transitions
	handle_dive_landing()
	
	# Update floor state
	was_on_floor = is_on_floor()

func handle_timers(delta):
	# Coyote time
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta
	
	# Jump buffer
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta
	
	# Slide timer
	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0:
			end_slide()
	
	# Dive recovery timer
	if dive_recovery_timer > 0:
		dive_recovery_timer -= delta
	
	# Roll timer
	if is_rolling:
		roll_timer -= delta
		if roll_timer <= 0:
			end_roll()
	
	# Wall jump timer
	if wall_jump_timer > 0:
		wall_jump_timer -= delta
	
	# Wall stick timer
	if wall_stick_timer > 0:
		wall_stick_timer -= delta

func handle_gravity(delta):
	if not is_on_floor():
		if is_wall_sliding:
			# Slower fall speed when wall sliding
			velocity.y -= gravity * delta * 0.3
			velocity.y = max(velocity.y, -wall_slide_speed)
		elif is_diving:
			# Faster fall when diving
			velocity.y -= gravity * delta * 1.5
			velocity.y = max(velocity.y, -max_fall_speed * 1.2)
		else:
			velocity.y -= gravity * delta
			# Cap fall speed
			velocity.y = max(velocity.y, -max_fall_speed)

func handle_wall_detection():
	is_wall_sliding = false
	wall_normal = Vector3.ZERO
	
	# Only check for walls when in air and moving towards a wall
	if is_on_floor():
		return
	if !is_sprinting and !is_diving:
		return
	
	# Check multiple directions around the player
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + Vector3.FORWARD * wall_detection_distance
	)
	query.exclude = [self]
		
	# Check forward direction
	var result = space_state.intersect_ray(query)
	if result:
		wall_normal = result.normal
		is_wall_sliding = true
		return
	
	# Check backward direction
	query.to = global_position + Vector3.BACK * wall_detection_distance
	result = space_state.intersect_ray(query)
	if result:
		wall_normal = result.normal
		is_wall_sliding = true
		return
	
	# Check left direction
	query.to = global_position + Vector3.LEFT * wall_detection_distance
	result = space_state.intersect_ray(query)
	if result:
		wall_normal = result.normal
		is_wall_sliding = true
		return
	
	# Check right direction
	query.to = global_position + Vector3.RIGHT * wall_detection_distance
	result = space_state.intersect_ray(query)
	if result:
		wall_normal = result.normal
		is_wall_sliding = true
		return
	
	# Check based on current velocity direction
	if velocity.length() > 0:
		var vel_dir = velocity.normalized()
		query.to = global_position + vel_dir * wall_detection_distance
		result = space_state.intersect_ray(query)
		if result:
			wall_normal = result.normal
			is_wall_sliding = true

func handle_jump():
	# Regular jump with coyote time and jump buffering
	var can_jump = (is_on_floor() or coyote_timer > 0) and not is_sliding and not is_diving and not is_rolling
	
	if jump_buffer_timer > 0:
		if can_jump:
			# Regular jump
			velocity.y = jump_velocity
			jump_buffer_timer = 0
			coyote_timer = 0
		elif is_wall_sliding and can_wall_jump and wall_jump_timer <= 0:
			# Wall jump
			perform_wall_jump()
			jump_buffer_timer = 0

func perform_wall_jump():
	# Store current horizontal velocity for momentum preservation
	var current_horizontal = Vector3(velocity.x, 0, velocity.z)
	var current_speed = current_horizontal.length()
	
	# Calculate wall jump direction (horizontal push away from wall)
	var horizontal_push = Vector3(wall_normal.x, 0, wall_normal.z).normalized() * wall_jump_push_force
	
	# Preserve existing momentum and add wall push
	var new_horizontal = current_horizontal * momentum_preservation + horizontal_push
	
	# If the player was moving into the wall, redirect that momentum
	var wall_horizontal = Vector3(wall_normal.x, 0, wall_normal.z).normalized()
	var dot_product = current_horizontal.normalized().dot(-wall_horizontal)
	
	if dot_product > momentum_redirect_threshold:  # Player was moving toward wall
		# Redirect the momentum away from the wall instead of into it
		var redirected_momentum = current_horizontal.reflect(wall_horizontal) * momentum_preservation
		new_horizontal = redirected_momentum + horizontal_push
		
		# Boost speed if redirecting momentum (rewards skilled wall jumping)
		if current_speed > walk_speed:
			var speed_boost = min(current_speed * 0.2, run_speed * 0.3)
			new_horizontal = new_horizontal.normalized() * (new_horizontal.length() + speed_boost)
	
	# Apply the new horizontal velocity
	velocity.x = new_horizontal.x
	velocity.z = new_horizontal.z
	
	# Handle vertical momentum preservation
	if velocity.y < wall_jump_velocity:
		# Not enough upward momentum, set to wall jump velocity
		velocity.y = wall_jump_velocity
	else:
		# Already have upward momentum, add a smaller boost
		velocity.y += wall_jump_velocity * 0.3
	
	# If falling fast, convert some of that into horizontal speed
	if velocity.y < -10.0:
		var fall_speed = abs(velocity.y)
		var horizontal_boost = min(fall_speed * 0.4, run_speed * 0.5)
		new_horizontal = new_horizontal.normalized() * (new_horizontal.length() + horizontal_boost)
		velocity.x = new_horizontal.x
		velocity.z = new_horizontal.z
		velocity.y = wall_jump_velocity * 0.8  # Reduced upward velocity when converting fall speed
	
	# Set cooldown timers
	wall_jump_timer = wall_jump_cooldown
	wall_stick_timer = wall_stick_time
	
	# Store wall normal for preventing immediate re-wall-jumping
	last_wall_normal = wall_normal
	
	# Temporary disable wall jumping to prevent spam
	can_wall_jump = false
	get_tree().create_timer(wall_jump_cooldown).timeout.connect(func(): can_wall_jump = true)
	
	# Reset wall sliding state
	is_wall_sliding = false

func handle_movement_states():
	var crouch_input = Input.is_action_pressed("crouch")
	var crouch_just_pressed = Input.is_action_just_pressed("crouch")
	var sprint_input = Input.is_action_pressed("sprint")
	
	# Handle diving (crouch in air while moving)
	if crouch_just_pressed and not is_on_floor() and can_dive and not is_diving and not is_rolling:
		var height_above_ground = get_height_above_ground()
		if height_above_ground >= dive_min_height:
			start_dive()
			return
	
	# Handle rolling (continue from dive or manual roll)
	if is_rolling:
		# Continue rolling until timer expires
		return
	
	# Handle sliding
	if is_sliding:
		# Continue sliding until timer expires or player stops crouching
		if not crouch_input:
			end_slide()
	elif crouch_input and is_sprinting and is_on_floor() and can_slide and not is_diving and dive_recovery_timer <= 0:
		# Start slide if sprinting and crouching
		start_slide()
	elif crouch_input and not is_diving:
		# Regular crouch
		is_crouching = true
		is_sprinting = false
	else:
		# Standing
		is_crouching = false
		is_sprinting = sprint_input
	
	# Update height
	update_height()

func start_dive():
	if not can_dive:
		return
	
	is_diving = true
	is_crouching = true
	dive_start_height = global_position.y
	
	# Get dive direction based on current movement or camera forward
	var input_dir = get_input_direction()
	if input_dir.length() > 0:
		dive_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	else:
		dive_direction = -transform.basis.z  # Forward direction
	
	# Apply dive force
	var horizontal_force = dive_direction * dive_force
	velocity.x = horizontal_force.x
	velocity.z = horizontal_force.z
	
	# Add downward force for dive
	velocity.y = -dive_downward_force
	
	# Set cooldown
	can_dive = false
	get_tree().create_timer(dive_cooldown).timeout.connect(func(): can_dive = true)

func handle_dive_landing():
	if is_diving and is_on_floor():
		end_dive()
		
		# Check if we should roll (from sufficient height and still sprinting)
		var fall_distance = dive_start_height - global_position.y
		if fall_distance >= dive_to_roll_height_threshold and Input.is_action_pressed("sprint"):
			start_roll()
		else:
			# Short recovery period
			dive_recovery_timer = dive_recovery_time

func end_dive():
	is_diving = false

func start_roll():
	is_rolling = true
	is_crouching = true
	roll_timer = roll_duration
	
	# Use current movement direction or dive direction
	var input_dir = get_input_direction()
	if input_dir.length() > 0:
		roll_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	else:
		roll_direction = dive_direction
	
	# Apply roll velocity
	velocity.x = roll_direction.x * roll_speed
	velocity.z = roll_direction.z * roll_speed

func end_roll():
	is_rolling = false
	
	# Transition to slide if still holding crouch and sprint
	if Input.is_action_pressed("crouch") and Input.is_action_pressed("sprint") and can_slide:
		start_slide()

func get_input_direction() -> Vector2:
	var input_dir = Vector2.ZERO
	
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_backward"):
		input_dir.y += 1
	
	return input_dir.normalized()

func get_height_above_ground() -> float:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + Vector3.DOWN * 100.0
	)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	if result:
		return global_position.y - result.position.y
	return 0.0

func start_slide():
	is_sliding = true
	is_crouching = true
	is_sprinting = false
	slide_timer = slide_duration
	slide_direction = -transform.basis.z  # Forward direction
	can_slide = false
	
	# Set slide cooldown
	get_tree().create_timer(slide_cooldown).timeout.connect(_on_slide_cooldown)

func end_slide():
	is_sliding = false
	slide_direction = Vector3.ZERO

func _on_slide_cooldown():
	can_slide = true

func update_height():
	var target_height = standing_height
	
	if is_diving:
		target_height = diving_height
	elif is_rolling:
		target_height = diving_height
	elif is_crouching or is_sliding:
		target_height = crouching_height
	
	current_height = move_toward(current_height, target_height, height_transition_speed * get_physics_process_delta_time())
	
	# Update camera position
	var height_diff = current_height - standing_height
	camera_3d.position.y = original_camera_y + height_diff * 0.5
	
	# Update collision shape
	update_collision_shape()

func update_collision_shape():
	if collision_shape.shape is CapsuleShape3D:
		collision_shape.shape.height = current_height
		collision_shape.position.y = current_height * 0.5

func handle_movement(delta):
	# Get input direction
	var input_dir = get_input_direction()
	
	# Convert to 3D direction
	var direction = Vector3.ZERO
	if input_dir != Vector2.ZERO:
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Handle different movement states
	if is_diving:
		handle_dive_movement(direction, delta)
		return
	elif is_rolling:
		handle_roll_movement(direction, delta)
		return
	elif is_sliding:
		handle_slide_movement(delta)
		return
	
	# Handle wall sliding movement
	if is_wall_sliding and wall_stick_timer <= 0:
		handle_wall_slide_movement(direction, delta)
		return
	
	# Determine target speed
	var target_speed = walk_speed
	if is_sprinting:
		target_speed = run_speed
	elif is_crouching:
		target_speed = crouch_speed
	
	# Apply movement
	if is_on_floor():
		handle_ground_movement(direction, target_speed, delta)
	else:
		handle_air_movement(direction, target_speed, delta)

func handle_dive_movement(direction: Vector3, delta: float):
	# Limited air control during dive
	if direction.length() > 0:
		var control_force = direction * dive_force * 0.3  # Reduced control
		velocity.x = move_toward(velocity.x, control_force.x, air_acceleration * delta * 0.5)
		velocity.z = move_toward(velocity.z, control_force.z, air_acceleration * delta * 0.5)

func handle_roll_movement(direction: Vector3, delta: float):
	# Apply roll movement in roll direction with slight input control
	var roll_vel = roll_direction * roll_speed
	
	# Allow slight direction changes during roll
	if direction.length() > 0:
		var influence = 0.3  # How much input affects roll direction
		var new_direction = (roll_direction * (1.0 - influence) + direction * influence).normalized()
		roll_vel = new_direction * roll_speed
		roll_direction = new_direction
	
	# Apply roll velocity
	velocity.x = roll_vel.x
	velocity.z = roll_vel.z

func handle_slide_movement(delta):
	# Apply slide movement in slide direction
	var slide_vel = slide_direction * slide_speed
	
	# Gradually reduce slide speed
	var friction_factor = 1.0 - (slide_friction * delta)
	slide_vel *= friction_factor
	
	# Apply slide velocity
	velocity.x = slide_vel.x
	velocity.z = slide_vel.z
	
	# Update slide direction with reduced speed
	if slide_vel.length() > 0:
		slide_direction = slide_vel.normalized()

func handle_wall_slide_movement(direction: Vector3, delta: float):
	# Allow limited movement along the wall
	var wall_right = wall_normal.cross(Vector3.UP).normalized()
	var wall_up = wall_right.cross(wall_normal).normalized()
	
	# Project input direction onto wall plane
	var wall_movement = Vector3.ZERO
	if direction.length() > 0:
		var dot_right = direction.dot(wall_right)
		var dot_up = direction.dot(wall_up)
		wall_movement = wall_right * dot_right + wall_up * dot_up
		wall_movement = wall_movement.normalized() * (walk_speed * 0.5)  # Reduced speed on wall
	
	# Apply wall movement
	velocity.x = move_toward(velocity.x, wall_movement.x, air_acceleration * delta)
	velocity.z = move_toward(velocity.z, wall_movement.z, air_acceleration * delta)

func handle_ground_movement(direction: Vector3, target_speed: float, delta: float):
	if direction:
		# Phantom Forces has very snappy movement - near instant acceleration
		velocity.x = move_toward(velocity.x, direction.x * target_speed, ground_acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, ground_acceleration * delta)
		
		# Camera tilt based on strafe direction
		var strafe_input = 0.0
		if Input.is_action_pressed("move_left"):
			strafe_input += 1.0
		if Input.is_action_pressed("move_right"):
			strafe_input -= 1.0
		
		target_camera_tilt = strafe_input * camera_tilt_amount
	else:
		# Apply friction
		velocity.x = move_toward(velocity.x, 0, ground_friction * delta)
		velocity.z = move_toward(velocity.z, 0, ground_friction * delta)
		target_camera_tilt = 0.0

func handle_air_movement(direction: Vector3, target_speed: float, delta: float):
	if direction:
		# Reduced air control but still responsive
		velocity.x = move_toward(velocity.x, direction.x * target_speed, air_acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, air_acceleration * delta)
	else:
		# Light air friction
		velocity.x = move_toward(velocity.x, 0, air_friction * delta)
		velocity.z = move_toward(velocity.z, 0, air_friction * delta)

func handle_camera_effects(delta):
	# Camera bob when moving
	if camera_bob_enabled and is_on_floor() and get_horizontal_velocity().length() > 0.1:
		camera_bob_time += delta * camera_bob_frequency * get_horizontal_velocity().length() / walk_speed
		var bob_offset = sin(camera_bob_time) * camera_bob_amplitude
		
		# Apply bob to camera
		if is_sprinting:
			bob_offset *= 1.5  # More bob when sprinting
		elif is_crouching:
			bob_offset *= 0.3  # Less bob when crouching
		elif is_rolling:
			bob_offset *= 2.0  # More dramatic bob when rolling
		
		camera_3d.position.y = original_camera_y + (current_height - standing_height) * 0.5 + bob_offset
	
	# Camera tilt
	camera_tilt = move_toward(camera_tilt, target_camera_tilt, 10.0 * delta)
	camera_3d.rotation.z = deg_to_rad(camera_tilt)

# Utility functions
func get_horizontal_velocity() -> Vector3:
	return Vector3(velocity.x, 0, velocity.z)

func get_movement_speed() -> float:
	return get_horizontal_velocity().length()

func is_moving() -> bool:
	return get_horizontal_velocity().length() > 0.1

func get_current_state() -> String:
	if is_diving:
		return "Diving"
	elif is_rolling:
		return "Rolling"
	elif is_wall_sliding:
		return "Wall Sliding"
	elif is_sliding:
		return "Sliding"
	elif is_sprinting:
		return "Sprinting"
	elif is_crouching:
		return "Crouching"
	elif not is_on_floor():
		return "In Air"
	else:
		return "Walking"

# Debug info
func get_debug_info() -> Dictionary:
	return {
		"Speed": "%.1f" % get_movement_speed(),
		"State": get_current_state(),
		"On Floor": is_on_floor(),
		"Wall Sliding": is_wall_sliding,
		"Diving": is_diving,
		"Rolling": is_rolling,
		"Can Dive": can_dive,
		"Dive Recovery": "%.2f" % dive_recovery_timer,
		"Coyote Time": "%.2f" % coyote_timer,
		"Can Slide": can_slide,
		"Can Wall Jump": can_wall_jump,
		"Height": "%.1f" % current_height,
		"Height Above Ground": "%.1f" % get_height_above_ground(),
		"Wall Normal": "%.2f, %.2f, %.2f" % [wall_normal.x, wall_normal.y, wall_normal.z] if wall_normal != Vector3.ZERO else "None"
	}
