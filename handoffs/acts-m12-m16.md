# Handoff — M12–M16, the five acts

**Start here for the next build session.** Read `CLAUDE.md`, the
[wiki](https://github.com/akinlin/Pico_Games/wiki/Meta-Pong) and `docs/BUILD-PLAN.md`
first; this file covers what those don't — where the engine actually stands and how an act
gets assembled now that it exists.

---

## Where the project is

**All eleven pre-act milestones are done (M0–M11).** The engine is finished. M12–M16 are
configuration, a per-act state machine, and dialogue.

**Cart: ~33,500 of 65,535 characters (51%)** — roughly **32k left**, shared between the
five acts' code and every line COM speaks. That is the binding constraint and it is why
the engine was kept small.

**Measured performance:** ~24% of frame in normal play with phosphor on; 40% with phosphor
plus a 40-ball swarm. Both comfortably inside budget.

**Branch state:** everything through M11b is merged to `master`.

---

## What already works, so you don't rebuild it

- Two top-level states, `attract` and `level`
- Win → checkpoint written, next act loads. Loss → back to attract in black and white,
  same act resumes when the player returns. Act 5 win → name entry → badge
- Persistence: `furthest_completed_act` and a 3-character name, verified across process
  restarts
- The 42-vector velocity model, 8-zone paddle returns, serve rules with invisible travel
- AI with self-balancing tiers, `fixed` mode built but unused until Acceptance
- Per-act config applied on load; every axis in the Tech Design table is wired
- Scrolling terminal with typewriter reveal, continuous scrollback, scanlines and tear
- Three hardware sounds; a silent per-character hook awaiting a human-authored cue

---

## How to build an act

An act is three things.

### 1. A config entry

`ACT_CONFIGS[n]` in `pong.p8`. Every axis has a default in `DEFAULT_CFG`; only override
what differs. Index 1 = COM, index 2 = player, matching `hud.p1`/`p2`.

```lua
{palette=2, nickname="dum", speed_tier_pin=3, scoring_model="intercept"}
```

Available: `paddle_height`, `paddle_accel`, `paddle_max_speed`, `ball_count`, `ball_mode`,
`ball_mode_pool`, `speed_tier_pin`, `win_score`, `sudden_death`, `scoring_model`,
`score_multiplier_com`, `initial_score_com`, `scoring_enabled`, `com_serves_every_point`,
`ai_enabled`, `ai_mode`, `ai_tier`, `palette`, `phosphor_mode` (boolean), `nickname`,
`cli_rate`. Per-side axes are `{com, player}` tables; `win_score` is one of them.

**If an act needs behavior no axis expresses, add an axis — do not special-case the
engine.** That rule is why the engine is still one engine.

### 2. A stage

```lua
local anger = stage:new("anger")
stages[2] = anger

anger:section({
    line("...", T_LONG),
    line("...", T_MED)
})

anger.win_section  = anger:branch({ line("...", T_MED) })
anger.lose_section = anger:branch({ line("...", T_MED) })
```

- `section()` extends the normal flow. `branch()` appends a section **outside** it,
  reachable only when the match resolves. An ending cannot be walked into.
- `T_SHORT` / `T_MED` / `T_LONG` = 45 / 90 / 180 frames, held **after** the line finishes
  typing.
- `stage:goto_section(i)` switches content mid-print, pushing the partial line into
  scrollback. This is how a game event interrupts a line.
- `on_complete` fires when a stage finishes. The act transition already waits on the
  win/lose branch, so COM gets the last word before the game advances.

### 3. A `machine()` hook

Runs every frame before line advance, and can watch anything. Denial's:

```lua
function denial:init()
    self.armed = false
end

function denial:machine()
    if not self.armed and hud.p2_score > 1 then
        self.armed = true
        gm.level.pong.cfg.ai_enabled = true
        hud.p1_score = 0
        hud.p2_score = 0
    end
end
```

`init()` is called by `stage:reset()` on every act load, so per-act state starts clean.

### Testing an act without playing to it

Pause menu → **`act`** steps 1..5 with left/right. It is real navigation, not a
reconfigure: it sets `gm.level_index`, **writes the checkpoint**, clears the band and loads
the level, so act, palette, dialogue and save state all move together — and it therefore
overwrites real progress. `ACT_CONFIGS[6]`, the 40-ball stress config, is no longer
reachable from it.

`DEBUG_KEYS` gives `c` = player win and `v` = player loss, which is how the win/lose
branches and the whole progression were verified, plus `[` / `]` to step `ball_scale` live.
`DEBUG_AI` makes COM play from the first serve, bypassing Denial's 2-point arming — turn it
off when you build M12's real arming logic.

---

## Per-act notes from the build plan

| M | Act | The part that isn't just config |
|---|---|---|
| M12 | **Intro + Denial** | Unmanned paddle for 2 points, COM takes over mid-sentence, score reset to 0–0, score-checkpoint sections at 0/5/10/11 (checkpoint 0 is a single fixed Section — the match is always tied there; 5/10/11 branch player-first vs COM-first), timed non-sequitur pool a checkpoint can interrupt mid-print |
| M13 | **Anger** | Nickname **DUM**. Three tests as three configs (1 fastball → 2 offset balls → staggered swarm), `intercept` scoring, tier pinned to 3, dialogue **gates** ball-firing, score cumulative to 11 |
| M14 | **Bargaining** | Nickname **SKR**. The pre-match choice screen — largest act-specific chunk in the cart. Runs inside `level` as a gate, so palette and dialogue stay live behind it. Head start must **not** feed the self-balancing calculation (`com_handicap` already exists for this) |
| M15 | **Depression** | Nickname **WHR**. Asymmetric win (player 5 / COM 11), `ball_mode_pool` = `slow_fast` + `homing` drawn per serve, on player reaching 5 both `scoring_enabled` and `ai_enabled` go false while closing dialogue runs |
| M16 | **Acceptance** | Nickname **PLR** until the win. `ai_mode = fixed` — the only act that uses it. Minimal dialogue. Win → name entry → badge replaces every AI-assigned nickname |

**Nickname UI is built** (M11a): `com` at x = 8 and the act's nickname at x = 108, both at
y = 1, drawn in `level` only and only when the act sets a nickname — so Denial shows
neither. A stored completion name replaces the AI-assigned nickname on every act. M13 only
has to set `nickname = "dum"`.

---

## Things that will bite

- **Dialogue is author-written.** Build the machinery, leave the slots empty. Structural
  placeholders (`line 1`) are fine as a harness; anything reading as finished game text is
  not. Same for audio and art. See `CLAUDE.md` → *Assets are human-created*.
- **The wiki is the only design doc.** The three repo mirrors were deleted at the
  2026-08-03 docs pass; read
  [the wiki](https://github.com/akinlin/Pico_Games/wiki/Meta-Pong) directly. The freeze is
  lifted, but it records **settled decisions and shipped implementation only** — park
  anything undecided in a GitHub issue, and record build status in `DEVLOG.md` and
  `docs/BUILD-PLAN.md`.
- **`ball_mode`'s `slow_fast` and `homing` are minimal implementations** so the axis is
  real rather than a stub. M15 owns tuning them and may change their semantics.
- **COM's paddle response has never been tuned** independently of the player's — it sits at
  `accel 0.08 / max 2.5` because that is what it was playtested against. It interacts with
  the `ai_levels` difficulty curve, so Bargaining's slower-COM option will want a look.
- **Timer values are a first guess.** 45/90/180 frames felt right against Denial's lines;
  the target is a ~20 minute clean playthrough, leaning shorter. Expect to tune once real
  dialogue exists.
- **Every character spent on act code is a character not spent on dialogue.**

---

## Verifying

Per `CLAUDE.md`: after every cart edit run the parse check, and hand over a concrete
"verify this" block. Behavior can now be tested headlessly by driving `_update60()` on a
copy of the cart — that found M11's freeze in seconds. Anything about how it *looks or
feels* still needs the user to play it.
