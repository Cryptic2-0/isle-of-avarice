# Isle of Avarice

Isle of Avarice is an original multiplayer game for Roblox. You explore an island, open caches and collect Relics left behind by the Hoarder.

Your Ledger is a book with 12 numbered slots. Each Relic you claim fills one slot. Your goal is to fill the whole Ledger.

## How to play-test

You need Roblox Studio. It is the free program Roblox provides for making and testing games.

1. Open this file on GitHub: https://github.com/Cryptic2-0/isle-of-avarice/blob/main/dist/IsleOfAvarice.rbxlx
2. Click the "Download raw file" button. Save the file on your computer.
3. Open Roblox Studio. Choose File, then Open from File, and pick the file you saved.
4. Press the Play button at the top of Studio.
5. Follow the steps in `docs/playtest/M1-checklist.md`. It lists what to do and what should happen.

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

The playable file in `dist/IsleOfAvarice.rbxlx` is a copy of `build/IsleOfAvarice.rbxlx`. Copy it again after any code change, once the checks pass.

### Layout of `src/`

- `src/shared/` is code that has no Roblox calls. It holds the game rules and the lists of Relics, tiers and messages. The tests run it outside Roblox.
- `src/server/` is code that runs on the server. It decides everything: saving, caches and the world.
- `src/client/` is code that runs on each player's computer. It draws the Ledger and sends requests to the server.
- `tests/` holds the tests for the shared rules.

## Credits

Saving uses ProfileStore by loleris (Apache-2.0 licence). It is included under `src/server/Vendor/`.
