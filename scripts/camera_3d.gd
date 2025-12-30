extends Camera3D

# Camera Field of View (FOV)
const HIP_FIRE_FOV = 70
const ADS_FOV = 40

# Manually-defined positions for the camera
const HIP_FIRE_POSITION = Vector3(0, 0.6, 0)  # Default position (standing)
const ADS_POSITION = Vector3(0, 1.2, -0.5)  # ADS position (closer to the gun)

# Aiming state variable
var is_aiming = false

# Called once per frame to detect aiming input
func _process(_delta):
	if Input.is_action_pressed("aim"):
		if not is_aiming:
			is_aiming = true
			update_camera_state()
	else:
		if is_aiming:
			is_aiming = false
			update_camera_state()

# Update the camera's position and FOV based on aiming state
func update_camera_state():
	if is_aiming:
		print("Switching to ADS position!")
		transform.origin = ADS_POSITION  # Move the camera to the aim position
		fov = ADS_FOV                     # Narrow the field of view (zoom in)
	else:
		print("Switching to Hip Fire position!")
		transform.origin = HIP_FIRE_POSITION  # Move the camera back to default
		fov = HIP_FIRE_FOV                      # Widen the field of view
