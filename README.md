# Isle of Avarice

Isle of Avarice is an original multiplayer game for Roblox. You explore an island, open caches and collect Relics left behind by the Hoarder.

Your Ledger is a book with 12 numbered slots. Each Relic you claim fills one slot. Your goal is to fill the whole Ledger.

## What is in the game now

- **Milestone 1, the Ledger:** walk the island, open caches, collect 12 Relics and claim them into your saved Ledger.
- **Milestone 2, combat and defeat:** fight other players with a basic Strike. When you defeat someone, you get a short blind claim: you pick numbered slots and take the Relics they hold there. Protections keep this fair: a shield for new players and after each respawn, no fighting in Tallyport, a red "MARKED" tag on whoever starts a fight, one claim per hour on the same player, and a Vault that keeps up to 3 of your Relics safe. If too many copies of a rare Relic are held on one server, its cache is sealed.
- **Milestone 3, the Six Paths:** choose one of six Paths (Fang, Gale, Ember, Mire, Mend, Bulwark) as your Calling. Every Path levels up on its own, from hits on training posts and from winning fights; your Calling learns fastest and the opposite Path slowest. Each Path teaches 3 abilities, at levels 3, 10 and 18. Equip up to 4 in Tallyport and use them with the keys 1 to 4 or the ability bar. The Paths panel (press P) shows your levels and lets you change your Calling: free the first time, then 500 Coin, with a 7-day wait after each change.

## How to play-test

You need Roblox Studio. It is the free program Roblox provides for making and testing games.

1. Open the game file on GitHub: https://github.com/Cryptic2-0/isle-of-avarice/blob/main/dist/IsleOfAvarice.rbxlx
2. Click the "Download raw file" button. Save the file on your computer.
3. Open Roblox Studio. Choose File, then Open from File, and pick the file you saved.
4. Press the Play button at the top of Studio.
5. Follow the steps in `docs/playtest/M1-checklist.md` (the Ledger), then `docs/playtest/M2-checklist.md` (combat, which needs two players), then `docs/playtest/M3-checklist.md` (the Six Paths, mostly two players). Each lists what to do and what should happen.
6. Then follow the steps in `docs/playtest/World-checklist.md` (the nine regions of the wide island and their hazards, partly with two players).

If a step fails, see the last line of the checklist.

## How to make saving work

Without this, your progress resets every time you press Play.

1. In Studio, publish the place to Roblox. Choose File, then Publish to Roblox. Keep it private.
2. Choose Home, then Game Settings, then Security.
3. Turn on "Enable Studio Access to API Services".
4. Click Save.

Now your Ledger is kept between play sessions.

## For developers

The rest of this page is for people who write code.

- Install the tools: `rokit install`
- Run all checks (format, lint, build, tests): `bash scripts/check.sh`
- Live-sync into Studio: `rojo serve`
- Automated two-player play test: `rojo build playtest.project.json -o build/playtest.rbxl`, open that file in Studio, choose Test, then Server & Clients, set 2 players and press Play. The script in `playtest/` drives both players through the M1, M2 and M3 checklists and the world checks, and prints `[PLAYTEST] PASS` or `FAIL` lines to the Output window, ending with a `DONE` summary. This build is for testing only; never copy it to `dist/`.

The playable file in `dist/IsleOfAvarice.rbxlx` is a copy of `build/IsleOfAvarice.rbxlx`. Copy it again after any code change, once the checks pass.

### Layout of `src/`

- `src/shared/` is code that has no Roblox calls. It holds the game rules and the lists of Relics, tiers and messages. The tests run it outside Roblox.
- `src/server/` is code that runs on the server. It decides everything: saving, caches, the world, combat, shields, claims, Paths and abilities.
- `src/client/` is code that runs on each player's computer. It draws the Ledger, the status lines, the claim screen, the Paths panel and the ability bar, and sends requests to the server.
- `tests/` holds the tests for the shared rules.

## Credits

Saving uses ProfileStore by loleris (Apache-2.0 licence). It is included under `src/server/Vendor/`.
