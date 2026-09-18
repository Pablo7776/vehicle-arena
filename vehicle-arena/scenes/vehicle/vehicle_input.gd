extends Node

@export var sensibilidad_volante := 1.0
@export var limite_volante := 0.6

var steering := 0.0
var throttle := 0.0
var brake := 0.0

func _physics_process(_delta):
	var volante_tilt := 0.0

	if OS.has_feature("mobile"):
		var accel = Input.get_accelerometer()
		# accel.x suele ser el eje de "inclinar como un volante"
		# (rotar el celular sobre su eje largo). Si usás el celu en horizontal
		# en vez de vertical, probablemente necesites accel.z en su lugar.
		volante_tilt = -(accel.x / 9.8) * sensibilidad_volante
		volante_tilt = clamp(volante_tilt, -limite_volante, limite_volante)

	var volante_botones = Input.get_axis("steer_right", "steer_left")

	steering = clamp(volante_tilt + volante_botones, -1.0, 1.0)
	throttle = Input.get_action_strength("accelerate")
	brake = Input.get_action_strength("brake")
