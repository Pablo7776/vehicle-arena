extends Area3D

## Ítem de MUNICIÓN con reaparición en un punto aleatorio.
## (Antes curaba; como los karts ya no pierden vida, ahora da balas.)
##
## RED (GD-Sync) — "solo el host decide" (clase 8, race condition del ítem):
## - Solo el HOST detecta quién lo agarró. Tiene la posición de todos los karts
##   (la manda su PropertySynchronizer), así que su física los ve a todos.
## - El flag _activo es el "yaRecolectado" de la clase: se cierra ANTES de hacer
##   nada más. Si dos karts lo tocan en el mismo frame, el segundo llega tarde.
## - El host le da las balas al kart (se las pide a su dueño), elige el
##   punto de reaparición y avisa a todos con call_func (un EVENTO puntual,
##   no un valor que cambie todo el tiempo).
## - Limitación: un jugador que se una a mitad de partida no sabe si el ítem
##   está oculto ni dónde está. Hoy no pasa, porque la sala se cierra al empezar.

@export var cantidad_balas: int = 15
@export var tiempo_reaparicion: float = 5.0
@export var puntos_spawn: Array[Marker3D]   # arrastrá los Marker3D desde el Inspector

@onready var colision = $CollisionShape3D
@onready var modelo = $"../Sketchfab_Scene/Sketchfab_model/root/GLTF_SceneRootNode/Body_0"
@onready var raiz: Node3D = get_parent()   # lo que se mueve (debe agrupar el área y el modelo)

var _activo := true   # = "yaRecolectado" al revés: true mientras se puede agarrar
var _indice_actual := -1


func _ready() -> void:
	GDSync.expose_func(_recoger_remoto, ENUMS.EXPOSE_PERMISSION.HOST)   # solo el host decide quién lo agarró


func _on_body_entered(body: Node3D) -> void:
	# 1. Solo el host decide quién lo agarró (if (!IsServer) return; de la clase 8)
	if not GDSync.is_host():
		return
	# 2. Si ya lo agarró alguien, este llegó tarde (if (yaRecolectado) return;)
	if not _activo:
		return
	if not body.has_method("recibir_balas"):
		return
	# 3. Cerrar YA, antes de cualquier otra cosa, para que nadie más lo agarre
	_activo = false

	body.recibir_balas(cantidad_balas)
	var nuevo := _elegir_punto()
	_ocultar_y_reaparecer(nuevo)                   # en el host
	GDSync.call_func(_recoger_remoto, [nuevo])     # en todos los demás, con el mismo punto


func _elegir_punto() -> int:
	if puntos_spawn.size() <= 1:
		return 0
	var i := randi() % puntos_spawn.size()
	while i == _indice_actual:   # que no repita el lugar actual
		i = randi() % puntos_spawn.size()
	return i


# Corre en los clientes cuando el host avisa. Esta versión de GD-Sync
# empaqueta los parámetros en un Array.
func _recoger_remoto(data = null) -> void:
	var indice: int = int(data[0]) if data is Array else int(data)
	_activo = false
	_ocultar_y_reaparecer(indice)


func _ocultar_y_reaparecer(indice: int) -> void:
	modelo.hide()
	colision.set_deferred("disabled", true)
	await get_tree().create_timer(tiempo_reaparicion).timeout
	# Se mueve mientras está oculto, así nadie ve el salto
	if not puntos_spawn.is_empty():
		raiz.global_position = puntos_spawn[indice].global_position
		raiz.reset_physics_interpolation()
		_indice_actual = indice
	modelo.show()
	colision.set_deferred("disabled", false)
	_activo = true
