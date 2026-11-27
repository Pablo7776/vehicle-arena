extends Camera3D

# Cámara fija detrás del kart. Sigue su posición y su giro,
# y mantiene el horizonte nivelado cuando se inclina el celular.

@export var vehiculo_path: NodePath   # asignar a Kart1
@export var offset := Vector3(0, 12.5, -4.0)
@export_range(-90, 90) var inclinacion_grados := -45.0   # negativo = mira hacia abajo
@export var suavizado_pos := 8.0

@export_group("Horizonte")
@export var horizonte_activo := true
@export var sensibilidad_horizonte := 1.0   # poné negativo si la imagen se inclina al revés
@export var limite_horizonte := 0.6
@export var recentrado_horizonte := 0.5
@export var intensidad_horizonte := 0.3     # cuánto se inclina la imagen (0 = nada)
@export var velocidad_horizonte := 8.0   # más alto = responde más rápido

var vehiculo: Node3D
var _inclinacion := 0.0


func _ready() -> void:
	current = true
	top_level = true   # ignora la transformación del padre (Player)
	vehiculo = get_node(vehiculo_path)
	# La cámara la movemos nosotros en cada imagen (_process), no la física:
	# Godot no tiene que interpolarla.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _process(delta: float) -> void:
	if vehiculo == null:
		return

	# Usamos la posición INTERPOLADA del kart: la física lo mueve 60 veces por
	# segundo, pero la pantalla se dibuja a otro ritmo. Con la interpolación de
	# física activada, Godot nos da dónde se ve el kart en ESTA imagen, así la
	# cámara no "salta" respecto del auto (era el parpadeo a gran velocidad).
	var t_kart := vehiculo.get_global_transform_interpolated()

	# Posición: sigue al vehículo con suavizado
	# (1 - exp(...) se comporta igual a cualquier cantidad de FPS)
	var pos_objetivo := t_kart.origin + t_kart.basis * offset
	global_position = global_position.lerp(pos_objetivo, 1.0 - exp(-suavizado_pos * delta))

	# Rotación: mira en la dirección del vehículo
	global_rotation = Vector3(
		deg_to_rad(inclinacion_grados),
		t_kart.basis.get_euler().y + PI,
		_calcular_horizonte(delta)
	)


# Devuelve el ángulo de inclinación de la imagen según el giroscopio.
func _calcular_horizonte(delta: float) -> float:
	if not horizonte_activo:
		return 0.0
	var g := Input.get_gravity()
	if g.length() < 1.0:   # PC o celular sin sensor
		return 0.0
	var objetivo := clampf(atan2(g.x, -g.y) * sensibilidad_horizonte, -limite_horizonte, limite_horizonte)
	_inclinacion = lerpf(_inclinacion, objetivo, 1.0 - exp(-velocidad_horizonte * delta))
	return _inclinacion * intensidad_horizonte
