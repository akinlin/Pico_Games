# libs

Lua shared across carts. Empty for now — nothing has been needed twice yet.

Pull a lib into a cart with `#include`, whose path is relative to the cart file:

```lua
#include ../libs/<name>.lua
```

## What earns a place here

A file moves into `libs/` when a **second** cart needs it. Not before. Writing a
general-purpose version of something up front costs characters in the only cart that
uses it, and PICO-8's budgets do not have room for generality that isn't being spent.

Two consequences of how `#include` works, both worth knowing before factoring something
out (see [`../docs/NEW-CART.md`](../docs/NEW-CART.md) for the longer note):

- **It costs full price in every cart that includes it.** The limits apply to the
  flattened result, so sharing buys maintenance, not budget.
- **It is flattened on export**, so a released `.p8.png` or binary carries no external
  dependency.

A lib should therefore be small, do one thing, and assume nothing about the game
including it.
