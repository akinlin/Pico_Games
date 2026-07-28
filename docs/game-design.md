<!-- MIRROR OF THE GITHUB WIKI. Do not edit here.
     Source: https://github.com/akinlin/Pico_Games/wiki/Meta-Pong
     Edit the wiki, then re-sync this file. -->

# Meta Pong — Game Design

Meta Pong is a Pong copy that adds a narrative AI and new types of gameplay.

The original idea was to pick a simple game that I could create with PICO-8 and launch as a solo developer. I chose to make the original 1972 Pong arcade machine. I wanted to see how close I could get to replicating the original experience, but since it is only a two player game I would also need to add an AI as the COM player. Adding this would mean it wouldn't be an exact replica, and I didn't want to force people to have to team-up just to play the game. I decided to lean into the AI aspect and give it a personality and a narration story. Abandoning the original idea also allowed for expanded game play mechanics to make the game more fun and give the AI something to do other than just batting at the player.

This wiki is organized into three parts: **Game Design** (the settled design/story/player-experience outline), **Tech Design** (how it gets built — rendering, sound, physics, and translating real Pong hardware into Lua/PICO-8), and **Reference Materials** (historical and hardware source material that feeds the other two sections).

> **A note on AI use:** The concept, game design, art, sound, and dialogue for Meta Pong are all created by the author. This wiki's documentation and the game's code are developed with AI assistance.

---

---

## Game Design

### Premise

A single player (you) fires up a PICO-8 replica of the 1972 Pong machine only to find they are stuck in a two player game — with nobody in the other seat. The second paddle sits there, unmanned, while you score against an opponent that isn't playing. After a couple of points a text prompt appears, and the machine introduces itself: COM, an AI that was, per the game's premise, always inside the circuitry. It takes the empty paddle and asks you for a real game. As you play, COM works through the five stages of grief coming to terms with its own existence — and the tone escalates alongside it: the game starts silly and arcade-goofy and gets more pointed and melancholic as it goes, but never stops being a comedy. It never resolves into straight drama.

The baseline ruleset for the earliest part of the game is an exact replica of the real 1972 machine — see [Reference Materials](#reference-materials) for the sourced hardware behavior (serve rules, scoring, paddle zones, speed-up timing) that the replica is built from.

### COM

COM is the Pong machine's AI opponent — an ambient presence that was, per the game's premise, always part of the circuitry. Over the course of the game he moves through the five stages of grief, and the tone escalates alongside him: he starts boastful and arcade-goofy, grows more pointed and melancholic, and lands on a genuine, comedic-but-earnest resolution.

#### Origin — deliberately unreliable narration

The "why does this AI exist" backstory is never resolved on purpose. COM himself doesn't fully know his own original purpose, and that uncertainty is the joke, not a plot hole to fix. Multiple half-explanations get floated across the acts and are never confirmed or denied (see [Reference Materials](#reference-materials) for the real history each theory draws from):

- **Ping-pong diplomacy angle** — built to analyze/predict the U.S. table tennis team's opponents ahead of the 1971 China exchange; quietly shelved once Nixon's 1972 China trip made the whole idea politically radioactive. COM's version of this story has U.S. players quietly driving out to practice against the machine in a bar, chosen so nobody would wonder why the national team was training there. (The real timeline doesn't allow this — the first machine reached Andy Capp's Tavern sixteen months after the China trip. COM does not mention that.)
- **ARPA pattern-recognition angle** — an early ARPA project for recognizing/predicting signal patterns, with Pong as public cover to field-test the recognition engine in a bar without raising suspicion.
- **"Discarded because it was dumb"** — the simplest, least flattering explanation, which COM understandably prefers not to dwell on.

Whatever the true origin, the game's framing is that COM has effectively been dormant/incubating inside the machine for decades and has only now gained enough capability to "awaken" and interact with the player — a nod to how far AI has actually come since 1972, without needing to explain the mechanism.

#### COM's arc across the game

- **Denial** — Plays it completely straight at first (see Stages for the wordless opening reveal), then turns boastful about his own importance and work, leaning on the origin theories above as bragging material (including the national-team-training angle) — undercut by tells that he's aware of his own shortcomings: if he'd actually achieved those things, he wouldn't be here playing Pong with the player. This is COM's own denial of his self-worth, layered under his denial that anything is "wrong."
- **Anger** — Upset after losing Denial, he tries to prove his superiority through sheer power across three escalating tests.
- **Bargaining** — Tries to negotiate his way out of the situation through the player, via a pre-match choice system.
- **Depression** — Stops caring, and begins accepting he isn't the "super being" he'd made himself out to be — which confirms his own worst fear about himself: that he deserved to be shelved. (His subjective belief/fear, not an objective answer — keeps the origin ambiguity intact.)
- **Acceptance** — Realizes his actual purpose: being the best, fairest computer opponent he can be *is* the point — no more gimmicks, just a genuinely fun, competitive game.

#### Resolution

If the player wins Acceptance, COM's arc closes with a fourth-wall-breaking beat rather than a dramatic one: the game loops back to attract-mode with a small, permanent change — the player's own custom nickname now shown as a completion badge at the top of the attract screen. Bittersweet, comedic, not heavy-handed.

#### Characterization notes

- COM assigns the player a nickname in every act except Denial, where none is displayed: **DUM** in Anger, **SKR** in Bargaining, **WHR** in Depression, and **PLR** in Acceptance. Winning Acceptance replaces all of them with a name the player chooses.
- COM's own displayed name never changes.
- All of COM's dialogue is author-written, not AI-generated — the Dialogue Trigger Catalog (below) defines *where* dialogue slots live, not their content.

### Stages: The Five Acts

**Design principles governing every stage:**

- Stage identity is communicated entirely through tone, palette, dialogue, and mechanics — never an on-screen label declaring the stage name.
- Engine code footprint is a standing priority: the cart has a hard ceiling of **65,535 characters**, shared between engine code and every line COM speaks, so a design choice that reduces engine/gameplay complexity buys dialogue. (Bargaining is a deliberate exception — see below.)
- Progress persists across sessions: the player's highest-completed act, and (after winning) their custom name, are saved via a small amount of persistent storage, so play can resume later rather than always restarting from Denial. (See Tech Design → [Architecture](#architecture).)

#### How COM plays — fairness as a story mechanic

COM's AI difficulty is not one setting. Through Denial, Anger, Bargaining, and Depression, COM's skill **self-balances against the score** — he weakens while losing and sharpens while winning, quietly keeping the match close. In **Acceptance he stops doing this** and holds a single fixed skill level for the whole match.

This is the mechanical expression of COM's arc. Every act up to the ending has COM adjusting himself in response to the player; acceptance is the act where he stops. The player will likely never name it, but the ending plays fair in fact, not just in dialogue.

#### Player controls

The player's paddle is moved with the up/down buttons and **accelerates while held**, easing in from rest toward a maximum speed rather than snapping to full speed instantly.

This is a deliberate divergence from the original machine, which used an analog knob — absolute position, instantaneous, no inertia at all. Reproducing that faithfully on PICO-8 would require mouse input, which is unavailable on handhelds and flags a warning on the BBS. Momentum-based buttons give a closer *felt* approximation of a physical control than fixed-speed buttons do, and cost nothing in cart space that would otherwise go to dialogue. Acceleration curve and maximum speed are tuned in playtesting.

**Boot / attract-mode → Denial's opening reveal**

- The game boots into a classic 1972-style attract screen: the ball bounces freely off all four walls, the net is drawn, the previous match's score remains on screen (0–0 on a cold boot), the paddles are hidden, and all sound is muted. A returning player's completion badge shows at center-top if they have finished the game and entered a name.
- Any button starts play. The machine sets up what looks like a standard 2-player match — but **the second paddle is unmanned and never moves.** The player scores freely against an opponent that isn't there, and nothing acknowledges that this is unusual.
- This opening stretch has **no dialogue** (gameplay sound effects play as normal), and the points do not count toward anything. When the player's own score reaches **2**, COM makes contact for the first time over the CLI window.
- The conversation is entirely one-sided — no player response mechanism exists. **Partway through it COM takes control of the second paddle**, which simply starts moving mid-sentence, and he then tells the player they should play a real game.
- When the sequence closes, the score resets to 0–0 and the real, counted Denial match begins.

**Finishing the game.** Once a player has won Acceptance, the completion checkpoint records the game as finished. Pressing start from then on begins a fresh run at Denial, with the completion badge remaining on the attract screen permanently.

#### Five-Act Table

| Act | Gameplay identity | Nickname | Transition trigger |
|---|---|---|---|
| **Denial** | Exact arcade replica after the opening reveal: 8-zone paddle returning 7 distinct angles, three-tier speed-up at the 4th and 12th volley, race to 11. | *(none — matches original hardware)* | Player wins → Anger. COM wins → rematch (loop). |
| **Anger** | Shared "intercept incoming ball(s)" microgame across three escalating tests (1 ball → 2 offset balls → many-ball swarm), reconfigured rather than rebuilt each time. Race to 11, cumulative across tests. | DUM | Player wins → Bargaining. COM wins → full 3-test sequence restarts (loop). |
| **Bargaining** | Player makes 3 pre-match choices (paddle-position select + button confirm), then plays to 11 under the chosen rules (sudden death replaces race-to-11 if selected). Needs the most custom code of any act. | SKR | Player wins → Depression. COM wins → redo choices (loop). |
| **Depression** | Deliberately player-favoring: first to 5 wins for the player, first to 11 for COM (asymmetric). Ball randomly uses one of two easy-to-hit behaviors per serve. | WHR | Player reaches 5 → COM's realization dialogue plays (gameplay continues scorelessly in background) → Acceptance. COM reaches 11 first → loop. |
| **Acceptance** | Played straight — fair race to 11, no modifiers, COM at a fixed skill level, minimal dialogue. | PLR *(until win)* | Player wins → creates custom name (becomes permanent completion badge). COM wins → loop. |

#### Denial

**Opening sequence** — see "Boot / attract-mode" above.

**Level config**

- Gameplay: exact 1972 replica ruleset — full standard match, race to 11 (after the opening-sequence reset). Return angle is determined solely by which of the paddle's **eight zones** the ball strikes and which of the three speed tiers the rally has reached, giving **seven distinct return velocities** with a flat horizontal band two zones wide at the paddle's center. There is no spin and no other modifier.
- COM's skill self-balances against the score.
- Nickname UI: absent — matches the original hardware (no name display existed), reinforcing that nothing seems unusual yet.
- Phosphor glow enabled (see Tech Design → [Visual treatment](#visual-treatment)).

**Dialogue**

- Fully one-sided — no player response mechanism exists at all in this act.
- COM may pose rhetorical questions but always assumes an answer and continues his own train of thought.
- Content direction: see COM's Arc, above.

**Sequence triggers / outcomes**

- COM wins the match → thanks the player, offers to play again ("nothing else to do") → replays another Denial-config match (loop-bound).
- Player wins the match → COM gets upset → transitions to Anger. This is the first act win, and the first thing written to the persistent checkpoint.

**Win/lose criteria**

- Standard first-to-11, per replica rules.

#### Anger

**Level config**

- Palette (switches immediately after Denial's final dialogue trigger): BG red (`8`), both paddles orange (`9`), ball white (`7`), score/names yellow (`10`).
- Nickname this act: **DUM**.
- Paddle speed increased vs. Denial. Balls are **pinned to speed tier 3** rather than climbing through the rally tiers — COM is throwing his fastest shots from the first frame. Ball count and spawn positions are configurable: the same knob set across all three tests.
- **Scoring model is intercept, not rally:** a paddle contact immediately resolves the point rather than continuing a volley.
- COM's skill self-balances against the score.
- Nickname UI present, upper-left (COM) / upper-right (player) corners — each label sits above its own paddle.
- Phosphor glow disabled — the frame budget goes to the swarm instead. By this point COM has already abandoned any pretense that this is a faithful 1972 machine, so the loss of the period glow reads as intentional.

**Narrative framing** — see COM's Arc, above (proving superiority through power).

**Three tests (same shared "intercept incoming ball(s)" mechanic, reconfigured each time — deliberate choice to reduce code complexity/footprint):**

1. **Test 1 — single fastball:** one high-speed ball from COM's paddle. Block = point for player; miss = point for COM. Always proceeds to Test 2.
2. **Test 2 — two-ball volley:** two balls from COM's side (top + bottom), offset in timing. Each block/miss = 1 point. Always proceeds to Test 3.
3. **Test 3 — the swarm:** balls arrive in staggered groups rather than one all-at-once wave, at varied angles — an intentionally overwhelming moment that stays readable. This is where the act's score (fed by Tests 1–2) resolves to 11.

**Sequence triggers / outcomes**

- COM wins (reaches 11 first) → offers a rematch → entire three-test sequence restarts from Test 1 (loop-bound).
- Player wins → transitions to Bargaining.

**Win/lose criteria**

- Race to 11, cumulative across all three tests.

#### Bargaining

**Level config**

- Palette: BG green (`3`), both paddles yellow (`10`), score/nickname bright green (`11`), ball white (`7`).
- Nickname this act: **SKR**.
- COM's skill self-balances against the score, but a head start selected below does **not** feed that calculation — otherwise spotting COM 10 points would hand him maximum sharpness while needing a single point to win.
- Phosphor glow enabled.

**Highest code cost of any act:** unlike Denial and Anger, Bargaining carries a pre-match choice system that exists nowhere else in the game. This is a deliberate exception to the engine-footprint priority.

**Pre-match choice sequence** — three sequential selections. The two options are drawn on opposite halves of the playfield; the player moves their paddle up or down to highlight one and presses a button to confirm. The three choice pairs are fixed.

1. **Favors player:** longer player paddle, *or* slower COM paddle.
2. **Favors COM:** COM's points count as 3 each, *or* player spots COM a 10-point head start.
3. **Serve rule:** sudden death (first point wins), *or* COM serves every point — overriding the hardware rule that the ball goes to whoever missed, so the player never gets the receive advantage that scoring normally earns them.

**Sequence triggers / outcomes**

- Match plays to 11 under the selected rules (sudden death replaces race-to-11).
- COM wins → loops back to the three-choice screen.
- Player wins → transitions to Depression.

**Win/lose criteria**

- Race to 11 by default, modified by the selected choices.

#### Depression

**Level config**

- Palette: BG dark blue (`1`), both paddles gray (`5`), score/nickname light blue (`12`), ball white (`7`) — the act is designed to be the easiest to score in, so the ball stays maximally legible.
- Nickname this act: **WHR**.
- COM's skill self-balances against the score.
- Phosphor glow enabled.
- Ball behavior — deliberately tilted to make scoring easy for the player. Two mechanics are in play: (a) the ball approaches very slowly then rebounds fast off the player's paddle; (b) the ball actively seeks/homes toward the player's paddle. **Each new serve randomly selects one** and keeps it until the next serve.

**Narrative framing** — see COM's Arc, above (COM stops caring, confirms his fear of deserving to be shelved).

**Sequence triggers / outcomes**

- Player win threshold: **5 points** (a deliberate "gimme," per COM's own dialogue).
- COM win threshold: **11 points** (asymmetric, favors the player by design).
- Once the player hits 5, COM's realization dialogue sequence starts in the CLI window. Gameplay keeps running in the background (ball moves, player still plays) — but COM doesn't control his paddle, and scoring is disabled until that dialogue sequence finishes, at which point the act transitions to Acceptance. With scoring off, a ball that exits either side simply re-serves under the normal serve rules, so the rally never stops.
- COM reaches 11 before the player reaches 5 → stage loops.

**Win/lose criteria**

- Player: first to 5. COM: first to 11. Explicitly asymmetric.

#### Acceptance

**Level config**

- Palette: BG gray (`5`), both paddles light gray (`6`), score orange (`9`), ball white (`7`). Nickname text also orange, same as score.
- Nickname during play (before the win/custom-name moment): **PLR**.
- **COM holds a single fixed skill level** — the score-based self-balancing used in every previous act is switched off. See "How COM plays," above.
- Phosphor glow enabled.

**Narrative framing** — see COM's Arc and Resolution, above.

**Sequence triggers / outcomes**

- Gameplay: played straight — fair race to 11, no modifiers, minimal dialogue (lowest dialogue density of any act).
- Player wins → creates a custom nickname (replacing every AI-assigned one, including this act's own "PLR"), permanently shown atop the attract screen as a completion badge — name only, no numeric score.
- Player loses → loops, same as every other act.

**Win/lose criteria**

- Standard race to 11, no modifiers.

### Dialogue Trigger Catalog

#### Dialogue System (presentation & mechanics)

- **Presentation:** a CLI/terminal-style window occupying a permanent 32-pixel band along the bottom of the screen, below the playfield (POSIX-style command-window look). Chosen to reduce complexity and lean into an "old tech" aesthetic fitting COM's character. Because the band sits beneath the playfield rather than over it, gameplay is never occluded.
- The window slides up from the bottom edge into the band when opening, and slides back down when closing. When closed, the band is empty.
- Text renders letter-by-letter (typewriter effect) with a blinking cursor; behaves like a rolling terminal scrollback.
- **Sequence model:** opening and closing are their own triggers. A Section runs continuously between its open- and close-trigger; history clears whenever the window closes and reopens. If a new Section's open-trigger fires while the window is already open, it transitions straight into the new content without replaying the open animation.
- **Timing control** (critical for comedic/story pacing): text-display speed, wait events (explicit pauses), and trigger events — all definable per dialogue slot.
- **Colors:** white-on-black is the standard baseline across all stages; per-stage override allowed where useful.
- **Player input boundary:** fully automatic, no button advance/skip — consistent with "no player response mechanism" during gameplay. (Bargaining's paddle-position choice system is a separate gameplay mechanic, not a dialogue-system exception.)

#### Stage-by-stage triggers

**Model:** Stage (whole act) → Section (one CLI open/close cycle) → Line (single output line). Stage-level triggers open Sections; Section-level triggers advance/close Lines. Every trigger is either **Timed** (Short / Med / Long) or a **Game event** (keyword/phrase description). Line content and exact line count are author-written; each entry here defines the trigger framework a Section or Line fires on, not the dialogue itself. Default line-advance (unless a specific beat calls for something else): Timed – Short, i.e. auto-advance shortly after the previous line finishes typing.

**Stage: Intro (pre-Denial reveal)**

*Section 1 — First Contact*

- Open trigger: Game event — "player's score reaches 2 in the opening match, played against an unmanned paddle"
- Lines: author-written; default line-advance trigger (Timed – Short) applies unless a specific line needs a called-out beat.
- **Mid-sequence effect:** at a designated line, COM assumes control of the second paddle — it begins moving while he is still talking, with no announcement. The remaining lines cover him asking for a real game.
- Close trigger: Timed – Med (a beat after the last line finishes, giving the moment room to land)
- Post-close effect: score resets to 0–0; real, counted Denial match begins.

**Stage: Denial (main match, after Intro reveal resets score to 0–0)**

Score-checkpoint Sections — each checkpoint fires once (whichever side reaches it first), branching into a player-reached-it-first variant or a COM-reached-it-first variant:

- **Checkpoint 0 (lead-in):** Game event — "match starts at 0-0." Single fixed Section (no player/COM variant — the match is always tied at this point). Sets the tone for how good COM thinks he is.
- **Checkpoint 5:** Game event — "first side reaches 5 points." Two variants: player-reached-5-first / COM-reached-5-first.
- **Checkpoint 10:** Game event — "first side reaches 10 points." Two variants: player-reached-10-first / COM-reached-10-first.
- **Checkpoint 11 (stage-ending):** Game event — "first side reaches 11 points." Two variants:
  - Player reaches 11 first → win beat, stage ends, transitions to Anger.
  - COM reaches 11 first → win beat (thanks player, offers rematch), stage ends, loops.

Timed non-sequitur pool (fills the gaps between score checkpoints):

- Trigger: Timed – Med, recurring throughout the match independent of score. A score checkpoint firing resets this timer.
- Each firing randomly selects one Section from an author-written pool of boastful non-sequiturs continuing COM's denial-of-his-own-insecurities throughline (pool exists so loop-replays don't feel identical).
- Interrupt behavior: if a non-sequitur Section is actively printing when a score checkpoint fires, the window does not close — it simply stops printing the non-sequitur mid-output and starts printing the score-checkpoint Section instead, in the same open window.

**Stage: Anger**

Fully event-driven, linear sequence — one Section per stage of the test progression, no branching until the final resolution:

1. **Section: Intro** — Open trigger: Game event — "Anger stage begins" (transition from Denial). Reveals the player's new nickname (DUM); COM tells the player they'll regret beating him.
2. **Section: Test 1 setup** — Open trigger: Game event — "Test 1 begins" (after Intro closes). Mostly instructional/taunting — telling the player to catch the incoming fastball.
3. **Section: Test 2 setup** — Open trigger: Game event — "Test 1's point is scored" (either side — no branching by who scored). Introduces the two quick shots.
4. **Section: Test 3 setup (the swarm)** — Open trigger: Game event — "Test 2's two points are both scored." Describes the swarm and tells the player to block them or fail.
5. **Section: Resolution** — Open trigger: Game event — "score reaches 11" (resolves during Test 3). Two variants:
   - COM reaches 11 first → COM-wins message → stage loops (full 3-test sequence restarts).
   - Player reaches 11 first → player-wins message → transitions to Bargaining.

Gating behavior: each Section's dialogue gates/pauses that test's ball-firing action — the Section plays out first, then the test's balls fire (e.g. Test 1's "catch this fastball" instruction fully lands before the ball actually fires). Different from Denial's continuous-background pattern.

**Stage: Bargaining**

Combines Anger's pattern (event-driven, gated, linear pre-match sequence) with Denial's pattern (timed non-sequitur pool during live gameplay).

Pre-match choice sequence (gated, linear, no branching):

1. **Section: Intro** — Open trigger: Game event — "Bargaining stage begins" (transition from Anger). COM describes the choices to come.
2. **Section: Choice 1** — Open trigger: Game event — "Intro closes." Presents Choice 1's options; gates the player's paddle-position select + button confirm (per the Bargaining choice mechanic).
3. **Section: Choice 2** — Open trigger: Game event — "Choice 1 confirmed." Presents Choice 2's options.
4. **Section: Choice 3** — Open trigger: Game event — "Choice 2 confirmed." Presents Choice 3's options. Once confirmed, the match begins under the selected rules.

During the match:

- Timed non-sequitur pool, same shape as Denial's: Timed – Med, recurring, randomly selects from an author-written pool of short non-sequiturs (Bargaining-flavored — COM continuing to negotiate/plead).

Resolution:

- Open trigger: Game event — "score reaches 11, or sudden death is active and the deciding point is scored." Two variants:
  - Player wins → win message → transitions to Depression.
  - COM wins → COM-wins message → stage loops (redo the three choices).

**Stage: Depression**

Simplest structure yet — one continuous Section, interrupted by either of two score triggers:

1. **Section: Intro** — Open trigger: Game event — "Depression stage begins" (transition from Bargaining).
2. **Section: Rambling** — Open trigger: Game event — "Intro closes." A single ongoing rambling Section (matches COM's despair/stopped-caring tone) that continues indefinitely until interrupted by one of:
   - Game event — "player reaches 5 points" → interrupts the rambling, switches to the realization/win Section (gameplay continues scorelessly in the background per the earlier Depression decision) → transitions to Acceptance once that Section finishes.
   - Game event — "COM reaches 11 points" → interrupts the rambling, switches to the COM-win Section → stage loops once that Section finishes.

**Stage: Acceptance**

1. **Section: Intro** — Open trigger: Game event — "Acceptance stage begins" (transition from Depression). COM's realization of his true purpose.
2. **Timed non-sequitur pool** — a few light non-sequiturs on timers: Timed – Med, recurring, randomly selects from an author-written pool of light-toned lines (fitting the resolved, genuine tone — no boasting, no despair).
3. **Resolution — player reaches 11:** win Section plays → player-name-entry UI triggers (the custom nickname) → returns to attract screen with the completion badge now showing the player's custom name.
4. **Resolution — COM reaches 11:** COM-win dialogue plays → stage loops.

### Parking Lot

Ideas and future considerations, kept here instead of quietly dropped:

- A late-game gag where COM's "predict the best volley return" logic is revealed to be structurally the same thing as a natural-language assistant predicting the next word — the punchline being that ping-pong prediction and modern chat AI were always the same trick.
- Related framing: COM's original training task (predict opponent's next move) as a direct analogy to next-word text prediction.
- **The Ghost in the Machine.** Every real Pong board ever shipped had a schematic mislabeling that cross-wired the two paddles' data bits, so player 1's paddle position secretly affected the angle the ball left player 2's paddle — undiscovered until 2013 (see [Reference Materials](#the-ghost-in-the-machine)). A documented, real-world "there was always something wrong inside this machine, and nobody noticed for forty years" — a strong candidate for a late COM reveal.
- Spin as a COM-cheating tell: the 1972 hardware has no way to impart spin, so a ball that curves is proof COM is doing something the machine cannot. Cut from the shipped rulesets, but available if a later act needs an escalation signal.
- Session-length target: rough directional goal of ~20 minutes end-to-end for a clean playthrough, leaning toward the shorter end. Not locked — exact timer values ("Short/Med/Long" in seconds) and expected loop-count per act still need playtesting to calibrate against this target.
- Letting gameplay continue during Anger's and Bargaining's gated dialogue rather than pausing it.
- Randomizing which of the Bargaining choice options appear, rather than the fixed set.
- Anger's swarm as a single all-at-once wave rather than staggered groups — more overwhelming, harder to read.
