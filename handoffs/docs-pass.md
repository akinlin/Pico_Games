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
- Surface the "press any button to start" prompt through the CLI terminal band rather than
  as text over the playfield. Attract should read as an unattended machine with nothing
  overlaying the field, but the affordance still needs to exist somewhere. *(See also the
  CLI handoff — this overlaps.)*
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

### Things to verify rather than assume

- **Stale GitHub issues.** `CLAUDE.md` lists #29, #30, #32, #34 as describing superseded
  behavior. Check whether they should be closed or rewritten now the design is settled.
- **Dev scaffolding.** The pause menu currently carries an act selector, `reset data`, a
  phosphor toggle, a CPU readout and a force-result item, plus `DEBUG_ACT`. Decide what
  ships. The act selector and reset may be worth keeping; force-result certainly isn't.
- **`ball_mode`.** `slow_fast` and `homing` are minimal working implementations so the axis
  is real rather than a stub. Depression (M15) owns tuning them — check whether M15 changed
  the semantics before documenting them.

---

## When done

- Remove the freeze notice from `docs/BUILD-PLAN.md` and empty its deferred table.
- Re-sync `docs/*.md` from the wiki so mirrors and source agree again.
- Record the new wiki commit hash, the way `2e419bc` is recorded above.
