# M2: Combat and Defeat — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Two players can fight with a basic Strike; a defeat opens a blind claim on the victim's Ledger; the Vault, scarcity caps and every PvP protection in the spec work.

**Architecture:** As in M1: every rule is a pure Luau module in `src/shared/Rules`, unit-tested with Lune; thin server services own state and validate every request; the client renders and sends requests. New server services: Vault, Protection, Combat, Claim. Health is the Roblox Humanoid's health, changed only by the server.

**Tech Stack:** Luau (`--!strict`), Rojo 7.7.1, Lune 0.11.1, StyLua 2.6.0 (built with the `luau` feature), Selene 0.31.0, ProfileStore 1.0.3 (vendored), plain Roblox UI instances.

**Spec:** `docs/superpowers/specs/2026-11-10-isle-of-avarice-design.md` revision 4 — sections 3.2 (scarcity), 3.3, 3.4 (Vault, blind claim), 3.5 (protections, basic combat). Not in this plan: the Six Paths and abilities (M3), creatures (M4), Edicts and trading (M5), and the loss of non-Relic cards on defeat (M5, when such cards exist).

## Global Constraints

- **Original content only.** No names, characters, cards, abilities or places from any existing anime, manga, game or other work, in code, data, comments or UI text.
- **Tone:** cartoon knock-outs. Player-facing text says "defeated", never "killed" or "dead". No blood or gore effects.
- Every file under `src/` except `src/server/Vendor` starts with `--!strict`.
- Files under `src/shared/` use no Roblox APIs and require each other only by relative string (`require("./X")`, `require("../Catalog/X")`). They must run unchanged under Lune.
- Rule functions never mutate their arguments; they return new values. Exception: `RateLimiter.allow`.
- The server decides everything. A client request names what the player wants; the server works out targets, positions, damage and results itself. No client-supplied position, target, damage or time is trusted.
- In server handlers, no yielding call between reading state and committing it.
- Damage is applied only with `Humanoid:TakeDamage`.
- Tables sent through RemoteEvents use string keys or gap-free arrays, never sparse numeric keys.
- Saved data contains only strings, numbers, booleans and tables with all-string keys or gap-free arrays.
- Numbers fixed by the spec: Vault size **3**; claim **5** picks, **30** seconds; tier limits Crown 1, Platinum 1, Gold 2, Silver 3, Copper 3; new-player shield ends at **3** Relics held; respawn shield **60** s; Marked **300** s; combat-log window **30** s; claim cooldown **3600** s; health **100**; Strike **20** damage, **0.8** s cooldown, **8** studs reach.
- `bash scripts/check.sh` must pass before every commit (StyLua check on every file, Selene with 0 warnings, Rojo build, all Lune tests).
- Work happens on branch `feat/m2-combat`.

## Review Focus

1. **A claim interrupted at any point** (killer leaves, victim leaves, killer is defeated, time runs out, server shuts down): no card is duplicated or destroyed, and the victim's Ledger is unlocked. Pinned in Task 6 (every pick conserves the total number of copies) and checked by reading in Task 9.
2. **Hostile claim picks** (non-number, NaN, 0, 13, 1.5, a pick with no open claim, a pick on someone else's claim, the same slot twice): refused, and no pick is spent. Pinned in Task 6; Task 9 by reading.
3. **A victim trying to dodge a claim** by discarding, moving, Vaulting or collecting cards while it is open: refused with `LEDGER_LOCKED`. Pinned in Task 7 by reading; rule-level locks tested in Task 2 and Task 3.
4. **Shield abuse:** hoarding spares while shielded, or regaining the shield after losing Relics. The shield ends for good at 3 Relics held, counting spares. Pinned in Task 5.
5. **Farming:** repeat claims on one victim inside an hour, Strikes faster than the cooldown, and Strikes across the safe-zone edge in either direction. Pinned in Task 4 and Task 5.

## File Map

```
src/shared/Types.luau                 + Vault, PlayerData.vault, PlayerData.shieldEnded
src/shared/Net.luau                   + new remote names
src/shared/Catalog/Messages.luau      + M2 messages
src/shared/Rules/Vault.luau           NEW  Vault changes, pruning, sanitising
src/shared/Rules/Scarcity.luau        NEW  server cap checks
src/shared/Rules/Sources.luau         + sealed and locked refusals
src/shared/Rules/Combat.luau          NEW  Strike cooldown, target choice, hit log
src/shared/Rules/Protection.luau      NEW  who may damage whom, shields, Marked, claim cooldown
src/shared/Rules/BlindClaim.luau      NEW  picks, tier limits, moving a card
src/shared/Rules/LedgerView.luau      + vault fields
src/shared/Rules/StatusView.luau      NEW  status lines for the HUD
src/shared/Rules/ClaimView.luau       NEW  claim screen data
src/server/DataService.luau           + new fields, beforeRelease, hold
src/server/LedgerService.luau         + lock, all, onChanged, vault in sync, hardening
src/server/SourceService.luau         + sealed, locked
src/server/VaultService.luau          NEW
src/server/ProtectionService.luau     NEW
src/server/CombatService.luau         NEW
src/server/ClaimService.luau          NEW
src/server/WorldBuilder.luau          + safe-zone disc, no default spawn force field
src/server/Main.server.luau           + start order
src/client/LedgerUI.luau              + Vault buttons
src/client/StatusHUD.luau             NEW
src/client/CombatController.luau      NEW
src/client/ClaimUI.luau               NEW
src/client/Main.client.luau           + wiring
tests/*.spec.luau                     one per new rule module, updates to existing
docs/playtest/M2-checklist.md         NEW
```

---

### Task 1: Messages and server hardening from the M1 backlog

**Files:**
- Modify: `src/shared/Catalog/Messages.luau`, `src/server/LedgerService.luau`, `src/server/SourceService.luau`, `src/server/DataService.luau`, `src/shared/Rules/Sources.luau`, `docs/backlog.md`
- Test: `tests/messages.spec.luau` (new), `tests/sources.spec.luau`

**Interfaces:**
- Produces: `LedgerService.set(player, ledger): boolean` (false when no data is loaded); `Sources.tryCollect` returns a fourth value, the time the cache becomes available again (`number?`, nil on failure).

Add these messages (exact copy):

| code | text |
|---|---|
| SEALED | The island has sealed this Relic. Too many are already held here. |
| LEDGER_LOCKED | Your Ledger is locked while a claim is made against you. |
| VAULTED | {name} is now in your Vault. |
| UNVAULTED | {name} left your Vault. |
| VAULT_FULL | Your Vault is full. |
| NOT_HELD | You do not hold that Relic. |
| CROWN_NO_VAULT | Crown Relics cannot be Vaulted. |
| ALREADY_VAULTED | That Relic is already in your Vault. |
| NOT_VAULTED | That Relic is not in your Vault. |
| NOT_IN_SAFE_ZONE | You can change your Vault only in Tallyport. |
| SHIELD_SELF | You are shielded. Drop your shield to fight. |
| TARGET_SHIELDED | That player is shielded. |
| SAFE_ZONE | No fighting in Tallyport. |
| SHIELD_ENDED | Your new-player shield has ended. Other players can now attack you. |
| MARKED | You started a fight. You are Marked for 5 minutes. |
| DEFEATED_BY | {player} defeated you and is making a claim on your Ledger. |
| CLAIM_STARTED | You defeated {player}. Make your claim. |
| CLAIM_COOLDOWN | You defeated {player}, but you already claimed from them in the last hour. |
| CLAIM_TAKEN | You took {name}! |
| CLAIM_MISS | Nothing there. |
| CLAIM_LOST | {player} took from you: {names}. |
| CLAIM_SAFE | {player} took nothing from you. |
| CLAIM_OVER | The claim is over. |
| ALREADY_PICKED | You already picked that slot. |
| TIER_LIMIT | You cannot take any more Relics of that rarity. |
| BAD_SLOT | That did not work. |

- [ ] **Step 1: Write the failing test `tests/messages.spec.luau`:** a list of every code in the table above plus every M1 code (`GOT_CARD`, `CLAIMED`, `UNCLAIMED`, `DISCARDED`, `FREE_FULL`, `CACHE_EMPTY`, `TOO_FAR`, `ALREADY_CLAIMED`, `NOT_CLAIMED`, `BAD_REQUEST`, `BAD_INDEX`, `UNKNOWN_CARD`, `SLOW_DOWN`, `DATA_NOT_LOADED`, `LEDGER_COMPLETE`); for each, `T.truthy(Messages.format(code) ~= code, code)`. Also `T.eq(Messages.format("CLAIM_LOST", { player = "Ann", names = "Barnacle Key, Bottled Squall" }), "Ann took from you: Barnacle Key, Bottled Squall.")`. Run — Expected: FAIL.
- [ ] **Step 2: Add the messages.** Run — Expected: PASS.
- [ ] **Step 3: `Sources.tryCollect` fourth return value.** Test first in `tests/sources.spec.luau`: on `GOT_CARD` for the Silver cache at `now = 100` the fourth value is `220`; on every failure it is `nil`. Then implement, and make `SourceService` use it for the reappear delay instead of working out the respawn time itself.
- [ ] **Step 4: Server hardening** (each is a backlog item):
  - `LedgerService`: both remote handlers return at once if `player.Parent ~= Players`.
  - `LedgerService`: send `SLOW_DOWN` to a player at most once per second.
  - `LedgerService.set` returns `false` when no data is loaded, `true` otherwise; `SourceService` and the action handler send their success message only when it returns `true`.
  - `DataService`: when the session ends because the player is leaving, do not kick them; on load, a `coin` that is not a finite non-negative number becomes 0.
- [ ] **Step 5:** Remove the items now done from `docs/backlog.md`. Run `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 6: Commit** — `feat: M2 messages and server hardening`

---

### Task 2: Vault rules

**Files:**
- Modify: `src/shared/Types.luau`, `src/shared/Rules/LedgerView.luau`
- Create: `src/shared/Rules/Vault.luau`
- Test: `tests/vault.spec.luau`, `tests/ledger_view.spec.luau`

**Interfaces:**
- Consumes: `Ledger.count(ledger, cardId)`, `Relics.byId`.
- Produces, in `Types.luau`:
```luau
export type Vault = { [CardId]: boolean }
export type PlayerData = { schemaVersion: number, ledger: Ledger, coin: number, vault: Vault, shieldEnded: boolean }
```
- Produces:
```luau
Vault.MAX = 3
Vault.size(vault: Vault): number
Vault.prune(vault: Vault, ledger: Ledger): Vault          -- drops ids the ledger no longer holds
Vault.sanitize(raw: any, ledger: Ledger): Vault           -- never errors; known, held, non-Crown ids with value true; at most 3 (lowest slot numbers kept)
-- request: { kind = "add" | "remove", cardId = string }
Vault.apply(vault: Vault?, ledger: Ledger?, raw: any, inSafeZone: boolean, locked: boolean)
	: (Vault?, string, CardId?)
-- success: new vault, "VAULTED" | "UNVAULTED", card id
-- failure: nil, code, nil — checked in this order:
--   DATA_NOT_LOADED (vault or ledger nil), LEDGER_LOCKED, BAD_REQUEST (non-table, unknown kind,
--   cardId not a string or longer than 16), NOT_IN_SAFE_ZONE, then
--   add:    UNKNOWN_CARD, CROWN_NO_VAULT, NOT_HELD, ALREADY_VAULTED, VAULT_FULL
--   remove: NOT_VAULTED
```
- `LedgerView.build(ledger: Ledger, vault: Vault?): View` — `vault` defaults to empty. `SlotView` gains `vaulted: boolean` and `canVault: boolean` (held, not Crown, not already vaulted). `View` gains `vaultText: string` (`"1 / 3"`).

- [ ] **Step 1: Write the failing tests.** `tests/vault.spec.luau`, one `T.test` per bullet:
```luau
local held = { claimed = { R001 = true }, free = { "R007", "R007" } }
T.eq({ Vault.apply({}, held, { kind = "add", cardId = "R007" }, true, false) }, { { R007 = true }, "VAULTED", "R007" })
T.eq({ Vault.apply({ R007 = true }, held, { kind = "remove", cardId = "R007" }, true, false) }, { {}, "UNVAULTED", "R007" })
T.eq({ Vault.apply({}, held, { kind = "add", cardId = "R007" }, false, false) }, { nil, "NOT_IN_SAFE_ZONE" })
T.eq({ Vault.apply({}, held, { kind = "add", cardId = "R007" }, true, true) }, { nil, "LEDGER_LOCKED" })
T.eq({ Vault.apply({}, held, { kind = "add", cardId = "R002" }, true, false) }, { nil, "NOT_HELD" })
T.eq({ Vault.apply({ R007 = true }, held, { kind = "add", cardId = "R007" }, true, false) }, { nil, "ALREADY_VAULTED" })
T.eq({ Vault.apply({}, held, { kind = "remove", cardId = "R007" }, true, false) }, { nil, "NOT_VAULTED" })
T.eq({ Vault.apply(nil, held, { kind = "add", cardId = "R007" }, true, false) }, { nil, "DATA_NOT_LOADED" })
-- a full vault (3 held ids) refuses a 4th held id with VAULT_FULL
-- hostile raw values (5, "add", {}, { kind = "steal" }, { kind = "add" }, { kind = "add", cardId = 7 },
--   { kind = "add", cardId = string.rep("R", 17) }) each give { nil, "BAD_REQUEST" }
-- { kind = "add", cardId = "R999" } gives UNKNOWN_CARD
-- apply does not mutate the vault passed in
T.eq(Vault.prune({ R001 = true, R007 = true }, { claimed = { R001 = true }, free = {} }), { R001 = true })
T.eq(Vault.sanitize("junk", held), {})
T.eq(Vault.sanitize({ R001 = true, R002 = true, R999 = true, R007 = "yes" }, held), { R001 = true })
```
A Crown Relic does not exist in the 12-card catalog, so `CROWN_NO_VAULT` is implemented but not tested here; note that in the report.
In `tests/ledger_view.spec.luau`: existing expectations gain `vaulted = false` and the right `canVault`; add a case with `vault = { R002 = true }` giving `slots[2].vaulted == true`, `slots[2].canVault == false`, `vaultText == "1 / 3"`.
- [ ] **Step 2: Run** `lune run tests/run` — Expected: FAIL.
- [ ] **Step 3: Implement `Types`, `Vault.luau`, and the `LedgerView` changes.**
- [ ] **Step 4: Run** `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 5: Commit** — `feat: Vault rules`

---

### Task 3: Scarcity and locked caches

**Files:**
- Create: `src/shared/Rules/Scarcity.luau`
- Modify: `src/shared/Rules/Sources.luau`
- Test: `tests/scarcity.spec.luau`, `tests/sources.spec.luau`

**Interfaces:**
- Consumes: `Tiers.info[tier].serverCap`, `Relics.byId`, `Ledger.count`.
- Produces:
```luau
Scarcity.countHeld(ledgers: { Ledger }, relicId: CardId): number   -- claimed + spare copies across all given ledgers
Scarcity.isSealed(relicId: CardId, held: number): boolean         -- false when the tier has no cap or the id is unknown
```
- `Sources.tryCollect(state, ledger, cache, now, distance, sealed: boolean, locked: boolean): (SourceState, Ledger?, string, number?)`. Check order: `DATA_NOT_LOADED`, `LEDGER_LOCKED`, `TOO_FAR`, `CACHE_EMPTY`, `SEALED`, `FREE_FULL`. Every failure returns the same state.

- [ ] **Step 1: Write the failing tests.**
```luau
-- scarcity.spec: R007 is Silver (cap 8), R010 Gold (cap 4), R012 Platinum (cap 2), R001 Copper (no cap)
T.eq(Scarcity.countHeld({ { claimed = { R007 = true }, free = { "R007" } }, { claimed = {}, free = { "R007", "R001" } } }, "R007"), 3)
T.falsy(Scarcity.isSealed("R007", 7)); T.truthy(Scarcity.isSealed("R007", 8)); T.truthy(Scarcity.isSealed("R007", 9))
T.truthy(Scarcity.isSealed("R012", 2)); T.falsy(Scarcity.isSealed("R001", 1000)); T.falsy(Scarcity.isSealed("R999", 5))
-- sources.spec: every existing tryCollect call gains `false, false`
-- sealed = true on an available cache -> code "SEALED", same state, cache still available
-- locked = true -> "LEDGER_LOCKED", even when also too far
-- sealed and free slots full -> "SEALED" (sealed is checked first)
```
- [ ] **Step 2: Run** — Expected: FAIL. **Step 3: Implement.** **Step 4: Run** `bash scripts/check.sh` — Expected: exit 0. The Rojo build still passes because `SourceService` is updated in Task 7; until then pass `false, false` from `SourceService` in this task so the game keeps working.
- [ ] **Step 5: Commit** — `feat: scarcity caps and locked-cache refusals`

---

### Task 4: Combat rules

**Files:**
- Create: `src/shared/Rules/Combat.luau`
- Test: `tests/combat.spec.luau`

**Interfaces:**
- Consumes: `Types.Vec3`.
- Produces:
```luau
Combat.MAX_HEALTH = 100
Combat.STRIKE_DAMAGE = 20
Combat.STRIKE_COOLDOWN = 0.8
Combat.STRIKE_RANGE = 8
Combat.STRIKE_MIN_DOT = 0.5        -- target must be within 60 degrees of straight ahead
Combat.STRIKE_MAX_HEIGHT = 6       -- maximum vertical gap
Combat.KILL_CREDIT_SECONDS = 15
Combat.COMBAT_LOG_SECONDS = 30
export type Fighter = { id: number, position: Vec3, look: Vec3 }   -- look: facing direction, any length
export type HitLog = { [string]: { attackerId: number, at: number } }  -- key: tostring(victim id)
Combat.canStrike(lastStrikeAt: number?, now: number): boolean
Combat.pickTarget(attacker: Fighter, others: { Fighter }): number?
Combat.recordHit(log: HitLog, victimId: number, attackerId: number, now: number): HitLog
Combat.creditFor(log: HitLog, victimId: number, now: number, windowSeconds: number): number?
Combat.clear(log: HitLog, victimId: number): HitLog
```
- `pickTarget` ignores the y axis for distance and direction, skips a fighter with the attacker's own id, skips anyone farther than `STRIKE_RANGE`, outside the arc, or more than `STRIKE_MAX_HEIGHT` above or below, and returns the id of the nearest remaining fighter. A fighter at the attacker's exact position counts as in the arc. A zero-length `look` gives no target.

- [ ] **Step 1: Write the failing tests `tests/combat.spec.luau`.**
```luau
local me = { id = 1, position = { x = 0, y = 0, z = 0 }, look = { x = 0, y = 0, z = -1 } }
local function at(id, x, y, z) return { id = id, position = { x = x, y = y, z = z }, look = { x = 0, y = 0, z = 1 } } end
T.eq(Combat.pickTarget(me, { at(2, 0, 0, -5) }), 2)
T.eq(Combat.pickTarget(me, { at(2, 0, 0, 5) }), nil)            -- behind
T.eq(Combat.pickTarget(me, { at(2, 5, 0, -5) }), 2)             -- 45 degrees off, distance 7.07
T.eq(Combat.pickTarget(me, { at(2, 7, 0, -2) }), nil)           -- outside the arc
T.eq(Combat.pickTarget(me, { at(2, 0, 0, -8.1) }), nil)         -- out of reach
T.eq(Combat.pickTarget(me, { at(2, 0, 0, -8) }), 2)             -- exactly at reach
T.eq(Combat.pickTarget(me, { at(2, 0, 7, -3) }), nil)           -- too high
T.eq(Combat.pickTarget(me, { at(2, 5, 0, -5), at(3, 0, 0, -5) }), 3)   -- nearest wins
T.eq(Combat.pickTarget(me, { at(1, 0, 0, -2) }), nil)           -- never yourself
T.eq(Combat.pickTarget({ id = 1, position = me.position, look = { x = 0, y = 0, z = 0 } }, { at(2, 0, 0, -5) }), nil)
T.truthy(Combat.canStrike(nil, 10)); T.falsy(Combat.canStrike(10, 10.79)); T.truthy(Combat.canStrike(10, 10.8))
local log = Combat.recordHit({}, 2, 1, 100)
T.eq(Combat.creditFor(log, 2, 115, 15), 1); T.eq(Combat.creditFor(log, 2, 115.1, 15), nil)
T.eq(Combat.creditFor(log, 2, 130, 30), 1); T.eq(Combat.creditFor(log, 3, 100, 15), nil)
T.eq(Combat.creditFor(Combat.recordHit(log, 2, 5, 110), 2, 112, 15), 5)   -- latest attacker gets credit
T.eq(Combat.clear(log, 2), {}); T.eq(Combat.creditFor(log, 2, 101, 15), 1) -- clear did not mutate
```
- [ ] **Step 2: Run** — Expected: FAIL. **Step 3: Implement.** **Step 4: Run** `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 5: Commit** — `feat: combat rules`

---

### Task 5: Protection rules

**Files:**
- Create: `src/shared/Rules/Protection.luau`
- Test: `tests/protection.spec.luau`

**Interfaces:**
- Consumes: `World.townRadius` (40), `Combat.HitLog`, `Types`.
- Produces:
```luau
Protection.SHIELD_RELICS = 3
Protection.RESPAWN_SHIELD_SECONDS = 60
Protection.MARKED_SECONDS = 300
Protection.RETALIATE_SECONDS = 30
Protection.CLAIM_COOLDOWN_SECONDS = 3600
export type Status = { inSafeZone: boolean, newShield: boolean, respawnShieldUntil: number, markedUntil: number }
export type ClaimHistory = { [string]: number }       -- key: killerId .. ":" .. victimId -> time of last claim
Protection.inSafeZone(position: Vec3): boolean        -- horizontal distance from the origin <= World.townRadius
Protection.shouldEndShield(ledger: Ledger): boolean   -- claimed + spare Relics >= 3
Protection.isMarked(status: Status, now: number): boolean
Protection.isShielded(status: Status, now: number): boolean   -- new-player shield or respawn shield active
Protection.canDamage(attacker: Status, victim: Status, now: number): (boolean, string?)
Protection.isAggressor(log: Combat.HitLog, attackerId: number, victimId: number, victimMarked: boolean, now: number): boolean
Protection.canClaim(history: ClaimHistory, killerId: number, victimId: number, now: number): boolean
Protection.recordClaim(history: ClaimHistory, killerId: number, victimId: number, now: number): ClaimHistory
```
- `canDamage` refusals, checked in this order: attacker has the new-player shield → `SHIELD_SELF`; victim shielded (either kind) → `TARGET_SHIELDED`; victim in the safe zone and not Marked → `SAFE_ZONE`; attacker in the safe zone and victim not Marked → `SAFE_ZONE`. Otherwise `true`. An attacker's own respawn shield does not block the Strike (the service ends it).
- `isAggressor` is `false` when the victim is Marked, or when the log shows the victim hit the attacker within `RETALIATE_SECONDS`; otherwise `true`.

- [ ] **Step 1: Write the failing tests `tests/protection.spec.luau`.**
```luau
local function st(over) local s = { inSafeZone = false, newShield = false, respawnShieldUntil = 0, markedUntil = 0 }
	for k, v in over or {} do s[k] = v end return s end
T.truthy(Protection.inSafeZone({ x = 40, y = 99, z = 0 })); T.falsy(Protection.inSafeZone({ x = 40.1, y = 0, z = 0 }))
T.truthy(Protection.inSafeZone({ x = 28, y = 0, z = 28 }))  -- 39.6 from the origin
T.eq({ Protection.canDamage(st(), st(), 100) }, { true })
T.eq({ Protection.canDamage(st({ newShield = true }), st(), 100) }, { false, "SHIELD_SELF" })
T.eq({ Protection.canDamage(st(), st({ newShield = true }), 100) }, { false, "TARGET_SHIELDED" })
T.eq({ Protection.canDamage(st(), st({ respawnShieldUntil = 101 }), 100) }, { false, "TARGET_SHIELDED" })
T.eq({ Protection.canDamage(st(), st({ respawnShieldUntil = 100 }), 100) }, { true })
T.eq({ Protection.canDamage(st({ respawnShieldUntil = 150 }), st(), 100) }, { true })
-- Review Focus 5: the safe-zone edge, both directions
T.eq({ Protection.canDamage(st(), st({ inSafeZone = true }), 100) }, { false, "SAFE_ZONE" })
T.eq({ Protection.canDamage(st({ inSafeZone = true }), st(), 100) }, { false, "SAFE_ZONE" })
-- a Marked player gets no protection from the safe zone
T.eq({ Protection.canDamage(st(), st({ inSafeZone = true, markedUntil = 200 }), 100) }, { true })
T.eq({ Protection.canDamage(st({ inSafeZone = true }), st({ inSafeZone = true, markedUntil = 200 }), 100) }, { true })
T.eq({ Protection.canDamage(st({ inSafeZone = true, markedUntil = 200 }), st({ inSafeZone = true }), 100) }, { false, "SAFE_ZONE" })
-- Review Focus 4: spares count toward ending the shield
T.falsy(Protection.shouldEndShield({ claimed = { R001 = true }, free = { "R002" } }))
T.truthy(Protection.shouldEndShield({ claimed = {}, free = { "R001", "R001", "R001" } }))
T.truthy(Protection.shouldEndShield({ claimed = { R001 = true, R002 = true }, free = { "R003" } }))
-- aggressor
local log = Combat.recordHit({}, 1, 2, 100)   -- player 2 hit player 1 at t=100
T.falsy(Protection.isAggressor(log, 1, 2, false, 120))   -- 1 hits back within 30 s
T.truthy(Protection.isAggressor(log, 1, 2, false, 130.1))
T.truthy(Protection.isAggressor(log, 3, 2, false, 101))  -- a third player joining in is an aggressor
T.falsy(Protection.isAggressor({}, 1, 2, true, 100))     -- attacking a Marked player never Marks you
-- Review Focus 5: claim cooldown
local h = Protection.recordClaim({}, 1, 2, 1000)
T.falsy(Protection.canClaim(h, 1, 2, 4599)); T.truthy(Protection.canClaim(h, 1, 2, 4600))
T.truthy(Protection.canClaim(h, 2, 1, 1001)); T.truthy(Protection.canClaim(h, 1, 3, 1001)); T.truthy(Protection.canClaim({}, 1, 2, 0))
```
- [ ] **Step 2: Run** — Expected: FAIL. **Step 3: Implement.** **Step 4: Run** `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 5: Commit** — `feat: protection rules`

---

### Task 6: Blind-claim rules

**Files:**
- Create: `src/shared/Rules/BlindClaim.luau`, `src/shared/Rules/ClaimView.luau`
- Test: `tests/blind_claim.spec.luau`, `tests/claim_view.spec.luau`

**Interfaces:**
- Consumes: `Relics.list`, `Relics.byId`, `Relics.count`, `Ledger.add`, `Ledger.FREE_SLOTS`, `Types.Vault`.
- Produces:
```luau
BlindClaim.PICKS = 5
BlindClaim.DURATION = 30
BlindClaim.TIER_LIMIT = { Crown = 1, Platinum = 1, Gold = 2, Silver = 3, Copper = 3 }
export type Claim = {
	picksLeft: number,
	expiresAt: number,
	taken: { [string]: number },        -- tier -> number taken so far
	picked: { [string]: string },       -- tostring(slot) -> "TAKEN" | "MISS"
	takenIds: { CardId },               -- in the order taken
}
BlindClaim.start(now: number): Claim
BlindClaim.isOpen(claim: Claim, now: number): boolean        -- picksLeft > 0 and now < expiresAt
BlindClaim.pick(claim: Claim, victim: Ledger, victimVault: Vault, killer: Ledger, rawSlot: any, now: number)
	: (Claim, Ledger, Ledger, string, CardId?)                -- claim, victim ledger, killer ledger, code, card id
```
- `pick` refusals — the same claim and ledgers come back and **no pick is spent**; checked in this order: `CLAIM_OVER` (not open), `BAD_SLOT` (`rawSlot` not an integer in `1..Relics.count`), `ALREADY_PICKED`, `TIER_LIMIT` (that slot's tier has reached its limit).
- Otherwise one pick is spent and the slot is recorded:
  - `MISS` — the victim holds no copy, or the Relic is in `victimVault`, or the killer's free slots are full. Ledgers unchanged.
  - `TAKEN` — one copy moves: the victim's first matching entry in `free` if there is one, otherwise the claimed copy; it is appended to the killer's `free`. The tier count goes up by one and the id is appended to `takenIds`.
- `ClaimView.build(victimName: string, claim: BlindClaim.Claim, now: number): View` where
```luau
export type SlotView = { slot: number, label: string, name: string, tier: Tier, state: "open" | "taken" | "miss" | "locked" }
export type View = { title: string, picksText: string, secondsLeft: number, open: boolean, slots: { SlotView } }
```
  `title` is `"Claim on <victimName>"`, `picksText` is `"Picks left: N"`, `secondsLeft` is the ceiling of the time left and never below 0, `locked` means the tier limit is reached or the claim is not open.

- [ ] **Step 1: Write the failing tests.** `tests/blind_claim.spec.luau`:
```luau
local victim = { claimed = { R001 = true, R007 = true, R012 = true }, free = { "R007", "R002" } }
local killer = { claimed = {}, free = {} }
local c0 = BlindClaim.start(100)
T.eq(c0, { picksLeft = 5, expiresAt = 130, taken = {}, picked = {}, takenIds = {} })
-- a spare is taken before the claimed copy
local c1, v1, k1, code1, id1 = BlindClaim.pick(c0, victim, {}, killer, 7, 101)
T.eq({ code1, id1 }, { "TAKEN", "R007" })
T.eq(v1, { claimed = { R001 = true, R007 = true, R012 = true }, free = { "R002" } })
T.eq(k1, { claimed = {}, free = { "R007" } })
T.eq(c1, { picksLeft = 4, expiresAt = 130, taken = { Silver = 1 }, picked = { ["7"] = "TAKEN" }, takenIds = { "R007" } })
-- the claimed copy is taken when there is no spare
local _, v2, k2, code2 = BlindClaim.pick(c0, victim, {}, killer, 1, 101)
T.eq(code2, "TAKEN"); T.eq(v2.claimed.R001, nil); T.eq(k2.free, { "R001" })
-- misses spend a pick and change nothing
local c3, v3, k3, code3, id3 = BlindClaim.pick(c0, victim, {}, killer, 3, 101)     -- victim does not hold R003
T.eq({ code3, id3, c3.picksLeft, c3.picked["3"] }, { "MISS", nil, 4, "MISS" }); T.eq(v3, victim); T.eq(k3, killer)
T.eq(select(4, BlindClaim.pick(c0, victim, { R012 = true }, killer, 12, 101)), "MISS")   -- Vaulted
-- a killer with 20 free cards gets MISS and the victim keeps the card
-- refusals spend nothing (Review Focus 2)
for _, bad in { 0, 13, 1.5, -1, 0 / 0, math.huge, "7", true, {} } do
	local c, v, k, code = BlindClaim.pick(c0, victim, {}, killer, bad, 101)
	T.eq(code, "BAD_SLOT", tostring(bad)); T.eq(c, c0); T.eq(v, victim); T.eq(k, killer)
end
T.eq(select(4, BlindClaim.pick(c0, victim, {}, killer, nil, 101)), "BAD_SLOT")
T.eq(select(4, BlindClaim.pick(c1, v1, {}, k1, 7, 102)), "ALREADY_PICKED")
T.eq(select(4, BlindClaim.pick(c0, victim, {}, killer, 7, 130)), "CLAIM_OVER")         -- time is up at exactly 130
-- after 5 picks every further pick is CLAIM_OVER
-- tier limit: the 12-card catalog has no tier with more Relics than its limit, so the limit cannot be
--   reached by picking. Build the case by hand: a claim with taken = { Gold = 2 } refuses slot 10 with
--   TIER_LIMIT and spends nothing
-- inputs are never mutated: victim, killer and c0 deep-equal fresh copies after every call above
-- Review Focus 1: conservation. For every slot 1..12 and for vault = {} and vault = { R007 = true }:
--   Ledger.count(victim', id) + Ledger.count(killer', id) == Ledger.count(victim, id) + Ledger.count(killer, id)
--   for every Relic id, after each pick in a 5-pick sequence
```
`tests/claim_view.spec.luau`: a fresh claim gives 12 slots all `"open"`, `picksText == "Picks left: 5"`, `secondsLeft == 30` at `now = 100`, `title == "Claim on Ann"`; after the `c1` above slot 7 is `"taken"`; a claim with `taken.Platinum = 1` shows slot 12 `"locked"`; at `now = 130` `open == false`, `secondsLeft == 0` and every unpicked slot is `"locked"`.
- [ ] **Step 2: Run** — Expected: FAIL. **Step 3: Implement both modules.** **Step 4: Run** `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 5: Commit** — `feat: blind-claim rules`

---

### Task 7: Server plumbing — data, Ledger locks, Vault and sealed caches

**Files:**
- Modify: `src/shared/Net.luau`, `src/server/DataService.luau`, `src/server/LedgerService.luau`, `src/server/SourceService.luau`, `src/server/Main.server.luau`, `src/client/Main.client.luau`, `tests/net.spec.luau`, `tests/build.spec.luau`
- Create: `src/server/VaultService.luau`

**Interfaces:**
- Consumes: `Vault.*` (Task 2), `Scarcity.*` and the new `Sources.tryCollect` (Task 3), `Protection.inSafeZone` (Task 5).
- Produces, in `Net.luau` (all names equal their keys):
  - `VaultAction` — client → server: `(request: table)`
  - `StatusSync` — server → one client: `(status: { newShield: boolean, respawnShieldSeconds: number, markedSeconds: number })`
  - `ShieldDrop` — client → server: `()`
  - `Strike` — client → server: `()`
  - `HitFx` — server → all clients: `(victimUserId: number)`
  - `ClaimUpdate` — server → one client: `(payload: { victimName: string, claim: Claim, secondsLeft: number }?)`, nil closes the screen
  - `ClaimPick` — client → server: `(slot: number)`
  - `LedgerSync` now carries `(ledger: Ledger, vault: Vault)`.
- Produces:
```luau
DataService.beforeRelease(callback: (player: Player) -> ()): ()   -- runs inside PlayerRemoving, before the profile is released
DataService.hold(player: Player): () -> ()                       -- keeps the profile open; call the returned function to let go
LedgerService.makeRemote(name: string): RemoteEvent              -- creates a RemoteEvent in the Remotes folder (other services use it)
LedgerService.getVault(player: Player): Vault?
LedgerService.setVault(player: Player, vault: Vault): boolean
LedgerService.all(): { Ledger }                                  -- Ledgers of every player whose data is loaded
LedgerService.lock(player: Player): ()
LedgerService.unlock(player: Player): ()
LedgerService.isLocked(player: Player): boolean
LedgerService.onChanged(callback: (player: Player, ledger: Ledger) -> ()): ()
LedgerService.notifyAll(code: string, args: { [string]: string }?): ()
VaultService.start(): ()
```

- [ ] **Step 1: `Net.luau` and `tests/net.spec.luau`** — test first, then add the names.
- [ ] **Step 2: `DataService`**
  - Template gains `vault = {}` and `shieldEnded = false`. On load, after the Ledger is sanitised: `data.vault = Vault.sanitize(data.vault, data.ledger)`; a `shieldEnded` that is not a boolean becomes `false`.
  - `PlayerRemoving`: run every `beforeRelease` callback (each in `pcall`), then wait until the player has no holds or 45 seconds have passed, then end the session. `get` keeps working for a held player.
  - A second `hold` on the same player stacks; each returned function lets go once only.
- [ ] **Step 3: `LedgerService`**
  - `set` prunes the Vault with `Vault.prune` after storing the Ledger, sends `LedgerSync(ledger, vault)` only if `player.Parent == Players`, then runs the `onChanged` callbacks.
  - The action handler passes through `LEDGER_LOCKED` when `isLocked(player)` — checked before `LedgerActions.apply`.
  - Locks are dropped on `PlayerRemoving` only if the player is not held; `unlock` is always safe to call.
- [ ] **Step 4: `VaultService`** — handles `VaultAction` with the same per-player rate limit style as `LedgerService` (capacity 10, refill 5 per second): `Vault.apply(getVault, get, request, inSafeZone, isLocked)`, where `inSafeZone` comes from `Protection.inSafeZone` on the player's `HumanoidRootPart` position (`false` if there is no character); then `setVault` and a notify with the Relic name, or a notify with the failure code.
- [ ] **Step 5: `SourceService`** — pass `sealed = Scarcity.isSealed(relicId, Scarcity.countHeld(LedgerService.all(), relicId))` and `locked = LedgerService.isLocked(player)` to `tryCollect`. Show sealed caches: whenever a Ledger changes (`LedgerService.onChanged`), a player's data loads, or a player leaves (checked one frame later), work out for every cache whether its Relic is sealed; a sealed cache's prompt reads `ObjectText = "Sealed cache"` and its `Pillar` uses `Material = SmoothPlastic`; an unsealed one reads `"Cache"` with `Neon`.
- [ ] **Step 6: Client and start order** — `Main.client.luau` passes the Vault to `LedgerView.build(ledger, vault)`. `Main.server.luau` starts `VaultService` after `SourceService` and before `DataService`. Add `Server.VaultService` to `tests/build.spec.luau`.
- [ ] **Step 7: Run** `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 8: Commit** — `feat: saved Vault, Ledger locks and sealed caches on the server`

No behaviour tests: Roblox engine glue. The reviewer checks Review Focus 3 by reading: every path that changes a Ledger or Vault refuses a locked player.

---

### Task 8: Server — protection and combat

**Files:**
- Create: `src/server/ProtectionService.luau`, `src/server/CombatService.luau`
- Modify: `src/server/WorldBuilder.luau`, `src/server/Main.server.luau`, `tests/build.spec.luau`, `isle.yml` if a new Roblox global is needed

**Interfaces:**
- Consumes: `Protection.*`, `Combat.*`, `LedgerService.get/notify/notifyAll/onChanged/makeRemote`, `DataService.get/onLoaded`, `Net.*`.
- Produces:
```luau
ProtectionService.start(): ()
ProtectionService.status(player: Player, now: number): Protection.Status?   -- nil without loaded data or a living character
ProtectionService.mark(player: Player, now: number): ()
ProtectionService.endRespawnShield(player: Player): ()
CombatService.start(): ()
CombatService.onDefeat(callback: (killer: Player, victim: Player) -> ()): ()   -- player-versus-player defeats and combat logs
```

- [ ] **Step 1: `WorldBuilder`** — the `SpawnLocation` gets `Duration = 0` (no default force field). Add a safe-zone marker: a flat cylinder of radius 40 centred on the origin, 0.1 studs above the plaza top, pale gold, `Transparency = 0.8`, `CanCollide = false`, `Material = Neon`.
- [ ] **Step 2: `ProtectionService`**
  - State per player: `respawnShieldUntil`, `markedUntil`. `shieldEnded` lives in saved data.
  - `CharacterAdded`: `respawnShieldUntil = now + 60`; put a `ForceField` named `Shield` in the character if the player is shielded in either way.
  - New-player shield ends, for good, when `Protection.shouldEndShield(ledger)` becomes true (subscribe with `LedgerService.onChanged`, and check once on load) or when the player fires `ShieldDrop`: set `data.shieldEnded = true`, notify `SHIELD_ENDED`.
  - The `Shield` force field is removed when neither shield applies; a task started on spawn removes it when the respawn shield runs out.
  - `mark`: `markedUntil = now + 300`, notify `MARKED`, and put a `BillboardGui` named `MarkedTag` above the character's head (red text "MARKED", `AlwaysOnTop = true`, `MaxDistance = 200`); it is removed after 300 seconds and re-added on respawn while still Marked.
  - Send `StatusSync` to the player whenever any of the three values changes and on spawn.
  - Clear state on `PlayerRemoving`.
- [ ] **Step 3: `CombatService`**
  - On `CharacterAdded`: set `Humanoid.MaxHealth` and `Health` to 100, and connect `Humanoid.Died`.
  - `Strike` handler, in order: ignore a player with no living character; ignore if `Combat.canStrike` is false (no message), else record the Strike time; build the fighter list from every other player's living character (`HumanoidRootPart.Position` and `CFrame.LookVector`); `Combat.pickTarget`; if none, stop; `Protection.canDamage(attackerStatus, victimStatus, now)` — on refusal notify the attacker with the code and stop; `ProtectionService.endRespawnShield(attacker)`; if `Protection.isAggressor(...)` then `ProtectionService.mark(attacker, now)`; `victimHumanoid:TakeDamage(20)`; record the hit; fire `HitFx` to all clients.
  - `Humanoid.Died`: `Combat.creditFor(log, victimId, now, 15)`; clear the victim's log entry; if the credited player is still in the game, run the `onDefeat` callbacks.
  - Combat log: register `DataService.beforeRelease`; if `Combat.creditFor(log, leaverId, now, 30)` names a player still in the game, run the `onDefeat` callbacks with the leaver as victim.
  - Time comes from `os.clock()` everywhere in this service and in `ProtectionService`.
- [ ] **Step 4: Start order in `Main.server.luau`:** `WorldBuilder.build`, `LedgerService.start`, `SourceService.start`, `VaultService.start`, `ProtectionService.start`, `CombatService.start`, `DataService.start`. Add both services to `tests/build.spec.luau`.
- [ ] **Step 5: Run** `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 6: Commit** — `feat: protection and combat services`

No behaviour tests: engine glue. The reviewer checks by reading that no client value is trusted, that damage only goes through `TakeDamage`, and Review Focus 5.

---

### Task 9: Server — the claim service

**Files:**
- Create: `src/server/ClaimService.luau`
- Modify: `src/server/Main.server.luau`, `tests/build.spec.luau`

**Interfaces:**
- Consumes: `BlindClaim.*`, `Protection.canClaim/recordClaim`, `CombatService.onDefeat`, `LedgerService.get/set/getVault/lock/unlock/notify/makeRemote`, `DataService.hold`, `Relics.byId`.
- Produces: `ClaimService.start(): ()`

- [ ] **Step 1: Implement `ClaimService`**
  - On defeat `(killer, victim)`:
    - Notify the victim `DEFEATED_BY` only when a claim opens.
    - Do nothing if either Ledger is not loaded, the killer already has an open claim, or the victim is already locked.
    - If `Protection.canClaim` is false: notify the killer `CLAIM_COOLDOWN` with the victim's name and stop.
    - Otherwise: record the claim in the history (keys are `UserId`s), `DataService.hold(victim)`, `LedgerService.lock(victim)`, `BlindClaim.start(now)`, notify the killer `CLAIM_STARTED`, send `ClaimUpdate`, and start a 30-second timer that closes the claim.
  - `ClaimPick` handler: find the open claim for this killer (none → ignore); `BlindClaim.pick(claim, victimLedger, victimVault, killerLedger, slot, now)`; on `TAKEN` write both Ledgers with `LedgerService.set`, with no yield between the pick and the two writes; notify the killer `CLAIM_TAKEN` with the Relic name or `CLAIM_MISS`, or the refusal code; send `ClaimUpdate`; close the claim if it is no longer open.
  - Closing a claim, from any path (no picks left, timer, killer leaves, killer's data unloads, victim's data is gone): runs once only; unlock the victim; let go of the hold; send `ClaimUpdate(nil)` and `CLAIM_OVER` to the killer if still in the game; notify the victim, if still in the game, `CLAIM_LOST` with the taken Relic names joined by ", " or `CLAIM_SAFE`.
  - If a write fails because the victim's data is gone, close the claim; never write one side without the other. Read both Ledgers, and check both are loaded, before writing either.
  - Rate limit `ClaimPick` per player (capacity 10, refill 5 per second).
- [ ] **Step 2: Start `ClaimService` after `CombatService` in `Main.server.luau`; add it to `tests/build.spec.luau`.**
- [ ] **Step 3: Run** `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 4: Commit** — `feat: blind-claim service`

No behaviour tests: engine glue. The reviewer checks Review Focus 1 and 2 by reading every path that closes a claim.

---

### Task 10: Client — status, Strike and the Vault buttons

**Files:**
- Create: `src/shared/Rules/StatusView.luau`, `src/client/StatusHUD.luau`, `src/client/CombatController.luau`
- Modify: `src/client/LedgerUI.luau`, `src/client/Main.client.luau`, `tests/build.spec.luau`
- Test: `tests/status_view.spec.luau`

**Interfaces:**
- Consumes: `Net.*`, `Combat.STRIKE_COOLDOWN`, `Protection.inSafeZone`, `LedgerView` vault fields.
- Produces:
```luau
export type Line = { text: string, kind: "safe" | "shield" | "marked" }
StatusView.build(status: { newShield: boolean, respawnShieldSeconds: number, markedSeconds: number }?, inSafeZone: boolean): { Line }
StatusHUD.mount(playerGui: PlayerGui, onDropShield: () -> ()): ()
StatusHUD.render(lines: { StatusView.Line }, showDropShield: boolean): ()
CombatController.start(strike: () -> (), isBlocked: () -> boolean): ()
CombatController.flash(character: Model): ()
LedgerUI.isOpen(): boolean
LedgerUI.mount(playerGui, onAction, onVault: (request: { [string]: any }) -> ())   -- third parameter is new
```
- `StatusView.build` lines, in this order, each only when it applies: `{ "Safe zone", "safe" }`; `{ "New-player shield", "shield" }`; `{ "Respawn shield: 42s", "shield" }` (seconds rounded up); `{ "MARKED 4:31", "marked" }` (minutes:seconds, seconds two digits). A nil status gives only the safe-zone line when inside.

- [ ] **Step 1: Write the failing tests `tests/status_view.spec.luau`.**
```luau
T.eq(StatusView.build(nil, false), {})
T.eq(StatusView.build(nil, true), { { text = "Safe zone", kind = "safe" } })
T.eq(StatusView.build({ newShield = true, respawnShieldSeconds = 41.2, markedSeconds = 0 }, true), {
	{ text = "Safe zone", kind = "safe" }, { text = "New-player shield", kind = "shield" }, { text = "Respawn shield: 42s", kind = "shield" } })
T.eq(StatusView.build({ newShield = false, respawnShieldSeconds = 0, markedSeconds = 271 }, false), { { text = "MARKED 4:31", kind = "marked" } })
T.eq(StatusView.build({ newShield = false, respawnShieldSeconds = 0, markedSeconds = 60 }, false)[1].text, "MARKED 1:00")
```
- [ ] **Step 2: Run** — Expected: FAIL. **Step 3: Implement `StatusView`.** Run — Expected: PASS.
- [ ] **Step 4: Implement the client**
  - `StatusHUD`: a `ScreenGui` with a top-left column of labels (green for safe, blue for shield, red for marked) and a "Drop shield" button shown only while the new-player shield is on. The button asks "Other players will be able to attack you. Drop it?" with Yes and No before calling `onDropShield`.
  - `Main.client.luau` keeps the last `StatusSync` and the time it arrived, and re-renders the HUD twice a second, counting the seconds down locally and testing `Protection.inSafeZone` on the local character's position.
  - `CombatController.start`: binds one action with `ContextActionService:BindAction("Strike", handler, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.F)` (the `true` adds a touch button on phones; set its title to "Strike"). On input begin, if `isBlocked()` is false and 0.8 seconds have passed since the last local Strike, call `strike()`. `isBlocked` is true while the Ledger book or the claim screen is open.
  - `CombatController.flash`: adds a white `Highlight` to the character for 0.15 seconds. `Main.client.luau` calls it on `HitFx` for the character of the player with that `UserId`.
  - `LedgerUI`: show `vaultText` beside the other counts ("Vault: 1 / 3"). On each numbered slot, a small corner button reading "Vault" when `canVault`, or "Vaulted" when `vaulted`; pressing it calls `onVault({ kind = "add" | "remove", cardId = ... })` and must not also trigger the slot's unclaim. Vaulted slots show a gold outline.
- [ ] **Step 5: Add the new modules to `tests/build.spec.luau`. Run** `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 6: Commit** — `feat: status HUD, Strike input and Vault buttons`

---

### Task 11: Client — the claim screen

**Files:**
- Create: `src/client/ClaimUI.luau`
- Modify: `src/client/Main.client.luau`, `tests/build.spec.luau`

**Interfaces:**
- Consumes: `ClaimView.build(victimName, claim, now)`, `Tiers.info[tier].color`, `Net.ClaimUpdate`, `Net.ClaimPick`.
- Produces:
```luau
ClaimUI.mount(playerGui: PlayerGui, onPick: (slot: number) -> ()): ()
ClaimUI.show(victimName: string, claim: BlindClaim.Claim, secondsLeft: number): ()
ClaimUI.hide(): ()
ClaimUI.isOpen(): boolean
```

- [ ] **Step 1: Implement `ClaimUI`** — a centred panel above everything else (`DisplayOrder` higher than the Ledger book), with the title, picks left, a seconds countdown that ticks locally from `secondsLeft`, and a grid of every numbered slot. Each cell shows the slot label, the Relic name and the tier colour, face-down style: nothing shows whether the victim holds it. States: `open` — clickable, calls `onPick(slot)`; `taken` — bright, text "Taken!"; `miss` — dark, text "Nothing"; `locked` — greyed out, not clickable. A line under the title reads "Pick the Relics you think they hold. You are not told why a pick misses." A "Done" button hides the screen locally (the server closes the claim on its timer).
- [ ] **Step 2: Wire `Main.client.luau`** — `ClaimUpdate(payload)` → `ClaimUI.show(...)` or, for nil, `ClaimUI.hide()`; `onPick` fires `ClaimPick`. The Strike `isBlocked` check includes `ClaimUI.isOpen()`.
- [ ] **Step 3: Add `Client.ClaimUI` to `tests/build.spec.luau`. Run** `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 4: Commit** — `feat: blind-claim screen`

---

### Task 12: Owner hand-off

**Files:**
- Create: `docs/playtest/M2-checklist.md`
- Modify: `README.md`, `dist/IsleOfAvarice.rbxlx`

- [ ] **Step 1: Write `docs/playtest/M2-checklist.md`** in the same plain style as the M1 checklist. Every step needs two players: explain once, at the top, how to start a two-player test in Studio (Test tab, Clients and Servers section, 2 players, Start) and that each player gets its own window. Steps, each with "what to do" and "what should happen", quoting the real on-screen text from `Messages.luau`:
  1. Both players spawn; each sees "New-player shield" and "Safe zone" at the top left, and a shimmer around their character.
  2. Player A strikes player B (click, or F): "You are shielded. Drop your shield to fight."
  3. Player A presses "Drop shield" and confirms: "Your new-player shield has ended…". A strikes B in town: "That player is shielded."
  4. B collects three Relics: B's shield ends by itself.
  5. Both leave town. A strikes B: B's health bar drops by a fifth; A shows a red MARKED tag; A sees "You started a fight…".
  6. B strikes back: B is not Marked.
  7. A walks into town while Marked; B follows and strikes A there: it works. A strikes B in town: "No fighting in Tallyport."
  8. Outside town, A defeats B (5 Strikes). A sees the claim screen; B respawns in town and sees "… defeated you and is making a claim on your Ledger."
  9. While the claim is open, B tries to discard a card: "Your Ledger is locked…".
  10. A picks a slot B holds: "You took …!", and the Relic appears in A's free slots. A picks a slot B does not hold: "Nothing there."
  11. The claim ends after 5 picks or 30 seconds; B sees what was taken.
  12. B respawns with "Respawn shield: 60s"; A cannot hurt B until it runs out.
  13. A defeats B again within the hour: no claim screen; "… you already claimed from them in the last hour."
  14. The Vault: in town, B opens the Ledger and presses "Vault" on a held Relic: "… is now in your Vault." Outside town the same button gives "You can change your Vault only in Tallyport." (Use a third test, with A and B swapped, to check a Vaulted Relic is never taken.)
  15. Combat log: B hits A, then A's window is closed within 30 seconds: B gets the claim screen.
  16. Scarcity (optional — it takes about 20 minutes of waiting, because the Platinum cache refills only every 10 minutes): A collects "The Hoarder's Thumbprint"; ten minutes later B collects it; the pillar then stops glowing and the prompt reads "Sealed cache"; when the cache refills, a third attempt by either player says "The island has sealed this Relic…".
- [ ] **Step 2: Update `README.md`** — what is in the game now, and a link to the M2 checklist.
- [ ] **Step 3: Rebuild the release place** — `bash scripts/check.sh && cp build/IsleOfAvarice.rbxlx dist/IsleOfAvarice.rbxlx`; confirm with `cmp`.
- [ ] **Step 4: Commit** — `docs: M2 play-test checklist and release build`

---

## Out of scope (later milestones)

The Six Paths and abilities, Strike animations and sound, creatures, trials, Coin earning, shops, Edicts (including the one-third loss of non-Relic cards on defeat), trading, the completion ceremony, a map, hand-made art, movement anti-cheat.

## Known limit

As in M1, nothing here can be run inside Roblox from the cloud workspace, and combat needs two players. `scripts/check.sh` proves the rules and the build. The owner's two-player test with `docs/playtest/M2-checklist.md` is the only proof the game works.
