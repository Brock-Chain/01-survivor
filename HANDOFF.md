# Session handoff — 2026-08-03

Transient. Delete once the next session has absorbed it. `TODO.md` is the durable
source of truth; `BRIEF.md` is the spec; `DECISIONS.md` is why things are the way
they are.

## Where we are

**The game is on itch.io and a human who did not build it has played it.** That is
the milestone: 7.9 ("measure with a human run") is no longer pending, and M8 is
the only thing between here and ship.

Working tree clean, `verify.ps1` green with **117 tests**, both builds packaged by
`tools/package.ps1`. The page is `brock-chain.itch.io/bestagon`, **Restricted +
password** — not public, deliberately, until the tuning below is settled.

## What the first external session produced

Six defects, all fixed and shipped. Three were reported by the player, three were
found by looking where the report pointed.

| # | Found by | Defect |
|---|---|---|
| 1 | screenshot before packaging | title menu overflowed the viewport AND sat against the bottom edge |
| 2 | screenshot of the live build | `◆` rendered as a tofu box — the font ships with zero fallbacks |
| 3 | player | Aegis "practically invisible, cant tell when it's on or off" |
| 4 | player | "0 indication we are getting stat boosts when leveling up" |
| 5 | player | ESC does not pause in fullscreen (the browser owns that key) |
| 6 | player | bosses too small; enemies "latch on weirdly" after they hit you |

Every one is written up in `DECISIONS.md` with its reasoning, and the reusable
half is in the hub (`knowledge/web-fonts-and-missing-glyphs.md`,
`the-browser-owns-your-runtime.md`, `power-the-player-cannot-perceive.md`,
`ui-must-fit.md`, `pipeline/publish-to-itch.md`).

## The open question: the freeze

The player twice saw the game **freeze and then recover** in a fullscreen browser
tab, at 3:52/588 kills and 4:19/699 kills. Not fixed, because not reproduced.

What was ruled out **by measurement**, not by inspection:

- **No leak.** Desktop soak: nodes oscillate 176→632→391 and return, objects flat
  at ~2400, memory pinned at ~38 MB, orphans zero, through 1068 kills. A
  self-playing web build in a clean browser: flat through 833 kills / 4:45 —
  past both freeze points — with zero main-thread stalls over 200 ms.
- **No engine error.** Every red line in the player's console came from two
  crypto-wallet extensions fighting over `window.ethereum`. The only game-origin
  line is a harmless `screen.orientation.lock()` at startup.
- **No synchronous work to blame** — no runtime `load()`, no disk I/O during a
  run, SFX voice-pooled, telemetry hard-disabled on web.

**Working hypothesis:** the browser stops `requestAnimationFrame` for a tab it
considers hidden, and Godot's web build drives its whole main loop from rAF — so
the loop stops and later resumes exactly where it left off, which is
indistinguishable from a freeze that recovers, and logs nothing. Auto-pause on
focus loss now makes that stop deliberate rather than mysterious.

**This is a hypothesis, not a diagnosis.** If it recurs while the tab is
demonstrably focused and in the foreground, the hypothesis is wrong and the next
step is different: instrument frame times inside the build itself and get the
number, rather than reasoning further. The untried cheap test is an
incognito/no-extension run.

## What still needs you

1. **Re-upload** `builds/BESTAGON-web-2026-08-03.zip` and play it. Confirm the six
   fixes, and see whether the freeze recurs.
2. **Tune 7.9 with real numbers.** Nothing below has been touched by a human run
   yet — bot soaks cannot judge any of it:
   - is the 10:00 fight the ~2 minute climax it is budgeted as?
   - does the difficulty ramp hold between 5:00 and 10:00?
   - do the level-up cards feel like decisions at one per three levels?
   - **note:** doubling the bosses also doubled their hitboxes, so both fights are
     now easier to land shots on. Read the next timings with that in mind.
3. **Decide on a licence.** There is no `LICENSE` file and this repo is public.

## Do not re-litigate

- **GRID**, not "The Lattice" — named by the human. A hex-cell layout for it is
  parked in `TODO.md` as a later idea, not a todo.
- **AI disclosure is Yes with all four sub-classifications ticked**, reasoned in
  `tools/share/ITCH-PAGE.md`. Decided on asymmetry: under-tagging risks
  delisting, over-tagging costs a browse filter already accepted.
- **The web zip must have `index.html` at its root** and must ship
  `START-HERE.bat`. `tools/package.ps1` asserts both — use it, do not zip by hand.

## Superseded

The previous handoff (2026-08-02, M7 rework) is fully absorbed: its open item was
7.9, which this session closed by putting the game in front of a person. The
telemetry/records bug it described is fixed; `save.cfg` was left untouched by
deliberate choice, and repairing `best_kills`/`best_time`/`unlocks` in the human's
own profile is still a one-line edit awaiting their say-so.
