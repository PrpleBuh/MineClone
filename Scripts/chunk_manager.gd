extends Node3D
class_name ChunkManager

var chunks: Array[Chunk]
var want_load_chunks: Array[Vector2i]

@onready var chunk_builder_thread: Thread = Thread.new()

@onready var instance = self 

func get_chunk_if_loaded(pos: Vector2i) -> Chunk:
	for chunk in chunks:
		if !is_instance_valid(chunk): continue
		if chunk.chunk_pos == pos:
			return chunk
	return null

func get_chunk(pos: Vector2i) -> Chunk:
	var chunk = get_chunk_if_loaded(pos)
	if chunk != null:
		return chunk
	chunk = Chunk.new()
	chunk.loaded = false
	add_child(chunk)
	chunk.set_chunk_manager(self)
	chunk.set_chunk_pos(pos)
	chunks.append(chunk)
	want_load_chunks.append(pos)
	return null

static func chunk_coords_at(pos: Vector3) -> Vector2i:
	@warning_ignore("integer_division")
	var x_neg = pos.x < 0
	var z_neg = pos.z < 0
	var coords = Vector2i(absi(int(pos.x / Chunk.CHUNK_WIDTH)), absi(int(pos.z / Chunk.CHUNK_WIDTH)))
	if x_neg:
		coords.x *= -1
		#coords.x -= 1
	if z_neg:
		coords.y *= -1
		#coords.y -= 1
	return coords

func get_block(x: int, y: int, z: int) -> Block.Type:
	@warning_ignore("integer_division")
	var chunk_coords = Vector2i(x, z) / Chunk.CHUNK_WIDTH
	if !is_chunk_loaded(chunk_coords): return Block.Type.STONE
	return get_chunk_if_loaded(chunk_coords).get_block(x % Chunk.CHUNK_WIDTH, y, z % Chunk.CHUNK_WIDTH)

func get_block_at(pos: Vector3) -> Block.Type:
	var chunk_coords = Vector2i(int(pos.x / Chunk.CHUNK_WIDTH), int(pos.z / Chunk.CHUNK_WIDTH))
	if !is_chunk_loaded(chunk_coords): return Block.Type.STONE
	return get_chunk_if_loaded(chunk_coords).get_block(int(pos.x) % Chunk.CHUNK_WIDTH, int(pos.y), int(pos.z) % Chunk.CHUNK_WIDTH)

func set_block_at(pos: Vector3, type: Block.Type) -> void:
	var chunk_coords = chunk_coords_at(pos)
	var chunk_pos = chunk_coords * Chunk.CHUNK_WIDTH
	if !is_chunk_loaded(chunk_coords): return
	var block_pos_in_chunk = Vector3i(int(pos.x - chunk_pos.x), int(pos.y), int(pos.z - chunk_pos.y))
	if pos.x < 0:
		block_pos_in_chunk.x -= 2
	if pos.z < 0:
		block_pos_in_chunk.z -= 2
	return get_chunk_if_loaded(chunk_coords).set_block(block_pos_in_chunk.x, block_pos_in_chunk.y, block_pos_in_chunk.z, type)

func generate_chunk(pos: Vector2i) -> void:
	var chunk = get_chunk_if_loaded(pos)
	if chunk == null: return
	chunk.generate()
	
func _ready() -> void:
	chunk_builder_thread.start(_chunk_rebuild)

func _process(_delta: float) -> void:
	for chunk in chunks:
		if Time.get_ticks_msec() - chunk.last_occupied > 50:
			unload_chunk.call_deferred(chunk.chunk_pos)
	if Input.is_action_just_pressed("test"):
		var chunk = get_chunk(Vector2i(0, 0))
		chunk.__fill_no_bounds_checking(0, 0, 0, 0, Chunk.CHUNK_HEIGHT - 1, 0, Block.Type.STONE)
		chunk = get_chunk(Vector2i(1, 1))
		chunk.__fill_no_bounds_checking(0, 0, 0, 0, Chunk.CHUNK_HEIGHT - 1, 0, Block.Type.STONE)
		chunk = get_chunk(Vector2i(-1, -1))
		chunk.__fill_no_bounds_checking(Chunk.CHUNK_WIDTH - 1, 0, Chunk.CHUNK_WIDTH - 1, Chunk.CHUNK_WIDTH - 1, Chunk.CHUNK_HEIGHT - 1, Chunk.CHUNK_WIDTH - 1, Block.Type.STONE)

func unload_chunk(pos: Vector2i) -> void:
	return
	@warning_ignore("unreachable_code")
	var chunk = get_chunk_if_loaded(pos)
	if chunk == null: return
	chunk.queue_free()
	chunks.erase(chunk)

func update_occupation(pos: Vector2i) -> void:
	var chunk = get_chunk_if_loaded(pos)
	if chunk == null: return
	chunk.last_occupied = Time.get_ticks_msec()

func is_chunk_loaded(pos: Vector2i) -> bool:
	for chunk in chunks:
		if chunk.chunk_pos == pos:
			return chunk.loaded
	return false

func _chunk_rebuild() -> void:
	var should_quit = false
	while not should_quit:
		for to_load in instance.want_load_chunks:
			if instance.is_chunk_loaded(to_load): continue
			generate_chunk(to_load)
		for chunk in instance.chunks:
			if chunk.loaded:
				instance.want_load_chunks.erase(chunk.chunk_pos)
			if chunk.dirty:
				chunk.rebuild_mesh()
				chunk.dirty = false
				break
