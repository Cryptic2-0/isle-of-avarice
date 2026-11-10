# Backlog

Small items found in review during M0 + M1 and left for later. None blocks
the M1 play test.

## Before or during M2

- Add a test that every message code the server can send has text in
  `Messages.luau`.
- `LedgerService`: ignore requests from a player who has already left, so a
  rate-limit record cannot be recreated after they leave.
- `LedgerService`: send the "Slow down." message at most once per second.
- `LedgerService.set` does nothing, silently, when a player's data is not
  loaded. Make it report that.
- `SourceService` works out the cache refill time separately from
  `Sources.tryCollect`. Return it from the rule so the two cannot drift.
- `DataService`: a leaving player is sent a "loaded elsewhere" kick message.
  Harmless, but skip it.
- `DataService`: reject an infinite Coin value on load; check
  `schemaVersion` when the saved-data format first changes.

## UI polish pass

- The Ledger button sits where the phone thumbstick is. Move it.
- The book is cramped on a phone screen.
- A claimed slot unclaims on a single tap. Consider a confirm step.
- Remove the default 1-pixel borders.
- Disable a row's buttons after the first click.

## Tests to add

- `Ledger.unclaim` does not change its input.
- `Messages.format` with `{player}` and with a missing value.
- `LedgerActions`: index 1.5, -1 and infinity on the claim path;
  claiming an already-claimed card.
- `Sources`: collecting again after the refill time; a cache whose Relic is
  not in the catalog.
- `RateLimiter`: time going backwards.

## Tidying

- `WorldBuilder.buildCache` takes an untyped parameter; building positions
  are written inline instead of in `World.luau`.
- `Ledger.sanitize` uses `#` on a list that could have gaps.
- Test harness: no guard against tables that contain themselves.
