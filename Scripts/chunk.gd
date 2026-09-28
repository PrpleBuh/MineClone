extends Node3D
class_name Chunk

class BlockCullInfo:
	static func is_pos_x_visible(state: int) -> bool:
		return state & 1 != 0
	
	static func is_pos_z_visible(state: int) -> bool:
		return state & 2 != 0
		
	static func is_neg_x_visible(state: int) -> bool:
		return state & 4 != 0
		
	static func is_neg_z_visible(state: int) -> bool:
		return state & 8 != 0
	
	static func is_top_visible(state: int) -> bool:
		return state & 16 != 0
		
	static func is_bottom_visible(state: int) -> bool:
		return state & 32 != 0
		
	static func set_pos_x_visible(state: int, value: bool) -> int:
		if value: return state & 1
		else: return state & ~1
	
	static func set_pos_z_visible(state: int, value: bool) -> int:
		if value: return state & 2
		else: return state & ~2
		
	static func set_neg_x_visible(state: int, value: bool) -> int:
		if value: return state & 4
		else: return state & ~4
		
	static func set_neg_z_visible(state: int, value: bool) -> int:
		if value: return state & 8
		else: return state & ~8
	
	static func set_top_visible(state: int, value: bool) -> int:
		if value: return state & 16
		else: return state & ~16

	static func set_bottom_visible(state: int, value: bool) -> int:
		if value: return state & 32
		else: return state & ~32

static var noise: FastNoiseLite = FastNoiseLite.new()

const CHUNK_WIDTH: int = 16
const CHUNK_HEIGHT: int = 128
const CHUNK_DATA_LEN: int = CHUNK_WIDTH * CHUNK_WIDTH * CHUNK_HEIGHT
const Y_LEVEL_GROUND: int = int(CHUNK_HEIGHT * 0.25)

var chunk_pos: Vector2i = Vector2i.ZERO
var dirty: bool = false
var loaded: bool = false

var mesh_renderer: MeshInstance3D

var block_data: Array[Block.Type] = []
var block_cull_data: Array[int] = []

var last_occupied: int = 0

var chunk_manager: ChunkManager = null

static func __xyz_to_idx(x: int, y: int, z: int) -> int:
	return x + CHUNK_WIDTH * (y + CHUNK_HEIGHT * z)

func set_chunk_manager(manager: ChunkManager) -> void:
	chunk_manager = manager

func set_chunk_pos(pos: Vector2i) -> void:
	chunk_pos = pos
	global_position = chunk_world_pos()

func chunk_world_pos() -> Vector3:
	return Vector3(chunk_pos.x * CHUNK_WIDTH, 0, chunk_pos.y * CHUNK_WIDTH)

func get_noise(pos: Vector2i) -> float:
	var world_pos = chunk_world_pos()
	return (noise.get_noise_2d(pos.x - world_pos.x, pos.y - world_pos.z) + 1) / 2

func generate() -> void:
	var start = Time.get_ticks_usec()
	__fill_no_bounds_checking(0, 0, 0, CHUNK_WIDTH - 1, Y_LEVEL_GROUND, CHUNK_WIDTH - 1, Block.Type.STONE)
	for x in range(0, CHUNK_WIDTH):
		for z in range(0, CHUNK_WIDTH):
			var n_val = get_noise(Vector2i(x, z))
			var block_height: int = int(n_val * (CHUNK_HEIGHT - Y_LEVEL_GROUND) * 0.25 + Y_LEVEL_GROUND)
			var tree_seed = (n_val * 1000)
			tree_seed = tree_seed - floor(tree_seed)
			for y in range(Y_LEVEL_GROUND, (CHUNK_HEIGHT - Y_LEVEL_GROUND) * 0.25 + Y_LEVEL_GROUND):
				var block: Block.Type = Block.Type.AIR
				if y <= block_height:
					if y == block_height: block = Block.Type.GRASS
					elif y > block_height - 5: block = Block.Type.DIRT
					else: block = Block.Type.STONE
				if tree_seed > 0.995:
					if y <= block_height + 5:
						block = Block.Type.OAK_LOG
					elif y <= block_height + 7:
						block = Block.Type.OAK_LEAVES
				__set_block_no_bounds_checking(x, y, z, block)
	dirty = true
	print("Chunk Gen took ", Time.get_ticks_usec() - start, "us")
	loaded = true

func _ready() -> void:
	block_data.resize(CHUNK_DATA_LEN)
	block_data.fill(Block.Type.AIR)
	block_cull_data.resize(CHUNK_DATA_LEN)
	block_cull_data.fill(0xffff)
	mesh_renderer = MeshInstance3D.new()
	add_child(mesh_renderer)

func __fill_no_bounds_checking(x1: int, y1: int, z1: int, x2: int, y2: int, z2: int, block: Block.Type) -> void:
	for x in range(x1, x2 + 1):
		for y in range(y1, y2 + 1):
			for z in range(z1, z2 + 1):
				__set_block_no_bounds_checking(x, y, z, block)

func __set_block_no_bounds_checking(x: int, y: int, z: int, block: Block.Type) -> void:
	var idx = __xyz_to_idx(x, y, z)
	if block_data[idx] == block: return
	
	if Block.from_id(block_data[idx]).transparent != Block.from_id(block).transparent:
		__recalc_cull_info(x, y, z, block)
	
	block_data[idx] = block
	dirty = true

func __set_cull_flag(x: int, y: int, z: int, side_flag: int, value: bool) -> void:
	var chunk = self
	
	if x < 0:
		chunk = chunk_manager.get_chunk_if_loaded(chunk_pos + Vector2i(1, 0))
		x = CHUNK_WIDTH + x
	if x >= CHUNK_WIDTH:
		chunk = chunk_manager.get_chunk_if_loaded(chunk_pos + Vector2i(-1, 0))
		x = x - CHUNK_WIDTH
	if z < 0:
		chunk = chunk_manager.get_chunk_if_loaded(chunk_pos + Vector2i(0, 1))
		z = CHUNK_WIDTH + z
	if z >= CHUNK_WIDTH:
		chunk = chunk_manager.get_chunk_if_loaded(chunk_pos + Vector2i(0, -1))
		z = z - CHUNK_WIDTH
	
	if chunk == null or y < 0 or y >= CHUNK_HEIGHT: return
	
	var idx = __xyz_to_idx(x, y, z)
	
	chunk.block_cull_data[idx] = chunk.block_cull_data[idx] & (side_flag if value else ~side_flag)

func __recalc_cull_info(x: int, y: int, z: int, block: Block.Type) -> void:
	var info = Block.from_id(block)
	__set_cull_flag(x - 1, y, z, 1, info.transparent)
	__set_cull_flag(x, y, z - 1, 2, info.transparent)
	__set_cull_flag(x + 1, y, z, 4, info.transparent)
	__set_cull_flag(x, y, z + 1, 8, info.transparent)
	__set_cull_flag(x, y - 1, z, 16, info.transparent)
	__set_cull_flag(x, y + 1, z, 32, info.transparent)
	

func set_block(x: int, y: int, z: int, block: Block.Type) -> void:
	var chunk: Chunk = self
	
	if x < 0:
		chunk = chunk_manager.get_chunk_if_loaded(chunk_pos + Vector2i(1, 0))
		x = CHUNK_WIDTH + x
	if x >= CHUNK_WIDTH:
		chunk = chunk_manager.get_chunk_if_loaded(chunk_pos + Vector2i(-1, 0))
		x = x - CHUNK_WIDTH
	if z < 0:
		chunk = chunk_manager.get_chunk_if_loaded(chunk_pos + Vector2i(0, 1))
		z = CHUNK_WIDTH + z
	if z >= CHUNK_WIDTH:
		chunk = chunk_manager.get_chunk_if_loaded(chunk_pos + Vector2i(0, -1))
		z = z - CHUNK_WIDTH
	
	if chunk == null or y < 0 or y >= CHUNK_HEIGHT: return
	
	chunk.__set_block_no_bounds_checking(x, y, z, block)

func get_block(x: int, y: int, z: int) -> Block.Type:
	var chunk: Chunk = self
	
	if x < 0:
		chunk = chunk_manager.get_chunk_if_loaded(chunk_pos + Vector2i(1, 0))
		x = CHUNK_WIDTH + x
	if x >= CHUNK_WIDTH:
		chunk = chunk_manager.get_chunk_if_loaded(chunk_pos + Vector2i(-1, 0))
		x = x - CHUNK_WIDTH
	if z < 0:
		chunk = chunk_manager.get_chunk_if_loaded(chunk_pos + Vector2i(0, 1))
		z = CHUNK_WIDTH + z
	if z >= CHUNK_WIDTH:
		chunk = chunk_manager.get_chunk_if_loaded(chunk_pos + Vector2i(0, -1))
		z = z - CHUNK_WIDTH
	
	if chunk == null or y < 0 or y >= CHUNK_HEIGHT: return Block.Type.AIR

	return chunk.block_data[x + CHUNK_WIDTH * (y + CHUNK_HEIGHT * z)]


func get_block_cull(x: int, y: int, z: int) -> int:
	var chunk: Chunk = self
	
	if x < 0:
		chunk = chunk_manager.get_chunk_if_loaded(chunk_pos + Vector2i(1, 0))
		x = CHUNK_WIDTH + x
	if x >= CHUNK_WIDTH:
		chunk = chunk_manager.get_chunk_if_loaded(chunk_pos + Vector2i(-1, 0))
		x = x - CHUNK_WIDTH
	if z < 0:
		chunk = chunk_manager.get_chunk_if_loaded(chunk_pos + Vector2i(0, 1))
		z = CHUNK_WIDTH + z
	if z >= CHUNK_WIDTH:
		chunk = chunk_manager.get_chunk_if_loaded(chunk_pos + Vector2i(0, -1))
		z = z - CHUNK_WIDTH
	
	if chunk == null or y < 0 or y >= CHUNK_HEIGHT: return 0

	return chunk.block_cull_data[x + CHUNK_WIDTH * (y + CHUNK_HEIGHT * z)]


func is_air(x: int, y: int, z: int) -> bool:
	return get_block(x, y, z) == Block.Type.AIR


func rebuild_mesh() -> void:
	var start = Time.get_ticks_usec()
	var mesh = ArrayMesh.new()
	mesh.clear_surfaces()
	var verts : Array[PackedVector3Array] = []
	var uvs : Array[PackedVector2Array] = []
	var normals : Array[PackedVector3Array] = []
	verts.resize(Block.COUNT)
	uvs.resize(Block.COUNT)
	normals.resize(Block.COUNT)
	
	var start_iterate = Time.get_ticks_usec()
	for x in range(0, CHUNK_WIDTH):
		for z in range(0, CHUNK_WIDTH):
			for y in range(0, CHUNK_HEIGHT):
				var block_here = get_block(x, y, z)
				var cull_info = get_block_cull(x, y, z)
				if(block_here == Block.Type.AIR): continue
				
				if(BlockCullInfo.is_bottom_visible(cull_info)):
					verts[block_here].append_array([Vector3(x, y, z + 1), Vector3(x + 1, y, z), Vector3(x, y, z), Vector3(x + 1, y, z), Vector3(x, y, z + 1), Vector3(x + 1, y, z + 1)])
					uvs[block_here].append_array([Vector2(0.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0)])
					normals[block_here].append_array([Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN])
					
				if(BlockCullInfo.is_top_visible(cull_info)):
					verts[block_here].append_array([Vector3(x, y + 1, z), Vector3(x + 1, y + 1, z), Vector3(x, y + 1, z + 1), Vector3(x, y + 1, z + 1), Vector3(x + 1, y + 1, z), Vector3(x + 1, y + 1, z + 1)])
					uvs[block_here].append_array([Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, 1.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0)])
					normals[block_here].append_array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
					
				if(BlockCullInfo.is_neg_z_visible(cull_info)):
					verts[block_here].append_array([Vector3(x + 1, y, z), Vector3(x + 1, y + 1, z), Vector3(x, y, z), Vector3(x + 1, y + 1, z), Vector3(x, y + 1, z), Vector3(x, y, z)])
					uvs[block_here].append_array([Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0), Vector2(0.0, 0.0)])
					normals[block_here].append_array([Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD])

				if(BlockCullInfo.is_pos_z_visible(cull_info)):
					verts[block_here].append_array([Vector3(x, y, z + 1), Vector3(x + 1, y + 1, z + 1), Vector3(x + 1, y, z + 1), Vector3(x, y, z + 1), Vector3(x, y + 1, z + 1), Vector3(x + 1, y + 1, z + 1)])
					uvs[block_here].append_array([Vector2(0.0, 0.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0)])
					normals[block_here].append_array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
					
				if(BlockCullInfo.is_neg_x_visible(cull_info)):
					verts[block_here].append_array([Vector3(x, y, z), Vector3(x, y + 1, z + 1), Vector3(x, y, z + 1), Vector3(x, y, z), Vector3(x, y + 1, z), Vector3(x, y + 1, z + 1)])
					uvs[block_here].append_array([Vector2(0.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0)])
					normals[block_here].append_array([Vector3.LEFT, Vector3.LEFT, Vector3.LEFT, Vector3.LEFT, Vector3.LEFT, Vector3.LEFT])

				if(BlockCullInfo.is_pos_x_visible(cull_info)):
					verts[block_here].append_array([Vector3(x + 1, y, z + 1), Vector3(x + 1, y + 1, z + 1), Vector3(x + 1, y, z), Vector3(x + 1, y + 1, z + 1), Vector3(x + 1, y + 1, z), Vector3(x + 1, y, z)])
					uvs[block_here].append_array([Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0)])
					normals[block_here].append_array([Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT])

	print("Chunk Iteration took ", Time.get_ticks_usec() - start_iterate, "us")

	var start_generate = Time.get_ticks_usec()
	for i in range(Block.COUNT):
		if verts[i].is_empty(): continue
		
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts[i]
		arrays[Mesh.ARRAY_TEX_UV] = uvs[i]
		arrays[Mesh.ARRAY_NORMAL] = normals[i]
		
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, Block.from_id(i).material)
	
	print("Chunk Mesh Creation took ", Time.get_ticks_usec() - start_generate, "us")
	
	mesh_renderer.set_deferred_thread_group("mesh", mesh)
	print("Chunk Mesh Gen took ", Time.get_ticks_usec() - start, "us")
