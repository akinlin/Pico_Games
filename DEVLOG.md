# Meta Pong — Dev Log

Raw material for a **making-of**, not an engineering log.

The eventual artifact is player-facing — something that could ship as a deluxe-edition
inclusion, a backer reward, or a marketing piece. Think *concept art book*: the journey
of the game's creation, told for someone who loves the game but will never read the
source. Its final shape gets decided when it's written; this file is the notebook it
gets written from.

**Collect:** the human arc. What we believed going in and how it changed. Things the
1972 hardware turned out to actually do. Ideas cut and why. Moments where the design
argued with itself. Constraints that shaped the game's feel rather than just its code.
Anything with a story, a reversal, or a surprise in it.

**Deprioritize** (true, but not the artifact): character counts, memory addresses,
function names, git mechanics. Where a technical detail carries the story — the machine
having no way to produce spin, or scanlines being physically finer than a pixel we can
draw — keep the *consequence* and let the implementation go.

Not a spec and not build status: `docs/` is the source of truth, GitHub issues and
`docs/BUILD-PLAN.md` track status.

Entries are roughly chronological. Started 2026-07-27 at the M0 rework. Present
entries lean engineering-heavy; later passes should correct toward the above.

---

## Recurring themes

**"You can't see it run" turned out to be half true.** The project rule was that every
behavioral claim is a hypothesis until the cart is launched by hand. That's still true
for behavior — but partway through M0 we found `pico8.exe -x pong.p8` loads the cart
headlessly and exits 0, surfacing syntax errors and load-time runtime errors before the
user ever sees them. It earned its keep immediately and repeatedly: during the M7a
cleanup it caught two runtime errors in a row (a half-deleted menu item, then two
globals accidentally swallowed by a slice) that a parse-only check would have missed.
It proves nothing behavioral — `_update60` and `_draw` never run — so the discipline
of "parses and loads clean, never 'works'" stayed.

**Headless PICO-8 as a calculator was the other big unlock.** Rather than reasoning
about fixed-point arithmetic on paper, we ran the actual numbers through the actual
interpreter. That caught things longhand would have missed:

- 16.16 overflow silently *wrapping to negative* (40,551 came back as −24,986)
- Confirming tier traverse times land at 4.32 / 2.15 / 1.43 s against a spec of
  4.3 / 2.1 / 1.4 — proving the fixed-point representation of 0.341 doesn't drift
- Comparing the new analytic AI prediction against a brute-force frame-by-frame
  simulation, agreeing within 1.1 px
- Measuring the paddle's zone distribution and finding a real bias (below)

Every one of those is a claim we'd otherwise have had to hand over as "should be fine."

**The spec was right more often than the code, but not always.** `docs/` won essentially
every disagreement — except where the docs disagreed with *themselves*, which happened
once and mattered a lot (see M6).

**Small verifiable increments beat big correct ones.** The rhythm that worked: plan
first, get a ruling on anything ambiguous, implement, run `-x`, hand over a concrete
"verify this" block with specific failure modes, then commit only after a human had
actually looked. Several milestones would have shipped subtle bugs without that.

---

## M0 — Cart upgrade and 60 fps migration

The plan said "switch `_update` to `_update60` and delete the `dt` machinery." That
part was mechanical. What wasn't in the plan were three consequences that fell out of
the frame-rate change:

1. **AI reaction times were in seconds.** The table held 0.2–1.8 compared against an
   accumulator fed by `dt`. With `dt` gone the comparison was meaningless; the values
   had to become frame counts (12–108).
2. **The AI prediction ray collapsed.** It was `ball.dx * 2` — meaning "two seconds of
   travel" when `dx` was px/sec. Per-frame, that became a 0.6 px ray that could never
   reach the prediction wall, and COM would have stopped moving entirely.
3. **Everything counted in frames silently doubled in speed** — paddles, dialogue
   timings, blink rates.

Lesson: a frame-rate migration isn't a frame-rate migration. It's an audit of every
number in the codebase for what unit it's secretly in.

Also of note: the build plan told us not to remove the player paddle's acceleration.
There wasn't any — the paddle moved at a flat speed. Raised rather than "fixed," and it
turned out to be an M8 item.

## M1 — Playfield geometry and the terminal band

The score placement bug is the fun one. Scores overlapped the net at double digits, and
the cause was that `\^p` is PICO-8's *pinball* mode — wide + tall + stripey — so each
glyph is **8 px wide, not 4**. The placement math had assumed 4.

Rather than eyeball a new position, `docs/reference-materials.md` turned out to record
the original hardware's exact score placement (left score at H 128–191, right at
H 320–383, symmetric about the net at H 256). Converting at 0.3413 px per clock put the
score fields 22–44 px either side of the net — a derived answer instead of a guessed one.

That also forced a small design call: `print()` is left-aligned, so with both scores
left-aligned a single-digit left score drifts further from the net than its counterpart.
Right-aligning the left score onto its inner edge keeps the pair symmetric at any digit
count, which is what the original did with fixed digit fields.

## M2 — Fixed-point ball and the three-tier speed model

Mostly smooth. The notable part was verifying the traverse times by simulation before
handing over, and being explicit that "paddle to paddle is 88 px, not the 128 px screen"
— timing wall-to-wall gives ~6.3 s at tier 1 and looks like a failure on correct code.
Writing the *wrong* measurement into the verify block was as important as the right one.

## M3 — The 8-zone return table

Deleted `apply_spin()`. The original paddle is an analog potentiometer with no velocity
signal anywhere in the circuit, so direction of travel at contact cannot affect the
return — spin was never in the machine.

A blocker was flagged going in: zone selection needs the ball's *center* against the
paddle's top edge, but `ball.y` was a top-left corner. It dissolved on inspection —
zone selection works entirely in collision space, where the model is self-consistent
(collision expands walls by the ball radius and treats `ball.y` as a center). The
draw/collide mismatch was real but purely visual, so it stayed deferred to M5 rather
than blocking M3.

Verified by simulation that the flat band is exactly 1.5 px of a 6 px face — the
"quarter of the paddle" the spec calls for — and that the vertical velocity table
reproduces the spec's separate angle table to rounding. Two tables that were asserted
independently in the docs turned out to be consistent, which is worth knowing.

## Comment strip (chore)

A budget question with a crisp answer. The manual's *Code Limits* section excludes
comments from the **token** count but they count in full against the **65,535
character** limit — which is the binding constraint, shared with every line of dialogue
COM speaks.

Measured: **5,871 characters, 17% of the code and 9% of the entire budget.** Stripped,
and the cart has carried no comments since; rationale lives in `docs/`, `CLAUDE.md` and
commit messages instead. The `-->8` tab separators look like comments and are not —
they're structural.

## M4 — Serve rules

The interesting mechanic: the ball keeps travelling and bouncing **invisibly** through
the ~1.7 s serve delay, so its height on reappearance is effectively arbitrary. That's
why the original's serve feels random, and it's reproduced deliberately.

Simulation across every vertical velocity and a spread of miss heights confirmed the
reappearance lands anywhere in 1.4–93.6 against bounds of 0–94. It also surfaced an
edge case worth documenting rather than "fixing": **if the point ends on a dead-flat
return (`dy = 0`), the ball reappears at exactly the height it left.** A flat ball
travelling flat for 1.7 s arrives where it started. Correct, and the one case where a
correct serve looks deterministic.

Also nice: "the ball is served toward whoever missed it" and "horizontal direction is
unchanged by a miss" are the same rule, which is easy to read as two. Preserving the
sign of `dx` gives it for free — no branch on who scored.

## M5 — Collision rework and the ball collection

The convention cleanup found a real bug. Under the old inclusive draw
(`rectfill(x, y, x+width, y+height)` paints `width+1` columns), the paddle's collidable
face was **5 units against a 6 px sprite**. The radius expansion therefore gave it an
overhang above its top edge and none below.

Measured across the contact span: zone 1 covered 1.80 units of contact range against
zone 8's 0.75. **The top rim returned steep-up 2.4× more often than the bottom rim
returned steep-down** — an asymmetry nobody would have found by playing, and which had
been silently shaping every rally since M3. Making logical size equal drawn size fixed
it; both rims now cover 1.75.

Verifying the *distribution* rather than just "does it return the right angle" is what
caught it.

## M6 — AI rework

**The docs contradicted themselves, and it mattered.** Game Design said COM
"weakens while losing and sharpens while winning, quietly keeping the match close."
Those two halves are incompatible — an AI that sharpens when ahead runs away with the
game. The sentence resolves only if "losing/winning" refers to the *player*.

Raised rather than resolved in code, per the project rule that Game Design is upstream.
The ruling came back as rubber-band (COM weakens as it pulls ahead), which is what the
cart had always done. Then grep found **two more places stating the opposite**, one of
which *reasoned from it* — Bargaining's note justified excluding the head start from
the balance calculation because spotting COM 10 points "would hand him maximum
sharpness." Under rubber-band it does the reverse. Four locations reworded; the rule
survived, its stated mechanism inverted.

Lesson: when a doc is ambiguous, grep for every restatement before acting on one
ruling. The majority of the prose was on the *other* side of the ambiguity.

Technically, this was the milestone where deferred debt paid off all at once. Replacing
segment-intersection prediction with closed-form
(`frames = (face - x) / dx`, `y = ball.y + dy * frames`) removed the prediction wall
entirely, which removed the only reason `intercept()` needed its ±140/−50 coordinate
clamps, which removed 8 comparisons per call from what will become the swarm's inner
loop. **First milestone to shrink the cart: 28,522 → 26,192 characters.**

It also fixed a behavior nobody had reported: the old ray was 120 frames of *travel*,
so it shrank with the ball — 41 px at tier 1 — leaving COM idle until the ball crossed
the net.

## M7a — Palettes and scanlines

The one milestone with no verification path. Headless PICO-8 doesn't render, and
`extcmd("screenshot")` writes nothing under `-x`, so the display behavior of the
undocumented scanline registers (`0x5f5f`, `0x5f70`–`0x5f7f`) could only be checked by a
human looking at a screen. Confirmed they're absent from the 0.2.7 manual, which the
project notes had already warned about.

**A structural consequence of display-palette recoloring:** it remaps stored pixel
values, so every element needs its own draw index. Paddles, net and ball were all
color 6 — indistinguishable to a remap, but Anger needs orange paddles against a white
ball. Everything moved onto role indices (bg / paddle / ball / score) with the per-act
table mapping roles to real colors.

**The scanline reality check.** The original playfield is 246 scanlines mapped onto our
96 rows — one Meta Pong pixel is ~2.56 original scanlines, so *a real scanline pair is
finer than a single pixel we can draw*. Any scanline we render is ~2.5× too coarse.
Scanlines here are necessarily stylization, not reproduction. Parked as a possible
player-facing option rather than pretending otherwise.

**The pullback.** The first version had full-screen alternating-line darkening at 50%
coverage, animated, on in every act. Feedback: eye strain, and plausibly a
photosensitivity trigger. That's a real accessibility problem and it should have been
weighed before shipping it as always-on.

The fix came from a better lever than the one we'd been using. The per-line hardware
darkens whole screen rows, so it *cannot* scope an effect to an element — the score sits
at rows 8–19, which the net also crosses. But the scanline palette only affects colors
whose darkened entry differs from their base. Setting `dark(bg) = bg`,
`dark(paddle) = paddle`, `dark(ball) = ball` and dimming *only* the score entry makes
scanlines physically incapable of touching the game area, whatever rows are enabled.
Since dialogue text already drew in the score role, one change scoped every effect to
exactly the two elements that should have them.

Final: 1/8 scan on score and dialogue text only, a slow crawl, and an infrequent
half-second tear. Game area is plain solid color.

**Two smaller finds.** A palette-contrast rule fell out of a bug where Bargaining's
score blinked out: it darkened `11 → 3` against a background that *is* `3`, so on dark
lines the score became the background exactly. The darkened palette has to preserve
*contrast*, not merely reduce luminance — and PICO-8 only has two greens, so some
colors can't darken at all.

And the score digits were dotted because `\^p` (pinball) includes stripey mode.
`\^w\^t` gives the same 8×12 dimensions solid — matching the machine's solid block
numbers.

**A tooling note:** a pause-menu tuning harness via `menuitem()` — live toggles for
density, crawl, tear, glow and act — was the single most productive thing built this
milestone. For anything only a human eye can judge, shipping the *options* and letting
the user compare beat any amount of describing them in prose. Glow and net drift were
both cut after a minute of looking at them; neither would have been settled by argument.

## M7b — Phosphor

What we're chasing here isn't a graphical effect so much as a physical fact: a CRT's
phosphor keeps glowing after the electron beam has moved on. On the original machine the
ball doesn't travel across the screen so much as it *smears* — a bright point dragging a
brief afterglow behind it. It's one of the reasons footage of real Pong looks alive in a
way a crisp emulator doesn't.

Two ways to fake it, and they turn out to be different design choices rather than
different implementations of the same idea. You can trail *the ball* — cheap, precise,
and it leaves everything else clean. Or you can blend the whole previous frame under the
new one, which is what an actual phosphor does: everything that moves glows, including
the score digits ticking over and the dialogue text as it types itself out. Built both.
The second is more honest to the hardware and possibly the nicer of the two, but the
verdict has to wait — the dialogue doesn't animate yet, so the thing most likely to make
full-frame blending unpleasant literally cannot be seen.

**The accident we kept.** In full-frame mode the previous frame gets stashed in unused
sprite memory. On the very first frame there's no previous frame — just whatever
leftover data happened to be sitting there — so the game opens on a flash of garbage
before the first real frame overwrites it. A bug, unambiguously. It also reads exactly
like an old machine warming up, so it stays.

**What the trail taught us about slowness.** The first version drew a tail behind the
ball at all times, and at the slowest rally speed it looked wrong in a way that took a
while to name. The tail wasn't too long — it was too *close*. A ball creeping along at a
third of a pixel per frame leaves its afterglow almost exactly where it already is, so
instead of a comet you get a slightly swollen ball. The fix was to let the trail vanish
whenever the ball hasn't travelled far enough to separate from it, which is also what
a real tube does: a slow-moving spot sits inside its own glow and simply looks brighter.
The smear needs the beam to have actually gone somewhere. So the effect now arrives with
speed and disappears in the slow, flat rallies — which is exactly when the original
machine looks calmest too.

**The cost of nostalgia, measured.** Blending the entire previous frame costs 29% of
everything the machine can do in a frame. Trailing just the ball costs 4%. Both look
good; only one leaves room for the moment, several acts later, when the screen fills
with balls. That act turns the glow off, and the design had always said so — but it's
a different thing to read that in a plan than to watch the number climb.

**The one-line bug that repainted the whole game.** Resetting the drawing palette after
compositing turned out to reset *every* palette, including the one holding the current
act's entire color scheme. The symptom was that full-frame mode ignored whichever act
you'd chosen and rendered everything in green-on-black — which, entirely by accident, is
about the most stereotypically "old computer terminal" pairing available. Briefly
tempting. Not what the act called for.

## M8 — The paddle that couldn't reach half of itself

The paddle moved two pixels at a time. That sounds like a detail about responsiveness.
It wasn't — it was quietly dismantling the most carefully built system in the game.

Every return angle in Meta Pong comes from *where* on the paddle the ball lands. The
face is six pixels tall, divided into eight bands three-quarters of a pixel wide, and
which band you hit decides where the ball goes. It's the whole reason the original
machine feels like a game of skill rather than a game of luck. We'd derived those bands
from the hardware, checked them against the original's angle tables, and confirmed they
were evenly reachable.

Except the paddle could only stop at every *other* pixel. Aiming at a specific band
meant putting the paddle at a specific height, and half the heights didn't exist. In
practice a player could reach about three of the eight bands.

It got stranger. The paddle started on odd-numbered positions and moved in twos, so it
stayed on odd numbers — until it hit the bottom of its travel, which sat on an even
number and knocked it permanently onto evens. Which positions you *could* reach depended
on where you'd been. There was no way to learn it, because it changed.

The report from playtesting was that the paddle "would skip certain locations so hitting
the ball on a certain point of the paddle couldn't be done in some cases." That is
exactly right, and it is the kind of thing that only surfaces from someone actually
playing. No amount of reading the code suggests it: every individual piece is correct.
The paddle moves at a sensible speed. The bands are the right width. The bug lives
entirely in the interaction between them.

The fix is that the paddle now has a real sense of momentum — it eases up from rest
instead of leaping, and it holds fractional positions rather than snapping to whole
pixels. A quick tap nudges it a fraction of a pixel; holding the button lets it build to
a sprint across the field in about three-quarters of a second. All eight bands became
reachable, and the aiming system that had been there all along finally turned on.

Two things worth remembering from this one. First, the tuning numbers came from
playtesting inside a minute — being able to adjust the paddle's response live, while
playing, found a good feel far faster than any amount of reasoning about acceleration
curves. Second, the ability to change that response *situationally* felt good enough
that it got written down as a possible feature rather than a setting. Some of the best
ideas arrive disguised as debug tools.

## M9 — The machine when nobody is watching

A real Pong cabinet was never off. Sitting in the corner of a bar at three in the
morning, it kept the ball in play against itself, bouncing off all four walls with no
paddles on the screen and the last customer's score still showing. That's attract mode,
and it's the first thing Meta Pong needs to look like a machine rather than a program —
you're supposed to walk up to something already running.

So the ball now plays alone until you touch a button. Any button: the original had no
menu to navigate, and neither does this. The screen carries nothing but the net, the
previous score, and a ball that doesn't need you.

**The ball that was there all along.** First attempt, the attract screen showed the net
and the score and nothing else. No ball. It turned out the ball had been bouncing
correctly around the field the entire time — every wall, every angle, perfectly — and
simply was never drawn. Somewhere between "it doesn't work" and "it works" there's a
category of bug where the thing is already right and you just can't see it.

**The bug that waited for permission.** Making *any* button start the game woke something
that had been asleep since long before this rework: a check that was supposed to ask "are
we on the start screen?" but, through a small slip, always answered yes. It meant that
pressing the start button *during a match* would quietly restart the match. Nobody had
ever noticed, because the start button was one you'd never press mid-game. The moment any
button counted, moving your paddle began resetting the ball. A latent bug can sit
harmlessly for years and then detonate the instant you widen the door.

**The game remembers you now.** Finish an act and it's written down; come back tomorrow
and you resume where you stopped. That's a small thing that quietly changes what the game
is — five acts is a lot to ask in one sitting, and a machine that remembers you is a
machine you can leave.

There's a footnote in the hardware here that decided which version of PICO-8 this game
targets. Older builds had a flaw where saving twice in quick succession would silently
lose the second save — exactly what happens when you win an act and the game writes both
your progress and your name. It's fixed in the version we build against, and confirming
that fix was the one thing in this whole project that could be tested completely, with
certainty, before anyone played it: write twice, quit, come back, look. It was still
there.

## M10a — What losing means

Losing used to mean the act simply started again. Correct, and completely inert: the ball
reappears, the score is zero, carry on. It's the response of a program, not of a
character — and this game's whole premise is that there's someone in the circuitry.

So now, when COM beats you, the machine goes quiet. The colours drain back to the black
and white it started in, the paddles disappear, and the ball goes back to knocking around
an empty field the way it was doing before you ever walked up. Your losing score stays on
the screen. Nothing invites you to play. It reads as a machine sitting idle — which is
precisely what it looked like at the start, before any of this began.

Press a button and he's exactly where you left him. Same act, same stage of grief, no
progress lost and none gained. He didn't reset. He just waited.

That's a two-line change to where the code goes after a loss, and it does more character
work than a paragraph of dialogue would.

**A detail that turned out to matter.** The first version froze the game for two seconds
after the final point so the score could be read, but left both paddles on screen. In
playtest that reads as broken — you keep tapping the button, because a paddle you can see
is a paddle you expect to move. The fix was to take them away. The field empties, the
score holds for a beat, and then the machine goes to sleep. Nobody has to be told the
match is over.

Somewhere in there is a general rule about interfaces: don't show someone a control you
have switched off.

## M10b — Three sounds nobody composed

The 1972 machine had no sound chip. It had no sound *anything* — there was no budget for
it and no obvious way to do it. What it had was a counter circuit tracking where the ball
was vertically, ticking away at audio frequencies as a simple consequence of counting
fast.

So they wired it to a speaker.

All three of Pong's sounds — the paddle hit, the wall bounce, the point scored — are taps
off that same counter, at different points. That's the entire sound design. It's why they
sit exactly an octave apart: not a musical decision, just two bits of the same counter,
one ticking twice as fast as the other. Nobody chose those notes. They were already there
in the circuit, and someone noticed they could be heard.

Reproducing them is therefore transcription rather than composition. The published
measurements give frequency and duration; the waveform follows from what a counter tap
physically is. The only genuinely invented number in all three sounds is how loud they
are.

There's something worth keeping in that. The most recognisable sound in video game
history — the one everybody can still make with their mouth — is a side effect. It exists
because a circuit that was doing something else happened to be audible, and somebody was
paying attention.

## M10c — Giving the machine a voice

A quarter of the screen has been sitting empty since early on. Not wasted — reserved. The
playfield is the top three quarters, sized so the ball's angles come out exactly as they
did in 1972, and the strip underneath belongs to COM. It's the one part of the display
that isn't a reconstruction of anything; it's the part where the machine talks back.

It works like a terminal, because that's what it should feel like: something typing at
you in real time rather than presenting you with finished sentences. Characters appear
one at a time with a cursor blinking at the end. Lines that run long wrap and keep going.
Completed lines scroll upward and eventually off the top, gone.

Two decisions shaped it, and both were about taking things away.

The original plan had the window slide open and closed as COM started and stopped
talking, with the scrollback wiped clean each time. We dropped both. The window is simply
always there, and nothing is ever cleared — old lines just drift up and out as new ones
arrive. It reads much more like a machine that has been running the whole time, which is
the thing the game keeps insisting on: COM was always in there. A window that appears when
he speaks implies he arrives when he speaks.

The other was refusing to build the slide animation at all, once we knew it was going. The
plan called for it, the spec described four states and a motion path, and it would have
been perhaps forty minutes of work — to then delete. Writing the code you know you'll
throw away is a habit that feels like diligence and is just cost.

**Pacing is characterisation.** How fast the words appear turns out to matter more than
almost any individual line. Too quick and COM is a computer printing output. Too slow and
he's laboured, or worse, you start waiting on him. The current speed is about thirty
characters a second, which reads as someone typing quickly and thinking as they go. That
was a guess that happened to land, which is not the usual outcome.

## M10d — Teaching the machine to talk

The last piece of scaffolding. Everything before this built the room COM speaks in; this
built the part that decides what he says and when.

Three things a talking character needs that a scrolling text box doesn't give you.

**Timing that isn't uniform.** A line that lands needs air after it; a throwaway remark
shouldn't sit on screen waiting to be admired. So every line carries a hold — short,
medium or long — counted from the moment it *finishes* typing rather than from when it
starts. That distinction matters more than it sounds: measured from the start, a long
line eats its own pause and the rhythm collapses exactly where you wanted emphasis.

**Reacting to the game rather than to a clock.** COM's opening depends on you scoring
twice while the second paddle sits unmanned. That isn't a timer, it's a thing he notices.
Each act gets a hook that runs every frame and can watch whatever it likes — the score,
the ball, how badly you're losing — and interrupt whatever he was saying. Denial's already
does it: your second point, and mid-sentence he takes the paddle and quietly resets the
score to nothing.

**Being able to lose.** Up to now the dialogue ran one path from start to end. Now the
outcome of the match chooses an ending. Win and he has a line about how good he is at
this. Lose and he has a different one.

That last one produced the tidiest bug of the session. The win and lose lines were simply
the sixth and seventh sections of the act — so once he'd finished his fifth, he cheerfully
carried on into *both* endings while you were still playing. He'd announce he'd won,
then that he'd lost, then go quiet.

The fix was to stop treating an ending as "the next thing." Endings sit outside the
sequence entirely and are reachable only by the match deciding to go there. It's now
structurally impossible to wander into one, which is the right shape for the idea: an
ending isn't a later part of the conversation, it's a different kind of thing.

**And he gets the last word.** Winning used to freeze the field for two seconds and move
on. Now the field clears, COM says his piece about it, and only then does the game
advance. The transition waits for him to finish. It costs nothing and it changes who the
pause belongs to.

## M11 — Three letters

Winning the whole thing earns you three characters. Up and down to pick a letter, left
and right to move, one button to commit. No keyboard — the game runs on handhelds and
phones where there isn't one, and a Pong cabinet wouldn't have had one anyway.

Three characters because that's how long the names COM gives you are. Through the middle
acts he stops calling you nothing and starts calling you something: DUM, then SKR, then
WHR, then PLR. Names assigned to you by a machine that has decided what you are. Win the
last act and you replace all of them with three characters of your own, and that's the
one that stays on the front of the cabinet.

The whole exchange is a high-score table with a single row, which is exactly what the
original had.

**The bug that froze the game.** Finishing the run, entering a name, and starting again
would leave the game running but not *playing* — COM talked away happily while the ball
sat still and the paddle ignored you.

The cause was that finishing a match sets a flag saying who won, and the code that
handles the ending forgot to clear it on one particular path — the path that only exists
after the final act. So the game finished, went to name entry, came back, started
Denial... and then immediately noticed there was still a winner recorded, concluded the
match had ended, and froze the field to play the ending again. Every frame. Forever.

It's the sort of bug that reading the code doesn't find, because every individual piece is
correct. What found it was being able to *run* the game headlessly — start it, force a
win, step through six hundred frames, and print what the machine believed about itself.
It reported the stuck flag in about a second, having spent a few minutes failing to spot
it by eye.

That turned out to matter beyond this one bug. The rule at the start of this project was
that nothing about behaviour could be checked without a human playing it. That's now
false twice over: the cart can be loaded to catch errors, and the game can be driven frame
by frame to catch broken logic. What still needs a person is everything about how it
*feels* — which, it turns out, is most of what matters.

---

## Running notes for the post-mortem

- Engine footprint over time: 32,653 (pre-M0) → 33,822 (M2 peak) → 27,951 (post comment
  strip) → 26,192 (M6, smallest) → 28,273 (M7a). Ceiling is 65,535, shared with dialogue.
- The five things simulation caught that review wouldn't have: fixed-point overflow
  wrapping, tier traverse timing, zone distribution bias, analytic-vs-simulated
  prediction agreement, serve-height spread.
- The one thing simulation *couldn't* touch: anything visual. M7a needed a human every
  single round.
- Deferred debt that paid off: `ball.y` conventions and the `intercept()` clamps were
  both carried for three milestones with a written reason, then removed in one pass when
  the milestone that owned them arrived. Writing down *why* something was deferred, with
  measurements, made the eventual removal a five-minute decision.
