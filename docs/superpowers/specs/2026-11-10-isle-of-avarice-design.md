# Isle of Avarice — Game Design

**Date:** 2026-11-10 (revision 5, 2026-11-12: M3 decisions in section 4, parties added to the roadmap)
**Status:** Draft, waiting for review
**Platform:** Roblox (3D, multiplayer, open PvP)
**Research:** see `docs/research/` (four reports)

## 1. What we are making

A multiplayer 3D Roblox game set on a cursed island. Every player carries a
book called the **Ledger**. The Ledger has numbered slots, and each slot can
hold only one specific card. Players explore, complete trials, fight
creatures and each other, and trade to fill every slot. Filling the Ledger
is how you win.

Players grow stronger through the **Six Paths**: six fighting styles on a
hexagon. You choose one. The further another Path sits from yours, the
slower you learn it.

The idea is inspired by the card-book game in the Greed Island arc of
*Hunter x Hunter*, and by the shape of that series' six-category power
system. We take the **mechanics**. We do not copy the content.

### What we borrow (mechanics)

| Mechanic | Why it is fun |
|---|---|
| Everything you earn becomes a card | One simple system for items and rewards |
| A book with numbered slots to complete | A clear, visible goal for every player |
| A limited number of free slots | Forces choices about what to carry |
| Each rare card has a cap on copies | Players must trade or fight for it, not just grind |
| Defeat puts your collection at risk | Every fight matters |
| Six power categories on a hexagon, learned at 100 / 80 / 60 / 40% | Real builds, real weaknesses |

### What we do not copy (content)

No names, characters, cards, spells, places, art or story from *Hunter x
Hunter*. No "Nen", no "Greed Island", none of its six category names, and
no card or ability lifted from the series. Every card, ability, place and
character here is original.

This is a hard rule. Copying a specific existing work is not something
this project will do, and Roblox removes games after copyright complaints.

## 2. Setting (original)

Long ago a merchant-king called the **Hoarder** bought everything on the
island: its treasures, its beasts, even its weather. When he died, his
greed sealed it all into cards and scattered them. His Ledger is still
open, and the island will crown whoever fills it.

- Players are **Claimants**.
- Numbered cards are **Relics**.
- Utility cards are **Edicts** (the Hoarder's old laws, still binding).
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

| Tier | Copies allowed per server | How you usually get it |
|---|---|---|
| Copper | No cap | Exploring, shop |
| Silver | 8 | Hidden places, simple trials |
| Gold | 4 | Hard trials, creatures |
| Platinum | 2 | Multi-step quests |
| Crown | 1 | One unique challenge each |

**Scarcity rule:** the island will not release a new copy of a Relic while
the players on that server already hold the capped number of copies. The
source shows as "sealed". To get a sealed Relic you must trade for it or
defeat a holder.

The cap blocks only new copies. A player who joins a server already
holding a card keeps it. Research showed that a cap with no release valve
becomes a permanent monopoly. Here the release valves are trade, the
blind claim (3.4), holders leaving the server, and the rule that Crown
Relics cannot be Vaulted.

### 3.3 Relics cannot be stolen

No Edict or ability can take a Relic from another player. Relics change
hands only two ways: **trade**, or **defeating the holder**.

### 3.4 Defeat and the blind claim

**The Vault.** Each player marks up to 3 of their Relics as Vaulted.
A Vaulted Relic can never be taken, whether claimed or spare, however
many copies the player holds. A player can Vault only a Relic they hold,
and it leaves the Vault when they no longer hold any copy. The Vault can
be changed only in a safe zone. Crown-tier Relics cannot be Vaulted, so
the rarest cards always stay in play.

**When one player defeats another outside a safe zone,** the killer makes
a **blind claim**:

1. The killer sees the victim's Ledger face-down: all 50 numbered slots,
   with nothing to show which ones the victim holds.
2. The killer has **5 picks** and 30 seconds. Each pick names one slot.
   A slot can be picked only once in a claim.
3. If the victim holds that Relic (claimed or spare) and it is not
   Vaulted, the killer takes one copy: a spare if the victim has one,
   otherwise the claimed copy. Otherwise the pick is wasted. The killer
   is not told why a pick missed.
4. The killer can take only a limited number per tier in one claim:

   | Tier | Killer takes at most |
   |---|---|
   | Crown | 1 |
   | Platinum | 1 |
   | Gold | 2 |
   | Silver | 3 |
   | Copper | 3 |

   Once a tier's limit is reached, its slots can no longer be picked.
5. Taken Relics go into the killer's free slots. A pick with no free slot
   to receive it is wasted.
6. While the claim is open the victim's Ledger is locked: they cannot
   move, discard, Vault or collect cards. When it closes they are told
   which Relics were taken.

Slot numbers are public, so a pick is an informed guess: the killer
chooses which Relic to bet on, not whether the victim has it. Audit and
Summons (3.6) are how a hunter learns what a target holds.

**What the victim keeps and loses, on any defeat (player or creature):**

- Keeps every Relic that was not taken. Nothing else is removed from the
  Ledger's Relics.
- Keeps all Coin.
- Keeps Path levels and abilities.
- Loses one third (rounded down) of their non-Relic cards, such as
  Edicts, chosen at random. These are destroyed, not given to the killer.
  (Built in M5 with Edicts; before then there are no non-Relic cards.)
- Respawns in Tallyport.

All numbers above are starting values to be tuned in play tests.

### 3.5 Keeping PvP fair

Research on harsh-loss games shows the same problems each time: veterans
farming new players, repeat kills, and logging out to dodge a loss. These
rules address them:

- **Safe zone.** No damage in Tallyport.
- **New-player shield.** A player cannot be attacked, or attack, until
  they hold 3 Relics (claimed or spare) or choose to drop the shield.
  Once it ends it never returns.
- **Repeat-kill limit.** A killer gets no blind claim against the same
  victim more than once per hour.
- **Respawn shield.** 60 seconds of immunity after respawning. It ends
  early if the player attacks.
- **Combat logging.** Leaving the game within 30 seconds of taking or
  dealing player damage counts as a defeat by the last attacker, who
  makes a blind claim as usual.
- **Marked.** A player who starts a fight is Marked for 5 minutes: a red
  marker above them is visible to everyone, and the safe zone does not
  protect them. Fighting back does not Mark you.
- **Basic combat.** Every player has 100 health and one Strike: 20
  damage, 0.8 seconds between Strikes, 8 studs reach, aimed by facing the
  target. From M3 the Strike stays as everyone's basic attack, next to the
  4 equipped abilities (section 4).
- **Tone.** Cartoon knock-outs. No blood, no gore. This keeps the game
  inside Roblox's lower maturity labels.

### 3.6 Edicts (utility cards)

Single-use cards kept in free slots. Bought in sealed packs of three from
the Edict Hall, or found as rewards. They never take cards.

| Edict | Effect |
|---|---|
| **Summons** | Shows which players on the server hold a named Relic |
| **Audit** | Look inside a nearby player's Ledger |
| **Veil** | Hides you from Summons and Audit for 10 minutes |
| **Passage** | Teleport near a player you have met this session |
| **Homecoming** | Teleport to Tallyport (not while Marked or in combat) |

Packs are bought with Coin earned in play. If packs are ever sold for
Robux, Roblox requires the odds to be shown.

### 3.7 Earning cards and Coin

- **Exploration:** hidden caches that respawn on a timer.
- **Trials:** challenges from island characters (obstacle courses,
  puzzles, timed deliveries, duels).
- **Creatures:** island beasts that drop cards when defeated.
- **Shops:** Copper Relics and Edict packs for Coin.
- **Trading:** a two-sided window where both players must confirm.
- **Blind claim:** defeating a holder (3.4).

Coin is a plain number, not a card. It comes from trials, creatures and
selling spares.

### 3.8 Winning

Claiming every Relic triggers a server-wide ceremony. The player earns the
**Crowned** title, a badge and a cosmetic, and joins the all-time
leaderboard. They may then **Renounce**: return all cards to the island
for a permanent prestige mark and start again.

## 4. The Six Paths

### 4.1 The hexagon

Six fighting styles sit on a hexagon. Neighbours blend naturally;
opposites clash.

```
            Fang
     Bulwark    Gale
     Mend       Ember
            Mire
```

| Path | Style | Example abilities |
|---|---|---|
| **Fang** | Close-range burst damage | Lunge, rending combo, finishing blow |
| **Gale** | Speed and evasion | Dash, air step, afterimage dodge |
| **Ember** | Ranged and area damage | Fire bolt, scatter shot, burning ground |
| **Mire** | Control | Slow field, root, pull |
| **Mend** | Healing and support | Self-heal, ally shield, cleanse |
| **Bulwark** | Defence and counter | Guard stance, reflect, taunt |

Opposites: Fang–Mire, Gale–Mend, Ember–Bulwark.

### 4.2 Choosing and learning

- The player **chooses** one Path as their **Calling**. There is no
  random roll, so nothing to pay to re-roll. In M3 a picker opens on first
  join, showing the hexagon and each Path's style and abilities; a guided
  tutorial comes later. A player without a Calling has only the Strike and
  earns no Path experience.
- Every Path has its own level. All six can be trained by anyone.
- Experience earned in a Path is multiplied by its distance from your
  Calling:

  | Distance on the hexagon | Learning rate |
  |---|---|
  | Your Calling | 100% |
  | Next to it (2 Paths) | 80% |
  | Two steps away (2 Paths) | 60% |
  | Opposite (1 Path) | 40% |

- **Levels.** Each Path has levels 1 to 20. Going from level L to L+1
  takes 100 x L experience, so level 20 needs 19,000 in total. Every
  Path starts at level 1, except the first Calling, which starts at
  level 3.
- Experience gained = base amount x learning rate, rounded down.
- A Path's 3 abilities unlock at levels **3, 10 and 18** of that Path.
- A player equips **4 abilities** at a time, from any Paths they have
  unlocked, plus the Strike. Loadouts change only in a safe zone. A newly
  unlocked ability goes into an empty slot by itself.
- **Changing Calling:** the first change is free, later changes cost 500
  Coin. Every change starts a 7-day cooldown (real time, saved). Levels
  are kept; only the learning rates change.

Experience comes from creatures, trials and winning fights. It is never
lost on defeat. Until creatures and trials exist (M4):

- **Training posts** stand at 6 spots around the island, outside
  Tallyport. A hit on a post gives 10 base experience to the Path of the
  ability used; the Strike trains the Calling. A post pays each player at
  most once every 0.5 seconds and cannot be defeated.
- **Defeating a player** gives 150 base experience to the Calling, but
  only when that defeat opens a blind claim, so the one-hour repeat-kill
  limit also stops experience farming.

### 4.3 Balance rules

- Every Path must have a way to win and a way to lose a duel. No Path is a
  pure helper.
- Counters give an edge, not a guaranteed win.
- Launch with **3 abilities per Path** (18 total). More come later as
  data, not new systems.
- **Support reaches allies.** Heals and shields work on "you and your
  allies". Until parties exist (section 6) your only ally is you.

### 4.4 The 18 abilities (M3 starting values)

Health is 100. Each ability has its own cooldown, plus 0.3 seconds after
any ability before the next. Abilities aim by facing, like the Strike.
Shots hit instantly (checked on the server) with a visual bolt.

| Path | Level 3 | Level 10 | Level 18 |
|---|---|---|---|
| Fang | **Lunge**: dash 12 studs; the first enemy passed takes 22. 6 s | **Rending Flurry**: 3 hits 0.25 s apart, 8 studs, Strike arc, 10 each. 8 s | **Final Toll**: 8-stud hit, 12 damage, or 40 if the target has 35 health or less. 14 s |
| Gale | **Slipstream**: dash 20 studs; the first enemy passed takes 10. 5 s | **Gust Blade**: shot, 35 studs, 18 damage. 4 s | **Afterimage**: 1.5 s immune to damage and effects; your next hit within 4 s deals +20. 16 s |
| Ember | **Cinder Bolt**: shot, 50 studs, 16 damage + burn 3 per second for 3 s. 3.5 s | **Scattershot**: 5 shots in a 40-degree fan, 30 studs, 8 each. 7 s | **Ashfield**: burning ground, radius 8, centred 25 studs ahead, 7 per second for 5 s. 15 s |
| Mire | **Bog Snare**: shot, 30 studs, 6 damage + root 1.5 s. 9 s | **Sinking Field**: zone of radius 10 where cast, 4 s; enemies inside are slowed 50% and take 3 per second. 14 s | **Undertow**: shot, 25 studs, pulls the target to 4 studs in front of you, 10 damage + slow 30% for 2 s. 12 s |
| Mend | **Siphon**: 8-stud hit, 14 damage; on a hit, heals you and allies 14. 6 s | **Ward**: 30-point shield for 6 s on you and allies within 15 studs. 14 s | **Renewal**: heals you and allies within 15 studs by 35 and removes slow, root and burn. 18 s |
| Bulwark | **Shield Bash**: 8-stud hit, 14 damage, knocks the target back 10 studs; you take 40% less damage for 2 s. 7 s | **Rebuke**: for 2 s, half of the player damage you take is dealt back to its attacker. 14 s | **Challenge**: shockwave of radius 12, 12 damage, taunts for 3 s: a taunted player's Strikes and single-target abilities can only target you while you are in their reach. 16 s |

How effects combine:

- **Immune** cancels a hit and any effect it carries.
- Otherwise **damage reduction** applies first, then the **shield**
  absorbs what it can, and the rest comes off health.
- **Rebuke** reflects half of the damage after reduction. Reflected
  damage is never reflected again and never Marks anyone.
- **Slows** do not stack: the strongest wins. **Root** overrides slow. A
  rooted player cannot dash.
- Applying a status again **refreshes** its timer.
- Every damaging hit on a player follows the protection rules exactly
  like the Strike (shields, safe zone, Marked, kill credit). Heals and
  shields on yourself work anywhere.
- **Training posts** take hits from every ability, for experience, and
  ignore all effects.

## 5. Technical design

### 5.1 Tools

| Area | Choice |
|---|---|
| Code sync | Rojo 7.x |
| Tool versions | Rokit |
| Packages | None yet. ProfileStore is copied into the repo. Wally is added when a second library is needed |
| Language | Luau, strict types |
| Saved data | ProfileStore (session locking prevents card duplication) |
| Unit tests | Lune, outside Roblox |
| Lint and format | Selene, StyLua |
| Checks on every push | GitHub Actions: lint, tests, Rojo build |

Rojo, Lune, StyLua and Selene are confirmed installable in the cloud
workspace.

### 5.2 Code layout

```
default.project.json
src/
  shared/                   used by server and client
    Catalog/                data: Relics, Edicts, tiers, Paths, abilities
    Rules/                  pure game rules, no Roblox APIs
      Ledger.luau           add / remove / move / claim / isComplete
      Scarcity.luau         cap checks
      BlindClaim.luau       picks, tier limits, Vault, defeat losses
      Paths.luau            hexagon distance, learning rate, unlocks
      Combat.luau           damage, cooldown and status maths
      TradeRules.luau       validate and apply a swap
    Net.luau                the single list of remote events
    Types.luau
  server/
    DataService.luau        load / save with ProfileStore
    LedgerService.luau      owns every Ledger; replicates changes
    SourceService.luau      caches, trials, sealed state
    CombatService.luau      health, hits, defeat, combat-log timer
    AbilityService.luau     validates and runs abilities
    PathService.luau        experience and levels
    ProtectionService.luau  safe zone, shields, Marked
    EdictService.luau
    TradeService.luau
    ShopService.luau
    WorldBuilder.luau       builds the starter island from code
  client/
    LedgerUI/  HUD/  PathUI/  TradeUI/
    AbilityController.luau  input, animation, effects
tests/                      Lune unit tests for src/shared/Rules
```

### 5.3 Design rules

1. **The server decides everything.** Clients send requests. The server
   checks range, cooldown, line of sight and rate for each one. Hits are
   confirmed on the server with shape casts.
2. **Game rules are pure functions.** Everything in `Rules/` takes plain
   data and returns plain data, so it can be unit-tested without Roblox.
3. **Card moves are atomic.** Claims and trades fully happen or do not
   happen. Nothing can create or destroy a card by accident, including
   when a player leaves mid-fight or a server shuts down.
4. **Content is data.** A new Relic or ability is a catalog entry.

### 5.4 The island

The first island is built by code when the server starts: simple terrain,
Tallyport, and marked spots for caches, trials and creatures. Hand-made
art in Studio can replace it later, because code finds world objects by
tag, not by position.

### 5.5 Testing

| Level | What | Who |
|---|---|---|
| Unit tests | All rules in `Rules/` | Automated |
| Build check | Project compiles into a place file | Automated |
| Play test | A short checklist per milestone, in Studio | You, on your PC |

Limit: Roblox Studio cannot run in the cloud workspace. Combat feel,
animation, UI and live networking are confirmed only by your play tests.
PvP needs at least two players; Studio's local test server can simulate
that on one PC.

## 6. Roadmap

Each milestone ends with something you can play, and gets its own build
plan.

| # | Milestone | You can… |
|---|---|---|
| M0 | Project skeleton | Open the built place in Studio and walk on an empty island |
| M1 | **The Ledger** | Find 12 Relics, fill the book, leave and return with it saved |
| M2 | Combat and defeat | Fight another player; the Vault, blind claim, scarcity caps and all protections work |
| M3 | The Six Paths | Choose a Calling, level Paths at different rates, equip 4 of 18 abilities |
| M4 | Creatures and trials | Earn experience and higher-tier Relics from the island |
| M5 | Edicts and trading | Track holders, hide, teleport, and swap cards safely |
| M6 | Parties | Group up; allies cannot hurt each other and support abilities reach them |
| M7 | Endgame and launch | Be Crowned, see the leaderboard; 50 Relics |

The first build plan covers **M0 and M1**.

### Not in scope for now

- Global (cross-server) scarcity.
- Guilds. (Parties are planned: M6.)
- Paid items. If added later: cosmetic only, no paid Relics, no paid
  re-rolls.

## 7. Open questions

1. **Blind-claim numbers.** 5 picks, the per-tier limits, the 3-Relic
   Vault and the one-third loss of non-Relic cards are first guesses.
2. **Research gaps.** No Reddit threads were found, and several sites
   (the official Roblox docs among them) were blocked in the workspace, so
   Roblox policy points rest on search snippets and need checking before
   launch.
