extends Node2D
## Run orchestrator: owns run state (time, kills, xp) and wires everything.
## Children signal up; Main calls down. Nothing else knows about Main.

const ARENA: Rect2 = Rect2(0, 0, 1280, 720)

const XP_GEM_SCENE: PackedScene = preload("res://scenes/pickups/xp_gem.tscn")

## Explicit preloads, not DirAccess scanning — directory listings misbehave
## inside exported .pck files (resources get .remap suffixes).
const UPGRADE_LIST: Array[UpgradeResource] = [
	preload("res://resources/upgrades/swift_boots.tres"),
	preload("res://resources/upgrades/tough_hide.tres"),
	preload("res://resources/upgrades/sharp_shots.tres"),
	preload("res://resources/upgrades/rapid_fire.tres"),
	preload("res://resources/upgrades/split_shot.tres"),
	preload("res://resources/upgrades/velocity.tres"),
	preload("res://resources/upgrades/magnetism.tres"),
	preload("res://resources/upgrades/scholar.tres"),
	preload("res://resources/upgrades/bandage.tres"),
	preload("res://resources/upgrades/cannonball.tres"),
]

var time_survived: float = 0.0
var kills: int = 0
var total_xp: int = 0
var level: int = 1
var xp_into_level: int = 0
## id -> times taken; the pool uses this to respect stack caps.
var stacks: Dictionary = {}

var pool: UpgradePool
var run_rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var player: Player = $Player
@onready var spawner: Spawner = $Spawner
@onready var enemies: Node2D = $Enemies
@onready var pickups: Node2D = $Pickups
@onready var projectiles: Node2D = $Projectiles
@onready var level_up_panel: LevelUpPanel = $LevelUpPanel
@onready var hud: Hud = $Hud
@onready var game_over: GameOverScreen = $GameOver


func _ready() -> void:
	run_rng.randomize()
	pool = UpgradePool.new(UPGRADE_LIST, run_rng)
	spawner.target = player
	spawner.container = enemies
	spawner.arena = ARENA
	spawner.enemy_spawned.connect(_on_enemy_spawned)
	player.died.connect(_on_player_died)
	player.health_changed.connect(hud.set_health)
	player.weapon.container = projectiles
	level_up_panel.upgrade_chosen.connect(_on_upgrade_chosen)
	hud.set_health(player.health.hp, player.health.max_hp)
	hud.set_xp(xp_into_level, Progression.xp_required(level), level)
	print("01-survivor boot OK — Godot %s" % Engine.get_version_info()["string"])


func _physics_process(delta: float) -> void:
	time_survived += delta
	hud.set_run(time_survived, kills)


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
	var gained: int = roundi(xp_value * player.stats.xp_mult)
	total_xp += gained
	xp_into_level += gained
	_check_level_up()
	hud.set_xp(xp_into_level, Progression.xp_required(level), level)


func _check_level_up() -> void:
	var required: int = Progression.xp_required(level)
	if xp_into_level < required:
		return
	xp_into_level -= required
	level += 1
	var offers: Array[UpgradeResource] = pool.draw(3, stacks)
	if offers.is_empty():
		return  # everything maxed — nothing to offer, keep playing
	get_tree().paused = true
	level_up_panel.show_offers(offers, level)


func _on_upgrade_chosen(upgrade: UpgradeResource) -> void:
	stacks[upgrade.id] = int(stacks.get(upgrade.id, 0)) + 1
	upgrade.apply_to(player.stats)
	# Two effects touch live Health, which Stats can't know about:
	match upgrade.effect:
		UpgradeResource.Effect.MAX_HP:
			player.health.raise_max(int(upgrade.magnitude))
		UpgradeResource.Effect.HEAL:
			player.health.heal(int(upgrade.magnitude))
	player.refresh_from_stats()
	get_tree().paused = false
	_check_level_up()  # banked XP can trigger another level immediately


func _on_player_died() -> void:
	get_tree().paused = true
	game_over.show_results(time_survived, kills, level)
