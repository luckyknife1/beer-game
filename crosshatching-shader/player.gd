extends CharacterBody3D

@onready var head: Node3D = $Head
@onready var standing_collisionshape: CollisionShape3D = $standing_collisionshape
@onready var crouching_collisionshape: CollisionShape3D = $crouching_collisionshape
@onready var ray_cast_3d: RayCast3D = $RayCast3D

# --- MOVEMENT ---
var current_speed := 5.0
var walking_speed := 5.0
var sprinting_speed := 12.0
const crouching_speed := 2.5
var jump := 4.5
@export var gravity := 9.8

# --- LOOK ---
@export var mouse_sens := 0.25
var direction := Vector3.ZERO
var lerp_speed := 10.0

# --- CROUCH / SLIDE ---
const STAND_HEAD_Y := 1.6
const crouching_depth := -1.0
var is_crouching := false

var is_sliding := false
var slide_timer := 0.0
@export var slide_duration := 0.6
@export var slide_speed := 16.0

# --- COMBAT ---
@export var projectile_scene: PackedScene
@export var fire_rate := 0.15
var fire_timer := 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event) -> void:
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _physics_process(delta: float) -> void:
	# ---------------- FIRE ----------------
	fire_timer -= delta
	if Input.is_action_pressed("attack") and fire_timer <= 0.0:
		fire_timer = fire_rate
		_fire_projectile()

	# ---------------- SLIDE ----------------
	if is_sliding:
		slide_timer -= delta
		current_speed = slide_speed

		if slide_timer <= 0.0:
			is_sliding = false

	elif Input.is_action_just_pressed("slide") and is_on_floor():
		is_sliding = true
		slide_timer = slide_duration

		var slide_input := Input.get_vector("left", "right", "forward", "backward")
		if slide_input.length() == 0.0:
			slide_input = Vector2(0, -1)

		direction = (transform.basis * Vector3(slide_input.x, 0, slide_input.y)).normalized()

		velocity.x = direction.x * slide_speed
		velocity.z = direction.z * slide_speed

	# ---------------- CROUCH STATE ----------------
	if is_sliding:
		is_crouching = true
	elif Input.is_action_pressed("crouch"):
		is_crouching = true
	elif ray_cast_3d.is_colliding():
		is_crouching = true
	else:
		is_crouching = false

	# ---------------- SPEED ----------------
	if is_crouching:
		current_speed = crouching_speed
	elif Input.is_action_pressed("sprint"):
		current_speed = sprinting_speed
	else:
		current_speed = walking_speed

	# ---------------- HEAD HEIGHT ----------------
	var target_head_y := STAND_HEAD_Y
	if is_crouching:
		target_head_y += crouching_depth
		crouching_collisionshape.disabled = false
		standing_collisionshape.disabled = true
	else:
		crouching_collisionshape.disabled = true
		standing_collisionshape.disabled = false

	head.position.y = move_toward(
		head.position.y,
		target_head_y,
		delta * lerp_speed
	)

	# ---------------- GRAVITY & JUMP ----------------
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_sliding:
		velocity.y = jump

	# ---------------- MOVE ----------------
	if not is_sliding:
		var input_dir := Input.get_vector("left", "right", "forward", "backward").normalized()
		var desired_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		direction = direction.lerp(desired_dir, delta * lerp_speed)
		
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed

	move_and_slide()

# ---------------- PROJECTILE ----------------
func _fire_projectile() -> void:
	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	
	var muzzle := get_node_or_null("Head/Camera3D/GunMuzzle")
	if muzzle == null:
		return
	
	projectile.global_transform = muzzle.global_transform
	
	# THIS is the important line
	projectile.launch(muzzle.global_transform.basis.z)
