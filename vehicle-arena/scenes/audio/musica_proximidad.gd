extends AudioStreamPlayer

# El volumen sube a medida que el kart se acerca al jabalí.
# Poner este script en un AudioStreamPlayer hijo de Player,
# con el sonido asignado en "Stream" y el loop activado en su importación.

@export var vehiculo: Node3D                 # arrastrá acá Kart1
@export var grupo_objetivo := "jabali"       # grupo al que pertenece el jabalí
@export var distancia_maxima := 150.0        # más lejos que esto, volumen mínimo
@export_range(0.0, 1.0) var volumen_lejos := 0.05   # volumen cuando está lejos (0 = silencio)
@export_range(0.5, 4.0) var curva := 2.0     # más alto = el volumen sube más recién cuando estás cerca
@export var suavizado := 5.0

var _objetivo: Node3D
var _volumen := 0.0


func _ready() -> void:
	# GD-Sync puede tardar un momento en asignar el dueño
	await get_tree().create_timer(0.5).timeout
	if vehiculo == null or not GDSync.is_gdsync_owner(vehiculo):
		set_process(false)
		stop()
		return
	_volumen = volumen_lejos
	play()


func _process(delta: float) -> void:
	if _objetivo == null or not is_instance_valid(_objetivo):
		_objetivo = get_tree().get_first_node_in_group(grupo_objetivo) as Node3D
		if _objetivo == null:
			return

	var distancia := vehiculo.global_position.distance_to(_objetivo.global_position)
	var cercania := 1.0 - clampf(distancia / distancia_maxima, 0.0, 1.0)
	var objetivo_vol := lerpf(volumen_lejos, 1.0, pow(cercania, curva))

	_volumen = lerpf(_volumen, objetivo_vol, 1.0 - exp(-suavizado * delta))
	volume_db = linear_to_db(maxf(_volumen, 0.0001))
