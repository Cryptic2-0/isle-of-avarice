# The Wide Isle (map and regions) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A 2,000-stud island of nine regions, each wild region with its own hazard rule and a gauntlet guarding one rare Relic, built from code, with all hazard effects decided by the server.

**Architecture:** As in M1–M3: pure Luau rules and catalogs in `src/shared`, unit-tested with Lune; thin server services; the client renders. Geography is a pure function of position (40-stud cells, bearings, a coast formula, three rivers). Hazards are catalog data built from five effects (`dps`, `damage`, `slow`, `heal`, `push`) with an optional idle/warn/active cycle that is a pure function of the shared server clock. One server service samples each player's position four times a second and applies the result.

**Tech Stack:** Luau (`--!strict`), Rojo 7.7.1, Lune 0.11.1, StyLua 2.6.0, Selene 0.31.0, plain Roblox instances.

**Spec:** `docs/superpowers/specs/2026-11-12-world-regions-design.md`. It extends section 5.4 of `docs/superpowers/specs/2026-11-10-isle-of-avarice-design.md` (revision 5), whose rules still bind.

## Global Constraints

- **Original content only.** No names, places or mechanics from any existing work. Region names are exactly: Tallyport, Counting Fields, Thornwood, Squall Steps, Cinder Flats, Drowned Fen, Reckoning Rock, Hush Gardens, Bastion Reach.
- **Tone:** cartoon knock-outs; "defeated", never "killed"; no blood or gore.
- Every file under `src/` except `src/server/Vendor` starts with `--!strict`. Files under `src/shared/` use no Roblox APIs and require each other only by relative string (`require("../Types")`).
- Rule functions never mutate their arguments.
- **The server decides** every hazard's damage, healing, slow and drowning. The only client-applied effect is the gust `push` on the player's own character.
- Player-on-player damage only through `CombatService.damage`. Island damage only through `CombatService.environmentDamage` / `environmentDefeat` (Task 6).
- **Untouched files:** `src/shared/Catalog/Relics.luau`, `src/shared/Net.luau`, `src/server/DataService.luau`. No new Relics, no new remotes, no saved-data changes.
- **Counting Fields stay as they are.** Caches C001–C006 and the six training posts keep their positions. No hazard affects any point within 270 studs of the centre. No solid feature has its centre within 280 studs of the centre.
- **Directions:** north is -Z, east is +X. A bearing is degrees clockwise from north. In a region's frame, `along` is distance from the island centre down the region's bearing and `across` is distance to the right of that line.
- **Numbers fixed by the spec:** cell 40; grid ±34 cells; Tallyport radius 40; Fields radius 260; coast `960 + 60·sin(3b) + 40·sin(5b + 1)`; rivers at bearings 30, 150, 270 from 300 out, half-width 50; bridges 420 and 760 out, 180 long, 16 wide; Rock centre (0, 1240) radius 80; causeway cells `i = 0`, `940 ≤ z ≤ 1160`; drown below y = -6; hazard tick 0.25 s; prize hold 3 s (Platinum 4 s), other caches 0.5 s; every hazard value as written in the task that defines it.
- Hazard cycles use `workspace:GetServerTimeNow()`. Status effects keep using `os.clock()`.
- `bash scripts/check.sh` must pass before every commit. On this machine the tools are not on PATH: run `export PATH="$PWD/.superpowers/tools/bin:$PATH"` first.
- Roblox Studio cannot run here. Server and client code is verified by `check.sh` (format, lint, build) only. Never write that something was play-tested.
- **Commits:** one line, conventional-commit style, at most 72 characters, no body, no AI attribution or co-author trailer.
- Work happens on branch `feat/world-regions` (based on `feat/m3-paths`). Do not push.

## Review Focus

1. **Non-finite positions and times.** NaN or infinite `x`, `z` or `now` passed to `Geography.regionAt`, `Geography.isLand`, `Hazards.contains`, `Hazards.phase` or `Hazards.sample` never errors; the position reads as `"CountingFields"`, not land, and takes no hazard effect. Pinned in Tasks 1 and 2.
2. **One hit per activation.** A player standing in a cycling `damage` hazard is hit once each time it goes off, not once per tick; a `dps` hazard removes `dps × elapsed`, not `dps` per tick. Pinned in Task 2 (cycle index) and by reading in Task 6.
3. **The Fields are safe.** No hazard reaches any point within 270 studs of the centre at any time, and all of it is land. Pinned in Task 5.
4. **Players who leave or are defeated mid-tick.** The hazard tick skips a player with no living character and forgets a player who leaves. Pinned by reading in Task 6.
5. **Shields and kill credit.** A force-fielded player still takes island damage; island damage never writes the hit log, so the last player to hit the victim keeps the defeat. Pinned by reading in Task 6.

## File Map

```
src/shared/Types.luau                    + Cache.hold, RegionId, Region, Shape, Cycle, Hazard, Feature, SiteCache, Site
src/shared/Catalog/Regions.luau          NEW  the nine regions
src/shared/Catalog/Looks.luau            NEW  colour and material per look name
src/shared/Rules/Geography.luau          NEW  bearings, coast, rivers, cells, regionAt, isLand, strips, bridges, shapes
src/shared/Rules/Hazards.luau            NEW  contains, affects, phase, sample
src/shared/Catalog/SiteData/Make.luau    NEW  block and disc feature helpers
src/shared/Catalog/SiteData/Thornwood.luau, SquallSteps.luau, CinderFlats.luau,
    DrownedFen.luau, ReckoningRock.luau, HushGardens.luau, BastionReach.luau   NEW  one site each
src/shared/Catalog/SiteData/Scenery.luau NEW  deterministic scatter
src/shared/Catalog/Sites.luau            NEW  all sites, common features, extra caches
src/shared/Catalog/World.luau            caches come from Sites; bigger island
src/shared/Rules/PlaceView.luau          NEW  region and hazard names for the HUD
src/shared/Rules/StatusView.luau         + region and hazard lines
src/server/CombatService.luau            + environmentDamage, environmentDefeat
src/server/HazardService.luau            NEW
src/server/LookPainter.luau              NEW
src/server/TerrainBuilder.luau           NEW
src/server/SiteBuilder.luau              NEW
src/server/WorldBuilder.luau             uses the builders; cache hold and height
src/server/Main.server.luau              + HazardService
src/client/HazardController.luau         NEW
src/client/Atmosphere.luau               NEW
src/client/StatusHUD.luau, Main.client.luau   + region line, banner, wiring
playtest/server/Driver.server.luau       cache count, C012 spot, world checks
docs/playtest/World-checklist.md         NEW
```

---

### Task 1: Types, regions, looks and geography

**Files:**
- Modify: `src/shared/Types.luau`
- Create: `src/shared/Catalog/Regions.luau`, `src/shared/Catalog/Looks.luau`, `src/shared/Rules/Geography.luau`
- Test: `tests/geography.spec.luau`

**Interfaces:**
- Consumes: nothing new.
- Produces (used by every later task):

```luau
-- Types.luau: change Cache, add the rest
export type Cache = { id: string, relicId: CardId, position: Vec3, hold: number? }
export type RegionId =
	"Tallyport" | "CountingFields" | "Thornwood" | "SquallSteps" | "CinderFlats"
	| "DrownedFen" | "ReckoningRock" | "HushGardens" | "BastionReach"
export type Region = {
	id: RegionId, name: string, hint: string,
	bearing: number?, -- wild regions only
	ground: string, -- a look name
	fog: { r: number, g: number, b: number, start: number, finish: number },
}
-- Every field is always present; unused ones are 0 or "".
export type Shape = {
	kind: "circle" | "rect" | "region",
	x: number, z: number, -- centre; 0 for "region"
	radius: number, -- circle radius; for "region" the least distance from the island centre
	bearing: number, halfAlong: number, halfAcross: number, -- rect only
	region: string, -- "region" only
}
export type Cycle = { period: number, warn: number, active: number, offset: number }
export type Hazard = {
	id: string, region: RegionId, name: string, look: string,
	shape: Shape, holes: { Shape }?, cycle: Cycle?,
	dps: number?, damage: number?, heal: number?,
	slow: number?, -- speed multiplier, 0.5 = half speed
	push: { x: number, z: number }?, -- world velocity, studs per second
	markerY: number?, -- height of the visual marker; ground when nil
}
-- x, y, z is the centre. sx is the extent across the yaw bearing, sy the height, sz the
-- extent along it. A cylinder stands upright: sx = sz = diameter.
export type Feature = {
	look: string, shape: "block" | "cylinder",
	x: number, y: number, z: number, sx: number, sy: number, sz: number,
	yaw: number, solid: boolean, text: string?,
}
export type SiteCache = { relicId: CardId, x: number, y: number, z: number, hold: number? }
export type Site = {
	region: RegionId, hazards: { Hazard }, features: { Feature },
	prize: SiteCache?, keepOut: { Shape },
}
```

```luau
-- Regions.luau
return { list: { Region }, byId: { [string]: Region }, wild: { RegionId } }
-- wild = { "Thornwood", "SquallSteps", "CinderFlats", "DrownedFen", "HushGardens", "BastionReach" }

-- Looks.luau
export type Look = { r: number, g: number, b: number, material: string, transparency: number }
return { byName: { [string]: Look } }

-- Geography.luau
Geography.CELL = 40
Geography.GRID = 34
Geography.TOWN_RADIUS = 40
Geography.FIELDS_RADIUS = 260
Geography.DROWN_Y = -6
Geography.ROCK = { x = 0, z = 1240, radius = 80 }
function Geography.bearingOf(x: number, z: number): number -- 0 <= b < 360; (0, 0) gives 0
function Geography.coastRadius(bearing: number): number
function Geography.toFrame(bearing: number, x: number, z: number): (number, number) -- along, across
function Geography.fromFrame(bearing: number, along: number, across: number): (number, number) -- x, z
function Geography.place(regionId: string, along: number, across: number): (number, number) -- errors for a region with no bearing
function Geography.cellOf(x: number, z: number): (number, number) -- i, j
function Geography.cellRegion(i: number, j: number): Types.RegionId -- never "Tallyport"
function Geography.cellIsLand(i: number, j: number): boolean
function Geography.regionAt(x: number, z: number): Types.RegionId
function Geography.isLand(x: number, z: number): boolean
function Geography.strips(): { { z: number, x1: number, x2: number, region: Types.RegionId } }
function Geography.bridges(): { { x: number, z: number, yaw: number, length: number, width: number } }
function Geography.circle(regionId: string, along: number, across: number, radius: number): Types.Shape
function Geography.rect(regionId: string, a1: number, a2: number, c1: number, c2: number): Types.Shape
function Geography.regionShape(regionId: string, minRadius: number): Types.Shape
```

- [ ] **Step 1: Add the types above to `src/shared/Types.luau`.**

- [ ] **Step 2: Write `src/shared/Catalog/Regions.luau`** with these nine entries, in this order:

| id | name | hint | bearing | ground | fog r, g, b, start, finish |
|---|---|---|---|---|---|
| Tallyport | Tallyport | Safe ground. No fighting here. | — | grass | 200, 215, 230, 200, 2500 |
| CountingFields | Counting Fields | Quiet fields. Nothing here will hurt you. | — | grass | 200, 215, 230, 200, 2500 |
| Thornwood | Thornwood | A hedge maze. Briars are a shortcut that costs health. | 0 | thorngrass | 60, 90, 60, 80, 900 |
| SquallSteps | Squall Steps | Climb the pillars. Brace when the wind lanes glow. | 60 | slate | 210, 225, 240, 300, 3000 |
| CinderFlats | Cinder Flats | Vents glow before they erupt. Lava burns fast. | 120 | ash | 120, 50, 30, 120, 1200 |
| DrownedFen | Drowned Fen | Stay on the boardwalk. The bog slows and drains you. | 180 | mud | 110, 125, 110, 30, 450 |
| ReckoningRock | Reckoning Rock | The causeway floods at high tide. The Rock is safe. | — | shale | 150, 170, 190, 100, 1500 |
| HushGardens | Hush Gardens | The blight drains you. Springs heal. | 240 | palegrass | 170, 150, 190, 100, 1000 |
| BastionReach | Bastion Reach | Rocks fall where the ground glows. Shelter under the roofs. | 300 | gravel | 150, 150, 160, 150, 1600 |

- [ ] **Step 3: Write `src/shared/Catalog/Looks.luau`.** `material` is the name of an `Enum.Material` item. Transparency is 0 unless given.

| look | r, g, b | material | transparency |
|---|---|---|---|
| grass | 86, 140, 60 | Grass | |
| thorngrass | 52, 92, 48 | Grass | |
| slate | 128, 136, 148 | Slate | |
| ash | 58, 52, 50 | Basalt | |
| mud | 84, 92, 62 | Mud | |
| shale | 96, 104, 112 | Slate | |
| palegrass | 150, 160, 120 | Grass | |
| gravel | 140, 132, 120 | Pebble | |
| hedge | 38, 84, 42 | Grass | |
| pillar | 150, 156, 168 | Slate | |
| wall | 120, 112, 104 | Brick | |
| roof | 96, 84, 72 | WoodPlanks | |
| wood | 139, 100, 60 | WoodPlanks | |
| road | 150, 146, 140 | Cobblestone | |
| sign | 139, 100, 60 | Wood | |
| rock | 110, 110, 112 | Slate | |
| trunk | 92, 64, 40 | Wood | |
| leaf | 60, 120, 50 | Grass | |
| deadwood | 120, 110, 100 | Wood | |
| basalt | 40, 38, 42 | Basalt | |
| rubble | 130, 124, 116 | Slate | |
| flower | 200, 150, 200 | Grass | |
| reed | 120, 130, 70 | Grass | |
| briar | 70, 48, 60 | Grass | 0.2 |
| lava | 255, 110, 20 | Neon | 0.1 |
| vent | 255, 170, 60 | Neon | 0.6 |
| bog | 60, 70, 40 | Mud | 0.2 |
| tide | 60, 120, 200 | Glass | 0.5 |
| spring | 90, 200, 255 | Neon | 0.4 |
| gust | 220, 240, 255 | Neon | 0.85 |
| rockfall | 255, 90, 60 | Neon | 0.7 |
| none | 0, 0, 0 | SmoothPlastic | 1 |

- [ ] **Step 4: Write the failing tests `tests/geography.spec.luau`.** Define a local `near(a, b)` as `math.abs(a - b) < 0.01`.

```luau
T.test("bearings and frames", function()
	T.eq(Geography.bearingOf(0, -100), 0)
	T.truthy(near(Geography.bearingOf(100, 0), 90))
	T.truthy(near(Geography.bearingOf(0, 100), 180))
	T.truthy(near(Geography.bearingOf(-100, 0), 270))
	T.eq(Geography.bearingOf(0, 0), 0)
	local x, z = Geography.place("Thornwood", 500, 100)
	T.truthy(near(x, 100) and near(z, -500))
	x, z = Geography.place("DrownedFen", 500, 100)
	T.truthy(near(x, -100) and near(z, 500))
	x, z = Geography.place("SquallSteps", 400, 0)
	T.truthy(near(x, 346.41) and near(z, -200))
	x, z = Geography.place("BastionReach", 820, 0)
	T.truthy(near(x, -710.14) and near(z, -410))
	local along, across = Geography.toFrame(60, 346.41, -200)
	T.truthy(near(along, 400) and near(across, 0))
	T.falsy(pcall(Geography.place, "Tallyport", 10, 0))
end)

T.test("coast", function()
	T.truthy(near(Geography.coastRadius(0), 993.66))
	T.truthy(near(Geography.coastRadius(120), 924.45))
	T.truthy(near(Geography.coastRadius(180), 926.34))
end)

T.test("regions by position", function()
	T.eq(Geography.regionAt(0, 0), "Tallyport")
	T.eq(Geography.regionAt(39, 0), "Tallyport")
	T.eq(Geography.regionAt(60, 40), "CountingFields")
	T.eq(Geography.regionAt(0, -600), "Thornwood")
	T.eq(Geography.regionAt(520, -300), "SquallSteps")
	T.eq(Geography.regionAt(520, 300), "CinderFlats")
	T.eq(Geography.regionAt(0, 600), "DrownedFen")
	T.eq(Geography.regionAt(-520, 300), "HushGardens")
	T.eq(Geography.regionAt(-520, -300), "BastionReach")
	T.eq(Geography.regionAt(0, 1240), "ReckoningRock")
	T.eq(Geography.regionAt(0, 1000), "ReckoningRock") -- the causeway
	T.eq(Geography.regionAt(0, 920), "DrownedFen")
end)

T.test("land and sea", function()
	T.truthy(Geography.isLand(0, 0))
	T.truthy(Geography.isLand(0, -600))
	T.falsy(Geography.isLand(2000, 0))
	T.falsy(Geography.isLand(-320, 0)) -- the west river
	T.truthy(Geography.isLand(-280, 0)) -- rivers start 300 out
	T.truthy(Geography.isLand(0, 1000)) -- causeway
	T.falsy(Geography.isLand(60, 1000)) -- sea beside it
	T.truthy(Geography.isLand(0, 1240))
	T.falsy(Geography.cellIsLand(35, 0))
end)

T.test("non-finite positions read as Fields and as not land", function()
	local nan = 0 / 0
	T.eq(Geography.regionAt(nan, 0), "CountingFields")
	T.eq(Geography.regionAt(0, math.huge), "CountingFields")
	T.falsy(Geography.isLand(nan, 0))
	T.falsy(Geography.isLand(0, -math.huge))
end)

T.test("everything within 270 of the centre is land", function()
	for x = -270, 270, 10 do
		for z = -270, 270, 10 do
			if x * x + z * z <= 270 * 270 then
				T.truthy(Geography.isLand(x, z), x .. "," .. z)
			end
		end
	end
end)

T.test("strips cover every land cell once", function()
	local strips = Geography.strips()
	T.eq(#strips, 144)
	local cells: { [string]: number } = {}
	local total = 0
	for _, s in strips do
		T.truthy(s.x2 > s.x1)
		local n = (s.x2 - s.x1) / 40
		T.eq(n, math.floor(n))
		total += n
		cells[s.region] = (cells[s.region] or 0) + n
		for x = s.x1 + 20, s.x2 - 20, 40 do
			T.truthy(Geography.isLand(x, s.z))
			local i, j = Geography.cellOf(x, s.z)
			T.eq(Geography.cellRegion(i, j), s.region)
		end
	end
	T.eq(total, 1695)
	T.eq(cells, {
		CountingFields = 137, Thornwood = 265, SquallSteps = 251, CinderFlats = 261,
		DrownedFen = 252, ReckoningRock = 18, HushGardens = 252, BastionReach = 259,
	})
end)

T.test("land is one connected piece and rivers split their regions", function()
	-- Flood fill over 4-neighbour land cells from (0, 0) must reach all 1695.
	-- No land cell of Thornwood/CinderFlats/HushGardens whose centre is 340 or more from
	-- the island centre has an 8-neighbour land cell of SquallSteps/DrownedFen/BastionReach
	-- respectively.
end)

T.test("six bridges land on both banks", function()
	local bridges = Geography.bridges()
	T.eq(#bridges, 6)
	for _, b in bridges do
		T.eq(b.length, 180)
		T.eq(b.width, 16)
		-- The two points 85 studs either side of the centre along the yaw bearing are land
		-- and lie in two different regions.
	end
end)

T.test("shape helpers", function()
	local c = Geography.circle("Thornwood", 500, 100, 14)
	T.eq(c.kind, "circle")
	T.truthy(near(c.x, 100) and near(c.z, -500))
	T.eq(c.radius, 14)
	local r = Geography.rect("DrownedFen", 400, 860, -180, 200)
	T.eq(r.kind, "rect")
	T.eq(r.bearing, 180)
	T.eq(r.halfAlong, 230)
	T.eq(r.halfAcross, 190)
	T.truthy(near(r.x, -10) and near(r.z, 630))
	local g = Geography.regionShape("HushGardens", 330)
	T.eq(g, { kind = "region", x = 0, z = 0, radius = 330, bearing = 0, halfAlong = 0, halfAcross = 0, region = "HushGardens" })
end)

T.test("regions and looks", function()
	T.eq(#Regions.list, 9)
	T.eq(Regions.wild, { "Thornwood", "SquallSteps", "CinderFlats", "DrownedFen", "HushGardens", "BastionReach" })
	for i, id in Regions.wild do
		T.eq(Regions.byId[id].bearing, (i - 1) * 60)
	end
	for _, region in Regions.list do
		T.truthy(Looks.byName[region.ground] ~= nil, region.id)
		T.truthy(#region.hint > 0)
	end
	T.eq(Regions.byId.SquallSteps.name, "Squall Steps")
	T.eq(Looks.byName.lava, { r = 255, g = 110, b = 20, material = "Neon", transparency = 0.1 })
end)
```

Write the two commented tests out in full.

- [ ] **Step 5: Run** `lune run tests/run` — Expected: FAIL, modules not found.

- [ ] **Step 6: Implement `src/shared/Rules/Geography.luau`.** It requires `../Catalog/Regions` and `../Types` only (never `World`). The exact rules:

```
bearingOf(x, z)   = 0 when x == 0 and z == 0; else math.deg(math.atan2(x, -z)), plus 360 when negative
coastRadius(b)    = 960 + 60*sin(3t) + 40*sin(5t + 1), t = math.rad(b)
toFrame(b, x, z)  = along  = x*sin(t) - z*cos(t);  across = x*cos(t) + z*sin(t)
fromFrame(b,a,c)  = x = a*sin(t) + c*cos(t);       z = -a*cos(t) + c*sin(t)
cellOf(x, z)      = floor(x/40 + 0.5), floor(z/40 + 0.5)

cellRegion(i, j), with x = 40i, z = 40j:
  1. (x - 0)^2 + (z - 1240)^2 <= 80^2            -> "ReckoningRock"
  2. i == 0 and 940 <= z and z <= 1160           -> "ReckoningRock"   (causeway)
  3. sqrt(x^2 + z^2) <= 260                      -> "CountingFields"
  4. otherwise Regions.wild[floor((bearingOf(x, z) + 30) / 60) % 6 + 1]

cellIsLand(i, j):
  1. |i| > 34 or |j| > 34                        -> false
  2. cellRegion(i, j) == "ReckoningRock"         -> true
  3. sqrt(x^2 + z^2) > coastRadius(bearingOf(x, z)) -> false
  4. for a river bearing b in {30, 150, 270}: along, across = toFrame(b, x, z);
     along >= 300 and |across| < 50              -> false
  5. otherwise true

regionAt(x, z): a non-finite x or z -> "CountingFields"; x^2 + z^2 <= 40^2 -> "Tallyport";
                otherwise cellRegion(cellOf(x, z))
isLand(x, z):   a non-finite x or z -> false; otherwise cellIsLand(cellOf(x, z))

strips(): for j = -34..34, each maximal run of consecutive land cells with the same
          cellRegion along i gives { z = 40j, x1 = 40*iFirst - 20, x2 = 40*iLast + 20, region }.
bridges(): for each river bearing b and each along in {420, 760}:
          x, z = fromFrame(b, along, 0); yaw = (b + 90) % 360; length 180; width 16.
rect(regionId, a1, a2, c1, c2): centre = place(regionId, (a1+a2)/2, (c1+c2)/2),
          bearing = the region's bearing, halfAlong = (a2-a1)/2, halfAcross = (c2-c1)/2.
```

- [ ] **Step 7: Run** `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 8: Commit** — `feat: regions, looks and island geography`

---

### Task 2: Hazard rules

**Files:**
- Create: `src/shared/Rules/Hazards.luau`
- Test: `tests/hazards.spec.luau`

**Interfaces:**
- Consumes: `Types.Shape`, `Types.Hazard`, `Geography.toFrame`, `Geography.regionAt`, `Geography.circle/rect/regionShape`.
- Produces:

```luau
export type Phase = "idle" | "warn" | "active"
export type Burst = { id: string, damage: number, cycle: number }
export type Sample = {
	dps: number, heal: number,
	slow: number, -- smallest speed multiplier in effect; 1 when none
	pushX: number, pushZ: number,
	bursts: { Burst }, names: { string },
}
Hazards.TICK_SECONDS = 0.25
Hazards.SLOW_SECONDS = 1
function Hazards.contains(shape: Types.Shape, x: number, z: number): boolean
function Hazards.affects(hazard: Types.Hazard, x: number, z: number): boolean -- in the shape and in no hole
-- phase, cycle index, fraction of the current phase already elapsed (0..1)
function Hazards.phase(hazard: Types.Hazard, now: number): (Phase, number, number)
function Hazards.sample(list: { Types.Hazard }, x: number, z: number, now: number): Sample
```

Rules:
- `contains`: circle — `dx² + dz² <= radius²`. Rect — `along, across = toFrame(bearing, x - shape.x, z - shape.z)`; `|along| <= halfAlong and |across| <= halfAcross`. Region — `Geography.regionAt(x, z) == shape.region and sqrt(x² + z²) >= shape.radius`. Written so a NaN coordinate gives false.
- `phase`: no cycle → `"active", 0, 0`. Otherwise `t = (now + offset) % period`, `idle = period - warn - active`; `t < idle` → idle; `t < idle + warn` → warn; else active. Cycle index = `floor((now + offset) / period)`. A non-finite `now` → `"idle", 0, 0`.
- `sample`: for each hazard in list order that `affects` the point and whose phase is active: add `dps`, `heal`, `push`; `slow = min(slow, hazard.slow)`; a hazard with `damage` appends `{ id, damage, cycle }` to `bursts`; its `name` is appended to `names` unless already there. Idle and warning hazards contribute nothing.

- [ ] **Step 1: Write the failing tests `tests/hazards.spec.luau`.**

```luau
local function hz(fields): Types.Hazard -- fills id, region, name, look with defaults
local pool = hz({ id = "pool", name = "Lava", dps = 30, shape = Geography.circle("CinderFlats", 500, 0, 20) })
local px, pz = Geography.place("CinderFlats", 500, 0)

T.test("circle, rect and region shapes", function()
	T.truthy(Hazards.contains(pool.shape, px + 19, pz))
	T.falsy(Hazards.contains(pool.shape, px + 21, pz))
	local rect = Geography.rect("SquallSteps", 530, 600, -40, 40)
	local x, z = Geography.place("SquallSteps", 599, 39)
	T.truthy(Hazards.contains(rect, x, z))
	x, z = Geography.place("SquallSteps", 601, 0)
	T.falsy(Hazards.contains(rect, x, z))
	x, z = Geography.place("SquallSteps", 560, 41)
	T.falsy(Hazards.contains(rect, x, z))
	local blight = Geography.regionShape("HushGardens", 330)
	x, z = Geography.place("HushGardens", 500, 60)
	T.truthy(Hazards.contains(blight, x, z))
	x, z = Geography.place("HushGardens", 300, 0)
	T.falsy(Hazards.contains(blight, x, z))
	T.falsy(Hazards.contains(blight, 0, -600)) -- Thornwood
end)

T.test("holes", function()
	local lake = hz({ id = "lake", dps = 30,
		shape = Geography.circle("CinderFlats", 760, 0, 110),
		holes = { Geography.circle("CinderFlats", 760, 0, 32), Geography.rect("CinderFlats", 650, 730, -10, 10) } })
	local function at(along, across) return Hazards.affects(lake, Geography.place("CinderFlats", along, across)) end
	T.truthy(at(760, 60))
	T.falsy(at(760, 0))
	T.falsy(at(700, 5))
	T.truthy(at(700, 15))
	T.falsy(at(600, 0))
end)

T.test("phases", function()
	local tide = hz({ id = "tide", dps = 40, cycle = { period = 120, warn = 15, active = 35, offset = 0 }, shape = pool.shape })
	local phase, cycle, part = Hazards.phase(tide, 0)
	T.eq({ phase, cycle, part }, { "idle", 0, 0 })
	T.eq((Hazards.phase(tide, 69.9)), "idle")
	phase, cycle, part = Hazards.phase(tide, 77.5)
	T.eq({ phase, cycle, part }, { "warn", 0, 0.5 })
	T.eq((Hazards.phase(tide, 85)), "active")
	T.eq((Hazards.phase(tide, 119.9)), "active")
	phase, cycle = Hazards.phase(tide, 120)
	T.eq({ phase, cycle }, { "idle", 1 })
	local late = hz({ id = "late", damage = 35, cycle = { period = 6, warn = 1.5, active = 1, offset = 2.4 }, shape = pool.shape })
	T.eq((Hazards.phase(late, 0)), "idle") -- t = 2.4 < 3.5
	T.eq((Hazards.phase(late, 1.2)), "warn") -- t = 3.6
	phase, cycle = Hazards.phase(late, 3.0) -- t = 5.4
	T.eq({ phase, cycle }, { "active", 0 })
	phase, cycle = Hazards.phase(late, 9.0) -- t = 11.4 -> 5.4 of cycle 1
	T.eq({ phase, cycle }, { "active", 1 })
	T.eq({ Hazards.phase(pool, 12345) }, { "active", 0, 0 })
	T.eq({ Hazards.phase(tide, 0 / 0) }, { "idle", 0, 0 })
	T.eq({ Hazards.phase(tide, math.huge) }, { "idle", 0, 0 })
end)

T.test("sample adds effects and reports bursts once per cycle index", function()
	local spring = hz({ id = "spring", name = "Spring", heal = 15, shape = pool.shape })
	local bog = hz({ id = "bog", name = "Bog", slow = 0.5, dps = 3, shape = pool.shape })
	local briar = hz({ id = "briar", name = "Briars", slow = 0.6, dps = 12, shape = pool.shape })
	local gust = hz({ id = "gust", name = "Gust", push = { x = 5.5, z = 9.53 }, shape = pool.shape })
	local vent = hz({ id = "vent", name = "Vent", damage = 35, cycle = { period = 6, warn = 1.5, active = 1, offset = 0 }, shape = pool.shape })
	local list = { pool, spring, bog, briar, gust, vent }
	T.eq(Hazards.sample(list, px, pz, 0), {
		dps = 45, heal = 15, slow = 0.5, pushX = 5.5, pushZ = 9.53, bursts = {},
		names = { "Lava", "Spring", "Bog", "Briars", "Gust" },
	})
	local s = Hazards.sample(list, px, pz, 5.2)
	T.eq(s.bursts, { { id = "vent", damage = 35, cycle = 0 } })
	T.eq(s.names[6], "Vent")
	T.eq(Hazards.sample(list, px, pz, 5.9).bursts[1].cycle, 0)
	T.eq(Hazards.sample(list, px, pz, 11.2).bursts[1].cycle, 1)
	T.eq(#Hazards.sample(list, px, pz, 4).bursts, 0) -- warning only
end)

T.test("outside everything, and non-finite input, give the empty sample", function()
	local empty = { dps = 0, heal = 0, slow = 1, pushX = 0, pushZ = 0, bursts = {}, names = {} }
	T.eq(Hazards.sample({ pool }, 0, 0, 0), empty)
	T.eq(Hazards.sample({ pool }, 0 / 0, pz, 0), empty)
	T.eq(Hazards.sample({ pool }, px, math.huge, 0), empty)
	T.eq(Hazards.sample({}, px, pz, 0), empty)
end)

T.test("same name from two hazards is listed once", function()
	local a = hz({ id = "a", name = "Lava", dps = 30, shape = pool.shape })
	T.eq(Hazards.sample({ pool, a }, px, pz, 0).names, { "Lava" })
	T.eq(Hazards.sample({ pool, a }, px, pz, 0).dps, 60)
end)
```

- [ ] **Step 2: Run** `lune run tests/run` — Expected: FAIL, `Hazards` not found.
- [ ] **Step 3: Implement `src/shared/Rules/Hazards.luau`** to the rules above.
- [ ] **Step 4: Run** `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 5: Commit** — `feat: hazard shape, cycle and sampling rules`

---

### Task 3: Sites — Thornwood and Squall Steps

**Files:**
- Create: `src/shared/Catalog/SiteData/Make.luau`, `src/shared/Catalog/SiteData/Thornwood.luau`, `src/shared/Catalog/SiteData/SquallSteps.luau`, `src/shared/Catalog/Sites.luau`
- Test: `tests/sites.spec.luau`

**Interfaces:**
- Consumes: Task 1 types, `Geography.place/circle/rect`, `Hazards.affects/phase/sample`, `Looks.byName`, `Relics.byId`.
- Produces:

```luau
-- Make.luau: a feature covering a region-frame rectangle from height y1 to y2 (yaw = the region's bearing)
function Make.block(regionId: string, a1: number, a2: number, c1: number, c2: number, y1: number, y2: number, look: string, solid: boolean): Types.Feature
-- an upright cylinder
function Make.disc(regionId: string, along: number, across: number, radius: number, y1: number, y2: number, look: string, solid: boolean): Types.Feature

-- each SiteData/<Region>.luau returns a Types.Site, plus any extra fields its tests need
-- Sites.luau
return {
	list: { Types.Site }, -- in the order sites are added: Thornwood, SquallSteps, (Task 4 adds five more)
	hazards: { Types.Hazard }, -- every site's hazards, in list order
	hazardById: { [string]: Types.Hazard },
	features: { Types.Feature }, -- every site's features, in list order
}
```

**Thornwood** (`region = "Thornwood"`). The maze, nearest row first:

```luau
local MAZE = {
	"#######.#########",
	"#...#...#...#...#",
	"#.#.#.#b#.#.#.#.#",
	"#.#.#.#...#...#.#",
	"#.###.#.#######.#",
	"#.#...#.......#.#",
	"#.#.#########.#.#",
	"..#...b.....#.#.#",
	"#.###.#.P.#.#.b.#",
	"#.....#.....#.#..",
	"#.#####.#.#.#.#.#",
	"#.....#.#.#.#.#.#",
	"#####.b.#.###.#.#",
	"#...#.#.#.....b.#",
	"#.###.###b#####.#",
	"#...............#",
	"#################",
}
```

- Square (row `r`, column `c`), both from 1, has its centre at `along = 490 + 20(r - 1)`, `across = 20(c - 9)`, and covers 20 x 20 studs. Export `MAZE` and `cellCentre(r, c): (number, number)` on the returned table.
- `#` is hedge: for each row, each maximal run of `#` is one `Make.block` from y 0 to 14, look `hedge`, solid.
- `b` is a briar gap: hazard `ThornBriar1`..`ThornBriar6` in row-then-column order, `Geography.rect` over the square, name `Briars`, look `briar`, `dps = 12`, `slow = 0.6`.
- Six thickets outside the maze: circles of radius 14 at (350, -100), (380, 110), (420, -150), (440, 60), (455, -60), (415, -35); ids `ThornThicket1`..`6`; same name, look and effects as briars.
- Prize: `R009` at the `P` square, `y = 1`, `hold = 3`.
- `keepOut = { Geography.rect("Thornwood", 480, 820, -170, 170) }`.

**Squall Steps** (`region = "SquallSteps"`):

- Pillars `k = 1..18`: `Make.block` 14 x 14, centre `along = 480 + 19(k - 1)`, `across = 6` for odd `k` and `-6` for even `k`, from y 0 to `3k`, look `pillar`, solid.
- Summit: `Make.block("SquallSteps", 815, 875, -30, 30, 0, 57, "pillar", true)`.
- Gust lanes, name `Gust`, look `gust`, speed 11, cycle period 7, warn 1.5, active 2:

| id | rect (a1, a2, c1, c2) | push direction | offset | markerY |
|---|---|---|---|---|
| SquallGust1 | 530, 600, -40, 40 | +across | 0 | — |
| SquallGust2 | 625, 695, -40, 40 | -across | 2.3 | — |
| SquallGust3 | 720, 790, -40, 40 | +across | 4.6 | — |
| SquallGust4 | 815, 875, -30, 30 | +along | 1.2 | 57.2 |

  `push` is the world vector: +along is `fromFrame(60, 1, 0)`, +across is `fromFrame(60, 0, 1)`, each times 11.
- Prize: `R007` at (845, 0), `y = 58`, `hold = 3`.
- `keepOut = { Geography.rect("SquallSteps", 470, 880, -45, 45) }`.
- Export `pillars: { { along: number, across: number, top: number } }` (the 18, in order) on the returned table.

- [ ] **Step 1: Write the failing tests `tests/sites.spec.luau`.** Two groups.

Generic invariants, looping over `Sites.list` so later sites are covered as they are added:

```luau
T.test("every hazard is well formed and sits on land in its own region", function()
	local seen: { [string]: boolean } = {}
	for _, site in Sites.list do
		for _, h in site.hazards do
			T.falsy(seen[h.id], h.id .. " is unique"); seen[h.id] = true
			T.eq(Sites.hazardById[h.id], h)
			T.eq(h.region, site.region, h.id)
			T.truthy(Looks.byName[h.look] ~= nil, h.id .. " look")
			T.truthy(h.dps ~= nil or h.damage ~= nil or h.heal ~= nil or h.slow ~= nil or h.push ~= nil, h.id .. " has an effect")
			if h.shape.kind ~= "region" then
				T.truthy(Geography.isLand(h.shape.x, h.shape.z), h.id .. " on land")
				T.eq(Geography.regionAt(h.shape.x, h.shape.z), site.region, h.id .. " region")
			end
			if h.cycle ~= nil then
				T.truthy(h.cycle.period > 0 and h.cycle.warn >= 0 and h.cycle.active > 0, h.id)
				T.truthy(h.cycle.warn + h.cycle.active < h.cycle.period, h.id)
			end
			if h.slow ~= nil then T.truthy(h.slow > 0 and h.slow < 1, h.id) end
		end
	end
end)

T.test("every feature is well formed", function()
	-- look exists in Looks; sx, sy, sz > 0 and finite; x, y, z finite
end)

T.test("every prize is a known Relic on land in its region and can be held", function()
	for _, site in Sites.list do
		local prize = site.prize
		if prize ~= nil then
			T.truthy(Relics.byId[prize.relicId] ~= nil)
			T.truthy(Geography.isLand(prize.x, prize.z))
			T.eq(Geography.regionAt(prize.x, prize.z), site.region)
			local hold = prize.hold or 0.5
			for _, h in Sites.hazards do
				if (h.dps ~= nil or h.damage ~= nil) and Hazards.affects(h, prize.x, prize.z) then
					if h.cycle == nil then
						T.eq(h.shape.kind, "region", h.id .. " always hurts at the prize")
					else
						local quiet = h.cycle.period - h.cycle.active
						T.truthy(quiet >= hold + 0.5, h.id .. " leaves time to open the prize")
					end
				end
			end
		end
	end
end)
```

Thornwood and Squall Steps:

```luau
T.test("Thornwood maze", function()
	T.eq(#Thornwood.MAZE, 17)
	for _, row in Thornwood.MAZE do T.eq(#row, 17) end
	local along, across = Thornwood.cellCentre(9, 9)
	T.eq({ along, across }, { 650, 0 })
	T.eq({ Thornwood.cellCentre(1, 8) }, { 490, -20 })
	-- Steps from each entrance to the P square, moving between squares that share a side:
	-- through "." and "P" only: south (1, 8) = 93, west (8, 1) = 77, east (10, 17) = 49;
	-- also allowing "b": 17, 13, 17.
	-- Every "#" square's centre lies inside exactly one solid hedge feature's footprint
	-- (use Hazards.contains on a rect built from the feature) and every other square's
	-- centre lies in none.
	-- Each "b" square's centre is affected by exactly one ThornBriar hazard with dps 12, slow 0.6.
	T.eq(#Thornwood.hazards, 12)
	local px, pz = Geography.place("Thornwood", 650, 0)
	T.eq(Thornwood.prize, { relicId = "R009", x = px, y = 1, z = pz, hold = 3 })
end)

T.test("Squall Steps climb", function()
	T.eq(#SquallSteps.pillars, 18)
	for k, p in SquallSteps.pillars do
		T.eq(p.top, 3 * k)
		T.eq(p.along, 480 + 19 * (k - 1))
		T.eq(p.across, if k % 2 == 1 then 6 else -6)
	end
	-- 19 features: 18 pillars 14 wide and the summit; pillar k's feature has sy = 3k and y = 1.5k.
	T.eq(#SquallSteps.hazards, 4)
	for _, h in SquallSteps.hazards do
		local push = h.push :: { x: number, z: number }
		T.truthy(math.abs(math.sqrt(push.x ^ 2 + push.z ^ 2) - 11) < 0.001, h.id)
		T.eq(h.cycle, { period = 7, warn = 1.5, active = 2, offset = ({ 0, 2.3, 4.6, 1.2 })[tonumber(string.sub(h.id, -1)) :: number] })
	end
	-- SquallGust1 pushes toward +across: toFrame(60, push.x, push.z) is about (0, 11).
	-- SquallGust2 about (0, -11); SquallGust4 about (11, 0), markerY 57.2.
	-- Lanes 1 to 3 each affect exactly 4 pillar centres.
	local px, pz = Geography.place("SquallSteps", 845, 0)
	T.eq(SquallSteps.prize, { relicId = "R007", x = px, y = 58, z = pz, hold = 3 })
end)

T.test("Sites gathers the sites", function()
	T.eq(Sites.list[1].region, "Thornwood")
	T.eq(Sites.list[2].region, "SquallSteps")
	-- #Sites.hazards and #Sites.features equal the sums over Sites.list
end)
```

Write every commented assertion out in full.

- [ ] **Step 2: Run** `lune run tests/run` — Expected: FAIL, modules not found.
- [ ] **Step 3: Implement `Make.luau`, `Thornwood.luau`, `SquallSteps.luau`, `Sites.luau`.**
- [ ] **Step 4: Run** `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 5: Commit** — `feat: Thornwood maze and Squall Steps sites`

---

### Task 4: Sites — Cinder Flats, Drowned Fen, Reckoning Rock, Hush Gardens, Bastion Reach

**Files:**
- Create: `src/shared/Catalog/SiteData/CinderFlats.luau`, `DrownedFen.luau`, `ReckoningRock.luau`, `HushGardens.luau`, `BastionReach.luau`
- Modify: `src/shared/Catalog/Sites.luau` (add the five, in that order, after the first two)
- Test: `tests/sites.spec.luau` (extend)

**Interfaces:**
- Consumes: Task 3's `Make`, `Sites`, and the generic invariant tests (which must pass for the new sites unchanged).
- Produces: `Sites.list` has 7 sites in the order Thornwood, SquallSteps, CinderFlats, DrownedFen, ReckoningRock, HushGardens, BastionReach.

All positions are (along, across) in the site's own region frame unless marked otherwise.

**Cinder Flats** (`region = "CinderFlats"`):

| ids | shape | effects | cycle (period, warn, active, offset) |
|---|---|---|---|
| `CinderVent1`..`25`, id number `5m + n + 1` | circle (440 + 40m, -80 + 40n), radius 15, `m, n = 0..4` | `damage = 35` | 6, 1.5, 1, `((m + 2n) % 5) × 1.2` |
| `CinderFlank1`, `CinderFlank2` | rect 440, 620, -190, -110 and rect 440, 620, 110, 190 | `dps = 30` | — |
| `CinderPool1`..`4` | circles (340, -120) r 22; (350, 90) r 20; (680, -190) r 26; (700, 200) r 24 | `dps = 30` | — |
| `CinderLake` | circle (760, 0) r 110; holes: circle (760, 0) r 32, rect 650, 730, -10, 10 | `dps = 30` | — |
| `CinderCausewayVent1`..`4` | circles (660, 0), (680, 0), (700, 0), (720, 0), radius 11 | `damage = 35` | 4.8, 1.2, 0.8, `(i - 1) × 1.2` |
| `CinderPrizeVent` | circle (760, 0) r 12 | `damage = 35` | 5, 1.5, 1, 0 |

Vents: name `Vent`, look `vent`. Lava: name `Lava`, look `lava`. Features: causeway `Make.block(…, 650, 730, -10, 10, 0, 0.6, "basalt", true)`; islet `Make.disc(…, 760, 0, 32, 0, 0.6, "basalt", true)`. Prize `R011` at (760, 0), `y = 1.6`, `hold = 3`. `keepOut`: rect 420, 640, -200, 200; circle (760, 0) r 120.

**Drowned Fen** (`region = "DrownedFen"`, no prize):

- `FenBog`: rect 400, 860, -180, 200; name `Bog`; look `bog`; `slow = 0.5`, `dps = 3`; holes are the five boardwalks: rect 400, 620, -7, 7; rect 680, 860, -7, 7; rect 493, 507, 7, 150; rect 493, 707, 143, 157; rect 693, 707, 7, 150.
- Features: one `Make.block` per boardwalk, y 0 to 0.6, look `wood`, solid.
- `keepOut = { the bog rect }`.

**Reckoning Rock** (`region = "ReckoningRock"`; it has no bearing, so use the Fen's frame, where along is world z and the Rock centre is (1240, 0)):

- `RockTide`: `Geography.rect("DrownedFen", 940, 1160, -20, 20)`; name `High tide`; look `tide`; `dps = 40`; cycle 120, 15, 35, 0.
- Prize `R010` at world (0, 1240), `y = 1`, `hold = 3`. No features. `keepOut = { circle at world (0, 1240) radius 30 }` (build with `Geography.circle("DrownedFen", 1240, 0, 30)`).

**Hush Gardens** (`region = "HushGardens"`):

- `HushBlight` (first in the hazard list): `Geography.regionShape("HushGardens", 330)`; name `Blight`; look `none`; `dps = 5`.
- `HushSpring1`..`9`: circles radius 14 at (380, 0), (470, 0), (560, 0), (650, 0), (740, 0), (450, -120), (560, 140), (660, -150), (790, 130); name `Spring`; look `spring`; `heal = 15`.
- Prize `R008` at (860, 0), `y = 1`, `hold = 3`. No features.
- `keepOut`: a circle of radius 20 at each spring and at the prize.

**Bastion Reach** (`region = "BastionReach"`):

- Walls, all `Make.block` from y 0 to 24, look `wall`, solid. Curtain walls at `A = 520, 640, 760` with a gate centred at across `g = -120, 120, -120`: two blocks each, `A - 4, A + 4, -200, g - 10` and `A - 4, A + 4, g + 10, 200`. Side walls `516, 884, -204, -196` and `516, 884, 196, 204`. Back wall `876, 884, -200, 200`. Nine blocks.
- Shelters, one per yard, for `A = 520, 640, 760`: roof `Make.block(…, A + 12, A + 108, -16, 16, 12, 13.5, "roof", true)` and two posts `Make.disc` radius 1.5 at (A + 14, 0) and (A + 106, 0), y 0 to 12, look `wall`, solid.
- Rockfall: yards `y = 1, 2, 3` start at `A = 520, 640, 760`. Rows `row = 0, 1, 2` at along `A + 24 + 36·row`. Columns `n = 0..10` at across `-180 + 36n`, **skipping `n = 5`**. Circle radius 18; id `BastionRock{y}_{row}_{n}`; name `Rockfall`; look `rockfall`. Yards 1 and 2: `damage = 30`, cycle 6, 2, 0.6, offset `((n + row) % 4) × 1.5`. Yard 3: `damage = 35`, cycle 4.5, 1.5, 0.6, offset `((n + row) % 3) × 1.5`. Ninety hazards.
- Prize `R012` at (820, 0), `y = 1`, `hold = 4`.
- `keepOut = { rect 510, 890, -210, 210 }`.

- [ ] **Step 1: Extend `tests/sites.spec.luau`** with one test per new site. `at(region, along, across, now)` is `Hazards.sample(Sites.hazards, x, z, now)` at `Geography.place(region, along, across)`.

```luau
T.test("Cinder Flats", function()
	T.eq(#CinderFlats.hazards, 37)
	T.eq(Sites.hazardById.CinderVent1.cycle, { period = 6, warn = 1.5, active = 1, offset = 0 })
	T.eq((Sites.hazardById.CinderVent8.cycle :: Types.Cycle).offset, 1.2 * ((1 + 2 * 2) % 5)) -- m = 1, n = 2
	T.eq(Sites.hazardById.CinderVent25.shape.radius, 15)
	T.eq(at("CinderFlats", 760, 60, 0).dps, 30) -- in the lake
	T.eq(at("CinderFlats", 760, 20, 0).dps, 0) -- on the islet
	T.eq(at("CinderFlats", 700, 0, 0), { dps = 0, heal = 0, slow = 1, pushX = 0, pushZ = 0, bursts = {}, names = {} })
	T.eq(at("CinderFlats", 700, 0, 2).bursts, { { id = "CinderCausewayVent3", damage = 35, cycle = 0 } })
	T.eq(at("CinderFlats", 760, 0, 4.5).bursts, { { id = "CinderPrizeVent", damage = 35, cycle = 0 } })
	T.eq(at("CinderFlats", 530, 150, 0).names, { "Lava" })
	T.eq(#CinderFlats.features, 2)
	T.eq((CinderFlats.prize :: Types.SiteCache).y, 1.6)
end)

T.test("Drowned Fen", function()
	T.eq(#DrownedFen.hazards, 1)
	T.eq(DrownedFen.prize, nil)
	T.eq(#DrownedFen.features, 5)
	local wet = { dps = 3, heal = 0, slow = 0.5, pushX = 0, pushZ = 0, bursts = {}, names = { "Bog" } }
	T.eq(at("DrownedFen", 650, 0, 0), wet) -- the rotted gap
	T.eq(at("DrownedFen", 600, 60, 0), wet)
	for _, p in { { 500, 0 }, { 700, 0 }, { 500, 100 }, { 600, 150 }, { 700, 100 }, { 850, 0 } } do
		T.eq(at("DrownedFen", p[1], p[2], 0).dps, 0, "boardwalk " .. p[1] .. "," .. p[2])
	end
	T.eq(at("DrownedFen", 390, 0, 0).dps, 0) -- before the bog
end)

T.test("Reckoning Rock tide", function()
	T.eq(ReckoningRock.prize, { relicId = "R010", x = 0, y = 1, z = 1240, hold = 3 })
	T.eq(Hazards.sample(Sites.hazards, 0, 1050, 0).dps, 0) -- low tide
	T.eq(Hazards.sample(Sites.hazards, 0, 1050, 75).dps, 0) -- warning
	T.eq(Hazards.sample(Sites.hazards, 0, 1050, 90), { dps = 40, heal = 0, slow = 1, pushX = 0, pushZ = 0, bursts = {}, names = { "High tide" } })
	T.eq(Hazards.sample(Sites.hazards, 0, 1240, 90).dps, 0) -- the Rock is always safe
	T.eq(Hazards.sample(Sites.hazards, 0, 920, 90).dps, 0) -- the Fen shore
end)

T.test("Hush Gardens", function()
	T.eq(#HushGardens.hazards, 10)
	T.eq(at("HushGardens", 500, 60, 0), { dps = 5, heal = 0, slow = 1, pushX = 0, pushZ = 0, bursts = {}, names = { "Blight" } })
	T.eq(at("HushGardens", 470, 0, 0), { dps = 5, heal = 15, slow = 1, pushX = 0, pushZ = 0, bursts = {}, names = { "Blight", "Spring" } })
	T.eq(at("HushGardens", 790, 130, 0).heal, 15)
	T.eq(at("HushGardens", 300, 0, 0).dps, 0) -- the gate is clear
	T.eq(at("HushGardens", 860, 0, 0).dps, 5) -- the prize is in the blight
	T.eq(at("HushGardens", 860, 0, 0).heal, 0)
end)

T.test("Bastion Reach", function()
	T.eq(#BastionReach.hazards, 90)
	T.eq(#BastionReach.features, 18)
	T.eq(Sites.hazardById.BastionRock1_0_0.cycle, { period = 6, warn = 2, active = 0.6, offset = 0 })
	T.eq(Sites.hazardById.BastionRock3_2_10.cycle, { period = 4.5, warn = 1.5, active = 0.6, offset = 0 })
	T.eq(Sites.hazardById.BastionRock3_1_4.damage, 35)
	T.eq(Sites.hazardById.BastionRock2_1_3.damage, 30)
	T.eq(Sites.hazardById.BastionRock1_0_5, nil)
	-- No rockfall hazard affects (along, 0) for along = 530..870 step 10: the shelter line and the prize.
	-- Every rockfall circle centre lies inside the walls: 524 < along < 876 and |across| < 196.
	-- For A, g in {520, -120}, {640, 120}, {760, -120}: (A, g) lies in no wall footprint and (A, 0) lies in one.
	local px, pz = Geography.place("BastionReach", 820, 0)
	T.eq(BastionReach.prize, { relicId = "R012", x = px, y = 1, z = pz, hold = 4 })
end)

T.test("seven sites in order", function()
	local order = {}
	for i, site in Sites.list do order[i] = site.region end
	T.eq(order, { "Thornwood", "SquallSteps", "CinderFlats", "DrownedFen", "ReckoningRock", "HushGardens", "BastionReach" })
end)
```

Write every commented assertion out in full.

- [ ] **Step 2: Run** `lune run tests/run` — Expected: FAIL, modules not found.
- [ ] **Step 3: Implement the five site modules and add them to `Sites.luau`.**
- [ ] **Step 4: Run** `bash scripts/check.sh` — Expected: exit 0, including the Task 3 generic invariants for all seven sites.
- [ ] **Step 5: Commit** — `feat: Cinder, Fen, Rock, Hush and Bastion sites`

---

### Task 5: Roads, bridges, signs, scenery and the 18 caches

**Files:**
- Create: `src/shared/Catalog/SiteData/Scenery.luau`
- Modify: `src/shared/Catalog/Sites.luau`, `src/shared/Catalog/World.luau`, `tests/world.spec.luau`, `tests/sites.spec.luau`
- Test: `tests/world.spec.luau`, `tests/scenery.spec.luau`

**Interfaces:**
- Consumes: `Sites.list`, `Geography.bridges/place/isLand/regionAt`, `Hazards.contains/affects`, `Regions`.
- Produces:

```luau
-- Scenery.luau
function Scenery.scatter(site: Types.Site, index: number): { Types.Feature } -- index = the region's place in Regions.wild

-- Sites.luau gains
Sites.common: { Types.Feature } -- roads, signs, bridges
Sites.scenery: { Types.Feature }
Sites.extras: { Types.SiteCache } -- six Copper caches, in Regions.wild order
-- Sites.features is now: every site's features, then common, then scenery

-- World.luau
World.islandHalfSize = 1380
World.townRadius = Geography.TOWN_RADIUS
World.caches: { Types.Cache } -- 18
```

**Common features**, for each wild region in `Regions.wild` order:

- Road: `Make.block(region, 45, 470, -6, 6, 0.02, 0.12, "road", false)`.
- Sign post: `Make.disc(region, 285, 14, 0.5, 0, 7, "sign", true)`. Sign board: `Make.block(region, 284.5, 285.5, 10, 18, 5, 8, "sign", false)` with `text = name .. "\n" .. hint` from `Regions`.

Then one bridge feature per `Geography.bridges()` entry: block, centre `(x, -0.7, z)`, `sx = 16`, `sy = 2`, `sz = 180`, `yaw` from the entry, look `wood`, solid.

**Extra caches:** the k-th wild region gets Relic `R00k` at `place(region, 310, -60)`, `y = 1`, no `hold`.

**Scenery.** `Scenery.scatter` only runs for the six wild sites (Reckoning Rock gets none). It is deterministic:

```
seed starts at 1000 + index
next(): seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648
repeat up to 400 times, stopping once 36 props are placed:
    along  = 300 + 600 * next()
    across = (2 * next() - 1) * 0.5 * along
    kind   = the site's kinds[floor(next() * #kinds) + 1]
    scale  = 0.8 + 0.6 * next()
    reject when any of these holds, checking the centre and the four points 12 studs
    from it along and across:
      - the point is not land, or regionAt(point) is not the site's region
      - the point is inside any of the site's keepOut shapes
      - any of the site's hazards whose shape kind is not "region" affects the point
    and also reject when:
      - |across| < 16 and along < 480                     (the road)
      - the centre is within 30 of the site's prize or of place(region, 310, -60)
```

A prop is one or two features at the centre; `scale` multiplies every height:

| region | kinds (each: parts as shape, diameter or sx × sz, height, look, solid) |
|---|---|
| Thornwood | tree: cylinder d 3 h 14 trunk solid + cylinder d 14 h 8 leaf not solid, sitting on top of the trunk; bush: cylinder d 8 h 4 leaf solid |
| SquallSteps | spire: block 6 × 6 h 18 pillar solid; boulder: block 8 × 8 h 5 rock solid |
| CinderFlats | column: cylinder d 6 h 12 basalt solid; mound: cylinder d 14 h 3 basalt solid |
| DrownedFen | dead tree: cylinder d 2.5 h 16 deadwood solid; reeds: cylinder d 10 h 5 reed not solid |
| HushGardens | dead tree (as above); flowers: cylinder d 12 h 0.4 flower not solid |
| BastionReach | rubble: block 8 × 6 h 4 rubble solid; column: cylinder d 4 h 10 wall solid |

**World caches:**

- `C001`–`C006`: Relics `R001`–`R006` at the six positions they have today — (60, 40), (-70, 55), (90, -60), (-50, -95), (120, 20), (-130, -10) — `y = 1`.
- `C007`–`C012`: Relic `R0NN` at the prize of the site that holds it, with the prize's `y` and `hold`.
- `C013`–`C018`: `Sites.extras[1..6]`.
- `cacheById` as before. `trainingPosts`, `POST_ID_BASE`, `postIndex`, `groundY`, `spawn` unchanged.

- [ ] **Step 1: Rewrite `tests/world.spec.luau`'s cache and constant tests and add the Fields test.** Keep the training-post test and the "every Relic in the catalog has at least one cache" test as they are.

```luau
T.test("eighteen caches on land, outside Tallyport", function()
	T.eq(#World.caches, 18)
	for i, cache in World.caches do
		T.eq(cache.id, string.format("C%03d", i))
		T.eq(World.cacheById[cache.id], cache)
		T.eq(cache.relicId, string.format("R%03d", if i <= 12 then i else i - 12))
		T.truthy(Geography.isLand(cache.position.x, cache.position.z), cache.id .. " on land")
		T.truthy(Geography.regionAt(cache.position.x, cache.position.z) ~= "Tallyport", cache.id)
	end
end)

T.test("Copper caches stay in the Fields; prizes sit in their regions", function()
	T.eq(World.cacheById.C001.position, { x = 60, y = 1, z = 40 })
	T.eq(World.cacheById.C006.position, { x = -130, y = 1, z = -10 })
	for i = 1, 6 do
		local cache = World.caches[i]
		T.eq(Geography.regionAt(cache.position.x, cache.position.z), "CountingFields")
		T.eq(cache.hold, nil)
	end
	local expected = { C007 = "SquallSteps", C008 = "HushGardens", C009 = "Thornwood", C010 = "ReckoningRock", C011 = "CinderFlats", C012 = "BastionReach" }
	for id, region in expected do
		local cache = World.cacheById[id]
		T.eq(Geography.regionAt(cache.position.x, cache.position.z), region, id)
		T.eq(cache.hold, if id == "C012" then 4 else 3, id)
	end
	T.eq(World.cacheById.C007.position.y, 58)
	T.eq(World.cacheById.C011.position.y, 1.6)
	local x, z = Geography.place("BastionReach", 820, 0)
	T.eq(World.cacheById.C012.position, { x = x, y = 1, z = z })
	for k, region in Regions.wild do
		local cache = World.caches[12 + k]
		local ex, ez = Geography.place(region, 310, -60)
		T.eq(cache.position, { x = ex, y = 1, z = ez })
		T.eq(cache.hold, nil)
	end
end)

T.test("constants", function()
	T.eq(World.islandHalfSize, 1380)
	T.eq(World.groundY, 0)
	T.eq(World.townRadius, 40)
	T.eq(World.spawn, { x = 0, y = 0.7, z = 0 })
end)

T.test("the Fields are safe: no hazard within 270 of the centre at any time", function()
	local empty = { dps = 0, heal = 0, slow = 1, pushX = 0, pushZ = 0, bursts = {}, names = {} }
	for now = 0, 120, 7.5 do
		for x = -270, 270, 15 do
			for z = -270, 270, 15 do
				if x * x + z * z <= 270 * 270 then
					T.eq(Hazards.sample(Sites.hazards, x, z, now), empty, x .. "," .. z .. " at " .. now)
				end
			end
		end
	end
end)

T.test("no solid feature stands in the Fields", function()
	for _, f in Sites.features do
		if f.solid then
			T.truthy(math.sqrt(f.x * f.x + f.z * f.z) >= 280)
		end
	end
end)
```

`tests/scenery.spec.luau`:

```luau
T.test("scatter is deterministic and respects the site", function()
	for index, region in Regions.wild do
		local site = -- the site in Sites.list with this region
		local a = Scenery.scatter(site, index)
		T.eq(Scenery.scatter(site, index), a)
		T.truthy(#a >= 24, region .. " has scenery")
		local ex, ez = Geography.place(region, 310, -60)
		for _, f in a do
			T.truthy(Geography.isLand(f.x, f.z) and Geography.regionAt(f.x, f.z) == region)
			T.truthy(Looks.byName[f.look] ~= nil)
			for _, shape in site.keepOut do T.falsy(Hazards.contains(shape, f.x, f.z)) end
			T.truthy(math.sqrt((f.x - ex) ^ 2 + (f.z - ez) ^ 2) >= 30)
			local along, across = Geography.toFrame(Regions.byId[region].bearing :: number, f.x, f.z)
			T.falsy(math.abs(across) < 16 and along < 480)
		end
	end
end)
```

Add to `tests/sites.spec.luau`: `#Sites.common == 24` (6 roads, 12 sign parts, 6 bridges); exactly six features have `text`, the first being `"Thornwood\nA hedge maze. Briars are a shortcut that costs health."`; `#Sites.extras == 6` with `relicId` `R001`..`R006`; `Sites.features` length equals site features + common + scenery.

- [ ] **Step 2: Run** `lune run tests/run` — Expected: FAIL.
- [ ] **Step 3: Implement `Scenery.luau`, extend `Sites.luau`, rewrite `World.luau`'s cache list.** `World.luau` requires `./Sites` and `../Rules/Geography`. Neither `Sites` nor `Geography` may require `World` or `Protection`.
- [ ] **Step 4: Run** `bash scripts/check.sh` — Expected: exit 0. All earlier specs still pass (`sources.spec`, `protection.spec` and others read `World`).
- [ ] **Step 5: Commit** — `feat: roads, bridges, scenery and eighteen caches`

---

### Task 6: Server — island damage and HazardService

**Files:**
- Modify: `src/server/CombatService.luau`, `src/server/Main.server.luau`, `tests/build.spec.luau`
- Create: `src/server/HazardService.luau`

**Interfaces:**
- Consumes: `Hazards.sample`, `Hazards.TICK_SECONDS`, `Hazards.SLOW_SECONDS`, `Sites.hazards`, `Geography.DROWN_Y`, `StatusService.update(player, fn: (Status, number) -> Status)`, `Effects.isImmune(status, now)`, `Effects.resolveDamage(status, amount, now): (Status, number, number)`, `Effects.applySlow(status, factor, duration, now)`.
- Produces:

```luau
-- Damage from the island: no attacker, no protections (shields guard against players only),
-- no hit-log entry. The victim's own effects still apply: immunity cancels it; damage
-- reduction and ability shields absorb. Sets Humanoid.Health directly, so a ForceField does
-- not block it. `flash` also fires the HitFx remote. True when health was removed.
function CombatService.environmentDamage(victim: Player, amount: number, flash: boolean?): boolean
-- Defeats the victim outright (drowning). Ignores effects.
function CombatService.environmentDefeat(victim: Player)
function HazardService.start()
```

- [ ] **Step 1: Add `environmentDamage` and `environmentDefeat` to `CombatService.luau`.** `environmentDamage` returns false for an amount that is not greater than 0 (so NaN is refused), a victim who has left, or one with no living character. It runs the same `StatusService.update` + `Effects.isImmune` + `Effects.resolveDamage` step that `CombatService.damage` uses on the victim, discards the reflect amount, and then sets `Humanoid.Health = math.max(0, Health - toHealth)`. It never touches `hitLog`, `ProtectionService` or `Protection.canDamage`. Both functions leave the existing `Humanoid.Died` handler to credit the defeat.

- [ ] **Step 2: Write `src/server/HazardService.luau`.**
  - One `RunService.Heartbeat` connection accumulates time and runs a tick every `Hazards.TICK_SECONDS`; `elapsed` is the real time since the last tick, capped at 1.
  - Each tick, `now = workspace:GetServerTimeNow()`; for each player with a living character (Humanoid with health above 0 and a HumanoidRootPart):
    1. root Y below `Geography.DROWN_Y` → `CombatService.environmentDefeat(player)`, next player.
    2. `sample = Hazards.sample(Sites.hazards, x, z, now)`.
    3. `sample.dps > 0` → `environmentDamage(player, sample.dps * elapsed)`.
    4. each burst whose `cycle` differs from the last one recorded for this player and hazard id → record it, then `environmentDamage(player, burst.damage, true)`.
    5. if still alive and `sample.heal > 0` → `Health = math.min(MaxHealth, Health + sample.heal * elapsed)`.
    6. `sample.slow < 1` → `StatusService.update(player, function(status, at) return Effects.applySlow(status, sample.slow, Hazards.SLOW_SECONDS, at) end)`.
  - Burst memory is per player and cleared on `Players.PlayerRemoving`.
  - A failure for one player (wrap the per-player step in `pcall`, warn once per tick) must not stop the others.

- [ ] **Step 3: Start it from `Main.server.luau`** with `runStep("HazardService.start", HazardService.start)` directly after `AbilityService.start`. Add `Server.HazardService`, `Shared.Rules.Geography`, `Shared.Rules.Hazards`, `Shared.Catalog.Regions`, `Shared.Catalog.Looks`, `Shared.Catalog.Sites` and `Shared.Catalog.SiteData.Thornwood` ModuleScript assertions to `tests/build.spec.luau`.

- [ ] **Step 4: Run** `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 5: Commit** — `feat: island damage pipeline and HazardService`

---

### Task 7: Server — build the island

**Files:**
- Create: `src/server/LookPainter.luau`, `src/server/TerrainBuilder.luau`, `src/server/SiteBuilder.luau`
- Modify: `src/server/WorldBuilder.luau`, `tests/build.spec.luau`

**Interfaces:**
- Consumes: `Geography.strips()`, `Regions.byId`, `Looks.byName`, `Sites.features`, `Sites.hazards`, `World.caches` (with `hold` and raised `y`), `Types.Feature`, `Types.Hazard`.
- Produces:

```luau
function LookPainter.paint(part: BasePart, look: string) -- colour, material, transparency; unknown look or material -> grey SmoothPlastic
function TerrainBuilder.build(island: Folder) -- Folder "Ground" (one Part per strip) and Folder "Sea"
function SiteBuilder.build(island: Folder)    -- Folder "Features" and Folder "Hazards"
```

- [ ] **Step 1: `LookPainter.luau`.** Looks the material up by name with `(Enum.Material :: any)[look.material]` inside `pcall`.

- [ ] **Step 2: `TerrainBuilder.luau`.**
  - Ground: for each strip, an anchored Part named `Ground`, size `(x2 - x1, 4, 40)`, centre `((x1 + x2) / 2, World.groundY - 2, z)`, painted with the strip region's `ground` look.
  - Sea: four anchored Parts `2048 × 2 × 2048` centred at `(±1024, -4, ±1024)`, with the colour, material, transparency and `CanCollide = false` the current sea has. (A Part cannot be larger than 2048 on a side.)

- [ ] **Step 3: `SiteBuilder.luau`.**
  - Feature → anchored Part in `Features`. Block: `Size = (sx, sy, sz)`, `CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, -math.rad(yaw), 0)`. Cylinder: `Shape = Cylinder`, `Size = (sy, sx, sx)`, `CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90))`. `CanCollide = solid`; a non-solid feature also has `CanQuery = false` and `CanTouch = false`. A feature with `text` gets a BillboardGui (size 260 × 70 offset, `MaxDistance = 120`, `AlwaysOnTop = false`) with one white bold scaled TextLabel showing the text, like the training-post label.
  - Hazard → marker Part in `Hazards`, named with the hazard id, attribute `HazardId` = the id, tag `Hazard`, painted with the hazard's look; anchored; `CanCollide`, `CanQuery`, `CanTouch` and `CastShadow` all false. Its centre height is `(hazard.markerY or World.groundY) + 0.2`. Circle: a flat cylinder 0.3 thick of the shape's radius. Rect: a block `(2·halfAcross, 0.3, 2·halfAlong)` turned to the shape's bearing as for features. Region shapes get no marker. A hazard whose look is `tide` also gets the attribute `Rise = 3`.

- [ ] **Step 4: `WorldBuilder.luau`.**
  - `build()` becomes: create `Island`; `TerrainBuilder.build`; `SiteBuilder.build`; Tallyport; caches; posts; parent to workspace. Remove the old single `Ground` slab and `Sea` part and the constants only they used.
  - `buildCache(island: Folder, index: number, cache: Types.Cache)` (typed): `prompt.HoldDuration = cache.hold or 0.5`. The pillar stands on the cache's own floor, `base = cache.position.y - 1`: its centre is `base + 6`. The landmark rock is built only when `base < 1`, standing on `base`.

- [ ] **Step 5: Add** `Server.LookPainter`, `Server.TerrainBuilder`, `Server.SiteBuilder` ModuleScript assertions to `tests/build.spec.luau`.
- [ ] **Step 6: Run** `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 7: Commit** — `feat: build terrain strips, sites and hazard markers`

---

### Task 8: Client — region HUD, hazard visuals, gusts and atmosphere

**Files:**
- Create: `src/shared/Rules/PlaceView.luau`, `src/client/HazardController.luau`, `src/client/Atmosphere.luau`
- Modify: `src/shared/Rules/StatusView.luau`, `src/client/StatusHUD.luau`, `src/client/Main.client.luau`, `tests/status_view.spec.luau`, `tests/build.spec.luau`
- Test: `tests/place_view.spec.luau`, `tests/status_view.spec.luau`

**Interfaces:**
- Consumes: `Geography.regionAt`, `Regions.byId`, `Hazards.sample/phase`, `Sites.hazards`, `Sites.hazardById`, the `Hazard` tag and `HazardId` / `Rise` attributes from Task 7, `Toast.show(text)`.
- Produces:

```luau
-- PlaceView.luau
export type Place = { regionId: string, name: string, hint: string, hazards: { string } }
function PlaceView.at(x: number, z: number, now: number): Place

-- StatusView.luau: Line.kind gains "region" and "hazard"; build takes an optional third argument
function StatusView.build(status: Status?, inSafeZone: boolean, place: { name: string, hazards: { string } }?): { Line }

function HazardController.start()
function Atmosphere.set(regionId: string)
```

- [ ] **Step 1: Write the failing tests.**

`tests/place_view.spec.luau`:

```luau
T.test("names the region and the hazards in effect", function()
	T.eq(PlaceView.at(0, 0, 0), { regionId = "Tallyport", name = "Tallyport", hint = "Safe ground. No fighting here.", hazards = {} })
	local x, z = Geography.place("HushGardens", 470, 0)
	local place = PlaceView.at(x, z, 0)
	T.eq(place.regionId, "HushGardens")
	T.eq(place.name, "Hush Gardens")
	T.eq(place.hazards, { "Blight", "Spring" })
	T.eq(PlaceView.at(0, 1050, 90).hazards, { "High tide" })
	T.eq(PlaceView.at(0, 1050, 10).hazards, {})
	T.eq(PlaceView.at(0 / 0, 0, 0).regionId, "CountingFields")
end)
```

Add to `tests/status_view.spec.luau` (the existing two-argument tests stay and must still pass):

```luau
T.test("place adds the region first and hazards last", function()
	T.eq(
		StatusView.build({ newShield = true, respawnShieldSeconds = 0, markedSeconds = 0 }, false, { name = "Thornwood", hazards = { "Briars" } }),
		{
			{ text = "Thornwood", kind = "region" },
			{ text = "New-player shield", kind = "shield" },
			{ text = "Briars", kind = "hazard" },
		}
	)
	T.eq(StatusView.build(nil, true, { name = "Tallyport", hazards = {} }), {
		{ text = "Tallyport", kind = "region" },
		{ text = "Safe zone", kind = "safe" },
	})
end)
```

- [ ] **Step 2: Run** `lune run tests/run` — Expected: FAIL.
- [ ] **Step 3: Implement `PlaceView.luau` and the `StatusView.build` change.**

- [ ] **Step 4: `StatusHUD.luau`** — add `KIND_COLORS` entries `region = Color3.fromRGB(245, 235, 210)` and `hazard = Color3.fromRGB(255, 170, 60)`.

- [ ] **Step 5: `Atmosphere.luau`** — `set(regionId)` tweens `Lighting.FogColor`, `Lighting.FogStart` and `Lighting.FogEnd` over 1.5 seconds to the region's `fog` values (`FogStart = fog.start`, `FogEnd = fog.finish`). An unknown region id does nothing.

- [ ] **Step 6: `HazardController.luau`.**
  - On `RunService.RenderStepped(dt)`: if the local character is alive, sample its position with `Hazards.sample(Sites.hazards, x, z, workspace:GetServerTimeNow())`; when `pushX` or `pushZ` is not 0, `root.CFrame += Vector3.new(pushX, 0, pushZ) * dt`.
  - Every 0.1 seconds, for every instance tagged `Hazard` whose `HazardId` names a hazard with a cycle: remember the part's first CFrame and its look's transparency; get `phase, _, part = Hazards.phase(hazard, now)`; set `Transparency` to the look's own value when idle, alternate 0.35 and 0.6 four times a second in the warning, and 0.05 when active; with a `Rise` attribute, set `CFrame = first + Vector3.new(0, rise * f, 0)` where `f` is 0 idle, `part` in the warning and 1 active. Hazards without a cycle are left alone.

- [ ] **Step 7: `Main.client.luau`.**
  - `HazardController.start()` once, after the other controllers.
  - In `refreshHud`, work out `place` from the local character's root position with `PlaceView.at(x, z, workspace:GetServerTimeNow())` (nil without a character) and pass it to `StatusView.build` as the third argument.
  - When `place.regionId` differs from the last one seen: `Atmosphere.set(place.regionId)`, and `Toast.show(place.name .. ": " .. place.hint)`.

- [ ] **Step 8: Add** `Shared.Rules.PlaceView`, `Client.HazardController`, `Client.Atmosphere` ModuleScript assertions to `tests/build.spec.luau`.
- [ ] **Step 9: Run** `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 10: Commit** — `feat: region HUD, hazard visuals, gusts and atmosphere`

---

### Task 9: Play test, checklist and release build

**Files:**
- Modify: `playtest/server/Driver.server.luau`, `README.md`, `docs/backlog.md`, `dist/IsleOfAvarice.rbxlx`
- Create: `docs/playtest/World-checklist.md`

**Interfaces:**
- Consumes: `World.cacheById`, `Sites.hazards`, `Sites.hazardById`, `Geography.strips/place/DROWN_Y`, the `Island.Ground`, `Island.Hazards` folders, the Driver's existing helpers (`check`, `place`, `send`, `mark`, `expectNote`, `waitAlive`).
- Produces: nothing later tasks use.

- [ ] **Step 1: Fix the Driver for the new world.**
  - `M1.1 12 caches tagged` becomes `M1.1 18 caches tagged` and compares with 18.
  - M2.16 places A beside `C012` using `World.cacheById.C012.position` (4 studs short of it on the side facing the island centre, y + 2), not the old literal `(-40, 3, 366)`. Require `World` from `Shared.Catalog`. Opening `C012` now takes 4 seconds, so give every wait that follows a `C012` prompt at least 10 seconds.
  - Update the header comment to say it also runs the world checks.

- [ ] **Step 2: Add a "world" block of checks after the existing world checks**, each printed through `check` with a `W.` prefix. Refill A's health to full before each measurement and read health the way the M3 ability checks do.
  - `W.1` `Island.Ground` has 144 children.
  - `W.2` `Island.Hazards` has as many children as `Sites.hazards` has hazards whose shape kind is not `"region"`, and each child has a `HazardId` attribute naming a hazard.
  - `W.3` lava: place A at the centre of `CinderPool1` for 1.5 seconds; health fell by at least 25.
  - `W.4` spring: place A at the centre of `HushSpring1` with health 40 for 2 seconds; health rose above 50.
  - `W.5` bog: place A at `Geography.place("DrownedFen", 650, 0)` for 1 second; `Humanoid.WalkSpeed` is below 10.
  - `W.6` vent: place A at the centre of `CinderVent1` for one full period plus 0.5 seconds; health fell by at least 30 and less than 60 (one hit, not one per tick).
  - `W.7` drowning: place A at `(-600, -8, 0)`; A is defeated within 3 seconds; then `waitAlive(A)`.
  - End the block by placing A back at `(0, 3, 10)` with full health.

- [ ] **Step 3: Write `docs/playtest/World-checklist.md`** in the style of `docs/playtest/M3-checklist.md` (plain words, "What to do" / "What should happen"). State at the top that the automated run has **not** been done on this branch yet and how to do it (same as M2's checklist). Steps: the region name in the status column and the entering message for each of the nine regions; a bridge and a river fall; the maze and a briar shortcut; the pillar climb and a gust; the Bellows and the lava causeway; the boardwalk and the rotted gap; the tide (walk out at low tide, watch the warning, wait on the Rock); blight and springs; the fortress gates, a shelter and a rockfall hit; a prize cache takes 3 seconds to open; knocking player B into lava with a Strike gives A the claim; fog changes between regions; the Counting Fields are unchanged.

- [ ] **Step 4: `README.md`** — in "How to play-test", point to `docs/playtest/World-checklist.md` after the M1 checklist line. **`docs/backlog.md`** — add a "World" section with the three open questions from the spec's section 10.

- [ ] **Step 5: Run** `bash scripts/check.sh` — Expected: exit 0. Then copy `build/IsleOfAvarice.rbxlx` over `dist/IsleOfAvarice.rbxlx`.
- [ ] **Step 6: Commit** — `test: world play-test checks, checklist and release build`
