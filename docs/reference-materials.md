<!-- MIRROR OF THE GITHUB WIKI. Do not edit here.
     Source: https://github.com/akinlin/Pico_Games/wiki/Meta-Pong
     Edit the wiki, then re-sync this file. -->

# Meta Pong — Reference Materials

## Reference Materials

*Historical and hardware source material — this is where facts get sourced from, not where design decisions live.*

### Background

Computer Space, the first coin-operated arcade video game, was designed by Nolan Bushnell and Ted Dabney under their Syzygy partnership and manufactured by Nutting Associates in 1971. It sold around 1,300 units — a commercial disappointment, but enough to convince its creators there was an industry here. In 1972 the pair founded Atari, and Bushnell hired Allan Alcorn to build a TTL circuit board intended as a training exercise for a developer he expected to need on real projects later. The game Alcorn produced turned out to be genuinely fun, and Bushnell and Dabney decided to market it instead.

![1972 Pong Arcade Machine](https://upload.wikimedia.org/wikipedia/commons/thumb/3/32/Signed_Pong_Cabinet.jpg/500px-Signed_Pong_Cabinet.jpg)

### Tidbits

- Syzygy was the name of Bushnell and Dabney's original partnership. The name was already claimed when they went to incorporate, so Bushnell chose Atari instead — making Pong the first game released under the Atari name (a possible tie-back for the AI backstory: Syzygy as a shell for the original project).
- Alcorn hired a teenage Steve Jobs at Atari in 1974. Alcorn himself later became an Apple Fellow.
- In May 1972, Bushnell had visited the Magnavox Profit Caravan in Burlingame, California where he played the Magnavox Odyssey demonstration, specifically the table tennis game. Though he thought the game lacked quality, seeing it prompted Bushnell to assign the project to Alcorn. (Magnavox had the game idea/mechanics first — a subsidiary of Philips, a Dutch company. Bill Rusch proposed the idea of video ping pong, developed by Ralph Baer and Bill Harrison.)
- Alcorn first examined Bushnell's schematics for Computer Space, but found them illegible, and went on to create his own designs based on his knowledge of transistor–transistor logic (TTL) and Bushnell's game.
- Andy Capp's Tavern was the bar the first machine was put into.

### Historical timeline

- **1971, April** — Ping Pong Diplomacy: nine players from the U.S. Table Tennis team took a historic trip to China, laying groundwork for U.S.–China diplomatic relations.
- **1972, February** — Nixon visits China.
- **1972, May** — Bushnell meets with Magnavox, sees the Odyssey's table tennis demo.
- **1972, August** — Pong installed at Andy Capp's Tavern.

### Ping-pong diplomacy detail

- In April 1971, nine players from the U.S. Table Tennis team took a historic trip to China. Their trip was the start of "ping pong diplomacy" and helped lay the groundwork for establishing official diplomatic relations between the United States and the People's Republic of China.
- Glenn Cowan, then 19, was the American player whose accidental ride on the Chinese team's bus — and the gift he received from world champion Zhuang Zedong — became the incident that triggered the invitation.
- The reading that the U.S. intended ping pong as an olive branch while still hoping to beat China at their own game is an **interpretation**, not a documented plan. It is useful to COM's backstory precisely because it is the kind of thing that sounds sourced and isn't.

*Note: Pong postdates all of this. The first machine was installed at Andy Capp's Tavern in August 1972, sixteen months after the China trip — so any story in which the machine trained the 1971 team is fiction. See COM's Origin.*

### ARPANET / DARPA note

The Advanced Research Projects Agency was renamed the **Defense** Advanced Research Projects Agency (DARPA) in 1972 — the same year Pong was built — and the network it had funded since 1969 was often informally called DARPAnet from then on.

Two details make this useful to COM's ARPA origin theory. First, ARPA's Information Processing Techniques Office was the primary funder of American AI research through this period, including pattern-recognition and speech-understanding work, so "an ARPA project about predicting patterns" is period-plausible in a way most conspiracy framings are not. Second, ARPANET's growth through the 1970s gives the story a mechanism for COM's decades of dormant "incubation" without requiring anyone to explain it.

---

### Original 1972 hardware behavior

Everything below is sourced from gate-level analyses of the real Pong E board — Hugo Holden's circuit analysis, Stephen Edwards' Columbia reconstruction, and MAME's transcribed netlist. Where those sources disagree with each other or with popular retellings, the disagreement is called out.

#### Video timing

- Crystal 14.318 MHz ÷ 2 → master clock **7.159 MHz**
- Line = **455 clocks** = 63.5 µs → horizontal frequency 15.734 kHz (exactly NTSC)
- Field = **262 lines** → **60.05 Hz**, **non-interlaced** — each field is scanned on top of itself rather than alternating, producing the characteristically coarse raster
- Horizontal blanking 80 clocks, vertical blanking 16 lines → **active playfield 375 clocks × 246 lines**, displayed at 4:3

Because 375 × 246 is displayed as 4:3, **one scanline is 1.143× taller than one clock is wide**. The pixels are not square, and any recreation that ignores this will change every return angle.

#### Object dimensions

| Object | Width | Height |
|---|---|---|
| Ball | 4 clocks | 4 scanlines |
| Paddle | 4 clocks | 15 scanlines |
| Net | 1 clock | 4 lines on / 4 lines off |
| Score digit | 32 clocks | ~32 lines |

Paddle 1 sits at H=128, the net at H=256, paddle 2 at H=384. Active video runs from clock 80 to 454, so the **visual center is H≈267, not 256** — the whole picture sits slightly left of center. Holden lists this as the board's first known defect: "Picture centres to the left, making monitor H hold setting difficult."

#### Paddle zones and return angle

The paddle is **15 scanlines tall**. A 7493 counter counts those lines while the paddle is drawn; **the least-significant bit is discarded**, and only the top three bits reach the encoder — giving **8 hit zones of 2 scanlines each** (the last is 1 line). A 7483 adder then adds 6 or 7 depending on the most significant bit, producing **7 distinct return velocities**:

| Paddle lines (top first) | Zone height | Load value | Vertical velocity |
|---|---|---|---|
| 0–1 | 2 | 13 | 3 lines/frame up |
| 2–3 | 2 | 12 | 2 up |
| 4–5 | 2 | 11 | 1 up |
| **6–7** | 2 | **10** | **0 — horizontal** |
| **8–9** | 2 | **10** | **0 — horizontal** |
| 10–11 | 2 | 9 | 1 down |
| 12–13 | 2 | 8 | 2 down |
| 14 | 1 | 7 | 3 down |

So the paddle has **8 zones producing 7 velocities**, and the horizontal-return band is **two zones wide** — 4 of 15 scanlines, 27% of the paddle face, and the widest single feature on it.

> **On the "seven segments vs. eight segments" confusion.** Alcorn is widely quoted as saying he "divided the paddle into eight segments… the center segment**s** return the ball at a 90° angle in relation to the paddle, while the outer segments return the ball at smaller angles." That is correct — note the plural, and note that "90° in relation to the paddle" means *perpendicular to the paddle*, i.e. traveling horizontally, not vertically. Gameplay guides that describe "seven blocks with a single middle block" have the right count of *outcomes* but are wrong that the center is one block.
>
> The decisive evidence is the Chicago Coin clone, which omitted the inverter gate C4. That changes the formula to `code + 6 + MSB`, yielding load values 6, 7, 8, 9, 11, 12, 13, 14 — **with 10 absent**. Holden reports that on that machine "the ball could never travel horizontally," which is exactly what the table above predicts.

**Return angle depends on rally speed.** Vertical velocity comes only from hit position (7 states); horizontal velocity comes only from the hit counter (3 tiers). They are independent circuits, so the same paddle zone returns a different angle at different rally speeds — and faster rallies produce **shallower** angles, because the vertical component is fixed while the horizontal component grows.

| Hit zone | Volleys 1–3 | Volleys 4–11 | Volleys 12+ |
|---|---|---|---|
| Center (2 zones) | 0° | 0° | 0° |
| ±1 line | 48.8° | 29.7° | 20.9° |
| ±2 lines | 66.4° | 48.8° | 37.3° |
| ±3 lines (edges) | 73.7° | 59.7° | 48.8° |

> ⚠️ Gameplay guides commonly state that volleys 12+ use "the steepest settings." This is backwards.

#### The 42 velocity vectors

Holden: *"Despite the lack of software, the ball in the game can have 42 distinct velocity vectors or directions and speeds."*

**7 vertical states × 3 horizontal speeds × 2 horizontal directions = 42.** Holden reaches the same total by a different route: 9 vectors per quadrant × 4 quadrants = 36, plus 6 purely horizontal vectors = 42.

#### Ball speed

Three discrete tiers. **No continuous acceleration.**

| Rally hit count | Horizontal movement per frame |
|---|---|
| < 4 | 1 clock |
| 4–11 | 2 clocks |
| ≥ 12 | 3 clocks |

The counter saturates at 12 and never goes higher. Speed resets to tier 1 on **any** point scored, and on coin insertion.

> ⚠️ **Sources disagree on the values.** Edwards and MAME's netlist give 1 / 2 / 3 clocks per frame (a 3× speed-up over a rally). Holden, who measured a real machine with a scope, gives 2 / 3 / 4 (a 2× speed-up); his 1.0 / 1.6 / 2.1 m/s readings sit much closer to 2:3:4 than to 1:2:3, though not exactly on it. Meta Pong uses **1 / 2 / 3**, on the weight of two independent gate-level sources.

#### Serve rules

- **Delay ≈ 1.7 s**, computed from the real 330 kΩ / 4.7 µF components. Holden estimates "about 1.5 seconds."
- **Position:** just right of the net — roughly 6 clock units.
- **Vertical velocity:** whatever it was at the moment of the miss. The three velocity latches are only clocked on a hit, so they hold the last hit's data.
- **Horizontal direction:** unchanged by a miss, so **the ball is served toward the player who missed it**. The left/right flip-flop is clocked through a gate that is dead during gameplay, so a miss cannot flip direction.
- **Vertical position is effectively arbitrary.** Only the *horizontal* counters are held reset during the serve delay. The vertical counter keeps running and keeps bouncing off the top and bottom for the full ~1.7 s while the ball is invisible — 102–306 lines of travel on a 246-line field. This is why the original's serve feels random.
- **First serve of a match:** the velocity latches are held at zero throughout attract mode, so on the first serve they read 000 — which the adder turns into load 7 or 13. **The opening serve always comes out at maximum vertical speed, the steepest angle the machine can produce.** Horizontal speed is reset to tier 1 by the coin.

#### Scoring

- An operator switch on the PCB selects a winning score of **11 or 15**. Eleven is the common default and what appears in most gameplay footage, but it is a setting, not a rule of the game.
- **The score display retains the previous match's score through attract mode.** The counters are reset on coin insertion, not at game over — so the between-match screen always shows one player on the winning score.
- Two 7490 decade counters plus a flip-flop for the tens digit, multiplexed through a 7448 BCD-to-seven-segment driver. Digits are 32 clocks wide; the left score occupies H 128–191 and the right H 320–383 — very nearly symmetric about the net at H=256, off by a single clock.

#### Paddle behavior and the travel defect

- **The paddle has no speed.** Position is set by an analog 5 kΩ potentiometer feeding a 555 one-shot triggered at the start of each vertical blank. The paddle is **absolutely positioned, instantaneous, with no velocity, acceleration or inertia** — it can travel from top to bottom in a single frame if the player spins the knob fast enough. This is the single largest difference between the original and any button-controlled recreation.
- **The paddles cannot reach the extremes of vertical travel.** Alcorn, in a 2013 Q&A: *"The problem you noticed about the paddle not going all the way to the top was left in because without it good players could monopolize the game. Our motto was 'if you can't fix it, call it a feature.'"* Holden disputes this in the same document, arguing the real purpose was to prevent the ball becoming latched in the vertical blanking interval — a documented lock-up requiring a power cycle.
- Wikipedia and the popular retelling describe the gap as being at the **top only**; Holden and Falstad both report a gap at **both** ends. The top is the famous one.
- **The size of the gap is not documented in any surviving source**, and is not derivable — MAME's potentiometer value is annotated `// This is a guess!!`.

#### Sound

Three sounds, all taps off the vertical ball-position counter rather than a dedicated oscillator — Alcorn's famous "the sound was free, it was already in the circuit."

| Sound | Trigger | Frequency | Duration |
|---|---|---|---|
| Hit | Ball and paddle coincident | ~492 Hz | ~16 ms (one field) |
| Bounce | Ball coincident with vertical blanking (top/bottom) | ~246 Hz | ~16 ms (one field) |
| Score | Ball video coincident with horizontal blanking | ~246 Hz | ~240 ms |

All sound is muted in attract mode.

> ⚠️ Edwards gives the bounce sound as ~980 Hz, which is internally inconsistent with his own hit-sound figure — the bounce tap is a *lower* bit-rate tap and cannot be an octave higher. Holden's figures are self-consistent, match MAME's tap assignments, and were measured on a real machine with a scope.

#### Attract mode

Holden: *"The ATRACT input is used when the game is not in use. It results in the ball being visible and bouncing around the screen and the player bats and scores are missing. It was done this way to attract people to the machine."*

The netlist refines this:

- **Ball:** visible, bouncing off **all four** edges. During play the ball only bounces off top and bottom; in attract, the score signal is passed through to the left/right flip-flop, adding side-wall bounces.
- **Paddles:** hidden.
- **Scores:** **retained from the last match** — this contradicts Holden's summary sentence above, but his own detailed section and the netlist agree the scores stay up.
- **Sound:** muted.
- **Trajectory:** the velocity latches are held at zero, forcing maximum vertical speed, and the hit counter never advances, so horizontal stays at tier 1. The attract ball therefore travels at **73.7° from horizontal — the steepest angle the machine can produce.**

On its origin, Alcorn: *"The attract mode was Nolan's idea. He told me that the controls must have no effect otherwise a child will sit there all day turning the knob. It took very few gates to make it work."*

#### The Ghost in the Machine

On **every real Pong E board ever shipped**, pins 1 and 10 of IC A6 were mislabelled on the schematic, cross-wiring the B data bits of the two paddles. The consequence: **player 1's paddle position affects the angle the ball leaves player 2's paddle, and vice versa.** When the paddles are more than 16 scanlines apart — which is most of the time — each paddle collapses from 8 zones to only **3 distinct vertical-motion states**, with the horizontal-return band displaced off-center.

It was not discovered until 2013, by William Buchholz, and is documented in Holden's analysis.

The practical implication for any recreation: a faithful reproduction of the *schematic* does not match the *machine* anybody actually played.

#### Flow chart of the original arcade machine

![Original arcade machine flow chart](https://user-images.githubusercontent.com/4650788/209723306-8119b8ca-ec1d-4dd5-bdd4-2bd5e5420fff.png)

[Created with apps.diagrams.net](https://app.diagrams.net/)

### Screen artifacts (CRT reference)

Phosphor afterglow and horizontal scan lines:

![Screen artifact examples](http://www.e-basteln.de/img/pong/upscaler_detail.jpg)

### Media

- [Pong — Wikipedia](https://en.wikipedia.org/wiki/Pong)
- [50 Years of Fun with Pong — Computer History Museum](https://computerhistory.org/blog/50-years-of-fun-with-pong/)
- [Original 1972 gameplay video](https://www.youtube.com/watch?v=fiShX2pTz9A)

![Pong gameplay](https://upload.wikimedia.org/wikipedia/commons/6/62/Pong_Game_Test2.gif) ![PICO-8 build screenshot](https://user-images.githubusercontent.com/4650788/209788733-1b88bb5f-b2fc-409a-86d7-1afae3868ff3.png)

### Hardware sources

Ordered by technical authority:

- [Hugo Holden — *Atari Pong E Circuit Analysis & Lawn Tennis* (PDF)](https://www.pong-story.com/LAWN_TENNIS.pdf) — reverse-engineered from real PCBs, with oscillograms and a 2013 Q&A with Alcorn. The single most authoritative source, though its tables are embedded images.
- [Stephen Edwards — *Reconstructing Pong on an FPGA*, Columbia CUCS-023-12 (PDF)](https://www.cs.columbia.edu/~sedwards/papers/edwards2012reconstructing.pdf) — academic gate-level analysis.
- [MAME `nl_pong.cpp`](https://github.com/mamedev/mame/blob/master/src/mame/atari/nl_pong.cpp) — executable gate-level netlist transcribed from the original schematics.
- [Falstad — Pong circuit simulator](https://www.falstad.com/pong/)
- [Ricardo Ramos — Pong board schematic redraw](https://ricardoramos.me/pong-board/)
- [Dan Boris on the Pong scoring system — AtariAge](https://forums.atariage.com/topic/225925-the-pong-scoring-system-game-ends-at-11/)
- [Pong Mechanics Wiki](https://gamemechanics.fandom.com/wiki/Pong) — general overview.
- [Gamesver — how the algorithm works](https://www.gamesver.com/how-to-win-at-pong-arcade-video-game-tips-tricks-strategies/) — useful gameplay observations, but **unreliable on technical detail**: it inverts the angle/speed relationship and its serve description does not match the hardware.

### Development references

- **Class diagram:** [Game Class Relationships](https://drive.google.com/file/d/10m8-LnTl3KZsYhIZ8uv-d-73zMB_cP55/view?usp=sharing)
- **PICO-8 documentation:** [manual](https://www.lexaloffle.com/dl/docs/pico-8_manual.html) · [changelog](https://www.lexaloffle.com/dl/docs/pico-8_changelog.txt) · [PICO-8 Wiki memory map](https://pico8wiki.com/index.php?title=Memory)
- **Helpful development and math guides:** [Javascript Pong Tutorial](https://codeincomplete.com/articles/javascript-pong/) · [Machine Specs](https://www.arcade-history.com/?n=pong&page=detail&id=2007)
- **Issue tracker:** [github.com/akinlin/Pico_Games/issues](https://github.com/akinlin/Pico_Games/issues)
