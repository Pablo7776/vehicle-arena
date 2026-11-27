extends VirtualJoystick

## Joystick izquierdo para manejar (solo en el celular):
##   - Tocar (y mantener) en la mitad izquierda: acelera a fondo, sin mover el dedo.
##   - Deslizar hacia abajo: frena y, con el kart quieto, marcha atrás
##     (el freno/reversa lo resuelve vehicle.gd).
## Por ahora se dobla inclinando el celular (vehicle_input.gd). Doblar con este
## joystick queda preparado: activá `dobla_con_joystick` y listo.
## Aprieta las mismas acciones del Input Map que el teclado, así que
## vehicle_input.gd no necesita saber que existe.

## Si está activado, izquierda/derecha del joystick doblan el kart
## (se suma a la inclinación del celular).
@export var dobla_con_joystick := false
## Cuánto hay que bajar el dedo (0 a 1) para dejar de acelerar y frenar
@export_range(0.0, 1.0) var umbral_freno := 0.3

# Acciones "vacías" para las direcciones que no usamos
# (el joystick siempre aprieta alguna acción; estas no las lee nadie)
const SIN_USO_ARRIBA := &"manejo_sin_uso_arriba"
const SIN_USO_IZQUIERDA := &"manejo_sin_uso_izquierda"
const SIN_USO_DERECHA := &"manejo_sin_uso_derecha"

var _tocando := false


func _ready() -> void:
	for accion in [SIN_USO_ARRIBA, SIN_USO_IZQUIERDA, SIN_USO_DERECHA]:
		if not InputMap.has_action(accion):
			InputMap.add_action(accion, 0.0)
	# El acelerador no depende de mover el joystick: lo maneja _process
	action_up = SIN_USO_ARRIBA
	action_down = &"brake"
	if dobla_con_joystick:
		action_left = &"steer_left"
		action_right = &"steer_right"
	else:
		action_left = SIN_USO_IZQUIERDA
		action_right = SIN_USO_DERECHA

	pressed.connect(func(): _tocando = true)
	released.connect(func(_v): _soltar())

	# En PC se maneja con el teclado
	if not OS.has_feature("mobile"):
		hide()
		process_mode = Node.PROCESS_MODE_DISABLED


func _process(_delta: float) -> void:
	if not _tocando:
		return
	# Con el dedo apoyado acelera, salvo que lo estés bajando (frenar / marcha atrás)
	var bajando := Input.get_action_raw_strength(&"brake") >= umbral_freno
	if bajando:
		Input.action_release(&"accelerate")
	else:
		Input.action_press(&"accelerate")


func _soltar() -> void:
	_tocando = false
	Input.action_release(&"accelerate")
