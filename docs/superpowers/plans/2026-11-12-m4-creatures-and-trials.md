# M4: Creatures and Trials — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Island beasts roam fixed dens, fight back and pay Coin, XP and Gold Relics to everyone who hurt them; six Wardens offer timed trials (courses, a delivery, hunts, a private duel) and a saved four-step quest; Relics 013–030 can be earned, every one under the scarcity caps.

**Architecture:** As in M1–M3: every rule is a pure Luau module in `src/shared/Rules`, unit-tested with Lune; thin server services own state and validate every request; the client renders and sends requests. M4 first turns the M3 "player or post" special cases into one **fighter registry** (players, posts, creatures by numeric id), so statuses, line of sight, zones, burns and the single `CombatService.damage` pipeline work on ids. Creatures are server-built Humanoid models driven by a pure behaviour rule ticked at 10 Hz; rewards and drop rolls are a pure rule; trials are a pure state machine run by a TrialService. One server function awards every Relic.

**Tech Stack:** Luau (`--!strict`), Rojo 7.7.1, Lune 0.11.1, StyLua 2.6.0 (Luau build), Selene 0.31.0, ProfileStore 1.0.3 (vendored), plain Roblox UI instances.

**Spec:** `docs/superpowers/specs/2026-11-10-isle-of-avarice-design.md` revision 6 — sections 3.9 (creatures), 3.10 (trials and quests), 3.11 (Relics 013–030), plus the sections they touch: 3.1–3.2 (30 slots, scarcity on every reward), 3.4 (defeat by a creature), 3.5 (protections, combat logging), 3.7 (earning cards and Coin), 4.2 (XP from creatures and trials), 4.4 (effects on creatures), 5.4 (the island). Gaps and contradictions found while planning are folded into spec 3.12; this plan follows them. Pre-flight rulings live in the SDD ledger and override the plan where they differ. Not in this plan: Edicts, shops and trading (M5), non-Relic card losses on defeat (M5), parties (M6).

## Global Constraints

- **Original content only.** Names are those of spec 3.9–3.11 including the third creature, **Bogspitter** (renamed from a first draft whose name was one letter from a well-known creature of another game). Relic names R013–R030 are exactly those in Task 2.
- **Tone:** cartoon knock-outs; "defeated", never "killed"; creatures tip over and vanish, no blood or gore.
- Every file under `src/` except `src/server/Vendor` starts with `--!strict`. Files under `src/shared/` use no Roblox APIs and require each other only by relative string. Rule functions never mutate their arguments (exception: `RateLimiter.allow`).
- The server decides everything. A client request names a trial id or an ability slot; the server works out distance, targets, damage, progress and rewards itself. No client position, target, time or result is trusted. In server handlers, no yielding call between reading state and committing it.
- **Fighter ids:** players are their `UserId` (Studio test players are −1, −2, …), training post *i* is `−1000000 − i`, den creature slot *n* is `−2000000 − n`, duel champion *k* is `−3000000 − k`. Never infer a kind from the sign: ask `Fighters.get(id).kind`, `World.postIndex`, `World.creatureIndex` or `World.isChampion`.
- **All damage goes through `CombatService.damage(attackerId, targetId, amount, opts)`** (players, posts and creatures, both directions), ending in `Humanoid:TakeDamage`. Heals set `Humanoid.Health` directly, capped at `MaxHealth`. Only `StatusService` writes `WalkSpeed` (`baseSpeed × Effects.speedFactor`).
- Every Relic reward goes through `SourceService.award`; Coin through `SourceService.addCoin` (which syncs it); XP through `PathService.grant`.
- Saved data and RemoteEvent payloads contain only strings, numbers, booleans and tables with all-string keys or gap-free arrays.
- Clocks: combat, brains, burns and trial run timers use `os.clock()`; trial cooldowns use `os.time()` (real seconds, saved).
- Spec 3.9 creatures: Brinehound 60 health, Bite 8 damage 5 studs every 1.4 s, speed 16, sight 35, 30 XP, 4 Coin, respawn 30 s; Shellback 160, Claw 14 damage 6 studs every 2 s, speed 10, sight 25, 70 XP, 10 Coin, 45 s; Bogspitter 90, Spit shot 30 studs 10 damage every 2.5 s, keeps 15 studs away, speed 12, sight 40, 60 XP, 8 Coin, 45 s; Brine Colossus 900, Slam 25 damage to every player within 10 studs every 4 s, speed 9, sight 45, 500 XP, 60 Coin, 10 min.
- Spec 3.9 dens and behaviour: four Brinehound packs of 3, three Shellback dens of 2, three Bogspitter dens of 2, one Brine Colossus; each respawns at its den on its own timer. Wanders within 12 studs of its den; chases the nearest player it can see within its sight range; never enters Tallyport; gives up when its target is more than 60 studs from the den, enters the safe zone or is defeated (walks home, heals to full); does not chase a player whose respawn shield is up.
- Spec 3.9 fighting: the Strike and every ability hit creatures with the same reach, aim and line-of-sight rules; slow, root, burn, pull, knockback and taunt work on them (a taunted creature chases the taunter). Hitting one never Marks; the new-player shield does not stop it; it ends your respawn shield. Creature damage follows immune, reduction, shield, then health; Rebuke reflects it; the safe zone and the respawn shield block it. Combat logging counts only damage between players. Defeat by a creature: respawn in Tallyport, no blind claim, no XP for anyone.
- Spec 3.9 rewards: contributors = every player who damaged it in the last 30 seconds; each gets the full Coin and XP and rolls the drop table on their own; XP goes to the Path that player dealt the most damage with (the Strike counts as the Calling; a tie goes to the Calling); no Calling = Coin only.
- Spec 3.10 trials (kind, goal, time, Relic, Coin, XP): Tidewalk course 6 markers in order 60 s R013 30 120; Gullstep Climb course 8 markers 75 s R014 40 160; Salt Post delivery to the Harbour Warden 70 s R015 35 140; Cull the Pack hunt 5 Brinehounds 120 s R016 40 180; Shellbreaker hunt 3 Shellbacks 150 s R024 70 300; The Tallyman's Duel duel 90 s R025 80 350.
- Spec 3.10 rules: one trial at a time; fails on timeout, defeat or leaving; retry after 30 s (failed) or 5 minutes (passed); trial XP goes to the Calling; Coin is paid even when the Relic is sealed; sealed → skipped, no free slot → lost with a message; hunts count creatures the player contributed to. Drowned Tallyman: only its duellist can hurt it or be hurt by it, 300 health, Strike-like hits of 12 damage every 1.2 s at 7 studs, speed 15, every 8 s a Lunge (dash 12 studs, 18 damage). Quest **The Unpaid Debt**: Tidewalk, Salt Post, The Tallyman's Duel in that order, then contribute to defeating the Brine Colossus; reward R027, 150 Coin, 600 XP; progress saved; out-of-order steps do not count.
- Spec 3.11: 013–016 Silver trials; 017–018 Silver caches in hard-to-reach spots; 019 Gold Brinehound 2% per contributor; 020 Gold Shellback 5%; 021 Gold Bogspitter 5%; 022 Gold Brine Colossus 100%; 023 Gold Brine Colossus 20%; 024–025 Gold trials; 026 Gold cache on the highest point; 027 Platinum quest; 028–030 Copper caches. Every drop and reward obeys scarcity.
- Plan values (not in the spec, fixed here): brain tick 0.1 s; home radius 3; creatures stop 4 studs outside Tallyport; melee creatures stop at 0.6 × reach; Drowned Tallyman sight 60, leashed 60 studs from its arena; marker touch radius 6; delivery radius 10; a trial is accepted within 15 studs of its Warden; reflected damage counts as Bulwark.
- `bash scripts/check.sh` must pass before every commit (it formats and lints `src`, `tests` and `playtest`). Work happens on branch `feat/m4-creatures` (based on `feat/m3-paths` at `e1faa26`).

## Review Focus

1. **Hostile trial requests** — `TrialAccept` with an unknown id, a number, `nil`, a table, an empty string; from 16+ studs away; while another trial runs; during a cooldown; before data loads: each refused with a code, nothing starts. Pinned in Task 6 (`TrialRun.start`) and by reading in Task 10.
2. **Corrupt saved trial data** (unknown trial ids, NaN/negative/huge cooldowns, a quest step of −1, 4, 1.5, NaN or "2", wrong types, nil): load yields a valid record, never an error, and no trial is ever locked longer than 300 s. Pinned in Task 6 (`TrialRun.sanitize`, `cooldownLeft`).
3. **Scarcity and free slots on every reward path** — creature drops (several contributors racing for a capped copy), trial Relics, the quest Relic: a sealed Relic is never given, a full or locked Ledger loses it with a message, Coin and XP are still paid. Pinned in Task 5 (`Rewards.awards`, `Sources.give`) and the play test (Task 12).
4. **PvE stays PvE, and ids never get confused** — hitting a creature never Marks and never opens a claim; a creature's defeat of a player gives no claim and no XP, and never steals a player's kill or combat-log credit; creature damage is blocked by the safe zone and the respawn shield but not by the new-player shield; a player in Tallyport cannot hurt creatures; only the duellist and their champion can touch each other; no creature id is ever resolved to a Studio test player. Pinned in Task 3 (id ranges), Task 7 (`Protection.creatureCanHit`, `Protection.canHitCreature`, `Combat.creditFor` with the creature log), by reading in Tasks 1 and 9, and the play test.
5. **Farming and leash abuse** — only hits in the last 30 s make a contributor; a creature walking home cannot be hurt, then heals and forgets its contributors; it never enters Tallyport, never targets a respawn-shielded or safe-zone player, and gives up past 60 studs from its den. Pinned in Task 4 (`CreatureBrain.tick`, `outsideTown`), Task 5 (`Rewards.contributors`) and by reading in Task 9 (immune while returning).

## File Map

```
src/server/Fighters.luau                 NEW  fighter registry: players, posts, creatures by id
src/server/Sight.luau                    + target-model rule, Creatures folder, move (from AbilityService)
src/server/Fx.luau                       NEW  shot rays and rings (from AbilityService)
src/server/StatusService.luau            + statuses keyed by fighter id, applyHit, base speed per fighter
src/server/CombatService.luau            + damage by fighter ids, creature branches, creature hit log, onHit
src/server/AbilityService.luau           + hits through the registry
src/shared/Types.luau                    + CreatureKind, Trial, TrialRecord, Den, Ledge, PlayerData.trials
src/shared/Net.luau                      + TrialOffer, TrialAccept, TrialSync, CoinSync
src/shared/Catalog/Relics.luau           + R013–R030
src/shared/Catalog/Creatures.luau        NEW  five creature kinds
src/shared/Catalog/Trials.luau           NEW  six trials and the quest
src/shared/Catalog/Messages.luau         + M4 messages
src/shared/Catalog/World.luau            + caches 017/018/026/028–030, climbs, dens, Wardens, courses, ids
src/shared/Rules/Effects.luau            + applyHit
src/shared/Rules/CreatureBrain.luau      NEW  wander / chase / attack / return
src/shared/Rules/Rewards.luau            NEW  contributors, XP Path, drop rolls under scarcity
src/shared/Rules/Sources.luau            + give
src/shared/Rules/TrialRun.luau           NEW  trial state machine, cooldowns, quest, sanitize
src/shared/Rules/TrialView.luau          NEW  offer window and trial HUD text
src/shared/Rules/Protection.luau         + creatureCanHit, canHitCreature
src/shared/Rules/Combat.luau             + creditFor with the creature log
src/server/DataService.luau              + trials field
src/server/SourceService.luau            + award, addCoin, held, CoinSync
src/server/PathService.luau              + Calling cost through addCoin
src/server/WorldBuilder.luau             + climbs, Wardens, markers, harbour, arena, dens
src/server/CreatureService.luau          NEW
src/server/TrialService.luau             NEW
src/server/Main.server.luau              + start order
src/client/TrialUI.luau                  NEW  offer window, trial HUD, next-marker beacon
src/client/CreatureFx.luau               NEW  hide other duellists' champions, hit flash
src/client/StatusHUD.luau                + Coin line
src/client/ClaimUI.luau                  + 30-slot grid
src/client/Toast.luau                    + short queue
src/client/Main.client.luau              + wiring
playtest/server/Driver.server.luau       + M4 checks
playtest/client/Agent.client.luau        + M4 ops and UI snapshot
docs/playtest/M4-checklist.md            NEW
```

---

### Task 1: Server refactor — the fighter registry

M3 code knows only "a player in `byId`" or "a post": hits on anything else are dropped (`AbilityService` `applyHits`, the Strike in `CombatService`), statuses are keyed by `Player`, zones loop `Players:GetPlayers()` and catalog post positions, burns resolve `Players:GetPlayerByUserId`, the movement loop hard-codes `WalkSpeed` 16, and `postParts()` rescans tags on every hit. This task changes **no behaviour**; it gives every target an id so creatures (Task 9) slot in.

**Files:**
- Create: `src/server/Fighters.luau`
- Modify: `src/server/Sight.luau`, `src/server/StatusService.luau`, `src/server/CombatService.luau`, `src/server/AbilityService.luau`, `src/server/Main.server.luau`, `src/shared/Rules/Effects.luau`, `tests/effects.spec.luau`, `tests/build.spec.luau`, `playtest/server/Driver.server.luau` (call sites only)

**Interfaces:**
- Consumes: `World.postIndex`, `World.POST_ID_BASE`, `Combat.Fighter`, `Sight.*` (from the M3 fix round), `Effects.*`.
- Produces:
```luau
-- Fighters.luau: requires only Roblox services and shared modules
export type Kind = "player" | "post" | "creature"
export type Entry = {
	id: number, kind: Kind,
	player: Player?,      -- kind "player"
	model: Instance?,     -- post part or creature model; a player's is read live from player.Character
	baseSpeed: number,    -- WalkSpeed with no slow or root: players 16, posts 0, creatures their catalog speed
	owner: number?,       -- creatures only: the one fighter id that may hit it or be hit by it (duel champion)
}
Fighters.start(): ()                                -- players (id = UserId) on join/leave; every TrainingPost part with a valid PostId, now and when tagged later
Fighters.add(entry: Entry): ()                     -- replaces any entry with the same id
Fighters.remove(id: number): ()
Fighters.get(id: number): Entry?
Fighters.model(id: number): Instance?              -- character, post part or creature model
Fighters.body(id: number): (Humanoid?, BasePart?)  -- living Humanoid and root of a player or creature
Fighters.fighter(id: number): Combat.Fighter?      -- position and look from the root (posts: the part, look +z); health for players and creatures
Fighters.list(viewer: number): { Combat.Fighter }  -- every other living fighter the viewer may fight, posts included
Fighters.mayFight(a: number, b: number): boolean   -- false for a == b, for a post attacker, and when either side has an owner that is not the other

-- Sight.luau
Sight.obstruction(from: Vector3, to: Vector3, target: Instance?): Vector3?   -- a first hit on `target` or its descendants is clear (was: postId)
Sight.inSight(from: Vector3, to: Vector3, target: Instance?): boolean
Sight.filter(from: Vector3, fighters: { Combat.Fighter }): { Combat.Fighter }  -- target = Fighters.model(id)
-- rayParams also excludes workspace.Creatures when it exists

-- StatusService.luau (keyed by fighter id)
type DamageFn = (attackerId: number, targetId: number, amount: number, opts: DamageOpts?) -> boolean
StatusService.start(damage: DamageFn): ()                    -- hitPost parameter removed: posts go through damage
StatusService.get(id: number): Effects.Status
StatusService.update(id: number, fn: (Effects.Status, number) -> Effects.Status): ()   -- no entry → nothing
StatusService.reset(id: number): ()                          -- fresh status (players on join/respawn; creatures on spawn)
StatusService.drop(id: number): ()                           -- forget the status, burn Path and zones owned by id
StatusService.applyHit(attackerId: number, targetId: number, ability: Ability): ()   -- Effects.applyHit; remembers ability.path as the burn's Path
StatusService.addZone(ownerId: number, zone: Casting.Zone, path: string): ()

-- CombatService.luau
type DamageOpts = { reflected: boolean?, tick: boolean?, passive: boolean?, path: string? }
CombatService.damage(attackerId: number, targetId: number, amount: number, opts: DamageOpts?): boolean
CombatService.flash(id: number): ()                          -- HitFx to every client, any fighter id
-- removed: CombatService.fighters, isPost, hitPost (post XP is now private to damage)

-- Effects.luau
Effects.applyHit(s: Status, ability: Ability, byId: number, now: number): Status   -- burn, root, slow, taunt, in that order
```
- **`damage` dispatches on the two entries' kinds** (`Fighters.get`, both must exist and `Fighters.mayFight`):
  - player → post: post XP exactly as M3's `hitPost` (10 base, once per 0.5 s per post per attacker, flash) to `opts.path`, where `"Strike"` means the attacker's Calling and `""` pays nothing; returns true (posts take no damage and ignore effects).
  - player → player: the M3 pipeline unchanged (protections, `passive`, respawn-shield end, Mark, empower, `resolveDamage`, hit log before `TakeDamage`, flash, reflect back with `{ reflected = true }`).
  - any pair involving a creature: returns false (Task 9 fills these branches in).
- **StatusService:** players get `reset(UserId)` on join and on `CharacterAdded`, `drop` on leave. The movement loop runs over every registry entry with a living body: `WalkSpeed = baseSpeed × speedFactor`, written only when different; jump blocking while rooted stays players-only. Burns call `damage(burnBy, id, dps, { tick = true, path = <remembered burn Path> })` when `Fighters.get(burnBy)` exists. Zones damage every other fighter inside (players, creatures, posts by their part) with `{ tick = true, passive = <not inside at placement>, path }` and refresh the slow only on non-post targets whose damage landed; `inside` is keyed by fighter id.
- **Strike:** candidates `Sight.filter(root, Fighters.list(UserId))`, target `Combat.pickTarget(...)`, then `damage(UserId, targetId, STRIKE_DAMAGE, { path = "Strike" })`.
- **AbilityService:** `others = Fighters.list(player.UserId)`; `inSight` passes `Fighters.model(id)`; each hit `if CombatService.damage(player.UserId, id, hit.damage, { path = ability.path }) then connected = true; StatusService.applyHit(...); pull/knockback on Fighters.body(id) end`. Self effects use `StatusService.update(ally.UserId, ...)`.

- [ ] **Step 1: Write the failing test.** In `tests/effects.spec.luau` (requiring the Abilities catalog) add:
```luau
local ab = Abilities.byId
T.eq({ Effects.burnTick(Effects.applyHit(Effects.new(), ab.cinder_bolt, 7, 0), 1) }, { 3, 7 })
T.truthy(Effects.isRooted(Effects.applyHit(Effects.new(), ab.bog_snare, 7, 0), 1))
T.eq(Effects.speedFactor(Effects.applyHit(Effects.new(), ab.undertow, 7, 0), 1), 0.7)
T.eq(Effects.tauntedBy(Effects.applyHit(Effects.new(), ab.challenge, 7, 0), 1), 7)
T.eq(Effects.applyHit(Effects.new(), ab.gust_blade, 7, 0), Effects.new())   -- no on-hit status
```
- [ ] **Step 2: Run** `lune run tests/run` — Expected: FAIL (`applyHit` missing). **Step 3: Implement** `Effects.applyHit` (M3's `applyHitStatuses` body, made pure). **Run** — Expected: PASS.
- [ ] **Step 4: Implement** `Fighters`, then switch `Sight`, `StatusService`, `CombatService`, `AbilityService` to it as above. `Main.server.luau`: `Fighters.start()` right after `WorldBuilder.build`; `StatusService.start(CombatService.damage)`. Driver: `StatusService.get(B)` → `StatusService.get(B.UserId)` (and the same for `update`). Add `Server.Fighters` and `Server.Sight` to `tests/build.spec.luau`.
- [ ] **Step 5: Run** `bash scripts/check.sh` — Expected: exit 0 (every M1–M3 test unchanged). **Commit** — `refactor: one fighter registry for players and posts`
- [ ] **Step 6: The controller runs the existing play test in Studio** (2 players) — Expected: `DONE` with `failed=0`, the same checks as before the refactor.

Pinned by reading: no code outside `Fighters` calls `Players:GetPlayerByUserId` on a fighter id; no `WalkSpeed` write outside `StatusService`; every damage, burn and zone tick goes through `CombatService.damage`.

---

### Task 2: Catalog — Relics 013–030, creatures, trials, messages, remotes, types

**Files:**
- Modify: `src/shared/Types.luau`, `src/shared/Net.luau`, `src/shared/Catalog/Relics.luau`, `src/shared/Catalog/Messages.luau`, `tests/catalog.spec.luau`, `tests/messages.spec.luau`, `tests/net.spec.luau`, `tests/ledger.spec.luau`, `tests/ledger_view.spec.luau`, `tests/claim_view.spec.luau`, `tests/blind_claim.spec.luau`
- Create: `src/shared/Catalog/Creatures.luau`, `src/shared/Catalog/Trials.luau`
- Test: `tests/creatures_catalog.spec.luau`, `tests/trials_catalog.spec.luau`

**Interfaces:**
- Produces, in `Types.luau`:
```luau
export type Drop = { relicId: CardId, chance: number }
export type CreatureKind = {
	id: string, name: string, health: number, speed: number, sight: number,
	attack: { kind: "melee" | "shot" | "slam", name: string, damage: number, range: number, interval: number },
	keepAway: number?, lunge: { distance: number, damage: number, interval: number }?,
	xp: number, coin: number, respawn: number, drops: { Drop },
	height: number, color: { r: number, g: number, b: number },   -- look only
}
export type TrialKind = "course" | "delivery" | "hunt" | "duel"
export type Trial = { id: string, name: string, warden: string, kind: TrialKind, goal: string, seconds: number,
	relicId: CardId, coin: number, xp: number, creature: string?, count: number? }
export type TrialRecord = { cooldowns: { [string]: number }, questStep: number }   -- trial id -> os.time() it may be taken again
export type Den = { kind: string, count: number, position: Vec3 }
export type Ledge = { x: number, z: number, size: number, top: number }
-- PlayerData gains: trials: TrialRecord
```
- `Creatures.list` (order below), `Creatures.byId`. `Trials.list` (spec order), `Trials.byId`, `Trials.quest = { name = "The Unpaid Debt", steps = { "tidewalk", "salt_post", "tallymans_duel", "colossus" }, relicId = "R027", coin = 150, xp = 600 }`.

| creature id | name | health | attack (kind, name, damage, range, interval) | speed | sight | xp | coin | respawn | extra / drops |
|---|---|---|---|---|---|---|---|---|---|
| brinehound | Brinehound | 60 | melee Bite 8 5 1.4 | 16 | 35 | 30 | 4 | 30 | R019 0.02 |
| shellback | Shellback | 160 | melee Claw 14 6 2 | 10 | 25 | 70 | 10 | 45 | R020 0.05 |
| bogspitter | Bogspitter | 90 | shot Spit 10 30 2.5 | 12 | 40 | 60 | 8 | 45 | keepAway 15; R021 0.05 |
| brine_colossus | Brine Colossus | 900 | slam Slam 25 10 4 | 9 | 45 | 500 | 60 | 600 | R022 1, R023 0.2 |
| drowned_tallyman | Drowned Tallyman | 300 | melee Strike 12 7 1.2 | 15 | 60 | 0 | 0 | 0 | lunge {12, 18, 8}; no drops |

| trial id | name | warden | kind | goal | s | relic | coin | xp | hunt |
|---|---|---|---|---|---|---|---|---|---|
| tidewalk | Tidewalk | Harbour Warden | course | Touch 6 markers in order. | 60 | R013 | 30 | 120 | |
| gullstep_climb | Gullstep Climb | Cliff Warden | course | Touch 8 markers in order. | 75 | R014 | 40 | 160 | |
| salt_post | Salt Post | Saltworks Warden | delivery | Carry the parcel to the Harbour Warden. | 70 | R015 | 35 | 140 | |
| cull_the_pack | Cull the Pack | Pack Warden | hunt | Defeat 5 Brinehounds. | 120 | R016 | 40 | 180 | brinehound × 5 |
| shellbreaker | Shellbreaker | Shell Warden | hunt | Defeat 3 Shellbacks. | 150 | R024 | 70 | 300 | shellback × 3 |
| tallymans_duel | The Tallyman's Duel | Duel Warden | duel | Defeat the Drowned Tallyman. | 90 | R025 | 80 | 350 | |

Relics (tier from spec 3.11; descriptions in the existing voice, the Hoarder as "they"):

| id | name | description |
|---|---|---|
| R013 | Low-Tide Tally Stick | Notched at every low tide, when the Hoarder walked the shore counting what the sea gave back. |
| R014 | Gull-Perch Spyglass | From the cliff tops the Hoarder watched every ship that still owed them money. |
| R015 | Unopened Salt Letter | A demand for payment, sealed in salt wax and never delivered until now. |
| R016 | Brinehound Collar | Brass-studded and far too heavy for a pet; the Hoarder's hounds wore it to collect debts. |
| R017 | Rook's-Nest Purse | Stuffed with coins and hidden where only the gulls could reach it. |
| R018 | Cliffside Tithe Box | Fishers paid their dues into it, and the climb kept thieves away. |
| R019 | Brine-Fang Charm | A hound's tooth set in gold, worn by the Hoarder's chief collector. |
| R020 | Gilded Carapace Plate | The Hoarder had their shellbacks gilded, so even the beasts would be worth something. |
| R021 | Bog Pearl | Spat up from the mud, it shines like interest on a loan nobody repaid. |
| R022 | Colossus Heartstone | The ballast that kept the Brine Colossus bound to the Hoarder's will. |
| R023 | Drowned Treasury Key | It opens the sea vault where the Hoarder kept what they could not count. |
| R024 | Shellbreaker's Mallet | Bought to crack shellbacks open, and billed to their owners afterwards. |
| R025 | Tallyman's Abacus | The Drowned Tallyman still counts on it, though every bead is a debt unpaid. |
| R026 | Lookout's Gilded Horn | Blown from the island's peak whenever a debtor tried to sail away. |
| R027 | Writ of the Unpaid Debt | The Hoarder's last demand, signed in platinum ink and finally settled. |
| R028 | Chipped Salt Cellar | The Hoarder salted every meal to make it last, and charged guests for the pinch. |
| R029 | Rusted Debtor's Link | One link from the chain that kept small debtors working the docks. |
| R030 | Waterlogged IOU | The ink has run, but the Hoarder still expects it paid. |

Net (names equal keys): `TrialOffer` server → one client `(offer: TrialView.OfferView)`; `TrialAccept` client → server `(trialId: string)`; `TrialSync` server → one client `(state: TrialView.HudState?, questStep: number)`; `CoinSync` server → one client `(coin: number)`. `HitFx` now carries any fighter id (comment only).

Messages (exact copy):

| code | text |
|---|---|
| CREATURE_DEFEATED | {creature} defeated! +{coin} Coin. |
| REWARD_SEALED | {name} is sealed on this server, so you did not get it. |
| REWARD_LOST | Your free slots are full, so {name} was lost. |
| REWARD_LOCKED | Your Ledger is locked, so {name} was lost. |
| TRIAL_STARTED | {name} has begun! |
| TRIAL_PASSED | You passed {name}! +{coin} Coin. |
| TRIAL_FAILED_TIME | Out of time: {name} failed. |
| TRIAL_FAILED_DEFEAT | You were defeated: {name} failed. |
| TRIAL_BUSY | Finish your current trial first. |
| TRIAL_COOLDOWN | You can try {name} again in {seconds} seconds. |
| MARKER_REACHED | Marker {n} of {total}. |
| HUNT_PROGRESS | {n} of {total} defeated. |
| QUEST_STEP | The Unpaid Debt: step {n} of 4 done. |
| QUEST_COMPLETE | The Unpaid Debt is paid! +{coin} Coin. |

- [ ] **Step 1: Write the failing tests.** `tests/catalog.spec.luau` becomes "30 relics, slots 1..30" (same per-relic checks) plus:
```luau
local expected = {}
for i = 13, 18 do expected[i] = "Silver" end
for i = 19, 26 do expected[i] = "Gold" end
expected[27] = "Platinum"
for i = 28, 30 do expected[i] = "Copper" end
for i = 13, 30 do T.eq(Relics.list[i].tier, expected[i], Relics.list[i].id) end
-- every name unique
```
`tests/creatures_catalog.spec.luau`: every row of the creature table as `T.eq` on the fields (e.g. `T.eq(Creatures.byId.brinehound.attack, { kind = "melee", name = "Bite", damage = 8, range = 5, interval = 1.4 })`, `T.eq(Creatures.byId.brine_colossus.drops, { { relicId = "R022", chance = 1 }, { relicId = "R023", chance = 0.2 } })`, `T.eq(Creatures.byId.bogspitter.keepAway, 15)`, `T.eq(Creatures.byId.drowned_tallyman.lunge, { distance = 12, damage = 18, interval = 8 })`); every drop names a known Relic; ids equal `byId` keys. `tests/trials_catalog.spec.luau`: every row of the trial table; every `relicId` known; `T.eq(Trials.quest.steps, { "tidewalk", "salt_post", "tallymans_duel", "colossus" })`.
Add the 14 codes to `tests/messages.spec.luau` plus `T.eq(Messages.format("TRIAL_PASSED", { name = "Tidewalk", coin = "30" }), "You passed Tidewalk! +30 Coin.")`; the 4 names to `tests/net.spec.luau`.
Fix tests that assumed 12 Relics: `ledger_view.spec` (`"1 / 30"`, 30 slots, `"30 / 30"`, `"0 / 30"`), `claim_view.spec` (30 slots), `blind_claim.spec` (bad slot 13 → 31), `ledger.spec` isComplete (use `Relics.list[Relics.count].id` instead of `"R012"`, label "all 30").
- [ ] **Step 2: Run** — Expected: FAIL. **Step 3: Implement.** **Step 4: Run** `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 5: Commit** — `feat: M4 catalog — Relics 013–030, creatures, trials`

---

### Task 3: World data — new caches, climbs, dens, Wardens, courses, creature ids

**Files:**
- Modify: `src/shared/Catalog/World.luau`, `tests/world.spec.luau`

**Interfaces:**
- Consumes: `Types.Den`, `Types.Ledge`, `Creatures`, `Trials`, `Relics`.
- Produces:
```luau
World.caches            -- C001–C012 unchanged, plus C017, C018, C026, C028, C029, C030 (cache C0NN holds R0NN)
World.climbs: { [string]: { Ledge } }     -- keys "C017", "C018", "C026", "gullstep_climb"; ledges in climbing order
World.dens: { Den }
World.CREATURE_ID_BASE = -2000000
World.creatureSlots: { { id: number, den: number, kind: string } }   -- den order, then member order; slot n has id CREATURE_ID_BASE - n
World.creatureIndex(id: number): number?
World.CHAMPION_ID_BASE = -3000000
World.isChampion(id: number): boolean     -- a whole number <= CHAMPION_ID_BASE - 1
World.wardens: { [string]: Vec3 }         -- trial id -> Warden position (ground, y = 0)
World.harbour: Vec3                       -- the Harbour Warden: the same position as wardens.tidewalk
World.courses: { [string]: { Vec3 } }     -- course trial id -> markers in order, at standing-root height (surface + 3)
World.duelArena: Vec3
```
Pinned positions (checked against every constraint below):
- New caches: C017 (280, 21, −300), C018 (−330, 25, 20), C026 (−60, 37, −330), C028 (160, 1, 60), C029 (−160, 1, −120), C030 (60, 1, 170).
- Dens (kind × count at position): brinehound × 3 at (200, 0, −220), (−230, 0, −60), (−30, 0, 250), (−330, 0, 140); shellback × 2 at (−250, 0, 30), (−120, 0, −230), (250, 0, 330); bogspitter × 2 at (−20, 0, −180), (−330, 0, −80), (150, 0, −330); brine_colossus × 1 at (−300, 0, 300).
- Wardens: tidewalk (330, 0, −20), gullstep_climb (−250, 0, −260), salt_post (−180, 0, 300), cull_the_pack (100, 0, −170), shellbreaker (200, 0, −20), tallymans_duel (100, 0, 300). Duel arena (120, 0, 330).
- Tidewalk markers: (330, 3, 20), (320, 3, 70), (300, 3, 110), (280, 3, 160), (300, 3, 210), (320, 3, 250).
- Climb ledges and the 8 Gullstep markers (near the Cliff Warden) are the implementer's to place within the rules the tests pin. The top ledges of C017, C018, C026 are at 20, 24 and 36.

- [ ] **Step 1: Write the failing tests** (rewrite the "twelve caches" and "every Relic has a cache" tests):
```luau
-- 18 caches: ids, relic ids, on the island (|x|, |z| <= 380), outside Tallyport
local ids = {}
for _, c in World.caches do table.insert(ids, c.id) end
T.eq(ids, { "C001", "C002", "C003", "C004", "C005", "C006", "C007", "C008", "C009", "C010", "C011", "C012", "C017", "C018", "C026", "C028", "C029", "C030" })
-- every Relic has a source; spot checks follow spec 3.11
local source = {}
for _, c in World.caches do source[c.relicId] = "cache" end
for _, t in Trials.list do source[t.relicId] = "trial" end
for _, k in Creatures.list do for _, d in k.drops do source[d.relicId] = "creature" end end
source[Trials.quest.relicId] = "quest"
for _, r in Relics.list do T.truthy(source[r.id], r.id) end
T.eq({ source.R017, source.R026, source.R019, source.R023, source.R024, source.R027, source.R030 }, { "cache", "cache", "creature", "creature", "trial", "quest", "cache" })
-- climbs: the first ledge top <= 4; each next rises <= 4 and its edge is <= 4 studs from the last
for name, ledges in World.climbs do
	T.truthy(ledges[1].top <= 4, name)
	for i = 2, #ledges do
		local a, b = ledges[i - 1], ledges[i]
		T.truthy(b.top - a.top <= 4, `{name} {i} rise`)
		T.truthy(math.max(math.abs(b.x - a.x), math.abs(b.z - a.z)) - (a.size + b.size) / 2 <= 4, `{name} {i} gap`)
	end
end
-- C017, C018, C026 sit on their last ledge (y = top + 1, at least 1 stud inside its edge) and are >= 21 up,
-- so the 15-stud collect distance cannot be met from the ground; C026's ledge is the highest of every climb
-- courses: tidewalk 6 markers, all y = 3; gullstep_climb 8, the first on the ground (y = 3), every later one
-- 3 above a gullstep ledge top and inside it, never lower than the one before, the last >= 27
T.eq(World.harbour, World.wardens.tidewalk)
-- one Warden per trial id; Wardens and markers more than 60 from the origin
-- dens: 4 × 3 brinehound, 3 × 2 shellback, 3 × 2 bogspitter, 1 × 1 brine_colossus; each den >= 130 from the
-- origin, |x|, |z| <= 340, >= 80 from every other den, cache, post, Warden, course marker, the duel arena and the
-- play test's open-ground spots (150, 0, 150) and (-150, 0, 150), and >= 60 from every climb ledge
-- ids
T.eq(#World.creatureSlots, 25)
T.eq(World.creatureSlots[1], { id = -2000001, den = 1, kind = "brinehound" })
T.eq(World.creatureSlots[25], { id = -2000025, den = 11, kind = "brine_colossus" })
T.eq({ World.creatureIndex(-2000025), World.creatureIndex(-2000026), World.creatureIndex(-1), World.creatureIndex(-2000001.5) }, { 25, nil, nil, nil })
T.eq({ World.isChampion(-3000001), World.isChampion(-3000000), World.isChampion(-1), World.isChampion(0 / 0) }, { true, false, false, false })
```
- [ ] **Step 2: Run** — Expected: FAIL. **Step 3: Implement** (the cache layout becomes a list of `{ slot, x, y, z }`). **Step 4: Run** `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 5: Commit** — `feat: M4 world data — dens, Wardens, courses, climbs`

---

### Task 4: Creature behaviour rules

**Files:**
- Create: `src/shared/Rules/CreatureBrain.luau`
- Test: `tests/creature_brain.spec.luau`

**Interfaces:**
- Consumes: `Types.CreatureKind`, `World.townRadius`, `Combat.STRIKE_MAX_HEIGHT`.
- Produces:
```luau
CreatureBrain.TICK_SECONDS = 0.1
CreatureBrain.WANDER_RADIUS = 12
CreatureBrain.LEASH = 60
CreatureBrain.HOME_RADIUS = 3
CreatureBrain.TOWN_MARGIN = 4
CreatureBrain.STOP_FRACTION = 0.6
export type Brain = { mode: "wander" | "chase" | "return", targetId: number, nextAttackAt: number,
	nextLungeAt: number, nextWanderAt: number, wanderTo: Vec3? }
export type Seen = { id: number, position: Vec3, visible: boolean, valid: boolean }
-- valid: alive, outside the safe zone, no respawn shield (the server decides); visible: clear line of sight
export type Body = { position: Vec3, den: Vec3, rooted: boolean }
export type Action = { kind: "attack" | "lunge", targetId: number }
export type Decision = { brain: Brain, moveTo: Vec3?, faceTo: Vec3?, action: Action?, home: boolean }
CreatureBrain.new(): Brain     -- wander, targetId 0, every time 0, no wanderTo
CreatureBrain.tick(kind: CreatureKind, brain: Brain, body: Body, seen: { Seen }, taunter: number?, provoker: number?, now: number, rng: () -> number): Decision
CreatureBrain.outsideTown(point: Vec3): Vec3   -- a point within townRadius + TOWN_MARGIN is pushed out along its bearing from the origin (+x for the origin itself)
```
Rules in order (all distances horizontal; a **target** is a `Seen` that is `valid` and within `LEASH` of the den):
1. **return:** ignore everyone; `moveTo = den`; within `HOME_RADIUS` of the den → `mode = "wander"`, `home = true`, `nextWanderAt = now`, `moveTo = nil`.
2. **chase:** give up (`mode = "return"`, `targetId = 0`, `moveTo = den`) when the current target is missing from `seen`, not valid, or past the leash. Otherwise a `taunter` that is a target replaces it.
3. **wander:** pick `taunter` if it is a target; else `provoker` if it is a target; else the nearest target that is `visible` and within `kind.sight` of the creature → `mode = "chase"`. With none: when `now >= nextWanderAt`, draw `angle = rng() × 2π`, `r = rng() × WANDER_RADIUS`, `wanderTo = den + (cos(angle) × r, 0, sin(angle) × r)`, `nextWanderAt = now + 3 + rng() × 3` (rng drawn in that order); `moveTo = wanderTo`.
4. **in chase:** `faceTo` = target position. Movement: with `keepAway` and distance < keepAway → the point keepAway from the target on the line through the creature; with `keepAway` and distance ≤ attack range → stand (`moveTo = nil`); otherwise `moveTo` = target position unless distance ≤ `range × STOP_FRACTION` (stand). Action: distance ≤ `attack.range` and vertical gap ≤ `STRIKE_MAX_HEIGHT` and `now >= nextAttackAt` → attack, `nextAttackAt = now + interval`; else with `lunge`, not rooted, `now >= nextLungeAt`, range < distance ≤ `lunge.distance` → lunge, `nextLungeAt = now + lunge.interval`.
5. Every `moveTo` passes through `outsideTown`.

- [ ] **Step 1: Write the failing tests `tests/creature_brain.spec.luau`** (`B = CreatureBrain`; `hound = Creatures.byId.brinehound`; `DEN = { x = 200, y = 0, z = 0 }`; `body(x, z, rooted?, den?)`; `seen(id, x, z, overrides?)` is visible and valid at y 0; `seq(...)` returns the values in turn, then 0; `near(a, b)` within 1e-6; `chasing(id)` is `B.new()` with mode "chase" and that target):
```luau
T.eq(B.new(), { mode = "wander", targetId = 0, nextAttackAt = 0, nextLungeAt = 0, nextWanderAt = 0 })
-- wander: angle, radius, delay
local w = B.tick(hound, B.new(), body(200, 0), {}, nil, nil, 10, seq(0.25, 0.5, 0))
T.truthy(near(w.moveTo, { x = 200, y = 0, z = 6 })); T.eq({ w.brain.mode, w.brain.nextWanderAt }, { "wander", 13 })
T.truthy(near(B.tick(hound, w.brain, body(200, 3), {}, nil, nil, 12, seq(0.9, 0.9)).moveTo, { x = 200, y = 0, z = 6 }))
-- 200 draws from math.random: every wanderTo within 12 of the den
-- noticing
T.eq(B.tick(hound, B.new(), body(200, 0), { seen(7, 230, 0) }, nil, nil, 0, seq()).brain, { mode = "chase", targetId = 7, nextAttackAt = 0, nextLungeAt = 0, nextWanderAt = 0 })
T.eq(B.tick(hound, B.new(), body(200, 0), { seen(7, 236, 0) }, nil, nil, 0, seq()).brain.mode, "wander")   -- sight 35
T.eq(B.tick(hound, B.new(), body(200, 0), { seen(7, 220, 0, { visible = false }) }, nil, nil, 0, seq()).brain.mode, "wander")
T.eq(B.tick(hound, B.new(), body(200, 0), { seen(7, 220, 0, { valid = false }) }, nil, nil, 0, seq()).brain.mode, "wander")
T.eq(B.tick(hound, B.new(), body(200, 0), { seen(7, 225, 0), seen(8, 215, 0) }, nil, nil, 0, seq()).brain.targetId, 8)
-- chasing and biting (reach 5, every 1.4 s, stands within 3)
local c = B.tick(hound, chasing(7), body(200, 0), { seen(7, 220, 0) }, nil, nil, 10, seq())
T.eq({ c.moveTo, c.faceTo, c.action }, { { x = 220, y = 0, z = 0 }, { x = 220, y = 0, z = 0 }, nil })
local bite = B.tick(hound, chasing(7), body(200, 0), { seen(7, 204, 0) }, nil, nil, 10, seq())
T.eq({ bite.action, bite.brain.nextAttackAt, bite.moveTo }, { { kind = "attack", targetId = 7 }, 11.4, { x = 204, y = 0, z = 0 } })
T.eq(B.tick(hound, bite.brain, body(200, 0), { seen(7, 204, 0) }, nil, nil, 11.3, seq()).action, nil)
T.eq(B.tick(hound, bite.brain, body(200, 0), { seen(7, 204, 0) }, nil, nil, 11.4, seq()).action, { kind = "attack", targetId = 7 })
T.eq(B.tick(hound, chasing(7), body(200, 0), { seen(7, 202.5, 0) }, nil, nil, 10, seq()).moveTo, nil)
T.eq(B.tick(hound, chasing(7), body(200, 0), { seen(7, 204, 0, { position = { x = 204, y = 7, z = 0 } }) }, nil, nil, 10, seq()).action, nil)
-- giving up: past the leash, no longer valid, or gone
for _, list in { { seen(7, 261, 0) }, { seen(7, 220, 0, { valid = false }) }, {} } do
	local g = B.tick(hound, chasing(7), body(240, 0), list, nil, nil, 10, seq())
	T.eq({ g.brain.mode, g.brain.targetId, g.moveTo }, { "return", 0, DEN })
end
-- returning ignores everyone, taunt included; home within 3
local back = chasing(0); back.mode = "return"
local r1 = B.tick(hound, back, body(210, 0), { seen(7, 212, 0) }, 7, 7, 10, seq())
T.eq({ r1.brain.mode, r1.moveTo, r1.home, r1.action }, { "return", DEN, false, nil })
local r2 = B.tick(hound, back, body(202.9, 0), {}, nil, nil, 10, seq())
T.eq({ r2.brain.mode, r2.home, r2.moveTo }, { "wander", true, nil })
-- taunt and provocation
T.eq(B.tick(hound, chasing(7), body(200, 0), { seen(7, 210, 0), seen(9, 220, 0) }, 9, nil, 10, seq()).brain.targetId, 9)
T.eq(B.tick(hound, chasing(7), body(200, 0), { seen(7, 210, 0), seen(9, 220, 0, { valid = false }) }, 9, nil, 10, seq()).brain.targetId, 7)
T.eq(B.tick(hound, B.new(), body(200, 0), { seen(9, 250, 0, { visible = false }) }, 9, nil, 10, seq()).brain.targetId, 9)
T.eq(B.tick(hound, B.new(), body(200, 0), { seen(3, 250, 0, { visible = false }) }, nil, 3, 10, seq()).brain.targetId, 3)
T.eq(B.tick(hound, B.new(), body(200, 0), { seen(3, 270, 0) }, nil, 3, 10, seq()).brain.mode, "wander")   -- 70 from the den
-- keep-away (Bogspitter: Spit 30, keeps 15 away)
local spit = Creatures.byId.bogspitter
T.eq(B.tick(spit, chasing(7), body(200, 0), { seen(7, 210, 0) }, nil, nil, 10, seq()).moveTo, { x = 195, y = 0, z = 0 })
local s25 = B.tick(spit, chasing(7), body(200, 0), { seen(7, 225, 0) }, nil, nil, 10, seq())
T.eq({ s25.moveTo, s25.action }, { nil, { kind = "attack", targetId = 7 } })
T.eq(B.tick(spit, chasing(7), body(200, 0), { seen(7, 235, 0) }, nil, nil, 10, seq()).moveTo, { x = 235, y = 0, z = 0 })
-- Slam within 10; Lunge (Tallyman: Strike 7, Lunge 12 every 8 s, not while rooted)
T.eq(B.tick(Creatures.byId.brine_colossus, chasing(7), body(200, 0), { seen(7, 209, 0) }, nil, nil, 10, seq()).action, { kind = "attack", targetId = 7 })
local tal = Creatures.byId.drowned_tallyman
local l1 = B.tick(tal, chasing(7), body(200, 0), { seen(7, 210, 0) }, nil, nil, 10, seq())
T.eq({ l1.action, l1.brain.nextLungeAt }, { { kind = "lunge", targetId = 7 }, 18 })
T.eq(B.tick(tal, l1.brain, body(200, 0), { seen(7, 210, 0) }, nil, nil, 17, seq()).action, nil)
T.eq(B.tick(tal, chasing(7), body(200, 0), { seen(7, 205, 0) }, nil, nil, 10, seq()).action, { kind = "attack", targetId = 7 })
T.eq(B.tick(tal, chasing(7), body(200, 0, true), { seen(7, 210, 0) }, nil, nil, 10, seq()).action, nil)
-- Tallyport (radius 40, margin 4)
T.eq(B.outsideTown({ x = 10, y = 2, z = 0 }), { x = 44, y = 2, z = 0 })
T.eq(B.outsideTown({ x = 0, y = 0, z = 0 }), { x = 44, y = 0, z = 0 })
T.eq(B.outsideTown({ x = 100, y = 0, z = 0 }), { x = 100, y = 0, z = 0 })
T.eq(B.tick(hound, chasing(7), body(60, 0, false, { x = 100, y = 0, z = 0 }), { seen(7, 42, 0) }, nil, nil, 10, seq()).moveTo, { x = 44, y = 0, z = 0 })
-- tick never mutates brain, body or seen
```
- [ ] **Step 2: Run** — Expected: FAIL. **Step 3: Implement.** **Step 4: Run** `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 5: Commit** — `feat: creature behaviour rules`

---

### Task 5: Reward rules — contributors, XP Path, drops under scarcity

**Files:**
- Create: `src/shared/Rules/Rewards.luau`
- Modify: `src/shared/Rules/Sources.luau`, `tests/sources.spec.luau`
- Test: `tests/rewards.spec.luau`

**Interfaces:**
- Consumes: `Scarcity.isSealed`, `Paths.order`, `Ledger.add`, `Types.Drop`.
- Produces:
```luau
Rewards.CONTRIBUTOR_SECONDS = 30
Rewards.STRIKE = "Strike"
export type Tally = { [string]: { lastAt: number, total: number, byPath: { [string]: number } } }   -- key tostring(attacker id)
export type Recipient = { calling: string, room: number }    -- room: free slots it can still fill (0 when its Ledger is locked)
export type Award = { userId: number, coin: number, xpPath: string, xp: number, relics: { string }, sealed: { string }, lost: { string } }
Rewards.record(tally: Tally, attackerId: number, path: string, amount: number, now: number): Tally   -- non-finite or <= 0 amount: same tally
Rewards.contributors(tally: Tally, now: number): { number }   -- hit within the last 30 s (now - lastAt <= 30); most total damage first, ties lower id first
Rewards.xpPath(byPath: { [string]: number }, calling: string): string
-- "" without a Calling; "Strike" adds to the Calling; most damage wins; a tie with the Calling goes to the Calling,
-- other ties to the earlier Path in hexagon order; keys that are not Paths are ignored
Rewards.awards(reward: { coin: number, xp: number, drops: { Drop } }, tally: Tally, recipients: { [string]: Recipient },
	held: { [string]: number }, now: number, rng: () -> number): { Award }
-- one Award per contributor present in recipients, in contributors() order; rng() is drawn exactly once per drop per
-- contributor, in drop order, and the drop is won when rng() < chance; a won Relic is sealed when Scarcity.isSealed(id,
-- held + copies given earlier in this call), else lost when the contributor's room is used up, else given; xp is 0 when xpPath is ""

-- Sources.luau
Sources.give(ledger: Ledger?, relicId: CardId, sealed: boolean, locked: boolean): (Ledger?, string)
-- order: DATA_NOT_LOADED, LEDGER_LOCKED, UNKNOWN_CARD, SEALED, FREE_FULL; success: new ledger, "GOT_CARD"
-- tryCollect keeps its signature and codes and calls give after its cache checks
```
- [ ] **Step 1: Write the failing tests.** `tests/rewards.spec.luau`:
```luau
local t = R.record({}, 1, "Strike", 20, 0)
t = R.record(t, 1, "Ember", 16, 1); t = R.record(t, 2, "Fang", 22, 2); t = R.record(t, 1, "Ember", 3, 3)
T.eq(t["1"], { lastAt = 3, total = 39, byPath = { Strike = 20, Ember = 19 } })
T.eq({ R.contributors(t, 32), R.contributors(t, 32.5), R.contributors(t, 33.5) }, { { 1, 2 }, { 1 }, {} })
for _, bad in { 0, -5, 0 / 0, math.huge } do T.eq(R.record(t, 1, "Fang", bad, 4), t) end
T.eq(R.contributors(R.record(R.record({}, 9, "Fang", 10, 0), 4, "Fang", 10, 0), 1), { 4, 9 })
-- XP Path
T.eq(R.xpPath({ Strike = 20, Ember = 25 }, "Fang"), "Ember")
T.eq(R.xpPath({ Strike = 20, Fang = 5, Ember = 25 }, "Fang"), "Fang")
T.eq(R.xpPath({ Ember = 10, Gale = 10 }, "Fang"), "Gale")
T.eq(R.xpPath({ Strike = 40 }, "Mire"), "Mire"); T.eq(R.xpPath({ Strike = 40, Ember = 99 }, ""), "")
T.eq(R.xpPath({ Nope = 99, Mend = 1 }, "Fang"), "Mend")
-- awards: Brine Colossus (60 Coin, 500 XP, R022 100%, R023 20%), six contributors dealing 60, 50, ... 10
local col = Creatures.byId.brine_colossus
local tally, all = {}, {}
for id = 1, 6 do tally = R.record(tally, id, "Strike", 70 - id * 10, 0); all[tostring(id)] = { calling = "Fang", room = 20 } end
local a = R.awards(col, tally, all, {}, 1, function() return 0.5 end)
T.eq(a[1], { userId = 1, coin = 60, xpPath = "Fang", xp = 500, relics = { "R022" }, sealed = {}, lost = {} })
T.eq({ #a, a[4].relics, a[5].relics, a[5].sealed, a[6].sealed }, { 6, { "R022" }, {}, { "R022" }, { "R022" } })   -- Gold cap 4
T.eq(R.awards(col, tally, all, { R022 = 3 }, 1, function() return 0.5 end)[2].sealed, { "R022" })
T.eq(R.awards(col, tally, all, {}, 1, function() return 0.1 end)[1].relics, { "R022", "R023" })
local tight = table.clone(all); tight["1"] = { calling = "Fang", room = 1 }
local t1 = R.awards(col, tally, tight, {}, 1, function() return 0.1 end)[1]
T.eq({ t1.relics, t1.lost }, { { "R022" }, { "R023" } })
local bare = table.clone(all); bare["1"] = { calling = "", room = 20 }
local b1 = R.awards(col, tally, bare, {}, 1, function() return 0.5 end)[1]
T.eq({ b1.coin, b1.xpPath, b1.xp }, { 60, "", 0 })
T.eq(#R.awards(col, tally, { ["2"] = all["2"] }, {}, 1, function() return 0.5 end), 1)   -- absent contributors get nothing
T.eq(#R.awards(col, tally, all, {}, 31, function() return 0.5 end), 0)                     -- nobody hit in the last 30 s
local hound, one = Creatures.byId.brinehound, R.record({}, 1, "Strike", 20, 0)
local me = { ["1"] = { calling = "Fang", room = 20 } }
T.eq(R.awards(hound, one, me, {}, 1, function() return 0.0199 end)[1].relics, { "R019" })
T.eq(R.awards(hound, one, me, {}, 1, function() return 0.02 end)[1].relics, {})
-- tally, recipients and held are never mutated
```
`tests/sources.spec.luau` (keep every existing test):
```luau
T.eq({ Sources.give(Ledger.new(), "R013", false, false) }, { { claimed = {}, free = { "R013" } }, "GOT_CARD" })
T.eq({ Sources.give(nil, "R013", false, false) }, { nil, "DATA_NOT_LOADED" })
T.eq({ Sources.give(Ledger.new(), "R013", false, true) }, { nil, "LEDGER_LOCKED" })
T.eq({ Sources.give(Ledger.new(), "R999", false, false) }, { nil, "UNKNOWN_CARD" })
T.eq({ Sources.give(Ledger.new(), "R013", true, false) }, { nil, "SEALED" })
T.eq({ Sources.give(fullFree, "R013", false, false) }, { nil, "FREE_FULL" })   -- fullFree: 20 free cards, as the file's other tests build
```
- [ ] **Step 2: Run** — Expected: FAIL. **Step 3: Implement.** **Step 4: Run** `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 5: Commit** — `feat: creature reward and drop rules`

---

### Task 6: Trial rules and display data

**Files:**
- Create: `src/shared/Rules/TrialRun.luau`, `src/shared/Rules/TrialView.luau`
- Test: `tests/trial_run.spec.luau`, `tests/trial_view.spec.luau`

**Interfaces:**
- Consumes: `Trials.*`, `World.courses`, `Relics.byId`, `Scarcity.isSealed`, `Types.TrialRecord`.
- Produces:
```luau
TrialRun.PASS_COOLDOWN = 300
TrialRun.FAIL_COOLDOWN = 30
TrialRun.MARKER_RADIUS = 6
TrialRun.DELIVERY_RADIUS = 10
TrialRun.WARDEN_REACH = 15
export type Run = { trialId: string, endsAt: number, progress: number, goal: number }   -- endsAt on os.clock()
TrialRun.newRecord(): TrialRecord                                 -- { cooldowns = {}, questStep = 0 }
TrialRun.sanitize(raw: any, realNow: number): TrialRecord         -- never errors
TrialRun.goal(trialId: string): number                            -- course: #World.courses[id]; hunt: count; delivery, duel: 1
TrialRun.cooldownLeft(record: TrialRecord, trialId: string, realNow: number): number   -- clamp(readyAt - realNow, 0, 300); NaN -> 300
TrialRun.start(record: TrialRecord, current: Run?, rawId: any, clock: number, realNow: number): (Run?, string)
-- order: BAD_REQUEST (not a trial id), TRIAL_BUSY (current ~= nil), TRIAL_COOLDOWN; success: Run, "TRIAL_STARTED"
TrialRun.reachMarker(run: Run, index: number): Run     -- course only: progress + 1 when index == progress + 1
TrialRun.countDefeat(run: Run, creature: string): Run  -- hunt of that creature only: progress + 1, capped at goal
TrialRun.complete(run: Run): Run                       -- delivery and duel only: progress = goal
TrialRun.isPassed(run: Run): boolean
TrialRun.isExpired(run: Run, clock: number): boolean   -- not (clock < endsAt)
TrialRun.finish(record: TrialRecord, trialId: string, passed: boolean, realNow: number): TrialRecord   -- cooldown readyAt = realNow + 300 or 30
TrialRun.advanceQuest(step: number, event: string): (number, boolean)
-- event: a trial id or "colossus"; counts only when it is Trials.quest.steps[step + 1]; the last step returns 0, true (the quest restarts)

export type OfferView = { trialId: string, title: string, warden: string, goal: string, timeText: string,
	rewardText: string, relicText: string, sealed: boolean, canStart: boolean, note: string }
export type HudState = { trialId: string, progress: number, goal: number, secondsLeft: number }
TrialView.offer(trialId: string, record: TrialRecord, running: string?, realNow: number, held: number, freeSlots: number): OfferView
-- note, first that applies: "Finish your current trial first." | "Try again in M:SS." | "Your free slots are full, so the Relic would be lost." | ""
-- canStart false only for the first two
TrialView.hud(state: HudState?, questStep: number): { string }
-- with a run: "<name>: <progress>" (course "marker n / N", hunt "defeated n / N", delivery "carry the parcel to the
-- Harbour Warden", duel "defeat the Drowned Tallyman") and "Time left M:SS" (seconds rounded up; below 0 or NaN reads 0:00);
-- always last: "The Unpaid Debt: <step> / 4, next: <Tidewalk | Salt Post | The Tallyman's Duel | defeat the Brine Colossus>"
```
- `sanitize`: non-table → `newRecord()`. `cooldowns` keeps only known trial ids with a finite number value; values ≤ `realNow` are dropped, values above `realNow + 300` become `realNow + 300`. `questStep` is kept only when it is a whole number 0..3.

- [ ] **Step 1: Write the failing tests.** `tests/trial_run.spec.luau`:
```luau
local rec = TrialRun.newRecord()
local run, code = TrialRun.start(rec, nil, "tidewalk", 100, 5000)
T.eq({ run, code }, { { trialId = "tidewalk", endsAt = 160, progress = 0, goal = 6 }, "TRIAL_STARTED" })
T.eq({ TrialRun.start(rec, run, "salt_post", 100, 5000) }, { nil, "TRIAL_BUSY" })
for _, bad in { "nope", "", 5, {}, true } do T.eq({ TrialRun.start(rec, nil, bad, 100, 5000) }, { nil, "BAD_REQUEST" }) end
T.eq({ TrialRun.start(rec, nil, nil, 100, 5000) }, { nil, "BAD_REQUEST" })
T.eq({ TrialRun.goal("gullstep_climb"), TrialRun.goal("cull_the_pack"), TrialRun.goal("shellbreaker"), TrialRun.goal("salt_post"), TrialRun.goal("tallymans_duel") }, { 8, 5, 3, 1, 1 })
-- cooldowns: 300 s after a pass, 30 s after a fail, per trial
local passed = TrialRun.finish(rec, "tidewalk", true, 5000)
T.eq(passed.cooldowns.tidewalk, 5300)
T.eq(select(2, TrialRun.start(passed, nil, "tidewalk", 0, 5299)), "TRIAL_COOLDOWN")
T.eq(select(2, TrialRun.start(passed, nil, "tidewalk", 0, 5300)), "TRIAL_STARTED")
T.eq(select(2, TrialRun.start(passed, nil, "salt_post", 0, 5000)), "TRIAL_STARTED")
local failed = TrialRun.finish(rec, "tidewalk", false, 5000)
T.eq({ TrialRun.cooldownLeft(failed, "tidewalk", 5000), TrialRun.cooldownLeft(failed, "tidewalk", 5030) }, { 30, 0 })
T.eq(TrialRun.cooldownLeft({ cooldowns = { tidewalk = 1e12 }, questStep = 0 }, "tidewalk", 5000), 300)
T.eq(TrialRun.cooldownLeft(passed, "tidewalk", 0 / 0), 300)
-- progress
local r1 = TrialRun.reachMarker(run, 1)
T.eq({ r1.progress, TrialRun.reachMarker(run, 2).progress, TrialRun.reachMarker(r1, 1).progress }, { 1, 0, 1 })
local done = run
for i = 1, 6 do done = TrialRun.reachMarker(done, i) end
T.truthy(TrialRun.isPassed(done)); T.falsy(TrialRun.isPassed(r1))
local hunt = TrialRun.start(rec, nil, "cull_the_pack", 0, 0)
T.eq({ TrialRun.countDefeat(hunt, "shellback").progress, TrialRun.countDefeat(hunt, "brinehound").progress }, { 0, 1 })
local h = hunt
for _ = 1, 6 do h = TrialRun.countDefeat(h, "brinehound") end
T.eq(h.progress, 5)
T.eq(TrialRun.complete((TrialRun.start(rec, nil, "salt_post", 0, 0))).progress, 1)
T.eq(TrialRun.complete(run).progress, 0); T.eq(TrialRun.countDefeat(run, "brinehound").progress, 0)
T.eq({ TrialRun.isExpired(run, 159.9), TrialRun.isExpired(run, 160), TrialRun.isExpired(run, 0 / 0) }, { false, true, true })
-- quest order
T.eq({ TrialRun.advanceQuest(0, "tidewalk") }, { 1, false }); T.eq({ TrialRun.advanceQuest(0, "salt_post") }, { 0, false })
T.eq({ TrialRun.advanceQuest(1, "salt_post") }, { 2, false }); T.eq({ TrialRun.advanceQuest(2, "tidewalk") }, { 2, false })
T.eq({ TrialRun.advanceQuest(2, "colossus") }, { 2, false }); T.eq({ TrialRun.advanceQuest(2, "tallymans_duel") }, { 3, false })
T.eq({ TrialRun.advanceQuest(3, "colossus") }, { 0, true })
-- sanitize (Review Focus 2)
T.eq(TrialRun.sanitize(nil, 5000), TrialRun.newRecord()); T.eq(TrialRun.sanitize("junk", 5000), TrialRun.newRecord())
T.eq(TrialRun.sanitize({ cooldowns = { tidewalk = 1e12, salt_post = 4000, gullstep_climb = 5100, nope = 9999, shellbreaker = 0 / 0, cull_the_pack = "x" }, questStep = 2 }, 5000),
	{ cooldowns = { tidewalk = 5300, gullstep_climb = 5100 }, questStep = 2 })
for _, bad in { -1, 4, 1.5, 0 / 0, "2", {} } do T.eq(TrialRun.sanitize({ questStep = bad }, 0).questStep, 0) end
-- no function mutates its arguments
```
`tests/trial_view.spec.luau`:
```luau
local fresh = TrialRun.newRecord()
T.eq(TrialView.offer("tidewalk", fresh, nil, 5000, 0, 20), { trialId = "tidewalk", title = "Tidewalk", warden = "Harbour Warden",
	goal = "Touch 6 markers in order.", timeText = "Time: 60 seconds", rewardText = "Reward: 30 Coin, 120 XP",
	relicText = "Relic: Low-Tide Tally Stick (Silver)", sealed = false, canStart = true, note = "" })
local s = TrialView.offer("tidewalk", fresh, nil, 5000, 8, 20)
T.eq({ s.sealed, s.relicText, s.canStart }, { true, "Relic: Low-Tide Tally Stick (Silver) — sealed on this server", true })
T.eq(TrialView.offer("tallymans_duel", fresh, nil, 5000, 4, 20).sealed, true)   -- Gold cap 4
T.eq(TrialView.offer("tidewalk", fresh, nil, 5000, 0, 0).note, "Your free slots are full, so the Relic would be lost.")
local cd = TrialView.offer("tidewalk", TrialRun.finish(fresh, "tidewalk", true, 5000), nil, 5025, 0, 0)
T.eq({ cd.canStart, cd.note }, { false, "Try again in 4:35." })
local busy = TrialView.offer("tidewalk", fresh, "salt_post", 5000, 0, 20)
T.eq({ busy.canStart, busy.note }, { false, "Finish your current trial first." })
T.eq(TrialView.hud(nil, 0), { "The Unpaid Debt: 0 / 4, next: Tidewalk" })
T.eq(TrialView.hud({ trialId = "tidewalk", progress = 2, goal = 6, secondsLeft = 42.2 }, 1),
	{ "Tidewalk: marker 2 / 6", "Time left 0:43", "The Unpaid Debt: 1 / 4, next: Salt Post" })
T.eq(TrialView.hud({ trialId = "cull_the_pack", progress = 3, goal = 5, secondsLeft = 61 }, 3),
	{ "Cull the Pack: defeated 3 / 5", "Time left 1:01", "The Unpaid Debt: 3 / 4, next: defeat the Brine Colossus" })
local salt = TrialView.hud({ trialId = "salt_post", progress = 0, goal = 1, secondsLeft = -3 }, 2)
T.eq({ salt[1], salt[2] }, { "Salt Post: carry the parcel to the Harbour Warden", "Time left 0:00" })
local duel = TrialView.hud({ trialId = "tallymans_duel", progress = 0, goal = 1, secondsLeft = 0 / 0 }, 2)
T.eq({ duel[1], duel[2] }, { "The Tallyman's Duel: defeat the Drowned Tallyman", "Time left 0:00" })
```
- [ ] **Step 2: Run** — Expected: FAIL. **Step 3: Implement both modules.** **Step 4: Run** `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 5: Commit** — `feat: trial and quest rules`

---

### Task 7: PvE protection and defeat-credit rules

**Files:**
- Modify: `src/shared/Rules/Protection.luau`, `src/shared/Rules/Combat.luau`, `tests/protection.spec.luau`, `tests/combat.spec.luau`

**Interfaces:**
- Produces:
```luau
Protection.creatureCanHit(victim: Status, now: number): boolean
-- creature -> player: false in the safe zone (Marked or not) and while the respawn shield is up (NaN counts as up);
-- the new-player shield does not block
Protection.canHitCreature(attacker: Status): (boolean, string?)
-- player -> creature: false, "SAFE_ZONE" when the attacker stands in the safe zone; the new-player shield does not block
Combat.creditFor(log: HitLog, victimId: number, now: number, windowSeconds: number, creatureLog: HitLog?): number?
-- unchanged without creatureLog; with it, nil when the creature log holds a hit within the window at least as recent
-- as the player hit (a creature's last blow is a creature defeat)
```
- [ ] **Step 1: Write the failing tests** (keep every existing test; `st` as in the file):
```luau
T.truthy(Protection.creatureCanHit(st({ newShield = true }), 10))
T.falsy(Protection.creatureCanHit(st({ inSafeZone = true }), 10))
T.falsy(Protection.creatureCanHit(st({ inSafeZone = true, markedUntil = 100 }), 10))
T.falsy(Protection.creatureCanHit(st({ respawnShieldUntil = 70 }), 10)); T.truthy(Protection.creatureCanHit(st({ respawnShieldUntil = 70 }), 70))
T.falsy(Protection.creatureCanHit(st({ respawnShieldUntil = 0 / 0 }), 10))
T.eq({ Protection.canHitCreature(st({ newShield = true })) }, { true })
T.eq({ Protection.canHitCreature(st({ inSafeZone = true, markedUntil = 999 })) }, { false, "SAFE_ZONE" })
```
```luau
local log = Combat.recordHit({}, 2, 7, 10)
T.eq(Combat.creditFor(log, 2, 13, 15), 7)
T.eq(Combat.creditFor(log, 2, 13, 15, Combat.recordHit({}, 2, -2000001, 12)), nil)   -- the creature hit last
T.eq(Combat.creditFor(log, 2, 13, 15, Combat.recordHit({}, 2, -2000001, 10)), nil)   -- same instant: the creature's
T.eq(Combat.creditFor(log, 2, 13, 15, Combat.recordHit({}, 2, -2000001, 9)), 7)      -- the player hit last
T.eq(Combat.creditFor(log, 2, 24, 15, Combat.recordHit({}, 2, -2000001, 8)), 7)      -- creature hit outside the window
```
- [ ] **Step 2: Run** — Expected: FAIL. **Step 3: Implement.** **Step 4: Run** `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 5: Commit** — `feat: PvE protection and defeat-credit rules`

---

### Task 8: Server — saved trial data, Coin sync, Relic awards, the M4 world

**Files:**
- Modify: `src/server/DataService.luau`, `src/server/SourceService.luau`, `src/server/PathService.luau`, `src/server/WorldBuilder.luau`

**Interfaces:**
- Consumes: `TrialRun.newRecord/sanitize`, `Sources.give`, `Scarcity.*`, `World.*` (Task 3), `Net.CoinSync`.
- Produces:
```luau
SourceService.award(player: Player, relicId: string): string
-- Sources.give(ledger, relicId, sealed now, LedgerService.isLocked(player)); on success LedgerService.set.
-- Notifies and returns: GOT_CARD {name} | REWARD_SEALED {name} | REWARD_LOST {name} | REWARD_LOCKED {name}; DATA_NOT_LOADED silently
SourceService.addCoin(player: Player, delta: number): boolean
-- false (nothing changes) for a non-finite delta, unloaded data, or a result below 0; else writes data.coin and fires CoinSync
SourceService.held(relicId: string): number   -- Scarcity.countHeld(LedgerService.all(), relicId)
```
- [ ] **Step 1: DataService** — template gains `trials = TrialRun.newRecord()`; on load `data.trials = TrialRun.sanitize(data.trials, os.time())`. `schemaVersion` stays 1.
- [ ] **Step 2: SourceService** — `award`, `addCoin`, `held` as above; creates `CoinSync` in `start` and fires it on `DataService.onLoaded`. The cache prompt keeps `Sources.tryCollect`, so caches and rewards share `Sources.give`.
- [ ] **Step 3: PathService** — a Calling change pays through `SourceService.addCoin(player, -cost)` (refused → `NOT_ENOUGH_COIN`, nothing changes), so the client's Coin stays current.
- [ ] **Step 4: WorldBuilder** (everything anchored; tags and attributes are what the services look up):
  - Caches on climbs: `Pillar` stands on the cache's own surface (`y − 1 + 6`), not the ground.
  - Each climb ledge: a slate rock block `size × top × size` from the ground up, named `Ledge`.
  - Wardens: per trial id a `Model` `Warden_<id>` — body (2 × 4 × 1.5, a colour per Warden), round head, a `BillboardGui` (Warden name, and "Trial: <name>"; MaxDistance 80), and a `ProximityPrompt` on the body (ActionText "Talk", ObjectText the Warden name, HoldDuration 0, MaxActivationDistance 10, RequiresLineOfSight false). Body tagged `Warden` with attribute `TrialId`.
  - Course markers: a flat neon ring (diameter 6, non-colliding, `CanQuery` and `CanTouch` false) on the surface under each marker with its number on a `BillboardGui`; tagged `TrialMarker`, attributes `TrialId`, `Index`. A low rock (3 high) halfway between consecutive Tidewalk markers.
  - A wooden dock beside the Harbour Warden, a stone disc of radius 25 at `World.duelArena`, and a dark patch of radius 8 at each den with a "<creature> den" label (MaxDistance 60).
- [ ] **Step 5: Run** `bash scripts/check.sh` — Expected: exit 0. **Commit** — `feat: saved trials, Coin sync, Relic awards and the M4 world`

No behaviour tests beyond those of Tasks 3, 5 and 6: engine glue. The reviewer checks by reading that `award` is the only place a reward Relic reaches a Ledger, and that `addCoin` never lets Coin go negative.

---

### Task 9: Server — CreatureService and creatures in the damage pipeline

**Files:**
- Create: `src/server/CreatureService.luau`, `src/server/Fx.luau`
- Modify: `src/server/CombatService.luau`, `src/server/Sight.luau`, `src/server/AbilityService.luau`, `src/server/Main.server.luau`, `tests/build.spec.luau`

**Interfaces:**
- Consumes: `Fighters.*`, `StatusService.*` (Task 1), `CreatureBrain.*` (Task 4), `Rewards.*` (Task 5), `Protection.creatureCanHit/canHitCreature`, `Combat.creditFor` (Task 7), `SourceService.award/addCoin/held` (Task 8), `PathService.grant`, `Creatures`, `World.creatureSlots/dens/CHAMPION_ID_BASE`, `Targeting.inRadius/dashHit`.
- Produces:
```luau
-- moved out of AbilityService, behaviour unchanged
Sight.move(humanoid: Humanoid, root: BasePart, target: Types.Vec3): number   -- was moveCharacter
Sight.standHeight(humanoid: Humanoid, root: BasePart): number
Fx.folder(): Folder; Fx.ray(from: Vector3, to: Vector3, color: Color3): (); Fx.ring(center: Vector3, radius: number, color: Color3): ()

CombatService.onHit(callback: (attackerId: number, targetId: number, amount: number, path: string) -> ()): ()
-- runs (each in pcall, never yielding) for every landed hit on a creature, before TakeDamage

CreatureService.start(): ()
CreatureService.onDefeated(callback: (kind: string, id: number, contributors: { Player }, owner: Player?) -> ()): ()
CreatureService.spawnChampion(owner: Player, at: Types.Vec3): number   -- a Drowned Tallyman owned by `owner`
CreatureService.despawn(id: number): ()                                 -- no rewards, no respawn
-- play-test seams
export type Info = { kind: string, alive: boolean, mode: string, targetId: number, position: Vector3?, owner: Player? }
CreatureService.setActive(ids: { number }?): ()   -- nil: every creature thinks; a list: only those den creatures (champions always think)
CreatureService.setRng(rng: () -> number): ()      -- wander and drop rolls; default Random.new():NextNumber
CreatureService.info(id: number): Info?
CreatureService.respawn(id: number): ()            -- a defeated den creature comes back now
```
- [ ] **Step 1: Move** `moveCharacter`/`standHeight` into `Sight` and `showRay`/`showRing`/`effectsFolder` into `Fx`; `AbilityService` calls them. Pull and knockback on a creature target pass the destination through `CreatureBrain.outsideTown`.
- [ ] **Step 2: Fill in the creature branches of `CombatService.damage`** (both entries exist and `Fighters.mayFight`):
  - **creature → player:** `ProtectionService.status(victim)` nil → false; `Protection.creatureCanHit` false → false (no message). No Mark, no empower, no respawn-shield end. `resolveDamage` on the victim's status; record in a separate **creature hit log** (`Combat.recordHit`, never the player hit log) before `TakeDamage`; flash. Reflected damage goes back as `damage(victimId, creatureId, reflected, { reflected = true, path = "Bulwark" })`, unless the hit defeated the victim (as between players).
  - **player → creature:** unless `reflected`: attacker status nil → false; `Protection.canHitCreature` refused → notify the code unless `tick`, false; `endRespawnShield(attacker)` unless `passive`; **never** Mark. Empower as for players (not on `tick` or `reflected`). `resolveDamage` on the creature's status (a creature walking home is immune: false). Run the `onHit` callbacks with the health damage and `opts.path`, then `TakeDamage`, flash.
  - Every other pair (creature → creature, creature → post) stays false.
  - Player `Died`: `Combat.creditFor(hitLog, id, now, KILL_CREDIT_SECONDS, creatureLog)`; clear the victim in both logs. The combat-log check on leaving keeps using the player hit log only.
- [ ] **Step 3: Implement `CreatureService`.**
  - **Spawn** (every `World.creatureSlots` entry at start; members 4 studs apart around the den): a `Model` named after the kind in `workspace.Creatures` — an invisible `HumanoidRootPart` (`PrimaryPart`) with a few primitive parts welded to it (`WeldConstraint`, Massless, CanCollide false), in the kind's colour, about `height` tall. Looks: Brinehound a low long slate-blue body with a fin; Shellback a wide domed sandy shell on a flat body; Bogspitter a thin olive stalk with a big round head; Brine Colossus a huge barnacled grey-blue block with two arm blocks; Drowned Tallyman a man-sized dark-teal coat, pale head and a gold book. `Humanoid`: RigType R15, HipHeight so the body stands on the ground, `MaxHealth = Health = kind.health`, `BreakJointsOnDeath = false`, `RequiresNeck = false`, `HealthDisplayType` AlwaysOff, `DisplayDistanceType` None. After parenting: `root:SetNetworkOwner(nil)`. Tag `Creature`; attributes `CreatureId`, `Kind`, `OwnerUserId` (0 for den creatures). A `BillboardGui` `Bar` (name and a health bar, MaxDistance 80) follows `HealthChanged`. Then `Fighters.add({ id, kind = "creature", model, baseSpeed = kind.speed, owner })` and `StatusService.reset(id)`.
  - **Brain loop** (Heartbeat, every `CreatureBrain.TICK_SECONDS`): den creatures not in the active set stop where they are and skip the tick. `seen`: den creatures see every player with a living body, a champion only its owner; `valid = ProtectionService.status(p) ~= nil and Protection.creatureCanHit(status, now)`; `visible = valid` and within `kind.sight` and `Sight.inSight(root, player root)`. `taunter = Effects.tauntedBy(StatusService.get(id), now)`; `provoker` = the last attacker since the previous tick (then cleared). Apply the `Decision`: entering `return` → `StatusService.update(id, applyImmune(math.huge))`; `home` → `Health = MaxHealth`, `StatusService.reset(id)`, tally cleared; `moveTo` → `Humanoid:MoveTo`, none → `MoveTo(root.Position)`; standing with `faceTo` → turn the root to face it (keep its height).
  - **Actions** (`Sight.inSight` from the creature's root to the target's first): melee → `damage(id, targetId, attack.damage)` when the target is still within `range + 1`; shot → the same plus `Fx.ray`; slam → `damage(id, pid, attack.damage)` for every player fighter within `range` (`Targeting.inRadius` over `Fighters.list(id)`, players only) plus `Fx.ring`; lunge → `Sight.move` towards the target by `lunge.distance` (destination through `outsideTown`), then `damage(id, targetId, lunge.damage)` when `Targeting.dashHit` from the start point finds the target within the distance travelled + 1.5.
  - **Tally:** `CombatService.onHit` → for its creatures `Rewards.record(tally, attackerId, path, amount, now)` and `provoker = attackerId`.
  - **Defeat** (`Humanoid.Died`, once): `Rewards.awards(kind, tally, recipients, held, now, rng)` where `recipients` covers present players with loaded data (`calling`, `room = 0` if their Ledger is locked else free slots left) and `held[relic] = SourceService.held(relic)` per drop. Per award, in order: notify `CREATURE_DEFEATED { creature, coin }`, `SourceService.addCoin`, `PathService.grant(player, xpPath, xp)` when `xp > 0`, `SourceService.award` for each given Relic, `REWARD_SEALED` for each sealed one, `REWARD_LOST` (or `REWARD_LOCKED` when locked) for each lost one. Then the `onDefeated` callbacks (pcall) with the contributors as Players, `Fighters.remove(id)`, `StatusService.drop(id)`, the model tips over and is destroyed after 1.5 s; a den creature respawns after `kind.respawn` (a generation counter stops a stale timer from spawning a second copy). A champion grants nothing and never respawns.
  - A model removed by anything else (fallen off the world) counts as a despawn without rewards; den creatures respawn on their timer.
  - **Champion:** `spawnChampion` uses id `World.CHAMPION_ID_BASE − k` (k counts up), den = `at`, `owner = owner.UserId`; it sees only its owner, so it only ever attacks its owner, and `Fighters.mayFight` keeps everyone else from hitting it.
- [ ] **Step 4: Start order** (`Main.server.luau`): `WorldBuilder.build`, `Fighters.start`, `LedgerService.start`, `SourceService.start`, `VaultService.start`, `ProtectionService.start`, `StatusService.start(CombatService.damage)`, `CombatService.start(PathService.get, PathService.grant)`, `AbilityService.start`, `ClaimService.start`, `PathService.start`, `CreatureService.start`, then `TrialService.start` (Task 10), `DataService.start` last. Add `Server.CreatureService` and `Server.Fx` to `tests/build.spec.luau`.
- [ ] **Step 5: Run** `bash scripts/check.sh` — Expected: exit 0. **Commit** — `feat: creatures roam, fight and pay out`

No behaviour tests: engine glue over tested rules; Task 12's play test exercises it. The reviewer checks Review Focus 4 and 5 by reading: the creature branches never touch the player hit log, Marks or claims; a returning creature is immune; champions and their owners are the only pair `mayFight` allows; no `WalkSpeed` write outside `StatusService`.

---

### Task 10: Server — TrialService

**Files:**
- Create: `src/server/TrialService.luau`
- Modify: `src/server/Main.server.luau`, `tests/build.spec.luau`

**Interfaces:**
- Consumes: `TrialRun.*`, `TrialView.*` (Task 6), `Trials`, `World.wardens/courses/harbour/duelArena`, `CreatureService.onDefeated/spawnChampion/despawn` (Task 9), `SourceService.award/addCoin/held` (Task 8), `PathService.grant/get`, `DataService.get/onLoaded/beforeRelease`, `LedgerService.makeRemote/notify/get/isLocked`, `RateLimiter`.
- Produces:
```luau
TrialService.start(): ()
TrialService.run(player: Player): TrialRun.Run?                                     -- play-test seam
TrialService.setClocks(clock: () -> number, realClock: () -> number): ()           -- play-test seam; defaults os.clock, os.time
```
- [ ] **Step 1: Implement `TrialService`.**
  - **Offer:** a `Warden` prompt's `Triggered(player)` → `TrialOffer:FireClient(player, TrialView.offer(id, data.trials, current run id, realClock(), SourceService.held(relic), room))` (`room` 0 when the Ledger is locked).
  - **Accept** (`TrialAccept`, rate limit capacity 10, refill 5/s, `player.Parent == Players`), in order: no data → `DATA_NOT_LOADED`; not a trial id → `BAD_REQUEST`; root farther than `WARDEN_REACH` from the Warden (+3 up), or no living body → `TOO_FAR`; `TrialRun.start(data.trials, run, id, clock(), realClock())` refused → its code (`TRIAL_COOLDOWN` with `{ name, seconds = <cooldownLeft, rounded up> }`). On success: delivery welds a `Parcel` (1.5 × 1.2 × 1.5 brown box, Massless, non-colliding) to the character's root; duel `spawnChampion(player, World.duelArena)`; notify `TRIAL_STARTED { name }`; sync.
  - **Tick** (Heartbeat, every 0.1 s), per running trial: `isExpired(run, clock())` → fail `TRIAL_FAILED_TIME`; course: root within `MARKER_RADIUS` of the next marker → `reachMarker`, notify `MARKER_REACHED { n, total }`, sync; delivery: root within `DELIVERY_RADIUS` of `World.harbour` (+3 up) → `complete`. Then `isPassed` → pass.
  - **Creature defeats** (`CreatureService.onDefeated`): each contributor running a hunt → `countDefeat`, notify `HUNT_PROGRESS { n, total }`, sync; the champion's owner → `complete`; every contributor of a `brine_colossus` defeat → quest event `"colossus"`.
  - **Pass:** clear the run and its parcel/champion; `data.trials = finish(..., true, realClock())`; notify `TRIAL_PASSED { name, coin }`; `addCoin(trial.coin)`; `grant(calling, trial.xp)` when the Calling is set; `SourceService.award(trial.relicId)`; quest event = the trial id; sync.
  - **Quest event:** `advanceQuest(questStep, event)`; when it moved: save it and notify `QUEST_STEP { n }`; when completed: notify `QUEST_COMPLETE { coin = "150" }`, `addCoin(150)`, `grant(calling, 600)`, `award("R027")`.
  - **Fail:** clear the run, parcel and champion; `finish(..., false, realClock())`; notify the code (`TRIAL_FAILED_TIME`, or `TRIAL_FAILED_DEFEAT` from the character's `Humanoid.Died`); sync. Leaving fails silently in `DataService.beforeRelease`, so the 30 s cooldown is saved before the profile is released.
  - **Sync:** `TrialSync(state, questStep)` on load, start, progress, pass and fail; `state = { trialId, progress, goal, secondsLeft = endsAt − clock() }` or nil.
  - No yielding call between reading a run or record and writing it back.
- [ ] **Step 2: Start order** — `TrialService.start` after `CreatureService.start`. Add `Server.TrialService` to `tests/build.spec.luau`. **Run** `bash scripts/check.sh` — Expected: exit 0. **Commit** — `feat: Wardens run trials and the Unpaid Debt quest`

No behaviour tests: engine glue over Task 6's rules. The reviewer checks Review Focus 1 by reading: the accept handler validates data, id, distance, busy and cooldown before anything changes.

---

### Task 11: Client — trial window, trial HUD, Coin, creatures, 30-slot claim, message queue

**Files:**
- Create: `src/client/TrialUI.luau`, `src/client/CreatureFx.luau`
- Modify: `src/client/StatusHUD.luau`, `src/client/ClaimUI.luau`, `src/client/Toast.luau`, `src/client/Main.client.luau`, `tests/build.spec.luau`

**Interfaces:**
- Consumes: `TrialView.*`, `World.courses`, `Net.TrialOffer/TrialAccept/TrialSync/CoinSync/HitFx`.
- Produces:
```luau
TrialUI.mount(playerGui: PlayerGui, onAccept: (trialId: string) -> ()): ()
TrialUI.showOffer(view: TrialView.OfferView): ()
TrialUI.renderHud(lines: { string }): ()
TrialUI.setBeacon(position: Types.Vec3?): ()   -- a local neon column at the next course marker; nil removes it
TrialUI.isOpen(): boolean
CreatureFx.start(localPlayer: Player): ()      -- hides champions owned by someone else (parts LocalTransparencyModifier 1, guis off), now and as they appear
CreatureFx.flash(id: number): ()               -- short flash on the creature with that CreatureId
StatusHUD.setCoin(coin: number): ()            -- "Coin: 120" above the status lines
```
- [ ] **Step 1: `TrialUI`** — one `ScreenGui` `TrialGui` (`ResetOnSpawn = false`, `DisplayOrder` 14). Offer window, centred: title, Warden, goal, `timeText`, `rewardText`, `relicText` (red when sealed), `note` (amber when not empty), "Accept" (dimmed and inert unless `canStart`) → `onAccept(trialId)` and close, "Close". HUD: top-right lines from `renderHud`. Same look as the Paths panel (`TextScaled` with `UITextSizeConstraint`, scale-based sizes that fit a phone).
- [ ] **Step 2: `CreatureFx`, `StatusHUD.setCoin`; `ClaimUI`** grid becomes 6 columns × 5 rows for 30 slots; **`Toast`** keeps a queue: a message shows 3 s, or 1.5 s when another is waiting; at most 4 wait, the oldest waiting is dropped first.
- [ ] **Step 3: Wire `Main.client.luau`** — `TrialOffer` → `showOffer`; `TrialSync` keeps the state and its local receipt time; every 0.5 s `renderHud(TrialView.hud(state with secondsLeft − elapsed, questStep))` and `setBeacon(World.courses[trialId][progress + 1])` for a course, else nil; `CoinSync` → `StatusHUD.setCoin` and the Paths panel re-renders with the new Coin; `PathSync`'s Coin seeds both; `HitFx(id)`: a player's character flashes as before, otherwise `CreatureFx.flash(id)`; `CreatureFx.start(localPlayer)`; Strike and ability input are blocked while `TrialUI.isOpen()`.
- [ ] **Step 4:** Add `Client.TrialUI`, `Client.CreatureFx`, `Shared.Rules.TrialView` to `tests/build.spec.luau`. **Run** `bash scripts/check.sh` — Expected: exit 0. **Commit** — `feat: trial window, trial HUD and Coin display`

---

### Task 12: Play test and owner hand-off

**Files:**
- Modify: `playtest/server/Driver.server.luau`, `playtest/client/Agent.client.luau`, `README.md`, `dist/IsleOfAvarice.rbxlx`
- Create: `docs/playtest/M4-checklist.md`

- [ ] **Step 1: Extend the agent** with ops `warden(trialId)` (holds that Warden's prompt), `accept(value)` (fires `TrialAccept` with any value, hostile ones included) and `closeOffer`; record `TrialOffer` and `TrialSync` payloads in the report stream; `inspect()` adds the Coin line, the trial HUD lines, the offer window (visible, title, relicText, note, Accept active), the beacon (exists, position) and, per `Creature`-tagged champion, its owner and whether this client draws it.
- [ ] **Step 2: Extend the driver.** First thing after the players load: `CreatureService.setActive({})`, so no creature disturbs M1–M3. Update the M1 checks that assumed 12 Relics (18 caches tagged, "Relics: 1 / 30"). Then an M4 section before M2.15 (which still ends the run); each line is one `check`. Use `CreatureService.setActive({ id })` to wake one creature at a time, set creature health through `Fighters.body(id)`, `CreatureService.setRng` for drops and `TrialService.setClocks` to skip timers:
  - World: 25 `Creature` models, one per slot, at full catalog health; 6 Wardens; 18 caches; no creature within `townRadius + 4` of the origin at any point of the run.
  - Wander and chase: an active Brinehound stays within 14 studs of its den for 5 s; A (shields off) 20 studs away → `info.mode == "chase"`, target A, the gap closes, A loses 8 per Bite. A with a respawn shield, or standing in town, is not chased and not hurt.
  - Leash and heal: chased A teleports 70 studs from the den → mode "return"; A's Strike on it during the walk home changes nothing; once home its health is full and its mode "wander".
  - Hits and PvE: A's Strike takes 20, Gust Blade 18, B's Bog Snare roots it (its `WalkSpeed` 0, then back to 16); none of these Marks anyone; A standing in town cannot hurt a creature just outside (`SAFE_ZONE`).
  - Rewards: a Shellback at 48 health; A (Gale Calling) Lunges through it (22, Fang) and Strikes it (20, counts as Gale); B's Bog Snare lands the last 6 → A gets 10 Coin and Fang XP +56 (70 × 80 %), B gets 10 Coin and Mire XP +70; the Coin line on both screens rises by 10. A player who last hit it 31 s earlier gets nothing.
  - Drops and scarcity: `setRng(→ 0)` → a defeated Brinehound gives A R019 (`GOT_CARD`); with 4 R019 held on the server the next gives `REWARD_SEALED`, Coin still paid; with A's free slots full a Bogspitter's R021 gives `REWARD_LOST`; `setRng(→ 0.99)` gives nothing.
  - Defeat by a creature: A at 5 health bitten → defeated, no `CLAIM_STARTED`/`DEFEATED_BY` for anyone, nobody's XP changes, A respawns in Tallyport; B Strikes A, then a creature lands the last blow within 15 s → still no claim for B.
  - Tidewalk: the offer window shows "Tidewalk" and Accept active; hostile `accept` values ("nope", 5, nil, a table) → `BAD_REQUEST`, from 20 studs → `TOO_FAR`; accept → `TRIAL_STARTED`, HUD "Tidewalk: marker 0 / 6", beacon at marker 1; marker 2 first → nothing; markers 1–6 in order → six `MARKER_REACHED`, `TRIAL_PASSED`, R013 in A's Ledger, +30 Coin, Calling XP +120, `QUEST_STEP`. Another accept → `TRIAL_COOLDOWN`, the offer note reads "Try again in 5:00" or "4:59"; real clock + 301 s → allowed.
  - Busy and timeout: during Gullstep Climb, accepting Tidewalk → `TRIAL_BUSY`; clock + 76 s → `TRIAL_FAILED_TIME`; retry refused, then allowed after real clock + 31 s.
  - Salt Post: accept → a `Parcel` on A; at the harbour → `TRIAL_PASSED`, parcel gone, quest step 2. Again (clock skipped): defeated on the way → `TRIAL_FAILED_DEFEAT`, parcel gone. B passes Salt Post before Tidewalk → B's quest step stays 0.
  - Cull the Pack: A defeats 5 Brinehounds (health set low, Strike) → `HUNT_PROGRESS` 1…5, `TRIAL_PASSED`; a Shellback, or a Brinehound only B hit, does not count.
  - Duel: A accepts → a champion owned by A appears; A's client draws it, B's does not; B's Strikes leave its health unchanged and it never hits B; at the same time B's own duel spawns a second champion owned by B; A defeats theirs → `TRIAL_PASSED`, the model is gone, quest step 3. A timed-out duel removes its champion.
  - Quest: the Brine Colossus at 20 health, A Strikes it → `QUEST_COMPLETE`, R027, +150 Coin, Calling XP +600, quest step back to 0, R022 given (rng 0.5); B, who did not hit it, gets nothing.
  - Sealed trial Relic: with 4 R025 held, the Duel offer shows the sealed text and passing it pays Coin and gives `REWARD_SEALED`.
  - Hard-to-reach caches: C017's prompt from the ground gives `TOO_FAR`; from the top ledge it gives R017.
- [ ] **Step 3: The controller runs the play test in Studio** (build `playtest.project.json`, Test → Server & Clients, 2 players) until the driver prints `DONE` with `failed=0`. Record the result line in the commit message.
- [ ] **Step 4: Write `docs/playtest/M4-checklist.md`** in the M3 checklist's plain style, for what the automated test cannot judge: how each creature looks and moves (wander, chase, giving up at the leash, the Bogspitter backing off, the Colossus slam ring), fighting a pack with abilities, the reward messages and the Coin line, talking to each Warden and reading the window, the feel of Tidewalk and the Gullstep jumps, carrying the parcel, the duel, the quest line in the HUD, climbing to C017, C018 and C026, and the trial window, HUD, claim grid and messages on a phone (Studio's device emulator). Quote on-screen text from `Messages.luau`.
- [ ] **Step 5:** README: "What is in the game now" gains the Creatures and trials line, the Ledger has 30 slots, and step 5 links `docs/playtest/M4-checklist.md`. Once the controller's Studio run has passed, rebuild `dist/IsleOfAvarice.rbxlx` (`bash scripts/check.sh && cp build/IsleOfAvarice.rbxlx dist/IsleOfAvarice.rbxlx`, confirm with `cmp`).
- [ ] **Step 6: Commit** — `docs: M4 play-test checklist and release build`

---

## Out of scope (later milestones)

Edicts, shops and trading (M5), non-Relic card losses on any defeat (M5), parties and ally rewards (M6), 50 Relics and the endgame (M7), pathfinding, creature animations and sound, a quest giver, balance beyond the spec's starting values.

## Known limit

`scripts/check.sh` proves the rules and the build. Creature movement, trial feel and UI are confirmed only by the Studio play test (automated in Task 12) and the owner's hands-on checklist.
