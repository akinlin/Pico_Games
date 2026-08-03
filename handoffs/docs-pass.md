# Handoff — End-of-Alpha documentation pass

**Standalone work item.** Everything needed is in this file; it does not depend on any
prior conversation. Do this in its own session, not alongside feature work.

---

## What this is

`docs/game-design.md`, `docs/tech-design.md` and `docs/reference-materials.md` were frozen
during Alpha so that engine work wouldn't be interleaved with documentation churn. Design
decisions taken during M0–M11 were recorded in a backlog instead. This pass applies that
backlog.

## Do this first — the order matters

`docs/*.md` are **mirrors of the GitHub wiki** and carry a header saying so:

```
<!-- MIRROR OF THE GITHUB WIKI. Do not edit here.
     Source: https://github.com/akinlin/Pico_Games/wiki/Meta-Pong
     Edit the wiki, then re-sync this file. -->
```

**Edit the wiki first, then re-sync the mirrors down.** Editing the mirror leaves changes
that the next sync silently reverts — this already happened once, across three milestones,
before anyone noticed the header.

The wiki is a git repo:

```bash
git clone https://github.com/akinlin/Pico_Games.wiki.git
```

All three `docs/` files mirror a **single wiki page**, `Meta-Pong.md`, whose top-level
sections are `## Game Design`, `## Tech Design` and `## Reference Materials`. Repo mirrors
and wiki were last consistent at wiki commit `2e419bc` (through M7b).

`docs/BUILD-PLAN.md` is **not** a mirror — it lives only in the repo. So does `DEVLOG.md`
and `CLAUDE.md`. Those can be edited directly.

---

## The backlog

### Game Design changes

**1. A loss no longer replays the act immediately.** It returns the player to `attract`,
with the palette reverting to Denial's black and white — COM has gone quiet and is waiting
for you to come back. Pressing start resumes the *same* act with fresh dialogue. Tech
Design's *Resolving a level result* table says loss "resets the current level, replays same
act", which describes the destination but not the trip through attract.

**2. Phosphor is now `full` in every act, including Anger.** Measured 40% of frame with
`full` plus the 40-ball swarm, ~24% in normal play; the cost was accepted. **This removes a
narrative beat Game Design currently states explicitly:**

> "Phosphor glow disabled — the frame budget goes to the swarm instead. By this point COM
> has already abandoned any pretense that this is a faithful 1972 machine, so the loss of
> the period glow reads as intentional."

That rationale needs rewriting. **If the "machine stops pretending" signal is still wanted
in Anger, it needs another carrier** — this is a live design question, not just a doc edit.

**3. Parking Lot additions:**
- Explore `paddle_accel` / `paddle_max_speed` as expressive *per-situation* settings rather
  than fixed per-act values. Changing paddle response mid-act felt good in playtest.
- ~~Surface the "press any button to start" prompt through the CLI terminal band rather than
  as text over the playfield.~~ **Built in M11b — see item 18. Do not add to the Parking Lot.**
- CRT treatment as a player-facing option rather than always-on. Already added to the
  Parking Lot in M7a; verify it survived.

### Tech Design changes

**4. The textbox state machine is gone.** `closed → opening → open → closing` and the slide
motion are dropped. The window is permanently open — a single scrolling scrollback view
where lines are removed as they scroll off the top. The rule *"history clears whenever the
window closes and reopens"* lost its trigger along with the close, and **scrollback is now
continuous and never clears**.

**5. `phosphor_enabled` became `phosphor_mode`** — three-state `off` / `ball` / `full`,
because trailing the ball and blending the whole frame turned out to be different design
choices rather than two implementations of one idea. Both ship.

**6. Score digits use `\^w\^t`, not `\^p`.** Pinball mode includes *stripey*, which renders
the digits dotted; the original machine's score is solid block numerals.

**7. New: palette contrast rule.** A scanline-palette entry must remain distinguishable
from the *darkened background*, not merely be lower in luminance. PICO-8 has only two
greens, so Bargaining's bright-green score has no darker sibling that isn't its own
background — darkening it made the score vanish on alternate lines.

**8. New: `pal()` hazard.** `pal()` with no arguments resets **all three** palettes — draw,
display *and* secondary — wiping both the act palette at `0x5f10` and the scanline palette
at `0x5f60`. Restore individual draw entries explicitly. Symptom is an act rendering
green-on-black.

**9. New: trail separation rule.** A phosphor trail dot is drawn only when total
displacement over the sample window reaches 2 px. Below that it cannot separate from a
2 × 2 ball and reads as a *fatter ball*. Also physically correct — a slow spot on a CRT sits
inside its own afterglow and brightens rather than smears.

**10. Scanlines are scoped, not global.** They apply to the score, the completion badge and
the dialogue text only — never the game area. Two independent mechanisms enforce it: the
`0x5f70` bitfield enables only rows 2–19 and 96–127, and the scanline palette is identity
for background, paddles and ball. Density 1/8, slow phase crawl, plus an infrequent
(7–17 s) horizontal tear sweeping in ~0.5 s. Rationale: the original's 246 scanlines map
onto 96 rows, so a real scanline pair is finer than one pixel we can draw and anything
rendered is ~2.5× too coarse. An earlier full-screen version at 50% coverage caused eye
strain and posed a photosensitivity risk.

**11. Audio asset boundary.** Audio is a human-created asset. The three hardware sounds are
transcribed from documented reference specs (frequency and duration) and are in bounds;
anything else — including the typewriter cue — is placeholder only. *(Already recorded in
`CLAUDE.md`; Tech Design may want it too.)*

**12. Measured CPU replaces estimates.** Tech Design's budget table carries ~24% for
phosphor and ~17% for the swarm. Measured: **`full` phosphor + 40 balls at tier 3 = 40%**;
**normal single-ball play with `full` = ~24%**. Also worth noting the ceiling convention
(2²³ cycles/second ÷ 60) is a community reading, not stated in the manual.

**13. Paddle values.** Playtest-tuned to `paddle_accel = 0.4`, `paddle_max_speed = 4.5` for
the **player**. COM stays at 0.08 / 2.5 — the values it was actually playtested against.
**COM's paddle response has never been tuned independently**, and it interacts with the
`ai_levels` difficulty curve. Flag as an open item rather than documenting 0.08/2.5 as
intentional.

### CLI / terminal — decided and built in M11b

The terminal design session (2026-08-03) settled what the band *is* in fiction and rebuilt
it against that. Branch `m11b-cli-console`. **These items amend earlier entries in this
backlog — read them together with #4 and #3.**

**14. The terminal is the host machine's console, not part of Pong.** The player boots into
a fictional machine's PICO-8 console; the Pong cart is a program running on it. This is the
governing decision and everything below follows from it. Game Design's *Dialogue System*
section (currently "a CLI/terminal-style window… POSIX-style command-window look") needs
rewriting around it.

**15. Two voices share the band.** `console` (the host machine) and `com`. They differ by
prefix and color only:

| | `console` | `com` |
|---|---|---|
| Prefix | `>` , authored into the line | none |
| Color | green at attract; the act's text color inside a stage | the act's text color |
| Speaks | boot, stage end, attract prompt | Denial onward |

Voice is a first-class parameter (`term:say(text, voice, instant)`) and each retained
scrollback row stores its own, so a third voice is a data change. **Currently only COM
speaks during an act** — the console is bookends. Keeping mid-act console lines *possible*
was an explicit requirement.

**16. The boot and transition sequences.** Cold boot, once per cart launch: `pico-8 cli` and
`(c) lexaloffle games llp` appear instantly (they are output), then `> load pong.p8` and
`> run` type (they are commands). The playfield appears only after `> run`. Then
`> press any button`. On press, `> run game` types and the act begins.

At the end of a stage: COM's last line, then the band **clears**, then `> run attract` types
**while the act's palette is still in force** — COM set it and has stepped away, so the
console comes back up still wearing his colors. The palette reverts as attract loads.

`run` (bare) is the real PICO-8 command that starts the cart; `run attract` and `run game`
are the cart's own internal commands. Two nested layers of the same fiction, deliberately
indistinguishable to the player. The boot header omits a version number on purpose, so the
cart doesn't date itself against future PICO-8 releases.

**17. Amends #4 — scrollback clears exactly once.** #4 says scrollback "is now continuous
and never clears." Correct as far as it went, but the clear now has one trigger: **stage
end**, immediately before `> run attract`. Not between Sections, and not on entering
attract — so `> press any button` and `> run game` persist into the act and are pushed out
by COM's dialogue rather than wiped.

**18. Amends #3 — the attract prompt Parking Lot item is done.** "Surface the *press any
button* prompt through the CLI terminal band" is implemented, not parked. Remove it from
the Parking Lot list rather than adding it.

**19. Tech Design — `textbox` is now `term`.** The state machine (`closed → opening → open
→ closing`) and the slide motion were already gone; the *Textbox behavior* table still
documents both and must be rewritten. `open()` and `close()` were dead code and are
deleted. New surface: `say(text, voice, instant)`, `clear()`, `done()`, and a `rate` field.

**20. Tech Design — band geometry, corrected.** Rows 96–127 inclusive is **32 rows, not
31**. The `31` came from `textbox:new(0,96,127,31,C_BG)`, whose `w`/`h`/`c` arguments were
accepted and discarded — dead parameters, never a source of truth. The old layout drew four
lines at y=98/104/110/116, occupying rows 98–120 and leaving **rows 121–127 unused**. Now
five lines at y=97/103/109/115/121, ending at row 125. Columns unchanged at 31 from x=2.

**21. Tech Design — the console has its own palette table.** `ACT_PALETTES` (the game
surface) and `CLI_PALETTES` (the console surface) are two tables sharing one index, so the
band's background and text are controllable independently of the act. `CLI_PALETTES` rows
are `{bg, text, text_dark}`; the console background does **not** darken under scanlines,
matching how the screen background behaves. Roles are `C_CLI` (6) for console text and
`C_CLIBG` (7) for the band background.

A **sixth row** exists in both tables for attract (`PAL_ATTRACT`) — attract and Denial
previously shared palette 1, so the console could not be green at attract and white in
Denial without splitting them. **Attract is the only place the two surfaces disagree
today:** console background `2` (dark purple) against a screen background of `0`, with
green text. Every act sets its console background equal to its screen background, so the
band is invisible there — that is deliberate placeholder state, not a finished choice.

Inside an act the console text color equals the act's score color, which is what makes the
console inherit COM's palette mechanically rather than by a branch.

**22. Tech Design — new roles must be added to the phosphor funnel.** `_draw()` maps roles
1/2/3 → `trail1` → `trail2` → background. **Anything outside that set maps to itself and
never fades**, leaving a permanent smear on the phosphor buffer. `C_CLI` was added to both
the set and the restore. Any future role has to be, too — this is a trap, not a detail.

**23. Tech Design — per-act reveal rate axis.** `cli_rate` on the act config, applied in
`pong:configure`, defaulting to `TB_REVEAL` (2 frames/char, ~30 cps). **The axis exists and
every act currently uses the default.** Per-act values are deliberately unset: reveal speed
is characterisation and cannot be tuned without the written dialogue. M12–M16 own it.

**25. A blank line separates the two voices.** `term:say()` pushes an empty row whenever the
voice changes and the band already has content, so console output and COM's speech read as
distinct blocks rather than one stream. Costs one of the five rows whenever both voices are
on screen — accepted deliberately for the visual separation.

**26. Game Design — the completion beat runs through the console.** After the player
confirms their nickname the band **clears**, the console prints `congrats <nickname>`, then
`> run attract` types, then attract loads. It runs in Acceptance's palette, since the
transition happens before the revert — same rule as any other stage ending. `congrats` is
console *output* and carries no `>`, following the boot header rather than the command
lines. **Both the wording and that prefix choice are placeholders for the author.**

**27. Tech Design — the band background costs the dialogue's phosphor trail.** Filling the
band means the dimmed previous frame is overdrawn there every frame, so text inside it no
longer glows. Tech Design's phosphor row currently claims `full` makes "everything that
moves glow, including score digits and dialogue text" — the dialogue-text half is no longer
true. In practice the loss is small (static text's dimmed copy sits exactly under the bright
one and was already invisible; only the scroll-up smear and cursor blink trail are gone),
but the sentence needs correcting. If the glow is wanted back, the fill can be skipped when
the console background equals the screen background — at the cost of the band behaving
differently per act.

**24. Tech Design — the palette contrast rule gains a case.** Console green has no darker
sibling that isn't Bargaining's own background (`ACT_PALETTES[3][1] = 3`). Harmless today,
because the console only speaks at attract where the background is black. **It becomes a
real bug the first time a console line is written into a stage** — which #15 explicitly
keeps possible. Flag it next to the existing rule.

### Things to verify rather than assume

- **Stale GitHub issues.** `CLAUDE.md` lists #29, #30, #32, #34 as describing superseded
  behavior. Check whether they should be closed or rewritten now the design is settled.
- **Dev scaffolding.** The pause menu currently carries an act selector, `reset data`, a
  phosphor toggle, a CPU readout and a force-result item, plus `DEBUG_ACT`. Decide what
  ships. The act selector and reset may be worth keeping; force-result certainly isn't.
- **`ball_mode`.** `slow_fast` and `homing` are minimal working implementations so the axis
  is real rather than a stub. Depression (M15) owns tuning them — check whether M15 changed
  the semantics before documenting them.

- **Does an act *win* route through the console too?** M11b hooked the
  clear → `> run attract` → `> press any button` → `> run game` sequence to the paths that
  actually return to attract, which today means **a loss and game completion only**. An act
  win still calls `level:load()` and goes straight into the next act, per Game Design's
  "stage ends, transitions to Anger." That was an assumption, not a decision — if each act
  should read as its own separate `run` of the program, it is a one-line change in
  `game_manager:resolve()`.

- **The name-entry path skips `> run attract`.** Acceptance win → name entry → `to_attract()`,
  which prints the prompt but not the `> run attract` line, because the sequence hangs off
  the resolve branch rather than off `to_attract()` itself. Probably fine — name entry is its
  own screen — but confirm it reads right once that flow is playable.

---

## When done

- Remove the freeze notice from `docs/BUILD-PLAN.md` and empty its deferred table.
- Re-sync `docs/*.md` from the wiki so mirrors and source agree again.
- Record the new wiki commit hash, the way `2e419bc` is recorded above.
