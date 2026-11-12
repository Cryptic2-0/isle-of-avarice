# Backlog

Small items found in review during M0 + M1 and left for later. None blocks
the M1 play test.

## Before or during M2

- `DataService`: check `schemaVersion` when the saved-data format first
  changes.

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

## World

Open questions from the wide-island design (section 10 of
`docs/superpowers/specs/2026-11-12-world-regions-design.md`), to settle in
play tests:

- All hazard numbers, especially blight (5 a second) against the 120-stud
  last leg to the Ledger-Moth Wing in Hush Gardens.
- Whether the pillar gaps in Squall Steps (5 studs across, 3 up) feel right
  on a phone.
- Whether dying to the island should cost something. Today it does not, so a
  prize run can end in a free trip home.

Known from the final review of the wide island, and left as they are:

- A prize cache's 3 or 4 second hold is set on the prompt, but the server
  does not check it (`SourceService` checks distance only).
- The region banner uses the same single message slot as server messages, so
  crossing a border can replace a message less than 3 seconds old.
- Roblox's default health regeneration (about 1 a second) is still on. Decide
  at the play test whether to turn it off or retune the bog and blight.
- The gust push moves the character's position directly and ignores
  collisions, so it may jitter against the sides of pillars.
- Walking back out along the Kiln Lake causeway has a much shorter safe start
  window than walking in.
- The "one hit per activation" rule lives in `HazardService`. Move it into
  `Hazards` as a pure, tested function.
- The extra-cache spot (310, -60) is written in both `Sites.luau` and
  `Scenery.luau`.
- Hush Gardens blight has no ground marker, only the status line and the
  entering message.
