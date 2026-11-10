# Fan implementations of the card-book game

Research status: 14 searches run. Most web page fetches failed (DNS blocked for the fandom wiki, itch.io, BuiltByBit, Siliconera and Chartopia), so most findings are from search snippets. The rules below come from a third-party mirror of the fan wiki and need checking against the official wiki before we rely on exact numbers. No Reddit threads on this topic were found.

## Key lessons

- **Copy caps lock out other players.** Per the wiki mirror, each item has a conversion cap, and higher-rank cards have lower caps. Once the cap is hit, nobody else can convert that item until a card is reverted or someone loses save data. Lesson: a global cap needs a defined release valve, or it becomes a permanent monopoly. ([wiki mirror](https://sonicgame.netlify.app/host-https-hunterxhunter.fandom.com/wiki/Greed_Island))
- **Random-target theft spells create a raid economy.** The fan wiki's Levy card steals a random card from every player within 20 meters, and a roll can improve the odds. Lesson: theft needs a radius, a cooldown, a per-target cap, and a clear counter. ([Levy card](https://hunterxhunter.fandom.com/wiki/Levy_(G.I_card)))
- **Information spells need limits.** The Steal/Peek card reveals the free slots of a player you have already met. Lesson: scouting should need proximity or a recent encounter. (Same source as above.)
- **Big clear rewards invite killing.** Viz notes that some players steal cards and kill rivals to chase the large reward. Lesson: the win reward must not make eliminating others the best path. ([Viz](https://www.viz.com/blog/posts/greed-island-arc))
- **Spells need an enchant step.** The manga requires spells to be enchanted before use. Lesson: a prep action gives spells a cost and a timing window. (Viz, same link.)
- **A co-op goal is a safer first version.** The 2022 board game *En Route Vers Greed Island* is cooperative, 1 to 4 players, about 30 to 45 minutes, with a rival who also wants the 100 cards. Lesson: a shared collection goal with one rival works without player-versus-player economy risks. ([BoardGameMatcher](https://boardgamematcher.com/game/hunter-x-hunter-en-route-vers-greed-island))
- **Card-for-card wagers need no economy.** A community Greed Island table has two players wager a card for a chance at the other's card. Lesson: a simple one-to-one wager is a low-risk trade mechanic. ([Chartopia contest chart](https://chartopia.d12dev.com/chart/9480/print))
- **Card-combat games need a live-service plan.** The 2018 mobile game *Greed Adventure* used cards that summon characters in battle. It was announced to end service in January 2020, about 13 months after launch. Lesson: a card economy tied to live service needs a long-term plan. ([ANN, launch](https://animenewsnetwork.com/daily-briefs/2018-12-06/hunter-x-hunter-greed-adventure-smartphone-game-launches-in-japan/.140450), [ANN, shutdown](https://admin.animenewsnetwork.com/news/2019-11-25/hunter-x-hunter-greed-adventure-smartphone-game-ends-service-on-january-14/.153655))
- **Prototype the binder before the world.** The Roblox "Greed" project is unfinished, and only its tutorial is playable. Lesson: test the binder and card loop in a small slice first. ([itch.io page](https://cb-1dev.itch.io/greed))

## Source rules summary

- **Goal:** Collect 100 specific Greed Island cards and fill the binder. The board game also uses 100 collection cards, though one listing gives 95 cards in the box, so the count is unclear. (Board game links above.)
- **Card limits:** Each item has a conversion cap. The mirror says caps range from over 100 down to 3, and higher ranks have lower caps. Exact per-rank values are not confirmed. Once a cap is reached, no one else can convert that item until a card is reverted or save data is lost. ([wiki mirror](https://sonicgame.netlify.app/host-https-hunterxhunter.fandom.com/wiki/Greed_Island))
- **Death and absence:** The story shows a player dying suddenly, and TV Tropes says death rules discouraged killing early on. How a dead player's cards are handled is not confirmed.
- **Monopolies:** Hoarding is a real threat in the story, and the cap is the main anti-monopoly rule.
- **Spells:** Theft (Levy), scouting (Steal/Peek) and tracking/contact spells exist. Spells must be enchanted first. No defensive or counter spell was confirmed.

## Implementations found

| Name | Platform | Binder / limits / spells / death | Outcome | URL |
|---|---|---|---|---|
| "Greed" | Roblox (itch.io page) | Unknown; tutorial playable | In development, unfinished | https://cb-1dev.itch.io/greed |
| Hunter x Craft | Minecraft mod (CurseForge) | 30 Nen abilities; Greed Island update planned | Status unknown | https://www.curseforge.com/minecraft/mc-mods/hunter-x-craft |
| Greed Island server interest check | Minecraft (BuiltByBit forum) | Competitive game mode proposed | Interest check only; no build found | https://builtbybit.com/threads/greed-island-server-interest-check.656789/ |
| Killua bot, Greed Island system | Discord (discord.py) | Hunt cards and monsters | Listing only; trading unconfirmed | https://discordbotlist.com/bots/killua/upvote |
| Hunter x Hangout | Discord community | Card-collecting bots, roughly 13k to 15k members | Active per listing | https://discord.com/servers/hunter-x-hangout-859205559412588544 |
| En Route Vers Greed Island | Board game (Cartamundi, 2022) | Co-op, 100 collection cards, rival | Sold; current availability unknown | https://www.analog.games/games/10b29322-7bb9-4b5e-b80b-91d1e53f8f75/hunter-x-hunter-en-route-vers-greed-island |
| Greed Adventure | Smartphone action RPG (Bandai Namco, 2018) | Cards summon characters in battle; multiplayer shown in trailer | Service ended January 14, 2020 | https://news.qoo-app.com/en/post/34423 |
| Greed Island contest tables | Tabletop RPG (Chartopia) | Card wagers; random contests | Community tool | https://chartopia.d12dev.com/chart/9480/print |

## Community opinions

- No Reddit threads on a Greed Island game were found in search. Searches returned only generic economy essays.
- General MMO economy view: rare items and currency get hoarded, and without enough sinks, value drifts. ([gamedepth](https://gamedepth.onrender.com/posts/why-do-mmorpg-economies-inflate-so-fast-in-2026)) This is a low-quality source, so treat it as a hint only.
- Some fan essays describe the island as a closed economy that rewards hoarding. These are unsourced and are not used as evidence.

## Not confirmed

- Reddit discussion of a Greed Island game (r/HunterXHunter, r/roblox, r/MMORPG, r/gameideas): not found.
- Official fandom rules and per-rank cap numbers: the official wiki could not be fetched, and the mirror is unverified.
- Death rules and what happens to a dead player's cards: not found.
- Whether a defensive or counter spell exists: not found.
- Current status of the Roblox "Greed" project, the Minecraft server idea, and Hunter x Craft: not verified.
- Greed Adventure multiplayer details: only the trailer headline was seen.
- Card count mismatch (95 in board game box vs 100 collection cards): unresolved.
- The "Gon's binder takes three cards" detail came from a search summary, not a page we could read.
