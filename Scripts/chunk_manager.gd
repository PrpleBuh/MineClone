extends Node3D
class_name ChunkManager

var chunks: Array[Chunk]
var want_load_chunks: Array[Vector2i]

@onready var chunk_builder_thread: Thread = Thread.new()

@onready var instance = self 

func get_chunk_if_loaded(pos: Vector2i) -> Chunk:
	for chunk in chunks:
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

func unload_chunk(pos: Vector2i) -> void:
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
