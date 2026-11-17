extends Label

# Solo se ve en el editor, no en la build final
func _ready() -> void:
	visible = OS.is_debug_build()
	set_process(visible)

func _process(_delta):
	text = "Gyro: " + str(Input.get_gyroscope())
