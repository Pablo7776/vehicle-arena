extends CanvasLayer

@onready var label_municion: Label = $LabelAmmo

func actualizar_municion(actual: int, maxima: int) -> void:
	# Si alguien llama antes de que el HUD esté listo (por ejemplo el kart,
	# que está antes en el árbol), esperamos a que termine su _ready.
	if not is_node_ready():
		await ready
	label_municion.text = "Munición: %d / %d" % [actual, maxima]
