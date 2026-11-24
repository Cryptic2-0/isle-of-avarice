# Play-test checklist for milestone 7

Milestone 7 is the endgame. The Ledger now has 50 slots. Three Crown Relics sit at the top of it: the Gilded Sceptre (from the Gilded Bailiff), the Orb of Every Shore (the reward of The Grand Tally) and the Hoarder's Crown (a cache on the Throne). A player who claims every Relic is Crowned, with a ceremony on every screen, a title and a circlet. A Crowned player may Renounce at the Tally Stone in Tallyport to start again with a star. Health now comes back by itself, but only after a while out of danger.

Some steps need two players. Start a two-player test the same way as in `docs/playtest/M2-checklist.md`: open the Test tab, set the number of players to 2 and press Start. **A** is Player1 and **B** is Player2.

Automated run (2026-11-22, Studio, two players): `[PLAYTEST] DONE passed=706 failed=0`, with no errors from the game's scripts (the only warning is the board's data store, which an unpublished place cannot reach). 120 of those checks are for milestone 7.

The automated run stands in for the data store and the badge, and it hands out Relics with a script. The steps below are the hand checks for how things look, move and feel, and for the phone layout. The part that only a published game can show is at the end, under "On the published game".

## Words used here

- **Tally Stone**: the slab of dark grey stone in Tallyport, south of the plaza centre, with the title "The Crowned" on its face. Its board lists the players who have been Crowned.
- **Crowned**: you have claimed all 50 Relics. It happens once for each run of the Ledger.
- **Renounce**: give every card back to the island, at the Tally Stone, and earn a star.
- **Hold**: some caches open only if you keep E pressed until the bar fills.

## Steps

1. **The 50-slot book and the claim screen**
   - What to do: start a test and open the Ledger book. With two players, defeat B once (see `docs/playtest/M2-checklist.md`) so that A's claim screen opens.
   - What should happen: the book shows 50 numbered slots, three across, and "Relics: 0 / 50"; it scrolls to the rest. The claim screen shows the same 50 slots, ten across, and "Picks left: 5", and every number and name can be read.

2. **The Tally Stone and its board**
   - What to do: walk up to the Tally Stone in Tallyport and read its face.
   - What should happen: a large slab with the label "Tally Stone" over it. The face reads "The Crowned" and, under it, a grey line. Before anyone is Crowned the first row says "Nobody has been Crowned yet." The grey line says "All time, every server" when the saving is set up (see "On the published game"), or "This server only: the all-time records cannot be reached" when it is not. No prompt shows on the stone for a player who is not Crowned.

3. **New caches**
   - What to do: find a few of the new caches. The nearest to town are in the wild regions, far from any road: Copper caches at the edge of the blight in Cinder Flats, at the far end of Bastion Reach and deep in the Hush Gardens; a Silver cache at the dead end of the Thornwood maze; and a Silver cache on a stone stairway of six steps in the Cinder Flats.
   - What should happen: each pillar glows, and the cache opens with "You found ...!" (for example "Ash-Crusted Tally Bead", "Rampart Toll Token", "Pressed Blight-Leaf", "Hedge-Heart Locket" and "Cinder-Shelf Coffer"). They return after the usual wait for their tier.

4. **The Rock's second prize, with its hold**
   - What to do: cross the causeway to Reckoning Rock when the tide is low (see step 10 of `docs/playtest/World-checklist.md`). Stand beside the new cache on the Rock, press E and release it quickly, then press and hold E until the bar fills.
   - What should happen: pressing and releasing quickly does nothing: the prompt does not fire and no message shows. Holding E fills a bar over 3 seconds, and then "You found Tide-Turner's Hourglass!" appears. Letting go before the bar is full also does nothing. ("Hold the cache open until it is done." is only what a cheated request that skips the hold gets.)

5. **The Throne: a 10-second hold, and being knocked off it**
   - What to do: in the Drowned Fen, find the stone stairway of twelve steps, in three rows, on the north side (about 650 steps out and 230 to the side of the road). Climb to the top and hold E on the cache. With two players, let B stand below with Shield Bash (Bulwark) equipped, climb up beside A while A holds, and knock A off the ledge.
   - What should happen: the bar takes 10 seconds. If A is knocked off, the hold ends, nothing is given, and A has to climb again. If it completes, "You found The Hoarder's Crown!" appears. Only one copy of the Hoarder's Crown can be held on a server, so while one player holds it, the cache says "Sealed cache".

6. **The Gilded Bailiff**
   - What to do: with two players, walk out to the Cinder Flats, to the far end (about 820 steps out and 230 to the left of the road). Find the huge gold figure with a gavel. Both players fight it. Bring Mend or Bulwark abilities.
   - What should happen: the Bailiff has 2400 health and is the biggest beast on the island. Its Gavel Slam takes 30 health from anyone within 12 steps about every 3.5 seconds, and it lunges 20 steps with a 25-damage hit. Both players see "Gilded Bailiff defeated! +120 Coin." and both get the Coin. A player who dealt damage gets "You found The Gilded Sceptre!" (a sure drop) and sometimes "You found Bailiff's Gavel!" (30%). It returns after 20 minutes.

7. **Reed Run, The Bellows Dance, Spitter Season**
   - What to do: talk to each new Warden and finish its trial. The Reed Warden stands across the road from the Shell Warden at the Drowned Fen gate; the Bellows Warden stands a little further out than the Saltworks Warden at the Cinder Flats gate, and the Spitter Warden stands across the road from the Saltworks Warden.
   - What should happen: Reed Run: "Touch 6 markers in order.", 70 seconds, "Reward: 40 Coin, 170 XP", "Relic: Reed-Woven Wallet (Silver)"; the markers are along the boardwalks of the Fen. The Bellows Dance: "Touch 5 markers in order.", 50 seconds, "Reward: 90 Coin, 400 XP", "Relic: Bellows Ember-Key (Gold)"; the markers lie across the vent centres, so time your run to the vents. Spitter Season: "Defeat 3 Bogspitters.", 180 seconds, "Reward: 80 Coin, 380 XP", "Relic: Gilded Spittoon (Gold)". Each pass shows "You passed ...!" with the Coin and the Relic.

8. **The Grand Tally**
   - What to do: talk to the Crown Warden, who stands in Tallyport, near the Tally Stone. Accept The Grand Tally and run to all seven markers in order: one in every wild region, then Reckoning Rock.
   - What should happen: the window reads "The Grand Tally", "Crown Warden", "Touch 7 markers in order: one in every wild region, then Reckoning Rock.", "Time: 300 seconds", "Reward: 200 Coin, 900 XP" and "Relic: The Orb of Every Shore (Crown)". The trial HUD reads "The Grand Tally: marker 0 / 7". The last marker is on the Rock, so plan the tide. If another player already holds the Orb, the window adds "sealed on this server" to the Relic line and the Relic is not given (you still get the Coin and XP).

9. **The rounds line**
   - What to do: look at the trial HUD at the top right at any time, and pass a few Wardens' trials.
   - What should happen: the last line reads "Warden's Round 0 / 9, Beast Tally 0 / 5". Each trial you pass counts once in the Warden's Round (the first nine trials), and each kind of beast you defeat counts once in the Beast Tally (Brinehound, Shellback, Bogspitter, Brine Colossus and the Gilded Bailiff). After a step you see "The Warden's Round: 1 of 9 done." (or "The Beast Tally: 1 of 5 done."). Finishing a round shows "The Warden's Round complete! +250 Coin." (or "The Beast Tally complete! +250 Coin.") and gives a Platinum Relic: Wardens' Seal of Service or The Menagerie Ledger. The round then starts again.

10. **Being Crowned**
    - What to do: claim every one of the 50 Relics. For a quick check, use two players, collect the Relics by any means, and trade them to A, then claim the last one.
    - What should happen: on every screen a gold banner reads "<A's name> is Crowned!" and "Every Relic of the Ledger is claimed." for 6 seconds. Everyone also sees "<A's name> has claimed every Relic and is Crowned!". A sees "You are Crowned! Your name goes on the Tally Stone in Tallyport." A tall gold column of light stands over A for about 6 seconds. From then on a gold title "Crowned" hangs over A's head and a gilt circlet of six points sits on A's head. A's book says "Crowned. You may Renounce at the Tally Stone in Tallyport." The Tally Stone's board shows "1. <A's name>: Crowned". Taking one Relic out of the claimed slots and claiming it again does not give a second Crown.

11. **Renouncing**
    - What to do: as the Crowned A, stand in Tallyport near the Tally Stone, not Marked and with no fight in the last 30 seconds, and hold E on "Renounce" for 2 seconds. In the window, first type something wrong and look at "Renounce", then press "Keep my Ledger", then open the window again, type "renounce" (any case, spaces do not matter) and press "Renounce".
    - What should happen: the window "Renounce the Ledger?" lists five lines: every card goes back to the island, the Vault empties and the Unpaid Debt and the two rounds start again, you keep your Coin, Paths, abilities, trial cooldowns and Crowns, you earn a star, and "This cannot be undone." A countdown reads "Ends in 1:00". "Renounce" stays dimmed and does nothing until the box reads RENOUNCE (any case, spaces ignored), so a wrong word cannot be sent. "Keep my Ledger" shows "You kept your Ledger." and closes it. If you wait more than a minute and then press "Renounce" with the word typed, the window shows "That took too long. Start again at the Tally Stone." With the right word everyone sees "<A's name> has Renounced the Ledger and starts again." and A sees "You Renounced. Every card went back to the island, and you earned a star." A's book is empty ("Relics: 0 / 50"), the Coin is the same, and the title now reads "Crowned ★1" with one purple gem on the circlet. Claiming all 50 again gives "Crowned twice ★1" and the banner "<A's name> is Crowned again: 2 Crowns!".
    - Also try it where it should be refused: outside Tallyport "You can Renounce only in Tallyport."; with a trade open "Finish your trade first."; during a trial "Not during a trial."; while Marked "Not while you are Marked."; as a player who is not Crowned, the prompt does not show, and a hostile request would get "Only a Crowned Claimant with every Relic claimed can Renounce."

12. **Health comes back slowly**
    - What to do: take some damage (let a Brinehound bite you, or step in a hazard), then get away from danger and watch the health bar.
    - What should happen: for 10 seconds after your last loss nothing comes back. Then health returns by 1 a second. Any new hit starts the 10 seconds again. It also works in Tallyport.

13. **A title in the party panel**
    - What to do: with a Crowned A and B, form a party (see `docs/playtest/M6-checklist.md`).
    - What should happen: A's row on B's party panel has a gold line under the name, for example "Crowned twice ★1".

14. **On a phone**
    - What to do: in Studio, open the Test tab, choose Device and pick a phone. Open the 50-slot book, open a claim screen, open the Renounce window and look at a Crowning banner.
    - What should happen: the 50 slots scroll and their names can be read, the Renounce window fits and its typing box and both buttons can be tapped, and the banner fits at the top of the screen without covering the ability bar.

## On the published game

Studio cannot check these. They need the game published (see "How to publish" in the README).

1. **The board**
   - What to do: publish the game, join a live server, and stand at the Tally Stone in Tallyport. A Crowned player must be on the server or have been Crowned in another server.
   - What should happen: within a few minutes the grey line says "All time, every server" and the board lists the Crowned players, most Crowns first. "This server only: the all-time records cannot be reached" means the data store cannot be reached.

2. **The badge**
   - What to do: after setting the badge's number in LaunchConfig, get Crowned for the first time on the live game.
   - What should happen: Roblox shows the "Crowned" badge once. It does not show again on a second Crown or after leaving and coming back.

3. **The Crown record survives a rejoin**
   - What to do: after being Crowned (and Renouncing once, if you like), leave the game and join again.
   - What should happen: the title and circlet are back on your character, the book shows the same Crown line, and the Tally Stone's board still lists you.

If any step fails, copy the red text from the Output window and send it back.
