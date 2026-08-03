class_name SkillNode
extends Resource
## One buyable node in the meta skill tree. Content as typed data, like every
## other authored thing here — never a dictionary, never code.
##
## TWO KINDS, and the difference is where the power lands:
##   STAT  a small permanent bump to the base numbers every run starts from.
##         Carries an UpgradeResource as its `payload` rather than duplicating
##         the effect switch — a node that says "+2 max HP" and an upgrade that
##         says "+2 max HP" must not be able to disagree about what that means.
##   CARD  puts a card into the DRAFT POOL that is otherwise absent from the
##         game. It grants nothing directly; the card still has to be drawn and
##         picked, so a purchase buys a possibility rather than a stat.
##
## The gate is the node's own id: a shop card's `requires_unlock` names the node
## that sells it, and `Main._offer_gates()` puts purchased node ids in the same
## array as profile unlocks and this run's weapon drafts. Three different
## questions, one mechanism, because the pool only ever asks "is this gate held".
##
## TUNED AGAINST A ZERO TREE. Every difficulty number in the game is balanced for
## an account that owns none of this, so the tree can only ever make the game
## easier than its tuning target — which is the mitigation that made shipping a
## permanent stat tree acceptable at all. Keep the numbers small.

enum Kind { STAT, CARD }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var kind: Kind = Kind.STAT
@export var cost: int = 50
## Row in the screen's grid. Purely presentational grouping — cheaper rows first.
@export var tier: int = 0

## STAT only. Applied to the player's Stats at run start.
@export var payload: UpgradeResource
## CARD only. The upgrade id this purchase makes draftable, for the catalogue
## text. The actual gating is by node id on the card's `requires_unlock`.
@export var grants_card: StringName = &""


## Apply a bought STAT node to a fresh run's stats. A no-op for CARD nodes, which
## is why Main can call this over every purchase without asking what kind it is.
func apply_to(stats: Stats) -> void:
	if kind == Kind.STAT and payload != null:
		payload.apply_to(stats)
