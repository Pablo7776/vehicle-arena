extends Area3D

@export var cantidad_vida: float = 25.0 # Cambiado a float para coincidir con tu componente
@onready var colision = $CollisionShape3D
@onready var modelo = $"../Sketchfab_Scene/Sketchfab_model/root/GLTF_SceneRootNode/Body_0"
func _on_body_entered(body: Node3D) -> void:
	print("LOG item_life: Colisión detectada con el nodo -> ", body.name)
	
	if body.is_in_group("Jugador") or body.has_method("curar"):
		print("LOG item_life: El jugador agarró el ítem.")
		
		# Curamos al jugador
		if body.has_method("curar"):
			body.curar(20)
			
	print("LOG item_life: Ocultando el ítem por 5 segundos...")
	_iniciar_reaparicion()

func _iniciar_reaparicion() -> void:
	# 1. Hacemos invisible el ítem
	modelo.hide()
	
	# 2. Desactivamos la colisión para que no se pueda volver a agarrar estando invisible.
	# Usamos set_deferred porque Godot no permite cambiar colisiones en medio del cálculo de físicas.
	colision.set_deferred("disabled", true)
	
	# 3. Esperamos 5 segundos exactos
	await get_tree().create_timer(5.0).timeout
	
	# 4. Volvemos a mostrar y activar el ítem
	print("LOG item_life: ¡El ítem ha reaparecido!")
	modelo.show()
	colision.set_deferred("disabled", false)

# Función para destruir la llave en todos los clientes
func eliminar_llave() -> void:
	# Si la llave es un nodo sincronizado por GDSync, asegúrate de que todos la borren
	GDSync.call_func(sync_queue_free)

func sync_queue_free() -> void:
	queue_free()

func _ready() -> void:
	# Exponemos la función de destrucción para que el Host pueda ordenarle a los clientes borrarla
	GDSync.expose_func(sync_queue_free)
