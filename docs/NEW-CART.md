# Adding a new cart

Every cart follows the same shape. [`meta_pong/`](../meta_pong/) is the reference —
when this document and that folder disagree, that folder is right.

## Layout

```
<cart_name>/
├── <cart_name>.p8    the cart
├── CLAUDE.md         working instructions for this cart
└── DEVLOG.md         the making-of notebook (optional)
```

**The folder name, the file name and the cart's name all match**, lowercase with
underscores. A cart is found by guessing its path, not by reading the README.

## Checklist

1. **Branch off `main`**, named after the cart folder.

   ```bash
   git fetch pico && git checkout main && git merge --ff-only pico/main
   git checkout -b <cart_name>
   ```

2. **Create the folder** and save the cart into it from PICO-8. The repository lives
   inside PICO-8's own carts directory, so the cart folder is already a subfolder of the
   cart browser — `SAVE <cart_name>` from that folder is enough.

3. **Write the cart's `CLAUDE.md`.** This is the part that matters most and the part
   easiest to skip. It is the authority on that cart, and the only file automatically
   read when working on it. What earns a place in it:

   - What the game *is*, in a paragraph — enough that a change can be judged against it.
   - Where the source of truth lives (wiki page, issues) and which wins in a conflict.
   - Constraints the cart is actually up against. Not the generic PICO-8 limits — the
     ones that bind *this* cart, and what they cost.
   - Conventions and gotchas that cost real time to rediscover.
   - What is authored by a human and must not be generated.

   Do not copy `meta_pong/CLAUDE.md` wholesale. Almost all of it is Meta Pong's
   specifics — its velocity tables, its palette handling, its character budget. Copy the
   *structure*, not the content.

4. **Add a section to the [wiki home page](https://github.com/akinlin/Pico_Games/wiki)**
   for the game — a short description and a link to its own wiki page. Create that page
   when there is settled design to put on it. **The wiki home page is the list of games** —
   the [root README](../README.md) describes the pattern and names no cart, so adding one
   does not touch it.

5. **Open a PR into `main`.**

## Verifying a cart loads

PICO-8 0.2.7 lives at `C:\Program Files (x86)\PICO-8\pico8.exe` (not on `PATH`).
Running it with `-x` loads a cart headlessly, executes the top-level chunk and prints
`RUNNING: <cart>` — a syntax error or a load-time runtime error surfaces there instead of
on the next launch.

```bash
"/c/Program Files (x86)/PICO-8/pico8.exe" -x <cart_name>/<cart_name>.p8
```

`-x` does **not** call `_update60` or `_draw`. It proves the cart parses and loads; it
proves nothing about behavior. On this host it also frequently fails to exit — run it
backgrounded with output redirected to a log, then kill leftover `pico8` processes.

## Sharing code with `libs/`

`#include` paths are resolved relative to the cart file, so from inside a cart folder:

```lua
#include ../libs/<name>.lua
```

Two things to know before reaching for it:

- **An include costs its full character and token count in the including cart.** PICO-8
  applies the normal limits to the flattened result, so sharing code saves duplication
  and maintenance, never budget. A cart whose binding constraint is characters is often
  better off with a version cut down to exactly what it uses.
- **Includes are flattened on export.** Saving as `.p8.png` or exporting to a binary
  bakes the included files in, so a released cart has no external dependencies.

Code stays in the cart that needed it until a second cart needs it too.
