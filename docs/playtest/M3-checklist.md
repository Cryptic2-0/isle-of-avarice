# Play-test checklist for milestone 3

Milestone 3 adds the Six Paths: Fang, Gale, Ember, Mire, Mend and Bulwark. You choose one as your Calling, level up Paths at training posts and in fights, and use up to 4 abilities with the keys 1 to 4.

Most steps need two players. Start a two-player test the same way as in `docs/playtest/M2-checklist.md`: open the Test tab, set the number of players to 2 and press Start. **A** is Player1 and **B** is Player2.

Automated run (2026-11-12, Studio, two players): `[PLAYTEST] DONE passed=230 failed=0`, no script errors. The steps below are the hand checks for feel, visuals and phone layout.

Each test starts fresh, so every new test gives both players the Calling picker again. Saving between tests works only after the steps in the README under "How to make saving work".

## Words used here

- **Calling**: the Path you choose. It learns fastest. Paths next to it on the hexagon learn a bit slower, and the opposite Path learns slowest.
- **Paths panel**: press P, or the "Paths" button at the bottom left, just above the Ledger button. Close it with the "X" at its top right.
- **Ability bar**: four squares at the bottom centre of the screen, numbered 1 to 4. Press a number key, or click or tap a square, to use that ability.
- **Training posts**: six wooden posts with the label "Training post", just outside the gold circle of Tallyport. Hit them to train your Paths.
- Messages appear at the top of the screen and disappear after about 3 seconds.

## Steps

1. **Start: the Calling picker**
   - What to do: start a two-player test. As A, look at the screen. Press "Later". Then press 1. Then press P.
   - What should happen: before you do anything, a large window titled "Choose your Calling" shows six coloured cards, one per Path, each with its style, its 3 abilities and a "Choose" button. "Later" closes it. Pressing 1 gives "Choose a Calling first." The Paths panel opens with the title "Choose your Calling" and a "Choose" button on each Path's row. The four squares of the ability bar show "—".

2. **Choose a Calling**
   - What to do: as A, press "Choose" on Fang (in the Paths panel, or in the picker if it is still open). As B, choose Mire.
   - What should happen: A sees "Fang is now your Calling." and B sees "Mire is now your Calling." The picker closes. A's ability bar shows "Lunge" in square 1. B's shows "Bog Snare" in square 1.

3. **The Paths panel and learning rates**
   - What to do: as A, press P.
   - What should happen: the title reads "Calling: Fang". There is one row per Path. The Fang row has a thick outline and reads "Fang  Lv 3  (Calling)", with "XP 0 / 300" and "Rate 100%". Gale and Bulwark show "Rate 80%", Ember and Mend "Rate 60%", and Mire "Rate 40%". Every other Path is at "Lv 1". Each row lists its 3 abilities. Abilities you have not learned are grey and show the level of that Path that teaches them, for example "Level 10". Lunge shows "Equipped (slot 1)". The other rows have a "Make Calling (Free)" button. Do not press it yet: step 11 is about changing your Calling.

4. **Training posts**
   - What to do: as A, walk out of Tallyport to a training post. Face it and Strike it once. Then open the Paths panel.
   - What should happen: the post flashes pale yellow. The Fang row now shows "XP 10 / 300". Each Strike on a post gives 10 XP to your Calling. A post pays each player at most once every half second.
   - Extra check: an ability that hits a post trains that ability's own Path, not your Calling. A dash (Lunge) stops short of anything solid in its way, so to hit a post with Lunge, dash past it close beside it, not straight into it.

5. **Levelling up**
   - What to do: as A, keep striking the post until Fang reaches the next level. That takes 30 hits, about half a minute.
   - What should happen: A sees "Fang reached level 4." and the Fang row reads "Lv 4". New abilities come at level 10 and level 18 of a Path. When you learn one you see "You learned …!" with its name, and it goes into an empty square of the bar by itself. Reaching level 10 by hand takes a long time; the automated play test checks it.

6. **Changing abilities only in Tallyport**
   - What to do: as A, stand inside the gold circle and open the Paths panel. Press the "×" next to "1: Lunge". Then press "Equip" under Lunge. Then walk out of town, open the panel and press "×" again.
   - What should happen: in town, the "×" gives "Abilities updated.", the slot reads "1: Empty" and square 1 of the bar shows "—". "Equip" gives "Abilities updated." again and Lunge shows "Equipped (slot 1)". Outside town, the "×" gives "You can change abilities only in Tallyport." and nothing changes.

7. **Keys 1 to 4 and the ability bar**
   - What to do: as A, outside town with nobody in front of you, press 1. Press 1 again straight away. Then press 2.
   - What should happen: the first 1 dashes A about 12 steps forward. Square 1 darkens and counts down from 6. Pressing 1 during the countdown does nothing. Pressing 2 (an empty square) gives "Nothing is equipped in that slot." While the Paths panel, the Ledger or a claim screen is open, the keys do nothing. Clicking or tapping a square works like its key.

8. **One try of each Path's first ability**
   - What to do: for each pair below, start a new two-player test and let A and B choose those two Callings. Both press "Drop shield", then "Yes". Wait one minute, until "Respawn shield" has gone from both players' status lines. Take both players outside town, about 5 steps apart and facing each other. Each player presses 1 once at the other.
     - Test 1: A Fang, B Mire (you can do this in the same test as steps 1 to 7).
     - Test 2: A Gale, B Mend.
     - Test 3: A Ember, B Bulwark.
   - What should happen: each ability does what its card says.
     - **Lunge** (Fang): A dashes about 12 steps. The other player, if A passes through them, loses about a fifth of their health.
     - **Slipstream** (Gale): A dashes about 20 steps. The other player, if passed, loses a little health.
     - **Cinder Bolt** (Ember): a short orange ray. The other player loses health, then keeps losing a little for 3 seconds.
     - **Bog Snare** (Mire): a short green ray. The other player loses a little health and cannot move for about 1.5 seconds. If that player presses Lunge or Slipstream while stuck, they see "You are rooted and cannot dash."
     - **Siphon** (Mend): works only up close. The other player loses health and the caster gains the same amount back (if the caster was hurt).
     - **Shield Bash** (Bulwark): works only up close. The other player loses health and is pushed back about 10 steps.
   - The player who hits first sees "You started a fight. You are Marked for 5 minutes.", the same as with the Strike.

9. **The protection rules still hold**
   - What to do: start a new two-player test. A chooses Mire; B chooses any Calling. Do not drop any shields yet.
     - As A, stand outside town facing B, about 10 steps away, and press 1 (Bog Snare).
     - As A, press "Drop shield", then "Yes". Wait 9 seconds for Bog Snare's countdown, then press 1 at B again.
     - As B, press "Drop shield", then "Yes". Wait until "Respawn shield" has gone from B's status lines. B stands just inside the gold circle; A stands just outside it, facing B about 10 steps away. A presses 1 at B.
   - What should happen: the first try gives "You are shielded. Drop your shield to fight." The second gives "That player is shielded." The third gives "No fighting in Tallyport." Each time B loses no health and can still walk.

10. **Winning a fight trains your Calling**
    - What to do: in test 1, after step 8, take both players outside town and let A defeat B with Strikes and abilities. Open A's Paths panel. Then, once B's respawn shield has ended, defeat B again outside town and look at the panel again.
    - What should happen: after the first defeat, A gets the claim screen and the Fang row's XP is 150 higher. After the second defeat, A sees "You defeated Player2, but you already claimed from them in the last hour." and the XP does not change. Experience is never lost on defeat.

11. **Changing your Calling**
    - What to do: as A, open the Paths panel and press "Make Calling (Free)" on the Gale row. Read the question, then press "Yes". Then look at the other rows.
    - What should happen: the question reads "Change your Calling to Gale? Levels are kept; learning rates change." After "Yes", A sees "Gale is now your Calling." The title reads "Calling: Gale" and every level stays the same. The rates change: Fang and Ember now show "Rate 80%", Mire and Bulwark "Rate 60%", and Mend "Rate 40%". The other rows now read "Make Calling (Available in 7 days)" in grey and do nothing when pressed. The first change is free; later changes cost 500 Coin, and every change starts a 7-day wait.

If any step fails, copy the red text from the Output window and send it back.
