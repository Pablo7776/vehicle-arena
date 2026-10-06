extends VehicleBody3D

@export var MAX_STEER := 0.9
@export var ENGINE_POWER := 9000.0
@export var hud: CanvasLayer
@onready var vehicle_input = $VehicleInput
var municion_maxima: int = 30
var municion_actual: int = 30

func _ready():
	if hud:
		hud.actualizar_municion(municion_actual, municion_maxima)

func _physics_process(delta: float) -> void:
	print("steering input: ", vehicle_input.steering)
	steering = move_toward(
		steering,
		vehicle_input.steering * MAX_STEER,
		delta * 10
	)

	engine_force = vehicle_input.throttle * ENGINE_POWER
