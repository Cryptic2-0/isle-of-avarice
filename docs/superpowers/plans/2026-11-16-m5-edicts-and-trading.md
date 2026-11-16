# M5: Edicts, the Shop and Trading — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Five single-use Edict cards live in free slots (track holders, look inside a Ledger, hide, two teleports); an Edict Hall clerk in Tallyport sells Edict packs and Copper Relics and buys spare cards; two players can swap cards and Coin in a window both must confirm; every defeat destroys a third of the victim's Edicts.

**Architecture:** As in M1–M4. Every rule is a pure Luau module in `src/shared/Rules`, unit-tested with Lune; thin server services own state and check every request; the client renders view data and sends requests. A card is now a Relic or an Edict: `Catalog/Cards` answers "what is this id", and `Ledger` accepts both in free slots.

**Spec:** `docs/superpowers/specs/2026-11-10-isle-of-avarice-design.md` revision 7 — section 3.13 (all M5 values and rulings), with 3.1, 3.4, 3.6, 3.7.

**Branch:** `feat/m5-edicts`, based on `feat/m4-creatures` at `020504d`.

## Global Constraints

- Original content only. Tone as before: "defeated", never "killed".
- Every file under `src/` except `src/server/Vendor` starts with `--!strict`. Files under `src/shared/` use no Roblox APIs. Rule functions never mutate their arguments (exception: `RateLimiter.allow`).
- The server decides everything. A request names a card, a Relic, a player or an amount; the server checks who, where, when and whether they hold it. No yielding call between reading a Ledger or Coin and writing it back.
- Card moves are atomic (spec 5.3 rule 3): a purchase, a sale and a trade fully happen or do not. A trade writes both Ledgers and both Coin totals in one step with no yield between.
- Coin changes go through `SourceService.addCoin`. Ledger changes go through `LedgerService.set`.
- Saved data shape is unchanged (`ledger.free` simply may hold `E00n` ids), so `schemaVersion` stays 1. Veil and "met" are session state, never saved.
- `bash scripts/check.sh` passes before every commit.

## Review Focus

1. **Hostile requests** on every new remote (`EdictUse`, `ShopAction`, `TradeRequest`, `TradeReply`, `TradeAction`): wrong types, unknown ids, indexes out of range, negative, fractional, NaN or huge Coin, another player's id, a request while dead, locked or unloaded. Each is refused with a code and nothing changes.
2. **No card or Coin is created or destroyed by accident.** Totals before and after a trade are equal; a refused purchase takes no Coin; a sale removes exactly one card and pays once; a double click cannot sell or use one card twice.
3. **The trade switch.** Changing an offer after the other side confirmed clears both confirmations and blocks confirming for 2 seconds; the settle step re-reads both live Ledgers.
4. **Edicts never give an edge they should not:** no Edict moves a card; teleports are refused while Marked, in combat or in a trial; Veil hides from Summons and Audit; Summons never lists the asker.
5. **Old saves and old code paths:** a Ledger holding Edicts survives `sanitize`; an Edict cannot be claimed, Vaulted or taken by a blind claim; Edicts do not count towards ending the new-player shield.

## Tasks

### Task 1: Cards — Edict catalog, card lookup, Ledger accepts Edicts
Files: `Catalog/Edicts.luau`, `Catalog/Cards.luau`, `Catalog/Shop.luau` (prices and stock), `Rules/Ledger.luau`, `Rules/Protection.luau` (`shouldEndShield`), `Rules/LedgerView.luau` (`FreeView.kind`, `canUse`), `Catalog/Messages.luau`, `Net.luau`, `Types.luau`; tests `edicts_catalog.spec`, `cards.spec`, additions to `ledger.spec`, `ledger_view.spec`, `protection.spec`, `messages.spec`, `net.spec`.
- `Cards.info(id): { id, name, kind: "relic" | "edict", tier: Tier? }?`, `Cards.isRelic`, `Cards.isEdict`.
- `Ledger.add` and `Ledger.sanitize` accept any known card; `Ledger.claim` refuses an Edict with `NOT_A_RELIC`; `Ledger.remove(ledger, cardIds): Ledger?` removes a multiset from the free slots (nil when not all held); `Ledger.holdsFree(ledger, cardIds): boolean`; `Ledger.edictCount`.
- Commit: `feat: Edict cards in free slots`

### Task 2: Edict rules
Files: `Rules/EdictRules.luau`, `tests/edict_rules.spec.luau`.
- `parseUse(ledger, raw): (Use?, string)` — `{ freeIndex, cardId, relicId?, targetId? }`; the card at the index must match and be an Edict.
- `canTravel(state, now): (boolean, string?)` — `EDICT_MARKED`, `EDICT_IN_COMBAT`, `EDICT_IN_TRIAL`.
- `holders(people, relicId, askerId): { string }`, `auditTarget(asker, others): number?`, `auditLines(ledger, vault): { string }`, `isVeiled(until, now)`, `arrival(target, isClear): Vec3`, `defeatLoss(ledger, rng): (Ledger, { CardId })`, `near(a, b, range)`.
- Commit: `feat: Edict rules`

### Task 3: Shop rules
Files: `Rules/Shop.luau`, `tests/shop.spec.luau`.
- `Shop.buyPack(ledger, coin, rng)`, `Shop.buyRelic(ledger, coin, rawRelicId)`, `Shop.sell(ledger, coin, rawIndex, rawCardId)`, `Shop.apply(ledger, coin, raw, rng)` (dispatch on `raw.kind`), `Shop.view(ledger, coin): ShopView`.
- Commit: `feat: shop rules`

### Task 4: Trade rules
Files: `Rules/Trade.luau`, `tests/trade.spec.luau`.
- `Trade.new(a, b, now)`, `Trade.setOffer(session, userId, raw, ledger, coin, now)`, `Trade.confirm(session, userId, now)`, `Trade.unconfirm(session, now)`, `Trade.ready(session)`, `Trade.settle(session, ledgerA, coinA, ledgerB, coinB)`, `Trade.prune(session, userId, ledger, coin, now)` (drops an offer the player can no longer cover), `Trade.view(session, viewerId, names, ledger, coin, now): TradeView`.
- Commit: `feat: trade rules`

### Task 5: Server — EdictService, ShopService, TradeService, the clerk

**Files:**
- Create: `src/server/EdictService.luau`, `src/server/ShopService.luau`, `src/server/TradeService.luau`
- Modify: `src/shared/Rules/Trade.luau`, `src/shared/Catalog/World.luau`, `src/server/CombatService.luau`, `src/server/WorldBuilder.luau`, `src/server/Main.server.luau`, `tests/build.spec.luau`
- Tests already written and failing in the working tree (uncommitted; they are this task's RED): the last two tests of `tests/trade.spec.luau` (`Trade.unconfirm`, `Trade.nearest`) and the last test of `tests/world.spec.luau` (`World.clerk`).

**Read first for patterns:** `src/server/TrialService.luau` (rate limiter bucket, remotes via `LedgerService.makeRemote`, a `Heartbeat` tick with an accumulator, `DataService.beforeRelease`, play-test seams), `src/server/SourceService.luau` (`addCoin`, prompt handling), `src/server/Fighters.luau` (`Fighters.body(userId)` gives the living Humanoid and root, `Fighters.get(id).player`).

**Step 1 — make the three failing tests pass (pure code):**
- `Trade.unconfirm(session, now): Session` — same offers, `confirmed = {}`, `changedAt = now`.
- `Trade.nearest(asker: { userId: number, position: Vec3 }, others: { same }): number?` — the nearest other within `Trade.INVITE_RANGE` (3D distance, inclusive, a NaN position is never near, ties to the lower id).
- `World.clerk: Vec3 = { x = 0, y = 0, z = -24 }` (between the two north buildings of Tallyport), exported from `World.luau`.
- Run `lune run tests/run` — Expected: the three tests pass.

**Step 2 — `CombatService.lastFightAt(player: Player): number?`** — the `os.clock()` time the player last dealt or took player damage. Set for both attacker and victim where `damagePlayer` records the hit in `hitLog` (player versus player only; creature and island damage do not count). Cleared in the existing `PlayerRemoving` handler.

**Step 3 — `EdictService`.** Requires (no cycles): `CombatService`, `DataService`, `Fighters`, `LedgerService`, `ProtectionService`, `TrialService`, and shared `Cards`, `EdictRules`, `Geography`, `Hazards`, `Ledger`, `Net`, `Protection`, `RateLimiter`, `Sites`, `World`.
```luau
EdictService.start(): ()
EdictService.isVeiled(player: Player): boolean
EdictService.setRng(rng: () -> number): ()        -- play-test seam: the defeat-loss rolls; default math.random
EdictService.meet(a: Player, b: Player): ()       -- play-test seam: marks the two as having met
```
- State (session only, never saved): `veilUntil: { [Player]: number }` on `os.clock()`; `met: { [Player]: { [Player]: boolean } }`.
- Remotes: `EdictUse` (client → server), `EdictResult` and `EdictSync` (server → client).
- **`EdictUse(player, raw)`**, in order, with nothing changed on a refusal: `player.Parent == Players` and a rate-limit token (capacity 10, refill 5 per second), else return silently; `LedgerService.isLocked(player)` → notify `LEDGER_LOCKED`; `EdictRules.parseUse(LedgerService.get(player), raw)` → on nil notify its code; no living body (`Fighters.body`) → notify `EDICT_NOT_NOW`. Then by `use.key`:
  - `summons`: `people` = every present player with loaded data `{ userId, name = DisplayName, ledger, veiled = isVeiled }`; fire `EdictResult` with `EdictRules.summonsResult(relicId, EdictRules.holders(people, relicId, player.UserId))`; consume.
  - `audit`: bodies of every other living player; `EdictRules.auditTarget`; none → notify `EDICT_NO_TARGET`, not consumed. Target Veiled → fire `EdictResult` with `EdictRules.veiledResult(target.DisplayName)`, consume. Else fire `EdictRules.auditResult(target.DisplayName, data.ledger, data.vault)`, notify the target `AUDITED { player = player.DisplayName }`, consume. A target without loaded data counts as no target.
  - `veil`: `veilUntil[player] = os.clock() + EdictRules.VEIL_SECONDS`; notify `EDICT_VEIL_ON`; sync; consume.
  - `passage`: the target is `Fighters.get(use.targetId)` of kind "player", another player, with `met[player][target]` → else notify `EDICT_NOT_MET`; the target has a living body → else `EDICT_NO_TARGET`; travel allowed (below) → else its code. Destination `EdictRules.arrival(targetPosition, isClear)` where `isClear(x, z)` is `Geography.isLand(x, z)` and no `Sites.hazards` entry has `Hazards.affects(hazard, x, z)`. Move the root: `root.CFrame = CFrame.new(x, y, z) * root.CFrame.Rotation`, `root.AssemblyLinearVelocity = Vector3.zero`. Notify `PASSAGE_DONE { player = target.DisplayName }`; consume.
  - `homecoming`: travel allowed → else its code. Move the root to `(World.spawn.x, World.spawn.y + 4, World.spawn.z)` the same way. Notify `HOMECOMING_DONE`; consume.
  - **Travel allowed:** `ProtectionService.status(player, now)` nil → `EDICT_NOT_NOW`; else `EdictRules.canTravel({ marked = Protection.isMarked(status, now), lastFightAt = CombatService.lastFightAt(player), inTrial = TrialService.run(player) ~= nil }, now)`.
  - **Consume** = `LedgerService.set(player, Ledger.discard(ledger, use.freeIndex))`, in the same step as the effect, with no yielding call between reading the Ledger and writing it.
- **Meeting:** once a second (Heartbeat with an accumulator), every pair of living players within `EdictRules.MEET_RANGE` (`EdictRules.near` on root positions) is marked met both ways; a new meeting syncs both.
- **`EdictSync(veilSeconds, met)`** to one client: `EdictRules.veilSeconds(veilUntil[player], os.clock())` and `{ { userId, name = DisplayName } }` for the met players still present, sorted by name. Sent on data load, on a new meeting, when a met player leaves, and after Veil.
- **Defeat:** each player's character `Humanoid.Died` (connect on `CharacterAdded`, and for a character already present) → `EdictRules.defeatLoss(ledger, rng)`; when it lost anything, `LedgerService.set` and notify `EDICTS_LOST { names = Cards.names(lost) }`. Leaving the game is not a defeat here.
- `PlayerRemoving`: forget the player's Veil, bucket and meetings (both directions) and re-sync the players who had met them.

**Step 4 — `ShopService`.**
```luau
ShopService.start(): ()
ShopService.setRng(rng: () -> number): ()   -- play-test seam: pack rolls; default math.random
```
- Remotes `ShopOpen` (server → client) and `ShopAction` (client → server).
- Every part tagged `ShopClerk` with a `ProximityPrompt`: `Triggered(player)` → with loaded data, fire `ShopOpen` with `Shop.view(data.ledger, data.coin)` (rules module `Shared.Rules.Shop`); without, notify `DATA_NOT_LOADED`.
- **`ShopAction(player, raw)`**, in order: present and a rate-limit token (10, 5 per second); data loaded else `DATA_NOT_LOADED`; Ledger locked → `LEDGER_LOCKED`; a living root within `ShopCatalog.REACH` (catalog module `Shared.Catalog.Shop`) of `World.clerk` raised 3 studs, written so a NaN distance is refused → else `TOO_FAR`; `Shop.apply(data.ledger, data.coin, raw, rng)`. Failure → notify its code and arguments. Success, with no yield in between: `LedgerService.set(player, newLedger)` (false → notify `DATA_NOT_LOADED` and stop), `SourceService.addCoin(player, newCoin - data.coin)` (read `data.coin` before `set`), notify the code and arguments, and fire `ShopOpen` again with the fresh view.

**Step 5 — `TradeService`.**
```luau
TradeService.start(): ()
TradeService.session(player: Player): Trade.Session?   -- play-test seam
```
- Remotes: `TradeRequest`, `TradeReply`, `TradeAction` (client → server); `TradeInvite`, `TradeSync` (server → client). One rate limiter for all three client remotes (10, 5 per second).
- State: `invites: { [Player]: { from: Player, expiresAt: number } }` keyed by the invited player; `asked: { [Player]: Player }` (asker → invited); `trades: { [Player]: Ref }` where both traders map to the same `Ref = { session: Trade.Session, a: Player, b: Player }`.
- A player is **free to trade** when: present, data loaded, a living body, Ledger not locked, not in `trades`, not in `invites`, not in `asked`.
- **`TradeRequest(player)`**: the asker must be free to trade (else notify `EDICT_NOT_NOW`). Target = `Trade.nearest` over the other living players; none → notify `EDICT_NO_TARGET`. Target not free to trade → notify `TRADE_BUSY { player = target.DisplayName }`. Else record the invite (`expiresAt = os.clock() + Trade.INVITE_SECONDS`), fire `TradeInvite` to the target with `{ from = player.DisplayName, seconds = Trade.INVITE_SECONDS }`, notify the asker `TRADE_SENT { player = target.DisplayName }`, and `task.delay(Trade.INVITE_SECONDS, ...)`: if that same invite is still pending, clear it, fire `TradeInvite(target, nil)` and notify the asker `TRADE_EXPIRED`.
- **`TradeReply(player, accept)`**: no invite → notify `TRADE_NOT_OPEN`. Clear the invite (both tables). `accept ~= true` → notify the asker `TRADE_DECLINED { player = player.DisplayName }`. Else both must still be present, loaded, alive, unlocked and within `Trade.KEEP_RANGE` → otherwise notify both `TRADE_CANCELLED`. Then create the `Ref` with `Trade.new(a.UserId, b.UserId, os.clock())` (a = the asker) and sync both.
- **`TradeAction(player, raw)`**: not in a trade → notify `TRADE_NOT_OPEN`. `raw` must be a table with a `kind`, else `BAD_REQUEST`.
  - `"offer"`: `Trade.setOffer(session, userId, raw, ledger, coin, os.clock())`; nil → notify its code; else store and sync both.
  - `"confirm"`: `Trade.confirm`; nil → notify its code. Else store; when `Trade.ready`, settle (below); otherwise sync both.
  - `"cancel"`: cancel the trade.
  - anything else: `BAD_REQUEST`.
- **Settle**, with no yielding call from reading both players' data to the last write: either Ledger locked or data missing → cancel. `Trade.settle(session, a.ledger, a.coin, b.ledger, b.coin)`. Failure → notify both its code, store `Trade.unconfirm(session, os.clock())`, sync both. Success → remove the trade from `trades` first (so the Ledger-changed hook below does nothing), then `LedgerService.set` for both, `SourceService.addCoin` for both with the differences, notify both `TRADE_DONE`, fire `TradeSync(nil)` to both.
- **Cancel** = remove from `trades`, notify both `TRADE_CANCELLED` (those still present), fire `TradeSync(nil)`.
- **Watch** (Heartbeat, every 0.5 s): a trade is cancelled when either trader is gone, has no living body, has a locked Ledger, or the two roots are more than `Trade.KEEP_RANGE` apart (written so a NaN distance cancels).
- **`LedgerService.onChanged(player, ledger)`**: if the player is in a trade, store `Trade.prune(session, userId, ledger, data.coin, os.clock())` and sync both.
- `PlayerRemoving`: cancel the leaver's trade; clear invites to and from them (withdraw a shown invite with `TradeInvite(target, nil)`); drop the bucket.
- **Sync** = to each trader `TradeSync` with `Trade.view(session, userId, other.DisplayName, ledger, coin, os.clock())`.

**Step 6 — the clerk (`WorldBuilder.buildTallyport` or a helper beside it):** a `Model` named `EdictHallClerk` in the Tallyport folder at `World.clerk`: a body block 2 × 4 × 1.5 (dark purple), a ball head, a low wooden counter 6 × 3 × 2 in front of it (towards the plaza centre), a `BillboardGui` label "Edict Hall" with a second line "Packs, Copper Relics, selling" (MaxDistance 80, same style as `makeLabel`), and on the body a `ProximityPrompt` (ActionText "Shop", ObjectText "Edict Hall clerk", HoldDuration 0, MaxActivationDistance 10, RequiresLineOfSight false). The body is tagged `ShopClerk`. Everything anchored.

**Step 7 — start order (`Main.server.luau`):** after `TrialService.start`: `EdictService.start`, `ShopService.start`, `TradeService.start`; `DataService.start` stays last. Add `Server.EdictService`, `Server.ShopService`, `Server.TradeService`, `Shared.Rules.EdictRules`, `Shared.Rules.Shop`, `Shared.Rules.Trade`, `Shared.Catalog.Cards`, `Shared.Catalog.Edicts`, `Shared.Catalog.Shop` to `tests/build.spec.luau`.

**Step 8:** `bash scripts/check.sh` — Expected: exit 0, every test passing. **Commit** — `feat: Edicts, the Edict Hall and trading on the server`

No behaviour tests for the services: they are engine glue over tested rules, and `scripts/check.sh` does not type-check Luau or run Roblox APIs, so read your code twice. Task 7's Studio play test exercises it.

---

### Task 6: Client — Edict use, shop window, trade window, Veil line

**Files:**
- Create: `src/client/EdictUI.luau`, `src/client/ShopUI.luau`, `src/client/TradeUI.luau`
- Modify: `src/client/LedgerUI.luau`, `src/client/StatusHUD.luau`, `src/client/Main.client.luau`, `src/shared/Rules/StatusView.luau`, `tests/status_view.spec.luau`, `tests/build.spec.luau`

**Read first for patterns:** `src/client/TrialUI.luau` (a centred window built in code with `UICorner`, `UITextSizeConstraint`, scale-based sizes, `mount` / `show` / `isOpen`), `src/client/LedgerUI.luau` (`makeFreeRow`, `tierColor`), `src/client/Main.client.luau` (how remotes are fetched and wired). Every text element uses `TextScaled` with a `UITextSizeConstraint`; windows use scale sizes with a `UISizeConstraint` minimum so they fit a phone.

**Interfaces:**
```luau
-- StatusView (pure, tested): a new optional last parameter and a new line kind "veil"
StatusView.build(status, inSafeZone, place, veilSeconds: number?): { Line }
-- with veilSeconds running (> 0 and finite): { text = "Veiled M:SS", kind = "veil" } after the Marked line and before the hazard lines

EdictUI.mount(playerGui: PlayerGui, onUse: (request: { [string]: any }) -> ()): ()
EdictUI.use(card: LedgerView.FreeView): ()        -- called by the Ledger's "Use" button
EdictUI.setMet(met: { { userId: number, name: string } }): ()
EdictUI.showResult(result: { title: string, lines: { string } }): ()
EdictUI.isOpen(): boolean                          -- any of its windows is showing

ShopUI.mount(playerGui: PlayerGui, onAction: (request: { [string]: any }) -> ()): ()
ShopUI.show(view: Shop.View): ()                   -- opens, or refreshes when already open
ShopUI.isOpen(): boolean

TradeUI.mount(playerGui: PlayerGui, handlers: { request: () -> (), reply: (accept: boolean) -> (), action: (request: { [string]: any }) -> () }): ()
TradeUI.showInvite(invite: { from: string, seconds: number }?): ()   -- nil hides it
TradeUI.render(view: Trade.View?): ()              -- nil closes the window
TradeUI.isOpen(): boolean
```

- [ ] **Step 1 (TDD): `StatusView`.** Add to `tests/status_view.spec.luau`: with `veilSeconds = 125.2` the lines contain `{ text = "Veiled 2:06", kind = "veil" }` placed after a Marked line and before hazard lines; `0`, a negative number, NaN, `math.huge` and `nil` add no line; every existing test still passes unchanged (the parameter is optional). Run — Expected: FAIL. Implement. Run — Expected: PASS.
- [ ] **Step 2: `LedgerUI`.** `makeFreeRow`: a row whose `card.tier` is nil (an Edict) uses a parchment colour `Color3.fromRGB(214, 196, 150)` instead of `tierColor`. A row with `card.canUse` shows a "Use" button where "Claim" would be, calling a handler set by a new `LedgerUI.setUseHandler(handler: (card: LedgerView.FreeView) -> ())`. "Discard" stays on every row.
- [ ] **Step 3: `StatusHUD`.** Add the colour for kind `veil` (`Color3.fromRGB(170, 140, 220)`). The line column grows to six lines: `Lines` height 192 and the "Drop shield" button 32 pixels lower than now.
- [ ] **Step 4: `EdictUI`** — one `ScreenGui` `EdictGui` (`ResetOnSpawn = false`, `DisplayOrder` 16) with three windows, all hidden at first:
  - `RelicPicker`: title "Summons: which Relic?", a grid of one button per `Relics.list` entry (six columns; text "001\nName", tier colour), and "Cancel". Picking one calls `onUse({ freeIndex, cardId, relicId })` and closes.
  - `PlayerPicker`: title "Passage: to whom?", one button per met player (name), the line "You have not met anyone this session." when the list is empty, and "Cancel". Picking one calls `onUse({ freeIndex, cardId, targetId = userId })` and closes.
  - `Result`: a title label, a scrolling list of the result's lines, and "Close".
  - `EdictUI.use(card)`: by the Edict's `needs` in `Catalog/Edicts` (`Edicts.byId[card.cardId]`): "relic" opens the Relic picker, "player" the player picker, anything else calls `onUse({ freeIndex = card.index, cardId = card.cardId })` at once. The pickers remember the card they were opened for.
- [ ] **Step 5: `ShopUI`** — `ScreenGui` `ShopGui` (`DisplayOrder` 16), one window `Shop`: title "Edict Hall", `Coin` label (`view.coinText`), a pack row (`view.packText`, `view.oddsText` in small dim text, a "Buy" button named `BuyPack`, dimmed and inert unless `view.canBuyPack`) → `onAction({ kind = "pack" })`; a `Stock` list, one row per `view.stock` (name, `priceText`, "Buy" → `{ kind = "relic", relicId }`, dimmed unless `canBuy`); a `Sell` scrolling list, one row per `view.sell` (name, `priceText`, "Sell" → `{ kind = "sell", freeIndex = index, cardId }`), or the line "Nothing to sell." when empty; and "Close". Rows are named `Stock_<relicId>` and `Sell<index>` so the play-test agent can find them.
- [ ] **Step 6: `TradeUI`** — `ScreenGui` `TradeGui` (`DisplayOrder` 16):
  - A HUD button `TradeButton` "Trade" at the bottom left above the existing Ledger and Paths buttons (check their positions in `LedgerUI` and `PathUI` and do not overlap) → `handlers.request()`.
  - `Invite`: a small banner top centre below the message line: "<from> wants to trade", "Accept" → `reply(true)`, "Decline" → `reply(false)`; it hides itself after `seconds`, on either button, and on `showInvite(nil)`.
  - `Trade` window: title "Trade with <otherName>"; left column "Your free slots": one button per `view.free` row (named `Free<index>`, the name, a marked look when `offered`); clicking toggles that card in your offer and sends the whole new offer `action({ kind = "offer", cards = { ids }, coin = n })`; middle "You give" (`Mine`): `view.mine.cards` names and a Coin line with `-10`, `-1`, `+1`, `+10` buttons (clamped to 0..`view.coinHeld`), each sending the whole new offer; right "You get" (`Theirs`): `view.theirs` names and Coin; a `Status` line (`view.status`); "Confirm" (inert and dimmed while `view.mineConfirmed`, and for `view.confirmIn` seconds after the view arrived — count that down locally) → `action({ kind = "confirm" })`; "Cancel" → `action({ kind = "cancel" })`.
  - An offer may hold at most 6 cards (`Trade.MAX_CARDS`): a seventh click does nothing.
- [ ] **Step 7: wire `Main.client.luau`.** Fetch the ten new remotes. `LedgerUI.setUseHandler(EdictUI.use)`. `EdictUse` requests go to the server; `EdictResult` → `EdictUI.showResult`; `EdictSync(veilSeconds, met)` → keep `veilSeconds` with its local arrival time and `EdictUI.setMet(met)`; `refreshHud` passes `math.max(0, veilSeconds - elapsed)` as the new last argument of `StatusView.build`. `ShopOpen` → `ShopUI.show`; `TradeInvite` → `TradeUI.showInvite`; `TradeSync` → `TradeUI.render`. Strike and ability input are also blocked while `EdictUI.isOpen()`, `ShopUI.isOpen()` or `TradeUI.isOpen()`.
- [ ] **Step 8:** add `Client.EdictUI`, `Client.ShopUI`, `Client.TradeUI` to `tests/build.spec.luau`. `bash scripts/check.sh` — Expected: exit 0. **Commit** — `feat: Edict, shop and trade windows`

`scripts/check.sh` does not type-check Luau or run UI code, so read your code twice; Task 7's Studio play test exercises it.

---

### Task 7: Play test and hand-off

**Files:**
- Modify: `playtest/server/Driver.server.luau`, `playtest/client/Agent.client.luau`, `README.md`
- Create: `docs/playtest/M5-checklist.md`

The controller (not the implementer) runs Studio and rebuilds `dist/`. The implementer writes the checks and documents.

**Read first:** in `playtest/server/Driver.server.luau` the helpers (`check`, `mark`, `expectNote`, `noteSince`, `codesSince`, `send`, `place`, `inspect`, `inspectUntil`, `waitAlive`, `heal`, `faceOff`, `strike`, `positionOf`, `flatDistance`, `coinOf`, `hasFree`, `beside`) and the whole `runM4` function with the way `run()` calls it in its own `xpcall`. In `playtest/client/Agent.client.luau` the `cmd.OnClientEvent` ops and `inspectUi`.

Lessons from the M4 run that the new checks must follow: never stand two test players on one spot (a Strike takes the nearest fighter in its arc); after `place`, wait until the player's server position has arrived before acting; compare timers against a value read before the action, not against zero (players are still Marked from earlier sections); a check that expects "nothing happened" waits a moment and then asserts state, not a message.

- [ ] **Step 1: agent.** New ops: `edict` (fires `EdictUse` with the given table, hostile ones included), `shopOpen` (triggers the clerk's prompt: `workspace.Island.Tallyport.EdictHallClerk.Body`), `shop` (fires `ShopAction`), `tradeRequest` (fires `TradeRequest`), `tradeReply` (fires `TradeReply` with the given value), `trade` (fires `TradeAction`). Report streams: `EdictResult` → `report:FireServer("edictResult", result)`, `EdictSync` → `("edictSync", veilSeconds, met)`, `ShopOpen` → `("shop", view)`, `TradeInvite` → `("tradeInvite", invite)`, `TradeSync` → `("tradeSync", view)`. `inspectUi` adds: `shopVisible`, `shopCoin`; `tradeVisible`, `tradeStatus`; `inviteVisible`; `resultVisible`, `resultTitle`; `veilLine` (the status line that starts with "Veiled", or ""). The driver stores the latest of each stream per player (`false` for a nil `tradeSync` or `tradeInvite`, so "closed" can be told from "never seen").
- [ ] **Step 2: driver.** A `runM5(A, B)` section called from `run()` right after the M4 section, in its own `xpcall` with a `check("M5 section ran to its end", ...)`. It starts by giving both players fresh state: empty Ledgers, `data.coin` set through `SourceService.addCoin` to a known amount, both alive, respawn shields ended, both standing apart in Tallyport. Use `EdictService.setRng`, `ShopService.setRng`, `EdictService.meet` and `TradeService.session`. One `check` per line:
  - Clerk: one part tagged `ShopClerk`; the shop opens from its prompt; the view's `coinText` matches.
  - Pack: with rolls `0, 0.5, 0.9` and 100 Coin → `SHOP_PACK` naming "Summons, Veil, Homecoming", Coin 40, three Edicts in the free slots, the window's Coin line follows. With 40 Coin → `NOT_ENOUGH_COIN`, nothing changes.
  - Relic: buy `R003` at 40 Coin → `SHOP_BOUGHT`, Coin 0. `R007` → `NOT_FOR_SALE`.
  - Sell: sell that `R003` → `SHOP_SOLD`, +1 Coin, gone from the Ledger. The same request again (the row is gone) → `BAD_INDEX`, Coin unchanged.
  - Reach: from 30 studs away `{ kind = "pack" }` with enough Coin → `TOO_FAR`, nothing changes.
  - Hostile shop requests (`"pack"`, `5`, `{}`, `{ kind = "steal" }`, nil) → `BAD_REQUEST` each.
  - Veil: use it → `EDICT_VEIL_ON`, the card is gone, `EdictService.isVeiled(A)`, the HUD shows a line starting "Veiled".
  - Summons: B holds `R007`; A's Summons for `R007` → result title "Summons: Bottled Squall" listing B's display name; the card is gone. With B Veiled → the "Nobody else here holds it" line.
  - Audit: B (unveiled) 10 studs from A → a result titled "Audit: <B>" containing "007 Bottled Squall (Silver)"; B gets `AUDITED`. With B 40 studs away → `EDICT_NO_TARGET` and A still holds the card.
  - Homecoming: A outside town, not Marked, no recent fight → `HOMECOMING_DONE`, A within 40 studs of the centre. During a trial (accept Tidewalk first, with `TrialService.setClocks` as M4 does) → `EDICT_IN_TRIAL`, the card kept, A not moved.
  - Passage: before meeting → `EDICT_NOT_MET`; after `EdictService.meet(A, B)` with B at `OUTSIDE` → `PASSAGE_DONE`, A within 10 studs of B.
  - Hostile Edict requests (a Relic row, a wrong `cardId` for the row, index 0, a table for `freeIndex`, nil) → `BAD_REQUEST` or `BAD_INDEX`, the Ledger unchanged.
  - Defeat loss: A holds 6 Edicts and 2 Relics; with the loss roll fixed at 0, `humanoid.Health = 0` → `EDICTS_LOST`, 4 Edicts left, both Relics kept.
  - Trade: A and B 8 studs apart in Tallyport. A requests → B's invite names A, A gets `TRADE_SENT`. B accepts → both get a view. A offers `R001` and 10 Coin, B offers `E003` → each sees the other's offer. A confirms at once → `TRADE_TOO_SOON`. After 2.2 s both confirm → both `TRADE_DONE`, the cards and Coin have changed hands, total Coin unchanged, windows closed.
  - The switch: a new trade; A offers `R001`, B offers `R007`, wait, A confirms; B changes the offer to nothing → `TradeService.session(A).confirmed` is empty; B's confirm at once → `TRADE_TOO_SOON`.
  - Cancel and leash: B cancels → both `TRADE_CANCELLED`. A new trade; move B 40 studs away → both `TRADE_CANCELLED` within 2 s.
  - Hostile trade requests during a trade: offering a card not held, 7 cards, Coin -5, Coin 1.5, more Coin than held, `{ kind = "steal" }` → a refusal code each and the session's offers unchanged.
  - Decline: A requests, B replies `false` → A gets `TRADE_DECLINED`.
  At the end leave both players alive in Tallyport with no trade open.
- [ ] **Step 3: `docs/playtest/M5-checklist.md`** in the plain style of `docs/playtest/M4-checklist.md` (read it first; the same "What to do / What should happen" steps, quoting on-screen text from `Messages.luau`): the clerk and the shop window (odds line visible), buying and selling, each of the five Edicts by hand, losing Edicts on defeat, a full trade with two players including the 2-second wait and a cancelled trade, and the three windows on a phone. Leave the "Automated run" line as: `Automated run: not done yet.` (the controller fills it in).
- [ ] **Step 4: README.** "What is in the game now" gains a Milestone 5 line (Edicts, the Edict Hall, trading, losing a third of your Edicts on defeat); the play-test list gains `docs/playtest/M5-checklist.md`; the automated play-test sentence names M5.
- [ ] **Step 5:** `bash scripts/check.sh` — Expected: exit 0. **Commit** — `test: M5 play-test checks; docs: M5 checklist`
