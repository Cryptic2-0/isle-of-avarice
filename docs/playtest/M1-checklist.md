# Play-test checklist for milestone 1

Do the steps in order. For each one, "What to do" is your action and "What should happen" is the right result.

Words used here:
- The Output window is the log inside Studio. Open it with View, then Output.
- A cache is a small glowing box on the ground with a tall glowing pillar next to it. You open it to get a Relic card.
- Spares are extra cards you hold but have not placed in a slot. The game calls them free slots.

Pillar colours show how rare a Relic is: copper (brown-orange) is common, silver is grey, gold is yellow, and platinum is pale white-blue.

1. **Start the game**
   - What to do: press Play in Studio.
   - What should happen: you appear in Tallyport, the stone plaza with four buildings, on a green island. The Output window shows no red text.

2. **Check the start-up messages**
   - What to do: look in the Output window.
   - What should happen: you see `[IsleOfAvarice] server started` and `[IsleOfAvarice] client started`.

3. **Open a copper cache**
   - What to do: walk off the plaza to the nearest copper pillar. It is about 70 steps from the spawn point. Stand next to the box and hold the E key until the bar fills.
   - What should happen: a message says "You found" and then the name of a Relic, with an exclamation mark. The cache disappears.

4. **Wait for the cache to return**
   - What to do: wait 30 seconds.
   - What should happen: the same cache comes back.

5. **Open the Ledger**
   - What to do: press the B key, or click the "Ledger" button at the bottom left of the screen.
   - What should happen: a book called "The Hoarder's Ledger" opens. It shows 12 numbered slots on the left. Your new card is in the free list on the right. The top of the book says "Relics: 0 / 12".

6. **Claim a Relic**
   - What to do: click the "Claim" button next to your card.
   - What should happen: its slot lights up in the tier colour and shows the Relic's name. The top of the book now says "Relics: 1 / 12". The card leaves the free list.

7. **Try to claim a spare**
   - What to do: close the book, wait for the same cache to return, and open it again. If you get a different Relic, repeat until you get the one you already claimed. Open the book.
   - What should happen: the card is in the free list, but it has no "Claim" button, because that slot is already filled. It only has "Discard".

8. **Release a claimed slot**
   - What to do: click the lit slot.
   - What should happen: the slot goes dark again and the card goes back to the free list.

9. **Discard a spare**
   - What to do: click "Discard" next to a card in the free list.
   - What should happen: the card disappears. A message says the Relic was discarded.

10. **Fill the free slots**
    - What to do: collect cards until you hold 20 spares. Do not claim or discard them. Then open one more cache.
    - What should happen: a message says "Your free slots are full." The cache does not disappear.

11. **Finish the Ledger**
    - What to do: find all 12 caches and claim all 12 Relics. Six are copper, three are silver, two are gold and one is platinum. The platinum one is the farthest from town, close to the island's edge, about 370 steps from the spawn point. Its pillar is pale white-blue. Keep walking away from Tallyport in different directions until you find it.
    - What should happen: the top of the book says "Relics: 12 / 12 (complete!)". When you make the last claim, every player sees the message "(your name) has completed the Ledger!".

12. **Check saving** (only if you did "How to make saving work" in the README)
    - What to do: stop the game, then press Play again.
    - What should happen: your Ledger is as you left it.

13. **Test two players**
    - What to do: in Studio, choose Test, then Start with 2 players. Both players go to the same cache and hold E at the same moment.
    - What should happen: only one player gets the card. The other sees "This cache is empty. It will refill soon."

14. **Fall off the island**
    - What to do: walk past the island's edge into the sea.
    - What should happen: you fall and then come back at the spawn point in Tallyport.

If any step fails, copy the red text from the Output window and send it back.
