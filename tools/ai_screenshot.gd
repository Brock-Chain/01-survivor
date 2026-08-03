extends Node
## AI eyes: when the game is launched with user args `-- --screenshot=<abs path>`,
## captures the viewport, writes a PNG and quits. Inert in normal play sessions.
## Must run windowed — headless renders nothing.
##
## Two modes:
##   --shot-frame=30            one PNG at frame 30 (the original behaviour)
##   --shot-frames=2,5,8,11,14  a CONTACT SHEET: those frames composed into a
##                              single grid image, left→right then top→bottom
##
## The sheet exists because one frame cannot show motion. An ease curve, a
## particle arc, a flash decay — each is a *sequence*, and a single capture of
## it only proves a pose existed. Five frames in one image is the difference
## between "the effect fired" and "the effect fires too late and stops dead".
##
## **Always pass `--fixed-fps 60` with frame numbers or they mean nothing** — an
## uncapped 2D scene runs at thousands of FPS, so every capture lands at t≈0 and
## the sheet is five identical images. With it, frame N is exactly N/60 s.
##
## Optional: --shot-scale=0.5  (default: 1.0 single, 0.5 sheet — a full-size
##                              sheet of 6 frames is 7700 px wide and unreadable)
##           --shot-cols=4     (grid width; sheets wrap to a new row past it)

const GAP: int = 4
const BACKDROP: Color = Color(0.08, 0.08, 0.11, 1.0)
const DEFAULT_FRAME: int = 30

## True while a capture run is in flight. Public because Main has to know: it
## pauses the run on focus loss, and a capture launched from a terminal NEVER has
## focus — so the gameplay screenshot rig silently started photographing the
## PAUSE MENU the day that shipped. Nothing errored, no frame number changed, the
## tool just stopped taking pictures of the game.
##
## A capture run is not a player, and this is the flag that says so. Set in
## `_ready` before the first frame, so the notification cannot beat it.
var capturing: bool = false

## Frames elapsed since boot. Counted here rather than by awaiting N times in a
## row because `RenderingServer.frame_post_draw` consumes an unspecified number
## of frames, so a capture would shift every later frame number in the sheet.
var _frame: int = 0


func _process(_delta: float) -> void:
	_frame += 1


func _ready() -> void:
	# The counter must survive anything that pauses the tree mid-capture
	# (victory, a modal) — a frozen counter is an await that never resolves.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var path: String = ""
	var frames: PackedInt32Array = PackedInt32Array()
	var scale: float = -1.0
	var cols: int = 4
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			path = arg.get_slice("=", 1)
		elif arg.begins_with("--shot-frame="):
			frames = PackedInt32Array([int(arg.get_slice("=", 1))])
		elif arg.begins_with("--shot-frames="):
			frames = _parse_frames(arg.get_slice("=", 1))
		elif arg.begins_with("--shot-scale="):
			scale = float(arg.get_slice("=", 1))
		elif arg.begins_with("--shot-cols="):
			cols = maxi(1, int(arg.get_slice("=", 1)))
	if path.is_empty():
		# Nothing to capture, so stop counting frames. This autoload ships inside
		# the web build, where a per-frame callback that exists only for the AI is
		# pure waste — small, but paid every frame of every player's run.
		set_process(false)
		return
	capturing = true
	if frames.is_empty():
		frames = PackedInt32Array([DEFAULT_FRAME])
	if scale < 0.0:
		scale = 1.0 if frames.size() == 1 else 0.5

	var shots: Array[Image] = await _capture(frames, scale)
	var sheet: Image = shots[0] if shots.size() == 1 else _compose(shots, cols)
	var err: int = sheet.save_png(path)
	print("[ai_screenshot] saved=%s err=%d frames=%s scale=%.2f cols=%d size=%dx%d"
			% [path, err, str(frames), scale, cols, sheet.get_width(), sheet.get_height()])
	get_tree().quit()


func _parse_frames(raw: String) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for piece: String in raw.split(",", false):
		out.append(int(piece.strip_edges()))
	out.sort()
	return out


func _capture(frames: PackedInt32Array, scale: float) -> Array[Image]:
	var out: Array[Image] = []
	for target: int in frames:
		while _frame < target:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		if not is_equal_approx(scale, 1.0):
			img.resize(int(img.get_width() * scale), int(img.get_height() * scale),
					Image.INTERPOLATE_BILINEAR)
		out.append(img)
	return out


func _compose(shots: Array[Image], cols: int) -> Image:
	var count: int = shots.size()
	var c: int = mini(cols, count)
	var r: int = int(ceil(float(count) / float(c)))
	var w: int = shots[0].get_width()
	var h: int = shots[0].get_height()
	var sheet: Image = Image.create_empty(
			c * w + (c + 1) * GAP, r * h + (r + 1) * GAP, false, Image.FORMAT_RGBA8)
	sheet.fill(BACKDROP)
	# Column/row are walked rather than derived (i % c, i / c) because the second
	# is integer division, which GDScript warns about on every parse.
	var col: int = 0
	var row: int = 0
	for shot: Image in shots:
		var at: Vector2i = Vector2i(GAP + col * (w + GAP), GAP + row * (h + GAP))
		sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, Vector2i(w, h)), at)
		col += 1
		if col >= c:
			col = 0
			row += 1
	return sheet
