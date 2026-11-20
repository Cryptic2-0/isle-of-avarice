# Play-test checklist for milestone 6

Milestone 6 adds parties. Up to four players can form a party. Party members cannot hurt each other, a heal or a shield from one reaches the others, and a player who helps a party member with a creature shares in its reward.

Almost every step needs two players. Start a two-player test the same way as in `docs/playtest/M2-checklist.md`: open the Test tab, set the number of players to 2 and press Start. **A** is Player1 and **B** is Player2. Parties of three and four are covered by unit tests only; if you have more players, try them too.

Automated run: not done yet.

## Words used here

- **Leader**: the player whose name has "(leader)" on the party panel. Only the leader can invite, remove a member or hand over the lead.
- **Ally**: another member of your party. A green name hangs over an ally's head.
- **Invite banner**: the box at the top of the screen that reads "<name> invites you to their party" with "Accept" and "Decline" buttons.

## Steps

1. **Inviting with the Party button**
   - What to do: A and B stand in Tallyport about 8 steps apart. A presses the "Party" button (bottom left, above "Trade"). First try it with B far away (20 steps or more).
   - What should happen: with B far away A sees "Nobody is close enough." With B close, A sees "You invited <B> to your party." and B sees the banner "<A> invites you to their party" with "Accept" and "Decline". If A presses "Party" again while the invite waits, A sees "You cannot do that now."

2. **Declining and letting an invite run out**
   - What to do: B presses "Decline". Then A invites B again and nobody answers for 20 seconds.
   - What should happen: after "Decline" A sees "<B> does not want to join your party." and no party exists. After 20 seconds the banner goes away by itself and A sees "Your party invite ran out."

3. **Joining**
   - What to do: A invites B again and B presses "Accept".
   - What should happen: B sees "You joined <A>'s party." and A sees "<B> joined your party."

4. **The party panel**
   - What to do: look at the panel at the top right, under the trial lines, on both screens.
   - What should happen: the title reads "Party 2 / 4". There is one row per member with the name, a health bar and the health as "100 / 100". The leader's row says "<A> (leader)". A's row for B has two small buttons, "Remove" and "Make leader". B's rows have no buttons. Both panels have a "Leave" button at the bottom. When B takes damage, the health on A's panel follows within a second or two.

5. **The green markers**
   - What to do: A and B stand a little apart and look at each other.
   - What should happen: a green name hangs above each ally's head, readable through walls from up to 250 steps away. After B respawns the marker is back on B's new character. It is gone when B leaves the party.

6. **A Strike and an ability pass an ally**
   - What to do: leave Tallyport. A stands 6 steps from B facing B and presses Strike, then fires Gust Blade (or any shot) at B. Then A faces a creature with B in front of A, in line, and does the same.
   - What should happen: B takes no damage and A does not get the red "MARKED" tag. A creature behind B is hit; B is not. B's Sinking Field does not slow or hurt A.

7. **Ward and Renewal on an ally**
   - What to do: B uses Ward with A within 15 steps, then again with A 20 steps away. Later, with both hurt, B uses Renewal with A close.
   - What should happen: with A close, both are shielded against 30 damage for 6 seconds. With A 20 steps away only B is shielded. Renewal heals both for 35 and removes slow, root and burn. Siphon on a creature heals A too when A is within 15 steps. Rebuke covers only B.

8. **Help in a fight and in a duel**
   - What to do: B is under the new-player shield or still in Tallyport, and A is fighting someone. B uses Ward near A. Also try it while A is in the Tallyman's Duel.
   - What should happen: a Ward from a shielded B does not reach A while A is fighting, so B cannot use a shield to cover a fight. A Ward never reaches a party member who is in a duel. When B's Ward does reach a fighting A, B's respawn shield ends.

9. **A creature defeated together**
   - What to do: A and B in a party outside Tallyport. A hits a Shellback; B stays out of its reach, uses Ward on A, then A defeats it.
   - What should happen: both see "Shellback defeated! +10 Coin." B gets the Coin and some Mend XP, but no XP for B's own Calling. Repeat after A has left the party: B uses Ward on A, A defeats the creature, and B gets nothing.

10. **Joining in the middle of a fight**
    - What to do: A and B are not in a party. A invites B, then hits B with Cinder Bolt, and B presses "Accept" straight away. Later, make B fall into the sea (or be defeated by a creature).
    - What should happen: the burn stops as soon as B joins. B's fall gives A no claim and no "defeated you" message, and B is still in A's party after respawning.

11. **Handing over the lead**
    - What to do: A presses "Make leader" on B's row.
    - What should happen: both see "<B> now leads your party." B's panel now shows the "Remove" and "Make leader" buttons and A's does not. A pressing "Party" sees "Only the party leader can do that."

12. **Removing a member**
    - What to do: with B as leader, B presses "Remove" on A's row.
    - What should happen: A sees "<B> removed you from the party." and B sees "Your party broke up." Both panels and all markers go away.

13. **Leaving**
    - What to do: form a party again. A presses "Leave".
    - What should happen: A sees "You left the party." B sees "Your party broke up." If the leader leaves a party of three or four, the first remaining member leads, and everyone sees "<name> now leads your party."

14. **Fighting again after leaving**
    - What to do: both outside Tallyport with shields down, not in a party. A presses Strike facing B.
    - What should happen: B takes damage and A is Marked, as in milestone 2.

15. **On a phone**
    - What to do: use the Test tab's device emulator to pick a phone and join a party.
    - What should happen: the "Party" button, the banner, the panel and its buttons are all readable and tappable. The banner sits under the trade banner and the panel under the trial lines, so none covers another.

If any step fails, copy the red text from the Output window and send it back.
