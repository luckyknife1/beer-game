extends CharacterBody3D

@export var move_speed := 4.0
@export var gravity := 9.8
@export var attack_range := 1.8

@export var max_health := 90
var health := max_health
var is_dead := false

var player: CharacterBody3D
var chasing := false

@onready var detection: Area3D = $Detection

@export var attack_damage := 20
@export var attack_cooldown := 1.0
var attack_timer := 0.0

@onready var beer_bar := get_tree().current_scene.get_node("SubViewportContainer/SubViewport/UI/BeerBar")

func _ready():
	player = get_tree().get_first_node_in_group("Player")
	detection.body_entered.connect(_on_body_entered)
	detection.body_exited.connect(_on_body_exited)
	
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# --- Gravity ---
	if not is_on_floor():
		velocity.y -= gravity * delta

	# --- Attack cooldown ---
	attack_timer -= delta

	if player == null:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if chasing:
		var to_player: Vector3 = player.global_position - global_position
		var distance: float = to_player.length()

		if distance > attack_range:
			var dir: Vector3 = to_player.normalized()
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed

			# Face player (Y-axis only)
			look_at(
				Vector3(player.global_position.x, global_position.y, player.global_position.z),
				Vector3.UP
			)
		else:
			velocity.x = 0.0
			velocity.z = 0.0

			if attack_timer <= 0.0:
				attack_timer = attack_cooldown

				get_tree().call_group(
					"Player",
					"take_damage",
					attack_damage,
					to_player.normalized()
				)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()


func _on_body_entered(body):
	if body.is_in_group("Player"):
		chasing = true

func _on_body_exited(body):
	if body.is_in_group("Player"):
		chasing = false

func take_damage(amount: int, hit_dir: Vector3) -> void:
	if is_dead:
		return

	health -= amount
	velocity += hit_dir.normalized() * 6.0
	velocity.y = 2.0

	if health <= 0:
		die()

func die():
	if beer_bar:
		beer_bar.add_beer(20)
	
	is_dead = true
	$"test dummy".visible = false
	await get_tree().create_timer(0.2).timeout
	queue_free()
