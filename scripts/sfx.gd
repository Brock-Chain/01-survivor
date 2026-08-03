extends Node
## Autoload "Sfx": fire-and-forget one-shots on a round-robin voice pool.
##
## A cue name maps to an ARRAY of streams. Sounds heard hundreds of times per
## run (shoot, hit, pop, pickup) ship as pre-rendered pitch-varied sets — a
## random variant per play, plus a little runtime pitch jitter, keeps repetition
## from turning into a drill. Sources live in audio_src/sfx/*.strudel; the WAVs
## are build artifacts of tools/build_sfx.py.
##
## Explicit preloads, not directory scanning — DirAccess listings misbehave
## inside exported .pck files (resources get .remap suffixes).

const VOICES: int = 12

const STREAMS: Dictionary = {
	&"shoot": [
		preload("res://assets/audio/sfx/shoot_0.wav"),
		preload("res://assets/audio/sfx/shoot_1.wav"),
		preload("res://assets/audio/sfx/shoot_2.wav"),
	],
	&"hit": [
		preload("res://assets/audio/sfx/hit_0.wav"),
		preload("res://assets/audio/sfx/hit_1.wav"),
		preload("res://assets/audio/sfx/hit_2.wav"),
	],
	&"pop": [
		preload("res://assets/audio/sfx/pop_0.wav"),
		preload("res://assets/audio/sfx/pop_1.wav"),
		preload("res://assets/audio/sfx/pop_2.wav"),
	],
	&"pickup": [
		preload("res://assets/audio/sfx/pickup_0.wav"),
		preload("res://assets/audio/sfx/pickup_1.wav"),
	],
	&"levelup": [preload("res://assets/audio/sfx/levelup.wav")],
	&"hurt": [preload("res://assets/audio/sfx/hurt.wav")],
	&"death": [preload("res://assets/audio/sfx/death.wav")],
	&"click": [preload("res://assets/audio/sfx/click.wav")],
	&"bolt": [preload("res://assets/audio/sfx/bolt.wav")],
	&"crit": [preload("res://assets/audio/sfx/crit.wav")],
	&"blast": [preload("res://assets/audio/sfx/blast.wav")],
	&"lance": [preload("res://assets/audio/sfx/lance.wav")],
	&"powerup": [preload("res://assets/audio/sfx/powerup.wav")],
	&"health": [preload("res://assets/audio/sfx/health.wav")],
	&"shield_on": [preload("res://assets/audio/sfx/shield_on.wav")],
	&"shield_off": [preload("res://assets/audio/sfx/shield_off.wav")],
	&"boss_telegraph": [preload("res://assets/audio/sfx/boss_telegraph.wav")],
	&"boss_spawn": [preload("res://assets/audio/sfx/boss_spawn.wav")],
	&"boss_death": [preload("res://assets/audio/sfx/boss_death.wav")],
	&"dash": [preload("res://assets/audio/sfx/dash.wav")],
}

## Cues that must never be cut off mid-play. A telegraph the player did not hear
## is a hit they could not avoid, and boss.gd's own comment records audio
## telegraphing as a FAIRNESS requirement.
##
## Review finding 15: this pool was a priority-free round-robin with no
## playing-state check at all, so one Prism Lance volley — which calls take_hit,
## and therefore `hit`, once per enemy in the corridor in a single frame — could
## flush all twelve voices and cut the boss telegraph mid-swell. Endless is about
## to be full of bolts, so it was going to get worse, not better.
const PROTECTED: Array[StringName] = [
	&"boss_telegraph", &"boss_spawn", &"boss_death",
	&"death", &"hurt", &"levelup", &"shield_on", &"dash",
]
## Plays of the SAME cue allowed in one frame. Thirty enemies dying together is
## one sound, not thirty — and thirty copies at the same volume is just clipping.
## Two, not one, so a genuine double-event still reads as heavier than a single.
const SAME_FRAME_CAP: int = 2

## Minimum seconds between plays of a cue.
##
## Playtest 2026-08-02: "the sound effects seem a bit high pitched and it's not
## super clear what's making what sound", clarified to "TOO MANY SOUNDS AND ALL
## TOO SIMILAR". That is a density problem, not 23 individually-wrong cues — by
## 5:00 there are four weapons firing, a `hit` per projectile-enemy contact, a
## `pop` per kill at 3+ kills/second, and a `pickup` per gem. The same-frame cap
## above only collapses simultaneous plays; it does nothing about forty plays
## spread across forty consecutive frames, which is what a real run sounds like.
##
## Throttling here rather than at each call site so no future caller can forget,
## and so the numbers sit together where the mix can be reasoned about as a whole.
## Cues absent from this table are unthrottled by design — every one of them is
## either rare or safety-critical.
const THROTTLE: Dictionary = {
	&"shoot": 0.05,
	&"hit": 0.10,
	&"pop": 0.07,
	&"pickup": 0.16,
	&"bolt": 0.07,
}

var _players: Array[AudioStreamPlayer] = []
## What each voice is currently playing, so a protected cue can be recognised
## without asking the stream what it is.
var _voice_sound: Array[StringName] = []
var _next: int = 0
## Same-frame dedupe bookkeeping, reset whenever the frame counter moves.
var _frame: int = -1
var _frame_counts: Dictionary = {}
## cue -> last play time in ms, for THROTTLE.
var _last_played: Dictionary = {}


func _ready() -> void:
	# UI clicks must be audible while the tree is paused (level-up screen).
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_players.append(player)
		_voice_sound.append(&"")


## Variant choice and jitter use the global RNG on purpose: cosmetic randomness
## must never consume from the seeded run stream, or sounds would change replays.
func play(sound: StringName, volume_db: float = 0.0, pitch_jitter: float = 0.08) -> void:
	if not STREAMS.has(sound):
		push_warning("Sfx: unknown cue '%s'" % sound)
		return
	if not _allow_this_frame(sound) or not _past_throttle(sound):
		return
	var player: AudioStreamPlayer = _take_voice(sound)
	if player == null:
		return  # every voice is mid-telegraph; dropping is better than cutting
	var variants: Array = STREAMS[sound]
	player.stream = variants[randi() % variants.size()]
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()


## Rate-limit the high-frequency cues. Real time (`Time.get_ticks_msec`) rather
## than a game clock, because this is about what an EAR can resolve — a paused
## tree does not change how fast two clicks blur into one.
func _past_throttle(sound: StringName) -> bool:
	if not THROTTLE.has(sound):
		return true
	var now: int = Time.get_ticks_msec()
	var gap: int = int(float(THROTTLE[sound]) * 1000.0)
	if now - int(_last_played.get(sound, -100000)) < gap:
		return false
	_last_played[sound] = now
	return true


## Collapse duplicate plays of one cue within a single frame. Mass kills (Second
## Wind, a wide Lance volley, an Event Horizon cascade) all resolve in one frame
## and would otherwise fire dozens of identical one-shots at once.
func _allow_this_frame(sound: StringName) -> bool:
	var now: int = Engine.get_process_frames()
	if now != _frame:
		_frame = now
		_frame_counts.clear()
	var used: int = int(_frame_counts.get(sound, 0))
	if used >= SAME_FRAME_CAP:
		return false
	_frame_counts[sound] = used + 1
	return true


## Round-robin that refuses to steal a voice mid-way through a PROTECTED cue.
## Falls back to stealing only when the incoming cue is itself protected — a
## telegraph may interrupt a telegraph, ordinary chatter may not interrupt
## either.
func _take_voice(sound: StringName) -> AudioStreamPlayer:
	var incoming_protected: bool = PROTECTED.has(sound)
	for i: int in VOICES:
		var idx: int = (_next + i) % VOICES
		var candidate: AudioStreamPlayer = _players[idx]
		if candidate.playing and PROTECTED.has(_voice_sound[idx]):
			continue
		_next = (idx + 1) % VOICES
		_voice_sound[idx] = sound
		return candidate
	if not incoming_protected:
		return null
	var idx2: int = _next
	_next = (_next + 1) % VOICES
	_voice_sound[idx2] = sound
	return _players[idx2]
