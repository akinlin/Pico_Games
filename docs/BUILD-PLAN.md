# Meta Pong — Build Plan

Goal: bring `pong.p8` up to everything currently specified in the wiki. This is a
**rework of the existing cart**, not a greenfield build — the `game_manager`/`level`/
`pong`/`dialogue`/`textbox` skeleton and the `ball_intercept()`/`intercept()`/
`predict()` math survive; the physics, geometry and presentation layers do not.

Order is **engine first**. Get the playfield, velocity model, serve, collision, AI and
visual system correct and verifiable, then the narrative engine, then the five acts as
configuration. This order exists because the per-act Customization config is the load-
bearing abstraction in the whole design — building acts before it is solid means
discovering its shape under pressure.

**Status lives here and in GitHub issues, never in the wiki.**

---

## How to run a milestone

1. Branch: `git checkout -b m<N>-<slug>`.
2. Read the milestone's *Spec* links in `docs/tech-design.md` and `docs/game-design.md`
   before writing code.
3. Implement. Keep `printh()` debug output behind a flag.
4. Hand the user a **verify block** — the acceptance criteria below, phrased as things
   to look at on screen.
5. User launches `pico8 pong.p8`, reports back. Iterate.
6. Strip debug scaffolding. Commit. Close/update the issue.

Milestones marked **⚠ no issue** have no GitHub issue covering them — file one before
starting, or fold them into the nearest existing issue.

---

## M0 — Cart upgrade and 60fps migration ⚠ no issue

The smallest change that unblocks everything else.

**Scope**

- Re-save the cart under PICO-8 0.2.7 so the header reads `version 43`.
- Switch `_update()` → `_update60()`.
- Delete the `dt = time() - timelast` machinery entirely. Velocities become per-frame
  quantities, applied once per frame with no scaling.
- Delete `MAX_ACCEL`, `MAX_SPEED`, and `pong.accelerate()`'s acceleration branches —
  position integration only. **Ball acceleration only.** The *player paddle* still
  accelerates while held, easing from rest toward a max speed (`paddle_accel` /
  `paddle_max_speed` become config axes in M8). Do not remove that behavior.

**Acceptance**

- Cart loads and plays at 60fps; the ball no longer changes speed as the rally goes on.
- Ball speed is now wrong (too slow or too fast) — expected, M2 fixes it. What must be
  true is that it is *constant*.
- No console errors.

**Why first:** every velocity number in the spec is per-60Hz-frame. Doing anything else
before this means tuning against a moving target.

---

## M1 — Playfield geometry and the terminal band ⚠ no issue

**Spec:** Tech Design → *Playfield & geometry*

**Scope**

- Playfield becomes rows 0–95. Terminal band is rows 96–127, permanently reserved.
- Net to x = 64, 1 px wide, 2 on / 2 off.
- COM paddle to x = 20, player paddle to x = 108. Paddle 1 × 6 px.
- Paddle travel: top-edge `y` clamped to 6–84.
- Ball 2 × 2 (radius 1).
- Score digits move into the upper playfield, either side of the net.
- Move the textbox from its floating `y=120` position into the band.

**Acceptance**

- Nothing gameplay-related is ever drawn below row 95.
- Paddles stop 6 px short of the top and bottom of the playfield, symmetrically.
- Net is visually centered between the two paddles (44 px either side).
- Both scores are readable and don't collide with the net.

---

## M2 — Fixed-point ball and the three-tier speed model — #17 (epic), ⚠ needs its own issue

**Spec:** Tech Design → *Ball motion and the velocity model*

**Scope**

- Ball `x`/`y` stored fractional; round only in the draw call.
- Rally hit counter with tiers at <4 / 4–11 / ≥12 → 0.341 / 0.683 / 1.024 px/frame.
- Counter saturates at 12; resets to tier 1 on any point scored or new match.

**Acceptance**

- Ball visibly moves less than a pixel per frame at tier 1 — it should look like it
  advances every third frame or so, not smoothly.
- Traverse times **paddle to paddle** (88 px, not the full 128 px screen):
  **~4.3 s / ~2.1 s / ~1.4 s**. Time them. Wall-to-wall gives ~6.3 s at tier 1 and
  would look like a failure on correct code.
- The speed change is a visible step at the 4th and 12th volley, not a ramp.
- Speed resets to slow after every point.

---

## M3 — The 8-zone paddle return table — #30 *(issue body is stale, see CLAUDE.md)*

**Spec:** Tech Design → *Ball motion and the velocity model*; CLAUDE.md → *42 vectors*

**Scope**

- Delete `apply_spin()` and every call site.
- 8 equal 0.75 px zones per paddle, selected from the **fractional** contact offset
  between ball center and paddle top edge.
- Flat lookup of 7 vertical velocities: ±1.171 / ±0.780 / ±0.390 / 0 / 0.
- Vertical and horizontal velocity stay fully independent — no trig, no per-hit math.

**Acceptance**

- Hitting the middle of the paddle returns the ball **dead horizontal**, and the flat
  band is noticeably wide — about a quarter of the paddle face, not a pixel.
- **Seven** distinguishable outcomes across eight zones — zones 4 and 5 both return
  horizontally and are indistinguishable by design. Test by hitting the paddle at its
  very top, then stepping down. If you can tell zone 4 from zone 5, that's a bug.
- The same contact point returns a **shallower** angle during a fast rally than a slow
  one. This is the easiest thing to get backwards.
- Moving the paddle at the moment of contact changes nothing about the return.

---

## M4 — Serve rules ⚠ no issue

**Spec:** Tech Design → *Serve*

**Scope**

- ~1.7 s delay after a point before the ball reappears at x = 66.
- Horizontal direction unchanged by a miss — served toward whoever missed.
- Vertical velocity carried over from the moment of the miss.
- Ball continues travelling and bouncing **invisibly** through the delay.
- First serve of a match: max vertical (±1.171) at tier 1.

**Acceptance**

- After scoring, there is a real pause, then the ball appears at a height that feels
  unpredictable. **This is correct.** If it always appears at the same height, the
  invisible travel isn't running.
- The ball always goes *toward* whoever just missed — the scorer never gets the serve.
  (Bargaining's `com_serves_every_point` is the sole later exception; it does not exist
  yet at this milestone.)
- Match's first serve is visibly the steepest angle in the game.

---

## M5 — Collision rework and the ball collection ⚠ no issue

**Spec:** Tech Design → *Collision*

**Scope**

- Keep `ball_intercept()`/`intercept()`; adapt to the fixed-point per-frame vector and
  the new geometry. Remove the ±140/−50 coordinate clamps if the new scale makes them
  unnecessary — verify first.
- Convert the single `ball` global to `balls[]`; each ball carries its own position,
  velocity, tier counter and behavior mode.
- Add the AABB pre-reject and the numeric-`for` inner loop discipline now, while
  there's one ball, so the swarm doesn't need a second pass.

**Acceptance**

- Single-ball play is unchanged from M4.
- The ball never passes through a paddle or wall, including at tier 3 and including
  corner hits.
- Dropping two balls into `balls[]` by hand plays both correctly.

---

## M6 — AI rework — #17 (epic), ⚠ needs its own issue

**Spec:** Tech Design → *AI*; Game Design → *How COM plays*

**Scope**

- `ai_levels[]` as discrete tiers, each pairing reaction delay with aiming error.
- `ai_mode`: `self_balancing` (tier indexed by score differential) or `fixed`.
- `ai_enabled` flag — Denial's opening needs COM's paddle genuinely unmanned.
- Retain `predict()`'s re-predict-on-direction-change logic and closeness-scaled jitter;
  adapt to per-frame velocities.

**Acceptance**

- With `ai_enabled = false`, COM's paddle does not move at all.
- In `self_balancing`, COM visibly gets worse when ahead and sharper when behind.
- In `fixed`, COM plays the same at 0–0 and 9–10.
- COM misses in a way that reads as human error, not as a stutter or teleport.

---

## M7 — Visual system: palettes, scanlines, phosphor — #29, #32 *(both stale)*

**Spec:** Tech Design → *Visual treatment*

**Scope**

- Two precomputed 16-byte palette tables per act (base + darkened scanline), applied
  together via `memcpy(0x5f10,…)` and `memcpy(0x5f60,…)` on act load.
- Scanlines on permanently: `poke(0x5f5f, 0x10)` + the `0x5f70`–`0x5f7f` bitfield, set
  once at boot.
- Phosphor as a toggleable per-act axis. Split into M7a (palettes, scanlines) and M7b (phosphor) because neither is verifiable headlessly and a single "the visuals look wrong" report would not say which half broke.
- Act palettes per Game Design. **Denial takes no override. Depression's ball is white
  (`7`), not purple** — #29's body is wrong on that.

**Acceptance**

- Scanlines visible in every act, including `attract`.
- Forcing each act's palette by hand recolors the whole frame in one go — including
  the scanlines, which must match the act rather than staying the previous act's color.
- Phosphor visibly trails the ball when on, and turning it off changes nothing else. `full` mode's effect on animated dialogue text cannot be judged until M10 gives the text a letter-by-letter reveal; both modes ship and the choice is deferred.
- `fillp` is not used anywhere (it collides with the scanline palette).

---

## M8 — Per-act Customization config — #25, #26

**Spec:** Tech Design → *Architecture* → Per-act configuration

This is the milestone the whole plan is built around. Everything above becomes a knob.

**Scope**

- Define the config table with every axis in the Tech Design table: `paddle_height`,
  `paddle_max_speed`, `paddle_accel`, `ball_count`, `ball_mode`, `ball_mode_pool`,
  `speed_tier_pin`, `win_score_player`, `win_score_com`, `sudden_death`,
  `scoring_model`, `score_multiplier_com`, `initial_score_com`, `scoring_enabled`,
  `com_serves_every_point`, `ai_enabled`, `ai_mode`, `ai_tier`, `palette`, `nickname`,
  `phosphor_mode` (`off`/`ball`/`full`).
- Apply on `level` load. **One engine, parameterized — never fork it.**
- ~~Collapse `game_manager`'s six states to `attract` and `level`.~~ **Deferred to M10** —
  the collapse touches the dialogue state machine that M10 rebuilds, so doing it here
  means reworking the same code twice.
- Player paddle control: buttons with acceleration/momentum, **and fractional position**.
  Curve and max speed are playtest values — start somewhere sane and expect to tune.

  **Why fractional matters more than the curve.** At a flat 2 px/frame the paddle reaches
  only 59 of its 79 positions, and *which* 20 are missing depends on which clamp it last
  touched — moving down from the start lands on odd positions, hitting the bottom clamp
  (84, even) flips it to evens permanently. The reachable set is stateful, so it can't be
  learned. Worse, 2 px quantization against 0.75 px zones means a player can reach only
  about **3 of the 8 return zones** for a given incoming ball, which makes most of M3's
  angle model unreachable in play. Fractional position is the fix; acceleration is what
  makes it usable. There is also a 1-frame overshoot past `PADDLE_MAX_Y` to y=85, because
  `handle_game_input` clamps *before* moving rather than after.

**Acceptance**

- Every axis above can be changed in one place and visibly takes effect.
- Setting a config with 40 balls, tier pinned to 3, phosphor off runs without dropping
  frames. Budget target is ~17% of frame before dialogue, AI and paddle costs; the
  single-ball-with-phosphor case should land near 27%.
- No act-specific branching exists in the engine yet.

---

## M9 — Attract mode and persistence — #34 *(stale body)*

**Spec:** Tech Design → *Architecture*; Game Design → *Boot / attract-mode*

**Scope**

- `attract`: two extra side walls in `walls[]`, ball bouncing off all four edges, net
  drawn, previous match's score retained (0–0 cold boot), paddles hidden, sound muted.
- `cartdata("akinlin_metapong_1")`. `furthest_completed_act` in slot 0 as **0–5**.
  `completion_name` as **three alphabet indices** at `0x5e04`. **No bit-shift packing.**
- Resume: `level_index` = one past last completed act. Checkpoint 5 → fresh run at
  Denial, badge stays.
- Completion badge at center-top of `attract` when a name exists.

**Acceptance**

- Cold boot shows 0–0 and a four-wall bounce with no paddles and no sound.
- Quitting mid-game and relaunching resumes at the right act.
- Cold boot: **any** button press starts play.
- Writing a checkpoint twice within one second still persists. Pre-0.2.7 releases had a
  `dset()` flush bug that silently dropped the second write; 0.2.7 fixes it. If this
  fails, the cart is not actually on 0.2.7.
- A saved name survives a full PICO-8 restart.

---

## M10 — Narrative engine rebuild — #24, #25, #27, #28, #33

**Spec:** Tech Design → *The Narrative / Dialogue Engine*; Game Design → *Dialogue
Trigger Catalog*

**Scope**

- Rename `dialogue`/`phrase` → `stage`/`line` (#33).
- Textbox lives in the 32px band; `closed → opening → open → closing`; slides up/down.
- Letter-by-letter reveal, blinking cursor, rolling scrollback (#28's text-fitting POC
  feeds this).
- Timed (Short/Med/Long) and Game-event triggers.
- Win/lose branching (#27) — the existing system is single-path.
- Per-line audio cue.
- Completion callback to the owning `level` so the next Section can load.
- **Scrollback clears on every close/reopen** — a Section never inherits the previous
  Section's lines.
- **No player advance or skip input.** Dialogue is fully automatic.

**Acceptance**

- Text never draws above row 96 and never occludes the playfield.
- No button does anything to the dialogue window.
- Open/close animations complete and fire their callbacks; a new Section opening while
  the window is already open transitions without replaying the open animation.
- A Section can be interrupted mid-print by a game event and switch content in the same
  open window (Denial's checkpoint-interrupts-non-sequitur behavior).
- Timers are frame-counted at 60fps, not `time()`-based.

---

## M11 — Name entry ⚠ no issue

**Spec:** Tech Design → *Name entry*

Three characters; up/down cycles through the alphabet, left/right moves the cursor, ❎
confirms. `btnp()` repeat tuned via `0x5f5c`/`0x5f5d`. Buttons only — no keyboard, no
mouse.

**Acceptance**

- Held up/down cycles at a comfortable rate, neither one-character-per-second nor a
  blur.
- Confirmed name round-trips through persistence and appears on the attract badge.

---

## M12–M16 — The five acts as configuration

Each act is a config plus a `stage` state machine. Build in story order; the Intro is
part of Denial. Dialogue content is **author-written** — leave the slots empty and let
the user fill them.

| M | Act | Issue | The part that isn't just config |
|---|---|---|---|
| M12 | **Intro + Denial** | #31 (nickname UI — Denial has none) | Unmanned paddle for the first 2 points; COM takes the paddle mid-sentence; score reset to 0–0; score-checkpoint Sections at 0/5/10/11 — **checkpoint 0 is a single fixed Section with no variants** (the match is always tied there), 5/10/11 each branch into player-first and COM-first; timed non-sequitur pool that a checkpoint can interrupt mid-print without closing the window |
| M13 | **Anger** | #31 | Nickname **DUM**. Three tests as three configs (1 fastball → 2 offset balls → staggered swarm); `intercept` scoring model (a paddle contact resolves the point); tier pinned to 3; phosphor off; dialogue **gates** ball-firing; score cumulative across all three tests to 11 |
| M14 | **Bargaining** | — ⚠ no issue | Nickname **SKR**. The pre-match choice screen — largest act-specific chunk in the cart. Three fixed pairs: (1) longer player paddle *or* slower COM paddle; (2) COM's points count 3× *or* COM gets a 10-point head start; (3) sudden death *or* `com_serves_every_point`. Runs inside `level` as a gate, not a top-level state, so palette and dialogue stay live behind it. Head start must **not** feed the self-balancing calculation |
| M15 | **Depression** | — ⚠ no issue | Nickname **WHR**. Asymmetric win (player 5 / COM 11); `ball_mode_pool` = `slow_fast` + `homing`, one drawn per serve; on player reaching 5, `scoring_enabled = false` + `ai_enabled = false` while the closing dialogue runs — the rally continues and balls that exit simply re-serve |
| M16 | **Acceptance** | — ⚠ no issue | Nickname **PLR** until the win. `ai_mode = fixed` — the only act that uses it. Minimal dialogue. Win → name entry → badge replaces every AI-assigned nickname |

**Acceptance, per act:** the act loads with the right palette, nickname, win condition
and ball behavior; win advances and writes the checkpoint; loss resets and replays the
same act with fresh dialogue.

---

## Documentation freeze (Alpha)

**`docs/tech-design.md`, `docs/game-design.md`, `docs/reference-materials.md` and the
GitHub wiki are frozen for the remainder of Alpha.** Do not edit them, and do not sync
the wiki. Only `DEVLOG.md` and this file may be updated as work proceeds.

A single documentation pass happens at the end of Alpha and incorporates everything
below. The correct order at that point is **wiki first, then re-sync the mirrors down** —
`docs/*.md` carry a "MIRROR OF THE GITHUB WIKI / do not edit here" header, and editing
the mirror leaves changes that the next sync silently reverts.

As of the freeze, repo mirrors and wiki are consistent through M7b (wiki `2e419bc`), so
this backlog starts empty. **Append to it whenever a milestone settles something the
design docs don't yet reflect** — otherwise the end-of-Alpha pass has to reconstruct it
from commit messages.

| Milestone | Needs writing up |
|---|---|
| M7b | `phosphor_mode` `full` vs `ball` — decision deferred until M10 gives dialogue a letter-by-letter reveal, since full-frame blending's effect on animated text cannot be judged before then. Both modes ship meanwhile |
| M7a/M7b | The pause-menu act selector and `DEBUG_ACT` are dev scaffolding currently living in the cart. Decide whether they ship (the CRT options were cut; the act selector may be worth keeping) or get stripped |
| M8 | **Parking Lot addition:** explore `paddle_accel` / `paddle_max_speed` as expressive per-situation settings rather than fixed per-act values — being able to change paddle response in different situations was noticeably good in playtest. Flagged deliberately as a *later* exploration, not scope creep into Alpha |
| M8 | Playtest-tuned paddle values landed at `paddle_accel = 0.4`, `paddle_max_speed = 4.5` for the **player**. COM stays at 0.08 / 2.5 — the values it was actually playtested against. COM's own paddle response has never been tuned independently and probably wants its own pass, since it interacts with the `ai_levels` difficulty curve |
| M8 | Measured **12%** of frame for 40 balls at tier 3 with phosphor off, against the ~17% budget estimate. The swarm has more headroom than the design assumed |
| M8 | `win_score` / `sudden_death` are plumbed and set `pong.winner`, but nothing acts on it — win/lose transitions live in `game_manager`'s states, deferred to M10 |
| M8 | `ball_mode`'s `slow_fast` and `homing` are minimal working implementations so the axis is real rather than a stub. Depression (M15) owns tuning them |

---

## Known bugs

| Area | Issue |
|---|---|
| Collision | **The ball passes through paddle corners.** `ball_intercept` resolves a `top`/`bottom` face hit by flipping `dy` only, so a ball clipping the paddle's end keeps its horizontal direction and continues through. M5's acceptance passed because corner contacts were rare with a 2 px-quantized paddle; M8's fractional paddle makes them common enough to hit regularly. Affects evaluation of the zone system at the paddle rims |

---

## Open items flagged but not decided

- **Depression contrast — already resolved, noted so it doesn't get reopened.** An
  earlier draft paired the ball with a low-contrast color against Depression's dark
  blue background (`1`), which would have been the worst pairing in the game in the act
  designed to be the easiest. The wiki settles it: **ball white (`7`)**. Issue #29 still
  says purple (`13`). Build from the wiki.
- **Timer calibration.** "Short / Med / Long" have no second values yet. The directional
  target is a ~20 minute clean playthrough, leaning shorter. Needs playtesting.
- **Paddle acceleration curve and max speed** — playtest values, not derived.
- **Anger swarm ball count.** The 40-ball figure in the resource budget is a worst-case
  estimate, not a design decision.
