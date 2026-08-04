# Pico Games

Every PICO-8 cart I build, plus the code and documentation shared between them.

| Looking for | Go to |
|---|---|
| What a game is, and how it's designed and built | [the wiki](https://github.com/akinlin/Pico_Games/wiki) |
| What's being worked on, and what's still open | [issues](https://github.com/akinlin/Pico_Games/issues) |
| How to add a cart | [`docs/NEW-CART.md`](docs/NEW-CART.md) |

This file covers the repository itself — how it's laid out, and how work moves through it.

---

## Structure

One folder per cart, named after the cart. Everything belonging to a game lives inside its
folder, and nothing outside it:

```
<cart_name>/
├── <cart_name>.p8    the cart — folder, file and cart name all match
├── CLAUDE.md         working instructions, and the authority on this cart
└── DEVLOG.md         the making-of notebook (optional)
```

Plus three things at the root:

| | |
|---|---|
| [`libs/`](libs/) | Lua shared between carts, pulled in with `#include ../libs/<name>.lua`. A file earns a place here when a *second* cart needs it — not before. |
| [`docs/`](docs/) | Documentation spanning the repository. Anything about a single game belongs in that game's folder or on the wiki. |
| This file | Repository-wide rules. **There is no `CLAUDE.md` at the root by design** — repo-wide rules live here and in `docs/`, per-cart rules in each cart's own file. |

---

## Working model

`main` is the integration branch and stays releasable. **Nothing is committed to it
directly.**

**Each cart has a branch**, named after its folder. All work on a game happens there and
lands on `main` through a pull request — so two carts can be in flight without either
one's half-finished state reaching `main`. Changes that aren't about a single game — this
file, `docs/`, `libs/`, the structure itself — go on their own descriptive branch and land
the same way.

```bash
git fetch pico && git checkout main && git merge --ff-only pico/main
git checkout <cart_name> && git merge main
```

Sync before starting: a clean `git status` says nothing about whether the checkout is
behind. Commit locally as you go rather than saving it all for the end, and push to the
cart's branch — always the same one, so the whole history is in one place when the
squash-or-not call gets made at merge. Conventional-commit subjects, referencing the issue.

New carts follow the same shape: [`docs/NEW-CART.md`](docs/NEW-CART.md).

---

Licensed under [`LICENSE`](LICENSE).
