extends VehicleBody3D

@export var MAX_STEER = 0.9
@export var ENGINE_POWER = 300

func _physics_process(delta: float) -> void:
	var input = Input.get_axis("steer_right", "steer_left")
	steering = move_toward(steering, input * MAX_STEER, delta * 10)

	var throttle = Input.get_axis("brake", "accelerate")
	engine_force = throttle * ENGINE_POWER


func _on_button_button_down() -> void:
	Input.action_press("accelerate")


func _on_button_button_up() -> void:
	Input.action_release("accelerate")


func _on_button_2_button_down() -> void:
	Input.action_press("brake")


func _on_button_2_button_up() -> void:
	Input.action_release("brake")


func _on_button_3_button_down() -> void:
	Input.action_press("steer_left")


func _on_button_3_button_up() -> void:
	Input.action_release("steer_left")


func _on_button_4_button_down() -> void:
	Input.action_press("steer_right")


func _on_button_4_button_up() -> void:
	Input.action_release("steer_right")


func _on_button_5_pressed() -> void:
	Input.action_press("accelerate")
