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

Split into four sub-milestones. M10 as originally written bundled four separable
concerns, and had three further items deferred into it (the state collapse from M8, the
win/checkpoint path from M8/M9, the phosphor decision from M7b) plus audio folded in.
Order is `a → b → c → d`: state is foundational, audio is a prerequisite of the
typewriter cue, and the engine needs a window to drive.

### M10a — State collapse and match resolution

- Collapse `game_manager`'s six states (`title`/`menu`/`options`/`level`/`gameover`/
  `intermission`) to **`attract`** and **`level`**.
- Act on `pong.winner`:
  - **Win** — write the checkpoint, advance `level_index`, load the next act directly.
  - **Loss** — return to **attract**, keeping `level_index` so the same act resumes when
    the player comes back. Attract reverts to Denial's black-and-white palette.
  - **Act 5 won** — checkpoint 5, back to attract, `level_index` reset to Denial.
- **Closes M9's open gap** — the persistence layer has no caller until this lands.

**Acceptance:** winning an act advances and persists; losing replays the same act;
quitting and relaunching resumes at the right act *through play* rather than by writing
a checkpoint by hand.

### M10b — Audio

- The three hardware sounds, all taps off the vertical ball-position counter in the
  original: hit ~492 Hz / ~16 ms, bounce ~246 Hz / ~16 ms, score ~246 Hz / ~240 ms.
- Muted in `attract`.

**Asset boundary — audio is a human-created asset.** The three sounds above are derived
from documented reference-material specifications (frequency and duration), so
reproducing them is transcription, not authorship. **Anything else is placeholder only.**
The per-character typewriter cue is a new creative asset and must not be authored here:
reuse one of the three game sounds as an explicit placeholder, flagged for replacement.

**Acceptance:** all three fire at the right moments and are silent in attract.

### M10c — The terminal window

- Textbox occupies the 32px band at rows 96–127.
- **No slide/open/close animation.** The window is permanently open — a single scrolling
  scrollback view where lines are removed as they scroll off the top. The
  `closed → opening → open → closing` state machine in the Tech Design is **dropped**;
  building a slide only to remove it later is wasted effort, and the CLI is getting
  further design attention.
- Letter-by-letter reveal, blinking cursor.
- Per-character or per-line audio cue (placeholder per M10b).
- **No player advance or skip input.** Dialogue is fully automatic.

**Unblocks** the M7b `phosphor_mode` `full` vs `ball` decision, which needs animated text
to judge.

**Acceptance:** text never draws above row 96 and never occludes the playfield; no button
does anything to the window; lines scroll off cleanly.

### M10d — The narrative engine

- Rename `dialogue`/`section`/`phrase` → `stage`/`section`/`line` (#33).
- Timed (Short/Med/Long) and Game-event triggers.
- Win/lose branching (#27) — the existing system is single-path.
- A Section can be interrupted mid-print by a game event and switch content
  (Denial's checkpoint-interrupts-non-sequitur behavior).
- Completion callback to the owning `level` so the next Section can load.
- Per-act `stage` state machines plug into a shared framework rather than subclassing.

**Act dialogue content is not in scope** — it is author-written and lands in M12–M16.
Denial's existing lines serve as the test harness.

**Acceptance:** Denial's existing content plays through the new engine; timers are
frame-counted at 60fps, not `time()`-based; a game event can interrupt a Section
mid-print.

**Open:** Short/Med/Long have no second values anywhere in the docs. M10d needs starting
numbers and a tuning round, against the ~20 minute playthrough target.

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

## M11b — The CLI as story element — #24

**Spec:** `handoffs/docs-pass.md` items 14–24 (the design session's output; not yet in the
design docs, which are frozen).

The terminal stops being a plain dialogue window and becomes the host machine's console,
with the Pong cart as a program running on it. Two voices share the band — `console`
(`>` prefix, green at attract, act-colored inside a stage) and `com` (unprefixed). Cold
boot types itself in; a stage ending hands the machine back to the console.

**Acceptance**

- Cold boot shows an empty playfield until `> run` finishes, then attract appears.
- Console text is green at attract and the act's text color when a stage is live.
- The band clears once per loop, at stage end — never between Sections.
- Console text fades under phosphor rather than burning in.
- Reveal rate is a per-act axis; every act still uses the default, by design.

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
| M10a | **Game Design change:** a loss no longer resets and immediately replays the act. It returns the player to **attract**, with the palette reverting to Denial's black and white — COM has gone quiet and is waiting for you to come back. Pressing start resumes the same act (fresh dialogue, same stage). Tech Design's *Resolving a level result* table says "Reset current level, replay same act", which describes the destination but not the trip through attract |
| M10c | **Tech Design change:** the textbox `closed → opening → open → closing` state machine and its slide motion are **dropped**. The window is permanently open, a single scrolling scrollback view where lines are removed as they scroll off the top. Building the slide only to remove it later is wasted effort, and the CLI is getting further design attention |
| M10b | **Tech Design / process addition:** record the audio asset boundary — audio is a human-created asset. The three hardware sounds are transcribed from documented reference-material specs and are in bounds; anything else, including the typewriter cue, is placeholder-only pending a human-authored replacement |
| M11 | **Game Design change — phosphor is now `full` in every act, including Anger.** Measured 40% of frame with `full` plus the 40-ball swarm, and ~24% in normal play, which the design accepts. This removes a narrative beat that Game Design currently states explicitly: *"Phosphor glow disabled — the frame budget goes to the swarm instead. By this point COM has already abandoned any pretense that this is a faithful 1972 machine, so the loss of the period glow reads as intentional."* That rationale needs rewriting, and if the "machine stops pretending" signal is still wanted in Anger it needs another carrier. Raised before the change was made; the decision was taken with the tradeoff stated |
| M11 | **Measured CPU, replacing estimates.** `full` phosphor + 40 balls at tier 3 = **40%**; normal single-ball play with `full` = **~24%**. Tech Design's budget table carries estimates of ~24% for phosphor and ~17% for the swarm; both should be replaced with measurements at the docs pass |
| M11a | **Game Design change — the ball is 1.4× the hardware speed.** A global `ball_scale = 1.4` multiplies both `BALL_SPEEDS` and `BALL_VZONES`, so the 42-vector model and every return angle carry over exactly; only the clock changes. Effective tiers are **0.477 / 0.956 / 1.434 px/frame**, cross-court **3.07 s / 1.53 s / 1.02 s** against the derived 4.3 / 2.1 / 1.4. This contradicts CLAUDE.md's *"Numbers you must not get wrong"* table and the cross-court timings quoted in Tech Design; both need the divergence recorded rather than the numbers quietly overwritten, since the 1972 values remain the derivation and 1.4 is a playability multiplier on top. Decision was playtested, not derived |
| M11a | **Paddle response retuned, superseding the M8 row above.** Player paddle is now `paddle_accel = 0.3`, `paddle_max_speed = 3` (was 0.4 / 4.5). The governing ratios, worth writing into Tech Design because they explain *why*: **R** = paddle max ÷ ball's steepest vertical (1.171 × scale) = **1.82**, and **T** = paddle max ÷ accel = **10 frames** to full speed. Overshoot is governed by T, not R — `move_paddle` has no momentum, so the smallest possible correction is bounded by ramp length. At 0.3 a 4-frame tap moves 3.0 px (half a paddle) versus 7.8 px at 0.8, which is what made deliberate zone aiming possible. Floors: R ≥ 1.0 or a steepest ball is vertically unreachable; paddle must cross 90 px inside a tier-3 flight (61 f) — it does, in 35 f, a 1.75× margin. COM remains 0.08 / 2.5 and still has never been tuned independently |
| M11a | **Paddle speed is coupled to ball speed** — `paddle_accel` and `paddle_max_speed` scale linearly with `ball_scale`, calibrated at `BALL_CAL = 1.4`, holding R and T invariant at any ball speed. This is a *tuning* device: it keys off `ball_scale`, **not** off the rally tier, and is inert (`pd_k() == 1`) at the default. Deliberately not tier-reactive — tier changes only horizontal speed, so the ball's vertical speed and therefore the paddle's tracking requirement are identical at every tier; coupling to tier would cancel the difficulty ramp. **Gotcha for whoever folds 1.4 into `BALL_SPEEDS`:** `BALL_CAL` must become 1 at the same time or the paddle silently drops to 2.14 / 0.21 |
| M11a | **`phosphor_mode` is now a boolean, resolving the M7b row above.** The `ball` (discrete 2-dot trail) mode and its per-ball trail state are deleted; `full` is the only mode. Tech Design's three-state `off`/`ball`/`full` axis becomes `on`/`off` |
| M11a | **Phosphor requires `palt(0, false)`.** The full-frame blit is `sspr`, and colour 0 is transparent to sprite drawing by default, so every background pixel of the blit was a no-op and the screen was never actually cleared — PICO-8's boot console text persisted under the playfield indefinitely. Set once at init, alongside `memset(0x0000, 0, 0x2000)` to stop the `__gfx__` data flashing on frame 0. Belongs in Tech Design's *Visual treatment* table next to the `pal()` reset hazard, as the same class of trap. Note `cls()` is **not** the fix: it costs 2,052 cycles/frame to clear pixels the blit then overwrites anyway |
| M11a | **Nickname UI implemented (#31), with one open design question.** Small text, rows 1–5 (above `miny = 6`, so no paddle can reach it), x = 8 and x = 108, exact mirror about the net, inside the scanline band. Game Design says *"text in the upper screen corners"* (plural) and *"COM's own displayed name never changes"*, which was read as **both** labels present — `COM` left, nickname right. That reading is an inference and Game Design should state it outright either way. Denial correctly shows neither, preserving the reveal |
| M11a | **The completion badge replaces every AI-assigned nickname retroactively.** Once `completion_name` exists, it is shown in place of DUM/SKR/WHR/PLR on replays of every act. Game Design's Resolution section says the custom name replaces the AI-assigned ones but is ambiguous about whether that applies only to Acceptance's own PLR or to all acts on subsequent runs; the cart now does the latter. Badge label is `HIGHSCORE`, no colon |
| M11a | **Narrative convention: `win_section` means the *player* wins.** Denial's two branches were wired to the opposite triggers — COM's boast played when the player won and COM's "thats not possible" when the player lost. The authored lines were correct; only the wiring was inverted. Tech Design should state the convention explicitly, since `stage:resolve(w)` takes the raw winner id (`2` = player) and the naming is the only thing carrying the meaning |
| M11a | **Debug scaffolding added, extends the M7a/M7b strip-list.** `DEBUG_KEYS` (`c` = player win, `v` = player loss, `[` / `]` step `ball_scale`) and `DEBUG_AI` (COM plays from the first serve, bypassing Denial's 2-point arming and its score reset). Both are single-flag kills. **Both stay `true` through Alpha by decision** — they are worth more for playtesting than the risk they carry, and `DEBUG_AI` in particular is what makes Denial playable before M12 builds its real arming logic |
| M11a | **⚠ File a GitHub issue at the docs pass to track debug-flag removal.** `DEBUG_KEYS` calls `poke(0x5f2d, 1)`, enabling devkit keyboard — this shows a warning banner to BBS players and does not exist on handheld or mobile targets, which CLAUDE.md's PICO-8 rules otherwise forbid outright. Deliberately left on for now (see row above), so it needs a tracked issue rather than a comment, or it ships by default. The issue should cover `DEBUG_KEYS`, `DEBUG_AI`, `DEBUG_ACT`, the pause-menu act selector, the `cpu` / paddle-tuning menu items and `draw_debug()` as one sweep, and should state the ship-blocking one explicitly: **`poke(0x5f2d, 1)` must be gone from a release build** |
| M9 | **Parking Lot addition:** surface the "press any button to start" prompt through the CLI terminal band rather than as text over the playfield. Attract is meant to look like an unattended machine, so nothing should overlay the field — but the affordance still needs to exist somewhere, and the terminal is where the machine already speaks |
| M9 | Attract currently rides on the legacy `menu` state. M10's state collapse should make it a real `attract` state. Note that `game_manager:input` contained an always-true condition (`state == menu or states.intermission` — the second operand was a bare constant, not a comparison), which meant *any* start press reloaded the level from *any* state. Dormant while only ❎ triggered it; M9's any-button rule exposed it |
| M8 | `win_score` / `sudden_death` are plumbed and set `pong.winner`, but nothing acts on it — win/lose transitions live in `game_manager`'s states, deferred to M10 |
| M8 | `ball_mode`'s `slow_fast` and `homing` are minimal working implementations so the axis is real rather than a stub. Depression (M15) owns tuning them |

---

## Known bugs

| Area | Issue |
|---|---|
| Collision | ~~The ball passes through paddle corners.~~ **Fixed in M8** (`031ac98`) — and it was two separate defects. (1) *Detected but misresolved:* a `top`/`bottom` face contact flipped `dy` only and left `dx` unchanged, so the tier block restated `dx` with the unflipped sign and the ball carried through. Paddle contacts now always reverse horizontally, which is what the hardware does — it detects coincidence with a rectangular region rather than having faces at all. (2) *Never detected:* the bottom face was **inset** by the ball radius where the top face is **expanded**, leaving a 1 px notch at each bottom corner. Predates the rework. Verified by exhaustive sweep over all 42 velocity vectors, entries from outside the paddle rect only: 0 tunnelling gaps |

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
