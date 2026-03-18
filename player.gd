extends CharacterBody3D

const SPEED_WALK = 5.0
const SPEED_SPRINT = 8.0
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.003

# Head bobbing and sway constants
const BOB_FREQ = 2.0
const BOB_AMP = 0.08
var t_bob = 0.0

const SWAY_LERP = 5.0
const SWAY_MAX = 0.1
var mouse_input = Vector2.ZERO

# ADS Constants
@export var ads_lerp = 15.0
@export var fov_default = 75.0
@export var fov_ads = 55.0
@export var fov_sprint = 85.0

# Recoil Settings (Tuned for Vertical Punch)
@export_group("Recoil")
@export var recoil_vertical = 0.35      # Kicks Up
@export var recoil_horizontal = 0.05
@export var recoil_snappiness = 30.0
@export var recoil_return_speed = 8.0
@export var recoil_hold_time = 0.15     # 150ms gap
@export var ads_recoil_multiplier = 0.5 

var recoil_target_rot = Vector3.ZERO
var current_recoil_rot = Vector3.ZERO
var recoil_timer = 0.0

# Custom gravity for a snappy feel
var gravity = 16.0

@onready var recoil_pivot = $RecoilPivot
@onready var camera = $RecoilPivot/Camera3D
@onready var arms = $RecoilPivot/Camera3D/Arms
@onready var ads_marker = $RecoilPivot/Camera3D/ADSMarker

@onready var arms_initial_pos = arms.transform.origin

func _ready():
	print("Player ready")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera.fov = fov_default

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		# Player handles Y look (horizontal)
		rotate_y(-event.relative.x * SENSITIVITY)
		# Camera handles X look (vertical)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		mouse_input = event.relative
	
	if event.is_action_pressed("shoot"):
		_apply_recoil()

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var is_sprinting = Input.is_action_pressed("sprint") and is_on_floor() and Input.is_action_pressed("move_forward")
	var current_speed = SPEED_SPRINT if is_sprinting else SPEED_WALK
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
	
	# RECOIL LOGIC (ON SEPARATE PIVOT)
	if recoil_timer > 0:
		recoil_timer -= delta
		# Lock at the peak during the hold phase
		current_recoil_rot = recoil_target_rot 
	else:
		# Return phase
		recoil_target_rot = lerp(recoil_target_rot, Vector3.ZERO, delta * recoil_return_speed)
		current_recoil_rot = lerp(current_recoil_rot, recoil_target_rot, delta * recoil_snappiness)
	
	# Apply recoil to the RECOIL PIVOT node (Subtract X to kick UP)
	recoil_pivot.rotation.x = -current_recoil_rot.x
	recoil_pivot.rotation.y = current_recoil_rot.y
	recoil_pivot.rotation.z = current_recoil_rot.z
	
	t_bob += delta * velocity.length() * float(is_on_floor())
	_handle_bob(t_bob, is_sprinting)
	_handle_sway(delta)
	_handle_ads(delta, is_sprinting)

func _handle_bob(time, is_sprinting):
	var pos = Vector3.ZERO
	var bob_factor = 1.0
	if Input.is_action_pressed("ads"):
		bob_factor = 0.2
	elif is_sprinting:
		bob_factor = 1.5
	
	pos.y = sin(time * BOB_FREQ) * BOB_AMP * bob_factor
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP * bob_factor
	
	camera.transform.origin.y = pos.y * 0.5
	camera.transform.origin.x = pos.x * 0.5
	
	return pos

func _handle_sway(delta):
	var target_sway = Vector2.ZERO
	var sway_factor = 0.2 if Input.is_action_pressed("ads") else 1.0
	target_sway.x = clamp(-mouse_input.x * 0.0005 * sway_factor, -SWAY_MAX, SWAY_MAX)
	target_sway.y = clamp(mouse_input.y * 0.0005 * sway_factor, -SWAY_MAX, SWAY_MAX)
	mouse_input = Vector2.ZERO
	return target_sway

func _handle_ads(delta, is_sprinting):
	var is_ads = Input.is_action_pressed("ads")
	var target_pos = ads_marker.transform.origin if is_ads else arms_initial_pos
	
	var target_fov = fov_default
	if is_ads:
		target_fov = fov_ads
	elif is_sprinting:
		target_fov = fov_sprint
	
	camera.fov = lerp(camera.fov, target_fov, delta * ads_lerp)
	
	var bob_pos = _handle_bob(t_bob, is_sprinting)
	var sway_pos = _handle_sway(delta)
	
	var final_target = target_pos
	final_target.x += bob_pos.x * 0.1 + sway_pos.x
	final_target.y += bob_pos.y * 0.2 + sway_pos.y
	
	# Add visual recoil "thump" to the arms model position
	final_target.z += current_recoil_rot.x * 1.0
	
	arms.transform.origin = arms.transform.origin.lerp(final_target, delta * ads_lerp)

func _apply_recoil():
	var mult = ads_recoil_multiplier if Input.is_action_pressed("ads") else 1.0
	
	recoil_target_rot.x = randf_range(recoil_vertical, recoil_vertical * 1.3) * mult
	recoil_target_rot.y = randf_range(-recoil_horizontal, recoil_horizontal) * mult
	recoil_target_rot.z = randf_range(-recoil_horizontal * 0.5, recoil_horizontal * 0.5) * mult
	
	recoil_timer = recoil_hold_time
	# Force current recoil to target immediately for that "snap" feel
	current_recoil_rot = recoil_target_rot
