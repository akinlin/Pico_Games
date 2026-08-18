# Meta Pong — working instructions

Meta Pong is a PICO-8 Pong clone. The player boots into what looks like a faithful
1972 arcade Pong replica and finds the second paddle unmanned. After two points the
machine introduces itself: COM, an AI that has always been in the circuitry. Across
five acts COM moves through the five stages of grief, and the gameplay rules change
with him.

Everything for this game lives in `meta_pong/`: the cart is `meta_pong/meta_pong.p8`,
alongside this file and `DEVLOG.md`. Paths here are written from the **repository root**,
which is the working directory. There is a second unrelated cart,
`possessor/possessor.p8` — do not touch it.

The repository holds several carts. Its layout, the branch-per-cart working model and
the rules for shared code in `libs/` are in the [root README](../README.md) and
[`docs/`](../docs/); there is no `CLAUDE.md` above this one.

---

## Source of truth

**There are no Meta Pong design documents in this repo** — `docs/` is repository-wide and
carries none. Two places hold everything:

- **[The wiki](https://github.com/akinlin/Pico_Games/wiki/Meta-Pong)** — one page, three
  sections: **Game Design**, **Tech Design**, **Reference Materials**. **Authoritative.**
- **[GitHub issues](https://github.com/akinlin/Pico_Games/issues)** — all work and all
  status. Each milestone is an issue; M12–M16 are #60–#64.

This file and `DEVLOG.md` are the only Meta Pong prose in the repo, and neither is a spec.
The wiki mirrors, the build plan and the session handoffs were **deleted at the
end-of-Alpha docs pass, 2026-08-03** — mirrors drifted, and the plan's finished milestones
were history that `DEVLOG.md` already tells better. Read the wiki. It is a git repo if you
need one locally:

```bash
git clone https://github.com/akinlin/Pico_Games.wiki.git
```

Rules that matter:

1. Game Design is upstream of Tech Design. If an implementation detail implies a
   design change, stop and raise it — do not resolve it in code.
2. **The wiki records settled decisions and shipped implementation only.** Build status,
   open questions and not-yet-taken ideas are issues, never wiki content. If something
   can't be settled, that is a reason to ask, not to write "TBD" on the wiki.
3. If code and the wiki disagree, the wiki wins and the code is a bug.
4. If you believe the wiki is wrong, say so and wait. Do not edit it unless asked.

---

## How we work

**You cannot see this code run.** There are no screenshots, and how the game *feels* is
never answerable from here. Every behavioral claim you make is a hypothesis until the user
launches the cart and reports back. Therefore:

- Work in small increments that the user can verify by eye in one sitting.
- End every change with a short **"verify this"** block: what to look at, what correct
  looks like, and what a specific failure would look like. Be concrete —
  "the ball should cross the field in about 3.1 seconds at rally start" beats
  "check the ball speed feels right."
- When a value needs playtesting rather than derivation (paddle acceleration curve,
  dialogue timer durations), say so explicitly and give a starting value with a range.
- Never claim something "works" or "is tested."

**You can check that it parses.** PICO-8 0.2.7 is installed at
`C:\Program Files (x86)\PICO-8\pico8.exe` (not on `PATH`). Running it with
`-x meta_pong/meta_pong.p8` loads the cart headlessly, executes the top-level chunk, prints
`RUNNING: meta_pong.p8` and exits 0 — a syntax error or a load-time runtime error surfaces
there instead of on the user's next launch. Do this after every edit to the cart, before
writing the verify block. It does **not** run `_update60` or `_draw`, so it proves
nothing behavioral: report it as "parses and loads clean," never as "works."

**You can also drive it headlessly.** `-x` executes the top-level chunk, so a *copy* of
the cart with `_init()` and a loop of `_update60()` calls appended will simulate real
frames. `btn`/`btnp` can be reassigned to inject input, and `printh()` reports state. This
tests **behavior** — state transitions, multi-frame sequences, input handling — not just
parsing. It found M11's freeze in seconds after reading the code had failed to:

```lua
function press(b) local o=btnp btnp=function(i) return i==b end _update60() btnp=o end
_init()
gm.level_index = 5
gm:start_level()
p.winner = 2
for i=1,900 do _update60() end
printh("resolving="..tostr(gm.resolving).." winner="..p.winner)
```

**A harness copy no longer fits under the token ceiling on its own.** The cart sits within
about a hundred tokens of 8,192, and a harness of any substance pushes it over — the run then
fails with `program too large` rather than a test result, which reads like a cart bug and is
not one. Strip what the harness cannot use when building the copy. `init_menu`, `nament:update`,
`nament:draw`, `_draw`, `apply_tear`, `set_scanlines`, `update_crt` and `draw_score` come to
roughly 700 tokens between them and none of them run under `-x`, which never calls `_draw`.
Replacing each body with a bare `end` is enough.

Work on a copy in the scratchpad, never the real cart. `_draw()` is not called, so nothing
visual can be checked this way — how the game *feels* still needs a human, and that is
most of what matters.

**The scratchpad is pruned between turns, and it lies about it.** The pruning deletes files
but leaves the directory tree standing, so a clone in there can end up with a `.git/`
containing four empty folders: `ls` still shows `.git`, and `git` says *"not a repository."*
In M13 this ate two local, unpushed **wiki** commits. Harness carts are disposable and it
does not matter; the wiki clone is not.

Treat anything committed in the scratchpad as **volatile until pushed**. Since wiki edits
normally sit unpushed across turns — pushing needs an explicit go-ahead, and that can be
several turns away — keep the edited `Meta-Pong.md` itself as the thing you are protecting,
not the commit. Recovery is then cheap: re-clone, copy the file back over, re-commit. Only
the git history is lost, and the wiki records settled state rather than process, so a single
consolidated commit is an acceptable outcome rather than a problem to reconstruct.

The cart repo is on a real disk and is **not** affected. This is a scratchpad-only hazard.

**Balance is measurable, and guessing at it has been wrong every time.** Overriding
`pong:handle_game_input()` with a controller built like `run_ai` — its own reaction delay
and aim error — puts the player on the same scale as COM, so "how much weaker than COM can
the player be and still rally?" becomes a number. Hook `score_point` to log `b.hits`, set
`win_score` high so the match never resolves, and call `p:update_game_state()` in a bare
loop. 30 points per configuration runs in seconds; treat ±10 points of win rate as noise.
M12 used this to find that softening COM *shortens* rallies, that rally length is capped at
roughly `1/AI_WHIFF`, and that longer rallies amplify the skill gap rather than closing it
— all three the opposite of what reading the code suggested. Two traps: `gm:start_level()`
loads Denial's Intro, which sets `ai_enabled = false`, so force it back on or COM's paddle
never moves; and PICO-8 numbers cap at 32767, so a frame guard of 300000 silently wraps
negative and the loop never runs.

**Anger's swarm is winnable only because the balls fly in formation, and that is the whole
trick.** Balls that arrive at *different* heights can only ever yield one interception
between them however many there are, so scattering the swarm makes it unwinnable and no
other knob rescues it. M13 proved that the expensive way: at four scattered balls per group
the player loses regardless of gap (24→72 frames), paddle max speed (4→8), pad (2→4) or
collidable height (8→12), with the score pinned near 22–22 the whole time. Spacing them out
one at a time is survivable but thin.

**The fix is a burst that holds formation.** Every ball in a burst shares one launch height
*and one `dy`*, so it keeps formation for the entire flight — wall bounces included, since
they all bounce at the same point in their arc — and the whole burst arrives inside about
11–14 px. That is roughly the paddle's effective band, so one good position sweeps a whole
burst. Sharing `dy` is the load-bearing half: same height with different angles fans out
across the field within a crossing and is no better than scattering.

**And model an imperfect player, or the number lies.** Two scattered balls per group looks
fine against a perfect controller — it wins 7 for 7 — and is unwinnable in the hand: a
controller that lets one ball in four go unchased loses *every* two-per-group configuration
by 9 to 16 points, at every gap tried. The perfect controller has no reaction time and hides
exactly the difficulty a person runs into. Ship against the 75% figure; use the perfect one
only to prove a configuration is possible at all.

Note the swarm is now **all-or-nothing per burst**, so scores move in steps of about eight
and a *parked* paddle still takes whole bursts by luck — a dead paddle measured 22–22, which
the tie rule correctly gives to COM. That is the intended floor: doing nothing cannot win.

**Check what the harness is actually running.** The first one-ball-per-group sweep measured
a 60-frame cadence rather than 20, because single-ball groups were still taking the
aim-and-wind-up path meant for Tests 1 and 2. The numbers looked clean and were answering a
different question. Aiming is now a per-test flag, not implied by group size.

**The harness copy must override `CD_ID`.** `cartdata` is keyed by name, not by cart file,
so a scratchpad copy writes to the *same* save file as the real cart. A harness that calls
`cd_save_name()` or completes an act leaves a checkpoint and a name behind, and the next
run of either cart resumes from it. In M11a this produced two phantom failures — `_init()`
resumed at act 2 so stage 1 never reset, and `cd_name()` returned a leftover `aab` — and
both looked like cart bugs. Rewrite the line to a throwaway id when building the copy:

```python
s = s.replace('CD_ID = "metapong_1972_1"', 'CD_ID = "metapong_harness"', 1)
```

Delete `%APPDATA%/pico-8/cdata/<id>.p8d.txt` before each run to guarantee a clean boot.

**`pico8 -x` does not always exit on this host.** It prints `RUNNING:` and the `printh`
output, then hangs rather than returning. Run it backgrounded with the output redirected to
a log, sleep ~10s, read the log, and kill leftover `pico8` processes afterwards — do not
wait on the process itself.

**The pause menu is reachable headlessly by overriding `menuitem`.** `init_menu()` calls the
global, so replacing it before `_init()` captures every item's callback and lets the harness
invoke it directly with the same bitfield PICO-8 passes (`1` left, `2` right):

```lua
MENU = {}
menuitem = function(i,l,f) MENU[i] = {l=l,f=f} end
_init()
MENU[1].f(2)
```

This is how M11b verified that the act selector moves palette, dialogue and checkpoint
together. Note `gm:start_level()` **no-ops when already in a level**, so a harness that sets
`gm.level_index` and calls it silently stays on the current act — set the index and call
`gm.level:load()` instead. That produced a phantom "wrong palette" reading before it was
spotted.

**Debugging.** `printh()` writes to the host console and is the only real logging
channel. Keep debug output behind a flag, and strip it before a milestone closes so it
doesn't eat the character budget. (`draw_debug()` is the surviving example and is now
dead code — see issue #54.)

**The milestone loop.** Sync → read the issue and the wiki sections it names, *before*
writing code → implement → hand over a verify block → the user launches the cart and
reports back → iterate → strip debug scaffolding → **measure every budget** → commit →
update or close the issue. **Each milestone is a GitHub issue**; there is no plan file.
M12–M16 are #60–#64.

**Record every budget at every milestone close** — compressed size, tokens, characters —
in the commit message and in the wiki's resource table. Watching one number is how M14 got
caught: compressed size was tracked from M12 and was comfortable, while tokens sat unmeasured
at 94.4% and the cart went **over the token ceiling mid-milestone**, refusing to load. A
budget that is not measured is not comfortable, it is unknown. If a future release adds a
limit this table does not carry — map size, sprite banks, memory — measure that too rather
than assuming the two we watch are the only two.

The full set PICO-8 enforces, and how each is read:

| Budget | Ceiling | How to measure |
|---|---|---|
| Tokens | 8,192 | `-x` reports `N / 8192` **only when over**. To read it while under, pad a copy with a known count and subtract — 300 × `zz=1` is 900 tokens |
| Compressed code | 15,616 | `.p8.rom` header, below |
| Characters | 65,535 | `wc -c` on the cart, minus the non-code sections |
| Sprites / SFX / music | 256 / 64 / 64 | Editor; the spritesheet is spoken for — phosphor stashes the previous frame in it |
| Map | 128 × 32 (+128 × 32 shared) | Unused |
| CPU | `stat(1)`, 1.0 = a full frame | The `cpu` pause-menu toggle |

`INFO()` prints code size, tokens and compressed size together from inside PICO-8, which is
the quickest read when a human is at the keyboard rather than a harness.

**Git workflow.** Conventional-commit style subject lines, reference the issue number.
The repository uses a **branch per cart** — all Meta Pong work lives on the `meta_pong`
branch, which lands on `main` through a pull request — and, since M13, a **branch per
milestone** beneath it: cut `m<n>-<name>` from `meta_pong`, and merge it back into
`meta_pong` by pull request. `meta_pong` → `main` stays a separate PR.

The milestone branch exists to keep the flow workable with more than one contributor
without being heavy for one. It is **not** a licence to open a second branch mid-milestone:
every push in a unit of work still goes to the same branch, because the user decides at
merge time whether to squash and that choice needs the whole history in one place.

The five steps, in order:

1. **Sync first.** The remote is `pico` (`github.com/akinlin/Pico_Games`) and the default
   branch is **`main`** — renamed from `master` on 2026-08-03.

   ```bash
   git fetch pico && git checkout main && git merge --ff-only pico/main
   git checkout meta_pong && git merge main
   ```

2. **Cut the milestone branch.** `git checkout -b m13-anger meta_pong`. Flat name — **not**
   `meta_pong/m13-anger`, because git cannot hold both a `meta_pong` branch and a
   `meta_pong/` ref namespace.
3. **Never commit to `main`,** and never to `meta_pong` directly once a milestone branch
   is open.
4. **Commit locally as progress is made** — don't save everything for one commit at the
   end. Local commits are free and need no permission.
5. **Ask before pushing.** When the work reaches a point worth publishing, say so and
   **wait for an explicit go-ahead**. Pushing is the outward-facing step and is the user's
   call every time; a go-ahead for one push does not authorize the next.

**The user owns PRs and merges.** Do not open, update, or merge a pull request, and do not
offer to. Stop at the pushed branch and hand back.

**Why step 1 has its own rule:** the local checkout has been found several commits behind
the remote at the start of a session with a clean working tree, so nothing signalled it.
In M11a a full pass was written against a base that predated M11 and had to be redone from
scratch — M11 had already rewritten the very code being edited. `git log --oneline
main..pico/main` is the one-line check; run it before trusting a clean `git status`.

---

## Assets are human-created

Three categories of content in this game are authored by the user, never by Claude:

- **Dialogue.** Every line COM speaks. Build the machinery and leave the slots empty —
  issues #60–#64 say the same for M12–M16. Structurally obvious placeholders
  (`line 1`, `section 2 line 3`) are fine as a test harness; anything that reads as a
  line of the finished game is not.
- **Audio.** All sounds and music.
- **Art.** Sprites, the cart label, and any authored pixel work.

**The boundary is authorship, not subject matter.** Transcribing a documented
specification is in bounds — the three hardware sounds are given as frequencies and
durations in the wiki's *Reference Materials*, the act palettes are listed in its *Game
Design*, and the playfield geometry is derived from the 1972 hardware. Reproducing those
is transcription. *Inventing* a sound, a line, or a sprite is authorship, and is not.

**Placeholders must be obvious and flagged.** Where a milestone needs an asset that does
not exist yet, either reuse an existing in-bounds asset or leave the hook silent — say
which, plainly, in the verify block, and track it so it gets replaced rather than shipped
by accident. **The per-character typewriter cue is the live case:** `snd_type()` is wired
into `term:update()` and is deliberately empty, awaiting a human-authored sound.

---

## Hard constraints

**Meta Pong is going to the BBS.** That is a settled decision, and it makes the
**compressed** ceiling the real one — the BBS distributes carts as `.p8.png`, so the
compressed limit is enforced on the only build that matters.

| Budget | Ceiling | Reality |
|---|---|---|
| **Tokens** | **8,192** | **The binding constraint, and the one nobody was watching.** 8,085 used at M14 close, 2026-08-17 (**98.7%**), up from 7,729 (94.4%) at M13 — a figure discovered only when the cart went *over* mid-milestone and refused to load. **107 tokens remain for Depression, Acceptance and every act mechanic still unwritten.** A whole string literal is 1 token, so dialogue is nearly free here and the pressure is entirely code. Enforced on every format, `.p8` included. See #70. |
| Compressed code | 15,616 bytes | 13,552 at M14 close (**86.8%**), from 12,968 (83.0%) at M13 and 11,801 (75.6%) at M12. **2,064 bytes remain** — real, but no longer the thing that runs out first. Enforced on `.p8.png` / `.p8.rom`, which is the release format. |
| Characters | 65,535 | Not binding, and **actively misleading** — it read as 28,413 spare on the same day compressed was 76% gone, and as roomy on the day tokens ran out. Still the ceiling for a plain `.p8`. |
| CPU | 139,810 cycles/frame at 60fps | Never binds. Worst measured case is 40%. |
| Sprites / SFX / music | 256 / 64 / 64 | Not close to binding. |

**Measure compressed size headlessly; do not estimate it.**

```bash
pico8 meta_pong.p8 -export meta_pong.p8.rom
```

The `.p8.rom` is exactly 32,768 bytes. Code lives at `0x4300` behind a PXA header —
`\x00pxa`, two bytes of decompressed length, then two bytes of **compressed** length.
`0x8000 - 0x4300 = 15,616` is the real ceiling, not the 15,360 quoted in older notes.
Fifteen seconds per measurement. **Delete the `.rom` afterwards** — it lands in the cart
folder and is not repo content.

**Prose costs more than code, per character.** Measured marginally by stripping each and
re-exporting: engine code **0.26** compressed bytes per raw character, dialogue prose
**0.62**. Code back-references well and English does not, so cutting a thousand characters
of engine buys only about four hundred characters of COM. Shrinking the engine is worth
doing (#70) but the leverage is well under 1:1 — do not assume otherwise.

Measured frame cost, not estimated: **~24%** in normal single-ball play with phosphor on;
**12%** for 40 balls at tier 3 with phosphor off; **40%** for both together. The 40-ball
figure **stopped being a stress configuration at M13** — Anger's Test 3 throws exactly 40,
with phosphor on, so 40% bounds the game's shipped worst case rather than being a
hypothetical. Because the swarm arrives as timed bursts, the measured peak is 16 balls at
once rather than 40, so the real figure is well under it. Note the cycles-per-frame
convention (2²³ ÷ 60) is the community reading of the manual's "8 MHz virtual CPU," not a
figure the manual states.

**The cart carries no comments.** Comments are free against the token budget — the
manual's *Code Limits* excludes them, along with commas, periods, `local`s, semicolons
and `end`s — but they count in full against the 65,535 characters, which is the budget
shared with dialogue. They cost 5,871 characters (9% of the total) before being stripped.
Rationale belongs on the wiki, in this file, or in the commit message; not in the cart.
The `-->8` tab separators look like comments and are not — they are structural.

Engine footprint is a standing priority. When two implementations are equally correct,
take the smaller one. Bargaining's pre-match choice system is the one sanctioned
exception — it is expected to be the largest act-specific chunk of code in the cart.

**Target: PICO-8 0.2.7, cart header `version 43`** — which is what the file says; keep it
there. 0.2.7 fixes a `dset()` flush bug that silently drops writes when
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
| Paddle | 1 px wide × 6 px tall drawn. COM collides 6; the **player collides 8**, plus 2 px of `paddle_pad` each end |
| Ball | 2 × 2 px (radius 1) |
| Net | x = 64, 1 px wide, 2 on / 2 off |
| COM paddle x | 20 |
| Player paddle x | 108 |
| Paddle travel | top-edge `y` from **6 to 84** for a 6 px paddle — one paddle height of dead zone each end, so the player's 8 px body travels 8 to 80. The dead zone is the `paddle_dead` axis (`{6,8}`), **not** the paddle's height: they were the same expression until M14, which meant a taller paddle silently lost reach at both ends. Bargaining's 16 px paddle keeps the standard 6–89 coverage band because of it |
| Serve x | 66 |

Ball, net, and paddle *width* are rounded up to minimum legible size — strict scaling
would put them under a pixel. Those three are deliberate departures. Everything else
is derived and must not be adjusted for "feel."

### Fixed-point is mandatory

The ball moves **sub-pixel on most frames**. Store position as a fractional value —
PICO-8 numbers are natively 16.16 fixed point, so this costs nothing — and round only
at draw time. Integer pixel steps cannot reproduce the angle set.

This matters most in zone selection. The eight bands are the paddle's **collidable
height / 8** — 0.75 px on a 6 px paddle, narrower than the ball. Zone selection uses the
**fractional** offset between ball center and paddle top edge. Rounding here collapses
eight zones into six and destroys the flat center band. The divisor was a hardcoded 0.75
until M12, which silently broke every paddle taller than 6 — including Bargaining's
longer-paddle choice.

### The velocity model — 42 vectors

Vertical and horizontal velocity come from **completely independent sources**, exactly
as in the hardware. 7 vertical states × 3 horizontal tiers × 2 directions = 42.

**Horizontal speed** — three discrete tiers off a rally hit counter. There is no
continuous acceleration. The counter saturates at 16 and resets to tier 1 on any point
scored or new match.

**The 6 / 16 thresholds are a playability decision, not the hardware's 4 / 12.** The
cross-court column is the reading budget: against ~13 frames of human reaction plus 35 for
the paddle to cross the field, tier 3's 61 frames leave a 1.2× margin against tier 2's
1.8×. Delaying the climb keeps rallies where the dialogue can land. Note the *slowest*
tier bounces most — vertical speed is independent of tier, so a steepest return crosses
302 px vertically at tier 1 (about three wall bounces) against one at tier 3.

| Rally hits | Tier | Derived | Shipped (× 1.4) | Cross-court |
|---|---|---|---|---|
| < 6 | 1 | 0.341 | **0.477** | 3.07 s |
| 6–15 | 2 | 0.683 | **0.956** | 1.53 s |
| ≥ 16 | 3 | 1.024 | **1.434** | 1.02 s |

"Cross-court" means the **88 px paddle-to-paddle separation**, not the 128 px screen
width. Timing wall-to-wall gives ~4.5 s at tier 1 and will look like a failure on
correct code.

**`ball_scale = 1.4` is a shipped playability multiplier, playtested not derived.** It
multiplies `BALL_SPEEDS` *and* `BALL_VZONES`, so the 42-vector model and every return
angle carry over exactly — only the clock changes. The derived column is the derivation
and stays on record; do not "correct" the cart back to it. `BALL_CAL = 1.4` couples
paddle response to it (see below): **if 1.4 is ever folded into `BALL_SPEEDS`, `BALL_CAL`
must become 1 in the same change**, or the paddle silently drops to 2.14 / 0.21.

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

Every value in that table is multiplied by the same `ball_scale`, which is exactly why
the angles below are unaffected by it.

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

`apply_spin()` was deleted in M3. Spin survives only as a parked idea for signalling COM
cheating — do not reintroduce it.

### Serve

| Rule | Behavior |
|---|---|
| Delay | ~1.7 s between the point scoring and the ball reappearing |
| Position | x = 66, two pixels clear of the net |
| Direction | Horizontal direction is unchanged by a miss — **the ball is served toward whoever missed it** |
| Vertical velocity | Whatever it was at the moment of the miss |
| Vertical position | The ball keeps travelling and bouncing **invisibly** through the delay, so its height on reappearance is effectively arbitrary. This is why the original's serve feels random. **Reproduce it deliberately — this is not a bug.** |
| First serve of a match | Always max vertical speed (±1.171), the steepest angle the model produces, at horizontal tier 1 |

**The rule is absolute — there is no longer an exception.** Bargaining's third choice used
to offer `com_serves_every_point`, which forced every serve toward the player. It was cut at
M14 for reading as a penalty rather than a bargain, and the axis went with it; a two-minute
match clock took its place. Do not reintroduce a serve-direction override without a design
decision on the wiki first.

### Collision

One model for all five acts: line-segment intersection between the ball's per-frame
movement vector and each wall's near edge, expanded by ball radius. Chosen because it
matches the hardware's rectangle-region approach and is inherently tunneling-proof at
sub-pixel speeds. Corners resolve as reliably as flat edges.

**It detects the ball *crossing* a face, so it misses the overlap case the hardware had:**
once the ball is past the paddle's plane nothing tests it again, and a paddle sweeping
vertically onto it passes straight through. `paddle_catch` takes that hit while the two
still overlap on screen. Anything that extends a paddle's reach must be applied in **two**
places — `ball_intercept()` *and* the swept-AABB reject above it in `update_ball()`.
Extending only the intercept makes the paddle behave *worse* near its edges rather than
doing nothing, because the AABB then gates the extension on the ball's direction of
travel.

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

Two top-level states only — `attract` and `level`. **Any button press** moves
`attract` → `level`.

`level_index` on entering `level` is set to one past the last **persisted, completed**
act, or 1 (Denial) with no checkpoint. A checkpoint of 5 means the game is finished;
start begins a fresh run at Denial with the completion badge left in place.

**One Pong engine, parameterized per act.** Never fork the engine. Each `level` owns a
Customization config applied to its `pong` instance on load. The axes are listed in
the wiki's *Tech Design* → Architecture → Per-act configuration. If an act needs behavior
that is not expressible as a config axis, that is a signal to add an axis, not to
special-case the engine.

Two axes whose values are easy to under-specify:

- **`ball_mode`** — `replica` (the standard model above), `slow_fast` (ball approaches
  very slowly then rebounds fast off the player's paddle), `homing` (ball actively
  seeks toward the player's paddle). `ball_mode_pool` holds the set Depression draws
  from, one per serve.
- **`serve_model`** — `replica` (a scored ball re-serves from x = 66 after
  `SERVE_DELAY`) or `launch` (Anger). Under `launch` a scored ball is **deleted** rather
  than re-served, `ball_count` is 0 so the act opens with an empty field, and balls enter
  only through `pong:launch(y)`, which spawns them at COM's paddle face travelling right
  at the pinned tier. The *schedule* — how many, in what groups, how far apart — is
  deliberately **not** a config axis: it varies per test, not per act, so Anger's
  `machine()` owns it.
- **`nickname`** — none in Denial, then **DUM** (Anger), **SKR** (Bargaining),
  **WHR** (Depression), **PLR** (Acceptance). All three characters long, which is why
  name entry is three characters. COM's own displayed name never changes.

**Persistence** via `cartdata("metapong_1972_1")`:

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

**`win_section` means the *player* wins.** `stage:resolve(w)` takes the raw winner id
(`2` = player, `1` = COM) and the naming is the only thing carrying that meaning — wiring
the branches to the opposite triggers is a silent failure that reads as the authored lines
being wrong.

Two dialogue rules that are easy to violate by accident:

- **Scrollback is continuous and clears exactly once per loop** — at stage end, immediately
  before `> run attract`. Not between Sections, and not on entering attract, so
  `> press any button` and `> run game` persist into the act and are pushed out by COM's
  dialogue rather than wiped. The window never closes; there is no open/close animation.
- **There is no player advance or skip button.** Dialogue is fully automatic. Do not add
  one. Bargaining's paddle-position choice system is a gameplay mechanic, not an
  exception to this.

---

## Building an act

The engine is finished. An act is three things and nothing else.

**1. A config entry.** `ACT_CONFIGS[n]`. Every axis has a default in `DEFAULT_CFG`;
override only what differs. Per-side axes are `{com, player}` tables — index 1 is COM,
index 2 the player, matching `hud.p1`/`p2`.

```lua
{palette=2, phosphor_mode=true, nickname="dum",
 speed_tier_pin=3, scoring_model="intercept", serve_model="launch",
 ball_count=0, ai_enabled=false, win_score={45,45},
 paddle_accel={0.5,0.4}, paddle_max_speed={6,4}}
```

That is Anger's real entry, and `win_score={45,45}` is deliberately unreachable: the act
throws 44 balls, each worth exactly one point, so **Anger does not race to a number** —
its `machine()` sets `p.winner` from the higher score once the last ball resolves. Keeping
the tally in the act rather than adding a `win_model` axis is the cheaper of the two, since
no other act would ever use it.

**2. A stage.**

```lua
local barg = stage:new("bargaining")
stages[3] = barg

barg:section({
    "a line on the default hold",
    {"a line that needs to breathe", T_LONG}
})

barg:section({"a section that waits for the game"}, true)

barg:pool({"a timed non-sequitur"})

barg.win_section  = barg:branch({"..."})
barg.lose_section = barg:branch({"..."})
```

A line is a bare string, or `{text, duration}` where it needs a hold other than
`T_SHORT`. `pool()` registers a section that fires at random on a recurring timer whenever
the stage has nothing else to say; `stage.idle` covers that resting state, the gate before
a stage's opening game event, **and the gate at the end of a `hold` section**.

`section()` extends the normal flow. `branch()` appends a section **outside** it, reachable
only by an explicit jump — an ending cannot be walked into. `stage:goto_section(i)`
switches content mid-print, pushing the partial line into scrollback; that is how a game
event interrupts a line. `on_complete` fires when a stage finishes, and the act transition
waits on the win/lose branch, so COM gets the last word before the game advances.

**The second argument to `section()` and `branch()` is `hold`.** A hold section parks into
`idle` when its last line's duration expires instead of advancing, and only a
`goto_section()` from the stage's `machine()` gets it moving again. That is the whole of
Anger's dialogue gating: it never advances on a timer between tests, so a ball cannot fire
before COM has finished telling the player what is about to happen. Denial uses no hold
sections at all — its dialogue runs continuously in the background of a live match, which
is the other of the two patterns.

**3. A `machine()` hook.** Runs every frame before line advance and can watch anything.
`init()` is called by `stage:reset()` on every act load, so per-act state starts clean.

```lua
function intro:init()
    self.idle = true
    p.cfg.ai_enabled = false
end

function intro:machine()
    if (self.idle and hud.p2_score >= INTRO_TRIGGER) self:goto_section(1)
end
```

`level:load()` runs `pong:configure()` **before** `stage:reset()`, which is what lets a
stage's `init()` override config for its own duration. A level may also own a *pre-stage*:
Denial's owns the Intro, loads it first, and swaps at its close without re-running
`load()`, so the score carries across as the spot.

**If an act needs behavior no axis expresses, add an axis — do not special-case the
engine.** That rule is why there is still one engine.

**Testing an act without playing to it.** Pause menu → `act` steps 1–5 with left/right.
It is real navigation — it sets `gm.level_index`, **writes the checkpoint**, clears the band
and loads the level — so it moves act, palette, dialogue and save state together, and it
destroys real progress. `DEBUG_KEYS` gives `1` = player win and `2` = player loss, which is
how the win/lose branches were verified, plus `[` / `]` to step `ball_scale` live.

**Every character spent on act code is a character not spent on dialogue.**

---

## PICO-8 specifics

- **`_update60`, not `_update`.** 60 fps matches the machine's 60.05 Hz field rate, and
  every velocity above is expressed in units per 60 Hz frame.
- **No `dt`.** Never derive a delta from `time()` and scale velocities by it. Fixed 60 Hz
  means velocities are applied per frame, full stop. This also removes a class of
  tunneling bugs. All narrative timers are frame counts for the same reason.
- **Palettes** are two 16-byte writes per act — the base display palette at `0x5f10` and
  the darkened scanline palette at `0x5f60` — each a single multi-value `poke()`, composed
  at call time from `ACT_PALETTES` (game surface) and `CLI_PALETTES` (console surface),
  which share one index. They target the *display* palette, so they recolor the entire
  frame including already-drawn pixels at zero per-object cost. **Both must be written
  together on act load** or the scanlines keep the previous act's colors. A **sixth row**
  exists in both tables for attract, so the console can be green there and white in Denial.
- **CRT scanlines** use per-line palette hardware: `poke(0x5f5f, 0x10)`, scanline
  palette at `0x5f60`–`0x5f6f`, per-line selection bitfield at `0x5f70`–`0x5f7f`. Set
  once, applied by the display hardware at no per-frame cost. **Scoped, not global** —
  enabled on rows **1–19** (labels + score) and **96–127** (console band) only, never the
  game area, enforced twice over: by the bitfield, and by the scanline palette being
  identity for background, paddles and ball. Two caveats: this shares `0x5f60`–`0x5f6f`
  with `fillp`'s secondary palette, so the two cannot both be used; and **these addresses
  are undocumented in the manual**, so re-verify against any future release.
- **Phosphor glow** is a per-act boolean, `phosphor_mode`, and it is **on in every act**.
  It blends the whole previous frame, stashed in the otherwise-unused spritesheet, and
  measures **~24%** of frame in normal play (40% against a 40-ball tier-3 swarm). The
  earlier three-state `off`/`ball`/`full` axis and its discrete 2-dot ball trail were
  deleted in M11a — do not reintroduce them.
- **Phosphor requires `palt(0, false)`.** The blit is `sspr`, and colour 0 is transparent
  to sprite drawing by default, so every background pixel of the blit is a no-op and the
  screen is never actually cleared — PICO-8's own boot console text persists under the
  playfield indefinitely. Set once at init, alongside `memset(0x0000, 0, 0x2000)` to stop
  the spritesheet data flashing on frame 0. `cls()` is **not** the fix: it costs 2,052
  cycles/frame to clear pixels the blit overwrites anyway.
- **`pal()` with no arguments resets all three palettes** — draw, display and secondary —
  wiping both the act palette at `0x5f10` and the scanline palette at `0x5f60`. Restore
  individual draw entries explicitly. The symptom is an act rendering green-on-black.
- **A face button is three keys, and a debug key that shadows one is a live bug.** The
  manual's default mapping is `[O]: Z C N` and `[X]: X V M`, plus the cursors. `DEBUG_KEYS`
  read `c` = player win and `v` = player loss, so confirming a Bargaining choice with C both
  committed the choice and won the act in the same frame — the labels stayed on screen while
  the game left for Depression. It was latent from the day the debug keys went in and
  unreachable until M14, because Denial and Anger never ask the player for a face button.
  The keys are `1` and `2` now. **Any future keyboard hook must avoid Z X C V N M, the
  cursors, and player 1's S F E D / LSHIFT / TAB W Q A.**
- **`btnp()` auto-repeat** timing is tuned via `0x5f5c` (delay) and `0x5f5d` (interval).
  Needed for name entry.
- **Do not use keyboard input** (`stat(30)`/`stat(31)`). It requires devkit mode,
  displays a warning banner to BBS players, and does not exist on handheld or mobile
  targets. Name entry is button-driven.
- **Do not use mouse input**, for the same reasons. Paddle control is buttons with
  acceleration/momentum.

---

## Codebase conventions and gotchas

### Settled conventions

Both were off-by-one traps until M5. They are now uniform; new code must not reintroduce
the split.

- **A wall's logical size is its drawn size.** `create_wall()` draws
  `rectfill(x, y, x+width-1, y+height-1)`, and collision reads the same `width` /
  `height`. Paddles therefore carry the spec's real `1 × 6`. Under the previous inclusive
  draw the paddle's collidable face was 5 units against a 6 px sprite, which gave it an
  overhang above its top edge and none below — the top rim returned steep-up 2.4× more
  often than the bottom rim returned steep-down. Zone reachability is symmetric now.
- **`ball.x` / `ball.y` are the ball's center**, in collision, in drawing and in zone
  selection alike. `draw_balls()` renders outward from it. The field bounds are placed so
  the ball's *edge* lands flush on rows 0 and 95: top wall at `y = -3`, bottom at
  `PLAYFIELD_BOTTOM + 1`.

### Still live

- **The AI no longer casts a prediction ray, and that is why `intercept()` has no clamps.**
  M6 replaced `predict_wall` with an algebraic solve for the intercept height plus a
  reflection loop, so the ±140 / −50 coordinate clamps went with it. They existed because a
  330 px prediction ray at tier 3 produced 122.9 × 330 = 40,551, which **wraps to −24,986**
  against the 32,767 ceiling of a 16.16 number. Ball-vs-wall collision peaks at 12,480 and
  never came close. **If anything ever reintroduces a long ray, the overflow comes back** —
  ball coordinates staying inside [-1, 129] is the only thing keeping the products small.
- **A new palette role must be added to the phosphor funnel or it burns in permanently.**
  `_draw()`'s `full` phosphor path has no `cls()` — the dimmed previous frame *is* the
  background. It maps roles `1`/`2`/`3` → `C_TRAIL1` → `C_TRAIL2` → `C_BG`, and **anything
  outside that set maps to itself**, so it never fades and leaves a permanent smear on the
  stashed frame. Add the role to both the dim mapping and the restore below it. The
  exception is a role that is fully overdrawn every frame — the console band background is
  a `rectfill`, so it is deliberately left out.
- **The score `hud.p1_x` / `p2_x` are field *inner* edges, not left edges.** The left
  score is right-aligned onto its edge so the pair stays symmetric about the net at any
  digit count. Digits are `\^w\^t` (wide + tall), so each glyph is **8 px** wide, not 4 —
  which is what made an earlier placement overlap the net at double digits. Do not use
  `\^p`: pinball mode also turns on *stripey*, which renders the digits dotted, and the
  original machine's score is solid block numerals.

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
4. **A 32-row console band** exists at all, replacing 32 rows of playfield.
5. **Ball speed is 1.4× the derived hardware speed** — `ball_scale`, a playtested
   playability multiplier applied to both axes so every angle survives.
6. **Scanlines are scoped, not full-screen** — rows 1–19 and 96–127 only. A faithful
   scanline is finer than one pixel at this resolution, and full-screen coverage caused
   eye strain and posed a photosensitivity risk.
7. **The speed tiers climb at 6 and 16 volleys, not 4 and 12.** Reading budget — see
   *The velocity model*. Rallies are where the dialogue lands, so the ball stays legible
   longer than the hardware kept it.
8. **The player's paddle is invisibly better than COM's**, three ways: 8 px of collidable
   height behind a 6 px sprite (`paddle_draw`), 2 px of `paddle_pad` past each end, and a
   3 px `paddle_catch` window that rescues a ball the paddle sweeps onto after it has
   passed. All three are per-side and all are zero for COM. **The advantage is deliberately
   invisible** — a visibly larger paddle was built, playtested and rejected for reading as
   the game conceding. Bargaining's longer paddle is the exception that proves it: an
   advantage the player *chooses* is allowed to show.

---

## GitHub issues

Issues are where all work and all status live. The open ones:

| | |
|---|---|
| **#35** | Refresh the class diagram — the last artefact still predating the M0–M11b object model |
| **#54** | Strip debug scaffolding and dead code. Holds the **one ship-blocker** (`poke(0x5f2d, 1)`). Partly done: M14 took `draw_debug`, `pong:create_prediction`, `level:input` and the per-wall debug fields because the token ceiling forced it. The player's paddle axes were never dead — that claim in the body is stale |
| **#55** | Obsolete — the axis was fixed in #62 and then cut entirely at M14. Close it |
| **#56** | Playtest tuning: dialogue timers, Depression's ball modes, COM's paddle, and **Anger's swarm cadence** — the count is settled at 40, the group size and gap are not |
| **#57** | Console band colours inside an act are placeholder |
| **#58** | Parking Lot — design ideas kept but not scheduled |
| **#60–#64** | The five acts: Intro + Denial, Anger, Bargaining, Depression, Acceptance |
| **#66** | The typewriter cue — `snd_type()` is the deliberately silent placeholder, awaiting a human-authored sound |
| **#67** | M17 release build. Compressed size has never been measured and the cart has no `__label__` |
| **#68** | Full-playthrough pass — the seams *between* acts, which no act's own issue covers |

`DEBUG_AI` was deleted in M12 — it forced `ai_enabled` for every act and bypassed the
2-point arming that #60 exists to build. `DEFAULT_CFG.ai_enabled` is now `true`, and the
Intro stage owns the unmanned exception.

**[Project board 3](https://github.com/users/akinlin/projects/3) is a second surface and it
does not update itself.** Closing an issue moves its card to Done automatically; **creating
one puts no card there at all**. Everything from #54 onward was missing from the board until
the #59 cleanup found it. Add a new issue by hand in the same breath as opening it:

```bash
gh project item-add 3 --owner akinlin --url https://github.com/akinlin/Pico_Games/issues/<n>
```

then set Status with `gh project item-edit --id <item> --project-id PVT_kwHOAEb3JM4AJ-KS
--field-id PVTSSF_lAHOAEb3JM4AJ-KSzgGMzCY --single-select-option-id f75ad846` (that option
id is `Todo`). The repo's GitHub *milestones* are a third surface and are stale — ignore
them; they predate the M-numbered milestones entirely.

**Older issue bodies are not a source of truth.** Read the wiki first, always. Where an
issue body and the wiki disagree, the wiki wins and the issue is stale — say so rather than
building from it. #59 closed the four bodies that actively contradicted the wiki — **#29**
(Depression's ball), **#30** (center zones and spin), **#32** (scanline scope), **#34**
(persistence format) — each with a comment recording what the body got wrong, and swept the
M1–M11 issues still open against finished work. **Nothing open disagrees with the wiki
today, and that will not stay true on its own.**
