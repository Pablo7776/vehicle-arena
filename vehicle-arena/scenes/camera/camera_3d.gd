extends Camera3D

@export var vehiculo_path: NodePath
@export var offset := Vector3(0, 2.5, 5)
@export var sensibilidad := 1.0
@export var limite_yaw := 1.0
@export var limite_pitch := 0.5
@export var suavizado_pos := 8.0
@export var recentrado := 1.5   # velocidad con la que vuelve al centro

@export var sensibilidad_volante := 1.0
@export var limite_volante := 0.6

var vehiculo: Node3D

var offset_yaw := 0.0
var offset_pitch := 0.0

func _ready():
	current = true
	top_level = true
	vehiculo = get_node(vehiculo_path)

func _process(delta):
	if vehiculo == null:
		return

	var gyro = Input.get_gyroscope()

	offset_yaw += gyro.y * sensibilidad * delta
	offset_pitch += gyro.x * sensibilidad * delta

	# --- Auto-recentrado: tira suavemente el offset hacia 0 ---
	offset_yaw = lerp(offset_yaw, 0.0, recentrado * delta)
	offset_pitch = lerp(offset_pitch, 0.0, recentrado * delta)

	offset_yaw = clamp(offset_yaw, -limite_yaw, limite_yaw)
	offset_pitch = clamp(offset_pitch, -limite_pitch, limite_pitch)

	var pos_objetivo = vehiculo.global_transform.origin + vehiculo.global_transform.basis * offset
	global_position = lerp(global_position, pos_objetivo, suavizado_pos * delta)

	var yaw_base = vehiculo.global_rotation.y + PI
	global_rotation.y = yaw_base + offset_yaw
	global_rotation.x = offset_pitch
	global_rotation.z = 0.0
