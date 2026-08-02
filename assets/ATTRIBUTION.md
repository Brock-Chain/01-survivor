# Asset attribution

Every sprite and sound in this game is **generated** by [tools/gen_assets.py](../tools/gen_assets.py)
(deterministic Python script committed to this repo) — no third-party assets are used.
Generated assets are original works of this project and ship under the repo's license.

To regenerate after tweaking: `python tools/gen_assets.py`, then reimport
(`--headless --import`).
