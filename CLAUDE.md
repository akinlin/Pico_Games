# Meta Pong — working instructions

Meta Pong is a PICO-8 Pong clone. The player boots into what looks like a faithful
1972 arcade Pong replica and finds the second paddle unmanned. After two points the
machine introduces itself: COM, an AI that has always been in the circuitry. Across
five acts COM moves through the five stages of grief, and the gameplay rules change
with him.

The cart is `pong.p8` at repo root. There is a second unrelated cart, `possesor.p8` —
do not touch it.

---

## Source of truth

The design lives in the GitHub wiki, mirrored into this repo:

- `docs/game-design.md` — story, acts, player experience. **Authoritative.**
- `docs/tech-design.md` — how it gets built. Derived from Game Design.
- `docs/BUILD-PLAN.md` — ordered milestones and their acceptance criteria.

Rules that matter:

1. Game Design is upstream of Tech Design. If an implementation detail implies a
   design change, stop and raise it — do not resolve it in code.
2. Tech Design describes **target state**, never build status. Build status lives in
   GitHub issues and `docs/BUILD-PLAN.md`.
3. If code and `docs/` disagree, `docs/` wins and the code is a bug.
4. If you believe `docs/` is wrong, say so and wait. Do not edit `docs/` unless asked.

---

## How we work

**You cannot run this code.** There is no PICO-8 binary here, no screenshots, no test
harness. Every behavioral claim you make is a hypothesis until the user launches the
cart and reports back. Therefore:

- Work in small increments that the user can verify by eye in one sitting.
- End every change with a short **"verify this"** block: what to look at, what correct
  looks like, and what a specific failure would look like. Be concrete —
  "the ball should cross the field in about 4.3 seconds at rally start" beats
  "check the ball speed feels right."
- When a value needs playtesting rather than derivation (paddle acceleration curve,
  dialogue timer durations), say so explicitly and give a starting value with a range.
- Never claim something "works" or "is tested."

**Debugging.** `printh()` writes to the host console and is the only real logging
channel. The existing cart has a `draw_debug()` for collision-point visualization —
keep that pattern, keep it behind a flag, and strip it before a milestone closes so it
doesn't eat the character budget.

**Commits.** One milestone per branch, conventional-commit style subject lines,
reference the issue number. Do not push or open PRs without being asked.

---

## Hard constraints

| Budget | Ceiling | Reality |
|---|---|---|
| Characters | 65,535 | **The binding constraint.** Shared between engine code and every line COM speaks. Engine bloat directly costs dialogue. |
| Tokens | 8,192 | A whole string literal is 1 token, so dialogue is nearly free here. |
| CPU | 139,810 cycles/frame at 60fps | Binds only during Anger's swarm. |
| Compressed code | 15,360 bytes | Only enforced for `.p8.png` / `.p8.rom` export. |
| Sprites / SFX / music | 256 / 64 / 64 | Not close to binding. |

Estimated worst-case frame, for budgeting against: `cls()` 2,052 cycles (1.5%); 40 balls
swept collision ~20,000 (~14%); drawing 40 balls ~1,500 (~1%); scanlines ~0; phosphor
~33,000 (~24%). Anger therefore runs at roughly **17%** of frame before dialogue, AI and
paddle costs; the four acts that do run phosphor land near **27%** against a single ball.
Both are estimates from published per-operation costs, not measurements.

Engine footprint is a standing priority. When two implementations are equally correct,
take the smaller one. Bargaining's pre-match choice system is the one sanctioned
exception — it is expected to be the largest act-specific chunk of code in the cart.

**Target: PICO-8 0.2.7, cart header `version 43`.** The file currently says
`version 41` (0.2.5g). 0.2.7 fixes a `dset()` flush bug that silently drops writes when
data changes more than once in a second — persistence is unreliable without it. There
is no 0.2.8; do not "upgrade" past 0.2.7.

---

## Numbers you must not get wrong

These are derived from the original hardware and are the reason the game feels right.
Do not round them, do not "simplify" them, do not replace the lookup tables with
trigonometry.

### Screen layout

The original playfield is 375 clocks × 246 scanlines at 4:3 — non-square pixels.
Mapping it to 128×128 changes every return angle. So:

| Region | Rows |
|---|---|
| Playfield | 0–95 (128×96, exactly 4:3) |
| Terminal band (dialogue) | 96–127 (32px, permanent) |

Scale: **0.3413 px per horizontal clock**, **0.3902 px per scanline**. Ratio 1.143 =
the pixel-aspect correction, which is why angles carry over exactly.

| Element | Value |
|---|---|
| Paddle | 1 px wide × 6 px tall |
| Ball | 2 × 2 px (radius 1) |
| Net | x = 64, 1 px wide, 2 on / 2 off |
| COM paddle x | 20 |
| Player paddle x | 108 |
| Paddle travel | top-edge `y` from **6 to 84** (one paddle height of dead zone each end) |
| Serve x | 66 |

Ball, net, and paddle *width* are rounded up to minimum legible size — strict scaling
would put them under a pixel. Those three are deliberate departures. Everything else
is derived and must not be adjusted for "feel."

### Fixed-point is mandatory

The ball moves **sub-pixel on most frames**. Store position as a fractional value —
PICO-8 numbers are natively 16.16 fixed point, so this costs nothing — and round only
at draw time. Integer pixel steps cannot reproduce the angle set.

This matters most in zone selection: the 6px paddle divides into eight **0.75 px**
bands, narrower than the ball. Zone selection uses the **fractional** offset between
ball center and paddle top edge. Rounding here collapses eight zones into six and
destroys the flat center band.

### The velocity model — 42 vectors

Vertical and horizontal velocity come from **completely independent sources**, exactly
as in the hardware. 7 vertical states × 3 horizontal tiers × 2 directions = 42.

**Horizontal speed** — three discrete tiers off a rally hit counter. There is no
continuous acceleration. The counter saturates at 12 and resets to tier 1 on any point
scored or new match.

| Rally hits | Tier | px/frame | Cross-court |
|---|---|---|---|
| < 4 | 1 | 0.341 | 4.3 s |
| 4–11 | 2 | 0.683 | 2.1 s |
| ≥ 12 | 3 | 1.024 | 1.4 s |

"Cross-court" means the **88 px paddle-to-paddle separation**, not the 128 px screen
width. Timing wall-to-wall gives ~6.3 s at tier 1 and will look like a failure on
correct code.

**Vertical speed** — set solely by which of the paddle's eight zones the ball strikes.
Note that **two adjacent center zones both return horizontally**: the flat band is a
quarter of the paddle face, the widest single feature on it, not a thin sweet spot.

| Zone (top first) | Vertical velocity | Offset |
|---|---|---|
| 1 | 1.171 up | ±3 |
| 2 | 0.780 up | ±2 |
| 3 | 0.390 up | ±1 |
| **4** | **0 — horizontal** | center |
| **5** | **0 — horizontal** | center |
| 6 | 0.390 down | ±1 |
| 7 | 0.780 down | ±2 |
| 8 | 1.171 down | ±3 |

Resulting angles — note that **faster rallies give shallower angles**:

| Offset | Tier 1 | Tier 2 | Tier 3 |
|---|---|---|---|
| Center | 0° | 0° | 0° |
| ±1 | 48.8° | 29.7° | 20.9° |
| ±2 | 66.4° | 48.8° | 37.3° |
| ±3 | 73.7° | 59.7° | 48.8° |

Implement as a flat lookup: 7 vertical values × 3 horizontal values. **No trigonometry,
no per-hit angle math.** The angle table above is a consequence, not an input.

### There is no spin

The original paddle is an analog potentiometer with no velocity signal anywhere in the
circuit. Direction of travel at contact cannot and does not affect the return. Return
angle is determined entirely by zone and tier.

`apply_spin()` currently exists in `pong.p8` and must be deleted. Spin survives only in
the Parking Lot as an unused idea for signalling COM cheating.

### Serve

| Rule | Behavior |
|---|---|
| Delay | ~1.7 s between the point scoring and the ball reappearing |
| Position | x = 66, two pixels clear of the net |
| Direction | Horizontal direction is unchanged by a miss — **the ball is served toward whoever missed it** |
| Vertical velocity | Whatever it was at the moment of the miss |
| Vertical position | The ball keeps travelling and bouncing **invisibly** through the delay, so its height on reappearance is effectively arbitrary. This is why the original's serve feels random. **Reproduce it deliberately — this is not a bug.** |
| First serve of a match | Always max vertical speed (±1.171), the steepest angle the model produces, at horizontal tier 1 |

**One exception to the direction rule:** Bargaining's third choice can set
`com_serves_every_point`, which overrides the hardware behavior so the player never gets
the receive advantage that scoring normally earns them. Everywhere else, the rule is
absolute.

### Collision

One model for all five acts: line-segment intersection between the ball's per-frame
movement vector and each wall's near edge, expanded by ball radius. Chosen because it
matches the hardware's rectangle-region approach and is inherently tunneling-proof at
sub-pixel speeds. Corners resolve as reliably as flat edges.

Top/bottom bounds and both paddles share one collidable shape in `walls[]`
(`x, y, width, height`). In `attract`, two side walls are added so the ball bounces off
all four edges; in `level` they are removed and the sides become scoring exits.

The engine operates on a **collection** of balls (`balls[]`), not a single instance, so
Anger's three tests are configuration rather than new code. Each ball carries its own
position, velocity, tier counter, and behavior mode.

Inner-loop discipline for the swarm: cache globals and table fields into locals, use
numeric `for` not `foreach`, reject with a cheap AABB test before the exact segment
test, and never call `sqrt()` — compare squared distances.

### Audio

All three original sounds were taps off the vertical ball-position counter, not a
dedicated oscillator. All muted in `attract`.

| Sound | Trigger | Freq | Duration |
|---|---|---|---|
| Hit | Ball contacts a paddle | ~492 Hz | ~16 ms |
| Bounce | Ball contacts top/bottom bound | ~246 Hz | ~16 ms |
| Score | Ball exits the field | ~246 Hz | ~240 ms |

---

## Architecture

Two top-level states only — `attract` and `level`. (The current cart has six:
title/menu/options/level/gameover/intermission. They collapse into these two.)
**Any button press** moves `attract` → `level`.

`level_index` on entering `level` is set to one past the last **persisted, completed**
act, or 1 (Denial) with no checkpoint. A checkpoint of 5 means the game is finished;
start begins a fresh run at Denial with the completion badge left in place.

**One Pong engine, parameterized per act.** Never fork the engine. Each `level` owns a
Customization config applied to its `pong` instance on load. The axes are listed in
`docs/tech-design.md` → Architecture → Per-act configuration. If an act needs behavior
that is not expressible as a config axis, that is a signal to add an axis, not to
special-case the engine.

Two axes whose values are easy to under-specify:

- **`ball_mode`** — `replica` (the standard model above), `slow_fast` (ball approaches
  very slowly then rebounds fast off the player's paddle), `homing` (ball actively
  seeks toward the player's paddle). `ball_mode_pool` holds the set Depression draws
  from, one per serve.
- **`nickname`** — none in Denial, then **DUM** (Anger), **SKR** (Bargaining),
  **WHR** (Depression), **PLR** (Acceptance). All three characters long, which is why
  name entry is three characters. COM's own displayed name never changes.

**Persistence** via `cartdata("akinlin_metapong_1")`:

- `furthest_completed_act` — `dset(0, n)` / `dget(0)`, number **0–5** where 5 means
  finished. Written on each act win.
- `completion_name` — 3 bytes at `0x5e04` via `poke(0x5e04, a, b, c)` /
  `peek(0x5e04, 3)`. Written on Acceptance win.

cartdata gives 64 slots × 4 bytes, each slot holding **one 32-bit 16.16 number** — a
string cannot be stored directly. The name is therefore **three indices into the game's
own alphabet string** (0–35 for A–Z, 0–9), one byte each: immune to glyph and case
handling, trivially validated on load. **Do not bit-shift-pack** — `<<16` overflows the
16.16 range.

**Narrative engine** data model is `stage` → `section` → `line`. Six stages: one per
act plus the pre-Denial Intro, which Denial's `level` owns and swaps out when the
Intro's close trigger fires. Each act's `stage` plugs in its own state machine
(`init`/`change_state`/`update`/`states`) against a shared framework rather than
subclassing — Denial's score-checkpoint branching and Anger's linear gated sequence are
authored independently.

The current code calls these `dialogue`/`section`/`phrase`. Rename to
`stage`/`section`/`line` (issue #33).

Two dialogue rules that are easy to violate by accident:

- **Scrollback history clears whenever the window closes and reopens.** A Section runs
  continuously between its open- and close-trigger; it does not inherit the previous
  Section's lines.
- **There is no player advance or skip button.** Dialogue is fully automatic. Do not add
  one. Bargaining's paddle-position choice system is a gameplay mechanic, not an
  exception to this.

---

## PICO-8 specifics

- **`_update60`, not `_update`.** 60 fps matches the machine's 60.05 Hz field rate, and
  every velocity above is expressed in units per 60 Hz frame.
- **No `dt`.** The current cart derives `dt` from `time()` and multiplies velocities by
  it. Delete that. Fixed 60 Hz means velocities are applied per frame, full stop. This
  also removes a class of tunneling bugs.
- **Palettes** are two precomputed 16-byte tables per act — base display palette and
  darkened scanline palette — applied with `memcpy(0x5f10, addr, 16)` and
  `memcpy(0x5f60, addr2, 16)`. One call each, ~5 tokens. They target the *display*
  palette, so they recolor the entire frame including already-drawn pixels at zero
  per-object cost. **Both must be swapped together on act load** or the scanlines keep
  the previous act's colors.
- **CRT scanlines** use per-line palette hardware: `poke(0x5f5f, 0x10)`, scanline
  palette at `0x5f60`–`0x5f6f`, per-line selection bitfield at `0x5f70`–`0x5f7f`. Set
  once, applied by the display hardware at no per-frame cost. Always on, every act.
  Two caveats: this shares `0x5f60`–`0x5f6f` with `fillp`'s secondary palette, so the
  two cannot both be used; and **these addresses are undocumented in the manual**, so
  re-verify against any future release.
- **Phosphor glow** is frame-blending via a stashed previous frame in remapped video
  memory. Costs ~24% of the frame budget, so it is a per-act config axis: on in Denial,
  Bargaining, Depression, Acceptance; **off in Anger**, where the frame goes to the
  swarm.
- **`btnp()` auto-repeat** timing is tuned via `0x5f5c` (delay) and `0x5f5d` (interval).
  Needed for name entry.
- **Do not use keyboard input** (`stat(30)`/`stat(31)`). It requires devkit mode,
  displays a warning banner to BBS players, and does not exist on handheld or mobile
  targets. Name entry is button-driven.
- **Do not use mouse input**, for the same reasons. Paddle control is buttons with
  acceleration/momentum.

---

## Deliberate divergences from the 1972 hardware

Flagged so you don't "fix" them:

1. **Paddle control is buttons with acceleration**, not an analog knob. Faithful
   reproduction needs mouse input, which is unavailable on handhelds. Momentum-based
   buttons approximate the felt experience of a physical control better than
   fixed-speed buttons, and cost nothing that would otherwise go to dialogue. Curve and
   max speed are playtest-tuned.
2. **The net is centered at x = 64.** The original picture sits slightly left of true
   center (visual center H≈267 against a net at H=256) — a documented hardware defect.
   Meta Pong centers it properly and places paddles symmetrically at 44 px either side.
3. **Ball, net, and paddle width** are rounded up to minimum legible size.
4. **A 32px terminal band** exists at all, replacing 32 rows of playfield.

---

## Known-stale GitHub issues

Several issues were written before the 2026-07-27 design review and describe superseded
behavior. Read `docs/` first; treat these issue bodies as historical:

- **#30** — describes a 90° center segment and says to combine with `apply_spin()`.
  Both wrong: two center zones return horizontally, and spin is cut entirely.
- **#32** — says the CRT treatment is global and the technique is TBD. Scanlines are
  global and the technique is specified; phosphor is per-act and off in Anger.
- **#34** — says `furthest_completed_act` is 0–4 and `completion_name` is a string.
  It's 0–5, and the name is three alphabet indices at `0x5e04`.
- **#29** — lists Depression's ball as purple (`13`). It is white (`7`); Depression is
  the easiest act to score in and the ball stays maximally legible.
