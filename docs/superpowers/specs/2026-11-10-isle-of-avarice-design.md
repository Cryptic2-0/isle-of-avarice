# Isle of Avarice — Game Design

**Date:** 2026-11-10 (revision 7, 2026-11-16: M5 Edicts, the shop and trading in section 3.13; revision 6, 2026-11-12: M4 in sections 3.9–3.12)
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
  Relic `017`. M1 shipped 12 Relics; M4 brings 30.
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

M5 builds these; section 3.13 has the details and numbers.

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

### 3.9 Creatures (M4 starting values)

Island beasts live at fixed dens outside Tallyport. The server runs them.

| Creature | Health | Attack | Speed | Sight | Base XP | Coin | Respawn |
|---|---|---|---|---|---|---|---|
| **Brinehound** | 60 | Bite: 8 damage, 5 studs, every 1.4 s | 16 | 35 | 30 | 4 | 30 s |
| **Shellback** | 160 | Claw: 14 damage, 6 studs, every 2 s | 10 | 25 | 70 | 10 | 45 s |
| **Bogspitter** | 90 | Spit: shot, 30 studs, 10 damage, every 2.5 s; keeps 15 studs away | 12 | 40 | 60 | 8 | 45 s |
| **Brine Colossus** | 900 | Slam: 25 damage to every player within 10 studs, every 4 s | 9 | 45 | 500 | 60 | 10 min |

Dens: four Brinehound packs of 3, three Shellback dens of 2, three
Bogspitter dens of 2, one Brine Colossus. Each creature respawns at its
den on its own timer.

**Behaviour.** A creature wanders within 12 studs of its den. It chases
the nearest player it can see within its sight range. It never enters
Tallyport, and it gives up when its target is more than 60 studs from
the den, enters the safe zone or is defeated: it walks home and heals to
full. It does not chase a player whose respawn shield is up.

**Fighting creatures.**

- The Strike and every ability hit creatures, with the same reach, aim
  and line-of-sight rules as against players. Slow, root, burn, pull,
  knockback and taunt work on them (a taunted creature chases the
  taunter). Training posts stay what they were.
- Creatures are PvE: hitting one never Marks a player, and the
  new-player shield does not stop it. Hitting one ends your respawn
  shield, like any attack.
- Creature damage follows the effect rules (immune, reduction, shield,
  then health). Rebuke reflects it back at the creature. The safe zone
  and the respawn shield block it.
- Combat logging counts only damage between players.
- A player defeated by a creature respawns in Tallyport. There is no
  blind claim and nobody gets XP for it. (Losses of non-Relic cards come
  with M5.)

**Rewards.** When a creature is defeated, every player who damaged it in
the last 30 seconds is a contributor. Each contributor gets the full Coin
and XP, and rolls its drop table on their own. XP goes to the Path that
player dealt the most damage to it with (the Strike counts as the
Calling; a tie goes to the Calling). A player without a Calling gets the
Coin only.

### 3.10 Trials and quests (M4 starting values)

**Wardens** stand at six spots. Each offers one trial. Taking it opens a
window with the goal, time limit and rewards, and says whether its Relic
is sealed. One trial at a time per player.

| Trial | Kind | Goal | Time | Relic | Coin | XP |
|---|---|---|---|---|---|---|
| **Tidewalk** | course | touch 6 markers in order | 60 s | R013 (Silver) | 30 | 120 |
| **Gullstep Climb** | course | touch 8 markers in order | 75 s | R014 (Silver) | 40 | 160 |
| **Salt Post** | delivery | carry the parcel to the Harbour Warden | 70 s | R015 (Silver) | 35 | 140 |
| **Cull the Pack** | hunt | defeat 5 Brinehounds | 120 s | R016 (Silver) | 40 | 180 |
| **Shellbreaker** | hunt | defeat 3 Shellbacks | 150 s | R024 (Gold) | 70 | 300 |
| **The Tallyman's Duel** | duel | defeat the Drowned Tallyman | 90 s | R025 (Gold) | 80 | 350 |

- A trial fails on timeout, on defeat, or when the player leaves. A
  failed trial can be retried after 30 seconds; a passed one after 5
  minutes.
- Trial XP goes to the Calling. Coin is paid even when the Relic is
  sealed; the Relic is skipped (sealed) or, with no free slot, lost with
  a message.
- Hunts count creatures the player contributed to (3.9).
- The **Drowned Tallyman** (duel) appears only for the duelling player
  and only they can hurt it or be hurt by it: 300 health, Strike-like
  hits of 12 damage every 1.2 s at 7 studs, speed 15, and every 8 s a
  Lunge (dash 12 studs, 18 damage).
- **Quest — The Unpaid Debt** (Platinum): pass Tidewalk, Salt Post and
  The Tallyman's Duel in that order, then contribute to defeating the
  Brine Colossus. Reward: R027 (Platinum), 150 Coin, 600 XP. Progress is
  saved. A step done out of order does not count.

### 3.11 Relics 013–030 (M4)

| Slot | Tier | Source |
|---|---|---|
| 013–016 | Silver | trials (above) |
| 017–018 | Silver | caches in hard-to-reach spots |
| 019 | Gold | Brinehound, 2% per contributor |
| 020 | Gold | Shellback, 5% |
| 021 | Gold | Bogspitter, 5% |
| 022 | Gold | Brine Colossus, 100% |
| 023 | Gold | Brine Colossus, 20% |
| 024–025 | Gold | trials (above) |
| 026 | Gold | cache on the highest point |
| 027 | Platinum | quest (above) |
| 028–030 | Copper | caches |

Every drop and reward obeys scarcity (3.2): a sealed Relic is not given.

### 3.12 M4 details (rulings made while planning)

- A creature "sees" a player within its sight range with an unblocked
  line from the creature (bodies never block). A hit on a creature with
  no target makes the attacker its target if that player is a valid
  target: alive, outside Tallyport, no respawn shield, within 60 studs
  of the den. A creature already chasing keeps its target. A taunted
  creature chases the taunter while the taunter is a valid target.
- A creature walking home is immune and ignores taunt. At its den it
  heals to full and forgets its contributors and statuses. Creatures
  stop 4 studs outside Tallyport; a pull or knockback cannot put one
  inside. Dens are at least 130 studs from the town centre.
- A player standing in Tallyport cannot damage creatures.
- The new-player shield does not block creature damage; the safe zone
  (even for a Marked player) and the respawn shield do.
- When both a player and a creature hit someone, the most recent hit
  within 15 seconds decides who defeated them. A creature's last blow is
  a creature defeat. Creature hits never take a player's kill or
  combat-log credit.
- XP Path: a tie not involving the Calling goes to the Path earlier in
  hexagon order. Rebuke's reflected damage counts as Bulwark; burns and
  zones count for the Path of the ability that made them.
- A capped drop with many contributors serves them most-damage-first;
  once the cap is reached the rest are told it is sealed. Contributors
  who left get nothing. A Relic reward to a Ledger locked by an open
  claim is lost with a message, like a full Ledger; Coin and XP are
  still paid.
- The Harbour Warden offers Tidewalk at the harbour; Salt Post starts at
  the Saltworks Warden. A trial is accepted within 15 studs of its
  Warden; its timer starts on Accept; a marker counts within 6 studs; the
  parcel is delivered within 10 studs of the Harbour Warden. Leaving
  mid-trial counts as a fail. Hunts count creatures defeated while the
  trial runs.
- The quest repeats: after its reward, progress restarts at step 1.
- The Drowned Tallyman has sight 60 and is leashed 60 studs from its
  arena; other players do not see it; it pays nothing itself (the trial
  pays).
- Hard-to-reach caches sit at least 20 studs up, reached by ledges that
  rise at most 4 studs each; R026's ledge is the island's highest point.
- The Ledger and the blind claim show the slots of the Relics that exist
  (30 in M4, 50 at launch).

### 3.13 Edicts, the shop and trading (M5 starting values)

Rulings made while planning M5. They fill the gaps in 3.4, 3.6 and 3.7.
All numbers are starting values for play tests.

**Edicts are cards.** An Edict sits in a free slot like a spare Relic,
with ids `E001` to `E005`. It can be used, discarded, sold or traded. It
can never be claimed into a numbered slot, and it does not count towards
the 3 Relics that end the new-player shield.

| Id | Edict | What using it does |
|---|---|---|
| E001 | Summons | You name a Relic. You see every other player on the server who holds it, claimed or spare. |
| E002 | Audit | You see the Ledger of the nearest other player within 20 studs: claimed Relics (and which are Vaulted) and free-slot cards. They are told you looked. |
| E003 | Veil | For 10 minutes Summons does not list you and Audit shows nothing. Using it again restarts the 10 minutes. Not saved: it ends when you leave. |
| E004 | Passage | You appear 8 studs from a player you have met this session. You meet a player by standing within 30 studs of them. |
| E005 | Homecoming | You appear in Tallyport. |

- An Edict is used up when it works. It is not used up when it is refused
  (nobody in range, not allowed now, bad request).
- A Summons that finds nobody is still used up: "nobody" is an answer.
- An Audit of a Veiled player is used up and shows only that their Ledger
  is veiled.
- Passage and Homecoming are refused while you are Marked, within 30
  seconds of dealing or taking player damage, or during a trial (a
  delivery or a course would be trivial otherwise).
- Passage sets you down on land, outside every hazard shape when it can.
- No Edict can be used while your Ledger is locked by a blind claim, or
  while you are defeated.

**Defeat costs Edicts.** On any defeat (a player, a creature or the
island) the victim loses one third, rounded down, of the Edicts they
hold, chosen at random. They are destroyed. This also answers the Wide
Isle's open question 3: dying to the island now costs something. Leaving
during a fight (combat logging) still costs only the blind claim.

**The Edict Hall.** A clerk stands in Tallyport. Talking to them opens the
shop. Every purchase is checked on the server: within 15 studs of the
clerk, enough Coin, enough free slots.

| Buy | Price |
|---|---|
| Edict pack: 3 Edicts, each drawn on its own | 60 Coin |
| A Copper Relic of the Counting Fields (R001 to R006) | 40 Coin |

Pack odds per card, shown in the window: Summons 25%, Audit 20%, Veil
20%, Homecoming 20%, Passage 15%.

| Sell (the card is destroyed) | Coin |
|---|---|
| Copper Relic | 1 |
| Silver Relic | 15 |
| Gold Relic | 50 |
| Platinum Relic | 150 |
| Crown Relic | cannot be sold |
| Edict | 3 |

Only cards in free slots can be sold. Selling a capped Relic frees a copy
under the scarcity rule: it is another release valve.

**Trading.** "Trade" asks the nearest other player within 15 studs. They
have 20 seconds to accept. Then both see one window:

- Each side offers up to 6 cards from their free slots and any amount of
  their Coin. Claimed Relics must be unclaimed first.
- Any change to either offer clears both confirmations, and nobody can
  confirm for 2 seconds after a change, so a last-moment switch cannot be
  slipped past the other player.
- When both have confirmed, the server checks everything again (both
  still hold what they offered, both have room for what they receive,
  neither Ledger is locked) and swaps everything at once, or nothing.
- The trade is cancelled if either player cancels, leaves, is defeated,
  has their Ledger locked by a claim, or moves more than 25 studs away.
- One-sided trades (gifts) are allowed. Trading never changes how many
  copies of a Relic the server holds.

Not in M5: Edicts as rewards from trials or creatures; shop stock beyond
the six Copper Relics; a trade history.

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
