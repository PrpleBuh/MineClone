extends Node
class_name Block

const COUNT = 6

enum Type {
	AIR,
	DIRT,
	STONE,
	GRASS,
	OAK_LOG,
	OAK_LEAVES
}

var material: Material = null
var transparent: bool = false
var type: Type = Type.AIR

static func full_block(block_type: Type, mat: Material) -> Block:
	var bl = Block.new()
	bl.material = mat
	bl.transparent = false
	bl.type = block_type
	return bl

static func transparent_full_block(block_type: Type, mat: Material) -> Block:
	var bl = Block.new()
	bl.material = mat
	bl.transparent = true
	bl.type = block_type
	return bl

static func from_id(id: int) -> Block:
	return BLOCK_LUT[id]

static var AIR: Block = transparent_full_block(Type.AIR, null)
static var DIRT: Block = full_block(Type.DIRT, preload("res://Materials/dirt.tres"))
static var STONE: Block = full_block(Type.STONE, preload("res://Materials/stone.tres"))
static var GRASS: Block = full_block(Type.GRASS, preload("res://Materials/grass.tres"))
static var OAK_LOG: Block = full_block(Type.OAK_LOG, preload("res://Materials/oak_log.tres"))
static var OAK_LEAVES: Block = transparent_full_block(Type.OAK_LEAVES, preload("res://Materials/oak_leaves.tres"))
static var BLOCK_LUT: Array[Block] = [AIR, DIRT, STONE, GRASS, OAK_LOG, OAK_LEAVES]
