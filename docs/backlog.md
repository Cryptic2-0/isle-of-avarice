# Backlog

Small items found in review and left for later. None blocks a play test.

## Left after M8

Each item says why it waits.

### Saved data

- `DataService`: check `schemaVersion` when the saved-data format first changes.
  Waits for: the first change to the format.

### Tuning, for the owner's play tests

- All hazard numbers, especially blight (5 a second) against the 120-stud last
  leg to the Ledger-Moth Wing in Hush Gardens. Waits for: how it feels in play.
- Whether the pillar gaps in Squall Steps (5 studs across, 3 up) feel right on a
  phone. Waits for: a play test on a real phone.
- Whether dying to the island should cost something. Today it does not, so a
  prize run can end in a free trip home. Waits for: how it feels in play.
- Walking back out along the Kiln Lake causeway has a much shorter safe start
  window than walking in. Waits for: the causeway timing at a play test.
- The gust push moves the character's position directly and ignores
  collisions, so it may jitter against the sides of pillars. Waits for: seeing
  whether it shows in play.
- The causeway vent markers are 1 stud wider than the causeway on each side.
  Waits for: a play test to say whether it is seen.

### Tests and tools, no change in play

- Nothing in `check.sh` checks Luau types. `--!strict` is only checked when the
  place is opened in Studio. Waits for: a type checker that can be installed.
- The sign label styling in `SiteBuilder` repeats the training-post label's.
  Waits for: a third place that needs it.
- Tests to tighten (test-only):
  - Only the `lava` look's values are pinned.
  - The hedge maze test does not check "one block per run".
  - The scenery tests do not pin the 36 props per region.
  - The Bellows straight-walk test passes at across ±20 and ±60 on rounding
    noise; give every tangent line the same small slack.
  - The marker test hardcodes the 0.2 lift and ground height 0.
- Play-test Driver: if the wait that lines up check W.6 with the vent times
  out, the check runs unaligned without saying so. Waits for: a flaky run that
  needs it.
