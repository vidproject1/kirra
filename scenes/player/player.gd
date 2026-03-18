extends CharacterBody3D

# --- Constants & Exported Variables ---

@export_group("Movement")
@export var speed_walk: float = 5.0
@export var speed_sprint: float = 8.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 16.0
@export var sensitivity: float = 0.003

@export_group("FOV Settings")
@export var fov_default: float = 75.0
@export var fov_ads: float = 55.0
@export var fov_sprint: float = 85.0
@export var ads_lerp: float = 30.0

@export_group("Recoil")
@export var recoil_vertical: float = 0.15
@export var recoil_horizontal: float = 0.02
@export var recoil_snappiness: float = 25.0
@export var recoil_return_speed: float = 10.0
@export var ads_recoil_multiplier: float = 0.5

@export_group("Head Bob & Sway")
@export var bob_freq: float = 2.0
@export var bob_amp: float = 0.08
@export var sway_lerp: float = 10.0
@export var sway_max: float = 0.1

@export_group("Leaning")
@export var lean_angle: float = 12.0
@export var lean_offset: float = 0.35
@export var lean_speed: float = 8.0

# --- State Variables ---

var t_bob: float = 0.0
var mouse_input: Vector2 = Vector2.ZERO
var arms_initial_pos: Vector3

# Recoil State
var target_recoil: Vector3 = Vector3.ZERO
var current_recoil: Vector3 = Vector3.ZERO

var lean_target: float = 0.0
var current_lean: float = 0.0

# --- Onready Variables ---

@onready var recoil_pivot: Node3D = $RecoilPivot
@onready var camera: Camera3D = $RecoilPivot/Camera3D
@onready var arms: Node3D = $RecoilPivot/Camera3D/Arms
@onready var gun: Node3D = $RecoilPivot/Camera3D/Arms/GunAssembly
@onready var ads_marker: Marker3D = $RecoilPivot/Camera3D/ADSMarker

# --- Lifecycle Methods ---

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera.fov = fov_default
	if arms:
		arms_initial_pos = arms.transform.origin

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_mouse_look(event.relative)
	
	if event.is_action_pressed("shoot"):
		_apply_recoil()
	
	_handle_lean_input(event)

func _physics_process(delta: float) -> void:
	_handle_movement(delta)

func _process(delta: float) -> void:
	var is_sprinting = _is_sprinting()
	var is_ads = Input.is_action_pressed("ads")
	
	_update_recoil(delta)
	_update_lean(delta)
	_update_camera_fov(delta, is_ads, is_sprinting)
	_update_animations(delta, is_ads, is_sprinting)

# --- Logic Modules ---

func _handle_mouse_look(relative: Vector2) -> void:
	rotate_y(-relative.x * sensitivity)
	camera.rotate_x(-relative.y * sensitivity)
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	mouse_input = relative

func _handle_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var is_sprinting = _is_sprinting()
	var current_speed = speed_sprint if is_sprinting else speed_walk
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()

func _is_sprinting() -> bool:
	return Input.is_action_pressed("sprint") and is_on_floor() and Input.is_action_pressed("move_forward")

func _handle_lean_input(event: InputEvent) -> void:
	if event.is_action_pressed("lean_left"):
		lean_target = -1.0 if lean_target != -1.0 else 0.0
	elif event.is_action_pressed("lean_right"):
		lean_target = 1.0 if lean_target != 1.0 else 0.0

func _update_lean(delta: float) -> void:
	current_lean = lerp(current_lean, lean_target, delta * lean_speed)
	camera.rotation.z = lerp_angle(camera.rotation.z, deg_to_rad(-current_lean * lean_angle), delta * lean_speed)
	recoil_pivot.transform.origin.x = lerp(recoil_pivot.transform.origin.x, current_lean * lean_offset, delta * lean_speed)

func _update_recoil(delta: float) -> void:
	target_recoil = target_recoil.lerp(Vector3.ZERO, recoil_return_speed * delta)
	current_recoil = current_recoil.lerp(target_recoil, recoil_snappiness * delta)
	recoil_pivot.rotation.x = current_recoil.x
	recoil_pivot.rotation.y = current_recoil.y
	recoil_pivot.rotation.z = current_recoil.z

func _apply_recoil() -> void:
	if gun and gun.has_method("shoot"):
		gun.shoot()
	
	var mult = ads_recoil_multiplier if Input.is_action_pressed("ads") else 1.0
	target_recoil.x += recoil_vertical * mult
	target_recoil.y += randf_range(-recoil_horizontal, recoil_horizontal) * mult
	target_recoil.z += randf_range(-recoil_horizontal, recoil_horizontal) * 0.5 * mult

func _update_camera_fov(delta: float, is_ads: bool, is_sprinting: bool) -> void:
	var target_fov = fov_default
	if is_ads: target_fov = fov_ads
	elif is_sprinting: target_fov = fov_sprint
	camera.fov = lerp(camera.fov, target_fov, delta * ads_lerp)

func _update_animations(delta: float, is_ads: bool, is_sprinting: bool) -> void:
	var speed_factor = velocity.length() if is_on_floor() else 0.0
	t_bob += delta * speed_factor
	
	var bob_pos = _calculate_bob(t_bob, is_ads, is_sprinting)
	var sway_pos = _calculate_sway(is_ads)
	
	camera.transform.origin.x = bob_pos.x * 0.5
	camera.transform.origin.y = bob_pos.y * 0.5
	
	var base_target = ads_marker.transform.origin if is_ads else arms_initial_pos
	var final_target = base_target
	final_target.x += bob_pos.x * 0.1 + sway_pos.x
	final_target.y += bob_pos.y * 0.2 + sway_pos.y
	final_target.z += current_recoil.x * 0.5 
	
	arms.transform.origin = arms.transform.origin.lerp(final_target, delta * ads_lerp)
	mouse_input = Vector2.ZERO

func _calculate_bob(time: float, is_ads: bool, is_sprinting: bool) -> Vector3:
	var bob_factor = 0.2 if is_ads else (1.5 if is_sprinting else 1.0)
	var pos = Vector3.ZERO
	pos.y = sin(time * bob_freq) * bob_amp * bob_factor
	pos.x = cos(time * bob_freq / 2.0) * bob_amp * bob_factor
	return pos

func _calculate_sway(is_ads: bool) -> Vector2:
	var sway_factor = 0.2 if is_ads else 1.0
	var target_sway = Vector2.ZERO
	target_sway.x = clamp(-mouse_input.x * 0.0005 * sway_factor, -sway_max, sway_max)
	target_sway.y = clamp(mouse_input.y * 0.0005 * sway_factor, -sway_max, sway_max)
	return target_sway
