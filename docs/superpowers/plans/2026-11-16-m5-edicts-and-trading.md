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
Files: `EdictService.luau`, `ShopService.luau`, `TradeService.luau`, `CombatService.luau` (`lastFightAt`), `WorldBuilder.luau` (the clerk), `Main.server.luau`, `tests/build.spec.luau`.
- Commit: `feat: Edicts, the Edict Hall and trading on the server`

### Task 6: Client — Edict use, shop window, trade window, Veil line
Files: `EdictUI.luau`, `ShopUI.luau`, `TradeUI.luau`, `LedgerUI.luau` (Use button), `StatusHUD.luau`, `Rules/StatusView.luau` (+ test), `Main.client.luau`, `tests/build.spec.luau`.
- Commit: `feat: Edict, shop and trade windows`

### Task 7: Play test and hand-off
Files: `playtest/server/Driver.server.luau`, `playtest/client/Agent.client.luau`, `docs/playtest/M5-checklist.md`, `README.md`, `dist/IsleOfAvarice.rbxlx`.
- Driver M5 section in its own protected call, before M2.15. Run in Studio (2 players) until `failed=0`. Then rebuild `dist/`.
- Commit: `test: M5 play-test checks; docs: M5 checklist and release build`
