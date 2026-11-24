# Play-test checklist for the wide island

The island is now about 2,000 steps across. It has nine regions, three rivers with bridges, and a rule of its own in each wild region. This checklist walks through all of it. A step here is about one stud, the game's unit of length. You walk 16 steps a second.

**Automated run: not done on this branch yet.** The automated two-player script was updated for the new island and has seven new world checks. Their names start with `W.`: the ground, the hazard markers, lava, a spring, the bog, a vent and drowning. Nobody has run the script in Studio on this branch. To run it, build the play-test file as the README says under "For developers", open it in Studio and start a two-player test the same way as in `docs/playtest/M2-checklist.md` (open the Test tab, set the number of players to 2 and press Start). The Output window should end with a line like `[PLAYTEST] DONE passed=… failed=0` and show no `FAIL` lines. When the run is done, write its date and that line here. The steps below are the hand checks for looks, warnings, timing and feel.

Most steps need one player. Steps marked (two players) need A and B. **A** is Player1 and **B** is Player2, as in the M2 checklist. Each test starts fresh, so every new test gives both players the Calling picker again. If it is in your way, press "Later".

## Words used here

- **Region**: one of the nine named parts of the island: Tallyport, Counting Fields, Thornwood, Squall Steps, Cinder Flats, Drowned Fen, Reckoning Rock, Hush Gardens and Bastion Reach.
- **Status column**: the lines at the top left of the screen. The first line is the name of the region you are in. Lower down, an orange line names any hazard that is working on you right now, for example "Lava".
- **Entering message**: when you step into a new region, a message at the top of the screen shows its name and its rule. It disappears after about 3 seconds.
- **Hazard**: ground that hurts, heals or slows you. Some hazards run on a timer: they glow dim, then flash as a warning, then glow bright while they work.
- **Defeated by the island**: your health runs out, or you fall into a river. You wake up in Tallyport a few seconds later. Nothing is taken from your Ledger. Shields protect you only from other players, never from the island.
- **Signpost**: a wooden sign beside each wild region's road, 285 steps from the centre of town. It names the region and its rule.

## Getting around

- A stone road leaves Tallyport for each of the six wild regions. Going clockwise round the town, seen from above, the roads lead to Thornwood (north), Squall Steps, Cinder Flats, Drowned Fen (south), Hush Gardens and Bastion Reach. The six signposts stand in a ring, each about 285 steps from the next. If you reach the wrong one, walk round the ring.
- Each road runs straight out to about 470 steps from the centre of town. Each region's main sights lie on the same straight line, further out.
- Reckoning Rock is an islet out at sea, due south of town. You reach it from the end of the Drowned Fen.
- Rough distances from the centre of town, and the walk at 16 steps a second:

| Place | Steps out | Walk |
| --- | --- | --- |
| Signposts | 285 | 18 s |
| Thornwood: the maze starts, the Bell room in the middle | 480, 650 | 30 s, 41 s |
| Squall Steps: the first pillar, the summit | 480, 845 | 30 s, 53 s |
| Cinder Flats: the Bellows, Kiln Lake | 440 to 600, 650 to 870 | 28 s, 41 s |
| Drowned Fen: the boardwalk starts, the rotted gap | 400, 620 to 680 | 25 s, 39 s |
| Reckoning Rock: the causeway starts, the Rock | 940, 1,240 | 59 s, 78 s |
| Hush Gardens: the first spring, the Moth Wing | 380, 860 | 24 s, 54 s |
| Bastion Reach: the first wall, the keep | 520, 820 | 33 s, 51 s |
| The rivers start; their bridges | 300; 420 and 760 | 19 s; 26 s and 48 s |

## Steps

1. **Region names and entering messages**
   - What to do: start a test. Look at the status column and the message right away. Then walk out of town along any road. Each time you cross into a region for the first time, look again. Do this now for Tallyport and the Counting Fields, and again in steps 3 to 13 for the rest.
   - What should happen: the first line of the status column is the region's name, and the message reads like this:

     | Region | Message |
     | --- | --- |
     | Tallyport | Tallyport: Safe ground. No fighting here. |
     | Counting Fields | Counting Fields: Quiet fields. Nothing here will hurt you. |
     | Thornwood | Thornwood: A hedge maze. Briars are a shortcut that costs health. |
     | Squall Steps | Squall Steps: Climb the pillars. Brace when the wind lanes glow. |
     | Cinder Flats | Cinder Flats: Vents glow before they erupt. Lava burns fast. |
     | Drowned Fen | Drowned Fen: Stay on the boardwalk. The bog slows and drains you. |
     | Reckoning Rock | Reckoning Rock: The causeway floods at high tide. The Rock is safe. |
     | Hush Gardens | Hush Gardens: The blight drains you. Springs heal. |
     | Bastion Reach | Bastion Reach: Rocks fall where the ground glows. Shelter under the roofs. |

     In Tallyport the status column also shows "Safe zone". Each signpost shows the region's name and the same rule.
   - Extra check: each wild region has one copper cache just past its signpost, about 315 steps from the centre of town and 60 steps to the left of the road as you walk out. Hold E at one to open it. With the six in the Counting Fields, that makes 12 copper caches, and 18 caches with the six prize caches.

2. **A bridge and a river fall**
   - What to do: go to the first bridge over the river between Thornwood and Squall Steps. It lies on the line halfway between those two roads, 420 steps from the centre of town. Walk across the bridge. Then walk back onto it and step off its side.
   - What should happen: the river is a gap in the ground, 100 steps wide, with blue water a few steps below the ground. It starts 300 steps from town and runs to the sea. The wooden bridge is 16 steps wide and you can walk across it. When you step off its side you fall, and within about a second you are defeated. You wake up in Tallyport. The other two rivers lie between Cinder Flats and Drowned Fen, and between Hush Gardens and Bastion Reach. Each river has two bridges, at 420 and 760 steps out.

3. **The maze (Thornwood)**
   - What to do: follow the Thornwood road north to the maze, about 480 steps out. Go in at the south entrance, the gap in the hedge that faces town. Walk around. Then come out and try the west entrance (on your left) or the east entrance (on your right).
   - What should happen: a square maze of dark green hedges, 340 steps on each side. The hedges are 14 steps high, so you cannot see over them. The corridors are 20 steps wide, with dead ends. There are three entrances: south, west and east. In the middle is a room about 60 steps wide. It holds the Debt-Collector's Bell. The safe way from an entrance to the middle is long, about one to two minutes of walking.

4. **A briar shortcut**
   - What to do: look for a patch of dark, thorny ground set into the maze, a "briar gap". One is in the left-hand wall of the middle room; the west entrance is the quickest way to it. Walk into it and stay a moment. If you cannot find one, use one of the round briar patches on open ground, off the road between 350 and 455 steps out. Then walk out.
   - What should happen: the status column shows "Briars". You lose about 12 health a second and walk 40% slower. Crossing one 20-step square of briars costs about 25 health. When you step out, the line goes and the slow wears off within a second. Through the briars the way to the Bell is only 13 to 17 squares. The safe way is 49 to 93. Health buys time.

5. **The pillar climb (Squall Steps)**
   - What to do: follow the Squall Steps road to the pillars, about 480 steps out. Jump from pillar to pillar up to the summit. Fall off on purpose once. On the summit, hold E at the Bottled Squall cache.
   - What should happen: eighteen stone pillars rise like stairs, each 3 steps taller than the last and 5 steps from the next. Each gap needs a jump. The summit is a wide plateau 57 steps up. If you fall, you lose the climb but no health. The summit cache is silver.

6. **A gust**
   - What to do: on the way up, find the pale, see-through patches on the ground between the pillars. There are three wind lanes across the climb and a fourth on the summit. Stand on a pillar inside a lane, or on the summit, press nothing and wait.
   - What should happen: every 7 seconds a lane flashes for 1.5 seconds, then glows bright for 2 seconds. While it is bright the status column shows "Gust" and you slide sideways about 11 steps a second, 22 in all, even with no key pressed. On a pillar that usually carries you off. The first and third lanes push to the right as you climb and the second to the left. The summit lane pushes toward the outer edge.

7. **The Bellows (Cinder Flats)**
   - What to do: follow the Cinder Flats road. About 440 steps out it runs into the Bellows. Stand beside it and watch. Then stand in one vent for a few seconds. Then run through the field.
   - What should happen: the Bellows is a field of 25 round vents, 5 by 5, with orange lava strips along both sides. Each vent is a pale orange disc. It flashes for 1.5 seconds, then erupts for about 1 second. During the eruption "Vent" shows for a moment, your character flashes white and you lose 35 health. You lose it once per eruption, however long you stand there. Vents erupt every 6 seconds, in slow diagonal waves across the field. With good timing you cross unhurt.

8. **Lava and the causeway (Kiln Lake)**
   - What to do: go past the Bellows to Kiln Lake, about 650 steps out. It is a round lake of bright orange lava with an islet in the middle. Cross the dark stone causeway to the islet. On the islet, hold E at the Weeping Strongbox. Then step off the causeway into the lava on purpose.
   - What should happen: four vents on the causeway erupt one after another, starting with the vent nearest the shore and ending with the one at the islet, each about 1.2 seconds after the one before. That wave moves about as fast as you walk. Each vent costs 35 health. Wait for the first vent to erupt, then walk just behind the wave. A vent at the Strongbox erupts every 5 seconds and leaves about 4 seconds of quiet. The hold takes 3 seconds, so start it just after an eruption. You see "You found Weeping Strongbox!". In the lava the status column shows "Lava". You lose 30 health a second and are defeated in about 3 seconds. You wake up in Tallyport.

9. **The boardwalk and the rotted gap (Drowned Fen)**
   - What to do: follow the Drowned Fen road south. About 400 steps out a wooden boardwalk starts and runs on through the mud. Walk along it. Step off it into the mud for a few seconds. Then go on to the middle, where the boardwalk breaks off. Wade through the gap. Later, go round it by the side boardwalk that leaves the main one about 120 steps before the gap, on your right.
   - What should happen: the Fen has the thickest fog on the island. In the mud the status column shows "Bog", you move at half speed and you lose 3 health a second. On the boards, "Bog" goes and you walk normally. The rotted gap is 60 steps long. Wading it takes about 8 seconds and costs about 22 health. The side boardwalk costs no health but is long, about 500 steps or 30 seconds.

10. **The tide (Reckoning Rock)**
    - What to do: go on south from the Fen to the shore. The causeway to the Rock starts 940 steps from town and runs 220 steps. Stop before it and watch the blue glow on it. When the water is low, cross to the Rock. Stay on the Rock and watch the causeway for two minutes.
    - What should happen: the water goes round in a 2-minute cycle. For about 70 seconds the tide is low and the causeway glows dim blue. Then the glow flashes for 15 seconds as a warning, and the water starts to rise. Then for 35 seconds the tide is high: the glow is bright, the water is 3 steps higher, and anyone on the causeway sees "High tide" and loses 40 health a second. The crossing takes about 14 seconds. On the Rock you see "Reckoning Rock" and no hazard line, and you lose no health at any time. You cannot leave until the water drops. The Rock holds the Gilded Anchor Link. If you want, step onto the causeway at high tide: you are defeated in about 3 seconds.

11. **Blight and springs (Hush Gardens)**
    - What to do: follow the Hush Gardens road, then keep walking straight out along the same line. Watch your health. Stand in the first spring, about 380 steps out. Then walk on to the last spring in the line, 740 steps out, and stand in it until your health is full. Walk 120 steps past it to the Ledger-Moth Wing, hold E, and walk back to that spring.
    - What should happen: from about 330 steps out the status column shows "Blight" and you lose 5 health a second. A spring is a bright blue disc about 28 steps across. In a spring "Spring" shows under "Blight" and your health rises about 10 a second overall. Five springs line the trail, 90 steps apart. Four more lie off the trail, and one of those is hidden near the prize. The round trip to the Moth Wing should leave you with very little health when you get back. Note how it felt: the blight numbers are still open for play tests.

12. **The fortress gates (Bastion Reach)**
    - What to do: follow the Bastion Reach road. About 520 steps out you meet the first of three high stone walls. Find its gate and walk through. Cross the yard behind it and find the gate in the second wall, then the third.
    - What should happen: the walls are 24 steps high and block your view. Each has one gate, 20 steps wide. The gates are on alternating sides: left, right, then left as you walk in. So the way in zigzags through three yards to the keep, where the Hoarder's Thumbprint lies.

13. **A shelter and a rockfall hit**
    - What to do: in the first yard, look at the ground: it has rows of round, see-through orange-red patches. Stand in one and wait. Then walk to the shelter in the middle of the yard, a wooden roof on two posts, and wait under it for 15 seconds.
    - What should happen: each patch flashes for 2 seconds, then a rock lands. "Rockfall" shows for a blink, your character flashes white and you lose 30 health (35 in the keep). Patches land every 6 seconds (4.5 in the keep), each on its own timer. Nothing lands under the roof or in the bare strip down the middle of each yard. The keep's prize cache stands under a shelter too.

14. **A prize cache takes longer to open**
    - What to do: stand beside a prize cache from the list below. Hold E and count. Let go early once. Then do the same at a copper cache in the Counting Fields.
    - What should happen: the ring on the prompt fills slowly. It takes about 3 seconds at a prize cache and 4 seconds at the Hoarder's Thumbprint. If you let go early, the cache stays shut. A copper cache in the Counting Fields opens after half a second.

    | Region | Prize | Where |
    | --- | --- | --- |
    | Thornwood | Debt-Collector's Bell (silver) | middle of the maze |
    | Squall Steps | Bottled Squall (silver) | on the summit |
    | Cinder Flats | Weeping Strongbox (gold) | on the Kiln Lake islet |
    | Reckoning Rock | Gilded Anchor Link (gold) | on the Rock |
    | Hush Gardens | Ledger-Moth Wing (silver) | 120 steps past the last trail spring |
    | Bastion Reach | The Hoarder's Thumbprint (platinum) | in the keep, under a shelter |

15. **The island ignores shields, and a push into lava is a defeat (two players)**
    - What to do: both players go to the lava pools beside the Cinder Flats road, about 340 steps out. One pool is about 120 steps to the left of the road and one about 90 steps to the right. Do not drop any shield yet. As B, walk into a pool. Then both press "Drop shield", then "Yes". Wait until "Respawn shield" has gone from B's status lines, about one minute. Take both back to the pool. As B, stand at its edge. As A, face B and Strike once. Then, as B, step into the lava within 15 seconds.
    - What should happen: the first time, B's shield lines stay on screen, but B still loses 30 health a second and is defeated in about 3 seconds. B wakes up in Tallyport. A sees no message and no claim screen. The second time, the Strike takes about a fifth of B's health. A sees "You started a fight. You are Marked for 5 minutes." When B is defeated by the lava, A sees "You defeated Player2. Make your claim." and the claim screen, and B sees "Player1 defeated you and is making a claim on your Ledger." It is the same as a defeat by a Strike in M2 step 8.
    - Extra check: after B's respawn shield ends, repeat the Strike, but this time B waits 20 seconds before stepping into the lava. A should see nothing: the hit was too long ago to count. If A sees "You defeated Player2, but you already claimed from them in the last hour.", the 15 seconds are not being counted.
    - Extra check: start a new test, let A choose Bulwark, and set up the same way (both drop shields, then wait a minute). Stand B between A and the pool, about 6 steps from its edge. As A, press 1 up close (Shield Bash). B is knocked back about 10 steps, into the lava, and A gets the same claim screen.

16. **Fog changes between regions**
    - What to do: walk from the Counting Fields into each region and look at the distance.
    - What should happen: within a couple of seconds of crossing into a region the haze fades to that region's colour. The Counting Fields and Tallyport are a clear pale blue. Thornwood is a dim green gloom. Squall Steps is bright and clear. Cinder Flats is a red-brown haze. The Drowned Fen is thick grey-green fog, the thickest of all. Reckoning Rock is a grey-blue. Hush Gardens is a lilac mist. Bastion Reach is plain grey.

17. **The Counting Fields are unchanged**
    - What to do: start a test and walk around the green ring between the town and the 260-step mark. Open the nearest copper cache. Strike a training post.
    - What should happen: the status column shows "Counting Fields" with no hazard line anywhere in the ring, and nothing glows. The ground is flat and open, with no hedges, walls or trees. The six copper caches are where they were, the nearest about 70 steps from the spawn point, and each opens after half a second. The six training posts stand just outside the gold circle of Tallyport, and a Strike on one flashes it pale yellow. The M3 checklist steps about training posts still work, and so do the M1 steps about opening these six copper caches. M1 steps 11 and 14 are changed for the wide island: the rarer Relics are the prize caches in the wild regions, and a river takes the place of the island's edge.

If any step fails, copy the red text from the Output window and send it back.
