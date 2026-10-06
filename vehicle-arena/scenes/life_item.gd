extends Area3D

## Ítem de curación con reaparición.
##
## RED (GD-Sync): este ítem NO usa PropertySynchronizer a propósito.
## "Alguien me recogió" es un EVENTO puntual, no un valor que cambie
## continuamente, así que se avisa con call_func y cada peer ejecuta
## su propio ciclo (ocultar -> esperar -> mostrar) con su temporizador local.
## - La cura real pasa por HealthComponent.heal() -> host -> PropertySynchronizer.
## - Limitación: un jugador que se una a mitad de partida no sabe si el ítem
##   está oculto. Si eso pasa a ser necesario, sincronizar _activo.

@export var cantidad_vida: float = 25.0
@export var tiempo_reaparicion: float = 5.0


@onready var colision = $CollisionShape3D
@onready var modelo = $"../Sketchfab_Scene/Sketchfab_model/root/GLTF_SceneRootNode/Body_0"

var _activo := true   # estado local de cada peer; no se sincroniza (ver cabecera)

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
	_recoger()
	# EVENTO: avisa a los demás peers (no se ejecuta en este)
	GDSync.call_func(_recoger_remoto)

func _recoger_remoto() -> void:
	_recoger()

func _recoger() -> void:
	if not _activo:
		return
	_activo = false
	modelo.hide()
	colision.set_deferred("disabled", true)
	await get_tree().create_timer(tiempo_reaparicion).timeout
	modelo.show()
	colision.set_deferred("disabled", false)
	_activo = true
