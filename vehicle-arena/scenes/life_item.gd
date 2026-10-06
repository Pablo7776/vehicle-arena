extends Area3D

## Ítem de curación con reaparición en un punto aleatorio.
##
## RED (GD-Sync): este ítem NO usa PropertySynchronizer a propósito.
## "Alguien me recogió" es un EVENTO puntual, no un valor que cambie
## continuamente, así que se avisa con call_func y cada peer ejecuta
## su propio ciclo (ocultar -> esperar -> mover -> mostrar) con su temporizador local.
## - La cura real pasa por HealthComponent.heal() -> host -> PropertySynchronizer.
## - El punto de reaparición lo elige UN solo peer (el que recoge) y envía el
##   índice a los demás, para que todos muevan el ítem al mismo lugar.
## - Limitación: un jugador que se una a mitad de partida no sabe si el ítem
##   está oculto ni dónde está. Si eso pasa a ser necesario, sincronizar
##   _activo y _indice_actual.

@export var cantidad_vida: float = 25.0
@export var tiempo_reaparicion: float = 5.0
@export var puntos_spawn: Array[Marker3D]   # arrastrá los Marker3D desde el Inspector

@onready var colision = $CollisionShape3D
@onready var modelo = $"../Sketchfab_Scene/Sketchfab_model/root/GLTF_SceneRootNode/Body_0"
@onready var raiz: Node3D = get_parent()   # lo que se mueve (debe agrupar el área y el modelo)

var _activo := true   # estado local de cada peer; no se sincroniza (ver cabecera)
var _indice_actual := -1

func _ready() -> void:
	GDSync.expose_func(_recoger_remoto)   # requerido para que otros peers puedan llamarla
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not _activo or not body.has_method("curar"):
		return
	# Solo el dueño del vehículo detecta la recogida, para no curar varias veces
	if not GDSync.is_gdsync_owner(body):
		return
	body.curar(cantidad_vida)
	var nuevo := _elegir_punto()   # lo elige quien recoge
	_recoger(nuevo)
	# EVENTO: avisa a los demás peers (no se ejecuta en este) con el mismo punto
	GDSync.call_func(_recoger_remoto, [nuevo])

func _elegir_punto() -> int:
	if puntos_spawn.size() <= 1:
		return 0
	var i := randi() % puntos_spawn.size()
	while i == _indice_actual:   # que no repita el lugar actual
		i = randi() % puntos_spawn.size()
	return i

# Esta versión de GD-Sync empaqueta los parámetros en un Array
func _recoger_remoto(data = null) -> void:
	var indice: int = int(data[0]) if data is Array else int(data)
	_recoger(indice)

func _recoger(indice: int) -> void:
	if not _activo:
		return
	_activo = false
	modelo.hide()
	colision.set_deferred("disabled", true)
	await get_tree().create_timer(tiempo_reaparicion).timeout
	# Se mueve mientras está oculto, así nadie ve el salto
	if not puntos_spawn.is_empty():
		raiz.global_position = puntos_spawn[indice].global_position
		_indice_actual = indice
	modelo.show()
	colision.set_deferred("disabled", false)
	_activo = true
