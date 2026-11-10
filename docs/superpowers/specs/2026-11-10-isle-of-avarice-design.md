# Isle of Avarice — Game Design

**Date:** 2026-11-10
**Status:** Draft, waiting for review
**Platform:** Roblox (3D, multiplayer)

## 1. What we are making

A multiplayer 3D Roblox game set on a cursed island. Every player carries a
book called the **Ledger**. The Ledger has numbered slots, and each slot can
hold only one specific card. Players explore, complete trials, trade, and
use spell cards on each other to fill every slot. Filling the Ledger is how
you win.

The idea is inspired by the card-book game in the Greed Island arc of
*Hunter x Hunter*. We take the **mechanics** that make that game fun. We do
not copy its content.

### What we borrow (mechanics)

| Mechanic | Why it is fun |
|---|---|
| Everything you earn becomes a card | One simple system for items, rewards and spells |
| A book with numbered slots to complete | A clear, visible goal for every player |
| A limited number of free slots | Forces choices about what to carry |
| Each rare card has a cap on copies | Players must trade, bargain or steal — not just grind |
| Spell cards used on other players | Stealing, defending, tracking and travelling create stories |

### What we do not copy (content)

No names, characters, cards, spells, places, art or story from *Hunter x
Hunter*. No "Nen", no "Greed Island", no card or spell lifted from the
series. Every card, spell, place and character in this game is original.

This is a hard rule for two reasons. Copying a specific existing work is
not something this project will do. And Roblox removes games after
copyright complaints; several popular anime-based games have been taken
down that way, which would erase the work.

## 2. Setting (original)

Long ago a merchant-king called the **Hoarder** bought everything on the
island: its treasures, its beasts, even its weather. When he died, his
greed sealed it all into cards and scattered them. His Ledger is still
open, and the island will crown whoever fills it.

- Players are **Claimants**.
- Numbered cards are **Relics**.
- Spell cards are **Edicts** (the Hoarder's old laws, still binding).
- Money is **Coin**.
- The safe starting town is **Tallyport**.

## 3. Core rules

### 3.1 The Ledger

- **Relic slots:** numbered `001`–`050` at launch. Slot `017` accepts only
  Relic `017`. The first playable version ships 12 Relics.
- **Free slots:** 20 slots that hold anything: spare Relics, Edicts,
  trade goods.
- A Relic in its own numbered slot is **claimed**. A Relic in a free slot
  is a **spare**.
- If the free slots are full, the player cannot pick up another card.
- The Ledger is saved between play sessions.

### 3.2 Card tiers and scarcity

Each Relic has a tier. Higher tiers are scarcer.

| Tier | Copies allowed per server | How you usually get it |
|---|---|---|
| Copper | No cap | Exploring, shop |
| Silver | 8 | Exploring hidden places, simple trials |
| Gold | 4 | Hard trials, creatures |
| Platinum | 2 | Multi-step quests |
| Crown | 1 | One unique challenge each |

**Scarcity rule:** the island will not release a new copy of a Relic while
the players currently on that server already hold the capped number of
copies. The source shows as "sealed". Players then have three options:
trade for it, take it with an Edict, or wait for a holder to leave.

The cap blocks only **new** copies. A player who joins a server already
holding a card always keeps it. Counting per server (not across all
servers) keeps the system simple and impossible to lock up forever.

### 3.3 Edicts (spell cards)

Edicts are single-use cards kept in free slots. They are bought in sealed
packs of three random Edicts from the Edict Hall in Tallyport, or found as
rewards. First set:

| Edict | Effect |
|---|---|
| **Seizure** | Take one random spare card from a nearby player's free slots |
| **Writ of Claim** | Take one named spare Relic from a nearby player (rare) |
| **Ward** | Blocks the next Edict used against you, then is used up |
| **Summons** | Shows which players on the server hold a named Relic |
| **Audit** | Look inside a nearby player's Ledger |
| **Passage** | Teleport to a player you have met this session |
| **Homecoming** | Teleport to Tallyport |

Rules that keep this fair:

- Edicts can only take **spares** from free slots. Claimed Relics in
  numbered slots are safe. (Tuning point: see open questions.)
- Attack Edicts need the target within range and in view.
- Tallyport is a safe zone. No attack Edicts work there.
- A player who was just robbed is immune for 60 seconds.
- New players are immune for their first 10 minutes of play.

### 3.4 Earning cards

- **Exploration:** hidden caches around the island that respawn on a timer.
- **Trials:** challenges given by island characters (obstacle courses,
  puzzles, timed deliveries).
- **Creatures:** island beasts that drop cards when defeated. *(Later
  milestone.)*
- **Shops:** Copper Relics and Edict packs for Coin.
- **Trading:** a two-sided trade window where both players must confirm.

Coin is a plain number on the player, not a card. It is earned from
trials, creatures and selling spare cards to shops.

### 3.5 Winning

Claiming every Relic triggers a server-wide ceremony. The player earns the
**Crowned** title, a Roblox badge and a cosmetic reward, and goes on the
all-time leaderboard. They may then **Renounce**: return all cards to the
island for a permanent prestige mark and start again. This keeps rare
cards moving.

## 4. Technical design

### 4.1 Tools

- **Rojo** keeps all game code in this repo and syncs it into Roblox
  Studio.
- **Luau** in strict type mode.
- **ProfileStore** for saved data. It locks a player's data to one server
  at a time, which prevents card duplication.
- **Lune** runs unit tests outside Roblox. **Selene** and **StyLua** lint
  and format.
- **GitHub Actions** runs lint, tests and a Rojo build on every push.

Rojo, StyLua, Selene and Lune can all be installed in the cloud workspace,
so game rules can be tested and the place file built without Studio.

### 4.2 Code layout

```
default.project.json        Rojo project file
src/
  shared/                   ReplicatedStorage — used by server and client
    Catalog/                Card data: Relics, Edicts, tiers
    Rules/                  Pure game rules, no Roblox APIs
      Ledger.luau           add / remove / move / claim / isComplete
      Scarcity.luau         cap checks
      EdictRules.luau       what each Edict may do, and when
      TradeRules.luau       validate and apply a swap
    Net.luau                the single list of remote events
    Types.luau
  server/                   ServerScriptService
    DataService.luau        load / save with ProfileStore
    LedgerService.luau      owns every player's Ledger; replicates changes
    SourceService.luau      caches, trials, sealed/unsealed state
    EdictService.luau
    TradeService.luau
    ShopService.luau
    WorldBuilder.luau       builds the starter island from code
  client/                   StarterPlayerScripts
    LedgerUI/               the book screen
    HUD/
    EdictTargeting.luau
    TradeUI/
tests/                      Lune unit tests for src/shared/Rules
```

### 4.3 Design rules

1. **The server decides everything.** Clients only send requests ("pick
   up this cache", "use this Edict on that player"). The server checks
   every request and rate-limits it. Roblox clients can be hacked, so the
   client is never trusted.
2. **Game rules are pure functions.** Everything in `Rules/` takes plain
   data and returns plain data, with no Roblox APIs. This allows fast unit
   tests, and it is where most bugs would otherwise hide.
3. **Card moves are atomic.** A steal or trade either fully happens or
   does not happen. No path can create or destroy a card by accident.
4. **Content is data.** Adding a Relic means adding one catalog entry, not
   writing new code.

### 4.4 The island

The first island is built by code when the server starts: simple terrain,
Tallyport, and marked spots for caches and trials. This keeps the whole
game in the repo and makes every build playable. Hand-made art in Studio
can replace it later without changing game code, because the code finds
world objects by tag, not by position.

### 4.5 Testing

| Level | What | Who |
|---|---|---|
| Unit tests | All rules in `Rules/` | Automated |
| Build check | Project compiles into a place file | Automated |
| Play test | A short checklist per milestone, in Studio | You, on your PC |

Limit: Roblox Studio cannot run in the cloud workspace. Anything that
depends on the engine (movement, UI feel, networking in a live server) is
confirmed only by your play tests.

## 5. Roadmap

Each milestone ends with something you can play. Each gets its own
detailed build plan.

| # | Milestone | You can… |
|---|---|---|
| M0 | Project skeleton | Open the built place in Studio and walk on an empty island |
| M1 | **The Ledger** | Find 12 Relics, fill the book, leave and return with it saved |
| M2 | Scarcity | See sources seal when the cap is hit; see who holds what |
| M3 | Edicts | Buy packs, steal, ward, track and teleport |
| M4 | Trading | Swap cards safely with another player |
| M5 | Trials and creatures | Earn Gold-tier and higher Relics through challenges |
| M6 | Endgame and launch | Complete the Ledger, be Crowned, see the leaderboard; 50 Relics |

The first build plan covers **M0 and M1**.

### Not in scope for now

- Player-versus-player combat with weapons or abilities.
- Global (cross-server) scarcity.
- Paid items. If added later they will be cosmetic only, with no paid way
  to obtain Relics.

## 6. Open questions

1. **Can claimed Relics ever be stolen?** The draft says no: only spares
   in free slots are at risk. Safer and kinder to new players, but lower
   stakes.
2. **Combat:** the draft has no player-versus-player fighting. Creatures
   arrive in M5. Is that right?
3. **Relic count:** 50 at launch, 12 in the first playable version.
4. **Names:** Ledger, Relics, Edicts, Claimants, Tallyport, the Hoarder.
   All can be changed.
