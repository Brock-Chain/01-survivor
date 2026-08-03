extends Node2D
## Juice lab — an isolation bench for one effect at a time.
##
## Why it exists: every other way we look at this game is either headless
## (tests, soak runs, telemetry) or whole-game (screenshot, web build). Neither
## answers "does this 0.3 s effect feel right, and is variant B better than what
## shipped?" — you cannot judge an animation inside a firefight you are also
## trying to survive, and you cannot replay it on demand. Here the effect plays
## alone, repeatedly, at any speed, with the shipped version sitting next to two
## alternatives so the comparison is A/B, not memory.
##
## Human use — run it windowed and click:
##   <console.exe> --path . -w --resolution 1280x720 res://scenes/dev/juice_lab.tscn
##   1/2/3 pick a variant · R replay · ←/→ change effect · Esc quit
##
## AI use — pin a case and variant, let the screenshot autoload capture the
## motion as a contact sheet:
##   <console.exe> --path . -w --resolution 1280x720 --fixed-fps 60 \
##       res://scenes/dev/juice_lab.tscn -- --lab-case=hit_flash --lab-variant=1 \
##       --screenshot=<abs>/.ai/flash.png --shot-frames=2,5,8,11,14,20
##
## Adding a case: append to CASES, then add a branch to _variants() and _play().
## **Variant 0 is always what shipped** — every comparison needs a baseline, and
## "the new one is different" is not the same claim as "the new one is better".
## Dev-only: this scene reads game code, nothing in the game imports it, and
## `scenes/dev/*` is excluded from both export presets.

const FLASH_SHADER: Shader = preload("res://assets/shaders/flash.gdshader")
const DEATH_BURST: PackedScene = preload("res://scenes/fx/death_burst.tscn")
const TEX_ENEMY: Texture2D = preload("res://assets/sprites/enemy.png")
const TEX_GEM: Texture2D = preload("res://assets/sprites/gem.png")
const TEX_ENEMY_DART: Texture2D = preload("res://assets/sprites/enemy_dart.png")
const TEX_ENEMY_RAM: Texture2D = preload("res://assets/sprites/enemy_ram.png")
const TEX_ENEMY_BULWARK: Texture2D = preload("res://assets/sprites/enemy_bulwark.png")
const TEX_ENEMY_SPLITTER: Texture2D = preload("res://assets/sprites/enemy_splitter.png")
const TEX_BOSS_CORE: Texture2D = preload("res://assets/sprites/boss_core.png")
const TEX_BULLET: Texture2D = preload("res://assets/sprites/bullet.png")
const TEX_BOLT: Texture2D = preload("res://assets/sprites/bolt.png")

const CASES: PackedStringArray = ["hit_flash", "death_burst", "screenshake", "pickup_pulse", "glow"]
## Sprites are authored at ~12 px for a 640×360 canvas; blown up here because
## the lab judges the curve, not the silhouette.
const SPRITE_SCALE: float = 5.0
## The Drifter's tint (resources/enemies/drifter.tres). Not decoration: enemies are
## always tinted in game, and a *white* test sprite makes the hit flash — which
## mixes toward white — look like it does nothing. The bench has to reproduce the
## conditions the effect ships under or it measures the wrong thing.
const ENEMY_TINT: Color = Color(1.0, 0.29, 0.72, 1.0)

var _case_index: int = 0
var _variant: int = 0

@onready var camera: GameCamera = $Camera
@onready var spawned: Node2D = $Spawned
@onready var case_box: VBoxContainer = $UI/Left/Cases
@onready var variant_box: HBoxContainer = $UI/Bottom/Variants
@onready var speed_slider: HSlider = $UI/Bottom/Controls/Speed
@onready var speed_value: Label = $UI/Bottom/Controls/SpeedValue
@onready var replay_button: Button = $UI/Bottom/Controls/Replay
@onready var header: Label = $UI/Header
@onready var hint: Label = $UI/Bottom/Hint
@onready var glow_hud: Label = $UI/GlowHud


func _ready() -> void:
	_apply_cmdline()
	_build_cases()
	speed_slider.min_value = 0.05
	speed_slider.max_value = 1.0
	speed_slider.step = 0.05
	speed_slider.value = Engine.time_scale
	speed_slider.value_changed.connect(_on_speed_changed)
	replay_button.pressed.connect(_play)
	_select_case(_case_index, _variant)


## time_scale is global state on the Engine singleton, so leaving it wound down
## would follow us out of the lab into any scene loaded afterwards. use_hdr_2d
## is the same kind of leak at the Viewport level (see _add_glow_env) — reset
## both or the lab's last-viewed case quietly changes rendering downstream.
func _exit_tree() -> void:
	Engine.time_scale = 1.0
	get_viewport().use_hdr_2d = false


func _apply_cmdline() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--lab-case="):
			var found: int = CASES.find(arg.get_slice("=", 1))
			if found >= 0:
				_case_index = found
		elif arg.begins_with("--lab-variant="):
			_variant = int(arg.get_slice("=", 1))
		elif arg.begins_with("--lab-speed="):
			Engine.time_scale = maxf(0.01, float(arg.get_slice("=", 1)))


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_R:
			_play()
		KEY_LEFT:
			_select_case(wrapi(_case_index - 1, 0, CASES.size()), 0)
		KEY_RIGHT:
			_select_case(wrapi(_case_index + 1, 0, CASES.size()), 0)
		KEY_ESCAPE:
			get_tree().quit()
		_:
			var picked: int = key_event.keycode - KEY_1
			if picked >= 0 and picked < _variants(CASES[_case_index]).size():
				_select_variant(picked)


# ---------------------------------------------------------------- cases

## Labels double as the spec: each one states the numbers it runs, so a
## screenshot of this scene says which variant it is without a caption.
func _variants(case_name: String) -> PackedStringArray:
	match case_name:
		"hit_flash":
			return ["1 · shipped 0.12s", "2 · snap 0.08 + punch", "3 · hold → 0.20 ease-in"]
		"death_burst":
			return ["1 · shipped 12p 0.35s", "2 · punchy 22p 0.22s", "3 · heavy 8p 0.70s"]
		"screenshake":
			return ["1 · kill 0.12", "2 · hurt 0.50", "3 · death 1.00"]
		"pickup_pulse":
			return ["1 · shipped 1.15 / 0.4s", "2 · big 1.30 / 0.5s", "3 · snappy 1.12 / 0.22s"]
		"glow":
			return ["1 · shipped baked (no post-fx)", "2 · real bloom thresh .55 str 1.3",
					"3 · gentle bloom thresh .75 str .6"]
	return PackedStringArray(["1 · default"])


func _play() -> void:
	# remove_child before queue_free: queue_free is deferred, so a fast replay
	# would otherwise stack the new effect on top of the old one for a frame.
	for child: Node in spawned.get_children():
		spawned.remove_child(child)
		child.queue_free()
	# GlowHud lives on the persistent UI CanvasLayer (see juice_lab.tscn), not
	# under `spawned`, so it needs its own toggle instead of riding the clear
	# loop above.
	glow_hud.visible = CASES[_case_index] == "glow"
	match CASES[_case_index]:
		"hit_flash":
			_play_hit_flash()
		"death_burst":
			_play_death_burst()
		"screenshake":
			_play_screenshake()
		"pickup_pulse":
			_play_pickup_pulse()
		"glow":
			_play_glow()


func _play_hit_flash() -> void:
	var sprite: Sprite2D = _make_sprite(TEX_ENEMY, ENEMY_TINT)
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = FLASH_SHADER
	mat.set_shader_parameter(&"flash", 1.0)
	sprite.material = mat
	# Tweens are created on the sprite, not on the lab, so freeing the stage
	# kills them — a tween outliving its target is a stale-reference crash.
	var tween: Tween = sprite.create_tween()
	match _variant:
		1:
			tween.tween_property(mat, "shader_parameter/flash", 0.0, 0.08)
			var punch: Tween = sprite.create_tween()
			punch.tween_property(sprite, "scale", Vector2.ONE * SPRITE_SCALE * 1.25, 0.04) \
					.set_trans(Tween.TRANS_QUAD)
			punch.tween_property(sprite, "scale", Vector2.ONE * SPRITE_SCALE, 0.10) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		2:
			tween.tween_interval(0.05)
			tween.tween_property(mat, "shader_parameter/flash", 0.0, 0.20) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_:
			tween.tween_property(mat, "shader_parameter/flash", 0.0, Enemy.FLASH_TIME)


func _play_death_burst() -> void:
	var burst: CPUParticles2D = DEATH_BURST.instantiate()
	burst.setup(ENEMY_TINT)
	match _variant:
		1:
			burst.amount = 22
			burst.lifetime = 0.22
			burst.initial_velocity_min = 90.0
			burst.initial_velocity_max = 190.0
		2:
			burst.amount = 8
			burst.lifetime = 0.7
			burst.initial_velocity_min = 25.0
			burst.initial_velocity_max = 70.0
			burst.scale_amount_min = 3.0
			burst.scale_amount_max = 5.5
	spawned.add_child(burst)


## The three trauma values the game actually calls with, felt in isolation:
## kills (main.gd), player hurt (player.gd), player death (player.gd).
func _play_screenshake() -> void:
	var amounts: PackedFloat32Array = PackedFloat32Array([0.12, 0.5, 1.0])
	camera.add_trauma(amounts[clampi(_variant, 0, amounts.size() - 1)])


func _play_pickup_pulse() -> void:
	var sprite: Sprite2D = _make_sprite(TEX_GEM, Color.WHITE)
	var peak: float = 1.15
	var half: float = 0.4
	match _variant:
		1:
			peak = 1.3
			half = 0.5
		2:
			peak = 1.12
			half = 0.22
	var pulse: Tween = sprite.create_tween().set_loops()
	pulse.tween_property(sprite, "scale", Vector2.ONE * SPRITE_SCALE * peak, half) \
			.set_trans(Tween.TRANS_SINE)
	pulse.tween_property(sprite, "scale", Vector2.ONE * SPRITE_SCALE, half) \
			.set_trans(Tween.TRANS_SINE)


## Real bloom vs the shipped baked glow (bright saturated art on a near-black
## floor, no post-process at all). Variant 0 is that shipped baseline: the
## match below only ever adds a WorldEnvironment for 1/2, so 0 renders exactly
## what main.tscn renders today — no glow node anywhere in the game.
##
## gl_compatibility does support Environment.glow in 4.7, so the old worry
## ("bloom breaks the single-threaded web export") is stale. The worry this
## case is FOR: at a 640x360 backbuffer, bloom's blur kernel operates in the
## same handful of pixels as a sprite's silhouette, and it does not distinguish
## arena sprites from the HUD text sitting on the same viewport.
func _play_glow() -> void:
	_spawn_glow_scene()
	match _variant:
		1:
			_add_glow_env(0.0, 8.0, 5.0)
		2:
			_add_glow_env(0.75, 0.6, 0.7)
		_:
			# use_hdr_2d has to come back down for variant 0 too: it is a
			# Viewport-level switch, not a child of `spawned`, so the clear
			# loop at the top of _play() does not touch it.
			get_viewport().use_hdr_2d = false


## Several enemy tints + a boss + pickups + both projectile types, because the
## failure mode under test is bloom applied indiscriminately across an
## arena's worth of brightness, not one sprite in isolation.
func _spawn_glow_scene() -> void:
	# scale_mult 1.0, not SPRITE_SCALE: every other case blows sprites up 5x
	# because it is judging an animation curve, not a silhouette. This case
	# judges whether bloom steps chunkily around a sprite's ACTUAL in-game
	# size (~12-18px at 640x360), so blowing it up here would hide the thing
	# being measured.
	_make_sprite(TEX_ENEMY, ENEMY_TINT, Vector2(-120, -60), 1.0)
	_make_sprite(TEX_ENEMY_DART, Color(1, 0.55, 0.16, 1), Vector2(-40, -100), 1.0)
	_make_sprite(TEX_ENEMY_RAM, Color(1, 0.26, 0.2, 1), Vector2(40, -50), 1.0)
	_make_sprite(TEX_ENEMY_BULWARK, Color(0.72, 0.35, 1, 1), Vector2(120, -90), 1.0)
	_make_sprite(TEX_ENEMY_SPLITTER, Color(0.93, 0.34, 0.94, 1), Vector2(200, -40), 1.0)
	# Boss-scale and placed to sit right beside GlowHud (see juice_lab.tscn) —
	# the brightest thing on screen, next to the text, on purpose.
	_make_sprite(TEX_BOSS_CORE, Color(1, 0.35, 0.72, 1), Vector2(260, -120), 2.0)
	_make_sprite(TEX_GEM, Color(0.45, 1, 0.72, 1), Vector2(-20, 40), 1.0)
	_make_sprite(TEX_BULLET, Color.WHITE, Vector2(80, 50), 1.0)
	_make_sprite(TEX_BOLT, Color.WHITE, Vector2(-90, 50), 1.0)


func _add_glow_env(threshold: float, strength: float, intensity: float) -> void:
	# use_hdr_2d defaults to false: the 2D backbuffer is 8-bit LDR, and glow's
	# bright-pass has nothing to extract from an already-clamped image. Measured
	# by diffing baked-vs-bloom screenshots pixel-for-pixel with this line
	# absent — 1062 stray pixels in a 390k-pixel arena crop, i.e. no visible
	# glow at all despite glow_enabled=true. This is the actual toggle.
	get_viewport().use_hdr_2d = true
	# LDR canvas colors cap at 1.0, so the engine default glow_hdr_threshold of
	# 1.0 would never trigger on a fully-saturated (but not HDR) neon sprite —
	# threshold has to come down below 1.0 or bloom does nothing here at all.
	var env: Environment = Environment.new()
	env.glow_enabled = true
	env.glow_hdr_threshold = threshold
	env.glow_strength = strength
	env.glow_intensity = intensity
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	# glow_mix defaults to 0.05 REGARDLESS of blend mode (confirmed by probing
	# Environment's own property defaults) — leaving it untouched caps the
	# whole effect at 5% no matter how high strength/intensity go. This is the
	# actual "is glow on" knob; strength/intensity only shape it after.
	env.glow_mix = 1.0
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	# Parented under `spawned` so the next _play() call's clear loop tears this
	# down too — glow reverting to "off" on the next replay/case switch is the
	# whole point, since variant 0 (shipped) must never inherit variant 1/2's
	# environment.
	spawned.add_child(world_env)
	print("[glow-debug] use_hdr_2d=", get_viewport().use_hdr_2d,
			" glow_enabled=", env.glow_enabled, " mix=", env.glow_mix,
			" thresh=", env.glow_hdr_threshold, " world_env_in_tree=",
			world_env.is_inside_tree(), " renderer=",
			ProjectSettings.get_setting("rendering/renderer/rendering_method"))


func _make_sprite(tex: Texture2D, tint: Color, pos: Vector2 = Vector2.ZERO,
		scale_mult: float = SPRITE_SCALE) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = tex
	sprite.position = pos
	sprite.scale = Vector2.ONE * scale_mult
	sprite.modulate = tint
	spawned.add_child(sprite)
	return sprite


# ---------------------------------------------------------------- ui

func _build_cases() -> void:
	for i: int in CASES.size():
		var button: Button = Button.new()
		button.text = CASES[i].capitalize()
		button.toggle_mode = true
		button.pressed.connect(_select_case.bind(i, 0))
		case_box.add_child(button)


func _select_case(index: int, variant: int) -> void:
	_case_index = index
	_build_variants()
	_select_variant(variant)


func _build_variants() -> void:
	for child: Node in variant_box.get_children():
		variant_box.remove_child(child)
		child.queue_free()
	var labels: PackedStringArray = _variants(CASES[_case_index])
	for i: int in labels.size():
		var button: Button = Button.new()
		button.text = labels[i]
		button.toggle_mode = true
		button.pressed.connect(_select_variant.bind(i))
		variant_box.add_child(button)


func _select_variant(variant: int) -> void:
	_variant = clampi(variant, 0, _variants(CASES[_case_index]).size() - 1)
	_refresh_labels()
	_play()


func _refresh_labels() -> void:
	for i: int in case_box.get_child_count():
		(case_box.get_child(i) as Button).button_pressed = i == _case_index
	for i: int in variant_box.get_child_count():
		(variant_box.get_child(i) as Button).button_pressed = i == _variant
	var case_name: String = CASES[_case_index]
	header.text = "%s  ·  %s" % [case_name, _variants(case_name)[_variant]]
	# The repro line is the point: what gets kept is the committed variant, not
	# the session that found it, so the lab prints how to reach this exact state.
	hint.text = "1/2/3 variant · R replay · ←/→ effect · Esc quit      --lab-case=%s --lab-variant=%d" \
			% [case_name, _variant]


func _on_speed_changed(value: float) -> void:
	Engine.time_scale = value
	speed_value.text = "%.2fx" % value
