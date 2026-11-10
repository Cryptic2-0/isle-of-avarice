# PvP death penalties and loot-on-kill

## Key lessons

- **Let players choose their risk by place.** Albion Online ties loss to zone colour: safe zones lose nothing, while red and black zones are full loot ([Gamerevolution](https://www.gamerevolution.com/guides/341481-albion-online-losing-items-upon-death-works-green-yellow-red-regions)). Risk becomes a decision, not a surprise.
- **Punish the aggressor, not the victim who fought back.** In RuneScape's Wilderness, attacking another player gives you a skull. Retaliating after you were attacked first avoids it ([OSRS Wiki](https://oldschool.runescape.wiki/w/Skull_(status))). Our killer-takes rule should check who started the fight.
- **Give players a pre-committed safe slot.** Escape from Tarkov's secure containers guarantee their contents on death ([AFKGaming](https://afkgaming.com/esports/guide/everything-about-insurance-in-escape-from-tarkov)). A few cards that can never be taken would limit how much a death can wipe.
- **Expect the attacker to target value, not just kills.** EVE's insurance covers only the hull, and cargo is the main target ([EVE University](https://wiki.eveuniversity.org/Insurance)). Our rule should assume the rarest cards will be hunted first.
- **A death tax that hits PvP reads as punishment.** Sea of Thieves dropped its planned death cost after backlash, and Rare said it would not apply to PvP deaths ([SlashGear](https://www.slashgear.com/sea-of-thieves-drops-plans-for-death-tax-after-community-pushback-27524713)).
- **Cap repeat kills on the same player.** Blox Fruits flags suspicious kills and has a bounty system meant to stop farming friends and alts ([Blox Fruits Wiki](https://blox-fruits.fandom.com/wiki/Bounty_and_Honor_System)). Without a cap, one strong player can strip one victim repeatedly.
- **Make losses recoverable, not only final.** Dark Souls bloodstains let players recover lost souls if they reach the death spot without dying again ([Critical Video Game Studies](https://criticalvideogamestudies.com/dark-souls-difficulty-and-comfort-in-failure/)). Dropping cards on the ground for a short window is a similar idea.
- **Expect ganking of new players.** Deepwoken players complain about veterans griefing new characters, though no official data exists ([Rowatcher](https://rowatcher.com/news/deepwoken-inside-roblox-s-most-brutal-hardcore-rpg)). New accounts need a grace period.
- **Test loss aversion with real stakes.** A 2020 CHI Play study found stakes can feel smaller when the items are not the player's own ([Tomé et al.](https://hci.usask.ca/wp-content/cache/mendeley-file-cache/6eb59aeb-38be-37ad-950c-7c625cb4cce2.pdf)). Playtest whether cards feel like the player's own collection.

## How other games handle death loss

| Game | What you lose | What protects you | Lesson | URL |
|---|---|---|---|---|
| Albion Online | Everything in red/black zones; nothing in blue zones | Zone choice | Risk is chosen by location | [link](https://www.gamerevolution.com/guides/341481-albion-online-losing-items-upon-death-works-green-yellow-red-regions) |
| RuneScape (OSRS) | All items if skulled; up to four kept otherwise | Protect Item prayer keeps 1 item if skulled | Skulls track aggression | [link](https://oldschool.runescape.wiki/w/Skull_(status)) |
| Escape from Tarkov | Gear in raid; uninsured items | Secure containers, insurance | Pre-committed safe items | [link](https://afkgaming.com/esports/guide/everything-about-insurance-in-escape-from-tarkov) |
| EVE Online | Ship hull (insured or not), cargo | Insurance (hull only) | Cargo drives attacks | [link](https://wiki.eveuniversity.org/Insurance) |
| Sea of Thieves | Planned gold fee; dropped | None needed | Death taxes provoke backlash | [link](https://www.slashgear.com/sea-of-thieves-drops-plans-for-death-tax-after-community-pushback-27524713) |
| Dark Souls | Souls, recoverable at bloodstain | Reaching the bloodstain | Recoverable loss teaches | [link](https://criticalvideogamestudies.com/dark-souls-difficulty-and-comfort-in-failure/) |
| Deepwoken (Roblox) | Notes and gear; permadeath later | Redemption life | Ganking complaints | [link](https://rowatcher.com/news/deepwoken-inside-roblox-s-most-brutal-hardcore-rpg) |

## Griefing problems and fixes

| Problem | Fix | Game that uses it | URL |
|---|---|---|---|
| Repeat kills on one player or alt | Bounty and honor limits; flagging suspicious kills | Blox Fruits | [link](https://blox-fruits.fandom.com/wiki/Bounty_and_Honor_System) |
| Logging out to escape a fight | Combat timer that resets on each hit | Community Minecraft plugins; timers are bypassed in some games | [link](https://robertsspaceindustries.com/spectrum/community/SC/forum/50259/thread/combat-logging-timer-and-ejecting-and-backspacing) |
| Veterans killing new players | Grace period for new accounts | Torn (not Roblox) | [link](https://wiki.torn.com/wiki/New_Player_Protection) |
| PvP that spreads everywhere | Consent-based shards or zones | Ultima Online (Trammel) | [link](https://www.raphkoster.com/?p=46381) |
| Hunting the weak | Aggression penalty on attacker | RuneScape Wilderness | [link](https://oldschool.runescape.wiki/w/Skull_(status)) |

## Options for our rule

Each option is "killer takes N cards by rarity; the rest are lost." The numbers are placeholders to tune.

1. **Harsh.** Only loose cards are at risk. Killer takes 1 to 3 cards depending on rarity. Other loose cards are destroyed. Placed cards are safe.
   - Pros: clear stakes; simple to build.
   - Cons: strong quit risk; hard on young players; invites revenge loops.

2. **Middle.** Loose cards are at risk, and placed cards are safe. Killer takes 1 card of the victim's choosing from the bottom tiers, or a rarity-based count. Other cards are not destroyed: they drop as a recoverable pile at the death spot for a fixed window. The victim can reclaim them.
   - Pros: loss is real but recoverable, close to Dark Souls and Rust drops.
   - Cons: a pile on the ground can be camped; needs a timer and anti-camp rules.

3. **Gentle.** Only open-zone deaths count. New accounts have a 24-hour grace period. A repeat-kill cap applies per killer per victim. Killer takes at most one card. Everything else returns to the island.
   - Pros: low quit risk; fits young players; easier to defend in policy review.
   - Cons: weak stakes; collecting feels less meaningful.

Questions to decide: whether placed cards are safer than loose ones (recommended yes), and whether "lost" means destroyed, returned to the island, or dropped on the ground (recommend returned or recoverable, not destroyed).

## Roblox policy notes

- Roblox uses maturity labels (Minimal, Mild, Moderate, Restricted). Minimal and Mild are eligible for the younger age groups ([Roblox Create docs, search snippet](https://create.roblox.com/docs/production/promotion/content-maturity)). Confirm before we commit.
- Violence must be disclosed in the Maturity and Compliance Questionnaire. Realistic or excessive blood may be moderated regardless of label ([Roblox Help, search snippet](https://en.help.roblox.com/hc/articles/8862768451604)).
- Community Standards prohibit extreme or graphic violence and gore ([Roblox Community Standards, search snippet](https://about.roblox.com/en-nz/community-standards)). Keep PvP cartoonish, with no blood or realistic death.
- Maturity labels do not cover user-generated items. Check how trading works, in case cards are sold outside the game.

## Not confirmed

- Type Soul and Grand Piece Online PvP and bounty rules: no usable results.
- Booga Booga and Grand Piece Online safe zones or new-player protection: not found.
- Roblox rules on PvP death loss or item drops: not found.
- Rogue Lineage's "global restore" practice: only a fan wiki snippet, no link.
- Koster's exact wording and the claim that UO lost more players than EverQuest gained: not verified.
- Albion "orange zone": mentioned by one guide only.
- Blox Fruits 1v1 limit (3 kills per 3 days, 2019): old, possibly outdated.
- Whether Sea of Thieves has any death penalty today: not checked.
- Several pages could not be opened (create.roblox.com, raphkoster.com, gamedeveloper.com, oldschool.runescape.wiki, avclub.com). Their claims rest on search snippets; these hosts need network access to verify.
