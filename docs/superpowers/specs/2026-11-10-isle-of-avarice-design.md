# Isle of Avarice — Game Design

**Date:** 2026-11-10 (revision 10, 2026-11-24: M8 launch polish in section 3.16; revision 9: M7 endgame in 3.15; revision 8: M6 in 3.14; revision 7: M5 in 3.13; revision 6: M4 in 3.9–3.12)
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
be changed only in a safe zone, and never while Marked or within 30 seconds
of dealing or taking player damage (the rule trading and selling use).
Crown-tier Relics cannot be Vaulted, so the rarest cards always stay in play.

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
- A trade cannot be asked for, accepted or confirmed while you are Marked or within 30 seconds of dealing or taking player damage, and nothing can be sold to the clerk then either: cards cannot be moved out of reach of a blind claim in the middle of a fight. A trade is cancelled instead of completed if either trader is Marked or in a fight at the moment of the swap.

Not in M5: Edicts as rewards from trials or creatures; shop stock beyond
the six Copper Relics; a trade history.

### 3.14 Parties (M6 starting values)

Rulings made while planning M6. They fill the gaps in 3.5, 3.9, 3.10, 3.13 and
4.3 ("support reaches allies"). All numbers are starting values for play tests.

**What a party is.** Up to 4 players who cannot hurt each other and whose heals
and shields reach each other. A party lasts for the session only: nothing about
it is saved, and leaving the game leaves the party.

| Rule | Value |
|---|---|
| Party size | 4 players at most |
| Who can be invited | the nearest other player within 15 studs (the same rule as trading) |
| An invite lasts | 20 seconds |
| Support reach (Siphon's heal, Ward, Renewal) | 15 studs from the caster |
| "In a player fight" | Marked, or dealt or took player damage in the last 30 seconds |
| Saved between sessions | no |

**Forming and leaving.**

- "Party" asks the nearest other player within 15 studs. They have 20 seconds
  to accept. If the asker has no party, accepting makes a party of two led by
  the asker; otherwise the new player joins the asker's party.
- Only the leader invites. A player already in a party cannot be invited: they
  must leave first. A full party cannot invite. One invite at a time, both for
  the one asking and the one asked.
- Anyone can leave at any time, in a fight or not. The leader can remove a
  member and can hand the lead to another member.
- When the leader leaves, the member who joined earliest leads. A party left
  with one player breaks up.
- Being defeated does not end a party. Leaving the game does.

**No friendly fire.** Party members cannot hurt each other in any way: the
Strike, every ability, zones, burns and reflected damage. An ally is not a
target at all, so a Strike or a shot passes an ally and can hit the enemy or
creature behind them. Effects carried by a hit (slow, root, burn, pull,
knockback, taunt) never reach an ally either.

**Joining in the middle of a fight.**

- From the moment two players are in one party, their hits on each other stop:
  a burn or a zone one of them placed stops hurting the other, and a taunt
  stops forcing targets.
- A Mark is never removed, shortened or shared by a party. Each player keeps
  their own Mark for its full time.
- A defeat is never credited to a party member of the victim. A hit landed
  before joining therefore cannot earn a blind claim, XP or a combat-log claim
  on someone who is now an ally. Party members can never blind-claim each other.
- Leaving a party takes effect at once. Former allies can then fight under the
  normal rules (whoever starts it is Marked).

**Support reaches allies.** Siphon's heal, Ward's shield and Renewal's heal and
cleanse reach the caster and every party member within 15 studs. Siphon gains
this 15-stud reach (4.4 gave it none). Nothing else reaches anyone else: damage
reduction (Shield Bash), reflect (Rebuke), immunity and the bonus hit
(Afterimage) stay the caster's own. Support never reaches a player outside the
caster's party.

- A caster who cannot be attacked by players (the new-player shield, or standing
  in Tallyport while not Marked) does not reach an ally who is in a player fight.
  Their support still reaches themselves and allies who are not fighting players.
- Support that reaches an ally in a player fight ends the caster's respawn
  shield, as attacking does.
- Support does not reach a player during The Tallyman's Duel (the duel stays
  private), and others cannot hurt that player's champion, as before.
- Heals and shields on yourself still work anywhere.

**Creatures and trials.** Support counts as helping (3.9):

- When a caster's support reaches an ally who has hit a creature in the last 30
  seconds, the caster becomes a contributor to that creature too, unless the
  caster is standing in Tallyport. The 30-second window then runs from the
  support.
- A contributor who dealt the creature no damage gets the full Coin, rolls its
  drops like anyone else, and gets the XP in the Path of their support (Mend).
  Contributors who did damage keep the old XP rule.
- For a capped drop, contributors who only supported are served after everyone
  who did damage.
- Standing near a fight pays nothing. A party member who neither hit the
  creature nor supported someone who did is not a contributor.
- Because support counts as contributing, it also counts for hunts (3.10) and
  for the quest's Brine Colossus step. Each member runs their own trial;
  parties do not share trial progress.

**Claims and the gang problem.** A party of four against one player is limited
by these rules, and by nothing else:

- Every attacker is Marked on their own first hit, as before.
- Fighting back covers the whole party: a player is not Marked for hitting any
  member of a party whose member hit them in the last 30 seconds.
- The one-hour repeat-kill limit (3.5) counts for the whole party: when a claim
  opens, the limit starts for the killer and for every member of the killer's
  party at that moment. Leaving the party afterwards does not reset it.
- The claim itself goes to whoever landed the defeat. A party shares no claim,
  no taken Relic and no defeat XP.

Two friends cannot farm each other inside a party: they cannot hurt each other,
so there is no defeat, claim or XP to gain.

**Other systems.**

- Edicts: unchanged. Passage still needs a meeting this session; an invite needs
  you within 15 studs, so you have always met whoever invited you or whom you
  invited. Audit and Summons treat party members like anyone else.
- Trading: unchanged. Party members trade like anyone else.
- New-player shield: a shielded player may join a party. The party changes
  nothing about the shield (see support above).

**What players see.**

- A "Party" button beside the "Trade" button, and an invite banner "<name>
  invites you to their party" with Accept and Decline.
- A party panel at the right of the screen: "Party 2 / 4", one row per member
  with name, "(leader)" for the leader, health as "75 / 100" with a bar, or
  "defeated". The leader's rows for other members have "Remove" and "Make
  leader". A "Leave" button.
- A green marker with the ally's name above each ally's head, seen only by
  their party.

Not in M6: party chat, shared claims or loot, invites from a player list,
cross-server parties, a party finder, shared trial runs, guilds.

### 3.15 The endgame (M7 starting values)

Rulings made while planning M7. They fill the gaps in 3.1, 3.2, 3.8 and the
backlog's launch items. With M7 the Ledger has all 50 slots. All numbers are
starting values for play tests.

**Relics 031 to 050.** Twenty new Relics, so the Ledger reaches 50. Every one
has a source that can give it again, so a copy freed by a trade, a sale, a
claim, a Renounce or a holder leaving can always be earned anew.

| Slot | Name | Tier | Source | Description |
|---|---|---|---|---|
| 031 | Clerk's Brass Receipt | Copper | Edict Hall, 40 Coin | The Hoarder's clerks stamped one for every sale, and charged a coin for the stamp. |
| 032 | Ash-Crusted Tally Bead | Copper | cache, far out in the Cinder Flats | A bead from an abacus left too near the vents; it still counts, just warmly. |
| 033 | Rampart Toll Token | Copper | cache, far out in Bastion Reach | Every visitor to the fortress paid one to get in, and another to get out. |
| 034 | Pressed Blight-Leaf | Copper | cache at the blight's edge in the Hush Gardens | Kept between the Ledger's pages, where the Hoarder pressed everything they could not sell. |
| 035 | Hound-Tooth Tally | Silver | Brinehound, 6% | Each notch is a debtor a Brinehound chased all the way home. |
| 036 | Barnacled Coin Purse | Silver | Shellback, 8% | Found inside a shellback, which the Hoarder then billed for storage. |
| 037 | Spitter's Glass Eye | Silver | Bogspitter, 8% | A Bogspitter kept watch over the Hoarder's mud with it, and missed nothing. |
| 038 | Hedge-Heart Locket | Silver | cache at a dead end of the Thornwood maze | The Hoarder hid it in a blind alley, then charged themselves rent for the space. |
| 039 | Cinder-Shelf Coffer | Silver | cache on a climb in the Cinder Flats | Kept high above the hot ground, where only the nimble and the fireproof could reach it. |
| 040 | Reed-Woven Wallet | Silver | trial: Reed Run | Woven from bog reeds and taken as the toll for walking the Hoarder's boardwalk. |
| 041 | Bailiff's Gavel | Gold | Gilded Bailiff, 30% | One knock and the debt was due; two knocks and so was the house. |
| 042 | Bellows Ember-Key | Gold | trial: The Bellows Dance | Forged in the Bellows and never quite cooled, so the Hoarder kept it in an oven mitt. |
| 043 | Colossus Barnacle Crest | Gold | Brine Colossus, 15% | The biggest barnacle on the Brine Colossus, polished to a shine and listed as an asset. |
| 044 | Tide-Turner's Hourglass | Gold | prize cache on Reckoning Rock (3 s hold) | It tells the time by the tide, and the Hoarder charged by the hour. |
| 045 | Gilded Spittoon | Gold | trial: Spitter Season | Bogspitters were trained to aim for it, and the Hoarder sold tickets. |
| 046 | Wardens' Seal of Service | Platinum | The Warden's Round | Every Warden pressed a thumb into it, swearing the Hoarder's trials were fair. |
| 047 | The Menagerie Ledger | Platinum | The Beast Tally | Every creature on the isle, counted, priced and entered in platinum ink. |
| 048 | The Gilded Sceptre | Crown | Gilded Bailiff, 100% | The Hoarder pointed it at whatever they wanted next, and the Bailiff went and fetched it. |
| 049 | The Orb of Every Shore | Crown | trial: The Grand Tally | Look inside and you see the whole island at once, every shore the Hoarder charged a toll on. |
| 050 | The Hoarder's Crown | Crown | the Throne: a climb in the Drowned Fen, then a 10 s hold | Heavy with every debt ever owed; the island crowns whoever fills the Ledger. |

**Three Crowns, one unique challenge each.** Crowns are capped at 1 per server
(3.2), cannot be Vaulted (3.4) and cannot be sold (3.13).

- **The Gilded Bailiff** (R048) is a world boss: one den far out in the Cinder
  Flats, too strong for most players alone. Its Sceptre drops for every
  contributor, so under the cap it goes to the contributor who dealt the most
  damage (3.12) and the rest are told it is sealed. A party makes it possible;
  a soloist must keep away from the slam and use ranged abilities.
- **The Grand Tally** (R049) is a course round the whole island under a hard
  clock: one marker in every wild region, then Reckoning Rock, in order, in
  300 seconds. The route crosses the Sluices at their bridges and ends across
  the tide causeway, so the tide must be timed. The Crown Warden stands in
  Tallyport. Passage and Homecoming are refused during a trial (3.13).
- **The Throne** (R050) is a twelve-ledge climb on the dry east bank of the
  Drowned Fen with the Crown cache on top. Opening it takes a 10-second hold,
  checked by the server, while rivals can knock the holder off or defeat them.

**The Gilded Bailiff.**

| Health | Attack | Lunge | Speed | Sight | Base XP | Coin | Respawn | Drops |
|---|---|---|---|---|---|---|---|---|
| 2400 | Gavel Slam: 30 damage to every player within 12 studs, every 3.5 s | 20 studs, 25 damage, every 9 s | 12 | 50 | 900 | 120 | 20 min | R048 100%, R041 30% |

It follows every creature rule of 3.9 and 3.12 (leash 60, heals at home, never
enters Tallyport). Drops added to the M4 creatures: Brinehound R035 6%,
Shellback R036 8%, Bogspitter R037 8%, Brine Colossus R043 15%.

**Four new trials.** Ten Wardens in all.

| Trial | Warden, where | Kind | Goal | Time | Relic | Coin | XP |
|---|---|---|---|---|---|---|---|
| **Reed Run** | Reed Warden, Drowned Fen gate | course | touch 6 markers on the boardwalks, in order | 70 s | R040 (Silver) | 40 | 170 |
| **The Bellows Dance** | Bellows Warden, before the Bellows | course | touch 5 markers inside the vent field, in order | 50 s | R042 (Gold) | 90 | 400 |
| **Spitter Season** | Spitter Warden, Cinder Flats gate | hunt | defeat 3 Bogspitters | 180 s | R045 (Gold) | 80 | 380 |
| **The Grand Tally** | Crown Warden, Tallyport | course | touch 7 markers: one in every wild region, then Reckoning Rock | 300 s | R049 (Crown) | 200 | 900 |

Reed Run's markers sit on both long boardwalks, so the rotted gap must be
waded or walked round. The Bellows markers are vent centres. Every rule of
3.10 applies (one trial at a time, cooldowns, Coin paid when the Relic is
sealed).

**Two rounds** (the multi-step Platinum sources). A round is a checklist done
in any order; finishing it pays once and empties it, so it can be done again.

| Round | Steps | Reward |
|---|---|---|
| **The Warden's Round** | pass each of the nine trials below the Crown (all but The Grand Tally) | R046, 250 Coin, 800 XP to the Calling |
| **The Beast Tally** | contribute to defeating one of each: Brinehound, Shellback, Bogspitter, Brine Colossus, Gilded Bailiff | R047, 250 Coin, 800 XP to the Calling |

Progress is saved. The trial HUD shows one line under the quest:
"Warden's Round 3 / 9, Beast Tally 2 / 5". A step already done this round
does not count again.

**Scarcity at 50.**

| Tier | Relics | Server cap per Relic |
|---|---|---|
| Copper | 13 | none |
| Silver | 15 | 8 |
| Gold | 15 | 4 |
| Platinum | 4 | 2 |
| Crown | 3 | 1 |

Completing is meant to take many sessions: a third of the Ledger comes only
from bosses, hard trials, rounds or contested caches, and each capped copy
must be free on that server when it is earned. Nothing can block it forever:

- **A complete Ledger steps aside.** The claimed Relics of a Ledger that has
  every slot claimed no longer count against the caps (its spares still do).
  A Crowned player who sits in Tallyport therefore blocks nobody, and others
  can earn their own copies. The cap still blocks only new copies (3.2): if a
  Crowned player later loses a Relic, the server may briefly hold more than
  the cap.
- The M2 to M5 valves stay: trading, the blind claim (a hoarder can Vault only
  3 Relics, never a Crown), selling a capped spare, and holders leaving.
- The last valve is the server itself: caps are per server, and a new server
  starts with nothing held.

**Completing the Ledger.** The moment every slot is claimed, the player is
**Crowned**, at most once per run (a run is the time between a start and the
next Renounce). Unclaiming and claiming again in the same run gives nothing.
A Crowning happens wherever a Ledger becomes complete, and on joining with a
complete Ledger that has not yet given its run's Crown.

- **The ceremony.** Every player sees the message "<name> has claimed every
  Relic and is Crowned!" and a gold banner across the top of the screen for 6
  seconds ("<name> is Crowned!", or "<name> is Crowned again: 3 Crowns!").
  A column of gold light 200 studs tall rises where the player stands and
  fades over 6 seconds, visible across the island. The player is told "You
  are Crowned! Your name goes on the Tally Stone in Tallyport."
- **The title.** "Crowned", "Crowned twice", "Crowned 3 times", followed by
  "★n" once the player has Renounced n times, for example "Crowned twice ★1".
  It shows in gold above the player's head to everyone (above the MARKED tag
  and the ally marker), under the player's name in the party panel, and on a
  line of the Ledger book. Titles are permanent: Renouncing keeps them. The
  Crowned are visible on purpose: their Crowns cannot be Vaulted.
- **The cosmetic.** The Gilt Circlet: a ring of six small gold points worn on
  the head by every player who has been Crowned, built from parts in code
  (nothing to buy, nothing to equip). Each star adds a purple gem, up to six.
- **The badge.** A Roblox badge, "Crowned", is awarded on the first Crowning.
  Its id is a setting (`LaunchConfig.CROWNED_BADGE_ID`); while it is 0 nothing
  is awarded. A player Crowned before the id was set gets the badge the next
  time they join. It is awarded once.

**The Tally Stone and the all-time board.** A stone tablet stands on the south
side of the Tallyport plaza. Its face is the board, "The Crowned": the ten
players with the most Crowns across every server, one line each
("1. Ann: Crowned 3 times"). Crowns rank; ties go to the lower user id.

| Rule | Value |
|---|---|
| Stored in | an ordered data store named `CrownedBoard_v1`: key the user id, value the Crown count |
| Rows | 10 |
| Read | every 120 s, and 5 s after a successful write |
| Written | when a player's Crowns exceed what the board last stored for them; a write never lowers a stored count |
| After a failed write | retried for that player no sooner than 60 s later |
| When the store cannot be reached | the board says "This server only: the all-time records cannot be reached" and lists the Crowned players on this server |

Present players count with their live Crowns, so a new Crown shows within
seconds even before the store has it. Every data store and badge call runs in
the background; none can delay joining, a request or a save.

**Renounce.** A Crowned player whose Ledger is complete may Renounce at the
Tally Stone: hold "Renounce" for 2 seconds, read what will happen, type the
word RENOUNCE (any case, spaces ignored) and press "Renounce" within 60
seconds. It cannot be undone.

| Goes back to the island | Kept |
|---|---|
| Every Relic, claimed and spare | Coin |
| Every Edict | Path levels, XP, Calling, abilities and loadout |
| The Vault (it empties) | Trial cooldowns |
| The Unpaid Debt's progress (back to step 0) | Crowns, title, badge, place on the board |
| Both rounds' progress | The ended new-player shield (it never returns) |

The player earns a **star**: a permanent prestige mark shown in the title and
as a gem on the circlet. A new run starts: completing the Ledger again gives
another Crown, ceremony and board update (no second badge).

Renounce is refused, with nothing changed, while the player: has not loaded,
is not Crowned this run or lacks a claimed slot, is defeated, has a Ledger
locked by a claim, is making a claim, is trading, is in a trial, is outside
Tallyport, is Marked, or dealt or took player damage in the last 30 seconds.
All of these are checked again at the confirm. The offer ends if the player
cancels, waits 60 seconds or leaves.

**Saved data.** Two new fields, each with its own sanitize step on load, so
`schemaVersion` stays 1 and old saves load unchanged:

- `crown`: Crowns, stars, the count last written to the board, and whether the
  badge was awarded. Stars are always the Crowns or one fewer; damaged values
  are pulled into range, and an unreadable star count reads as "Crowned this
  run", so a damaged save can never give a free Crown.
- `rounds`: the steps done in each round, known ids only, no repeats.

**Launch fixes** (from the backlog; the rest of it waits):

- **Health regeneration.** Roblox's default regeneration is replaced by the
  game's own: 1 health a second, starting 10 seconds after the player last
  lost health from anything. Standing in a hazard therefore never
  regenerates, and the hazard numbers of the Wide Isle mean what they say.
- **Held caches are checked by the server.** A cache with a hold (the prize
  caches, 3 or 4 s; the Rock's second prize, 3 s; the Throne, 10 s) opens
  only if the player's hold, as the server saw it, lasted the hold time less
  0.3 seconds.

**What a two-player Studio test can check.** Data stores and badges do not
work in an unpublished place, and ProfileStore keeps data in memory, so
nothing survives a restart. The automated test checks the new world, the
held caches, Crowning, the ceremony on both screens, the title, the circlet,
the step-aside rule, the board through a stand-in store and in its offline
form, the badge through a stand-in, every Renounce refusal it can stage, the
two-step confirm, what Renounce returns and keeps, a second Crown, the Gilded
Bailiff, the Beast Tally, the rounds line, regeneration and the 50-slot
screens. The real board, the badge and saving across sessions are checked by
the owner on the published game.

Not in M7: a fastest-run board, a board window away from Tallyport, more
cosmetics or a way to hide the circlet, titles in chat, global (cross-server)
scarcity, sounds, the UI polish pass of the backlog, paid items.

### 3.16 Launch polish (M8 starting values)

Rulings made while planning M8. M8 adds no content: it makes the game
comfortable on a phone, stops a tap from doing something the player did not
mean, and clears the backlog items and review notes that a player could meet.
The phone target is a landscape screen of 640 by 360 pixels, under Roblox's top
bar (36 or 58 pixels). All numbers are starting values for play tests.

**Where the HUD goes.** One pure rule, `HudLayout`, places every always-on
control from the screen's size, the top bar's height and whether it is a touch
screen. A screen whose shorter side is under 500 pixels is a phone.

| Area | Rule |
|---|---|
| Thumbstick zone (touch only) | the left 40% of the screen, bottom 45% |
| Jump zone (touch only) | phone: the bottom-right 100 by 95 pixels; larger: 180 by 220 |
| Free band | touch: from the thumbstick zone + 12 to the jump zone − 12; otherwise the whole width less 12 each side |
| Ability bar | four square slots, 6 apart, 12 above the bottom, centred in the free band; a slot is a tenth of the screen height, at least 44 and at most 96 pixels |
| Menu row | Ledger, Paths, Trade, Party, one row 6 above the ability bar, centred in the free band; each button a quarter of the band, at most 120 wide; 32 tall on a phone, 36 otherwise |
| Drop shield | under the Coin line, top left (12, 44 under the top bar), 150 by 32; on a touch screen the status lines under it stop 6 above the thumbstick (the least urgent are dropped, the region first) |
| Trial HUD | top right, 12 from the edge, room for four lines; phone: 220 wide, lines 22 tall, 8 under the top bar; otherwise 300 wide, lines 28 tall, 16% down |
| Party panel | top right under the lines the trial HUD shows, 6 below them; 220 wide on a phone, 280 otherwise; it stops 6 above anything below it in its column (the menu row, the ability bar, the jump zone), keeps at least its title row (46 pixels) and scrolls its rows; its rows are 40 tall on a touch screen (so one fits beside four trial lines on a phone), 48 otherwise |

On a 640 by 360 phone with a 58-pixel top bar this puts the ability bar at
(301, 304), 194 by 44; the menu row at y 266, four buttons 60 by 32 from x 269;
the trial HUD at (408, 66), 220 by 100. On a screen without touch the ability
bar and menu row are centred, as before. The four menu buttons leave the bottom
left (where they sat on the thumbstick) and live in their own row; B and P
still open the Ledger and the Paths panel. The HUD sits under the windows: the
menu row and the ability bar never cover an open window. In screen order (DisplayOrder) the
menu row is 5, the ability bar 6, the trial HUD lines 7, the Coin and status lines 8 and the
party panel 9, all under the lowest window (the Ledger, 10). The trial offer (14), the "Drop
shield" dialog (15) and the party invite banner (16) are windows and keep their own screens above.

**Windows on a phone.** Every window keeps its size as a share of the screen,
with a smallest size that fits a 640 by 360 phone under a 58-pixel top bar:

| Kind | Smallest size | Windows |
|---|---|---|
| Big | 600 by 280 | the Ledger book, the claim screen, the Edict Hall, the trade window, the Paths panel, the Calling picker, the Summons picker |
| Small | 300 by 240 | the trial offer, the Renounce window, the Passage picker, the Edict result |
| Dialog | 300 by 140 | the "Drop shield?" and "Change your Calling?" questions |

A window's Close button is at least 40 by 32. The Calling picker's cards are
220 pixels tall, so a whole card fits a phone.

**Taps.**

- **A second tap to confirm.** Unclaiming a claimed slot, and discarding a
  free-slot card, take two taps on the same control within 3 seconds. The
  first tap marks the control in red ("Tap again to unclaim", "Sure?") and
  sends nothing; a tap on another control, or a wait of more than 3 seconds,
  starts over. The server is not involved: it still checks every request.
- **One request at a time.** After a tap sends a request, the row it was on
  (a Ledger slot or free-slot row, a claim cell, the Paths loadout) or the whole
  window (the Edict Hall, the trade window, the party panel, the Renounce
  window) goes inert and dimmed until the server's next view of it arrives, or
  for 1 second when the server answers with a message only (a refusal). Every
  button ignores a tap while it is inert.
- **No borders.** Nothing the client draws has Roblox's default 1-pixel border.
- **One kit.** The shared pieces every screen repeated (corners, text limits,
  labels, buttons, the inert look, list clearing, scrolling lists, windows,
  the one-request guard) live in one client module, `UiKit`.

**The region banner.** Entering a region shows its name and hint ("Thornwood:
A hedge maze...") for 3 seconds in its own line just under the message line,
so it never replaces or delays a message from the server. A newer region
replaces an older one at once. The trade and party invite banners move down to
make room (18% and 28% from the top).

**The blight on the ground.** The Hush Gardens blight gets a ground tint: a
dull purple-grey, see-through sheet (colour 92, 72, 104, Ground material, 35%
see-through) laid on every ground strip of the Hush Gardens beyond 330 studs
from the island centre, judged on each strip's centre line. It touches nothing
and blocks nothing; the status line and the entering message stay the exact
truth (the tint's edge can be up to half a ground cell off).

**Fixes folded in** from the review notes of M4 to M7, each one a player could
meet:

- The all-time board asks again for a name it could not read, 300 seconds
  after the failed try, instead of showing "Claimant N" until the server
  restarts.
- The Edict Hall and trades check that the Coin move is valid before they
  write anything, so a card can never move without its Coin.
- An open trade is sent again when either trader's Coin changes, so "of N"
  stays true.
- The trade window's confirm countdown runs only while a trade is open.
- A refused Ledger request no longer leaves its row dimmed until the next
  change (the 1-second rule above).
- Health regeneration waits for a new character's Humanoid before watching it
  (a character whose Humanoid arrived late healed through hazards), and a
  failed health write for one player no longer stops the others.
- The party panel fits a phone (above), and a long name in a party row ends
  in "..." instead of running under the buttons: the name and health share the
  first line, the title and the Lead and Remove buttons the second.
- The Summons picker, the Renounce window's lines and the Ledger's Crown line
  fit a phone (the window sizes above).

**Tidying.** HazardService's "a burst hits once per cycle" rule becomes a pure,
tested `Hazards.landing`; the extra-cache spot (310, −60) is written once
(`Regions.extraCache`); Squall Steps and the tests read region bearings from
`Regions`; one `living` helper (`Fighters.body`) replaces the copies;
Tallyport's buildings move into `World.buildings`; the unused
`World.islandHalfSize` goes; `Ledger.sanitize` keeps saved free cards after a
gap; the test harness survives tables that contain themselves; and the tests
the backlog listed are written.

**What the automated play test checks.** Every game screen has no borders; the
menu row and ability bar sit where `HudLayout` says for the test window; the
old bottom-left buttons are gone; every window has its smallest size; the menu
buttons open and close the Ledger and the Paths panel; one tap on a claimed
slot or on Discard does nothing and two do; a refused Claim's row comes back
after a second; the region banner and a server message show together; the
blight tint lies inside the blight and touches nothing; a Coin change reaches
an open trade; a new character does not regenerate in its first 10 seconds
after a hit; the party panel keeps clear of the menu row and shows whole names.
A phone screen cannot be emulated by the test: the owner checks it by hand
(Studio's device emulator, then a real phone).

**Review notes left as they are**, because no player can meet them today:
code only the play test uses; wording and readability notes; checks that
cannot fail because nothing yields between them (EdictService's discard after
an effect, AbilityService's caster check); values that are always the same in
play (MaxHealth is always 100; stars are pulled into range on load); the
duplicated rate-limit helper in three services; a defeat writing a Ledger that
a claim has locked (intended); Passage landing on its target when every spot
round them is blocked (rare, and the target sees it). Tuning stays with the
owner's play tests: the hazard numbers, whether dying to the island should
cost something, the 0.3-second hold slack on a slow phone, the gust push near
pillars and the causeway's walk-out window.

Not in M8: sounds (no verified asset ids), paid items, global (cross-server)
scarcity, guilds, Luau type checking in `check.sh` (none of the installed
tools — Rojo, Lune, StyLua, Selene — checks Luau types), a UI size setting,
portrait phones, gamepad layout, translations.

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
| M8 | Launch polish | Play comfortably on a phone; no slot unclaimed or card discarded by one stray tap; the backlog and review notes a player could meet are fixed |

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
