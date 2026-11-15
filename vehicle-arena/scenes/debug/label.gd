extends Label

func _process(delta):
	text = "Gyro: " + str(Input.get_gyroscope())
