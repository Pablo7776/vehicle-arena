extends Node
class_name TouchGestureController

@export var accelerate_action := "accelerate"

var _active_touches := {}

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_active_touches[event.index] = true
			Input.action_press(accelerate_action)
		else:
			_active_touches.erase(event.index)
			if _active_touches.is_empty():
				Input.action_release(accelerate_action)
