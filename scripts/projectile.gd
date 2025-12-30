extends RigidBody3D

@export var speed := 45.0
@export var damage := 10
@export var lifetime := 3.0
var hit_dir = linear_velocity.normalized()

func launch(direction: Vector3) -> void:
	set_as_top_level(true)
	linear_velocity = direction * speed
	
	await get_tree().create_timer(lifetime).timeout
	queue_free()
	
	
func _on_body_entered(body: Node) -> void:
	if body and body.has_method("take_damage"):
		body.take_damage(damage, hit_dir)
		
	queue_free()
