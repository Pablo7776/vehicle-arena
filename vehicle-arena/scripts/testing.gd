extends Label

func _process(_delta):
	var prim = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var calls = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	text = "FPS: %d\nTriángulos: %d\nDraw calls: %d" % [Engine.get_frames_per_second(), prim, calls]
