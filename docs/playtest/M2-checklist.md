# Play-test checklist for milestone 2

Milestone 2 adds fighting. Every step needs two players.

## How to start a two-player test

1. Open the Test tab at the top of Studio.
2. Find the Clients and Servers section. Set the number of players to 2.
3. Press Start.

Studio opens three new windows: one server window and one window for each player. The players are called Player1 and Player2 in Studio. Below, **A** is Player1 and **B** is Player2. Click inside a player's window to control that player.

Studio's menus change between versions. If you cannot find these options, look for a multi-player or multi-client test option.

## Words used here

- **Strike**: the basic attack. Click the left mouse button or press F. On a phone, tap the "Strike" button.
- **Tallyport** is the stone plaza where you spawn. A pale gold circle on the ground marks it. Nobody can fight inside it.
- **Status lines** appear at the top left of the screen: "Safe zone" in green, shields in blue, "MARKED" in red.
- Messages appear at the top of the screen and disappear after about 3 seconds.
- The Output window is the log inside Studio. Open it with View, then Output.

## Steps

1. **Start**
   - What to do: start a two-player test.
   - What should happen: both players spawn in Tallyport. Each sees "Safe zone" and "New-player shield" at the top left, and a shimmer around their character. For the first minute each also sees "Respawn shield" counting down from 60s. No red text in the Output window.

2. **A shielded player cannot attack**
   - What to do: as A, walk up to B and Strike while facing B.
   - What should happen: A sees "You are shielded. Drop your shield to fight." B takes no damage.

3. **Drop the shield**
   - What to do: as A, press "Drop shield" at the top left, then press "Yes". Then Strike B, still in town.
   - What should happen: after "Yes", A sees "Your new-player shield has ended. Other players can now attack you." and "New-player shield" disappears from A's status lines. The Strike on B gives "That player is shielded." because B still has the new-player shield.

4. **The shield ends by itself at 3 Relics**
   - What to do: as B, open caches until you hold 3 Relics. Spare copies count.
   - What should happen: on the third, B sees "Your new-player shield has ended. Other players can now attack you." The shimmer around B disappears.

5. **Start a fight**
   - What to do: take both players outside the gold circle. As A, face B and Strike once.
   - What should happen: B's health bar drops by about a fifth. B flashes white. A sees "You started a fight. You are Marked for 5 minutes." A red "MARKED" tag appears over A's head, and A's status lines show "MARKED" counting down from 5:00.

6. **Hitting back does not Mark you**
   - What to do: as B, Strike A straight away.
   - What should happen: A takes damage. B is not Marked: no red tag over B and no "MARKED" line for B.

7. **A Marked player is not safe in town**
   - What to do: walk A into Tallyport while A is still Marked. Have B follow and Strike A there. Then, as A, Strike B inside town.
   - What should happen: B's Strike on A works. A's Strike on B gives "No fighting in Tallyport."

8. **Defeat**
   - What to do: take both players outside town again. As A, Strike B until B is defeated. That takes about 5 Strikes. Wait about a second between Strikes; faster clicks are ignored.
   - What should happen: A sees "You defeated Player2. Make your claim." and a screen titled "Claim on Player2" with 12 numbered slots, "Picks left: 5" and a countdown from 30s. B respawns in Tallyport and sees "Player1 defeated you and is making a claim on your Ledger."

9. **The victim's Ledger is locked**
   - What to do: while A's claim screen is still open, as B, open the Ledger (press B) and press "Discard" next to a spare card.
   - What should happen: B sees "Your Ledger is locked while a claim is made against you." The card stays.

10. **Make picks**
    - What to do: as A, click a slot for a Relic you know B holds. Then click a slot for a Relic B does not hold.
    - What should happen: the first gives "You took …!" with the Relic's name, the slot shows "Taken!", and the Relic appears in A's free slots. The second gives "Nothing there." and the slot shows "Nothing". "Picks left" goes down by one each time.

11. **The claim ends**
    - What to do: use all 5 picks, or wait for the countdown to reach 0.
    - What should happen: A's claim screen closes and A sees "The claim is over." B sees "Player1 took from you: …" with the names of the Relics taken, or "Player1 took nothing from you." B can now discard cards again.

12. **Respawn shield**
    - What to do: right after B respawns, as A, Strike B.
    - What should happen: B's status lines show "Respawn shield" counting down from 60s. A sees "That player is shielded." until the countdown ends.

13. **One claim per hour on the same player**
    - What to do: after B's respawn shield ends, defeat B again outside town.
    - What should happen: no claim screen opens. A sees "You defeated Player2, but you already claimed from them in the last hour."

14. **The Vault**
    - What to do: as B, stand in Tallyport, open the Ledger and press the small "Vault" button on a slot you hold. Then walk out of town and press "Vaulted" on the same slot.
    - What should happen: in town, B sees "… is now in your Vault.", the button reads "Vaulted" and the slot gets a gold outline. The top of the book shows "Vault: 1 / 3". Outside town, B sees "You can change your Vault only in Tallyport." and the Relic stays in the Vault.
    - Extra check: start a new two-player test with the roles swapped, so the hour limit from step 13 does not apply. As B, Vault a Relic, then let A defeat B and pick that Relic's slot. A sees "Nothing there." and B keeps the Relic.

15. **Leaving during a fight**
    - What to do: start a new two-player test. Both players press "Drop shield", then "Yes". Wait until "Respawn shield" has gone from both players' status lines (one minute). Take both players outside town. As A, Strike B once. Within 30 seconds of that hit, close B's window.
    - What should happen: A gets the claim screen for B, the same as for a defeat.

16. **Too many copies on one server** (optional: it takes about 20 minutes, because the platinum cache refills only every 10 minutes)
    - What to do: as A, collect "The Hoarder's Thumbprint". It is the platinum cache with the pale white-blue pillar, in the keep of Bastion Reach (steps 12 to 14 of `docs/playtest/World-checklist.md` show the way). It takes 4 seconds to open. Ten minutes later, as B, collect it too. Then wait for the cache to refill and try to open it again with either player.
    - What should happen: once two copies are held, the pillar stops glowing and the cache prompt reads "Sealed cache". The third attempt gives "The island has sealed this Relic. Too many are already held here."

If any step fails, copy the red text from the Output window and send it back.
