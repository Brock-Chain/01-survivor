class_name EnemySize
extends RefCounted
## Named size tiers, in VIEWPORT pixels (the arena is 640x360).
##
## Size became a first-class VARIANT axis in the BESTAGON pass: silhouette encodes
## the family, size and colour encode the variant within it. That rule only means
## something if size is a small set of deliberate steps rather than eight
## hand-picked floats — a "heavy" version of any enemy should be the next tier up,
## not a number someone eyeballed.
##
## It also makes a global rescale one edit. This file exists because the first
## rescale was ten.
##
## Raised 2026-08-02 after the first human playtest: "the small enemies are TOO
## small". Roughly +30% at the bottom of the ladder and +20% at the top, which
## averages near +25%. Bosses moved only +10% (they were already legible) and
## PROJECTILES DID NOT MOVE AT ALL — bolts are already at the edge of what reads
## as a bullet rather than a body, and the colour law leans on that distinction.

## The Dart. The smallest thing in the game that is not a bullet, and it has to
## stay clearly larger than one.
const SMALL: float = 16.0
## Baseline crowd: Drifter, Lancer, Splitter.
const MEDIUM: float = 18.5
## Things with weight behind them: Ram, heavy Lancer.
const LARGE: float = 21.0
## HP walls and boss fragments: Bulwark, Shard.
const HEAVY: float = 23.5

## Bosses are their own scale entirely and only moved 10%.
const BOSS: float = 35.0
## Nogaxeh is deliberately the largest thing in the game: it is the mirror, and
## "a hexagon that is not you" has to be unmistakable in the half-second before
## colour registers.
const MIRROR: float = 44.0

## NOTE: the two boss stat blocks are hand-authored .tres, not written by
## tools/gen_waves.gd, so BOSS and MIRROR are DUPLICATED as literals in
## resources/enemies/prism.tres and resources/enemies/nogaxeh.tres. Changing a
## value here means changing it there. Everything else in the roster reads these
## constants directly and cannot drift.
