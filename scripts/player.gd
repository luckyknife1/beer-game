extends CharacterBody3D

# ================== NODES ==================
@onready var head: Node3D = $Head
@onready var recoil_pivot: Node3D = $Head/RecoilPivot
@onready var standing_collisionshape: CollisionShape3D = $standing_collisionshape
@onready var crouching_collisionshape: CollisionShape3D = $crouching_collisionshape
@onready var ray_cast_3d: RayCast3D = $RayCast3D

# ================== HEALTH ==================
@export var max_health := 100
var health := max_health
var is_dead := false

# ================== MOVEMENT ==================
@export var walking_speed := 10.0
@export var sprinting_speed := 16.0
const CROUCHING_SPEED := 2.5
@export var gravity := 12.8
@export var jump := 7.5

var current_speed := walking_speed
var direction := Vector3.ZERO
var lerp_speed := 10.0

# ================== LOOK ==================
@export var mouse_sens := 0.25

# ================== CROUCH / SLIDE ==================
const STAND_HEAD_Y := 1.6
const CROUCH_DEPTH := -1.0

var is_crouching := false
var is_sliding := false
var slide_timer := 0.0
@export var slide_duration := 0.6
@export var slide_speed := 16.0

# ================== COMBAT ==================
@export var projectile_scene: PackedScene
@export var fire_rate := 0.5
var fire_timer := 0.0
var base_fire_rate := 0.5

# ================== BEER / BUFF ==================
var buff_active := false
var buff_timer := 0.0
const BUFF_DURATION := 15.0
const BUFF_SPEED_MULT := 1.4
const BUFF_FIRE_RATE_MULT := 0.6

# ================== BEER STATE ==================
enum BeerState { SOBER, DRUNK, GOD }
var beer_state := BeerState.SOBER

# ================== CAMERA SWAY ==================
var drunk_time := 0.0
@export var sway_strength := 3.0
@export var sway_speed := 2.6

# ================== CAMERA TILT ==================
@export var tilt_strength := 0.015   # how much it leans
@export var tilt_return_speed := 8.0 # how fast it recenters

var target_tilt := 0.0

# ================== GOD MODE ==================
var god_mode := false
var god_timer := 0.0
const GOD_DURATION := 9.0
const GOD_CHANCE := 0.75

# ================== UI ==================
@export var death_screen_scene: PackedScene
@onready var chromatic_rect := get_tree().get_first_node_in_group("Chromatic")

# ================== RECOIL ==================
@export var recoil_kick := 4.0
@export var recoil_return := 12.0
@export var recoil_side := 0.15

var recoil := Vector2.ZERO

# =====================================================
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	base_fire_rate = fire_rate
	update_visual_effects()

	var beer_bar = get_tree().get_first_node_in_group("BeerBar")
	if beer_bar:
		beer_bar.beer_redeemed.connect(_on_beer_redeemed)

# =====================================================
func _input(event) -> void:
	if event.is_action_pressed("redeem_beer"):
		var beer_bar = get_tree().get_first_node_in_group("BeerBar")
		if beer_bar:
			beer_bar.redeem()
		
	if is_dead and event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
		return
		
	if event is InputEventMouseMotion and not is_dead:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
		head.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
		head.rotation.x = clamp(head.rotation.x,deg_to_rad(-80),deg_to_rad(80))
		
		# --- CAMERA TILT INPUT ---
		target_tilt = clamp(-event.relative.x * tilt_strength,-0.25,0.25)
		
# =====================================================
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# ---------- FIRE ----------
	fire_timer -= delta
	if Input.is_action_pressed("attack") and fire_timer <= 0.0:
		fire_timer = fire_rate
		_fire_projectile()
		apply_recoil()

	# ---------- SLIDE ----------
	if is_sliding:
		slide_timer -= delta
		current_speed = slide_speed
		if slide_timer <= 0.0:
			is_sliding = false

	elif Input.is_action_just_pressed("slide") and is_on_floor():
		is_sliding = true
		slide_timer = slide_duration

		var slide_input := Input.get_vector("left", "right", "forward", "backward")
		if slide_input.length() == 0:
			slide_input = Vector2(0, -1)

		direction = (transform.basis * Vector3(slide_input.x, 0, slide_input.y)).normalized()
		velocity.x = direction.x * slide_speed
		velocity.z = direction.z * slide_speed

	# ---------- CROUCH ----------
	is_crouching = is_sliding or Input.is_action_pressed("crouch") or ray_cast_3d.is_colliding()

	# ---------- SPEED ----------
	current_speed = walking_speed
	if is_crouching:
		current_speed = CROUCHING_SPEED
	elif Input.is_action_pressed("sprint"):
		current_speed = sprinting_speed

	if buff_active:
		current_speed *= BUFF_SPEED_MULT

	# ---------- HEAD HEIGHT ----------
	var target_head_y := STAND_HEAD_Y
	if is_crouching:
		target_head_y += CROUCH_DEPTH
		crouching_collisionshape.disabled = false
		standing_collisionshape.disabled = true
	else:
		crouching_collisionshape.disabled = true
		standing_collisionshape.disabled = false

	head.position.y = move_toward(head.position.y, target_head_y, delta * lerp_speed)

	# ---------- CAMERA SWAY ----------
	if buff_active:
		drunk_time += delta
		head.rotation.z = deg_to_rad(sin(drunk_time * sway_speed) * sway_strength)
	else:
		drunk_time = 0.0
		head.rotation.z = lerp(head.rotation.z, 0.0, delta * 6.0)

# ---------- CAMERA TILT APPLY ----------
	head.rotation.z = lerp(head.rotation.z,target_tilt,delta * tilt_return_speed)
		# Slowly decay target so it recenters
	target_tilt = lerp(target_tilt, 0.0, delta * tilt_return_speed)
	
	# ---------- GRAVITY / JUMP ----------
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_sliding:
		velocity.y = jump

	# ---------- MOVE ----------
	if not is_sliding:
		var input_dir := Input.get_vector("left", "right", "forward", "backward")
		var desired_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		direction = direction.lerp(desired_dir, delta * lerp_speed)

		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed

	move_and_slide()

	# ---------- BUFF TIMER ----------
	if buff_active:
		buff_timer -= delta
		if buff_timer <= 0:
			end_buff()

	# ---------- GOD TIMER ----------
	if god_mode:
		god_timer -= delta
		if god_timer <= 0:
			exit_god_mode()

	# ---------- RECOIL UPDATE ----------
	recoil = recoil.lerp(Vector2.ZERO, recoil_return * delta)
	recoil_pivot.rotation.x = -recoil.y
	recoil_pivot.rotation.y = recoil.x

# =====================================================
func _fire_projectile() -> void:
	if projectile_scene == null:
		return

	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)

	var muzzle := get_node_or_null("Head/RecoilPivot/Camera3D/GunMuzzle")
	if muzzle == null:
		return

	projectile.global_transform = muzzle.global_transform
	projectile.launch(muzzle.global_transform.basis.z)

# =====================================================
func apply_recoil():
	recoil.y += deg_to_rad(recoil_kick)
	recoil.x += deg_to_rad(randf_range(-recoil_side, recoil_side))

# =====================================================
func take_damage(amount: int, hit_dir: Vector3) -> void:
	if is_dead:
		return

	health -= amount
	velocity += hit_dir.normalized() * 6.0
	velocity.y = 2.0

	if health <= 0:
		die()

# =====================================================
func die() -> void:
	is_dead = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var death_screen = death_screen_scene.instantiate()
	get_tree().current_scene.add_child(death_screen)
	set_physics_process(false)

# =====================================================
# ================= BEER LOGIC ========================
# =====================================================
func _on_beer_redeemed():
	start_buff()

func start_buff():
	buff_active = true
	buff_timer = BUFF_DURATION
	fire_rate = base_fire_rate * BUFF_FIRE_RATE_MULT
	beer_state = BeerState.DRUNK

	if randf() < GOD_CHANCE:
		enter_god_mode()

	update_visual_effects()

func end_buff():
	buff_active = false
	fire_rate = base_fire_rate
	beer_state = BeerState.SOBER
	update_visual_effects()

# =====================================================
# ================= GOD MODE ==========================
# =====================================================
func enter_god_mode():
	god_mode = true
	god_timer = GOD_DURATION
	beer_state = BeerState.GOD

	get_tree().call_group("TimeAffected", "set_physics_process", false)
	get_tree().call_group("TimeAffected", "set_process", false)

	update_visual_effects()

func exit_god_mode():
	god_mode = false
	beer_state = BeerState.SOBER

	get_tree().call_group("TimeAffected", "set_physics_process", true)
	get_tree().call_group("TimeAffected", "set_process", true)

	update_visual_effects()

# =====================================================
func update_visual_effects():
	var crosshatch = get_tree().get_first_node_in_group("Crosshatch")
	var posterize = get_tree().get_first_node_in_group("Posterize")

	if chromatic_rect:
		chromatic_rect.visible = (beer_state == BeerState.DRUNK)

	if crosshatch:
		crosshatch.visible = (beer_state != BeerState.GOD)

	if posterize:
		posterize.visible = (beer_state == BeerState.GOD)
