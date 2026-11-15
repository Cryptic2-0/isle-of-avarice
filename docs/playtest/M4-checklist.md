# Play-test checklist for milestone 4

Milestone 4 adds creatures and trials. Beasts live at dens out in the wild regions, fight back, and pay Coin, Path XP and sometimes a Relic to everyone who helped defeat them. Six Wardens, one at each region's gate, offer timed trials. Three of the trials and one great beast make up a quest, The Unpaid Debt. The Ledger now has 30 slots.

Some steps need two players. Start a two-player test the same way as in `docs/playtest/M2-checklist.md`: open the Test tab, set the number of players to 2 and press Start. **A** is Player1 and **B** is Player2.

Automated run: **not done yet.** The play-test script has M4 checks (their names start with "M4"), but they have not been run in Studio. Run the automated two-player play test described in the README first. It should end with `[PLAYTEST] DONE` and `failed=0`. If it does not, copy the lines that start with `[PLAYTEST] FAIL` or `[PLAYTEST] CRASH` and send them back before going through the steps below.

The steps below are the hand checks for how things look, move and feel, and for the phone layout.

## Words used here

- **Gate**: where a region's road leaves the Counting Fields, about 300 studs from Tallyport. A signpost names the region. The Warden stands to the right of the road as you walk out; the region's Copper cache is to the left.
- **Den**: a dark round patch of ground with a label such as "Brinehound den". Its creatures stay near it.
- **Coin line**: the gold line "Coin: …" at the top left, above the status lines.
- **Trial HUD**: the lines at the top right. The last one is always the quest line, for example "The Unpaid Debt: 0 / 4, next: Tidewalk".
- Messages appear at the top of the screen. When several arrive together they now show one after another instead of replacing each other.

## Where things are

| Region (road from Tallyport) | Warden and trial | Creatures nearby |
|---|---|---|
| Thornwood (north) | Pack Warden: Cull the Pack | Two Brinehound packs west of the road and the maze; Bogspitters on the far north shore |
| Squall Steps (north-east) | Cliff Warden: Gullstep Climb | Shellbacks and the Brine Colossus on the far east flank |
| Cinder Flats (south-east) | Saltworks Warden: Salt Post | Bogspitters north of the road |
| Drowned Fen (south) | Shell Warden: Shellbreaker | Shellbacks west of the road; Bogspitters far down the west side |
| Hush Gardens (south-west) | Harbour Warden: Tidewalk | None |
| Bastion Reach (north-west) | Duel Warden: The Tallyman's Duel | Two Brinehound packs, one on each side of the road |

## Steps

1. **The Coin line and the 30-slot Ledger**
   - What to do: start a test. Look at the top left. Open the Ledger book.
   - What should happen: a gold line reads "Coin: 0" above the status lines. The book shows 30 slots and "Relics: 0 / 30". Slots 13 to 30 have names and tiers like the first twelve.

2. **A Brinehound pack**
   - What to do: as A, press "Drop shield", then "Yes". Walk north along the Thornwood road to the signpost, then go left (west) about 100 steps past the Copper cache until you see a "Brinehound den" label. Stop about 40 steps away and watch. Then walk closer.
   - What should happen: three low, long, slate-blue beasts with a dark fin wander near the dark patch and never go far from it. Each has its name and a red health bar above it. When you come within about 35 steps and they can see you, they run at you and bite. Each Bite takes 8 health. You do not get the red "MARKED" tag for fighting them.

3. **Fighting back**
   - What to do: Strike a Brinehound until it is defeated. Use an ability on another one.
   - What should happen: each Strike takes 20 of its 60 health and it flashes white. A defeated Brinehound tips over and vanishes. You see "Brinehound defeated! +4 Coin." and the Coin line goes up by 4. Your Calling's XP goes up in the Paths panel. Abilities hit them like players: a slow slows them, a root holds them still, a taunt makes one chase the taunter. About 30 seconds later a new Brinehound appears at the den.

4. **The leash**
   - What to do: get a Brinehound to chase you, then run straight away from the den, back toward the road.
   - What should happen: about 60 steps from the den it gives up and walks home. While it walks home your hits do nothing. Once home it is back at full health. It never follows you into the Counting Fields far enough to reach Tallyport, and it stops at the edge of a river instead of walking into the water.

5. **Shellbacks and Bogspitters**
   - What to do: walk the Drowned Fen road to its signpost and go right (west) about 130 steps to the "Shellback den". Fight one. Then find a "Bogspitter den" (for example north of the Cinder Flats road, about 140 steps to the left of the signpost as you walk out) and fight one.
   - What should happen: a Shellback is a wide, sandy shell on a dark flat body. It is slow, has 160 health and its Claw takes 14. A Bogspitter is a thin olive stalk with a big round head. It spits from far away (a short green beam, 10 damage) and backs off when you come within about 15 steps. Defeating them pays 10 Coin and 8 Coin.

6. **Two players share the reward**
   - What to do: with two players, both drop their shields and both hit the same Shellback before it is defeated.
   - What should happen: both players see "Shellback defeated! +10 Coin." and both Coin lines go up by the full 10. Each gets XP on the Path they did the most damage with (the Strike counts as your Calling).

7. **Defeated by a creature**
   - What to do: let a Brinehound pack defeat A.
   - What should happen: A respawns in Tallyport. Nobody gets a claim screen and A loses nothing.

8. **Talking to a Warden**
   - What to do: walk the Hush Gardens road (south-west) to the signpost. The Harbour Warden stands to the right of the road by a wooden dock, about 80 steps from the road. Walk up to the small figure and press E on "Talk".
   - What should happen: a window opens with the title "Tidewalk", "Harbour Warden", "Touch 6 markers in order.", "Time: 60 seconds", "Reward: 30 Coin, 120 XP" and "Relic: Low-Tide Tally Stick (Silver)". It has an "Accept" and a "Close" button. While the window is open, clicking does not Strike.

9. **Tidewalk**
   - What to do: press "Accept". Follow the glowing column to each numbered ring on the ground.
   - What should happen: "Tidewalk has begun!" The trial HUD reads "Tidewalk: marker 0 / 6" and "Time left 1:00", counting down. A tall pale-blue column stands on marker 1; when you touch a ring you see "Marker 1 of 6." and the column moves to the next. The whole course stays outside the blight. After the sixth you see "You passed Tidewalk! +30 Coin.", "You found Low-Tide Tally Stick!" and "The Unpaid Debt: step 1 of 4 done." Talk to the Warden again: "Accept" is dimmed and an amber line reads "Try again in 4:5…".
   - Feel check: is 60 seconds too easy or too tight? Are the rings easy to see?

10. **Gullstep Climb**
    - What to do: walk the Squall Steps road (north-east). The Cliff Warden is to the right of the road at the signpost. Accept, then go to the row of seven grey stone steps a little further out and to the right. Touch the ring on the ground, then jump up the steps.
    - What should happen: eight markers, the last 28 studs up. Each step is one jump higher than the last. 75 seconds. Passing gives "Gull-Perch Spyglass".
    - Feel check: are the jumps comfortable on a keyboard? On a phone?

11. **Salt Post**
    - What to do: talk to the Saltworks Warden at the Cinder Flats gate (south-east) and accept. Run to the Harbour Warden at the Hush Gardens gate.
    - What should happen: a small brown parcel appears on your back. The HUD reads "Salt Post: carry the parcel to the Harbour Warden". The run crosses the Counting Fields and takes a little over half of the 70 seconds. Reaching the Harbour Warden passes the trial and the parcel disappears. If you did Tidewalk first, the quest line moves to "2 / 4". If you are defeated on the way you see "You were defeated: Salt Post failed." and can try again after 30 seconds.

12. **A hunt**
    - What to do: talk to the Pack Warden at the Thornwood gate, accept Cull the Pack, and defeat 5 Brinehounds in 120 seconds. The nearest pack is about 200 steps away, to the left of the road.
    - What should happen: each defeat shows "1 of 5 defeated." and so on. After the three of the first pack you must wait for them to come back (30 seconds) or run to the second pack further out. Passing gives "Brinehound Collar".
    - Feel check: is 120 seconds fair for one player? This is the number most likely to need changing.

13. **The duel**
    - What to do: with two players, A talks to the Duel Warden at the Bastion Reach gate (north-west) and accepts. Both players walk to the round stone floor nearby.
    - What should happen: a man-sized figure in a dark-teal coat with a pale head and a gold book, the "Drowned Tallyman", appears on the stone floor. Only A can see it, hit it, or be hit by it. B sees nothing there and can walk through the spot. It strikes for 12 and every 8 seconds lunges for 18. Defeating it within 90 seconds gives "Tallyman's Abacus" and, if steps 9 and 11 were done in order, the quest line moves to "3 / 4, next: defeat the Brine Colossus". If time runs out it vanishes.

14. **The Brine Colossus**
    - What to do: walk far out along the east side of Squall Steps, past the pillar climb and to the right of it, to the "Brine Colossus den". Bring a friend.
    - What should happen: a huge grey-blue block with two arms and pale barnacles, 900 health. Every 4 seconds it slams the ground: a pale ring shows, and everyone within 10 steps takes 25. Defeating it pays 60 Coin and 500 XP to everyone who helped, and each gets "Colossus Heartstone" unless four are already held on the server. With the quest at 3 / 4 you also see "The Unpaid Debt is paid! +150 Coin." and get "Writ of the Unpaid Debt". The quest line returns to "0 / 4". The Colossus comes back after 10 minutes.

15. **Caches up a climb**
    - What to do: find the three stone stairways with a cache on top. The easiest is the Lookout's crag: sixteen grey steps in four rows on the east flank of Squall Steps, about 550 steps out and 220 to the right of the road. Try the cache's prompt from the ground, then climb.
    - What should happen: from the ground the prompt is out of reach. On the top step, 64 studs up (the highest point on the island), the cache gives "Lookout's Gilded Horn". The other two are behind the Thornwood maze on the north shore (five steps, "Rook's-Nest Purse") and far out on the right side of Bastion Reach (six steps, "Cliffside Tithe Box").

16. **Sealed and full**
    - What to do: fill all 20 free slots (collect Copper Relics without claiming them), then pass a trial.
    - What should happen: you still get the Coin and XP, and see "Your free slots are full, so … was lost." Before you accept, the Warden's window warns in amber: "Your free slots are full, so the Relic would be lost."

17. **On a phone**
    - What to do: in Studio, open the Test tab, choose Device and pick a phone. Talk to a Warden, run a trial, and (with two players) open a claim screen.
    - What should happen: the Warden's window fits the screen and both buttons can be tapped. The trial HUD at the top right does not cover the ability bar. The claim screen shows all 30 slots in six columns and five rows, and the names can be read.

If any step fails, copy the red text from the Output window and send it back.
