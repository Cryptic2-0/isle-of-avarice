# Isle of Avarice — The Wide Isle (map and regions)

**Date:** 2026-11-12
**Status:** Draft, built without a question round at the owner's request
**Extends:** `2026-11-10-isle-of-avarice-design.md` section 5.4 ("The island")
**Based on:** branch `feat/m3-paths`. M4 (creatures and trials) is being built
on another device and is not in this branch; see section 9.

## 1. Why

The island today is one flat 800 x 800 square with 12 caches and 6 training
posts. Every spot plays the same. The owner asked for a big map with many
different parts, each with its own challenge, so there is more to do.

This design makes the island about four times larger and splits it into nine
regions. Each wild region has one rule of its own that no other region has,
and one rare Relic guarded by a gauntlet built from that rule.

## 2. Goals, non-goals, anti-goals

**Goals**

- A big island: about 2,000 studs across, plus an offshore rock.
- Nine named regions that look and play differently.
- One unique environmental challenge per wild region, readable at a glance.
- Geography that shapes PvP: rivers with bridges, walls with gates, a maze, a
  rock that strands players together.
- Everything is data plus pure rules, so it is unit-tested without Roblox and
  a new hazard or region is a catalog entry.

**Non-goals (not in this work)**

- Creatures and trials (M4), Edicts and fast travel (M5), parties (M6).
- New Relics. The 12 existing Relics are re-homed; the catalog is unchanged.
- Saved data changes. Nothing new is saved.
- Hand-made art. The world stays a greybox built from code.

**Anti-goals**

- A hazard that hurts players inside Tallyport or the starter ring.
- A hazard the client decides. Damage, healing and slows come from the server.
- Any name, place or mechanic lifted from an existing work.

## 3. Approaches considered

1. **Hand-placed parts in Studio.** Best looking, but Studio cannot run in
   this workspace, nothing could be unit-tested, and spec 5.4 says the first
   island is built by code.
2. **Roblox smooth terrain generated from noise.** Natural shapes, but the
   layout would be hard to test, hard to reason about for hazards, and slow
   to generate at this size.
3. **A grid of flat ground tiles coloured by region, with data-driven
   structures and hazards on top (chosen).** Every position question
   ("which region is this?", "is this land?", "what hurts here?") is a pure
   function with tests. Greybox art can be replaced later because code finds
   world objects by tag.

## 4. The shape of the island

North is -Z, east is +X. A **bearing** is degrees clockwise from north.

- The ground is a grid of 40-stud cells. A cell is land or sea as a whole.
  Ground level stays y = 0 everywhere; height comes from structures.
- **Tallyport**: the safe town, radius 40 (unchanged).
- **Counting Fields**: the ring out to radius 260. Flat, no hazards, no
  obstacles. The six Copper caches and the six training posts stay exactly
  where they are today.
- **Six wild regions**, each a 60-degree wedge from the Fields to the coast,
  placed like the Six Paths hexagon so the Paths panel doubles as a compass:

  | Bearing | Region | Path it echoes | Prize |
  |---|---|---|---|
  | 0 (north) | Thornwood | Fang | R009 Debt-Collector's Bell (Silver) |
  | 60 | Squall Steps | Gale | R007 Bottled Squall (Silver) |
  | 120 | Cinder Flats | Ember | R011 Weeping Strongbox (Gold) |
  | 180 (south) | Drowned Fen | Mire | — (leads to Reckoning Rock) |
  | 240 | Hush Gardens | Mend | R008 Ledger-Moth Wing (Silver) |
  | 300 | Bastion Reach | Bulwark | R012 The Hoarder's Thumbprint (Platinum) |

- **Reckoning Rock**: an islet of radius 80 off the south coast, reached by a
  40-wide causeway. Prize: R010 Gilded Anchor Link (Gold).
- **Coast**: distance from the centre = `960 + 60 sin(3b) + 40 sin(5b + 1)`
  for bearing `b` (radians inside the sines), so the shore has capes and
  bays between about 860 and 1,060 studs.
- **Three rivers ("Sluices")** run from radius 300 to the sea along bearings
  30, 150 and 270, each 100 studs wide. They are gaps in the ground: fall in
  and you drown. Each has two bridges, 420 and 760 studs out. The rivers
  split the wilds into three pairs; the bridges are the chokepoints.
- **Drowning**: a character below y = -6 is defeated at once.

A region's content is laid out in its own frame: **along** is the distance
from the island centre down the region's bearing, **across** is the distance
to the right of that line.

## 5. The rule every region shares

The island hurts everyone equally. Shields protect only from players: the
new-player shield and the respawn shield do not stop hazard damage. Hazard
damage does pass through a player's own effects (immunity, damage reduction,
ability shields), so abilities matter against the island.

A defeat by the island follows spec 3.4 as it stands: respawn in Tallyport,
nothing taken. If another player hit the victim in the last 15 seconds, that
player gets the defeat and the blind claim, exactly as today. Knocking a
rival into lava or off a bridge is a kill.

**Prize caches take longer to open** (3 seconds; 4 for the Platinum one)
instead of the usual 0.5, so the last step of each gauntlet is holding your
ground.

Hazards are built from five effects, combined as data:

| Effect | What it does |
|---|---|
| `dps` | Damage every second while inside |
| `damage` | One hit each time the hazard goes off |
| `slow` | Slower movement while inside (same slow as abilities use) |
| `heal` | Health every second while inside |
| `push` | Carries the character sideways at a set speed |

A hazard has a shape (circle, rectangle or a whole region) and may have
holes. It is either always on, or runs a **cycle**: idle, then a warning,
then active. The cycle is a pure function of the shared server clock, so the
server (for damage) and every client (for the warning glow) agree with no
network traffic.

## 6. The regions

Numbers are starting values for play tests. Positions are (along, across).

### Thornwood — the hedge maze (close quarters)

A 340 x 340 hedge maze, 17 x 17 squares of 20 studs, hedges 14 high, three
entrances (south, west, east). The Bell hangs in a 60-stud room at its heart.

- Unique rule: **briars**. Six hedge squares are briar gaps: you can push
  through, at 12 damage a second and 40% slower. The safe way from each
  entrance to the heart is 49 to 93 squares long; through briars it is 13 to
  17. Health buys time.
- Short sightlines and dead ends favour melee and ambush.

### Squall Steps — the pillar climb (movement)

Eighteen stone pillars rise 3 studs at a time, 5 studs apart, to a summit
plateau 57 studs up. The Bottled Squall sits on the summit.

- Unique rule: **gusts**. Four wind lanes cross the climb and the summit.
  Every 7 seconds a lane warns for 1.5 seconds, then blows for 2, carrying
  anyone in it sideways at 11 studs a second. A fall costs the climb, not
  health.
- Dashes and timing win here. A defender on the summit holds high ground.

### Cinder Flats — vents and lava (timing)

- Unique rule: **vents**. A vent warns for 1.5 seconds, then erupts for 35
  damage. "The Bellows" is a 5 x 5 field of vents firing in diagonal waves,
  flanked by lava.
- **Lava** deals 30 damage a second. Kiln Lake is a lava lake 220 across
  with an islet in the middle; a causeway with four vents firing in sequence
  leads to it. The Strongbox sits on the islet beside a vent that leaves a
  4-second gap for the 3-second hold.
- Wide open ground favours ranged fighting.

### Drowned Fen — bog and boardwalk (commitment)

- Unique rule: **bog**. Off the boardwalk you move at half speed and lose 3
  health a second. The boardwalk is rotted through for 60 studs in the
  middle: wade it, or take the long dry loop.
- The Fen ends at the causeway to Reckoning Rock.

### Reckoning Rock — the tide (being trapped)

- Unique rule: **the tide**. On a 120-second cycle the causeway is dry for
  70 seconds, warns for 15, then floods for 35 at 40 damage a second. The
  crossing takes about 14 seconds.
- The Rock itself is always safe, so everyone on it at high tide is stuck
  there together until the water drops. It is a natural arena.

### Hush Gardens — blight and springs (endurance)

- Unique rule: **blight**. The whole region beyond radius 330 drains 5
  health a second. **Springs** (radius 14) heal 15 a second. Five springs
  line the main trail 90 studs apart, with four more off the trail, one of
  them hidden near the prize.
- The Moth Wing lies 120 studs past the last trail spring. A full-health
  player reaches it and gets back with almost nothing left; healing and
  shields make it comfortable. Springs are contested ground.

### Bastion Reach — the fortress (attrition)

A walled ruin: three curtain walls 24 high with one 20-wide gate each, on
alternating sides, so the way in zigzags through three yards.

- Unique rule: **rockfall**. Each yard is covered by a grid of impact
  circles that warn for 2 seconds and land for 30 damage (35 in the keep),
  on staggered timers. A roofed shelter stands in the middle of each yard,
  and the prize spot in the keep is one.
- The Thumbprint is the only Platinum Relic and its cap is 2, so the keep is
  where the server fights. Walls block shots; gates favour defenders.

### Everywhere

- A road runs from Tallyport to each region's gate, with a signpost naming
  the region and its rule.
- Each wild region has one extra Copper cache just inside its gate, so the
  first visit always pays. That makes 18 caches.
- Scattered scenery (trees, rocks, rubble) gives cover. None in the Fields.

## 7. What the player sees

- The status column shows the region name, and the name of any hazard the
  player is standing in ("Briars", "Blight", "High tide").
- A message appears on entering a region: its name and its rule.
- Fog changes per region (thick in the Fen, red haze on the Flats).
- Cycling hazards glow dim, then bright as a warning, then brightest when
  active. The tide water visibly rises.

## 8. Technical design

Follows the main spec's rules: the server decides, rules are pure, content
is data.

```
src/shared/Catalog/Regions.luau        the nine regions
src/shared/Rules/Geography.luau        bearings, coast, rivers, cells, regionAt, isLand, strips
src/shared/Rules/Hazards.luau          shapes, cycles, sampling a position
src/shared/Rules/PlaceView.luau        region and hazard names for the HUD
src/shared/Catalog/SiteData/*.luau      one file per wild region: hazards, structures, caches
src/shared/Catalog/Sites.luau          all of them together, plus roads, bridges, signs, scenery
src/shared/Catalog/World.luau          caches now come from Sites
src/server/HazardService.luau          4 ticks a second: damage, heal, slow, drown
src/server/CombatService.luau          + environmentDamage
src/server/TerrainBuilder.luau         ground strips and sea
src/server/SiteBuilder.luau            structures and hazard markers
src/client/HazardController.luau       warning glow, tide height, gust push
src/client/Atmosphere.luau             fog per region
```

Decisions:

- **Clock.** Hazard cycles use `workspace:GetServerTimeNow()`, which the
  server and clients share. Status effects keep using `os.clock()`.
- **Gust push is applied by each client to its own character.** Roblox
  characters are simulated by their owner, so a server push would stutter.
  Nothing is granted for being pushed, so a cheater who ignores wind gains
  only what any movement cheat already gives. Damage, healing, slows and
  drowning stay on the server.
- **Hazard damage bypasses force fields** (it sets health directly), because
  shields are protection from players only.
- **No streaming.** The world is about 750 anchored parts.
- **No new remotes and no saved data.**

Testing: every rule and catalog invariant has Lune tests (land is one
connected piece, rivers fully separate their regions, every hazard and cache
sits on land in its own region, the Fields are hazard-free, each prize can
be held between hazard activations). Server and client code is checked by
lint and build here and by a Studio play test on the owner's PC.

## 9. Fit with M4

M4 is not in this branch, so this work avoids its ground: no creatures, no
trials, no new Relics, no saved data. Expect merge conflicts in
`World.luau`, `WorldBuilder.luau`, `CombatService.luau`, `Main.server.luau`
and the play-test driver; they are small and mechanical. After the merge,
M4's creature dens and trial spots should be placed per region with
`Geography.place`, and creature damage can reuse the hazard pipeline's
`environmentDamage`.

## 10. Open questions for play tests

1. All hazard numbers, especially blight (5/s) against the 120-stud last leg.
2. Whether the pillar gaps (5 studs across, 3 up) feel right on a phone.
3. Whether dying to the island should cost something. Today it does not, so
   a prize run can end in a free trip home.
