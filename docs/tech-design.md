<!-- MIRROR OF THE GITHUB WIKI. Do not edit here.
     Source: https://github.com/akinlin/Pico_Games/wiki/Meta-Pong
     Edit the wiki, then re-sync this file. -->

# Meta Pong — Tech Design

## Tech Design

*Tech Design describes how the game gets built to match Game Design — rendering/visuals, sound, physics, and translating the real Pong hardware behavior into Lua/PICO-8. Game Design is the source of truth: implementation details here never originate a design change; if something here implies one, it gets resolved in Game Design first.*

### Overview

- **Platform:** PICO-8 **0.2.7** (cart format `version 43`)
- **Language:** Lua
- **Frame rate:** 60 fps (`_update60`) — matches the original machine's 60.05 Hz non-interlaced field rate, and the entire velocity model below is expressed in units per 60 Hz frame
- **Repository:** [pong.p8](https://github.com/akinlin/Pico_Games/blob/master/pong.p8)

The cart is two small games running side by side, coordinated by a thin state-machine layer:

| System | Responsibility | Key objects |
|---|---|---|
| Pong engine | Arcade ball/paddle/wall physics, AI difficulty | `pong`, `wall`, `ball`, `ai_levels` |
| Narrative engine | CLI dialogue driving COM's five-act arc | `stage`, `section`, `line`, `textbox` |
| Orchestration | Owns the top-level screen, coordinates the two per act | `game_manager`, `level` |

### Playfield & geometry

The original playfield is **375 clocks × 246 scanlines displayed at 4:3** — the pixels are not square, one scanline being 1.143× taller than one clock is wide. Mapping that onto a square 128×128 area would change every return angle and invalidate the velocity model.

The screen is therefore split:

| Region | Rows | Purpose |
|---|---|---|
| Playfield | 0–95 | 128×96 — exactly 4:3, so the original angle set is preserved |
| Terminal band | 96–127 | 32-pixel permanent home for the CLI dialogue window |

Scale factors: **0.3413 px per horizontal clock**, **0.3902 px per scanline**. Their ratio is 1.143, which is precisely the pixel-aspect correction — so angles carry over exactly.

| Element | Original | Meta Pong |
|---|---|---|
| Paddle height | 15 scanlines | **6 px** |
| Paddle width | 4 clocks | **1 px** |
| Ball | 4 clocks × 4 lines | **2 × 2 px** |
| Net | 1 clock wide, 4 on / 4 off | 1 px wide, 2 on / 2 off |
| Net position | H=256 | **x = 64** |
| Player 1 (COM) paddle | H=128 | **x = 20** |
| Player 2 (human) paddle | H=384 | **x = 108** |
| Paddle separation | 256 clocks | **88 px** |

Paddle height and the positional values above follow the scale factors directly. Ball, net and paddle *width* are rounded up to the minimum legible size — strict scaling would put them below one pixel — so those three are deliberate departures rather than derived values. Ball size in particular has no effect on the angle model, which depends only on contact position and rally tier.

The original picture sits slightly left of true center (visual center H≈267 against a net at H=256) — a documented hardware defect. Meta Pong centers the net properly and places the paddles symmetrically about it, at 44 px either side.

**Paddle travel limits.** The original paddles cannot reach the extreme top or bottom of the field. The gap size is not documented in any surviving source, so Meta Pong uses **one paddle height (6 px) of dead zone at each end**: paddle top-edge `y` ranges from 6 to 84.

**Fixed-point positions are mandatory.** At this scale the ball moves **sub-pixel** on most frames (see the speed table below). Ball position is stored as a fractional value — PICO-8 numbers are natively 16.16 fixed point, so this is free — and rounded only at draw time. Integer pixel steps cannot reproduce the angle set.

### Architecture

**Top-level states:**

| State | Entered from | Behavior | Exits to |
|---|---|---|---|
| `attract` | boot; return from a completed run | Ball bounces off all four walls (two side walls are added to `walls[]` in this state and removed on entering `level`); net drawn; previous match's score retained, 0–0 on cold boot; paddles hidden; sound muted; completion badge shown if a persisted `completion_name` exists | Any button press → `level` |
| `level` | `attract` | Runs the current act's `pong` + `stage` concurrently | Act win → advance/complete; act loss → reset & loop |

**Resolving a level result:**

| Outcome | `level_index` | Result |
|---|---|---|
| Win, acts 1–4 (Denial–Depression) | `+1` | Load next act's level; stay in `level` state |
| Win, act 5 (Acceptance) | → 5 | Name entry → persist completion + name → `attract` |
| Loss, any act | unchanged | Reset current level (fresh dialogue + pong state), replay same act |

On entering `level` from `attract`, `level_index` is set to one past the last **persisted, completed** act (or `1`/Denial with no checkpoint) — returning players resume rather than restarting. A checkpoint of `5` means the game has been completed, and start begins a fresh run at Denial with the badge left in place.

**Per-act configuration.** One Pong engine is parameterized per act rather than forked. Each `level` owns a Customization config, applied to its `pong` instance on load:

| Axis | Field | Example use |
|---|---|---|
| Paddle size | `paddle_height` (per side) | Bargaining: longer player paddle |
| Paddle motion | `paddle_max_speed`, `paddle_accel` (per side) | Anger: faster paddles. Bargaining: slower COM paddle |
| Ball count | `ball_count`, spawn table | Anger: 1 → 2 → staggered swarm |
| Ball behavior | `ball_mode` (`replica`, `slow_fast`, `homing`), `ball_mode_pool` | Depression: pool of `slow_fast` + `homing`, one drawn per serve |
| Ball speed | `speed_tier_pin` — pins the rally tier instead of letting it climb | Anger: pinned to tier 3 |
| Win condition | `win_score_player`, `win_score_com`, `sudden_death` | Depression: 5 vs. 11. Bargaining: sudden death |
| Scoring | `scoring_model` (`rally` / `intercept`), `score_multiplier_com`, `initial_score_com`, `scoring_enabled` | Anger: `intercept` — a paddle contact resolves the point. Bargaining: 3× COM points, 10-point head start. Depression: scoring off during the closing dialogue |
| Serve | `com_serves_every_point` | Bargaining choice 3 |
| AI | `ai_enabled`, `ai_mode` (`self_balancing` / `fixed`), `ai_tier` | Denial opens with `ai_enabled = false` (unmanned paddle) and the Intro stage switches it on mid-Section. Acceptance: `fixed`. Depression closing: `ai_enabled = false` |
| Rendering | `palette` (per-act role colours), `nickname`, `phosphor_mode` (`off`/`ball`/`full`) | Per-act colors; phosphor `off` in Anger |

**Persistence.** Two values survive across sessions, via `cartdata("akinlin_metapong_1")`:

| Value | Storage | Written | Read |
|---|---|---|---|
| `furthest_completed_act` | `dset(0, n)` / `dget(0)` — number 0–5, where 5 means the game is finished | on each act win | on `attract` load, sets resume `level_index` |
| `completion_name` | 3 bytes at `0x5e04`, written with `poke(0x5e04, a, b, c)` and read with `peek(0x5e04, 3)` | on Acceptance win | on `attract` load, drives the badge display |

`cartdata` provides 64 slots of 4 bytes each (256 bytes total), and each slot holds **one 32-bit 16.16 fixed-point number** — a string cannot be stored directly. The name is therefore stored as **three indices into the game's own alphabet string** (0–35 for A–Z and 0–9) rather than raw character codes: one byte each, immune to glyph and case handling, and trivially validated on load. Bit-shift packing is not used — `<<16` overflows the 16.16 range.

*This is one of the reasons the cart targets 0.2.7: releases before it had a bug where `dset()` was not flushed when data changed more than once in the last second, which can silently drop these writes.*

**Name entry.** Three characters, button-driven: up/down cycles the current character through the alphabet, left/right moves the cursor, ❎ confirms. `btnp()` auto-repeat timing is tuned via `0x5f5c` (delay) and `0x5f5d` (interval). Three characters matches the length of every AI-assigned nickname (DUM / SKR / WHR / PLR). Keyboard input (`stat(30)`/`stat(31)`) is not used: it requires devkit mode, displays a warning banner to BBS players, and does not exist on handheld or mobile targets.

**Pre-match choice screen.** Bargaining's choice system is the only component in the game that takes structured player input during a match setup, and the largest single piece of act-specific code. It renders two labelled options on opposite halves of the playfield, tracks which is highlighted from the player's paddle position, and commits on button press. It runs inside `level` as a gate ahead of the match rather than as a top-level state, so the dialogue window and palette stay live behind it. Each confirmation fires a game event that advances the narrative engine to the next choice Section.

**Score display.** Two digits per side drawn in the upper playfield, mirroring the original's placement either side of the net. Scores are owned by the `pong` instance and persist through `attract`, where they show the previous match's result.

### The Pong Engine

#### Ball motion and the velocity model

Vertical and horizontal velocity come from two completely independent sources, exactly as in the original hardware. This is what produces the machine's characteristic 42 distinct velocity vectors:

**7 vertical states × 3 horizontal speed tiers × 2 horizontal directions = 42**

**Horizontal speed** is set by a rally hit counter with three discrete tiers. There is no continuous acceleration.

| Rally hit count | Tier | Speed |
|---|---|---|
| < 4 | 1 | 0.341 px/frame |
| 4–11 | 2 | 0.683 px/frame |
| ≥ 12 | 3 | 1.024 px/frame |

The counter saturates at 12 and resets to tier 1 whenever a point is scored or a new match begins. A full cross-court traverse takes **4.3 s / 2.1 s / 1.4 s** at the three tiers.

**Vertical speed** is set solely by which of the paddle's eight zones the ball strikes. The paddle is 6 px tall, subdivided into 8 zones, which map to 7 distinct return velocities:

| Zone (top first) | Vertical velocity |
|---|---|
| 1 | 1.171 px/frame up |
| 2 | 0.780 up |
| 3 | 0.390 up |
| **4** | **0 — horizontal** |
| **5** | **0 — horizontal** |
| 6 | 0.390 down |
| 7 | 0.780 down |
| 8 | 1.171 down |

Note that **two adjacent center zones both return the ball horizontally** — the flat-return band is a quarter of the paddle face, the widest single feature on it, not a thin sweet spot.

The eight zones are equal, dividing the 6 px paddle into bands of **0.75 px** each — narrower than the ball itself. Zone selection therefore uses the **fractional** contact offset between the ball's center and the paddle's top edge, never a rounded pixel coordinate. This is the place where fixed-point positioning is most load-bearing: rounding here would collapse eight zones into six and destroy the flat center band.

Because the two axes are independent, **the same paddle zone returns a different angle at different rally speeds**, and higher rally speeds produce *shallower* angles:

| Zone offset | Tier 1 | Tier 2 | Tier 3 |
|---|---|---|---|
| Center | 0° | 0° | 0° |
| ±1 | 48.8° | 29.7° | 20.9° |
| ±2 | 66.4° | 48.8° | 37.3° |
| ±3 (edges) | 73.7° | 59.7° | 48.8° |

Implemented as a flat lookup — 7 vertical values × 3 horizontal values. No trigonometry, no per-hit angle math.

**There is no spin.** The original paddle is an analog potentiometer with no velocity signal anywhere in the circuit, so direction of travel at contact cannot and does not affect the return. Return angle is determined entirely by zone and tier.

#### Serve

| Rule | Behavior |
|---|---|
| Delay | ~1.7 s between the point being scored and the ball reappearing |
| Position | Just right of the net — **x = 66**, two pixels clear of it |
| Direction | Horizontal direction is unchanged by a miss, so **the ball is served toward whoever missed it** |
| Vertical velocity | Whatever it was at the moment of the miss |
| Vertical position | The ball continues to travel and bounce vertically, invisibly, throughout the serve delay — so its height on reappearance is effectively arbitrary. This is why the original's serve feels random, and it is reproduced deliberately |
| First serve of a match | Always maximum vertical speed (±1.171 px/frame), the steepest angle the model can produce, at horizontal tier 1 |

#### Collision

| Component | Behavior | Key functions |
|---|---|---|
| Walls | Top/bottom playfield bounds and both paddles share one collidable shape. In `attract` two side walls are added so the ball bounces off all four edges; in `level` they are removed and the sides become scoring exits | `walls[]` — `x, y, width, height` |
| Model | A single model throughout all five acts: line-segment intersection between the ball's per-frame movement vector and each wall's near edge, expanded by ball radius. Resolves corners as reliably as flat edges. Chosen because it most closely matches the original hardware's rectangle-region approach, and because it is inherently tunneling-proof at sub-pixel speeds | `ball_intercept()`, `intercept()` |
| Multi-ball | The engine operates on a collection of balls, not a single instance, so Anger's three tests are configuration rather than new code. Each ball carries its own position, velocity, tier counter and behavior mode | `balls[]` |

Inner-loop discipline for the swarm: cache globals and table fields into locals, use numeric `for` rather than `foreach`, reject with a cheap AABB test before the exact segment test, and never call `sqrt()` — compare squared distances.

#### AI

| Component | Behavior | Key variables |
|---|---|---|
| Difficulty tiers | Discrete tiers, each pairing a reaction delay with an aiming error | `ai_levels[]`, `ai_reaction`, `ai_error` |
| Tier selection | `self_balancing` mode indexes the tier by score differential, so COM weakens as he pulls ahead and sharpens as he falls behind. `fixed` mode holds one tier for the whole match | `ai_mode`, `ai_tier` |
| Targeting | Predicts the ball's future intercept point rather than tracking it live; re-predicts only on direction change or after enough reaction time has elapsed; jitters the aim by the current tier's error, scaled by how close the ball is | `predict()`, `predict_wall` |

Acceptance is the only act that uses `fixed` mode. See Game Design → [How COM plays](#how-com-plays--fairness-as-a-story-mechanic).

#### Visual treatment

| Element | Implementation |
|---|---|
| Per-act palette | **Two** 16-byte tables per act — the base display palette at `0x5f10` and the scanline palette at `0x5f60` — each written with a single multi-value `poke()`. Because they target the *display* palette they recolor the entire frame including already-drawn pixels, at zero per-object cost. Elements draw in **role indices** — `0` background, `1` paddle/net, `2` ball, `3` score/nickname/dialogue text — which the tables map onto each act's real colors. A display-palette swap remaps *stored pixel values*, so anything needing its own color needs its own index; paddles, net and ball sharing one color would be indistinguishable to the remap. Both tables must be swapped together on act load |
| Palette contrast rule | A scanline-palette entry must remain distinguishable from the **darkened background**, not merely be lower in luminance. PICO-8 has only two greens, so Bargaining's bright-green score has no darker sibling that isn't its own background — darkening it to `3` made the score vanish on alternate lines. Where no darker color survives the test, shift hue or leave the entry undarkened |
| CRT scanlines | Per-line palette hardware: `poke(0x5f5f, 0x10)`, scanline palette at `0x5f60`–`0x5f6f`, per-line selection bitfield at `0x5f70`–`0x5f7f`. **Scoped to the score and the terminal band — never the game area.** Two mechanisms enforce this together: the bitfield enables only the score's rows and rows 96–127, and the scanline palette is *identity* for background, paddles and ball, so no enabled row can tint them whatever else changes. Density 1/8, with a slow phase crawl and an infrequent (7–17 s) horizontal tear that sweeps in roughly half a second. **Rationale:** a faithful scanline is impossible at this resolution — the original's 246 scanlines map onto 96 rows, so a real scanline pair is finer than one pixel we can draw, and anything we render is ~2.5× too coarse. An earlier full-screen version at 50% coverage, animated, caused eye strain and posed a photosensitivity risk. Paddles, net and ball are plain solid color. Two caveats: `0x5f60`–`0x5f6f` is shared with `fillp`'s secondary palette, so the two cannot both be used; and **these addresses are undocumented in the PICO-8 manual** (confirmed absent in 0.2.7), so behavior should be re-verified against any future release |
| Score digits | `\^w\^t` — wide + tall, 8 × 12 px, solid. **Not** `\^p` (pinball), which adds stripey mode and renders the digits dotted; the original machine's score is solid block numerals |
| Phosphor glow | Three-state per-act axis `phosphor_mode` — `off` / `ball` / `full` — not a boolean, because the two techniques turned out to be different design choices rather than two implementations of one idea. **`full`** blends the whole previous frame, stashed in the (otherwise unused) spritesheet and redrawn beneath the new frame through a dim mapping where every colour funnels `paddle`/`ball`/`score` → `trail1` → `trail2` → background, so nothing can leave a permanent smear. Everything that moves glows, including score digits and dialogue text. **Measured at 29% of frame** with one ball and static dialogue, against the ~27% predicted below. **`ball`** trails only the ball, from a three-slot position history sampled every 3 frames, and costs **4%**. Enabled in Denial, Bargaining, Depression and Acceptance; `off` in Anger, where the frame goes to the swarm instead |
| Trail separation rule | A trail dot is drawn only when total displacement over the sample window is **≥ 2 px**. Below that it cannot separate from a 2 × 2 ball and reads as a *fatter ball* rather than a trail — which is also physically correct, since a slow spot on a CRT overlaps its own afterglow and brightens rather than smears. The effect is therefore absent on slow flat rallies and lengthens with speed |
| Palette reset hazard | `pal()` with no arguments resets **all three** palettes — draw, display *and* secondary — wiping both the act's display palette at `0x5f10` and the scanline palette at `0x5f60`. Restore individual draw entries explicitly instead. The symptom is an act rendering in raw role indices: green-on-black |
| Nickname UI | Text in the upper screen corners from Anger onward, populated by the narrative system |

#### Audio

Reproducing the original's three sounds, all of which were taps off the vertical ball-position counter rather than a dedicated oscillator:

| Sound | Trigger | Frequency | Duration |
|---|---|---|---|
| Hit | Ball contacts a paddle | ~492 Hz | ~16 ms |
| Bounce | Ball contacts the top or bottom bound | ~246 Hz | ~16 ms |
| Score | Ball passes a paddle and exits the field | ~246 Hz | ~240 ms |

All three are muted in `attract`. The narrative engine adds a short cue per printed character or line.

### The Narrative / Dialogue Engine

**Data model:**

| Object | Scope |
|---|---|
| `stage` | One per act, plus the pre-Denial Intro — six in total. The Intro is owned by Denial's `level`, which loads it first and swaps to Denial's own `stage` when the Intro's close trigger fires and the score resets |
| `section` | One open/close cycle of the CLI window |
| `line` | One rendered line of output |

Each act's `stage` plugs in its own state machine (`init`/`change_state`/`update`/`states`) rather than forking a base class, so per-act behavior — Denial's score-checkpoint branching against Anger's linear gated sequence — is authored independently against a shared framework.

**Trigger types**, per the Dialogue Trigger Catalog:

| Trigger type | Behavior | Example |
|---|---|---|
| Timed | Auto-advances after a duration (Short / Med / Long) | Default line-advance |
| Game event | Advances or opens in response to gameplay state | Score checkpoint reached; act transition |

**Textbox behavior:**

| Property | Definition |
|---|---|
| Position | Occupies the 32-px terminal band at rows 96–127, beneath the playfield |
| States | `closed → opening → open → closing` |
| Motion | Slides up from the bottom edge into the band on open, back down on close |
| Text reveal | Letter-by-letter typewriter effect, blinking cursor, rolling terminal scrollback |
| Callback | Notifies the owning `level` when each animation completes, so the next Section can load |
| Audio | Short cue per printed character or line |

Because the band sits below the playfield rather than over it, no transparency is required and gameplay is never occluded.

### Resource budget

| Resource | Ceiling | Notes |
|---|---|---|
| Code tokens | **8,192** | A whole string counts as **1 token**, so dialogue is nearly free here |
| Characters | **65,535** | **This is the real constraint on dialogue volume** — every line of COM's script spends against it directly |
| Compressed code | 15,360 bytes | Only enforced for `.p8.png` / `.p8.rom` export |
| Sprites | 256 | |
| SFX / music | 64 / 64 | |
| CPU | **139,810 cycles per frame** at 60 fps | Half the 30 fps budget |

The two budgets that actually bind are **characters** (dialogue) and **CPU during Anger's swarm**. Estimated worst-case frame:

| Load | Cycles | % of frame |
|---|---|---|
| `cls()` | 2,052 | 1.5% |
| 40 balls, swept collision | ~20,000 | ~14% |
| Drawing 40 balls | ~1,500 | ~1% |
| Scanlines | ~0 | ~0% |
| Phosphor *(disabled in Anger)* | ~33,000 | ~24% est. / **29% measured** (`full` mode; `ball` mode measures 4%) |

Anger therefore runs at roughly **17%** of frame before dialogue, AI and paddle costs. The four acts that do run phosphor carry it against a single ball rather than forty, landing near **27%**. Both figures are estimates derived from published per-operation cycle costs rather than measurements, and the cycle-per-frame convention used here (2²³ cycles/second ÷ 60) is the community reading of the manual's "8 MHz virtual CPU," not a figure the manual states directly.
