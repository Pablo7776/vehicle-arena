extends CanvasLayer

@onready var label_municion = $LabelAmmo

func actualizar_municion(actual: int, maxima: int):
	label_municion.text = "Munición: %d / %d" % [actual, maxima]
