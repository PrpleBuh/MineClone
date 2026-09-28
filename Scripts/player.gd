extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.7

@onready var camera : Camera3D = $pbody/neck/head/Camera3D

func _physics_process(delta: float) -> void:
	## Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (Vector3 (input_dir.x, 0, input_dir.y).normalized() * SPEED).rotated(Vector3.UP, camera.global_rotation.y)
	var vel_y = velocity.y
	velocity.y = 0
	velocity = (velocity + direction).clamp(Vector3.ONE * -SPEED, Vector3.ONE * SPEED)
	velocity *= Vector3 (0.8, 1, 0.8)
	velocity.y = vel_y
	move_and_slide()


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var delta = event.relative / -50.0
		camera.rotation += Vector3(delta.y, delta.x, 0)
		fix_cam_angle()
		#facing = camera.rotation

func cam_angle_invalid() -> bool:
	return camera.rotation_degrees.x > 89 || camera.rotation_degrees.x < -80

func fix_cam_angle() -> void:
	if !cam_angle_invalid(): return
	camera.rotation_degrees.x = 89 if camera.rotation_degrees.x > 89 else -80
