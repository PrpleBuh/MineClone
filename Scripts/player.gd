extends CharacterBody3D

const SPEED = 5.0
const SPEED_VEC = Vector3.ONE * SPEED
const JUMP_VELOCITY = 4.7
const LATERAL_FRICTION = 0.8
const LATERAL_FRICTION_VEC = Vector3(LATERAL_FRICTION, 1, LATERAL_FRICTION)
const BODY_ROTATION_MAX = 0.4

@onready var camera : Camera3D = $Camera3D
@onready var body: Node3D = $pbody
@onready var cam_resting_pos: Vector3 = camera.position
@onready var chunk_manager: ChunkManager = get_node("../ChunkManager")
@onready var ui: UI = $UI

func _physics_process(delta: float) -> void:
	for x in range(-3, 3):
		for z in range(-3, 3):
			var selected_chunk = chunk_pos() + Vector2i(x, z)
			chunk_manager.get_chunk(selected_chunk)
			chunk_manager.update_occupation(selected_chunk)
	
	if not chunk_manager.is_chunk_loaded(chunk_pos()):
		return
	
	if not is_on_floor():
		velocity += get_gravity() * delta

	if !ui.is_input_blocked():
		if Input.is_action_pressed("jump") && is_on_floor():
			velocity.y = JUMP_VELOCITY
		#if Input.is_action_pressed("crouch"):
			#global_position.y -= JUMP_VELOCITY * delta * 10

	var wish_dir: Vector3 = Vector3(Input.get_axis("left", "right"), 0.0, Input.get_axis("forward", "backward")).normalized()
	var direction = wish_dir.rotated(Vector3.UP, camera.rotation.y) * -SPEED
	
	if ui.is_input_blocked():
		direction = Vector3.ZERO
	
	var vel_y = velocity.y
	velocity.y = 0
	
	velocity = (velocity + direction) * LATERAL_FRICTION_VEC
	
	if velocity.length() > SPEED:
		velocity = velocity.normalized() * SPEED
		body.rotation.y = lerp(body.rotation.y, camera.rotation.y, delta * 10)
			
	velocity.y = vel_y
	
	move_and_slide()
	
	var space_state = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + -camera.global_transform.basis.z * 5)
	var cast = space_state.intersect_ray(query)
	if cast.is_empty(): return
	if Input.is_action_just_pressed("break"):
		var collide_point = cast.get("position") - cast.get("normal") / 3
		chunk_manager.set_block_at(collide_point, Block.Type.AIR)
	if Input.is_action_just_pressed("place"):
		var collide_point = cast.get("position") + cast.get("normal") / 3
		chunk_manager.set_block_at(collide_point, Block.Type.STONE)

func chunk_pos():
	return Vector2i(int(global_position.x / Chunk.CHUNK_WIDTH), int(global_position.z / Chunk.CHUNK_WIDTH))

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if ui.is_input_blocked():
		return
	if event is InputEventMouseMotion:
		var delta = event.relative / -50.0
		camera.rotation += Vector3(delta.y, delta.x, 0)
		camera.position = cam_resting_pos.rotated(Vector3.UP, camera.rotation.y)
		if body.rotation.y > camera.rotation.y + BODY_ROTATION_MAX:
			body.rotation.y = camera.rotation.y + BODY_ROTATION_MAX
		if body.rotation.y < camera.rotation.y - BODY_ROTATION_MAX:
			body.rotation.y = camera.rotation.y - BODY_ROTATION_MAX
		fix_cam_angle()
		#facing = camera.rotation

func cam_angle_invalid() -> bool:
	return camera.rotation_degrees.x > 89 || camera.rotation_degrees.x < -80

func fix_cam_angle() -> void:
	if !cam_angle_invalid(): return
	camera.rotation_degrees.x = 89 if camera.rotation_degrees.x > 89 else -80
