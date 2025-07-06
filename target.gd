extends StaticBody3D

@export var max_health: int = 1  # Dies in one hit
@export var spawn_range: float = 20.0  # How far from origin to spawn targets
@export var target_count: int = 5

var current_health: int
var target_scene = preload("res://target.tscn")  # Adjust path as needed

func _ready():
	current_health = max_health
	add_to_group("targets")
	
	# If this is the main target spawner, create the other targets
	if name == "TargetSpawner" or get_parent().name == "Main":
		spawn_targets()

func spawn_targets():
	var parent = get_parent()
	
	for i in range(target_count):
		# Create new target instance
		var new_target = duplicate()
		
		# Generate random position within spawn range
		var random_pos = Vector3(
			randf_range(-spawn_range, spawn_range),
			randf_range(2.0, 10.0),  # Keep targets above ground
			randf_range(-spawn_range, spawn_range)
		)
		
		# Set position and add to scene
		new_target.global_position = random_pos
		new_target.name = "Target_" + str(i + 1)
		parent.add_child(new_target)
		
		print("Spawned target at: ", random_pos)

func take_damage(amount: int):
	current_health -= amount
	print("Target hit! Health: ", current_health)
	
	if current_health <= 0:
		die()

func die():
	print("Target destroyed!")
	
	# Optional: Create death effect
	create_death_effect()
	
	# Remove from scene
	queue_free()

func create_death_effect():
	# Simple death effect - you can make this more elaborate
	print("Target exploded at: ", global_position)
	
	# Optional: Add particle effect or sound here
	# var effect = preload("res://path/to/death_effect.tscn")
	# if effect:
	#     var death_fx = effect.instantiate()
	#     get_parent().add_child(death_fx)
	#     death_fx.global_position = global_position

# Optional: Add a visual indicator when hit
func _on_area_3d_body_entered(body):
	if body.has_method("is_projectile") and body.is_projectile():
		# Visual feedback before taking damage
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color.WHITE, 0.1)
