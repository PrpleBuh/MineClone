extends Control
class_name UI

@onready var inventory: Control = $Inventory
@onready var crosshair: Control = $CenterContainer/Crosshair

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("inventory"):
		inventory.visible = !inventory.visible
		if inventory.visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_redraw()

func _draw() -> void:
	draw_arc(crosshair.position, 4, 0, TAU, 20, Color.WHITE, 2, true)
	

func is_input_blocked() -> bool:
	return inventory.visible
