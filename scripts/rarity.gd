class_name Rarity
extends RefCounted
## Rarity tiers and the roll that picks one. Pure — RNG and run progress are
## both injected — so the odds are assertable without playing for six minutes.
##
## Rolled PER CARD, not per level-up: a screen reading Common / Common / Epic is
## what makes the Epic land. If every card on screen were Legendary, none of
## them would feel like one.
##
## Odds shift toward the high tiers as the run progresses, so a level-30 screen
## feels different from a level-3 screen without needing more level-ups.

enum Tier { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

const TIER_COUNT: int = 5

## Display names, indexed by Tier.
const NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

## The conventional rarity hues, rendered as neon so they sit inside the game's
## palette rather than fighting it. Saturation and glow scale with tier too, so
## the ladder still reads in a screenshot where animation cannot help.
const COLORS: Array[Color] = [
	Color(0.62, 0.68, 0.78),   # Common    — cool grey LED
	Color(0.45, 1.00, 0.62),   # Uncommon  — electric green
	Color(0.36, 0.68, 1.00),   # Rare      — electric blue
	Color(0.72, 0.45, 1.00),   # Epic      — neon violet
	Color(1.00, 0.78, 0.25),   # Legendary — hot gold
]
## Glow strength per tier, as a second channel so rarity survives a screenshot.
const GLOWS: Array[float] = [0.0, 0.25, 0.5, 0.8, 1.0]

## Draw weights at the START of a run and at full progress. Every roll lerps
## between the two, so early runs are mostly Commons and late ones are not.
const EARLY: Array[float] = [62.0, 26.0, 10.0, 2.0, 0.3]
const LATE: Array[float] = [30.0, 30.0, 24.0, 12.0, 4.0]

## Level-ups without a Rare-or-better before one is guaranteed. A cold streak
## that lasts a whole run is the single worst thing a random reward can do, and
## it is invisible in aggregate stats — so it gets a hard floor rather than a
## hope.
const PITY_LIMIT: int = 6
const PITY_TIER: Tier = Tier.RARE

## Progress saturates here: past this level the odds stop improving, so a long
## endless run cannot drift into handing out Legendaries every screen.
const PROGRESS_FULL_LEVEL: float = 30.0


static func name_of(tier: Tier) -> String:
	return NAMES[clampi(int(tier), 0, TIER_COUNT - 1)]


static func color_of(tier: Tier) -> Color:
	return COLORS[clampi(int(tier), 0, TIER_COUNT - 1)]


static func glow_of(tier: Tier) -> float:
	return GLOWS[clampi(int(tier), 0, TIER_COUNT - 1)]


## 0.0 at level 1, 1.0 at PROGRESS_FULL_LEVEL and beyond.
static func progress_for_level(level: int) -> float:
	return clampf((float(level) - 1.0) / maxf(1.0, PROGRESS_FULL_LEVEL - 1.0), 0.0, 1.0)


## Draw weights at a given progress, lerped between EARLY and LATE.
static func weights(progress: float) -> Array[float]:
	var p: float = clampf(progress, 0.0, 1.0)
	var out: Array[float] = []
	for i: int in TIER_COUNT:
		out.append(lerpf(EARLY[i], LATE[i], p))
	return out


## Roll one card's tier. `pity` is the number of consecutive level-ups without a
## Rare-or-better; at PITY_LIMIT the result is floored to PITY_TIER.
static func roll(rng: RandomNumberGenerator, progress: float, pity: int = 0) -> Tier:
	var w: Array[float] = weights(progress)
	var total: float = 0.0
	for value: float in w:
		total += value
	var pick: Tier = Tier.COMMON
	if total > 0.0:
		var target: float = rng.randf() * total
		for i: int in TIER_COUNT:
			target -= w[i]
			if target <= 0.0:
				pick = i as Tier
				break
	if pity >= PITY_LIMIT and int(pick) < int(PITY_TIER):
		return PITY_TIER
	return pick
