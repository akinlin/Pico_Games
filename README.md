# Pico Games

Every PICO-8 cart I build, plus the shared code and documentation behind them.
PICO-8 is a fantasy console — each game ships as a single `.p8` cartridge with hard
ceilings on code, sprites and sound, and those limits shape most of what follows.

**Game design and implementation notes live on [the wiki](https://github.com/akinlin/Pico_Games/wiki).**
**Work and status live in [issues](https://github.com/akinlin/Pico_Games/issues).**
This README covers the repository itself: how it is laid out and how work moves through it.

---

## Structure

```
.
├── meta_pong/      a Pong clone with a narrative AI
├── possessor/      possession-mechanic prototype
├── libs/           reusable Lua shared across carts
├── docs/           documentation covering the whole repository
└── README.md
```

### Cart folders

One folder per cart, named after the cart. Everything belonging to that game lives
inside it, and nothing outside it:

```
meta_pong/
├── meta_pong.p8    the cart — folder name, file name and cart name all match
├── CLAUDE.md       working instructions for this cart
└── DEVLOG.md       the making-of notebook (optional, per cart)
```

`meta_pong/` is the reference layout. **New carts follow the same shape** —
see [`docs/NEW-CART.md`](docs/NEW-CART.md) for the checklist.

Each cart's `CLAUDE.md` is the authority on how to work on *that* cart: its constraints,
its conventions, its gotchas. There is deliberately no `CLAUDE.md` at the repository
root — repository-wide rules live here and in `docs/`.

### `libs/`

Lua that more than one cart uses, or is written to be reused. PICO-8 pulls these in
with `#include`, which is resolved relative to the cart file:

```lua
#include ../libs/<name>.lua
```

A file earns a place here by actually being shared. Code written for one cart stays in
that cart's folder until a second cart needs it — the character budget means a cart
should never carry a general-purpose version of something it uses one way.

### `docs/`

Documentation that spans the repository rather than any single game: the working model,
the new-cart checklist, tooling and host setup. Anything specific to one game belongs in
that cart's folder or on the wiki, not here.

---

## Working model

`main` is the integration branch and stays releasable. **Nothing is committed to it
directly.**

**Each cart has its own branch**, named after the cart folder (`meta_pong`,
`possessor`). All work on a game happens on its branch, which lands on `main` through a
pull request. Two carts can therefore be in flight at once without either one's
half-finished state reaching `main`.

```
main ─────●────────────────●──────────────●─────▶
           \              /                  ⋮
meta_pong   ●──●──●──●───●  (PR)             ⋮
                                             ⋮
possessor   ●──●──────────────────────────●─● (PR)
```

1. **Sync before starting.** The remote is `pico`
   (`github.com/akinlin/Pico_Games`) and the default branch is `main`.

   ```bash
   git fetch pico && git checkout main && git merge --ff-only pico/main
   ```

2. **Work on the cart's branch**, brought up to date off `main`. Commit locally as
   progress is made rather than saving everything for one commit at the end.
3. **Push to the cart's branch.** Every push in a unit of work goes to the same branch —
   the whole history stays in one place so the squash-or-not call can be made at merge.
4. **Open a PR into `main`** when the work is ready to land.

Changes that are not about a single game — this README, `docs/`, `libs/`, repository
structure — go on their own descriptive branch (`repo-restructure`, `docs-pass`) and land
the same way.

Commit subjects are conventional-commit style and reference the issue they serve.

---

## Adding a new cart

The short version — the full checklist is in [`docs/NEW-CART.md`](docs/NEW-CART.md):

1. Branch off `main`, named after the cart.
2. Create `<cart_name>/` with `<cart_name>.p8` and a `CLAUDE.md`.
3. Add the game's section to the [wiki home page](https://github.com/akinlin/Pico_Games/wiki),
   linking to its own wiki page.
4. Add the cart to the structure table above.
5. PR into `main`.

---

## Games

| Cart | Folder | Design & implementation |
|---|---|---|
| **Meta Pong** | [`meta_pong/`](meta_pong/) | [wiki](https://github.com/akinlin/Pico_Games/wiki/Meta-Pong) |
| **Possessor** | [`possessor/`](possessor/) | [wiki](https://github.com/akinlin/Pico_Games/wiki) |

---

## License

See [`LICENSE`](LICENSE).
