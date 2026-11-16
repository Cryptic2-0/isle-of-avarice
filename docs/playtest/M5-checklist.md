# Play-test checklist for milestone 5

Milestone 5 adds the Edicts, the Edict Hall and trading. An Edict is a single-use card kept in a free slot of your Ledger. There are five: Summons, Audit, Veil, Passage and Homecoming. The clerk in the Edict Hall, in Tallyport, sells packs of Edicts and Copper Relics and buys spare cards. Two players standing near each other can trade cards and Coin. A defeat now also destroys a third of the Edicts you hold (Relics are safe).

Many steps need two players. Start a two-player test the same way as in `docs/playtest/M2-checklist.md`: open the Test tab, set the number of players to 2 and press Start. **A** is Player1 and **B** is Player2.

Automated run: not done yet.

## Words used here

- **Edict**: a card with an id from E001 to E005. It sits in a free slot and has a "Use" button in the Ledger book.
- **Clerk**: the figure in Tallyport between the two north buildings, with the sign "Edict Hall" and "Packs, Copper Relics, selling".
- **Veil**: ten minutes in which Summons and Audit cannot see you.
- **Met**: you have met a player once you have both been within 30 steps of each other on this server. Passage only goes to players you have met.

## Steps

1. **The clerk and the shop window**
   - What to do: start a test. Walk to the clerk in Tallyport and press E on "Shop".
   - What should happen: a window titled "Edict Hall" opens. The top right shows your Coin, for example "Coin: 0". Below it are the line "Edict pack: 3 Edicts for 60 Coin" and, under it, the odds: "Each card: Summons 25%, Audit 20%, Veil 20%, Passage 15%, Homecoming 20%". The odds can be read. There is a "Relics for sale" list of six Copper Relics at 40 Coin each, a list "Sell a free-slot card", and a "Close" button. Buy buttons you cannot afford are dimmed. While the window is open, clicking does not Strike.

2. **Buying a pack**
   - What to do: earn at least 60 Coin (for example by defeating a few Brinehounds), open the shop and press the pack's "Buy" button.
   - What should happen: you see "You opened a pack: ..." naming three Edicts. The Coin line drops by 60 and the window's Coin line follows. The three cards are in your free slots (open the Ledger book). With less than 60 Coin the button is dimmed and pressing it does nothing.

3. **Buying a Relic**
   - What to do: with 40 Coin or more, press "Buy" on one of the Copper Relics.
   - What should happen: "You bought ..." and the card is in your free slots. Coin drops by 40. If your free slots are full, the Buy buttons are dimmed and you keep your Coin.

4. **Selling**
   - What to do: in the "Sell a free-slot card" list, press "Sell" on a spare card.
   - What should happen: "You sold ... for ... Coin." An Edict pays 3 Coin and a Copper Relic 1 Coin. The row disappears and the card leaves your free slots. Claimed Relics cannot be sold.

5. **Too far from the clerk**
   - What to do: open the window, then walk away from the clerk (about 20 steps) and press a button.
   - What should happen: "You are too far away." and nothing changes.

6. **Veil**
   - What to do: with a Veil card, open the Ledger book and press "Use" on it.
   - What should happen: "You are veiled for 10 minutes." The card is gone. A purple status line at the top left reads "Veiled 10:00" and counts down.

7. **Summons**
   - What to do: with B holding a Relic (claimed or spare), A presses "Use" on a Summons card. A grid of all the Relics opens. Pick the one B holds.
   - What should happen: a result window titled "Summons: ..." (the Relic's name) opens with "Held on this server by:" and B's name. The card is gone. If B has used a Veil, or nobody holds it, the window reads "Nobody else here holds it, or they are veiled."

8. **Audit**
   - What to do: A stands within 20 steps of B, B not veiled, and A presses "Use" on an Audit card.
   - What should happen: a window titled "Audit: " and B's name lists "Claimed: ... of 30", each claimed Relic as a number, name and tier (for example "007 Bottled Squall (Silver)"), then "Free slots: ... of 20" and B's spare cards. B sees "... looked inside your Ledger." If B is veiled the window reads "Their Ledger is veiled." If nobody is within 20 steps A sees "Nobody is close enough." and keeps the card.

9. **Passage**
   - What to do: A and B walk near each other so they have met, then B walks about 100 steps away. A presses "Use" on a Passage card and picks B from the list. (Before you have met anyone the list reads "You have not met anyone this session.")
   - What should happen: "You step out beside ..." and A stands a few steps from B. The card is gone. While A is Marked you see "Not while you are Marked." and the card is kept. Within 30 seconds of a fight you see "Not so soon after a fight." During a trial: "Not during a trial."

10. **Homecoming**
    - What to do: go out into the wild, wait until you are not Marked and have not fought for 30 seconds, then press "Use" on a Homecoming card.
    - What should happen: "You are back in Tallyport." and you stand in Tallyport. The card is gone. The same three refusals as in step 9 apply.

11. **Losing Edicts on defeat**
    - What to do: hold at least three Edicts and some Relics. Let B defeat A (or let a creature do it).
    - What should happen: A respawns in Tallyport and sees "Your defeat cost you: ..." naming a third of the Edicts held, rounded down (6 Edicts lose 2, 2 Edicts lose none). The Relics in your free slots are kept.

12. **A full trade (two players)**
    - What to do: A and B stand within 15 steps. A presses the "Trade" button.
    - What should happen: A sees "You asked ... to trade." B sees a banner with A's name and "wants to trade", with "Accept" and "Decline".
    - What to do: B presses "Accept". Both windows read "Trade with ...". A clicks one of A's cards (it moves to "You give") and presses a Coin step; B clicks a card of their own.
    - What should happen: each player sees the other's cards and Coin under "You get". The "Confirm" button reads "Confirm (2)", counting down. Pressing it early does nothing, or shows "Wait a moment after a change before you confirm."
    - What to do: wait until "Confirm" is lit, then both press it.
    - What should happen: the status line first reads "You confirmed. Waiting for ..." and then both see "The trade is done." The cards and Coin have changed hands and both windows close.

13. **Changing an offer resets the wait**
    - What to do: start another trade, wait for "Confirm", press it as A, then as B change the offer.
    - What should happen: A's confirmation is cleared and both buttons count down from 2 again.

14. **A cancelled trade and the leash**
    - What to do: start a trade and press "Cancel" as B. Then start another and walk B more than 25 steps from A.
    - What should happen: both see "The trade was cancelled." and the windows close. The same happens when either player is defeated or leaves.

15. **Declining**
    - What to do: A presses "Trade", B presses "Decline".
    - What should happen: A sees "... does not want to trade." If B does nothing for 20 seconds, A sees "The trade request ran out."

16. **On a phone**
    - What to do: in Studio, open the Test tab, choose Device and pick a phone. Open the shop window, a Summons result and a trade.
    - What should happen: each window fits the screen, text can be read, and the buttons ("Buy", "Sell", "Close", "Accept", "Decline", "Confirm", "Cancel") can be tapped. The invite banner does not cover the messages at the top.

If any step fails, copy the red text from the Output window and send it back.
