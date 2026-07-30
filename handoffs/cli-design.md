# Handoff — CLI / terminal design session

**Standalone work item.** Everything needed to start is in this file. This is a *design*
session first and an implementation session second — the ideas are the user's, and this
document exists to give them somewhere to land, not to pre-empt them.

---

## Why this session exists

The terminal band was built to the minimum the narrative engine needed: text appears, it
scrolls, it goes away. During M7 and M10 the user repeatedly flagged wanting to do more
with it — enough that building elaborate behavior *then* would have meant building it
twice. The slide-open animation was cut for exactly this reason.

So the current CLI is deliberately plain, and this is where it stops being plain.

---

## What exists today

**Geometry.** Rows 96–127, a permanent 32-pixel band beneath the 128×96 playfield. It is
never occluded and gameplay never draws into it. This split is load-bearing: the playfield
is 128×96 because that is exactly 4:3, which is what preserves the original's return
angles. The band is what is left over, and it is not negotiable without redoing the
physics.

**Behavior.**
- Permanently open. No open/close states, no slide.
- 4 visible rows at 6 px line height; 3 completed rows retained plus the row being revealed.
- Letter-by-letter reveal at 1 character per 2 frames (~30 cps), blinking cursor at the
  write head.
- Word wrap at 31 columns; each wrapped row scrolls independently.
- **Continuous scrollback** — completed rows scroll up and fall off the top. Nothing is
  ever cleared, including between narrative Sections.
- Scanlines, phase crawl and the occasional tear apply to the text (it draws in the
  `C_SCORE` role, the only role whose darkened palette entry differs).
- `snd_type()` fires per revealed character and **plays nothing** — a real hook awaiting a
  human-authored sound.

**Constraints that are not up for grabs.**
- **No player advance or skip input.** Dialogue is fully automatic. This is a stated design
  rule, not an oversight.
- **Every line COM speaks is human-written.** The machinery is built; the words are not
  Claude's to write. Structural placeholders (`line 1`) are fine as a harness.
- **Characters are the binding budget.** 65,535 shared between engine code and all
  dialogue. The cart currently sits at ~30,400, so roughly 35k remains — and CLI features
  spend from the same pool the writing does.

**Relevant code.** `pong.p8`, the `textbox` object: `say()`, `wrap()`, `update()`, `draw()`,
`done()`, plus `TB_ROWS`, `TB_COLS`, `TB_REVEAL`, `TB_LH`. The narrative engine drives it
via `stage:update(tb)` calling `tb:say(text)`.

---

## Already parked, feeds into this

- **"Press any button to start" belongs in the terminal.** Attract should read as an
  unattended machine with nothing overlaying the playfield, but the affordance has to
  exist somewhere — and the terminal is where the machine already speaks. Currently there
  is no prompt at all on the attract screen.
- **A `>` prompt prefix was considered and not done.** It costs 2 of 31 columns on every
  row, and four stacked prompts read as four commands rather than one machine talking.
  Left plain deliberately, pending this session.
- **Reveal speed is a pacing value**, currently a guess that happened to land. Pacing is
  characterisation — too fast and COM is a printer, too slow and you are waiting on him.

---

## Questions worth answering here

Not prescriptive — a starting frame.

1. **What is the terminal, in fiction?** COM's voice, a machine's console, something the
   player could in principle type into? The answer shapes everything else, including
   whether a prompt character makes sense.
2. **Does it ever address the player directly** — prompts, status, the start affordance —
   or is it strictly COM speaking?
3. **Does its appearance change per act?** Colours already do. Does the *behavior* — reveal
   speed, glitching, corruption — track COM's state of mind across the five stages?
4. **Is there ever more than one voice in it?**
5. **What happens to it during attract?** Currently nothing is drawn. COM's last lines
   could linger — a machine still showing what it was saying when everyone left — or it
   could be empty because he has gone quiet.
6. **How much of the 35k character budget is this worth?** Every feature here is dialogue
   that does not get written.

---

## Suggested shape for the session

1. Talk through the questions above; write the answers into Game Design (or the Parking
   Lot for anything deferred).
2. Only then decide what to build.
3. Build it in small verifiable pieces with a "verify this" block each, per `CLAUDE.md`.
4. Anything visual needs a human eye — the headless harness can drive frames and check
   logic, but not how it looks.
