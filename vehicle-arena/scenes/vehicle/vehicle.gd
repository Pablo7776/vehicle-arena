extends VehicleBody3D

@export var MAX_STEER = 0.9
@export var ENGINE_POWER = 300

func _physics_process(delta: float) -> void:
	var input = Input.get_axis("steer_right", "steer_left")
	steering = move_toward(steering, input * MAX_STEER, delta * 10)

	var throttle = Input.get_axis("brake", "accelerate")
	engine_force = throttle * ENGINE_POWER
