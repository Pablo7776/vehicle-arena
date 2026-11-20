extends Node3D

## "Precalienta" shaders al empezar la partida.
## La primera vez que Godot dibuja un material nuevo tiene que compilar su
## shader, y eso traba el juego un instante (por ejemplo, en el primer disparo).
## Este nodo dibuja una vez, frente a la cámara y casi invisibles, las cosas
## que todavía no están en pantalla al arrancar (balas, indicador de apuntado...),
## así la traba pasa durante la carga y no mientras jugás.
## Para sumar otra cosa, agregá su escena a la lista `escenas` en el inspector.

@export var escenas: Array[PackedScene] = []
## Cuántos frames se dibujan (con 2 o 3 alcanza).
@export var frames := 3


func _ready() -> void:
	# La cámara del jugador aparece un momento después que la arena
	var camara := await _esperar_camara()
	if camara == null:
		queue_free()
		return

	for escena in escenas:
		if escena == null:
			continue
		_copiar_mallas(escena)

	# Un poco delante de la cámara, en miniatura: se dibuja, pero no se nota
	var adelante := -camara.global_basis.z
	global_position = camara.global_position + adelante * 2.0
	scale = Vector3.ONE * 0.01

	for i in frames:
		await get_tree().process_frame
	queue_free()


# Instanciamos la escena SIN agregarla al árbol (así no corre su script:
# una bala de verdad se movería y haría daño) y copiamos solo sus mallas.
func _copiar_mallas(escena: PackedScene) -> void:
	var instancia := escena.instantiate()
	var mallas := instancia.find_children("*", "MeshInstance3D", true, false)
	if instancia is MeshInstance3D:
		mallas.append(instancia)
	for nodo in mallas:
		var malla := nodo as MeshInstance3D
		var copia := MeshInstance3D.new()
		copia.mesh = malla.mesh
		copia.material_override = malla.material_override
		copia.material_overlay = malla.material_overlay
		for s in malla.get_surface_override_material_count():
			copia.set_surface_override_material(s, malla.get_surface_override_material(s))
		copia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(copia)
	instancia.free()


func _esperar_camara() -> Camera3D:
	for i in 120:   # hasta ~2 segundos
		var camara := get_viewport().get_camera_3d()
		if camara != null:
			return camara
		await get_tree().process_frame
	return null
