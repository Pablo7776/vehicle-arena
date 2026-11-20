extends Node
class_name TouchGestureController

## Controles táctiles del lado izquierdo de la pantalla:
##   - Tocar y mantener            -> acelerar
##   - Doble toque y mantener      -> frenar (y marcha atrás cuando el auto se detiene)
## El freno/reversa en sí lo resuelve vehicle.gd; acá solo se aprietan las acciones.

@export var accelerate_action := "accelerate"
@export var brake_action := "brake"
## Tiempo máximo (en segundos) entre soltar el acelerador y volver a tocar
## para que cuente como doble toque.
@export var tiempo_doble_toque := 0.3

var _active_touches := {}        # índice del dedo -> acción que activó ese dedo
var _ultimo_soltado_acelerar := -1.0   # momento en que se soltó el último toque de acelerar


func _ready() -> void:
	# En PC el clic del mouse también llega como "toque" (emulate_touch_from_mouse)
	# y se usa para disparar, así que estos controles solo van en Android.
	if not OS.has_feature("mobile"):
		set_process_unhandled_input(false)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventScreenTouch:
		return

	var ahora := Time.get_ticks_msec() / 1000.0

	if event.pressed:
		# Si recién soltaste el acelerador, este toque es el segundo del doble toque
		var es_doble := _ultimo_soltado_acelerar >= 0.0 \
				and ahora - _ultimo_soltado_acelerar <= tiempo_doble_toque
		var accion := brake_action if es_doble else accelerate_action
		_active_touches[event.index] = accion
		Input.action_press(accion)

	elif _active_touches.has(event.index):
		var accion: String = _active_touches[event.index]
		_active_touches.erase(event.index)
		if accion == accelerate_action:
			_ultimo_soltado_acelerar = ahora
		else:
			# Después de frenar, el próximo toque vuelve a ser acelerar
			_ultimo_soltado_acelerar = -1.0
		# Soltar la acción solo si ningún otro dedo la sigue usando
		if not _active_touches.values().has(accion):
			Input.action_release(accion)
