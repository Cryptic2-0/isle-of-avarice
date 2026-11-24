# Isle of Avarice

Isle of Avarice is an original multiplayer game for Roblox. You explore an island, open caches and collect Relics left behind by the Hoarder.

Your Ledger is a book with 50 numbered slots. Each Relic you claim fills one slot. Your goal is to fill the whole Ledger.

## What is in the game now

- **Milestone 1, the Ledger:** walk the island, open caches, collect Relics and claim them into your saved Ledger.
- **Milestone 2, combat and defeat:** fight other players with a basic Strike. When you defeat someone, you get a short blind claim: you pick numbered slots and take the Relics they hold there. Protections keep this fair: a shield for new players and after each respawn, no fighting in Tallyport, a red "MARKED" tag on whoever starts a fight, one claim per hour on the same player, and a Vault that keeps up to 3 of your Relics safe. If too many copies of a rare Relic are held on one server, its cache is sealed.
- **Milestone 3, the Six Paths:** choose one of six Paths (Fang, Gale, Ember, Mire, Mend, Bulwark) as your Calling. Every Path levels up on its own, from hits on training posts and from winning fights; your Calling learns fastest and the opposite Path slowest. Each Path teaches 3 abilities, at levels 3, 10 and 18. Equip up to 4 in Tallyport and use them with the keys 1 to 4 or the ability bar. The Paths panel (press P) shows your levels and lets you change your Calling: free the first time, then 500 Coin, with a 7-day wait after each change.
- **Milestone 4, creatures and trials:** beasts live at dens in the wild regions. They fight back, and defeating one pays Coin, Path XP and sometimes a Relic to everyone who helped. Six Wardens, one at each region's gate, offer timed trials: two courses, a delivery, two hunts and a private duel. Three trials and the Brine Colossus make up a quest, The Unpaid Debt. Relics 13 to 30 come from trials, creatures, the quest and hard-to-reach caches.
- **Milestone 5, Edicts and trading:** five single-use Edict cards (Summons, Audit, Veil, Passage, Homecoming) live in your free slots. The clerk of the Edict Hall in Tallyport sells packs of Edicts and Copper Relics and buys spare cards. Two players standing close can trade cards and Coin, with a short wait before either can confirm. A defeat destroys a third of the Edicts you hold (never Relics).
- **Milestone 6, parties:** up to four players can form a party (the "Party" button asks the nearest player). Allies cannot hurt each other, heals and shields from Mend abilities reach them, and a player who supports an ally against a creature shares in its reward. A panel shows each member's health and a green marker hangs over each ally.
- **Milestone 7, the endgame:** the Ledger has 50 Relics. Three Crown Relics sit at the top: the Gilded Sceptre (from the Gilded Bailiff), the Orb of Every Shore (the reward of The Grand Tally) and the Hoarder's Crown (a cache on the Throne, opened by a 10-second hold). A player who claims every Relic is Crowned, with a ceremony on every screen, a title and a gilt circlet. The all-time board of the Crowned stands on the Tally Stone in Tallyport. A Crowned player may Renounce there, give every card back and earn a star. Health comes back slowly, but only after 10 seconds out of danger.

## How to play-test

You need Roblox Studio. It is the free program Roblox provides for making and testing games.

1. Open the game file on GitHub: https://github.com/Cryptic2-0/isle-of-avarice/blob/main/dist/IsleOfAvarice.rbxlx
2. Click the "Download raw file" button. Save the file on your computer.
3. Open Roblox Studio. Choose File, then Open from File, and pick the file you saved.
4. Press the Play button at the top of Studio.
5. Follow the steps in `docs/playtest/M1-checklist.md` (the Ledger), then `docs/playtest/M2-checklist.md` (combat, which needs two players), then `docs/playtest/M3-checklist.md` (the Six Paths, mostly two players). Each lists what to do and what should happen.
6. Then follow the steps in `docs/playtest/World-checklist.md` (the nine regions of the wide island and their hazards, partly with two players).
7. Then follow the steps in `docs/playtest/M4-checklist.md` (creatures and trials, partly with two players).
8. Then follow the steps in `docs/playtest/M5-checklist.md` (Edicts, the shop and trading, mostly with two players).
9. Then follow the steps in `docs/playtest/M6-checklist.md` (parties, with two players).
10. Then follow the steps in `docs/playtest/M7-checklist.md` (the endgame: the 50-slot Ledger, Crowning, the Tally Stone and Renouncing, mostly with two players).

If a step fails, see the last line of the checklist.

## How to publish

You do this once, as the owner of the game. Until you publish, progress resets every time you press Play.

1. Open the game in Studio. Choose File, then Publish to Roblox. Keep it private for now.
2. Choose Home, then Game Settings, then Security, and turn on "Enable Studio Access to API Services". Click Save. (Live servers save without this; it lets saving and the board work when you press Play in Studio.)
3. Create the badge on the Creator Dashboard (create.roblox.com): open your experience, find Badges (under Associated Items or Engagement), choose Create a Badge, name it "Crowned", describe it as "Claimed every Relic of the Hoarder's Ledger.", and upload a square image. Roblox may ask for Robux beyond a small free allowance of badges; read the page before you confirm. Copy the badge's number (its id).
4. In Studio, open ServerScriptService, then Server, then LaunchConfig, and replace the 0 after `CROWNED_BADGE_ID =` with the id. Publish again. Tell the developer the id so `src/server/LaunchConfig.luau` keeps it in the next build.
5. Before making the game public, fill in the experience questionnaire (content maturity) and the description in Game Settings, then set the game to Public.
6. Check: in a live server, the Tally Stone in Tallyport should say "All time, every server" within a few minutes. "This server only" means the data store cannot be reached (step 2, or a Roblox outage).

## For developers

The rest of this page is for people who write code.

- Install the tools: `rokit install`
- Run all checks (format, lint, build, tests): `bash scripts/check.sh`
- Live-sync into Studio: `rojo serve`
- Automated two-player play test: `rojo build playtest.project.json -o build/playtest.rbxl`, open that file in Studio, choose Test, then Server & Clients, set 2 players and press Play. The script in `playtest/` drives both players through the M1, M2, M3, M4, M5, M6 and M7 checklists and the world checks, and prints `[PLAYTEST] PASS` or `FAIL` lines to the Output window, ending with a `DONE` summary. This build is for testing only; never copy it to `dist/`.

The playable file in `dist/IsleOfAvarice.rbxlx` is a copy of `build/IsleOfAvarice.rbxlx`. Copy it again after any code change, once the checks pass.

### Layout of `src/`

- `src/shared/` is code that has no Roblox calls. It holds the game rules and the lists of Relics, tiers and messages. The tests run it outside Roblox.
- `src/server/` is code that runs on the server. It decides everything: saving, caches, the world, combat, shields, claims, Paths and abilities.
- `src/client/` is code that runs on each player's computer. It draws the Ledger, the status lines, the claim screen, the Paths panel and the ability bar, and sends requests to the server.
- `tests/` holds the tests for the shared rules.

## Credits

Saving uses ProfileStore by loleris (Apache-2.0 licence). It is included under `src/server/Vendor/`.
