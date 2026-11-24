# Play-test checklist for milestone 8

Milestone 8 is launch polish. The game now fits a phone. The Ledger, Paths, Trade and Party buttons sit in one row above the ability bar. Every window has a smallest size so that it fits a small screen. A claimed slot is unclaimed, and a free card discarded, with two taps. The region name has its own line. The blighted ground in the Hush Gardens has a tint.

Some steps need two players. Start a two-player test the same way as in `docs/playtest/M2-checklist.md`: open the Test tab, set the number of players to 2 and press Start. **A** is Player1 and **B** is Player2.

Automated run: not done yet.

The automated run taps the game's own buttons and checks where every control sits, but it runs in a desktop window. It cannot show a phone. The steps below are the hand checks for how things look and feel, and for the phone layout. The last part, "On a real phone", needs the published game.

## Words used here

- **Menu row**: the four buttons "Ledger", "Paths", "Trade" and "Party" in a row just above the ability bar at the bottom of the screen.
- **Thumbstick area**: on a phone, the bottom left of the screen, where the thumb steers the character.
- **Two taps**: the first tap only asks "are you sure?" and the button turns red; the second tap, within 3 seconds, does it.

## Steps

1. **The menu row**
   - What to do: start a test (on a computer first). Look at the bottom of the screen. Press each of the four buttons, and press B and then P on the keyboard.
   - What should happen: four buttons, "Ledger", "Paths", "Trade" and "Party", stand in a row directly above the four ability slots, with no other buttons for these in the corners. "Ledger" opens the book and "Paths" opens the Paths panel; pressing the same button again closes it. B and P still open and close the same two windows. With a second player standing close, "Trade" asks that player to trade and "Party" asks that player to join a party (see `docs/playtest/M5-checklist.md` and `docs/playtest/M6-checklist.md`).

2. **The HUD on a phone**
   - What to do: in Studio choose the Test tab, then Device, and pick a phone in landscape (for example one 640 by 360, or "iPhone SE"). Start a test.
   - What should happen: the thumbstick area at the bottom left has no button on it. The jump button at the bottom right is clear. The menu row and the ability bar sit between them, and all four menu buttons can be read. The trial HUD and the party panel at the top right do not cover the menu row (start a trial, and with a second player form a party, to see both).

3. **Every window on the phone**
   - What to do: on the same phone, open each of these in turn and close it again: the Ledger book; the claim screen (defeat B, see `docs/playtest/M2-checklist.md`); the Edict Hall (hold E at the clerk, see `docs/playtest/M5-checklist.md`); a trade; the Paths panel and the Calling picker; the Summons picker (use a Summons card from the free slots); a trial offer (talk to a Warden); the Renounce window (see `docs/playtest/M7-checklist.md`); and the window that asks "Other players will be able to attack you. Drop it?" (press "Drop shield" while the new-player shield is on).
   - What should happen: each window fits the screen, its buttons can be tapped with a thumb and its text can be read. The claim screen shows every number and name. No window is cut off at an edge or hidden behind the menu row.
   - Also: open the Ledger during a trial, in a party. The "X" and every Claim and Discard button are visible and work: the quest lines, the Coin line and the party panel are drawn under the window, not over it.

4. **Two taps to unclaim**
   - What to do: in the Ledger book, tap a claimed slot once, and look at it. Tap it again within 3 seconds. Then tap another claimed slot once and wait 3 seconds.
   - What should happen: the first tap turns the slot red and it reads "Tap again to unclaim". The second tap unclaims it: "<name> moved to your free slots." shows and the card appears among the free slots. A slot that is tapped once and then left for 3 seconds goes back to its normal colour and name, and nothing is unclaimed.

5. **Two taps to discard**
   - What to do: with a card in the free slots, tap its "Discard" button once, and look at it. Tap it again within 3 seconds. Try it again on another card and wait 3 seconds.
   - What should happen: the first tap turns the button red and it reads "Sure?". The second tap shows "<name> discarded." and the card is gone. Left for 3 seconds, the button goes back to "Discard" and the card stays.

6. **Buttons dim for a moment after a tap**
   - What to do: tap "Claim" on a free card, or "Vault" on a claimed slot, and look at the buttons right away.
   - What should happen: the buttons of that row turn pale for a moment and ignore taps, so a second tap cannot send the same request twice. They come back when the book updates. If the game refuses the request (for example a locked Ledger during a claim against you: "Your Ledger is locked while a claim is made against you."), they come back after about 1 second.

7. **No thin dark borders**
   - What to do: open every window and look at the edges of the buttons, labels and rows.
   - What should happen: there are no thin dark outlines anywhere. Buttons and panels have soft rounded corners and nothing else around them.

8. **The region banner**
   - What to do: walk from Tallyport out into a wild region, for example along the Thornwood road. While you cross the border, make a message show at the same time (for example press Trade with nobody close).
   - What should happen: the message stays at the top, and the region name and hint show in their own line just under it, for example "Thornwood: A hedge maze. Briars are a shortcut that costs health." The banner stays about 3 seconds. The message is not replaced by the banner, and the banner does not wait behind the message.

9. **The blight tint**
   - What to do: walk into the Hush Gardens along its road and keep going. Watch the ground and the status lines at the top left.
   - What should happen: the ground turns purple-grey where the status line begins to say "Blight", and not before. It stays tinted everywhere the blight drains you. The tint can be seen from a distance. Walking over it does nothing by itself.

10. **A long name in the party panel**
    - What to do: with two players in a party, give one of them a long display name, or use a long name from the start. Look at that player's row on the other player's party panel.
    - What should happen: the name ends in "…" at the right edge of its row. It is never made smaller to fit and never runs over the health numbers.

## On a real phone

This needs the published game (see "How to publish" in the README). Do the same checks once on the owner's phone: steps 1 to 10 above, with the real thumbstick and jump button. Look in particular at step 2 (nothing under the thumb or the jump button), step 3 (every window fits and every button can be tapped) and steps 4 and 5 (two taps feel right with a thumb).

If any step fails, copy the red text from the Output window and send it back.
