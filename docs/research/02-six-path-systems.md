# Six-path affinity systems

## Key lessons

- **Make the limit the source of power.** In Nen, a stricter self-imposed vow makes the ability stronger, and breaking it has a cost. Build our "off-path" penalty and our "strong-but-restricted" abilities as one mechanic. Source: [Epic Stream on Gon's vow](https://epicstream.com/article/will-gon-get-his-nen-back-in-hunter-x-hunter) (search snippet; the page was not fetched).
- **Count progress by a rule that favors focus.** Oblivion's original level-up counted only Major skills, and its skill multiplier tiers rewarded focused training. Off-path progress should be real but slower, not invisible. Source: [UESP Oblivion Efficient Leveling](https://content1.uesp.net/wiki/Oblivion:Efficient_Leveling) (search snippet).
- **Let every path reach everything, but charge by distance.** Path of Exile uses one shared tree; the class sets the start point, and you can reach any node with enough points. Cost is points spent, not a hard lock. Source: [PoE Passive skill wiki](https://pathofexile.fandom.com/wiki/Passive_skill) and [Vulkk PoE 2 tree guide](https://vulkk.com/2025/02/08/path-of-exile-2-passive-tree-guide/).
- **Starting position matters more than access.** FFX put all characters on one grid, and the default layout made play feel linear. Players disliked it, and the Expert grid starting in the middle helped. Our starting nodes or first-learn bonuses should be designed, not left to chance. Source: [GameSkinny, FFX Standard vs Expert grid](https://www.gameskinny.com/tips/final-fantasy-x-standard-sphere-grid-vs-expert-sphere-grid/) and [Shamus Young on the FFX sphere grid](https://www.shamusyoung.com/twentysidedtale/?p=33974).
- **Use a counter as a bias, not a hard rule.** RuneScape's combat triangle gives an edge in armour and reach, but the wiki says it does not decide a fight. Source: [OSRS Wiki, Combat Triangle](https://oldschool.runescape.wiki/w/Combat_Triangle).
- **Watch for one "best" path.** A fan d20 homebrew calls Enhancement the best balance of offense and defense. Treat that as a warning sign to test in PvP, not as data. Source: [GiantITP d20 Nen homebrew thread](https://forums.giantitp.com/archive/index.php/t-503437.html) (search snippet; the page was not fetched).
- **Paid rerolls need disclosed odds.** Roblox's paid random items policy requires numerical odds for randomized items bought with Robux or in-game currency, including indirect purchases. Source: [Roblox Creator Hub, Paid random items](https://create.roblox.com/docs/en-us/production/monetization/paid-random-items) (search snippet; the page could not be fetched).
- **Reroll-for-type is a common fan-game pattern.** Several Roblox Nen games sell or give rerolls through codes and in-game currency. Source: [Pocket Tactics, Eternal Nen codes](https://www.pockettactics.com/eternal-nen/codes) and [ProGameGuides, Ryoshi codes](https://progameguides.com/roblox/ryoshi-codes/).
- **Respec and balance tests need to be cheap to run.** Deepwoken's attunement system uses investment thresholds and a community warning that low investment in key stats hurts damage. Source: [LDPlayer Deepwoken build guide](https://www.ldplayer.net/blog/roblox-deepwoken-build-guide.html) (search snippet; off-attunement cost was not confirmed).

## Source structure summary

- **Categories:** Six: Enhancement, Transmutation, Emission, Conjuration, Manipulation, Specialization. Most sources agree. One German guide uses "Materialization" for the fourth; I did not confirm which name the official chart uses. Source: [Sportskeeda, Nen overview](https://www.sportskeeda.com/anime/i-don-t-think-hunter-x-hunter-commended-enough-power-system-needs-change) (search snippet).
- **Hexagon and efficiency:** Own type 100%, adjacent 80%, the two next 60%, opposite 40%. Only the 80% and 40% values appear in several sources; the 60% figure comes from one source (Sportskeeda). I did not verify it against Togashi's chart.
- **Type assignment:** A water divination test. Sources agree on some results (Manipulator, Transmuter, Conjurer, Specialist) and conflict on Emitter and Enhancer. Source: [Beebom Nen chart explainer](https://beebom.com/hunter-x-hunter-nen-chart-explained/amp/) (search snippet).
- **Conditions and limits:** Vows (also called restrictions) are self-imposed rules. The stricter the rule, the stronger the ability. Breaking a vow carries a serious cost.

## How fan games did it

| Game | Platform | How type is assigned | Off-type leveling | Known complaints | URL |
|---|---|---|---|---|---|
| Hunter Era | Roblox | Reroll at Nen Master NPC; spins limited, extra spins from codes or in-game currency | Not confirmed | Not found in search | [DroidGamers guide](https://www.droidgamers.com/guides/hunter-era-nen-guide/) |
| Ryoshi | Roblox | Codes grant Nen type rerolls | Not confirmed | Not found | [ProGameGuides](https://progameguides.com/roblox/ryoshi-codes/) |
| Eternal Nen | Roblox | Codes change Nen, clan, and color | Not confirmed | Not found | [Pocket Tactics](https://www.pockettactics.com/eternal-nen/codes) |
| Hunter x Anomaly | Roblox | Codes grant clan and Hatsu rerolls | Not confirmed | Not found | [Pocket Tactics](https://www.pockettactics.com/hunter-x-anomaly/codes) |
| d20 Nen Aura homebrew (2016 draft) | Tabletop | Affinity by distance on the hexagon (100/80/60/40) | Affinity percentages only | Author calls it bare-bones | [GiantITP](https://forums.giantitp.com/archive/index.php/t-503437.html) |

## Comparable systems in other games

| Game | Mechanic | Lesson | URL |
|---|---|---|---|
| Path of Exile | Shared tree; class sets start | Access is open; distance is the cost | [PoE wiki](https://pathofexile.fandom.com/wiki/Passive_skill) |
| Final Fantasy X | Shared sphere grid | Default layout caused linearity; starting setup matters | [Shamus Young](https://www.shamusyoung.com/twentysidedtale/?p=33974) |
| Elder Scrolls (Morrowind, Oblivion) | Major/minor skills drive level | Counting rules shape focus | [UESP Morrowind:Level](https://en.uesp.net/wiki/Morrowind:Level) |
| RuneScape | Melee/ranged/magic triangle | Counter is a bias, not a lock | [OSRS Wiki](https://oldschool.runescape.wiki/w/Combat_Triangle) |
| Deepwoken (Roblox) | Attunements with investment thresholds | Neglecting a stat hurts; thresholds gate upgrades | [Deepwoken Fandom](https://deepwoken.fandom.com/wiki/Attributes_Unbound) |

## Design options for us

1. **XP multiplier on off-path progress (e.g. 100/80/60/40%).**
   - Pros: simple to explain, keeps every path open, easy to tune.
   - Cons: players may ignore far paths, so those paths are dead in PvP unless the payoff is strong.
2. **Level cap on off-path abilities.**
   - Pros: clear rule, keeps natural paths strong.
   - Cons: punitive feel; a capped path may still be useless in PvP.
3. **Skill slot cost for off-path abilities.**
   - Pros: makes loadout choices matter in PvP, ties to the "limit equals power" idea.
   - Cons: adds UI and slot scarcity; needs a respec rule so players can change path.

## Not confirmed

- **Blocked sites:** The Roblox Creator Hub page, the GiantITP thread, and the Beebom article could not be fetched because the session network did not resolve those hosts. Add `create.roblox.com`, `forums.giantitp.com`, and `beebom.com` to the session's allowed domains to verify them.
- **Reddit complaints:** I found no r/HunterXHunter, r/gamedesign, or r/RPGdesign threads on reroll gambling or type balance. The claims about reroll anger are unverified.
- **Off-type leveling in Roblox games:** Not found for any game.
- **Deepwoken off-attunement cost:** Not found.
- **Oblivion Remastered leveling:** Sources conflict on whether Minor skills count.
- **Type assignment:** Water divination mappings for Emitter and Enhancer conflict across sources.
- **Killua and Machi as midpoint users:** From one Reddit snippet only.
- **Roblox UK under-18 restriction on paid random items:** Seen in a forum post; not checked against official sources.
