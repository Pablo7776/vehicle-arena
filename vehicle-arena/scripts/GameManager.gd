extends Node

@export var label_resultado: Label

var _terminada := false

func _ready() -> void:
	add_to_group("game_manager")
	GDSync.expose_func(_mostrar_resultado)
	if label_resultado:
		label_resultado.hide()

# Solo el host decide
func revisar_ganador() -> void:
	if not GDSync.is_host() or _terminada:
		return
	var vehiculos := get_tree().get_nodes_in_group("vehiculos")
	var vivos := vehiculos.filter(func(v): return v.health.current > 0.0)
	if vehiculos.size() < 2 or vivos.size() != 1:
		return
	_terminada = true
	var ganador_id: int = GDSync.get_gdsync_owner(vivos[0])
	_mostrar_resultado(ganador_id)                      # el host
	GDSync.call_func(_mostrar_resultado, [ganador_id])  # los demás

# Los parámetros llegan empaquetados en un Array
func _mostrar_resultado(data = null) -> void:
	var ganador_id: int = int(data[0]) if data is Array else int(data)
	if not label_resultado:
		return
	label_resultado.show()
	if ganador_id == GDSync.get_client_id():
		label_resultado.text = "¡VICTORIA!"
	else:
		label_resultado.text = "DERROTA"
