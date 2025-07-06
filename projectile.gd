extends RigidBody3D

@export var damage: int = 25
@export var speed: float = 50.0
@export var lifetime: float = 5.0
#@export var gravity_scale: float = 0.5  # Uncommented this

var direction: Vector3
var has_hit: bool = false

func _ready():
	# Add to projectiles group for target detection
	add_to_group("projectiles")
	
	# Set up the projectile
	gravity_scale = gravity_scale
	
	# Only set velocity if direction is already set
	if direction != Vector3.ZERO:
		linear_velocity = direction * speed
	
	# Self-destruct after lifetime
	get_tree().create_timer(lifetime).timeout.connect(destroy_projectile)

func initialize(start_position: Vector3, shoot_direction: Vector3):
	global_position = start_position
	direction = shoot_direction.normalized()
	linear_velocity = direction * speed

func create_impact_effect():
	# Simple impact effect - you can make this more elaborate
	#var effect = preload("res://path/to/impact_effect.tscn")  # Create this scene
	#if effect:
		#var impact = effect.instantiate()
		#get_parent().add_child(impact)
		#impact.global_position = global_position
	
	# Or create a simple particle effect
	print("Impact at: ", global_position)

func destroy_projectile():
	queue_free()

# Add this method for target detection
func is_projectile() -> bool:
	return true


func _on_area_3d_area_entered(area: Area3D) -> void:
	print("test")
	if has_hit:
		return
		
	has_hit = true
	
	# Check if we hit a target
	var target = area.get_parent()
	if target and target.has_method("take_damage"):
		target.take_damage(damage)
	
	# Create impact effect
	create_impact_effect()
	
	# Destroy projectile
	destroy_projectile()
	pass # Replace with function body.
