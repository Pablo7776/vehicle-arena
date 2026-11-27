extends VirtualJoystick

## Joystick izquierdo para manejar (solo en el celular):
##   - Arriba: acelera (más lo empujás, más acelera).
##   - Abajo: frena y, con el kart quieto, marcha atrás (lo resuelve vehicle.gd).
## Por ahora se dobla inclinando el celular (vehicle_input.gd). Doblar con este
## joystick queda preparado: activá `dobla_con_joystick` y listo.
## Aprieta las mismas acciones del Input Map que el teclado, así que
## vehicle_input.gd no necesita saber que existe.

## Si está activado, izquierda/derecha del joystick doblan el kart
## (se suma a la inclinación del celular).
@export var dobla_con_joystick := false

# Acciones "vacías" para izquierda/derecha mientras no dobla con el joystick
# (el joystick siempre aprieta alguna acción; estas no las lee nadie)
const SIN_USO_IZQUIERDA := &"manejo_sin_uso_izquierda"
const SIN_USO_DERECHA := &"manejo_sin_uso_derecha"


func _ready() -> void:
	action_up = &"accelerate"
	action_down = &"brake"
	if dobla_con_joystick:
		action_left = &"steer_left"
		action_right = &"steer_right"
	else:
		for accion in [SIN_USO_IZQUIERDA, SIN_USO_DERECHA]:
			if not InputMap.has_action(accion):
				InputMap.add_action(accion, 0.0)
		action_left = SIN_USO_IZQUIERDA
		action_right = SIN_USO_DERECHA

	# En PC se maneja con el teclado
	if not OS.has_feature("mobile"):
		hide()
		process_mode = Node.PROCESS_MODE_DISABLED
