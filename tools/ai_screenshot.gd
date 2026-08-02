extends Node
## AI eyes: when the game is launched with user args
## `-- --screenshot=<absolute path> [--shot-frame=N]`, waits N frames,
## saves a PNG of the viewport, and quits. Inert in normal play sessions.
## Must run windowed — headless renders nothing.


func _ready() -> void:
	var path := ""
	var frames := 30
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			path = arg.get_slice("=", 1)
		elif arg.begins_with("--shot-frame="):
			frames = int(arg.get_slice("=", 1))
	if path.is_empty():
		return
	for i: int in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png(path)
	print("[ai_screenshot] saved=%s err=%d" % [path, err])
	get_tree().quit()
