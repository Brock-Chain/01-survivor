extends Node2D
## Run orchestrator: owns run state (time, kills, xp) and wires everything.
## Children signal up; Main calls down. Nothing else knows about Main.

const ARENA: Rect2 = Rect2(0, 0, 1280, 720)

const XP_GEM_SCENE: PackedScene = preload("res://scenes/pickups/xp_gem.tscn")

var time_survived: float = 0.0
var kills: int = 0
var total_xp: int = 0

@onready var player: Player = $Player
@onready var spawner: Spawner = $Spawner
@onready var enemies: Node2D = $Enemies
@onready var pickups: Node2D = $Pickups
@onready var projectiles: Node2D = $Projectiles


func _ready() -> void:
	spawner.target = player
	spawner.container = enemies
	spawner.arena = ARENA
	spawner.enemy_spawned.connect(_on_enemy_spawned)
	player.died.connect(_on_player_died)
	player.weapon.container = projectiles
	print("01-survivor boot OK — Godot %s" % Engine.get_version_info()["string"])


func _physics_process(delta: float) -> void:
	time_survived += delta


func _on_enemy_spawned(enemy: Enemy) -> void:
	enemy.died.connect(_on_enemy_died)


func _on_enemy_died(xp_value: int, at: Vector2) -> void:
	kills += 1
	# died fires from a physics callback (projectile body_entered) — adding
	# an Area2D to the tree mid-flush is forbidden, so defer the spawn.
	_spawn_gem.call_deferred(xp_value, at)


func _spawn_gem(xp_value: int, at: Vector2) -> void:
	var gem: XpGem = XP_GEM_SCENE.instantiate()
	gem.setup(xp_value)
	gem.position = at
	pickups.add_child(gem)
	gem.collected.connect(_on_gem_collected)


func _on_gem_collected(xp_value: int) -> void:
	total_xp += roundi(xp_value * player.stats.xp_mult)


func _on_player_died() -> void:
	print("game over — survived %.1fs, %d kills" % [time_survived, kills])
