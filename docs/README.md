# docs

Documentation that spans the whole repository.

| File | Covers |
|---|---|
| [`NEW-CART.md`](NEW-CART.md) | The checklist for adding a cart, and the layout every cart follows |

## What belongs here

Repository-wide concerns: the working model, tooling and host setup, conventions that
apply to every cart, decisions about the repository's own shape.

## What does not

- **Game design and implementation** → [the wiki](https://github.com/akinlin/Pico_Games/wiki).
  One page per game, linked from the wiki home page. The wiki is authoritative for
  anything about how a game works.
- **Work and status** → [issues](https://github.com/akinlin/Pico_Games/issues). Build
  status, open questions and ideas not yet taken are issues, never documentation. If
  something can't be settled, that is a reason to ask rather than to write "TBD" here.
- **Anything specific to one cart** → that cart's folder. Its `CLAUDE.md` holds the
  working instructions; its `DEVLOG.md`, if it has one, holds the making-of material.

A doc that only ever gets read while working on one game is in the wrong place.
