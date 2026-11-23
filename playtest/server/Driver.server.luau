--!nonstrict
-- Automated two-player play test. Only in the play-test build (playtest.project.json),
-- never in dist. Start a local server with 2 players; this script walks through the M1,
-- M2, M3, M4, M5, M6, M7 and M8 checklists and the world checks (W.1 to W.7, for the nine-region island),
-- driving each player through their Agent, and prints one line per check:
-- "[PLAYTEST] PASS ..." or "[PLAYTEST] FAIL ...", then a DONE summary.
--
-- Player moves are teleports, and a few waits are skipped on purpose (the 60-second
-- respawn shield is ended early with ProtectionService.endRespawnShield, and Relics are
-- handed out with LedgerService.set where the checklist would walk to caches for minutes).
-- For M3, Path XP is handed out with PathService.grant (or written into the saved data)
-- where the checklist would hit training posts for hours, and health is refilled before
-- each measured ability hit. The world checks refill health the same way before each
-- measurement and stand A in one hazard at a time.
--
-- Order: the world checks (M1.1, then W.1 to W.7; the last of those drowns A, who respawns
-- in Tallyport), then M1 and M2, with M3.1 to M3.3 (first join, choosing a Calling) right
-- after M2.1. A can claim B only once an hour and M2 makes that claim (and B's on A), so
-- M2.8, M2.13 and M2.14 also check the Calling's defeat XP (M3.10). Then the rest of M3,
-- then M4 (creatures, trials and the quest), then M5 (Edicts, the shop and trading), then M6 (parties), then M7 (held caches, Crowning, the board, Renounce, the
-- Crown Relics, health regeneration), then M8 (launch polish: the UI kit, the menu row, where the
-- controls sit, two taps to unclaim or discard, the region banner, the blight tint, a Coin change
-- reaching an open trade, a new character's health watch, the party panel), and M2.15, which ends
-- B's session, last of all. M8 taps the game's own buttons through the agent's press seam (it runs
-- the handler the button recorded, as a tap would, only while the button is Active and shown).
-- Creatures are put to sleep for the whole run (CreatureService.setActive) and M4 wakes one
-- at a time; it sets their health directly, fixes the drop rolls and skips trial time. The Tally
-- Stone's board and the badge are stand-ins from the start of the run to the end of M7 (M1.11
-- already Crowns A, and M7 Crowns A again from scratch). Health regenerates 1 a second, but only
-- 10 seconds after the last loss (setting Humanoid.Health lower counts as a loss), so a check
-- that measures damage reads health right before and right after, never across 10 seconds.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local CombatService = require(Server:WaitForChild("CombatService"))
local CreatureService = require(Server:WaitForChild("CreatureService"))
local CrownService = require(Server:WaitForChild("CrownService"))
local DataService = require(Server:WaitForChild("DataService"))
local EdictService = require(Server:WaitForChild("EdictService"))
local Fighters = require(Server:WaitForChild("Fighters"))
local LaunchConfig = require(Server:WaitForChild("LaunchConfig"))
local LeaderboardService = require(Server:WaitForChild("LeaderboardService"))
local LedgerService = require(Server:WaitForChild("LedgerService"))
local PartyService = require(Server:WaitForChild("PartyService"))
local PathService = require(Server:WaitForChild("PathService"))
local ProtectionService = require(Server:WaitForChild("ProtectionService"))
local ShopService = require(Server:WaitForChild("ShopService"))
local Sight = require(Server:WaitForChild("Sight"))
local SourceService = require(Server:WaitForChild("SourceService"))
local StatusService = require(Server:WaitForChild("StatusService"))
local TradeService = require(Server:WaitForChild("TradeService"))
local TrialService = require(Server:WaitForChild("TrialService"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rules = Shared:WaitForChild("Rules")
local Combat = require(Rules:WaitForChild("Combat"))
local Crown = require(Rules:WaitForChild("Crown"))
local Geography = require(Rules:WaitForChild("Geography"))
local Hazards = require(Rules:WaitForChild("Hazards"))
local HudLayout = require(Rules:WaitForChild("HudLayout"))
local Ledger = require(Rules:WaitForChild("Ledger"))
local Party = require(Rules:WaitForChild("Party"))
local PathProgress = require(Rules:WaitForChild("PathProgress"))
local PathView = require(Rules:WaitForChild("PathView"))
local Protection = require(Rules:WaitForChild("Protection"))
local Rounds = require(Rules:WaitForChild("Rounds"))
local Creatures = require(Shared:WaitForChild("Catalog"):WaitForChild("Creatures"))
local Looks = require(Shared:WaitForChild("Catalog"):WaitForChild("Looks"))
local Messages = require(Shared:WaitForChild("Catalog"):WaitForChild("Messages"))
local Regions = require(Shared:WaitForChild("Catalog"):WaitForChild("Regions"))
local Trials = require(Shared:WaitForChild("Catalog"):WaitForChild("Trials"))
local Relics = require(Shared:WaitForChild("Catalog"):WaitForChild("Relics"))
local Sites = require(Shared:WaitForChild("Catalog"):WaitForChild("Sites"))
local World = require(Shared:WaitForChild("Catalog"):WaitForChild("World"))

local folder = Instance.new("Folder")
folder.Name = "Playtest"
local cmd = Instance.new("RemoteEvent")
cmd.Name = "Cmd"
cmd.Parent = folder
local report = Instance.new("RemoteEvent")
report.Name = "Report"
report.Parent = folder
folder.Parent = ReplicatedStorage

local passed, failed = 0, 0
local failures = {}

local function log(message: string)
	print("[PLAYTEST] " .. message)
end

local function check(name: string, ok: boolean, detail: string?): boolean
	if ok then
		passed += 1
		log("PASS " .. name)
	else
		failed += 1
		table.insert(failures, name)
		log("FAIL " .. name .. (if detail then " -- " .. detail else ""))
	end
	return ok
end

-- What each client reported.
local ready = {}
local notes = {} -- player -> { { code, args } }
local claimPayload = {} -- player -> last ClaimUpdate payload (nil = closed)
local hitFx = {} -- player -> count of HitFx seen
local uiReport = {} -- player -> last UI snapshot
local cooldowns = {} -- player -> { { slot, seconds, at } }, each AbilityCooldown seen
local offers = {} -- player -> last TrialOffer view
local edictResults = {} -- player -> last EdictResult
local edictSyncs = {} -- player -> { veilSeconds, met } of the last EdictSync
local shopViews = {} -- player -> last ShopOpen view
local tradeInvites = {} -- player -> last TradeInvite (false = closed, nil = never seen)
local tradeViews = {} -- player -> last TradeSync view (false = closed, nil = never seen)
local partyInvites = {} -- player -> last PartyInvite (false = closed, nil = never seen)
local partySyncs = {} -- player -> last PartySync (false = none, nil = never seen)
local ceremonies = {} -- player -> last Ceremony payload
local renounceOffers = {} -- player -> last RenounceOffer (false = closed, nil = never seen)
local presses = {} -- player -> what a pressed button looked like right after the press (M8)
local agentErrors = {}
local renderNotes = {} -- each time a client stopped or started drawing frames

report.OnServerEvent:Connect(function(player, kind, a, b)
	if kind == "ready" then
		ready[player] = true
	elseif kind == "notify" then
		notes[player] = notes[player] or {}
		table.insert(notes[player], { code = a, args = b })
	elseif kind == "cooldown" then
		cooldowns[player] = cooldowns[player] or {}
		table.insert(cooldowns[player], { slot = a, seconds = b, at = os.clock() })
	elseif kind == "claim" then
		claimPayload[player] = a
	elseif kind == "offer" then
		offers[player] = a
	elseif kind == "hitfx" then
		hitFx[player] = (hitFx[player] or 0) + 1
	elseif kind == "edictResult" then
		edictResults[player] = a
	elseif kind == "edictSync" then
		edictSyncs[player] = { veilSeconds = a, met = b }
	elseif kind == "shop" then
		shopViews[player] = a
	elseif kind == "tradeInvite" then
		tradeInvites[player] = if a == nil then false else a
	elseif kind == "tradeSync" then
		tradeViews[player] = if a == nil then false else a
	elseif kind == "partyInvite" then
		partyInvites[player] = if a == nil then false else a
	elseif kind == "partySync" then
		partySyncs[player] = if a == nil then false else a
	elseif kind == "ceremony" then
		ceremonies[player] = a
	elseif kind == "renounceOffer" then
		renounceOffers[player] = if a == nil then false else a
	elseif kind == "ui" then
		uiReport[player] = a
	elseif kind == "pressed" then
		presses[player] = a
	elseif kind == "error" then
		table.insert(agentErrors, player.Name .. ": " .. tostring(a))
		log("agent error from " .. player.Name .. ": " .. tostring(a))
	elseif kind == "promptTrace" then
		-- What the client saw of a prompt it held (see the agent's holdPrompt).
		log(`prompt {player.Name} {tostring(a)}`)
	elseif kind == "render" then
		-- A client stopped (or started again) drawing frames. In run 1 every prompt hold after
		-- the display went to sleep did nothing, so say so where the failures will be read.
		local text = if a == true
			then `{player.Name} draws frames again ({tostring(b)} a second)`
			else `{player.Name} has stopped drawing frames ({tostring(b)} simulated a second): display asleep or window hidden? Prompt checks from here on are not trustworthy`
		table.insert(renderNotes, string.format("%.0f s: %s", os.clock(), text))
		log("RENDER " .. text)
	end
end)

local function waitFor(predicate: () -> boolean, timeout: number): boolean
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		if predicate() then
			return true
		end
		task.wait(0.1)
	end
	return predicate()
end

local function mark(player: Player): number
	return #(notes[player] or {})
end

local function noteSince(player: Player, from: number, code: string)
	local list = notes[player] or {}
	for i = from + 1, #list do
		if list[i].code == code then
			return list[i]
		end
	end
	return nil
end

local function codesSince(player: Player, from: number): string
	local list = notes[player] or {}
	local codes = {}
	for i = from + 1, #list do
		table.insert(codes, list[i].code)
	end
	return "[" .. table.concat(codes, ", ") .. "]"
end

local function expectNote(
	name: string,
	player: Player,
	from: number,
	code: string,
	timeout: number?
)
	local ok = waitFor(function()
		return noteSince(player, from, code) ~= nil
	end, timeout or 3)
	check(name, ok, player.Name .. " got " .. codesSince(player, from))
	return noteSince(player, from, code)
end

local function expectNoNote(name: string, player: Player, from: number, code: string)
	task.wait(1.5)
	check(
		name,
		noteSince(player, from, code) == nil,
		player.Name .. " got " .. codesSince(player, from)
	)
end

local function send(player: Player, op: string, arg: any?)
	cmd:FireClient(player, op, arg)
end

-- Taps a button on the player's screen (a path like "MenuGui/LedgerButton") through the agent's
-- press seam. Returns { path, ok, active, text }: ok is whether the button's handler ran, active
-- and text are read right after it. {} when the agent did not answer within 3 seconds.
local function press(player: Player, path: string)
	presses[player] = nil
	send(player, "press", path)
	waitFor(function()
		return presses[player] ~= nil
	end, 3)
	return presses[player] or {}
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function health(player: Player): number
	local humanoid = humanoidOf(player)
	return if humanoid ~= nil then humanoid.Health else -1
end

local function waitAlive(player: Player): boolean
	return waitFor(function()
		local humanoid = humanoidOf(player)
		return humanoid ~= nil and humanoid.Health > 0 and rootOf(player) ~= nil
	end, 20)
end

local function place(player: Player, position: Vector3, face: Vector3)
	local root = rootOf(player)
	if root == nil then
		return
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.lookAt(position, Vector3.new(face.X, position.Y, face.Z))
end

-- Puts `a` at `center` and `b` 4 studs in front of it, facing each other.
local function faceOff(a: Player, b: Player, center: Vector3)
	local pa = center
	local pb = center + Vector3.new(0, 0, -4)
	place(a, pa, pb)
	place(b, pb, pa)
	task.wait(0.6)
end

local function inspect(player: Player)
	uiReport[player] = nil
	send(player, "inspect")
	waitFor(function()
		return uiReport[player] ~= nil
	end, 5)
	return uiReport[player] or {}
end

local function hasLine(ui, text: string): boolean
	for _, line in ui.statusLines or {} do
		if string.find(line, text, 1, true) then
			return true
		end
	end
	return false
end

-- The HUD redraws twice a second, so give a status line up to 3 seconds to appear.
local function inspectForLine(player: Player, text: string)
	local ui = inspect(player)
	local deadline = os.clock() + 3
	while not hasLine(ui, text) and os.clock() < deadline do
		task.wait(0.4)
		ui = inspect(player)
	end
	return ui
end

local function strike(attacker: Player)
	send(attacker, "strike")
	task.wait(0.9)
end

-- Strikes until the victim is defeated (re-facing before each Strike). True on a defeat.
local function defeat(attacker: Player, victim: Player, center: Vector3): boolean
	for _ = 1, 14 do
		if health(victim) <= 0 then
			return true
		end
		faceOff(attacker, victim, center)
		strike(attacker)
	end
	return health(victim) <= 0
end

local function totals(players: { Player }): { [string]: number }
	local result = {}
	for _, relic in Relics.list do
		local count = 0
		for _, player in players do
			local ledger = LedgerService.get(player)
			if ledger ~= nil then
				count += Ledger.count(ledger, relic.id)
			end
		end
		result[relic.id] = count
	end
	return result
end

local function sameTotals(x, y): boolean
	for id, count in x do
		if y[id] ~= count then
			return false
		end
	end
	return true
end

local OUTSIDE = Vector3.new(150, 3, 150)
local OUTSIDE_2 = Vector3.new(-150, 3, 150)
local IN_TOWN = Vector3.new(10, 3, 12)

------------------------------------------------------------------------------- M3 helpers

local B_TOWN = Vector3.new(-10, 3, 12) -- B's spot in Tallyport while A stands at IN_TOWN
-- Training post 1 stands at (55, 0, 0). From here, facing -z, it is 6 studs ahead and 2 to
-- the side: in the Strike's reach and arc, and beside Lunge's path. A dash stops short of
-- anything solid in its way, so Lunge can hit a post it passes beside, never one dead ahead.
local POST1_STAND = Vector3.new(53, 3, 6)
local POST1_FACE = Vector3.new(53, 3, -6)
local POST4_STAND = Vector3.new(-53, 3, 6) -- the same for post 4 at (-55, 0, 0)
local POST4_FACE = Vector3.new(-53, 3, -6)
local EMPTY_BAR = "—" -- what the ability bar shows in an empty slot
local CAST_GAP = 0.45 -- the server needs 0.3 s between any two casts

local function levelOf(player: Player, path: string): number
	local progress = PathService.get(player)
	return if progress ~= nil then PathProgress.level(progress, path) else -1
end

local function xpOf(player: Player, path: string): number
	local progress = PathService.get(player)
	return if progress ~= nil then progress.xp[path] or 0 else -1
end

local function slotHas(player: Player, slot: number, abilityId: string): boolean
	local progress = PathService.get(player)
	return progress ~= nil and progress.loadout[slot] == abilityId
end

-- The saved loadout as "{lunge, -, -, -}".
local function loadoutText(player: Player): string
	local progress = PathService.get(player)
	if progress == nil then
		return "no data"
	end
	local parts = {}
	for slot = 1, 4 do
		local id = progress.loadout[slot]
		table.insert(parts, if id == nil or id == "" then "-" else id)
	end
	return "{" .. table.concat(parts, ", ") .. "}"
end

local function noteWith(player: Player, from: number, code: string, key: string, value: string)
	local list = notes[player] or {}
	for i = from + 1, #list do
		local entry = list[i]
		if entry.code == code and entry.args ~= nil and entry.args[key] == value then
			return entry
		end
	end
	return nil
end

-- A UI snapshot trails the server by a sync and a redraw: poll it for up to 3 seconds.
local function inspectUntil(player: Player, predicate: (any) -> boolean)
	local ui = inspect(player)
	local deadline = os.clock() + 3
	while not predicate(ui) and os.clock() < deadline do
		task.wait(0.3)
		ui = inspect(player)
	end
	return ui
end

local function barText(ui, slot: number): string
	return (ui.abilitySlots or {})[slot] or "?"
end

local function barDump(ui): string
	return "bar [" .. table.concat(ui.abilitySlots or {}, " | ") .. "]"
end

-- One Path row of the Paths panel: { header, detail, button }.
local function rowOf(ui, path: string)
	return (ui.pathRows or {})[path] or { header = "", detail = "", button = "" }
end

local function has(text: string?, part: string): boolean
	return text ~= nil and string.find(text, part, 1, true) ~= nil
end

local function heal(player: Player)
	local humanoid = humanoidOf(player)
	if humanoid ~= nil then
		humanoid.Health = humanoid.MaxHealth
	end
end

local function walkSpeed(player: Player): number
	local humanoid = humanoidOf(player)
	return if humanoid ~= nil then humanoid.WalkSpeed else -1
end

-- The lowest WalkSpeed the server gives the player over the next `seconds`.
local function lowestWalkSpeed(player: Player, seconds: number): number
	local lowest = walkSpeed(player)
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		task.wait(0.05)
		lowest = math.min(lowest, walkSpeed(player))
	end
	return lowest
end

local function positionOf(player: Player): Vector3
	local root = rootOf(player)
	return if root ~= nil then root.Position else Vector3.new(0 / 0, 0 / 0, 0 / 0)
end

local function flatDistance(p: Vector3, q: Vector3): number
	return Vector3.new(p.X - q.X, 0, p.Z - q.Z).Magnitude
end

local function fmt(value: number): string
	return string.format("%.1f", value)
end

local function at(p: Vector3): string
	return `({fmt(p.X)}, {fmt(p.Y)}, {fmt(p.Z)})`
end

-- Ability casts. The server answers each accepted cast with AbilityCooldown(slot, seconds);
-- the driver waits that out (and the gap after any cast) before casting the same ability
-- again, so a refused cast in a check is never the driver's own timing.
local readyAt = {} -- player -> { [abilityId]: os.clock() when the driver may cast it again }
local lastCastAt = {} -- player -> os.clock() of the last accepted cast

local function cooldownCount(player: Player): number
	return #(cooldowns[player] or {})
end

local function abilityIn(player: Player, slot: number): string
	local progress = PathService.get(player)
	return if progress ~= nil then progress.loadout[slot] or "" else ""
end

local function secondsUntilReady(player: Player, slot: number): number
	local times = readyAt[player] or {}
	local gapEnds = (lastCastAt[player] or -math.huge) + CAST_GAP
	return math.max(times[abilityIn(player, slot)] or 0, gapEnds) - os.clock()
end

local function waitReady(player: Player, slot: number)
	local delay = secondsUntilReady(player, slot)
	if delay > 0 then
		task.wait(delay)
	end
end

-- Casts `slot` through the game's CastAbility once it is ready. True when the server took
-- the cast (its AbilityCooldown came back); by then the cast's first hit has been applied.
local function cast(player: Player, slot: number): boolean
	waitReady(player, slot)
	local id = abilityIn(player, slot)
	local before = cooldownCount(player)
	send(player, "cast", slot)
	local accepted = waitFor(function()
		return cooldownCount(player) > before
	end, 2)
	if accepted then
		local event = cooldowns[player][before + 1]
		local times = readyAt[player] or {}
		times[id] = event.at + event.seconds + 0.2
		readyAt[player] = times
		lastCastAt[player] = event.at
	end
	return accepted
end

-- Sets one loadout slot through the game's LoadoutAction. The player must be in Tallyport.
local function equip(player: Player, slot: number, abilityId: string)
	local from = mark(player)
	send(player, "loadout", { slot = slot, abilityId = abilityId })
	check(
		`M3 setup: {player.Name} equips {abilityId} in slot {slot}`,
		waitFor(function()
			return slotHas(player, slot, abilityId)
		end, 3),
		`{loadoutText(player)}; {player.Name} got {codesSince(player, from)}`
	)
end

------------------------------------------------------------------------------- M4 helpers

local HOUND_1, HOUND_2, HOUND_3 = -2000001, -2000002, -2000003
local SHELLBACK_1 = -2000013 -- den 5, beside the Shell Warden
local BOGSPITTER_1 = -2000019
local COLOSSUS = -2000025
-- Added to the trial clocks, so the driver can skip a run's time and a cooldown.
local clockSkip, realSkip = 0, 0

local function creatureBody(id: number): (Humanoid?, BasePart?)
	return Fighters.body(id)
end

local function creatureHealth(id: number): number
	local humanoid = creatureBody(id)
	return if humanoid ~= nil then humanoid.Health else -1
end

local function denOf(id: number): Vector3
	local slot = World.creatureSlots[World.creatureIndex(id)]
	local p = World.dens[slot.den].position
	return Vector3.new(p.x, 3, p.z)
end

-- A spot `distance` from `center` on land with a clear line back to it.
local function clearSpot(center: Vector3, distance: number): Vector3
	for step = 0, 15 do
		local angle = step * math.pi / 8
		local spot = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		if Geography.isLand(spot.X, spot.Z) and Sight.inSight(spot, center, nil) then
			return spot
		end
	end
	return center + Vector3.new(distance, 0, 0)
end

-- A fresh den creature that stands still (not in the active set), at the given health.
local function freshCreature(id: number, healthNow: number?): boolean
	CreatureService.respawn(id)
	task.wait(0.3)
	local humanoid = creatureBody(id)
	if humanoid == nil then
		return false
	end
	if healthNow ~= nil then
		humanoid.Health = healthNow
	end
	return true
end

-- What the game's Strike would hit from `spot`, facing `target`: the server's own sight filter
-- and Combat.pickTarget over every fighter the player may hit (taunts aside).
local function strikePick(player: Player, spot: Vector3, target: Vector3): number?
	local look = Vector3.new(target.X - spot.X, 0, target.Z - spot.Z)
	if not (look.Magnitude > 0) then
		return nil
	end
	look = look.Unit
	local attacker = {
		id = player.UserId,
		position = { x = spot.X, y = spot.Y, z = spot.Z },
		look = { x = look.X, y = 0, z = look.Z },
	}
	local others = Sight.filter(spot, Fighters.list(player.UserId))
	return Combat.pickTarget(attacker, others, nil, nil)
end

-- Every fighter within `radius` (level) of `center`, nearest first, for the log.
local function fightersNear(player: Player, center: Vector3, radius: number): string
	local found = {}
	for _, other in Fighters.list(player.UserId) do
		local p = Vector3.new(other.position.x, other.position.y, other.position.z)
		local d = flatDistance(p, center)
		if d <= radius then
			local entry = Fighters.get(other.id)
			table.insert(found, {
				d = d,
				text = `{other.id} {if entry ~= nil then entry.kind else "?"} at {at(p)} ({fmt(d)} studs, health {fmt(
					other.health or -1
				)})`,
			})
		end
	end
	table.sort(found, function(a, b)
		return a.d < b.d
	end)
	local lines = {}
	for _, f in found do
		table.insert(lines, f.text)
	end
	return if #lines > 0 then table.concat(lines, "; ") else "none"
end

-- A spot 4 studs from the creature (on land, in clear sight) from which the game's own Strike
-- picks that creature: a sleeping den-mate parked nearer in the arc would take the hit instead.
-- Falls back to clearSpot (and logs why) when no spot qualifies.
local function strikeSpot(player: Player, id: number, target: Vector3): Vector3
	local plain = clearSpot(target, 4)
	local plainPick = strikePick(player, plain, target)
	if plainPick == id then
		return plain
	end
	log(
		`strikeCreature {player.Name} -> {id}: from {at(plain)} the Strike would take {tostring(
			plainPick
		)}; fighters near: {fightersNear(player, target, 10)}`
	)
	for step = 0, 15 do
		local angle = step * math.pi / 8
		local spot = target + Vector3.new(math.cos(angle) * 4, 0, math.sin(angle) * 4)
		if
			Geography.isLand(spot.X, spot.Z)
			and Sight.inSight(spot, target, nil)
			and strikePick(player, spot, target) == id
		then
			log(`strikeCreature {player.Name} -> {id}: using {at(spot)} instead`)
			return spot
		end
	end
	log(`strikeCreature {player.Name} -> {id}: no spot picks it; using {at(plain)}`)
	return plain
end

-- Stands the player 4 studs from the creature, facing it, and Strikes. A teleport across the
-- island can take a moment to settle, so a Strike that changed nothing is tried once more.
-- `once`: for checks that expect the Strike to change nothing.
local function strikeCreature(player: Player, id: number, once: boolean?)
	for attempt = 1, if once then 1 else 3 do
		local _, root = creatureBody(id)
		if root == nil then
			return
		end
		local before = creatureHealth(id)
		local target = Vector3.new(root.Position.X, 3, root.Position.Z)
		local spot = strikeSpot(player, id, target)
		place(player, spot, target)
		waitFor(function()
			return flatDistance(positionOf(player), spot) <= 1.5
		end, 2)
		task.wait(0.5)
		strike(player)
		if creatureHealth(id) ~= before then
			return
		end
		if not once then
			-- Evidence for a Strike that changed nothing: where everyone stood and what the
			-- game's targeting picks from where the player really is.
			local here = positionOf(player)
			local me = Fighters.fighter(player.UserId)
			local look = if me ~= nil
				then Vector3.new(me.look.x, 0, me.look.z)
				else Vector3.new(0 / 0, 0, 0)
			log(
				`strikeCreature {player.Name} -> {id} attempt {attempt} changed nothing: player at {at(
					here
				)} look {at(look)}, creature at {at(root.Position)} health {fmt(
					creatureHealth(id)
				)}, pick now {tostring(strikePick(player, here, root.Position))}; fighters near: {fightersNear(
					player,
					root.Position,
					10
				)}`
			)
		end
	end
end

local function coinOf(player: Player): number
	local data = DataService.get(player)
	return if data ~= nil then data.coin else -1
end

local function questStepOf(player: Player): number
	local data = DataService.get(player)
	return if data ~= nil then data.trials.questStep else -1
end

local function hasFree(player: Player, relicId: string): boolean
	local ledger = LedgerService.get(player)
	return ledger ~= nil and table.find(ledger.free, relicId) ~= nil
end

local function beside(position, offset: Vector3?): Vector3
	return Vector3.new(position.x, position.y + 3, position.z) + (offset or Vector3.new(3, 0, 0))
end

-- Talks to a Warden and returns the offer window's data as the client received it.
local function talkTo(player: Player, trialId: string)
	offers[player] = nil
	place(player, beside(World.wardens[trialId]), beside(World.wardens[trialId], Vector3.zero))
	task.wait(0.4)
	send(player, "warden", trialId)
	waitFor(function()
		return offers[player] ~= nil
	end, 4)
	return offers[player] or {}
end

-- Accepts a trial beside its Warden. True when the run started.
local function acceptTrial(player: Player, trialId: string): boolean
	place(player, beside(World.wardens[trialId]), beside(World.wardens[trialId], Vector3.zero))
	task.wait(0.4)
	local from = mark(player)
	send(player, "accept", trialId)
	return waitFor(function()
		return noteSince(player, from, "TRIAL_STARTED") ~= nil
	end, 3)
end

local function runProgress(player: Player): number
	local current = TrialService.run(player)
	return if current ~= nil then current.progress else -1
end

local function championOf(player: Player): Instance?
	for _, model in CollectionService:GetTagged("Creature") do
		if
			model:GetAttribute("OwnerUserId") == player.UserId and model:IsDescendantOf(workspace)
		then
			return model
		end
	end
	return nil
end

-- Creatures, trials and the quest. Every creature is asleep except the one a check wakes.
local function runM4(A: Player, B: Player)
	TrialService.setClocks(function()
		return os.clock() + clockSkip
	end, function()
		return os.time() + realSkip
	end)
	CreatureService.setRng(function()
		return 0.99
	end)
	waitAlive(A)
	waitAlive(B)
	LedgerService.set(A, { claimed = {}, free = {} })
	LedgerService.set(B, { claimed = {}, free = {} })
	local dataA, dataB = DataService.get(A), DataService.get(B)
	dataA.trials = { cooldowns = {}, questStep = 0 }
	dataB.trials = { cooldowns = {}, questStep = 0 }

	-- M4.1: the world.
	local models = 0
	for _, model in CollectionService:GetTagged("Creature") do
		if model:IsDescendantOf(workspace) then
			models += 1
		end
	end
	check("M4.1 26 creatures stand at their dens", models == 26, tostring(models))
	local wrong = {}
	for _, slot in World.creatureSlots do
		local humanoid = creatureBody(slot.id)
		local kind = Creatures.byId[slot.kind]
		if
			humanoid == nil
			or humanoid.MaxHealth ~= kind.health
			or humanoid.Health ~= kind.health
		then
			table.insert(wrong, tostring(slot.id))
		end
	end
	check("M4.1 every creature has its catalog health", #wrong == 0, table.concat(wrong, ", "))
	local wardenWanted, markerWanted = 0, 0
	for _, trial in Trials.list do
		if World.wardens[trial.id] ~= nil then
			wardenWanted += 1
		end
		local course = World.courses[trial.id]
		if course ~= nil then
			markerWanted += #course
		end
	end
	local wardenCount = #CollectionService:GetTagged("Warden")
	local markerCount = #CollectionService:GetTagged("TrialMarker")
	check(
		"M4.1 one Warden per trial",
		wardenCount == wardenWanted,
		`{wardenCount} of {wardenWanted}`
	)
	check(
		"M4.1 every course marker is built",
		markerCount == markerWanted,
		`{markerCount} of {markerWanted}`
	)

	-- M4.2: wander, notice, chase, bite.
	local den = denOf(HOUND_1)
	-- A may still be Marked from the fights of M2 and M3: what matters is that M4 adds no time.
	local function markedUntil(player: Player): number
		local protection = ProtectionService.status(player, os.clock())
		return if protection ~= nil then protection.markedUntil else -1
	end
	local markedBefore = markedUntil(A)
	place(A, IN_TOWN, B_TOWN)
	place(B, B_TOWN, IN_TOWN)
	CreatureService.setActive({ HOUND_1 })
	local strayed = 0
	for _ = 1, 25 do
		task.wait(0.2)
		local info = CreatureService.info(HOUND_1)
		if info ~= nil and info.position ~= nil then
			strayed = math.max(strayed, flatDistance(info.position, den))
		end
	end
	check("M4.2 an idle Brinehound stays within 14 studs of its den", strayed <= 14, fmt(strayed))
	check("M4.2 it wanders", strayed > 0.5, fmt(strayed))

	ProtectionService.endRespawnShield(A)
	heal(A)
	place(A, clearSpot(den, 20), den)
	local chased = waitFor(function()
		local info = CreatureService.info(HOUND_1)
		return info ~= nil and info.mode == "chase" and info.targetId == A.UserId
	end, 6)
	local seenInfo = CreatureService.info(HOUND_1)
	check(
		"M4.2 it notices A 20 studs away and chases",
		chased,
		if seenInfo ~= nil then `{seenInfo.mode}, target {seenInfo.targetId}` else "no creature"
	)
	local before = health(A)
	local bitten = waitFor(function()
		return health(A) < before - 1
	end, 10)
	local lost = before - health(A)
	check("M4.2 its Bite takes 8", bitten and lost >= 7 and lost <= 9, fmt(lost))
	check(
		"M4.2 being bitten Marks nobody",
		markedUntil(A) == markedBefore,
		`{fmt(markedBefore)} -> {fmt(markedUntil(A))}`
	)

	-- M4.3: A hits it, then runs: it walks home, cannot be hurt on the way, and heals.
	strikeCreature(A, HOUND_1)
	local hurt = creatureHealth(HOUND_1)
	check("M4.3 A's Strike takes 20 from the Brinehound", hurt >= 39 and hurt <= 41, fmt(hurt))
	check(
		"M4.3 hitting a creature does not Mark A",
		markedUntil(A) == markedBefore,
		`{fmt(markedBefore)} -> {fmt(markedUntil(A))}`
	)
	place(A, den + Vector3.new(0, 0, 0) + (clearSpot(den, 20) - den).Unit * 75, den)
	local returning = waitFor(function()
		local info = CreatureService.info(HOUND_1)
		return info ~= nil and info.mode == "return"
	end, 4)
	check("M4.3 past 60 studs from the den it gives up", returning)
	local onTheWay = creatureHealth(HOUND_1)
	strikeCreature(A, HOUND_1, true)
	check(
		"M4.3 it cannot be hurt while walking home",
		creatureHealth(HOUND_1) >= onTheWay,
		`{fmt(onTheWay)} -> {fmt(creatureHealth(HOUND_1))}`
	)
	place(A, IN_TOWN, B_TOWN)
	local home = waitFor(function()
		local info = CreatureService.info(HOUND_1)
		return info ~= nil and info.mode == "wander" and creatureHealth(HOUND_1) == 60
	end, 12)
	check("M4.3 home again it is at full health", home, fmt(creatureHealth(HOUND_1)))
	CreatureService.setActive({})

	-- M4.4: rewards for everyone who helped.
	check("M4.4 setup: a Shellback at 40 health", freshCreature(SHELLBACK_1, 40))
	ProtectionService.endRespawnShield(B)
	local coinA, coinB = coinOf(A), coinOf(B)
	local callingA, callingB = PathService.get(A).calling, PathService.get(B).calling
	local xpA, xpB = xpOf(A, callingA), xpOf(B, callingB)
	local ma, mb = mark(A), mark(B)
	strikeCreature(A, SHELLBACK_1)
	check(
		"M4.4 A's Strike leaves it at 20",
		math.abs(creatureHealth(SHELLBACK_1) - 20) <= 1,
		fmt(creatureHealth(SHELLBACK_1))
	)
	-- A steps away first: B's Strike takes the nearest fighter in its arc, and that must be
	-- the Shellback, not A standing on the same spot.
	place(A, OUTSIDE, OUTSIDE_2)
	task.wait(0.3)
	strikeCreature(B, SHELLBACK_1)
	local paidA =
		expectNote("M4.4 A is told the Shellback is defeated", A, ma, "CREATURE_DEFEATED", 4)
	expectNote("M4.4 B is told too", B, mb, "CREATURE_DEFEATED", 4)
	check(
		"M4.4 the message names it and the Coin",
		paidA ~= nil and paidA.args.creature == "Shellback" and paidA.args.coin == "10"
	)
	check(
		"M4.4 both get the full 10 Coin",
		coinOf(A) == coinA + 10 and coinOf(B) == coinB + 10,
		`A {coinA} -> {coinOf(A)}, B {coinB} -> {coinOf(B)}`
	)
	check(
		"M4.4 both get XP on their Calling (the Strike counts as it)",
		xpOf(A, callingA) > xpA and xpOf(B, callingB) > xpB,
		`A {callingA} {xpA} -> {xpOf(A, callingA)}, B {callingB} {xpB} -> {xpOf(B, callingB)}`
	)
	local uiCoin = inspectUntil(A, function(ui)
		return ui.coin == "Coin: " .. tostring(coinOf(A))
	end)
	check(
		"M4.4 A's Coin line shows it",
		uiCoin.coin == "Coin: " .. tostring(coinOf(A)),
		tostring(uiCoin.coin)
	)
	check(
		"M4.4 the Shellback is gone",
		waitFor(function()
			return creatureBody(SHELLBACK_1) == nil
		end, 3)
	)

	-- M4.5: drops obey the roll, the server cap and the free slots.
	CreatureService.setRng(function()
		return 0
	end)
	check("M4.5 setup: a Brinehound at 15 health", freshCreature(HOUND_2, 15))
	ma = mark(A)
	strikeCreature(A, HOUND_2)
	if creatureBody(HOUND_2) ~= nil then
		strikeCreature(A, HOUND_2)
	end
	local got = expectNote("M4.5 a winning roll gives the drop: GOT_CARD", A, ma, "GOT_CARD", 4)
	check(
		"M4.5 it is the Brine-Fang Charm, in A's free slots",
		got ~= nil and got.args.name == "Brine-Fang Charm" and hasFree(A, "R019")
	)
	LedgerService.set(B, { claimed = {}, free = { "R019", "R019", "R019" } })
	check("M4.5 setup: another Brinehound at 15 health", freshCreature(HOUND_3, 15))
	ma = mark(A)
	coinA = coinOf(A)
	strikeCreature(A, HOUND_3)
	expectNote("M4.5 with 4 held on the server the drop is sealed", A, ma, "REWARD_SEALED", 4)
	check("M4.5 the Coin is still paid", coinOf(A) == coinA + 4, `{coinA} -> {coinOf(A)}`)
	local full = {}
	for _ = 1, Ledger.FREE_SLOTS do
		table.insert(full, "R001")
	end
	LedgerService.set(A, { claimed = {}, free = full })
	check("M4.5 setup: a Bogspitter at 15 health", freshCreature(BOGSPITTER_1, 15))
	ma = mark(A)
	strikeCreature(A, BOGSPITTER_1)
	expectNote("M4.5 with full free slots the drop is lost", A, ma, "REWARD_LOST", 4)
	LedgerService.set(A, { claimed = {}, free = {} })
	LedgerService.set(B, { claimed = {}, free = {} })
	CreatureService.setRng(function()
		return 0.99
	end)
	check("M4.5 setup: a Brinehound at 15 health", freshCreature(HOUND_2, 15))
	ma = mark(A)
	strikeCreature(A, HOUND_2)
	expectNote("M4.5 a losing roll still pays Coin", A, ma, "CREATURE_DEFEATED", 4)
	check("M4.5 and gives no Relic", noteSince(A, ma, "GOT_CARD") == nil and not hasFree(A, "R019"))

	-- M4.6: a creature's last blow is nobody's defeat.
	check("M4.6 setup: a fresh Brinehound", freshCreature(HOUND_1, nil))
	den = denOf(HOUND_1)
	local arena = clearSpot(den, 8)
	ProtectionService.endRespawnShield(A)
	ProtectionService.endRespawnShield(B)
	heal(A)
	faceOff(B, A, OUTSIDE)
	strike(B)
	check("M4.6 setup: B hits A", health(A) < 100, fmt(health(A)))
	ma, mb = mark(A), mark(B)
	local xpBefore = xpOf(B, callingB)
	place(B, IN_TOWN, B_TOWN)
	place(A, arena, den)
	local humanoidA = humanoidOf(A)
	if humanoidA ~= nil then
		humanoidA.Health = 5
	end
	CreatureService.setActive({ HOUND_1 })
	check(
		"M4.6 the Brinehound defeats A",
		waitFor(function()
			return health(A) <= 0
		end, 12)
	)
	CreatureService.setActive({})
	task.wait(1.5)
	check(
		"M4.6 B gets no claim and A is told of none",
		noteSince(B, mb, "CLAIM_STARTED") == nil
			and noteSince(B, mb, "CLAIM_COOLDOWN") == nil
			and noteSince(A, ma, "DEFEATED_BY") == nil,
		`B {codesSince(B, mb)}, A {codesSince(A, ma)}`
	)
	check("M4.6 nobody gets defeat XP", xpOf(B, callingB) == xpBefore)
	waitAlive(A)
	task.wait(0.5)
	check(
		"M4.6 A respawns in Tallyport",
		flatDistance(positionOf(A), Vector3.zero) <= World.townRadius,
		at(positionOf(A))
	)
	ProtectionService.endRespawnShield(A)

	-- M4.7: Tidewalk, from the offer to the cooldown.
	local offer = talkTo(A, "tidewalk")
	check(
		"M4.7 the Harbour Warden offers Tidewalk",
		offer.title == "Tidewalk" and offer.canStart == true,
		`{tostring(offer.title)}, canStart {tostring(offer.canStart)}`
	)
	local uiOffer = inspectUntil(A, function(ui)
		return ui.offerVisible == true
	end)
	check(
		"M4.7 the window shows it with Accept on",
		uiOffer.offerVisible == true
			and uiOffer.offerTitle == "Tidewalk"
			and uiOffer.acceptActive == true,
		`{tostring(uiOffer.offerTitle)}, {tostring(uiOffer.offerRelic)}`
	)
	send(A, "closeOffer")
	for _, bad in { "nope", 5, { "tidewalk" } } :: { any } do
		ma = mark(A)
		send(A, "accept", bad)
		expectNote(`M4.7 hostile accept ({typeof(bad)}): BAD_REQUEST`, A, ma, "BAD_REQUEST")
	end
	ma = mark(A)
	send(A, "accept", nil)
	expectNote("M4.7 hostile accept (nothing): BAD_REQUEST", A, ma, "BAD_REQUEST")
	place(A, beside(World.wardens.tidewalk, Vector3.new(20, 0, 0)), Vector3.zero)
	task.wait(0.4)
	ma = mark(A)
	send(A, "accept", "tidewalk")
	expectNote("M4.7 from 20 studs: TOO_FAR", A, ma, "TOO_FAR")
	check("M4.7 nothing started", TrialService.run(A) == nil)

	coinA = coinOf(A)
	xpA = xpOf(A, callingA)
	ma = mark(A)
	check("M4.7 accepting beside the Warden starts it", acceptTrial(A, "tidewalk"))
	local uiRun = inspectUntil(A, function(ui)
		return has((ui.trialLines or {})[1], "marker 0 / 6")
	end)
	check(
		"M4.7 the HUD reads Tidewalk: marker 0 / 6",
		(uiRun.trialLines or {})[1] == "Tidewalk: marker 0 / 6",
		table.concat(uiRun.trialLines or {}, " | ")
	)
	local markers = World.courses.tidewalk
	check(
		"M4.7 the beacon stands at marker 1",
		uiRun.beacon ~= nil
			and math.abs(uiRun.beacon.x - markers[1].x) < 0.5
			and math.abs(uiRun.beacon.z - markers[1].z) < 0.5
	)
	place(A, Vector3.new(markers[2].x, markers[2].y, markers[2].z), Vector3.zero)
	task.wait(0.6)
	check("M4.7 marker 2 first does not count", runProgress(A) == 0, tostring(runProgress(A)))
	for index, marker in markers do
		place(A, Vector3.new(marker.x, marker.y, marker.z), Vector3.zero)
		waitFor(function()
			return runProgress(A) >= index or TrialService.run(A) == nil
		end, 2)
	end
	local passedNote = expectNote("M4.7 all six in order: TRIAL_PASSED", A, ma, "TRIAL_PASSED", 4)
	check(
		"M4.7 the message names the trial and its Coin",
		passedNote ~= nil and passedNote.args.name == "Tidewalk" and passedNote.args.coin == "30"
	)
	check("M4.7 A has the Low-Tide Tally Stick", hasFree(A, "R013"))
	check("M4.7 +30 Coin", coinOf(A) == coinA + 30, `{coinA} -> {coinOf(A)}`)
	check("M4.7 Calling XP rose", xpOf(A, callingA) > xpA)
	check("M4.7 the quest moved to step 1", questStepOf(A) == 1, tostring(questStepOf(A)))
	expectNote("M4.7 A is told the quest step", A, ma, "QUEST_STEP")

	ma = mark(A)
	place(A, beside(World.wardens.tidewalk), Vector3.zero)
	task.wait(0.4)
	send(A, "accept", "tidewalk")
	expectNote("M4.7 again at once: TRIAL_COOLDOWN", A, ma, "TRIAL_COOLDOWN")
	offer = talkTo(A, "tidewalk")
	check(
		"M4.7 the offer says when to try again",
		offer.canStart == false
			and (offer.note == "Try again in 5:00." or has(offer.note, "Try again in 4:5")),
		tostring(offer.note)
	)
	send(A, "closeOffer")
	realSkip += 301
	check("M4.7 after 5 minutes it can be taken again", acceptTrial(A, "tidewalk"))

	-- M4.8: one trial at a time; out of time.
	ma = mark(A)
	place(A, beside(World.wardens.gullstep_climb), Vector3.zero)
	task.wait(0.4)
	send(A, "accept", "gullstep_climb")
	expectNote("M4.8 a second trial: TRIAL_BUSY", A, ma, "TRIAL_BUSY")
	ma = mark(A)
	clockSkip += 61
	expectNote("M4.8 past its 60 seconds: TRIAL_FAILED_TIME", A, ma, "TRIAL_FAILED_TIME")
	check("M4.8 the run is over", TrialService.run(A) == nil)
	ma = mark(A)
	place(A, beside(World.wardens.tidewalk), Vector3.zero)
	task.wait(0.4)
	send(A, "accept", "tidewalk")
	expectNote("M4.8 a failed trial waits 30 seconds", A, ma, "TRIAL_COOLDOWN")
	realSkip += 31

	-- M4.9: Salt Post.
	ma = mark(A)
	check("M4.9 the Saltworks Warden starts Salt Post", acceptTrial(A, "salt_post"))
	local character = A.Character
	check("M4.9 A carries a parcel", character ~= nil and character:FindFirstChild("Parcel") ~= nil)
	place(A, beside(World.harbour), Vector3.zero)
	expectNote("M4.9 at the Harbour Warden: TRIAL_PASSED", A, ma, "TRIAL_PASSED", 4)
	check("M4.9 the parcel is gone", character ~= nil and character:FindFirstChild("Parcel") == nil)
	check("M4.9 the quest moved to step 2", questStepOf(A) == 2, tostring(questStepOf(A)))
	mb = mark(B)
	check("M4.9 B starts Salt Post without Tidewalk", acceptTrial(B, "salt_post"))
	place(B, beside(World.harbour), Vector3.zero)
	expectNote("M4.9 B passes it", B, mb, "TRIAL_PASSED", 4)
	check(
		"M4.9 out of order it does not count for the quest",
		questStepOf(B) == 0,
		tostring(questStepOf(B))
	)
	realSkip += 301
	ma = mark(A)
	check("M4.9 A starts Salt Post again", acceptTrial(A, "salt_post"))
	humanoidA = humanoidOf(A)
	if humanoidA ~= nil then
		humanoidA.Health = 0
	end
	expectNote("M4.9 defeated on the way: TRIAL_FAILED_DEFEAT", A, ma, "TRIAL_FAILED_DEFEAT", 4)
	waitAlive(A)
	ProtectionService.endRespawnShield(A)

	-- M4.10: Cull the Pack.
	ma = mark(A)
	check("M4.10 the Pack Warden starts Cull the Pack", acceptTrial(A, "cull_the_pack"))
	check("M4.10 setup: a Shellback at 15 health", freshCreature(SHELLBACK_1, 15))
	strikeCreature(A, SHELLBACK_1)
	task.wait(0.5)
	check("M4.10 a Shellback does not count", runProgress(A) == 0, tostring(runProgress(A)))
	for count, id in { HOUND_1, HOUND_2, HOUND_3, HOUND_1, HOUND_2 } do
		freshCreature(id, 15)
		strikeCreature(A, id)
		waitFor(function()
			return runProgress(A) >= count or TrialService.run(A) == nil
		end, 3)
	end
	local last = noteWith(A, ma, "HUNT_PROGRESS", "n", "5")
	check("M4.10 five Brinehounds: HUNT_PROGRESS up to 5 of 5", last ~= nil, codesSince(A, ma))
	expectNote("M4.10 TRIAL_PASSED", A, ma, "TRIAL_PASSED", 4)
	check("M4.10 A has the Brinehound Collar", hasFree(A, "R016"))

	-- M4.11: the duel.
	ma = mark(A)
	check("M4.11 the Duel Warden starts the duel", acceptTrial(A, "tallymans_duel"))
	local champion = championOf(A)
	check("M4.11 a Drowned Tallyman owned by A appears", champion ~= nil)
	if champion ~= nil then
		local championId = champion:GetAttribute("CreatureId")
		local seenByA = inspectUntil(A, function(ui)
			return (ui.champions or {})[tostring(A.UserId)] == true
		end)
		local seenByB = inspect(B)
		check("M4.11 A's screen draws it", (seenByA.champions or {})[tostring(A.UserId)] == true)
		check("M4.11 B's screen does not", (seenByB.champions or {})[tostring(A.UserId)] == false)
		local championHealth = creatureHealth(championId)
		heal(B)
		strikeCreature(B, championId, true)
		check(
			"M4.11 B cannot hurt it",
			creatureHealth(championId) == championHealth,
			`{fmt(championHealth)} -> {fmt(creatureHealth(championId))}`
		)
		check("M4.11 it never hurts B", health(B) >= 99, fmt(health(B)))
		place(B, IN_TOWN, B_TOWN)
		local championHumanoid = creatureBody(championId)
		if championHumanoid ~= nil then
			championHumanoid.Health = 15
		end
		heal(A)
		strikeCreature(A, championId)
		expectNote("M4.11 A defeats it: TRIAL_PASSED", A, ma, "TRIAL_PASSED", 4)
		check("M4.11 the quest moved to step 3", questStepOf(A) == 3, tostring(questStepOf(A)))
		check(
			"M4.11 the champion is gone",
			waitFor(function()
				return championOf(A) == nil
			end, 4)
		)
	end
	realSkip += 301
	ma = mark(A)
	heal(A)
	if acceptTrial(A, "tallymans_duel") then
		clockSkip += 91
		expectNote("M4.11 a duel out of time fails", A, ma, "TRIAL_FAILED_TIME")
		check(
			"M4.11 and its champion is removed",
			waitFor(function()
				return championOf(A) == nil
			end, 3)
		)
	else
		check("M4.11 a second duel starts after the cooldown", false, codesSince(A, ma))
	end

	-- M4.12: the Brine Colossus ends the quest.
	CreatureService.setRng(function()
		return 0.5
	end)
	check("M4.12 setup: the Brine Colossus at 15 health", freshCreature(COLOSSUS, 15))
	coinA = coinOf(A)
	ma, mb = mark(A), mark(B)
	heal(A)
	strikeCreature(A, COLOSSUS)
	expectNote("M4.12 A is told the quest is complete", A, ma, "QUEST_COMPLETE", 4)
	check("M4.12 A has the Writ of the Unpaid Debt", hasFree(A, "R027"))
	check("M4.12 and the Colossus Heartstone (a certain drop)", hasFree(A, "R022"))
	check("M4.12 but not the 20% drop on a roll of 0.5", not hasFree(A, "R023"))
	check("M4.12 +60 and +150 Coin", coinOf(A) == coinA + 210, `{coinA} -> {coinOf(A)}`)
	check("M4.12 the quest starts again at step 0", questStepOf(A) == 0, tostring(questStepOf(A)))
	check("M4.12 B, who did not hit it, gets nothing", noteSince(B, mb, "CREATURE_DEFEATED") == nil)

	-- M4.13: a cache up a climb cannot be opened from the ground.
	local cache = World.cacheById.C019
	local ledges = World.climbs.C019
	ma = mark(A)
	place(A, Vector3.new(ledges[1].x - 8, 3, ledges[1].z), Vector3.zero)
	task.wait(0.4)
	send(A, "prompt", "C019")
	-- 20 studs up, the prompt is out of reach, so the game either refuses or hears nothing.
	task.wait(2)
	check(
		"M4.13 C019 cannot be opened from the ground",
		noteSince(A, ma, "GOT_CARD") == nil and not hasFree(A, "R017"),
		codesSince(A, ma)
	)
	ma = mark(A)
	place(
		A,
		Vector3.new(cache.position.x + 2.5, cache.position.y + 2, cache.position.z),
		Vector3.zero
	)
	task.wait(0.6)
	send(A, "prompt", "C019")
	expectNote("M4.13 from its top ledge: GOT_CARD", A, ma, "GOT_CARD", 4)
	check("M4.13 A has the Rook's-Nest Purse", hasFree(A, "R017"))

	-- Leave the world quiet for the checks that follow.
	CreatureService.setActive({})
	TrialService.setClocks(os.clock, os.time)
	place(A, IN_TOWN, B_TOWN)
	place(B, B_TOWN, IN_TOWN)
	waitAlive(A)
	waitAlive(B)
end

------------------------------------------------------------------------------- M5 helpers

local CLERK_SPOT = Vector3.new(4, 3, -18) -- 7 studs from the clerk, inside the shop's reach
local FAR_FROM_CLERK = Vector3.new(0, 3, 6) -- 30 studs from the clerk
local TRADE_A = Vector3.new(10, 3, 12)
local TRADE_B = Vector3.new(10, 3, 20) -- 8 studs from TRADE_A
local TRADE_FAR = Vector3.new(-30, 3, 12) -- 40 studs from TRADE_A, still in Tallyport

-- Stands the player at `spot` and waits until the server sees them there.
local function put(player: Player, spot: Vector3, face: Vector3)
	place(player, spot, face)
	waitFor(function()
		return flatDistance(positionOf(player), spot) <= 1.5
	end, 3)
	task.wait(0.3)
end

local function setCoin(player: Player, amount: number)
	SourceService.addCoin(player, amount - coinOf(player))
end

local function setFree(player: Player, free: { string }, claimed: { [string]: boolean }?)
	LedgerService.set(player, { claimed = claimed or {}, free = free })
end

local function freeOf(player: Player): { string }
	local ledger = LedgerService.get(player)
	return if ledger ~= nil then ledger.free else {}
end

local function freeText(player: Player): string
	return "{" .. table.concat(freeOf(player), ", ") .. "}"
end

local function isMarkedNow(player: Player): boolean
	local status = ProtectionService.status(player, os.clock())
	return status ~= nil and Protection.isMarked(status, os.clock())
end

-- Waits until 31 seconds have passed since the player's last fight.
local function waitNoFight(player: Player)
	local last = CombatService.lastFightAt(player)
	if last ~= nil then
		local need = last + 31 - os.clock()
		if need > 0 then
			log(`M5 waiting {fmt(need)} s for the 30-second fight rule`)
			task.wait(need)
		end
	end
end

-- Waits for one of several codes; returns the note that came.
local function expectOneOf(name: string, player: Player, from: number, codes: { string })
	local found = nil
	local ok = waitFor(function()
		for _, code in codes do
			local note = noteSince(player, from, code)
			if note ~= nil then
				found = note
				return true
			end
		end
		return false
	end, 3)
	check(name, ok, `{player.Name} got {codesSince(player, from)}`)
	return found
end

-- Sends the request, then gives the server a moment (the rate limit is 5 a second).
local function fire(player: Player, op: string, arg: any?)
	send(player, op, arg)
	task.wait(0.3)
end

local function edictCountOf(player: Player): number
	local ledger = LedgerService.get(player)
	return if ledger ~= nil then Ledger.edictCount(ledger) else -1
end

local function sessionOffers(player: Player): string
	local session = TradeService.session(player)
	if session == nil then
		return "no session"
	end
	local parts = {}
	for key, offer in session.offers do
		table.insert(parts, `{key}:{table.concat(offer.cards, "+")}/{offer.coin}`)
	end
	table.sort(parts)
	return table.concat(parts, " ")
end

local function lineHas(result, text: string): boolean
	for _, line in (result and result.lines) or {} do
		if string.find(line, text, 1, true) then
			return true
		end
	end
	return false
end

local function linesOf(result): string
	return if result ~= nil then table.concat(result.lines, " | ") else "no result"
end

-- Starts a trade: A asks, B accepts. True when both windows got a view.
local function openTrade(A: Player, B: Player): boolean
	tradeViews[A] = nil
	tradeViews[B] = nil
	tradeInvites[B] = nil
	send(A, "tradeRequest")
	if not waitFor(function()
		return type(tradeInvites[B]) == "table"
	end, 3) then
		return false
	end
	task.wait(0.3)
	send(B, "tradeReply", true)
	return waitFor(function()
		return type(tradeViews[A]) == "table" and type(tradeViews[B]) == "table"
	end, 3)
end

-- Edicts, the Edict Hall and trading.
local function runM5(A: Player, B: Player)
	TrialService.setClocks(function()
		return os.clock() + clockSkip
	end, function()
		return os.time() + realSkip
	end)
	waitAlive(A)
	waitAlive(B)
	ProtectionService.endRespawnShield(A)
	ProtectionService.endRespawnShield(B)
	heal(A)
	heal(B)
	local dataA, dataB = DataService.get(A), DataService.get(B)
	dataA.trials = { cooldowns = {}, questStep = 0 }
	dataB.trials = { cooldowns = {}, questStep = 0 }
	setFree(A, {})
	setFree(B, {})
	setCoin(A, 100)
	setCoin(B, 0)
	-- Selling and trading are refused for 30 seconds after a fight and while Marked, so start
	-- from neither (earlier sections may have left A or B in a fight).
	ProtectionService.endMark(A)
	ProtectionService.endMark(B)
	waitNoFight(A)
	waitNoFight(B)
	EdictService.setRng(function()
		return 0
	end)
	put(A, CLERK_SPOT, Vector3.new(0, 3, -24))
	put(B, TRADE_FAR, TRADE_A)

	-- The clerk and the shop window.
	local clerks = CollectionService:GetTagged("ShopClerk")
	check("M5 clerk: one part is tagged ShopClerk", #clerks == 1, tostring(#clerks))
	shopViews[A] = nil
	send(A, "shopOpen")
	check(
		"M5 clerk: the shop opens from the clerk's prompt",
		waitFor(function()
			return shopViews[A] ~= nil
		end, 4)
	)
	local opened = shopViews[A] or {}
	check(
		"M5 clerk: the view's Coin line matches",
		opened.coinText == `Coin: {coinOf(A)}`,
		tostring(opened.coinText)
	)
	local ui = inspectUntil(A, function(snapshot)
		return snapshot.shopVisible == true
	end)
	check(
		"M5 clerk: the shop window is open and shows the Coin",
		ui.shopVisible == true and ui.shopCoin == "Coin: 100",
		`{tostring(ui.shopVisible)}, "{tostring(ui.shopCoin)}"`
	)

	-- Pack.
	local rolls, rollIndex = { 0, 0.5, 0.9 }, 0
	ShopService.setRng(function()
		rollIndex += 1
		return rolls[rollIndex] or 0
	end)
	shopViews[A] = nil
	local m = mark(A)
	fire(A, "shop", { kind = "pack" })
	local pack = expectNote("M5 pack: SHOP_PACK", A, m, "SHOP_PACK")
	check(
		"M5 pack: names Summons, Veil, Homecoming",
		pack ~= nil and pack.args ~= nil and pack.args.names == "Summons, Veil, Homecoming",
		if pack ~= nil and pack.args ~= nil then tostring(pack.args.names) else "none"
	)
	local free = freeOf(A)
	check(
		"M5 pack: 40 Coin left and three Edicts in the free slots",
		coinOf(A) == 40 and free[1] == "E001" and free[2] == "E003" and free[3] == "E005",
		`{coinOf(A)} Coin, {freeText(A)}`
	)
	waitFor(function()
		return shopViews[A] ~= nil
	end, 3)
	ui = inspectUntil(A, function(snapshot)
		return snapshot.shopCoin == "Coin: 40"
	end)
	check(
		"M5 pack: the window's Coin line follows",
		ui.shopCoin == "Coin: 40",
		`"{tostring(ui.shopCoin)}"`
	)
	m = mark(A)
	fire(A, "shop", { kind = "pack" })
	expectNote("M5 pack: 40 Coin is NOT_ENOUGH_COIN", A, m, "NOT_ENOUGH_COIN")
	check(
		"M5 pack: nothing changed when refused",
		coinOf(A) == 40 and #freeOf(A) == 3,
		`{coinOf(A)} Coin, {freeText(A)}`
	)

	-- Relic.
	m = mark(A)
	fire(A, "shop", { kind = "relic", relicId = "R003" })
	expectNote("M5 relic: R003 at 40 Coin is SHOP_BOUGHT", A, m, "SHOP_BOUGHT")
	check(
		"M5 relic: Coin is 0 and the Relic is held",
		coinOf(A) == 0 and hasFree(A, "R003"),
		tostring(coinOf(A))
	)
	m = mark(A)
	fire(A, "shop", { kind = "relic", relicId = "R007" })
	expectNote("M5 relic: R007 is NOT_FOR_SALE", A, m, "NOT_FOR_SALE")

	-- Sell.
	local row = table.find(freeOf(A), "R003") or 0
	m = mark(A)
	fire(A, "shop", { kind = "sell", freeIndex = row, cardId = "R003" })
	expectNote("M5 sell: SHOP_SOLD", A, m, "SHOP_SOLD")
	check(
		"M5 sell: +1 Coin and the Relic is gone",
		coinOf(A) == 1 and not hasFree(A, "R003"),
		`{coinOf(A)} Coin, {freeText(A)}`
	)
	m = mark(A)
	fire(A, "shop", { kind = "sell", freeIndex = row, cardId = "R003" })
	expectNote("M5 sell: the same request again is BAD_INDEX", A, m, "BAD_INDEX")
	check("M5 sell: Coin unchanged by the repeat", coinOf(A) == 1, tostring(coinOf(A)))

	-- Reach.
	setCoin(A, 100)
	put(A, FAR_FROM_CLERK, Vector3.new(0, 3, -24))
	local freeBefore = freeText(A)
	m = mark(A)
	fire(A, "shop", { kind = "pack" })
	expectNote("M5 reach: 30 studs from the clerk is TOO_FAR", A, m, "TOO_FAR")
	check(
		"M5 reach: nothing changed",
		coinOf(A) == 100 and freeText(A) == freeBefore,
		`{coinOf(A)} Coin, {freeText(A)}`
	)
	put(A, CLERK_SPOT, Vector3.new(0, 3, -24))

	-- Hostile shop requests.
	local hostile = {
		{ "a string", "pack" },
		{ "a number", 5 },
		{ "an empty table", {} },
		{ "kind steal", { kind = "steal" } },
		{ "nil", nil },
	}
	freeBefore = freeText(A)
	for _, entry in hostile do
		m = mark(A)
		fire(A, "shop", entry[2])
		expectNote(`M5 hostile shop request ({entry[1]}): BAD_REQUEST`, A, m, "BAD_REQUEST")
	end
	check(
		"M5 hostile shop requests changed nothing",
		coinOf(A) == 100 and freeText(A) == freeBefore,
		`{coinOf(A)} Coin, {freeText(A)}`
	)

	-- Veil.
	put(A, TRADE_A, TRADE_B)
	put(B, TRADE_B, TRADE_A)
	setFree(A, { "E003" })
	m = mark(A)
	fire(A, "edict", { freeIndex = 1, cardId = "E003" })
	expectNote("M5 veil: EDICT_VEIL_ON", A, m, "EDICT_VEIL_ON")
	check("M5 veil: the card is gone", #freeOf(A) == 0, freeText(A))
	check("M5 veil: A is veiled", EdictService.isVeiled(A))
	ui = inspectUntil(A, function(snapshot)
		return string.sub(snapshot.veilLine or "", 1, 6) == "Veiled"
	end)
	check(
		'M5 veil: the HUD shows a line starting "Veiled"',
		string.sub(ui.veilLine or "", 1, 6) == "Veiled",
		`"{tostring(ui.veilLine)}"`
	)

	-- Summons.
	setFree(A, { "E001" })
	setFree(B, {}, { R007 = true })
	edictResults[A] = nil
	fire(A, "edict", { freeIndex = 1, cardId = "E001", relicId = "R007" })
	waitFor(function()
		return edictResults[A] ~= nil
	end, 3)
	local summons = edictResults[A]
	check(
		'M5 summons: the result is titled "Summons: Bottled Squall"',
		summons ~= nil and summons.title == "Summons: Bottled Squall",
		if summons ~= nil then tostring(summons.title) else "no result"
	)
	check(
		"M5 summons: it lists B's display name",
		lineHas(summons, B.DisplayName),
		linesOf(summons)
	)
	check("M5 summons: the card is gone", #freeOf(A) == 0, freeText(A))
	ui = inspectUntil(A, function(snapshot)
		return snapshot.resultVisible == true
	end)
	check(
		"M5 summons: the result window is open with that title",
		ui.resultVisible == true and ui.resultTitle == "Summons: Bottled Squall",
		`{tostring(ui.resultVisible)}, "{tostring(ui.resultTitle)}"`
	)

	-- Audit (B is not veiled yet).
	setFree(A, { "E002" })
	put(A, TRADE_A, TRADE_B)
	put(B, Vector3.new(10, 3, 22), TRADE_A)
	edictResults[A] = nil
	local mb = mark(B)
	fire(A, "edict", { freeIndex = 1, cardId = "E002" })
	waitFor(function()
		return edictResults[A] ~= nil
	end, 3)
	local audit = edictResults[A]
	check(
		"M5 audit: the result is titled with B's name",
		audit ~= nil and audit.title == "Audit: " .. B.DisplayName,
		if audit ~= nil then tostring(audit.title) else "no result"
	)
	check(
		'M5 audit: it shows "007 Bottled Squall (Silver)"',
		lineHas(audit, "007 Bottled Squall (Silver)"),
		linesOf(audit)
	)
	expectNote("M5 audit: B is told AUDITED", B, mb, "AUDITED")
	check("M5 audit: the card is gone", #freeOf(A) == 0, freeText(A))
	setFree(A, { "E002" })
	put(B, TRADE_FAR, TRADE_A)
	m = mark(A)
	fire(A, "edict", { freeIndex = 1, cardId = "E002" })
	expectNote("M5 audit: B 40 studs away is EDICT_NO_TARGET", A, m, "EDICT_NO_TARGET")
	check("M5 audit: A still holds the card", freeOf(A)[1] == "E002", freeText(A))

	-- Summons with B veiled (B uses a Veil of their own).
	put(B, TRADE_B, TRADE_A)
	setFree(B, { "E003" }, { R007 = true })
	mb = mark(B)
	fire(B, "edict", { freeIndex = 1, cardId = "E003" })
	expectNote("M5 summons: B veils themselves", B, mb, "EDICT_VEIL_ON")
	setFree(A, { "E001" })
	edictResults[A] = nil
	fire(A, "edict", { freeIndex = 1, cardId = "E001", relicId = "R007" })
	waitFor(function()
		return edictResults[A] ~= nil
	end, 3)
	check(
		'M5 summons: with B veiled it says "Nobody else here holds it"',
		lineHas(edictResults[A], "Nobody else here holds it"),
		linesOf(edictResults[A])
	)

	-- Homecoming. Earlier sections may have left A Marked or in a fight: end both first.
	ProtectionService.endMark(A)
	ProtectionService.endMark(B)
	waitNoFight(A)
	waitNoFight(B)
	setFree(A, { "E005" })
	put(A, OUTSIDE, Vector3.zero)
	-- First, while Marked, travel is refused and the card is kept.
	ProtectionService.mark(A, os.clock())
	m = mark(A)
	fire(A, "edict", { freeIndex = 1, cardId = "E005" })
	expectNote("M5 homecoming is refused while Marked: EDICT_MARKED", A, m, "EDICT_MARKED")
	check(
		"M5 homecoming while Marked: the card is kept and A did not move",
		freeOf(A)[1] == "E005" and flatDistance(positionOf(A), OUTSIDE) < 3,
		`{freeText(A)}, {at(positionOf(A))}`
	)
	ProtectionService.endMark(A)
	check("M5 homecoming setup: A is no longer Marked", not isMarkedNow(A))
	m = mark(A)
	fire(A, "edict", { freeIndex = 1, cardId = "E005" })
	expectNote("M5 homecoming: HOMECOMING_DONE", A, m, "HOMECOMING_DONE")
	waitFor(function()
		return flatDistance(positionOf(A), Vector3.zero) <= World.townRadius
	end, 3)
	check(
		"M5 homecoming: A is within the town radius",
		flatDistance(positionOf(A), Vector3.zero) <= World.townRadius,
		at(positionOf(A))
	)
	check("M5 homecoming: the card is gone", #freeOf(A) == 0, freeText(A))

	-- Homecoming during a trial.
	setFree(A, { "E005" })
	dataA.trials = { cooldowns = {}, questStep = 0 }
	ProtectionService.endMark(A)
	waitNoFight(A)
	m = mark(A)
	local started = acceptTrial(A, "tidewalk")
	check("M5 trial setup: A accepts Tidewalk", started, codesSince(A, m))
	if started then
		task.wait(0.5)
		local spot = positionOf(A)
		m = mark(A)
		fire(A, "edict", { freeIndex = 1, cardId = "E005" })
		expectNote("M5 homecoming during a trial: EDICT_IN_TRIAL", A, m, "EDICT_IN_TRIAL")
		check(
			"M5 homecoming during a trial: the card is kept and A did not move",
			freeOf(A)[1] == "E005" and flatDistance(positionOf(A), spot) < 3,
			`{freeText(A)}, {at(positionOf(A))}`
		)
		clockSkip += 200
		waitFor(function()
			return TrialService.run(A) == nil
		end, 5)
	end

	-- Passage.
	ProtectionService.endMark(A)
	put(A, TRADE_A, TRADE_B)
	put(B, OUTSIDE, TRADE_A)
	setFree(A, { "E004" })
	-- A and B have already met in the earlier sections and cannot be un-met, so "before
	-- meeting" asks for a player who is not on the server.
	m = mark(A)
	fire(A, "edict", { freeIndex = 1, cardId = "E004", targetId = 7 })
	expectNote("M5 passage: an unmet player is EDICT_NOT_MET", A, m, "EDICT_NOT_MET")
	check("M5 passage: the card is kept", freeOf(A)[1] == "E004", freeText(A))
	EdictService.meet(A, B)
	waitNoFight(A)
	put(B, OUTSIDE, TRADE_A)
	m = mark(A)
	fire(A, "edict", { freeIndex = 1, cardId = "E004", targetId = B.UserId })
	expectNote("M5 passage: PASSAGE_DONE after meeting", A, m, "PASSAGE_DONE")
	waitFor(function()
		return flatDistance(positionOf(A), positionOf(B)) <= 10
	end, 3)
	check(
		"M5 passage: A is within 10 studs of B",
		flatDistance(positionOf(A), positionOf(B)) <= 10,
		fmt(flatDistance(positionOf(A), positionOf(B)))
	)

	-- Hostile Edict requests.
	put(A, TRADE_A, TRADE_B)
	put(B, TRADE_B, TRADE_A)
	setFree(A, { "R001", "E002" })
	local hostileUse = {
		{ "a Relic row", { freeIndex = 1, cardId = "R001" } },
		{ "a wrong card for the row", { freeIndex = 2, cardId = "E003" } },
		{ "index 0", { freeIndex = 0, cardId = "E002" } },
		{ "a table for freeIndex", { freeIndex = {}, cardId = "E002" } },
		{ "nil", nil },
	}
	for _, entry in hostileUse do
		m = mark(A)
		fire(A, "edict", entry[2])
		expectOneOf(
			`M5 hostile Edict request ({entry[1]}) is refused`,
			A,
			m,
			{ "BAD_REQUEST", "BAD_INDEX" }
		)
	end
	check(
		"M5 hostile Edict requests left the Ledger unchanged",
		freeText(A) == "{R001, E002}",
		freeText(A)
	)

	-- Defeat loss.
	setFree(A, { "E001", "E002", "E003", "E004", "E005", "E001", "R001", "R002" })
	check("M5 defeat setup: A holds 6 Edicts", edictCountOf(A) == 6, tostring(edictCountOf(A)))
	m = mark(A)
	local humanoid = humanoidOf(A)
	if humanoid ~= nil then
		humanoid.Health = 0
	end
	expectNote("M5 defeat: EDICTS_LOST", A, m, "EDICTS_LOST", 5)
	check(
		"M5 defeat: 4 Edicts are left and both Relics are kept",
		edictCountOf(A) == 4 and hasFree(A, "R001") and hasFree(A, "R002"),
		freeText(A)
	)
	waitAlive(A)
	ProtectionService.endRespawnShield(A)
	EdictService.setRng(math.random)

	-- Trade.
	waitNoFight(A)
	waitNoFight(B)
	put(A, TRADE_A, TRADE_B)
	put(B, TRADE_B, TRADE_A)
	setFree(A, { "R001" })
	setFree(B, { "E003" })
	setCoin(A, 50)
	setCoin(B, 5)
	local totalBefore = coinOf(A) + coinOf(B)
	tradeInvites[B] = nil
	m = mark(A)
	send(A, "tradeRequest")
	local invited = waitFor(function()
		return type(tradeInvites[B]) == "table"
	end, 3)
	check(
		"M5 trade: B's invite names A",
		invited and tradeInvites[B].from == A.DisplayName,
		if type(tradeInvites[B]) == "table" then tostring(tradeInvites[B].from) else "no invite"
	)
	expectNote("M5 trade: A gets TRADE_SENT", A, m, "TRADE_SENT")
	ui = inspectUntil(B, function(snapshot)
		return snapshot.inviteVisible == true
	end)
	check("M5 trade: B's invite banner is showing", ui.inviteVisible == true)
	tradeViews[A] = nil
	tradeViews[B] = nil
	send(B, "tradeReply", true)
	check(
		"M5 trade: B accepts and both get a view",
		waitFor(function()
			return type(tradeViews[A]) == "table" and type(tradeViews[B]) == "table"
		end, 3)
	)
	fire(A, "trade", { kind = "offer", cards = { "R001" }, coin = 10 })
	fire(B, "trade", { kind = "offer", cards = { "E003" }, coin = 0 })
	-- Straight away, before anything slow: the server has both offers now.
	m = mark(A)
	fire(A, "trade", { kind = "confirm" })
	expectNote("M5 trade: confirming at once is TRADE_TOO_SOON", A, m, "TRADE_TOO_SOON")
	local seen = waitFor(function()
		local va, vb = tradeViews[A], tradeViews[B]
		return type(va) == "table"
			and type(vb) == "table"
			and va.theirs.cards[1] ~= nil
			and va.theirs.cards[1].cardId == "E003"
			and vb.theirs.coin == 10
			and vb.theirs.cards[1] ~= nil
			and vb.theirs.cards[1].cardId == "R001"
	end, 3)
	check("M5 trade: each sees the other's offer", seen, sessionOffers(A))
	ui = inspectUntil(A, function(snapshot)
		return snapshot.tradeVisible == true
	end)
	check("M5 trade: A's trade window is open", ui.tradeVisible == true, tostring(ui.tradeStatus))
	task.wait(2.3)
	local ma, mb2 = mark(A), mark(B)
	fire(A, "trade", { kind = "confirm" })
	fire(B, "trade", { kind = "confirm" })
	expectNote("M5 trade: A gets TRADE_DONE", A, ma, "TRADE_DONE")
	expectNote("M5 trade: B gets TRADE_DONE", B, mb2, "TRADE_DONE")
	check(
		"M5 trade: the cards changed hands",
		hasFree(A, "E003")
			and not hasFree(A, "R001")
			and hasFree(B, "R001")
			and not hasFree(B, "E003"),
		`A {freeText(A)}, B {freeText(B)}`
	)
	check(
		"M5 trade: 10 Coin moved and the total is unchanged",
		coinOf(A) == 40 and coinOf(B) == 15 and coinOf(A) + coinOf(B) == totalBefore,
		`A {coinOf(A)}, B {coinOf(B)}`
	)
	check("M5 trade: both windows closed", waitFor(function()
		return tradeViews[A] == false and tradeViews[B] == false
	end, 3) and TradeService.session(A) == nil)

	-- The switch: a changed offer clears the confirmations.
	setFree(A, { "R001" })
	setFree(B, { "R007" })
	check("M5 switch: a new trade opens", openTrade(A, B))
	fire(A, "trade", { kind = "offer", cards = { "R001" }, coin = 0 })
	fire(B, "trade", { kind = "offer", cards = { "R007" }, coin = 0 })
	task.wait(2.4)
	fire(A, "trade", { kind = "confirm" })
	local session = TradeService.session(A)
	check(
		"M5 switch: A's confirmation is recorded",
		session ~= nil and session.confirmed[tostring(A.UserId)] == true
	)
	fire(B, "trade", { kind = "offer", cards = {}, coin = 0 })
	session = TradeService.session(A)
	check(
		"M5 switch: B changing the offer clears the confirmations",
		session ~= nil and next(session.confirmed) == nil,
		sessionOffers(A)
	)
	mb = mark(B)
	fire(B, "trade", { kind = "confirm" })
	expectNote("M5 switch: B confirming at once is TRADE_TOO_SOON", B, mb, "TRADE_TOO_SOON")

	-- Cancel and leash.
	ma, mb = mark(A), mark(B)
	fire(B, "trade", { kind = "cancel" })
	expectNote("M5 cancel: A gets TRADE_CANCELLED", A, ma, "TRADE_CANCELLED")
	expectNote("M5 cancel: B gets TRADE_CANCELLED", B, mb, "TRADE_CANCELLED")
	check("M5 leash: a new trade opens", openTrade(A, B))
	ma, mb = mark(A), mark(B)
	place(B, TRADE_FAR, TRADE_A)
	expectNote(
		"M5 leash: A gets TRADE_CANCELLED when B is 40 studs away",
		A,
		ma,
		"TRADE_CANCELLED",
		3
	)
	expectNote("M5 leash: B gets TRADE_CANCELLED too", B, mb, "TRADE_CANCELLED", 3)
	put(B, TRADE_B, TRADE_A)

	-- Hostile trade requests during a trade.
	setFree(A, { "R001" })
	setFree(B, { "R007" })
	setCoin(A, 40)
	check("M5 hostile trade: a new trade opens", openTrade(A, B))
	fire(A, "trade", { kind = "offer", cards = { "R001" }, coin = 5 })
	local offersBefore = sessionOffers(A)
	local sevenCards = { "R001", "R001", "R001", "R001", "R001", "R001", "R001" }
	local hostileTrade = {
		{ "a card not held", { kind = "offer", cards = { "R002" }, coin = 0 } },
		{ "7 cards", { kind = "offer", cards = sevenCards, coin = 0 } },
		{ "Coin -5", { kind = "offer", cards = {}, coin = -5 } },
		{ "Coin 1.5", { kind = "offer", cards = {}, coin = 1.5 } },
		{ "more Coin than held", { kind = "offer", cards = {}, coin = 41 } },
		{ "kind steal", { kind = "steal" } },
	}
	for _, entry in hostileTrade do
		m = mark(A)
		fire(A, "trade", entry[2])
		expectOneOf(
			`M5 hostile trade request ({entry[1]}) is refused`,
			A,
			m,
			{ "TRADE_BAD_OFFER", "BAD_REQUEST" }
		)
	end
	check(
		"M5 hostile trade requests left the offers unchanged",
		sessionOffers(A) == offersBefore,
		`{offersBefore} -> {sessionOffers(A)}`
	)
	fire(A, "trade", { kind = "cancel" })
	waitFor(function()
		return TradeService.session(A) == nil
	end, 3)

	-- Decline.
	tradeInvites[B] = nil
	m = mark(A)
	send(A, "tradeRequest")
	waitFor(function()
		return type(tradeInvites[B]) == "table"
	end, 3)
	task.wait(0.3)
	send(B, "tradeReply", false)
	expectNote("M5 decline: A gets TRADE_DECLINED", A, m, "TRADE_DECLINED")

	-- No dealing while Marked: no trade request, no sale to the clerk (spec 3.13).
	setFree(A, { "R001" })
	setCoin(A, 40)
	put(A, TRADE_A, TRADE_B)
	put(B, TRADE_B, TRADE_A)
	ProtectionService.mark(A, os.clock())
	tradeInvites[B] = nil
	m = mark(A)
	send(A, "tradeRequest")
	expectNote("M5 dealing: a trade request while Marked is EDICT_MARKED", A, m, "EDICT_MARKED")
	task.wait(0.5)
	check(
		"M5 dealing: B got no invite and no trade opened",
		type(tradeInvites[B]) ~= "table"
			and TradeService.session(A) == nil
			and TradeService.session(B) == nil,
		`invite {type(tradeInvites[B])}`
	)
	put(A, CLERK_SPOT, Vector3.new(0, 3, -24))
	m = mark(A)
	fire(A, "shop", { kind = "sell", freeIndex = 1, cardId = "R001" })
	expectNote("M5 dealing: a sale while Marked is EDICT_MARKED", A, m, "EDICT_MARKED")
	check(
		"M5 dealing: the refused sale changed nothing",
		freeOf(A)[1] == "R001" and coinOf(A) == 40,
		`{freeText(A)}, {coinOf(A)} Coin`
	)
	ProtectionService.endMark(A)
	check(
		"M5 dealing: A is no longer Marked and no trade is open",
		not isMarkedNow(A) and TradeService.session(A) == nil and TradeService.session(B) == nil
	)

	-- A trader who starts a fight after confirming early: the swap is cancelled.
	setFree(A, { "R001" })
	setFree(B, {})
	setCoin(A, 40)
	setCoin(B, 0)
	-- The dealing checks left A at the clerk: both stand on the trade spots first.
	put(A, TRADE_A, TRADE_B)
	put(B, TRADE_B, TRADE_A)
	local swapOpen = openTrade(A, B)
	check("M5 swap guard: a trade opens", swapOpen)
	if not swapOpen then
		log("M5 swap guard: no trade opened, the rest of this section is skipped")
		ProtectionService.endMark(A)
		fire(A, "trade", { kind = "cancel" })
	else
		fire(A, "trade", { kind = "offer", cards = { "R001" }, coin = 0 })
		task.wait(2.4)
		fire(A, "trade", { kind = "confirm" })
		task.wait(0.5)
		ProtectionService.mark(A, os.clock())
		m = mark(A)
		local mB = mark(B)
		fire(B, "trade", { kind = "confirm" })
		expectNote("M5 swap guard: A gets TRADE_CANCELLED", A, m, "TRADE_CANCELLED")
		expectNote("M5 swap guard: B gets TRADE_CANCELLED", B, mB, "TRADE_CANCELLED")
		check(
			"M5 swap guard: A keeps the card, B gets nothing, no trade is open",
			freeOf(A)[1] == "R001"
				and #freeOf(B) == 0
				and TradeService.session(A) == nil
				and TradeService.session(B) == nil,
			`{freeText(A)} / {freeText(B)}`
		)
		ProtectionService.endMark(A)
		check("M5 swap guard: A is no longer Marked", not isMarkedNow(A))
	end

	-- Leave the world quiet.
	ShopService.setRng(math.random)
	EdictService.setRng(math.random)
	TrialService.setClocks(os.clock, os.time)
	waitAlive(A)
	waitAlive(B)
	put(A, IN_TOWN, B_TOWN)
	put(B, B_TOWN, IN_TOWN)
	check(
		"M5 ends with no trade open",
		TradeService.session(A) == nil and TradeService.session(B) == nil
	)
end

------------------------------------------------------------------------------- M6 parties
-- B's new-player-shield flag as M6 found it, so run() can put it back if M6 stops half way.
local m6ShieldEnded: boolean? = nil

-- Parties: invites, the panel and markers, no friendly fire, support reaching allies and the
-- creature share, handing over the lead, removing, and fighting again after leaving.
local function runM6(A: Player, B: Player)
	TrialService.setClocks(function()
		return os.clock() + clockSkip
	end, function()
		return os.time() + realSkip
	end)
	waitAlive(A)
	waitAlive(B)
	ProtectionService.endRespawnShield(A)
	ProtectionService.endRespawnShield(B)
	ProtectionService.endMark(A)
	ProtectionService.endMark(B)
	waitNoFight(A)
	waitNoFight(B)
	heal(A)
	heal(B)
	local dataA, dataB = DataService.get(A), DataService.get(B)
	dataA.trials = { cooldowns = {}, questStep = 0 }
	dataB.trials = { cooldowns = {}, questStep = 0 }
	m6ShieldEnded = dataB.shieldEnded
	setFree(A, {})
	setFree(B, {})
	CreatureService.setActive({})
	CreatureService.setRng(function()
		return 0.99
	end)

	-- Local helpers.
	local blankRow = { name = "", health = "", remove = false, lead = false }

	local function raiseTo(player: Player, path: string, level: number)
		local tries = 0
		while levelOf(player, path) < level and tries < 60 do
			PathService.grant(player, path, 2000)
			tries += 1
		end
	end

	-- True when the player's party has this leader and exactly these members, in this order.
	local function partyIs(player: Player, leader: number, members: { number }): boolean
		local party = PartyService.party(player)
		if party == nil or party.leader ~= leader or #party.members ~= #members then
			return false
		end
		for i, id in members do
			if party.members[i] ~= id then
				return false
			end
		end
		return true
	end

	local function partyText(player: Player): string
		local party = PartyService.party(player)
		if party == nil then
			return "no party"
		end
		local ids = {}
		for _, id in party.members do
			table.insert(ids, tostring(id))
		end
		return `leader {party.leader}, members {table.concat(ids, ",")}`
	end

	local function pairIs(): boolean
		return partyIs(A, A.UserId, { A.UserId, B.UserId })
	end

	local function syncIs(player: Player, leader: number, count: number): boolean
		local view = partySyncs[player]
		return type(view) == "table" and view.leader == leader and #view.members == count
	end

	local function noParty(): boolean
		return PartyService.party(A) == nil and PartyService.party(B) == nil
	end

	-- Does the note's {player} argument name this player?
	local function names(note, player: Player): boolean
		return note ~= nil and note.args ~= nil and note.args.player == player.DisplayName
	end

	local function setHealth(player: Player, amount: number)
		local humanoid = humanoidOf(player)
		if humanoid ~= nil then
			humanoid.Health = amount
		end
	end

	local function statusOf(player: Player)
		return StatusService.get(player.UserId)
	end

	local function creatureAt(id: number): Vector3
		local _, root = creatureBody(id)
		return if root ~= nil then Vector3.new(root.Position.X, 3, root.Position.Z) else OUTSIDE
	end

	-- A asks and B has the invite on screen. False when it never came.
	local function inviteB(): boolean
		partyInvites[B] = nil
		send(A, "partyRequest")
		return waitFor(function()
			return type(partyInvites[B]) == "table"
		end, 3)
	end

	-- A invites B and B accepts. True once the party exists.
	local function joinB(): boolean
		if not inviteB() then
			return false
		end
		task.wait(0.3)
		send(B, "partyReply", true)
		return waitFor(pairIs, 3)
	end

	-- B at OUTSIDE and A `distance` studs from B, each facing the other.
	local function standApart(distance: number)
		local spot = clearSpot(OUTSIDE, distance)
		put(B, OUTSIDE, spot)
		put(A, spot, OUTSIDE)
	end

	local function shieldsDown()
		ProtectionService.endRespawnShield(A)
		ProtectionService.endRespawnShield(B)
	end

	-- Setup: Paths, then the loadouts in Tallyport.
	raiseTo(B, "Mend", 18)
	raiseTo(B, "Mire", 10)
	raiseTo(B, "Bulwark", 10)
	raiseTo(A, "Gale", 10)
	raiseTo(A, "Ember", 3)
	check(
		"M6 setup: B at Mend 18, Mire 10, Bulwark 10; A at Gale 10, Ember 3",
		levelOf(B, "Mend") >= 18
			and levelOf(B, "Mire") >= 10
			and levelOf(B, "Bulwark") >= 10
			and levelOf(A, "Gale") >= 10
			and levelOf(A, "Ember") >= 3,
		`B Mend {levelOf(B, "Mend")}, Mire {levelOf(B, "Mire")}, Bulwark {levelOf(B, "Bulwark")}; A Gale {levelOf(
			A,
			"Gale"
		)}, Ember {levelOf(A, "Ember")}`
	)
	put(A, IN_TOWN, B_TOWN)
	put(B, B_TOWN, IN_TOWN)
	equip(A, 3, "gust_blade")
	equip(A, 4, "cinder_bolt")
	equip(B, 1, "siphon")
	equip(B, 2, "sinking_field")
	equip(B, 3, "ward")
	equip(B, 4, "renewal")

	--------------------------------------------------------------------------- M6.1 invites
	partyInvites[A], partyInvites[B] = nil, nil
	partySyncs[A], partySyncs[B] = nil, nil
	local mA = mark(A)
	fire(A, "partyRequest")
	expectNote("M6.1 a request with nobody close: EDICT_NO_TARGET", A, mA, "EDICT_NO_TARGET")

	put(B, TRADE_B, IN_TOWN)
	partyInvites[B] = nil
	mA = mark(A)
	send(A, "partyRequest")
	local sent = expectNote("M6.1 A's request: PARTY_INVITE_SENT", A, mA, "PARTY_INVITE_SENT")
	check("M6.1 the message names B", names(sent, B))
	waitFor(function()
		return type(partyInvites[B]) == "table"
	end, 3)
	local invite = partyInvites[B]
	check(
		"M6.1 B's invite names A and runs 20 seconds",
		type(invite) == "table" and invite.from == A.DisplayName and invite.seconds == 20,
		if type(invite) == "table"
			then `{tostring(invite.from)}, {tostring(invite.seconds)}`
			else "no invite"
	)
	local banner = inspectUntil(B, function(ui)
		return ui.partyInviteVisible == true
	end)
	check(
		'M6.1 B\'s banner reads "<A> invites you to their party"',
		banner.partyInviteVisible == true
			and banner.partyInviteText == `{A.DisplayName} invites you to their party`,
		`{tostring(banner.partyInviteVisible)}, "{tostring(banner.partyInviteText)}"`
	)
	mA = mark(A)
	fire(A, "partyRequest")
	expectNote("M6.1 a second request while one is pending: EDICT_NOT_NOW", A, mA, "EDICT_NOT_NOW")

	-- Declined. (A reply does not close the banner by itself: only the Accept and Decline
	-- buttons do, and the agent fires the remote directly. So the check is that the server
	-- forgot the invite.)
	mA = mark(A)
	send(B, "partyReply", false)
	expectNote("M6.1 B declines: A gets PARTY_DECLINED", A, mA, "PARTY_DECLINED")
	check("M6.1 a declined invite makes no party", PartyService.party(A) == nil)
	local mB = mark(B)
	fire(B, "partyReply", true)
	expectNote("M6.1 the declined invite is gone: PARTY_NO_INVITE", B, mB, "PARTY_NO_INVITE")
	check("M6.1 and a late reply makes no party", noParty())

	-- A reply that is not the boolean true counts as a decline.
	check("M6.1 setup: a fresh invite reaches B", inviteB())
	task.wait(0.3)
	mA = mark(A)
	send(B, "partyReply", "true")
	expectNote('M6.1 a reply of the string "true": PARTY_DECLINED', A, mA, "PARTY_DECLINED")
	check("M6.1 and no party", noParty())

	-- An invite left alone runs out.
	check("M6.1 setup: another fresh invite reaches B", inviteB())
	mA = mark(A)
	expectNote(
		"M6.1 an invite left alone for 21.5 s: PARTY_EXPIRED",
		A,
		mA,
		"PARTY_EXPIRED",
		Party.INVITE_SECONDS + 1.5
	)
	check(
		"M6.1 B's invite stream closes",
		waitFor(function()
			return partyInvites[B] == false
		end, 3),
		tostring(partyInvites[B])
	)
	mB = mark(B)
	fire(B, "partyReply", true)
	expectNote("M6.1 B's late reply: PARTY_NO_INVITE", B, mB, "PARTY_NO_INVITE")
	check("M6.1 and no party", noParty())

	-- Accepted.
	check("M6.1 setup: a last fresh invite reaches B", inviteB())
	task.wait(0.3)
	partySyncs[A], partySyncs[B] = nil, nil
	mA, mB = mark(A), mark(B)
	send(B, "partyReply", true)
	local joinedNote = expectNote("M6.1 B accepts: PARTY_JOINED", B, mB, "PARTY_JOINED")
	check("M6.1 PARTY_JOINED names A", names(joinedNote, A))
	local memberNote = expectNote("M6.1 A hears PARTY_MEMBER_JOINED", A, mA, "PARTY_MEMBER_JOINED")
	check("M6.1 PARTY_MEMBER_JOINED names B", names(memberNote, B))
	waitFor(function()
		return syncIs(A, A.UserId, 2) and syncIs(B, A.UserId, 2)
	end, 3)
	check("M6.1 the party is led by A with A and B", pairIs(), partyText(A))
	check(
		"M6.1 A and B are allied, both ways",
		Fighters.allied(A.UserId, B.UserId) and Fighters.allied(B.UserId, A.UserId)
	)
	check(
		"M6.1 both sync streams list two members led by A",
		syncIs(A, A.UserId, 2) and syncIs(B, A.UserId, 2)
	)

	--------------------------------------------------------------------------- M6.2 panel and markers
	heal(A)
	heal(B)
	local panelA = inspectUntil(A, function(ui)
		local rows = ui.partyRows or {}
		return ui.partyVisible == true
			and #rows == 2
			and rows[1].health == "100 / 100"
			and rows[2].health == "100 / 100"
	end)
	local rowsA = panelA.partyRows or {}
	local firstA, secondA = rowsA[1] or blankRow, rowsA[2] or blankRow
	check(
		"M6.2 A's panel is visible and titled Party 2 / 4",
		panelA.partyVisible == true and panelA.partyTitle == "Party 2 / 4",
		`{tostring(panelA.partyVisible)}, "{tostring(panelA.partyTitle)}"`
	)
	check(
		"M6.2 A's first row is A (leader) at 100 / 100",
		firstA.name == `{A.DisplayName} (leader)` and firstA.health == "100 / 100",
		`"{firstA.name}", "{firstA.health}"`
	)
	check(
		"M6.2 A's second row is B at 100 / 100 with Remove and Lead",
		secondA.name == B.DisplayName
			and secondA.health == "100 / 100"
			and secondA.remove
			and secondA.lead,
		`"{secondA.name}", "{secondA.health}", remove={tostring(secondA.remove)}, lead={tostring(
			secondA.lead
		)}`
	)
	local panelB = inspectUntil(B, function(ui)
		return ui.partyVisible == true and #(ui.partyRows or {}) == 2
	end)
	local rowsB = panelB.partyRows or {}
	local firstB, secondB = rowsB[1] or blankRow, rowsB[2] or blankRow
	check(
		"M6.2 B's rows have no Remove and no Lead",
		#rowsB == 2 and not (firstB.remove or firstB.lead or secondB.remove or secondB.lead),
		`{#rowsB} rows`
	)
	local markersA = inspectUntil(A, function(ui)
		return #(ui.allyMarkers or {}) >= 1
	end)
	local markersB = inspectUntil(B, function(ui)
		return #(ui.allyMarkers or {}) >= 1
	end)
	check(
		"M6.2 A's markers are just B's name",
		table.concat(markersA.allyMarkers or {}, "|") == B.DisplayName,
		table.concat(markersA.allyMarkers or {}, "|")
	)
	check(
		"M6.2 B's markers are just A's name",
		table.concat(markersB.allyMarkers or {}, "|") == A.DisplayName,
		table.concat(markersB.allyMarkers or {}, "|")
	)
	setHealth(B, 40)
	local lowRow = inspectUntil(A, function(ui)
		local row = (ui.partyRows or {})[2]
		return row ~= nil and (row.health == "40 / 100" or row.health == "41 / 100")
	end)
	local lowSecond = (lowRow.partyRows or {})[2] or blankRow
	check(
		"M6.2 B at 40 health shows as 40 / 100 or 41 / 100 on A's panel",
		lowSecond.health == "40 / 100" or lowSecond.health == "41 / 100",
		`"{lowSecond.health}"`
	)
	heal(B)

	--------------------------------------------------------------------------- M6.3 refusals
	mB = mark(B)
	fire(B, "partyRequest")
	expectNote("M6.3 B is not the leader: PARTY_NOT_LEADER", B, mB, "PARTY_NOT_LEADER")
	-- B stands 3 studs from A. The leader's own party mates are not asked: nobody else is in
	-- range, so the request finds no one (and never refuses with B "already in a party").
	put(B, clearSpot(IN_TOWN, 3), IN_TOWN)
	mA = mark(A)
	fire(A, "partyRequest")
	expectNote("M6.3 A asks with only B near: EDICT_NO_TARGET", A, mA, "EDICT_NO_TARGET")
	check(
		"M6.3 and no PARTY_TARGET_IN_PARTY names B",
		noteSince(A, mA, "PARTY_TARGET_IN_PARTY") == nil,
		codesSince(A, mA)
	)
	check("M6.3 the party is unchanged by the request", pairIs(), partyText(A))
	local hostile = {
		{ label = "nil", value = nil },
		{ label = "5", value = 5 },
		{ label = "{}", value = {} },
		{ label = "kind steal", value = { kind = "steal" } },
		{ label = "kick without a user", value = { kind = "kick" } },
		{ label = "kick a string", value = { kind = "kick", userId = "x" } },
		{ label = "kick self", value = { kind = "kick", userId = A.UserId } },
		{ label = "promote NaN", value = { kind = "promote", userId = 0 / 0 } },
	}
	for _, entry in hostile do
		mA = mark(A)
		fire(A, "party", entry.value)
		expectNote(`M6.3 A's action ({entry.label}): BAD_REQUEST`, A, mA, "BAD_REQUEST")
	end
	mB = mark(B)
	fire(B, "party", { kind = "kick", userId = A.UserId })
	expectNote("M6.3 B's kick of A: PARTY_NOT_LEADER", B, mB, "PARTY_NOT_LEADER")
	check("M6.3 the party is unchanged after all of them", pairIs(), partyText(A))

	--------------------------------------------------------------------------- M6.4 no friendly fire
	shieldsDown()
	heal(A)
	heal(B)
	standApart(6)
	task.wait(0.3)
	local hB0 = health(B)
	local statusA0 = ProtectionService.status(A, os.clock())
	local marked0 = if statusA0 ~= nil then statusA0.markedUntil else nil
	mA = mark(A)
	strike(A)
	task.wait(1)
	local statusA1 = ProtectionService.status(A, os.clock())
	check(
		"M6.4 A's Strike at B: B's health has not fallen",
		health(B) >= hB0,
		`{fmt(hB0)} -> {fmt(health(B))}`
	)
	check(
		"M6.4 A's Strike at B: A is not Marked",
		marked0 ~= nil and statusA1 ~= nil and statusA1.markedUntil == marked0,
		`{tostring(marked0)} -> {tostring(statusA1 and statusA1.markedUntil)}`
	)
	check(
		"M6.4 A's Strike at B: no SAFE_ZONE, TARGET_SHIELDED or MARKED",
		noteSince(A, mA, "SAFE_ZONE") == nil
			and noteSince(A, mA, "TARGET_SHIELDED") == nil
			and noteSince(A, mA, "MARKED") == nil,
		codesSince(A, mA)
	)
	heal(B)
	hB0 = health(B)
	local bladeCast = cast(A, 3)
	task.wait(0.6)
	check("M6.4 A's Gust Blade was cast", bladeCast)
	check(
		"M6.4 A's Gust Blade at B: B's health has not fallen",
		health(B) >= hB0,
		`{fmt(hB0)} -> {fmt(health(B))}`
	)
	standApart(4)
	heal(A)
	heal(B)
	task.wait(0.3)
	local hA0 = health(A)
	local fieldCast = cast(B, 2)
	local lowest = lowestWalkSpeed(A, 2.5)
	check("M6.4 B's Sinking Field was cast", fieldCast)
	check(
		"M6.4 B's Sinking Field: A's health has not fallen over 2.5 s",
		health(A) >= hA0,
		`{fmt(hA0)} -> {fmt(health(A))}`
	)
	check("M6.4 B's Sinking Field: A's WalkSpeed stays 16", lowest == 16, fmt(lowest))
	-- A sleeping Brinehound, A 7 studs from it, B on the line 3.5 studs in front of A.
	check("M6.4 setup: a sleeping Brinehound", freshCreature(HOUND_1, nil))
	local houndAt = creatureAt(HOUND_1)
	local houndSpot = clearSpot(houndAt, 7)
	local toHound = Vector3.new(houndAt.X - houndSpot.X, 0, houndAt.Z - houndSpot.Z).Unit
	local inFront = houndSpot + toHound * 3.5
	put(A, houndSpot, houndAt)
	put(B, inFront, houndAt)
	heal(B)
	hB0 = health(B)
	strike(A)
	local houndNow = creatureHealth(HOUND_1)
	check(
		"M6.4 A's Strike past B reaches the Brinehound (60 to 40)",
		math.abs(houndNow - 40) < 0.6,
		fmt(houndNow)
	)
	check("M6.4 and B is unhurt", health(B) >= hB0, `{fmt(hB0)} -> {fmt(health(B))}`)
	local bladeAgain = cast(A, 3)
	task.wait(0.4)
	houndNow = creatureHealth(HOUND_1)
	check("M6.4 A's Gust Blade was cast again", bladeAgain)
	check(
		"M6.4 A's Gust Blade past B reaches the Brinehound (40 to 22)",
		math.abs(houndNow - 22) < 0.6,
		fmt(houndNow)
	)
	check("M6.4 and B is still unhurt", health(B) >= hB0, `{fmt(hB0)} -> {fmt(health(B))}`)

	--------------------------------------------------------------------------- M6.5 joining mid-fight
	partySyncs[A], partySyncs[B] = nil, nil
	mA, mB = mark(A), mark(B)
	send(A, "party", { kind = "leave" })
	expectNote("M6.5 A leaves: PARTY_LEFT", A, mA, "PARTY_LEFT")
	expectNote("M6.5 B hears PARTY_DISBANDED", B, mB, "PARTY_DISBANDED")
	check(
		"M6.5 both sync streams are false",
		waitFor(function()
			return partySyncs[A] == false and partySyncs[B] == false
		end, 3),
		`{tostring(partySyncs[A])}, {tostring(partySyncs[B])}`
	)
	local gone = inspectUntil(A, function(ui)
		return ui.partyVisible == false and #(ui.allyMarkers or {}) == 0
	end)
	check(
		"M6.5 A's panel is hidden and A has no markers",
		gone.partyVisible == false and #(gone.allyMarkers or {}) == 0,
		`{tostring(gone.partyVisible)}, markers {table.concat(gone.allyMarkers or {}, "|")}`
	)
	check(
		"M6.5 A and B are no longer allied",
		not Fighters.allied(A.UserId, B.UserId) and not Fighters.allied(B.UserId, A.UserId)
	)
	shieldsDown()
	heal(A)
	heal(B)
	standApart(6)
	task.wait(0.3)
	partyInvites[B] = nil
	mA = mark(A)
	send(A, "partyRequest")
	expectNote("M6.5 A invites B: PARTY_INVITE_SENT", A, mA, "PARTY_INVITE_SENT")
	hB0 = health(B)
	local boltCast = cast(A, 4)
	local hHit = health(B)
	check(
		"M6.5 A's Cinder Bolt hurts B while the invite is pending",
		boltCast and hHit < hB0,
		`accepted={tostring(boltCast)}, {fmt(hB0)} -> {fmt(hHit)}`
	)
	local boltAt = os.clock()
	send(B, "partyReply", true)
	check("M6.5 B accepts at once and joins", waitFor(pairIs, 3), partyText(A))
	task.wait(0.3)
	local h1 = health(B)
	task.wait(3.5)
	check(
		"M6.5 the burn stopped once they were allies",
		health(B) >= h1,
		`{fmt(h1)} -> {fmt(health(B))}`
	)
	mA, mB = mark(A), mark(B)
	if os.clock() - boltAt > 14 then
		log("M6.5 note: more than 14 s since the bolt")
	end
	CombatService.environmentDefeat(B)
	task.wait(2)
	check(
		"M6.5 B's fall gives A no claim",
		noteSince(A, mA, "CLAIM_STARTED") == nil and noteSince(A, mA, "CLAIM_COOLDOWN") == nil,
		codesSince(A, mA)
	)
	check(
		"M6.5 and B is not told DEFEATED_BY",
		noteSince(B, mB, "DEFEATED_BY") == nil,
		codesSince(B, mB)
	)
	check("M6.5 B respawns", waitAlive(B))
	check("M6.5 B is still in A's party", pairIs(), partyText(A))

	--------------------------------------------------------------------------- M6.6 support
	put(A, IN_TOWN, B_TOWN)
	put(B, B_TOWN, IN_TOWN)
	equip(B, 2, "rebuke")
	shieldsDown()
	heal(A)
	heal(B)
	standApart(10)
	task.wait(0.3)
	local wardOk = cast(B, 3)
	local shieldA, shieldB = statusOf(A), statusOf(B)
	check("M6.6 B's Ward was cast", wardOk)
	check(
		"M6.6 Ward with A 10 studs away: A shielded for 30",
		shieldA.shield == 30 and shieldA.shieldUntil > os.clock(),
		`shield {shieldA.shield}, left {fmt(shieldA.shieldUntil - os.clock())}`
	)
	check(
		"M6.6 Ward with A 10 studs away: B shielded for 30",
		shieldB.shield == 30 and shieldB.shieldUntil > os.clock(),
		`shield {shieldB.shield}, left {fmt(shieldB.shieldUntil - os.clock())}`
	)
	standApart(20)
	task.wait(0.3)
	local aUntil, bUntil = statusOf(A).shieldUntil, statusOf(B).shieldUntil
	local wardFar = cast(B, 3)
	check("M6.6 the next Ward was cast", wardFar)
	check(
		"M6.6 Ward with A 20 studs away: B's own shield renewed",
		statusOf(B).shieldUntil > bUntil,
		`{fmt(bUntil)} -> {fmt(statusOf(B).shieldUntil)}`
	)
	check(
		"M6.6 Ward with A 20 studs away: A's shield is unchanged",
		statusOf(A).shieldUntil == aUntil,
		`{fmt(aUntil)} -> {fmt(statusOf(A).shieldUntil)}`
	)
	standApart(10)
	task.wait(0.3)
	setHealth(A, 50)
	setHealth(B, 50)
	local renewalCast = cast(B, 4)
	task.wait(0.3)
	check("M6.6 B's Renewal was cast", renewalCast)
	check(
		"M6.6 Renewal with A 10 studs away: both at least 84",
		health(A) >= 84 and health(B) >= 84,
		`A {fmt(health(A))}, B {fmt(health(B))}`
	)
	-- Siphon on a sleeping Brinehound from 4 studs, A 10 studs from B.
	check("M6.6 setup: a sleeping Brinehound", freshCreature(HOUND_1, nil))
	houndAt = creatureAt(HOUND_1)
	local siphonSpot = clearSpot(houndAt, 4)
	local helperSpot = clearSpot(siphonSpot, 10)
	put(B, siphonSpot, houndAt)
	put(A, helperSpot, houndAt)
	setHealth(A, 50)
	local houndBefore = creatureHealth(HOUND_1)
	local siphonCast = cast(B, 1)
	task.wait(0.3)
	local lost = houndBefore - creatureHealth(HOUND_1)
	check("M6.6 B's Siphon was cast", siphonCast)
	check(
		"M6.6 Siphon: the Brinehound loses 14",
		math.abs(lost - 14) < 0.6,
		`{fmt(houndBefore)} -> {fmt(creatureHealth(HOUND_1))}`
	)
	check("M6.6 Siphon: A, 10 studs away at 50, is at least 63", health(A) >= 63, fmt(health(A)))
	-- Rebuke is only B's own.
	standApart(5)
	task.wait(0.3)
	local rebukeB, rebukeA = statusOf(B).reflectUntil, statusOf(A).reflectUntil
	local rebukeCast = cast(B, 2)
	check("M6.6 B's Rebuke was cast", rebukeCast)
	check(
		"M6.6 Rebuke: B reflects, A's reflect is unchanged",
		statusOf(B).reflectUntil > os.clock()
			and statusOf(B).reflectUntil > rebukeB
			and statusOf(A).reflectUntil == rebukeA,
		`B {fmt(rebukeB)} -> {fmt(statusOf(B).reflectUntil)}, A {fmt(rebukeA)} -> {fmt(
			statusOf(A).reflectUntil
		)}`
	)

	--------------------------------------------------------------------------- M6.6 protected caster
	standApart(10)
	task.wait(0.3)
	ProtectionService.mark(A, os.clock())
	dataB.shieldEnded = false
	aUntil = statusOf(A).shieldUntil
	local protectedWard = cast(B, 3)
	check("M6.6 setup: B, still under the new-player shield, casts Ward", protectedWard)
	check(
		"M6.6 a protected caster's Ward does not reach A, who is fighting",
		statusOf(A).shieldUntil == aUntil,
		`{fmt(aUntil)} -> {fmt(statusOf(A).shieldUntil)}`
	)
	check(
		"M6.6 and B's own shield is up (30)",
		statusOf(B).shield == 30 and statusOf(B).shieldUntil > os.clock(),
		`shield {statusOf(B).shield}`
	)
	dataB.shieldEnded = m6ShieldEnded
	B:LoadCharacter()
	check("M6.6 setup: B respawns", waitAlive(B))
	standApart(10)
	local respawnStatus = ProtectionService.status(B, os.clock())
	check(
		"M6.6 setup: B stands outside with the respawn shield up",
		respawnStatus ~= nil and respawnStatus.respawnShieldUntil > os.clock(),
		tostring(respawnStatus and respawnStatus.respawnShieldUntil)
	)
	aUntil = statusOf(A).shieldUntil
	local respawnWard = cast(B, 3)
	respawnStatus = ProtectionService.status(B, os.clock())
	check("M6.6 setup: B casts Ward under the respawn shield", respawnWard)
	check(
		"M6.6 an unprotected caster's Ward reaches A, who is fighting",
		statusOf(A).shield == 30 and statusOf(A).shieldUntil > aUntil,
		`{fmt(aUntil)} -> {fmt(statusOf(A).shieldUntil)}`
	)
	check(
		"M6.6 and reaching A ended B's respawn shield",
		respawnStatus ~= nil and respawnStatus.respawnShieldUntil == 0,
		tostring(respawnStatus and respawnStatus.respawnShieldUntil)
	)
	ProtectionService.endMark(A)

	--------------------------------------------------------------------------- M6.6 duel stays private
	shieldsDown()
	heal(A)
	heal(B)
	waitReady(B, 3)
	realSkip += 400
	local duelStarted = acceptTrial(A, "tallymans_duel")
	check("M6.6 setup: A starts the Tallyman's Duel", duelStarted)
	if duelStarted then
		put(B, clearSpot(positionOf(A), 8), positionOf(A))
		heal(A)
		aUntil = statusOf(A).shieldUntil
		local duelWard = cast(B, 3)
		check("M6.6 setup: B casts Ward 8 studs from A", duelWard)
		check("M6.6 setup: A is alive in the duel", health(A) > 0, fmt(health(A)))
		check(
			"M6.6 a Ward never reaches an ally in a duel",
			statusOf(A).shieldUntil == aUntil,
			`{fmt(aUntil)} -> {fmt(statusOf(A).shieldUntil)}`
		)
		mA = mark(A)
		clockSkip += 100
		expectNote("M6.6 the duel runs out: TRIAL_FAILED_TIME", A, mA, "TRIAL_FAILED_TIME", 3)
		waitFor(function()
			return TrialService.run(A) == nil
		end, 3)
	end
	heal(A)
	heal(B)

	--------------------------------------------------------------------------- M6.7 creature assist
	check("M6.7 setup: a sleeping Shellback at 60 health", freshCreature(SHELLBACK_1, 60))
	waitReady(B, 3)
	heal(A)
	heal(B)
	strikeCreature(A, SHELLBACK_1)
	check(
		"M6.7 A's Strike leaves the Shellback at 40",
		math.abs(creatureHealth(SHELLBACK_1) - 40) < 0.6,
		fmt(creatureHealth(SHELLBACK_1))
	)
	local shellAt = creatureAt(SHELLBACK_1)
	local aAt = positionOf(A)
	local behind = Vector3.new(aAt.X - shellAt.X, 0, aAt.Z - shellAt.Z).Unit
	local behindSpot = aAt + behind * 6
	if not Geography.isLand(behindSpot.X, behindSpot.Z) then
		behindSpot = clearSpot(aAt, 6)
	end
	put(B, behindSpot, shellAt)
	local assistWard = cast(B, 3)
	check("M6.7 B casts Ward 6 studs behind A", assistWard)
	local callingB = PathService.get(B).calling
	local coinB0, mendB0, callingXpB0 = coinOf(B), xpOf(B, "Mend"), xpOf(B, callingB)
	mA, mB = mark(A), mark(B)
	local shellHumanoid = creatureBody(SHELLBACK_1)
	if shellHumanoid ~= nil then
		shellHumanoid.Health = 15
	end
	strikeCreature(A, SHELLBACK_1)
	waitFor(function()
		return noteWith(B, mB, "CREATURE_DEFEATED", "coin", "10") ~= nil
	end, 3)
	check(
		"M6.7 A is paid: CREATURE_DEFEATED with 10 Coin",
		noteWith(A, mA, "CREATURE_DEFEATED", "coin", "10") ~= nil,
		codesSince(A, mA)
	)
	check(
		"M6.7 B, who only healed, is paid too: CREATURE_DEFEATED with 10 Coin",
		noteWith(B, mB, "CREATURE_DEFEATED", "coin", "10") ~= nil,
		codesSince(B, mB)
	)
	check("M6.7 B's Coin is up by 10", coinOf(B) == coinB0 + 10, `{coinB0} -> {coinOf(B)}`)
	check(
		"M6.7 B's Mend XP is up by 56",
		xpOf(B, "Mend") == mendB0 + 56,
		`{mendB0} -> {xpOf(B, "Mend")}`
	)
	check(
		"M6.7 B's Calling XP is unchanged",
		xpOf(B, callingB) == callingXpB0,
		`{callingXpB0} -> {xpOf(B, callingB)}`
	)
	-- Out of the party, the same help earns nothing.
	mA, mB = mark(A), mark(B)
	send(A, "party", { kind = "leave" })
	expectNote("M6.7 A leaves: PARTY_LEFT", A, mA, "PARTY_LEFT")
	expectNote("M6.7 B hears PARTY_DISBANDED", B, mB, "PARTY_DISBANDED")
	check("M6.7 setup: a second sleeping Shellback at 60 health", freshCreature(SHELLBACK_1, 60))
	waitReady(B, 3)
	strikeCreature(A, SHELLBACK_1)
	put(B, clearSpot(positionOf(A), 10), positionOf(A))
	aUntil = statusOf(A).shieldUntil
	local strangerWard = cast(B, 3)
	check("M6.7 B casts Ward 10 studs from A", strangerWard)
	check(
		"M6.7 and it does not reach A, who is no longer an ally",
		statusOf(A).shieldUntil == aUntil,
		`{fmt(aUntil)} -> {fmt(statusOf(A).shieldUntil)}`
	)
	coinB0 = coinOf(B)
	mA, mB = mark(A), mark(B)
	shellHumanoid = creatureBody(SHELLBACK_1)
	if shellHumanoid ~= nil then
		shellHumanoid.Health = 15
	end
	strikeCreature(A, SHELLBACK_1)
	expectNote("M6.7 A defeats it: CREATURE_DEFEATED", A, mA, "CREATURE_DEFEATED")
	task.wait(1)
	check(
		"M6.7 B gets no CREATURE_DEFEATED and no Coin",
		noteSince(B, mB, "CREATURE_DEFEATED") == nil and coinOf(B) == coinB0,
		`{codesSince(B, mB)}, {coinB0} -> {coinOf(B)}`
	)

	--------------------------------------------------------------------------- M6.8 the lead and removing
	put(A, IN_TOWN, B_TOWN)
	put(B, TRADE_B, IN_TOWN)
	check("M6.8 setup: a new party forms", joinB(), partyText(A))
	mA, mB = mark(A), mark(B)
	send(A, "party", { kind = "promote", userId = B.UserId })
	local leadA = expectNote(
		"M6.8 A hands over the lead: A hears PARTY_NEW_LEADER",
		A,
		mA,
		"PARTY_NEW_LEADER"
	)
	local leadB = expectNote("M6.8 B hears PARTY_NEW_LEADER", B, mB, "PARTY_NEW_LEADER")
	check("M6.8 both messages name B", names(leadA, B) and names(leadB, B))
	check("M6.8 B leads the party", partyIs(A, B.UserId, { A.UserId, B.UserId }), partyText(A))
	mA = mark(A)
	fire(A, "partyRequest")
	expectNote("M6.8 A is no longer the leader: PARTY_NOT_LEADER", A, mA, "PARTY_NOT_LEADER")
	partySyncs[A], partySyncs[B] = nil, nil
	mA, mB = mark(A), mark(B)
	send(B, "party", { kind = "kick", userId = A.UserId })
	local kicked = expectNote("M6.8 B removes A: A hears PARTY_KICKED", A, mA, "PARTY_KICKED")
	check("M6.8 PARTY_KICKED names B", names(kicked, B))
	expectNote("M6.8 B hears PARTY_DISBANDED", B, mB, "PARTY_DISBANDED")
	check(
		"M6.8 both sync streams are false",
		waitFor(function()
			return partySyncs[A] == false and partySyncs[B] == false
		end, 3),
		`{tostring(partySyncs[A])}, {tostring(partySyncs[B])}`
	)
	check("M6.8 no party is left", noParty())

	--------------------------------------------------------------------------- M6.9 fighting again
	shieldsDown()
	heal(A)
	heal(B)
	dataB.shieldEnded = true
	standApart(4)
	task.wait(0.5)
	hB0 = health(B)
	mA = mark(A)
	for _ = 1, 2 do
		strike(A)
		if health(B) < hB0 then
			break
		end
	end
	check(
		"M6.9 after leaving, A's Strike lands on B",
		health(B) < hB0,
		`{fmt(hB0)} -> {fmt(health(B))}; A got {codesSince(A, mA)}; A at {at(positionOf(A))}, B at {at(
			positionOf(B)
		)}`
	)
	heal(A)
	heal(B)
	waitAlive(A)
	waitAlive(B)
	put(A, IN_TOWN, B_TOWN)
	put(B, B_TOWN, IN_TOWN)
	check(
		"M6.9 A and B end alive in Tallyport and in no party",
		noParty() and health(A) > 0 and health(B) > 0
	)
end

------------------------------------------------------------------------------- M7 the endgame
-- Held caches, Crowning, the board and the badge (with stand-ins for both), Renounce, the Crown
-- Warden, the Gilded Bailiff, slow health regeneration and the rounds line. Three functions
-- (each stays under Luau's limit of 60 upvalues) share the `m7` table.
local BAILIFF = -2000026
local STONE_FRONT = Vector3.new(0, 3, 25) -- 6 studs in front of the Tally Stone, in Tallyport

local m7 = {
	-- B's new-player-shield flag as M7 found it, so run() can put it back if M7 stops half way.
	shieldEnded = nil,
	-- The stand-in board: every write, the stored counts, and whether the store "fails".
	fake = { writes = {}, rows = {}, failing = false },
	badgeCalls = {},
	star = "★",
}

m7.backend = {
	write = function(userId: number, crowns: number): boolean
		local fake = m7.fake
		if fake.failing then
			return false
		end
		table.insert(fake.writes, { userId, crowns })
		fake.rows[userId] = math.max(fake.rows[userId] or 0, crowns)
		return true
	end,
	readTop = function(count: number)
		local fake = m7.fake
		if fake.failing then
			return nil
		end
		local entries = {}
		for userId, crowns in fake.rows do
			table.insert(entries, { userId = userId, crowns = crowns })
		end
		table.sort(entries, function(x, y)
			if x.crowns ~= y.crowns then
				return x.crowns > y.crowns
			end
			return x.userId < y.userId
		end)
		while #entries > count do
			table.remove(entries)
		end
		return entries
	end,
}

-- Does the note's {player} argument name this player?
function m7.names(note, player: Player): boolean
	return note ~= nil and note.args ~= nil and note.args.player == player.DisplayName
end

-- The text of the player's CrownTag over their head ("" when there is none).
function m7.tagText(player: Player): string
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local tag = head and head:FindFirstChild("CrownTag")
	local label = tag and tag:FindFirstChildOfClass("TextLabel")
	return if label ~= nil then label.Text else ""
end

-- How many parts of one name the player's circlet has (-1 without a circlet).
function m7.circlet(player: Player, partName: string): number
	local character = player.Character
	local circlet = character and character:FindFirstChild("GiltCirclet")
	if circlet == nil then
		return -1
	end
	local count = 0
	for _, child in circlet:GetChildren() do
		if child.Name == partName then
			count += 1
		end
	end
	return count
end

function m7.ceremonyIs(payload, player: Player, crowns: number): boolean
	return type(payload) == "table"
		and payload.userId == player.UserId
		and payload.name == player.DisplayName
		and payload.crowns == crowns
end

-- Every Relic claimed, except `skip`.
function m7.claimedExcept(skip: string?)
	local claimed = {}
	for _, relic in Relics.list do
		if relic.id ~= skip then
			claimed[relic.id] = true
		end
	end
	return claimed
end

function m7.isComplete(player: Player): boolean
	local ledger = LedgerService.get(player)
	return ledger ~= nil and Ledger.isComplete(ledger)
end

-- A row of the Tally Stone's board.
function m7.stoneRow(index: number): string
	for _, stone in CollectionService:GetTagged("TallyStone") do
		local board = stone:FindFirstChild("Board")
		local row = board and board:FindFirstChild("Row" .. index)
		if row ~= nil and row:IsA("TextLabel") then
			return row.Text
		end
	end
	return "?"
end

function m7.roundsEmpty(record): boolean
	for _, round in Trials.rounds do
		local steps = record[round.id]
		if type(steps) ~= "table" or #steps ~= 0 then
			return false
		end
	end
	return true
end

-- Does one of the trial HUD's lines read exactly this?
function m7.hudHas(ui, text: string): boolean
	for _, line in ui.trialLines or {} do
		if line == text then
			return true
		end
	end
	return false
end

-- M7.1 to M7.5: the world, held caches, Crowning, one Crown per run, the board and the badge.
local function runM7World(A: Player, B: Player)
	local dataA = DataService.get(A)
	local fake = m7.fake

	--------------------------------------------------------------------------- M7.1 the world
	do
		local caches = #CollectionService:GetTagged("Cache")
		check("M7.1 31 caches are tagged", caches == 31, tostring(caches))
		-- Den creatures defeated earlier in the run may still be on their respawn timers (the
		-- Brine Colossus, defeated in M4.12, takes 600 s). Bring each of them back with the
		-- seam first, so the count checks the world, not how long ago a check ran.
		local waiting = {}
		for _, slot in World.creatureSlots do
			local info = CreatureService.info(slot.id)
			if info == nil or not info.alive then
				table.insert(waiting, `{slot.id} {slot.kind}`)
				CreatureService.respawn(slot.id)
			end
		end
		if #waiting > 0 then
			log(`M7.1 respawned den creatures still on their timers: {table.concat(waiting, ", ")}`)
			task.wait(0.5)
		end
		local models = 0
		for _, model in CollectionService:GetTagged("Creature") do
			if model:IsDescendantOf(workspace) then
				models += 1
			end
		end
		check("M7.1 26 creatures stand at their dens", models == 26, tostring(models))
		local wardens = #CollectionService:GetTagged("Warden")
		check("M7.1 10 Wardens stand", wardens == 10, tostring(wardens))
		local markers = #CollectionService:GetTagged("TrialMarker")
		check("M7.1 32 course markers are built", markers == 32, tostring(markers))
		local stones = CollectionService:GetTagged("TallyStone")
		local stone = stones[1]
		local stonePrompt = stone and stone:FindFirstChild("RenouncePrompt")
		local stoneBoard = stone and stone:FindFirstChild("Board")
		check(
			"M7.1 one Tally Stone with a Renounce prompt (hold 2) and a Board",
			#stones == 1
				and stonePrompt ~= nil
				and stonePrompt:IsA("ProximityPrompt")
				and stonePrompt.HoldDuration == 2
				and stoneBoard ~= nil
				and stoneBoard:IsA("SurfaceGui"),
			`{#stones} stones`
		)
		check(
			"M7.1 the Gilded Bailiff stands at 2400 health",
			creatureHealth(BAILIFF) == 2400,
			tostring(creatureHealth(BAILIFF))
		)
		local island = workspace:FindFirstChild("Island")
		local c029 = island and island:FindFirstChild("C029")
		local c031 = island and island:FindFirstChild("C031")
		local p029 = c029 and c029:FindFirstChildOfClass("ProximityPrompt")
		local p031 = c031 and c031:FindFirstChildOfClass("ProximityPrompt")
		check(
			"M7.1 the prompts of C029 and C031 hold 3 and 10 seconds",
			p029 ~= nil and p029.HoldDuration == 3 and p031 ~= nil and p031.HoldDuration == 10,
			`{if p029 then p029.HoldDuration else "none"}, {if p031
				then p031.HoldDuration
				else "none"}`
		)
		local ui = inspectUntil(A, function(snapshot)
			return snapshot.ledgerSlotCount == 50
		end)
		check("M7.1 A's book has 50 slots", ui.ledgerSlotCount == 50, tostring(ui.ledgerSlotCount))
	end

	--------------------------------------------------------------------------- M7.2 held caches
	do
		local rock = Vector3.new(0, 3, 1284)
		put(A, rock, Vector3.new(0, 3, 1290))
		check(
			"M7.2 setup: A stands 6 studs from C029 on the Rock",
			flatDistance(positionOf(A), rock) <= 1.5,
			at(positionOf(A))
		)
		local freeBefore = freeText(A)
		local m = mark(A)
		local code = SourceService.tryOpen(A, "C029")
		check("M7.2 opening C029 with no hold: HOLD_TOO_SHORT", code == "HOLD_TOO_SHORT", code)
		-- The seam also tells A, and A's agent echoes that message back a moment later. Wait
		-- for the echo, or it lands after the next mark and reads as the prompt's answer.
		expectNote("M7.2 A is told HOLD_TOO_SHORT", A, m, "HOLD_TOO_SHORT")
		check(
			"M7.2 and A's free slots are unchanged",
			freeText(A) == freeBefore and not hasFree(A, "R044"),
			`{freeBefore} -> {freeText(A)}`
		)
		m = mark(A)
		send(A, "prompt", "C029")
		expectNote("M7.2 holding C029's prompt: GOT_CARD", A, m, "GOT_CARD", 6)
		check("M7.2 A has the Tide-Turner's Hourglass", hasFree(A, "R044"), freeText(A))

		local ledges = World.climbs.C031
		local top = ledges[#ledges]
		local standOn = Vector3.new(top.x + 2.5, top.top + 3, top.z)
		put(A, standOn, Vector3.new(top.x, top.top + 3, top.z))
		check(
			"M7.2 setup: A stands on the Throne's top ledge",
			flatDistance(positionOf(A), standOn) <= 1.5,
			at(positionOf(A))
		)
		m = mark(A)
		send(A, "prompt", "C031")
		expectNote("M7.2 holding C031's prompt for 10 seconds: GOT_CARD", A, m, "GOT_CARD", 14)
		check("M7.2 A has the Hoarder's Crown", hasFree(A, "R050"), freeText(A))
		check(
			"M7.2 one copy of R050 is held",
			SourceService.held("R050") == 1,
			tostring(SourceService.held("R050"))
		)
	end

	--------------------------------------------------------------------------- M7.3 Crowning
	put(A, IN_TOWN, B_TOWN)
	put(B, B_TOWN, IN_TOWN)
	LedgerService.set(A, { claimed = m7.claimedExcept("R050"), free = { "R050" } })
	ceremonies[A], ceremonies[B] = nil, nil
	local mA, mB = mark(A), mark(B)
	send(A, "ledger", { kind = "claim", freeIndex = 1, cardId = "R050" })
	local crowned = expectNote("M7.3 A hears CROWNED_YOU", A, mA, "CROWNED_YOU")
	check(
		"M7.3 the title is Crowned",
		crowned ~= nil and crowned.args ~= nil and crowned.args.title == "Crowned",
		if crowned ~= nil and crowned.args ~= nil then tostring(crowned.args.title) else "none"
	)
	local completeA = expectNote("M7.3 A hears LEDGER_COMPLETE", A, mA, "LEDGER_COMPLETE")
	local completeB = expectNote("M7.3 B hears LEDGER_COMPLETE", B, mB, "LEDGER_COMPLETE")
	check("M7.3 both messages name A", m7.names(completeA, A) and m7.names(completeB, A))
	check(
		"M7.3 both clients got the ceremony: A, one Crown",
		waitFor(function()
			return m7.ceremonyIs(ceremonies[A], A, 1) and m7.ceremonyIs(ceremonies[B], A, 1)
		end, 3),
		`{typeof(ceremonies[A])}, {typeof(ceremonies[B])}`
	)
	local uiBanner = inspectUntil(B, function(snapshot)
		return snapshot.ceremonyVisible == true
	end)
	check(
		"M7.3 B's banner shows A's name",
		uiBanner.ceremonyVisible == true and has(uiBanner.ceremonyText, A.DisplayName),
		`{tostring(uiBanner.ceremonyVisible)}, "{tostring(uiBanner.ceremonyText)}"`
	)
	check(
		"M7.3 A's record: 1 Crown, 0 stars",
		dataA.crown.crowns == 1 and dataA.crown.stars == 0,
		`{dataA.crown.crowns}, {dataA.crown.stars}`
	)
	check(
		"M7.3 A's Crowns and Stars attributes read 1 and 0",
		A:GetAttribute("Crowns") == 1 and A:GetAttribute("Stars") == 0,
		`{tostring(A:GetAttribute("Crowns"))}, {tostring(A:GetAttribute("Stars"))}`
	)
	check(
		"M7.3 A's CrownTag reads Crowned",
		waitFor(function()
			return m7.tagText(A) == "Crowned"
		end, 3),
		`"{m7.tagText(A)}"`
	)
	check(
		"M7.3 A wears a circlet of 6 points and no gem",
		m7.circlet(A, "CircletPoint") == 6 and m7.circlet(A, "CircletGem") == 0,
		`{m7.circlet(A, "CircletPoint")} points, {m7.circlet(A, "CircletGem")} gems`
	)
	check(
		"M7.3 a CrownLight stands in Effects",
		waitFor(function()
			local effects = workspace:FindFirstChild("Effects")
			return effects ~= nil and effects:FindFirstChild("CrownLight") ~= nil
		end, 2)
	)
	local crownLine = "Crowned. You may Renounce at the Tally Stone in Tallyport."
	local uiA = inspectUntil(A, function(snapshot)
		return snapshot.crownLine == crownLine and snapshot.stonePromptEnabled == true
	end)
	check(
		"M7.3 A's book says how to Renounce and the stone's prompt is on",
		uiA.crownLine == crownLine and uiA.stonePromptEnabled == true,
		`"{tostring(uiA.crownLine)}", prompt {tostring(uiA.stonePromptEnabled)}`
	)
	local uiB = inspect(B)
	check(
		"M7.3 B's stone prompt is off",
		uiB.stonePromptEnabled == false,
		tostring(uiB.stonePromptEnabled)
	)
	check(
		"M7.3 A's complete Ledger steps aside: no R050 is held",
		SourceService.held("R050") == 0,
		tostring(SourceService.held("R050"))
	)

	--------------------------------------------------------------------------- M7.4 one Crown per run
	mA, mB = mark(A), mark(B)
	fire(A, "ledger", { kind = "unclaim", cardId = "R050" })
	expectNote("M7.4 A unclaims R050: UNCLAIMED", A, mA, "UNCLAIMED")
	fire(A, "ledger", { kind = "claim", freeIndex = 1, cardId = "R050" })
	expectNote("M7.4 A claims it again: CLAIMED", A, mA, "CLAIMED")
	task.wait(2)
	check(
		"M7.4 no second Crown: no new LEDGER_COMPLETE or CROWNED_YOU",
		noteSince(A, mA, "LEDGER_COMPLETE") == nil
			and noteSince(A, mA, "CROWNED_YOU") == nil
			and noteSince(B, mB, "LEDGER_COMPLETE") == nil,
		`A got {codesSince(A, mA)}, B got {codesSince(B, mB)}`
	)
	check(
		"M7.4 A still has 1 Crown",
		dataA.crown.crowns == 1 and dataA.crown.stars == 0,
		`{dataA.crown.crowns}, {dataA.crown.stars}`
	)

	--------------------------------------------------------------------------- M7.5 board and badge
	waitFor(function()
		return #fake.writes >= 1 and dataA.crown.boardCrowns == 1
	end, 6)
	check(
		"M7.5 the board is written once for A, one Crown",
		#fake.writes == 1
			and fake.writes[1][1] == A.UserId
			and fake.writes[1][2] == 1
			and dataA.crown.boardCrowns == 1,
		`{#fake.writes} writes, boardCrowns {dataA.crown.boardCrowns}`
	)
	LeaderboardService.refreshNow()
	local view = LeaderboardService.board()
	local row1 = `1. {A.Name}: Crowned`
	check(
		"M7.5 the board reads The Crowned, All time, every server, A first",
		view.title == "The Crowned"
			and view.subtitle == "All time, every server"
			and #view.rows == 1
			and view.rows[1] == row1,
		`{view.title} / {view.subtitle} / {table.concat(view.rows, " | ")}`
	)
	check("M7.5 the board is online", LeaderboardService.isOnline())
	check(
		"M7.5 the Tally Stone's first row matches",
		m7.stoneRow(1) == view.rows[1],
		`"{m7.stoneRow(1)}"`
	)
	task.wait(3)
	check("M7.5 still the same writes 3 seconds on", #fake.writes == 1, tostring(#fake.writes))
	local badges = m7.badgeCalls
	check(
		"M7.5 the badge was awarded once: A, 4242",
		waitFor(function()
			return #badges >= 1
		end, 3)
			and #badges == 1
			and badges[1][1] == A.UserId
			and badges[1][2] == 4242,
		`{#badges} calls`
	)
	check(
		"M7.5 A's record says the badge was awarded",
		waitFor(function()
			return dataA.crown.badgeAwarded == true
		end, 2)
	)
	fake.failing = true
	LeaderboardService.refreshNow()
	local failView = LeaderboardService.board()
	check(
		"M7.5 with the store failing the stone says this server only",
		failView.subtitle == "This server only: the all-time records cannot be reached"
			and failView.rows[1] == row1
			and not LeaderboardService.isOnline(),
		`{failView.subtitle} / {table.concat(failView.rows, " | ")}`
	)
	fake.failing = false
	LeaderboardService.refreshNow()
end

-- M7.6 to M7.11: Renounce refusals, the two-step confirm, Renouncing, a second Crown, no badge
-- without an id, a Marked Claimant, and the Crown Warden.
local function runM7Renounce(A: Player, B: Player)
	local dataA = DataService.get(A)
	local fake = m7.fake
	local stoneFace = Vector3.new(0, 3, 32)

	--------------------------------------------------------------------------- M7.6 refusals
	put(A, OUTSIDE, OUTSIDE_2)
	local code = CrownService.beginRenounce(A)
	check("M7.6 A outside town: RENOUNCE_NOT_IN_TOWN", code == "RENOUNCE_NOT_IN_TOWN", code)
	check("M7.6 and no offer opens", CrownService.offer(A) == nil)
	put(B, STONE_FRONT, stoneFace)
	code = CrownService.beginRenounce(B)
	check(
		"M7.6 B at the stone with no Crown: RENOUNCE_NOT_READY",
		code == "RENOUNCE_NOT_READY",
		code
	)
	local mA = mark(A)
	check("M7.6 setup: A starts the Grand Tally", acceptTrial(A, "grand_tally"), codesSince(A, mA))
	code = CrownService.beginRenounce(A)
	check("M7.6 A in a trial: EDICT_IN_TRIAL", code == "EDICT_IN_TRIAL", code)
	mA = mark(A)
	clockSkip += 400
	expectNote("M7.6 the trial runs out of time: TRIAL_FAILED_TIME", A, mA, "TRIAL_FAILED_TIME", 4)
	check(
		"M7.6 no trial is left running",
		waitFor(function()
			return TrialService.run(A) == nil
		end, 3)
	)
	put(A, TRADE_A, TRADE_B)
	put(B, TRADE_B, TRADE_A)
	check("M7.6 setup: A and B open a trade", openTrade(A, B))
	code = CrownService.beginRenounce(A)
	check("M7.6 A in a trade: RENOUNCE_TRADING", code == "RENOUNCE_TRADING", code)
	mA = mark(A)
	fire(B, "trade", { kind = "cancel" })
	expectNote("M7.6 B cancels: A gets TRADE_CANCELLED", A, mA, "TRADE_CANCELLED")
	check(
		"M7.6 no trade is left",
		waitFor(function()
			return TradeService.session(A) == nil
		end, 3)
	)

	--------------------------------------------------------------------------- M7.7 the two-step confirm
	put(A, STONE_FRONT, stoneFace)
	put(B, B_TOWN, IN_TOWN)
	renounceOffers[A] = nil
	send(A, "renouncePrompt")
	check(
		"M7.7 holding the stone's prompt opens the offer: 5 lines, 60 seconds",
		waitFor(function()
			local offer = renounceOffers[A]
			return type(offer) == "table"
		end, 6)
			and #renounceOffers[A].lines == 5
			and renounceOffers[A].seconds == 60,
		typeof(renounceOffers[A])
	)
	check("M7.7 the server keeps the offer", CrownService.offer(A) ~= nil)
	local uiOffer = inspectUntil(A, function(snapshot)
		return snapshot.renounceVisible == true
	end)
	check("M7.7 A's Renounce window is open", uiOffer.renounceVisible == true)

	mA = mark(A)
	fire(A, "renounce", { kind = "confirm", word = "renounce please" })
	expectNote("M7.7 a wrong word: RENOUNCE_WORD", A, mA, "RENOUNCE_WORD")
	mA = mark(A)
	fire(A, "renounce", { kind = "confirm", word = 5 })
	expectNote("M7.7 a number for the word: RENOUNCE_WORD", A, mA, "RENOUNCE_WORD")
	mA = mark(A)
	fire(A, "renounce", nil)
	expectNote("M7.7 hostile nil: BAD_REQUEST", A, mA, "BAD_REQUEST")
	for _, case in
		{
			{ label = "string", value = "x" },
			{ label = "empty table", value = {} },
			{ label = "unknown kind", value = { kind = "steal" } },
		} :: { any }
	do
		mA = mark(A)
		fire(A, "renounce", case.value)
		expectNote(`M7.7 hostile {case.label}: BAD_REQUEST`, A, mA, "BAD_REQUEST")
	end
	check(
		"M7.7 after all that A's Ledger is complete and the offer still stands",
		m7.isComplete(A) and CrownService.offer(A) ~= nil
	)
	local mB = mark(B)
	fire(B, "renounce", { kind = "confirm", word = "RENOUNCE" })
	expectNote("M7.7 B with no offer: RENOUNCE_NO_OFFER", B, mB, "RENOUNCE_NO_OFFER")
	mA = mark(A)
	fire(A, "renounce", { kind = "cancel" })
	expectNote("M7.7 A cancels: RENOUNCE_CANCELLED", A, mA, "RENOUNCE_CANCELLED")
	check(
		"M7.7 the offer is gone on the server and on the screen",
		CrownService.offer(A) == nil
			and waitFor(function()
				return renounceOffers[A] == false
			end, 3),
		tostring(renounceOffers[A])
	)
	mA = mark(A)
	fire(A, "renounce", { kind = "confirm", word = "RENOUNCE" })
	expectNote("M7.7 a confirm after cancelling: RENOUNCE_NO_OFFER", A, mA, "RENOUNCE_NO_OFFER")
	code = CrownService.beginRenounce(A)
	check("M7.7 setup: a new offer opens", code == "RENOUNCE_OFFER", code)
	CrownService.setClock(function()
		return os.clock() + 61
	end)
	mA = mark(A)
	fire(A, "renounce", { kind = "confirm", word = "RENOUNCE" })
	expectNote("M7.7 a confirm after 61 seconds: RENOUNCE_EXPIRED", A, mA, "RENOUNCE_EXPIRED")
	CrownService.setClock(os.clock)
	check(
		"M7.7 an expired offer changed nothing",
		m7.isComplete(A) and CrownService.offer(A) == nil
	)

	--------------------------------------------------------------------------- M7.8 Renounce
	LedgerService.set(A, { claimed = m7.claimedExcept(nil), free = { "E001", "R001" } })
	LedgerService.setVault(A, { R007 = true })
	setCoin(A, 500)
	local cooldownAt = os.time() + realSkip + 200
	dataA.trials = { cooldowns = { tidewalk = cooldownAt }, questStep = 2 }
	dataA.rounds = { wardens = { "tidewalk" }, beasts = { "brinehound" } }
	-- Show A's HUD the quest at step 2 first, so "starts again" below really tests the resync
	-- the Renounce sends (a HUD that was never told about step 2 already reads 0 / 4).
	TrialService.resync(A)
	local uiStep2 = inspectUntil(A, function(snapshot)
		for _, line in snapshot.trialLines or {} do
			if has(line, "The Unpaid Debt: 2 / 4") then
				return true
			end
		end
		return false
	end)
	check(
		"M7.8 setup: A's trial HUD reads The Unpaid Debt: 2 / 4",
		has(table.concat(uiStep2.trialLines or {}, " | "), "The Unpaid Debt: 2 / 4"),
		table.concat(uiStep2.trialLines or {}, " | ")
	)
	local xpBefore = table.clone(PathService.get(A).xp)
	local shieldBefore = dataA.shieldEnded
	renounceOffers[A] = nil
	send(A, "renouncePrompt")
	check(
		"M7.8 setup: the offer opens again",
		waitFor(function()
			return type(renounceOffers[A]) == "table"
		end, 6),
		typeof(renounceOffers[A])
	)
	mA, mB = mark(A), mark(B)
	fire(A, "renounce", { kind = "confirm", word = "  renounce " })
	expectNote("M7.8 A Renounces: RENOUNCE_DONE", A, mA, "RENOUNCE_DONE")
	local renounced = expectNote("M7.8 B hears RENOUNCED", B, mB, "RENOUNCED")
	check("M7.8 the message names A", m7.names(renounced, A))
	local ledgerA = LedgerService.get(A)
	check(
		"M7.8 A's Ledger is empty",
		ledgerA ~= nil and Ledger.claimedCount(ledgerA) == 0 and #ledgerA.free == 0
	)
	check("M7.8 A's Vault is empty", next(LedgerService.getVault(A) or { x = true }) == nil)
	check("M7.8 A keeps 500 Coin", coinOf(A) == 500, tostring(coinOf(A)))
	local xpKept = true
	local xpNow = PathService.get(A).xp
	for path, xp in xpBefore do
		if xpNow[path] ~= xp then
			xpKept = false
		end
	end
	for path, xp in xpNow do
		if xpBefore[path] ~= xp then
			xpKept = false
		end
	end
	check("M7.8 A keeps every Path's XP", xpKept)
	check(
		"M7.8 the Unpaid Debt starts again and the Tidewalk cooldown is kept",
		dataA.trials.questStep == 0 and dataA.trials.cooldowns.tidewalk == cooldownAt,
		`step {dataA.trials.questStep}, cooldown {tostring(dataA.trials.cooldowns.tidewalk)}`
	)
	check("M7.8 both rounds start again", m7.roundsEmpty(dataA.rounds))
	check(
		"M7.8 the record: 1 Crown, 1 star, board and badge kept",
		dataA.crown.crowns == 1
			and dataA.crown.stars == 1
			and dataA.crown.boardCrowns == 1
			and dataA.crown.badgeAwarded == true,
		`{dataA.crown.crowns}, {dataA.crown.stars}, {dataA.crown.boardCrowns}, {tostring(
			dataA.crown.badgeAwarded
		)}`
	)
	check("M7.8 A's Stars attribute reads 1", A:GetAttribute("Stars") == 1)
	local starTitle = "Crowned " .. m7.star .. "1"
	check(
		"M7.8 A's CrownTag reads Crowned with a star",
		waitFor(function()
			return m7.tagText(A) == starTitle
		end, 3),
		`"{m7.tagText(A)}"`
	)
	check(
		"M7.8 the circlet has 1 gem",
		m7.circlet(A, "CircletGem") == 1,
		tostring(m7.circlet(A, "CircletGem"))
	)
	local uiDone = inspectUntil(A, function(snapshot)
		return snapshot.renounceVisible == false
	end)
	check(
		"M7.8 the offer is cleared and the window is closed",
		renounceOffers[A] == false and uiDone.renounceVisible == false,
		`{tostring(renounceOffers[A])}, {tostring(uiDone.renounceVisible)}`
	)
	local questLine = "The Unpaid Debt: 0 / 4, next: Tidewalk"
	local uiQuest = inspectUntil(A, function(snapshot)
		return m7.hudHas(snapshot, questLine)
	end)
	check(
		"M7.8 A's trial HUD reads The Unpaid Debt: 0 / 4, next: Tidewalk",
		m7.hudHas(uiQuest, questLine),
		table.concat(uiQuest.trialLines or {}, " | ")
	)
	check(
		"M7.8 A's new-player shield flag is unchanged",
		dataA.shieldEnded == shieldBefore,
		`{tostring(shieldBefore)} -> {tostring(dataA.shieldEnded)}`
	)

	--------------------------------------------------------------------------- M7.9 a second Crown
	ceremonies[B] = nil
	mA, mB = mark(A), mark(B)
	LedgerService.set(A, { claimed = m7.claimedExcept(nil), free = {} })
	local second = expectNote("M7.9 A is Crowned again: CROWNED_YOU", A, mA, "CROWNED_YOU")
	local twice = "Crowned twice " .. m7.star .. "1"
	check(
		"M7.9 the title is Crowned twice with a star",
		second ~= nil and second.args ~= nil and second.args.title == twice,
		if second ~= nil and second.args ~= nil then tostring(second.args.title) else "none"
	)
	expectNote("M7.9 B hears LEDGER_COMPLETE", B, mB, "LEDGER_COMPLETE")
	check(
		"M7.9 B's banner counts 2 Crowns",
		waitFor(function()
			return m7.ceremonyIs(ceremonies[B], A, 2)
		end, 3),
		typeof(ceremonies[B])
	)
	check("M7.9 A has 2 Crowns", dataA.crown.crowns == 2, tostring(dataA.crown.crowns))
	check(
		"M7.9 A's CrownTag reads Crowned twice with a star",
		waitFor(function()
			return m7.tagText(A) == twice
		end, 3),
		`"{m7.tagText(A)}"`
	)
	check("M7.9 the board gets A's second Crown", waitFor(function()
		return #fake.writes >= 2
	end, 6) and fake.writes[2][1] == A.UserId and fake.writes[2][2] == 2, `{#fake.writes} writes`)
	check("M7.9 the badge is not awarded twice", #m7.badgeCalls == 1, `{#m7.badgeCalls} calls`)

	--------------------------------------------------------------------------- M7.10 no badge without an id, and Marked
	local lateBadges = {}
	CrownService.setBadge(0, function(userId, badgeId)
		table.insert(lateBadges, { userId, badgeId })
		return true
	end)
	mB = mark(B)
	LedgerService.set(B, { claimed = m7.claimedExcept(nil), free = {} })
	expectNote("M7.10 B is Crowned: CROWNED_YOU", B, mB, "CROWNED_YOU")
	task.wait(1.5)
	check("M7.10 with badge id 0 nothing is awarded", #lateBadges == 0, `{#lateBadges} calls`)
	ProtectionService.mark(B, os.clock())
	put(A, IN_TOWN, B_TOWN)
	put(B, STONE_FRONT, stoneFace)
	code = CrownService.beginRenounce(B)
	check("M7.10 a Marked B at the stone: EDICT_MARKED", code == "EDICT_MARKED", code)

	--------------------------------------------------------------------------- M7.11 the Crown Warden
	local offer = talkTo(A, "grand_tally")
	check(
		"M7.11 the Crown Warden offers The Grand Tally and its Crown Relic",
		offer.title == "The Grand Tally"
			and offer.relicText == "Relic: The Orb of Every Shore (Crown)",
		`{tostring(offer.title)}, {tostring(offer.relicText)}`
	)
	local uiGrand = inspectUntil(A, function(snapshot)
		return snapshot.offerVisible == true
	end)
	check(
		"M7.11 the window shows it with Accept on",
		uiGrand.offerVisible == true and uiGrand.acceptActive == true,
		`{tostring(uiGrand.offerTitle)}, {tostring(uiGrand.offerRelic)}`
	)
	send(A, "closeOffer")
	setFree(B, { "R049" }, LedgerService.get(B).claimed)
	local sealedOffer = talkTo(A, "grand_tally")
	check(
		"M7.11 with a copy held, the offer reads sealed on this server",
		has(sealedOffer.relicText, "sealed on this server"),
		tostring(sealedOffer.relicText)
	)
	send(A, "closeOffer")
end

-- M7.12 to M7.15: the Gilded Bailiff and the Beast Tally, regeneration, the rounds line, and a
-- Crowned title in the party panel.
local function runM7Endgame(A: Player, B: Player)
	local dataA = DataService.get(A)

	--------------------------------------------------------------------------- M7.12 the Gilded Bailiff
	LedgerService.set(A, Ledger.new())
	dataA.rounds.beasts = { "brinehound", "shellback", "bogspitter", "brine_colossus" }
	check("M7.12 setup: the Gilded Bailiff at 15 health", freshCreature(BAILIFF, 15))
	heal(A)
	local coinBefore = coinOf(A)
	local mA, mB = mark(A), mark(B)
	strikeCreature(A, BAILIFF)
	local defeated = nil
	waitFor(function()
		defeated = noteWith(A, mA, "CREATURE_DEFEATED", "coin", "120")
		return defeated ~= nil
	end, 4)
	check("M7.12 A is told the Bailiff is defeated: 120 Coin", defeated ~= nil, codesSince(A, mA))
	check(
		"M7.12 A gets the Gilded Sceptre although B's Ledger holds one claimed",
		waitFor(function()
			return hasFree(A, "R048")
		end, 3),
		`{freeText(A)}; A got {codesSince(A, mA)}`
	)
	check("M7.12 but not the 30% drop on a roll of 0.5", not hasFree(A, "R041"), freeText(A))
	local roundDone = nil
	waitFor(function()
		roundDone = noteWith(A, mA, "ROUND_COMPLETE", "name", "The Beast Tally")
		return roundDone ~= nil
	end, 4)
	check(
		"M7.12 the Beast Tally is complete: 250 Coin",
		roundDone ~= nil and roundDone.args.coin == "250",
		codesSince(A, mA)
	)
	check("M7.12 A has the Menagerie Ledger and the round starts again", waitFor(function()
		return hasFree(A, "R047")
	end, 3) and #dataA.rounds.beasts == 0, `{freeText(A)}; beasts {#dataA.rounds.beasts}`)
	check(
		"M7.12 A was paid 120 and 250 Coin",
		coinOf(A) == coinBefore + 370,
		`{coinBefore} -> {coinOf(A)}`
	)
	check(
		"M7.12 B, who did not hit it, hears nothing of it",
		noteSince(B, mB, "CREATURE_DEFEATED") == nil
	)

	--------------------------------------------------------------------------- M7.13 regeneration
	put(A, IN_TOWN, B_TOWN)
	put(B, B_TOWN, IN_TOWN)
	heal(A)
	task.wait(0.5)
	local humanoid = humanoidOf(A)
	if humanoid ~= nil then
		humanoid.Health = 50
	end
	local startedAt = os.clock()
	local hurt = health(A)
	task.wait(5)
	local early = health(A)
	check(
		"M7.13 5 seconds after a loss no health has come back",
		early <= hurt + 0.01,
		`{fmt(hurt)} -> {fmt(early)}`
	)
	task.wait(math.max(0, startedAt + 14 - os.clock()))
	local later = health(A)
	check(
		"M7.13 14 seconds after it, health is coming back",
		later >= hurt + 2,
		`{fmt(hurt)} -> {fmt(later)}`
	)

	--------------------------------------------------------------------------- M7.14 the rounds line
	local roundsLine = "Warden's Round 0 / 9, Beast Tally 0 / 5"
	local uiRounds = inspectUntil(A, function(snapshot)
		local lines = snapshot.trialLines or {}
		return lines[#lines] == roundsLine
	end)
	local lines = uiRounds.trialLines or {}
	check(
		"M7.14 the trial HUD ends with the rounds line",
		lines[#lines] == roundsLine,
		table.concat(lines, " | ")
	)

	--------------------------------------------------------------------------- M7.15 the title in the party panel
	put(A, TRADE_A, TRADE_B)
	put(B, TRADE_B, TRADE_A)
	partyInvites[B] = nil
	send(A, "partyRequest")
	local invited = waitFor(function()
		return type(partyInvites[B]) == "table"
	end, 3)
	task.wait(0.3)
	send(B, "partyReply", true)
	check("M7.15 setup: A and B form a party", invited and waitFor(function()
		return PartyService.party(A) ~= nil and PartyService.party(B) ~= nil
	end, 3))
	local twice = "Crowned twice " .. m7.star .. "1"
	local function titleOfA(snapshot): string?
		for _, row in snapshot.partyRows or {} do
			if has(row.name, A.DisplayName) then
				return row.title
			end
		end
		return nil
	end
	local uiParty = inspectUntil(B, function(snapshot)
		return titleOfA(snapshot) == twice
	end)
	check(
		"M7.15 B's party panel shows A as Crowned twice with a star",
		titleOfA(uiParty) == twice,
		tostring(titleOfA(uiParty))
	)
	fire(A, "party", { kind = "leave" })
	waitFor(function()
		return PartyService.party(A) == nil and PartyService.party(B) == nil
	end, 3)
end

-- The endgame: Crowning, the board and badge, Renounce, the Crown Relics, regeneration.
local function runM7(A: Player, B: Player)
	waitAlive(A)
	waitAlive(B)
	local dataA, dataB = DataService.get(A), DataService.get(B)
	m7.shieldEnded = dataB.shieldEnded
	-- Both players are still Marked and inside the 30-second fight window from earlier
	-- sections, which would refuse trades and Renounce.
	ProtectionService.endRespawnShield(A)
	ProtectionService.endRespawnShield(B)
	ProtectionService.endMark(A)
	ProtectionService.endMark(B)
	waitNoFight(A)
	waitNoFight(B)
	CreatureService.setActive({})
	CreatureService.setRng(function()
		return 0.5
	end)
	TrialService.setClocks(function()
		return os.clock() + clockSkip
	end, function()
		return os.time() + realSkip
	end)
	CrownService.setClock(os.clock)
	heal(A)
	heal(B)
	put(A, IN_TOWN, B_TOWN)
	put(B, B_TOWN, IN_TOWN)
	for _, player in { A, B } do
		local data = DataService.get(player)
		LedgerService.set(player, Ledger.new())
		data.crown = Crown.newRecord()
		data.rounds = Rounds.new()
		data.trials = { cooldowns = {}, questStep = 0 }
		CrownService.refresh(player)
		setCoin(player, 500)
	end
	-- The stand-in board starts empty; the real one is never touched.
	m7.fake.writes, m7.fake.rows, m7.fake.failing = {}, {}, false
	LeaderboardService.setBackend(m7.backend)
	LeaderboardService.refreshNow()
	m7.badgeCalls = {}
	local badgeCalls = m7.badgeCalls
	CrownService.setBadge(4242, function(userId, badgeId)
		table.insert(badgeCalls, { userId, badgeId })
		return true
	end)
	check(
		"M7 setup: both players start with an empty Ledger, no Crown and 500 Coin",
		Ledger.claimedCount(LedgerService.get(A)) == 0
			and dataA.crown.crowns == 0
			and dataB.crown.crowns == 0
			and coinOf(A) == 500
			and coinOf(B) == 500
	)

	runM7World(A, B)
	runM7Renounce(A, B)
	runM7Endgame(A, B)
end

------------------------------------------------------------------------------- M8 launch polish
-- The UI kit, the menu row, where each control sits, two taps to unclaim or discard, the region
-- banner, the blight tint, a Coin change reaching an open trade, a new character's health watch
-- and the party panel. Taps go through the agent's press seam. Four parts (each stays under
-- Luau's limit of upvalues) share the `m8` table.
local m8 = {
	-- What runM8 changed that m8.restore puts back: A's Ledger, Vault and Coin as M8 found them.
	saved = {},
	-- Each window's kind, by the window's name.
	kinds = {
		Book = "big",
		Claim = "big",
		Shop = "big",
		Trade = "big",
		Panel = "big",
		Picker = "big",
		RelicPicker = "big",
		PlayerPicker = "small",
		Result = "small",
		Offer = "small",
		Renounce = "small",
		Confirm = "dialog",
		ConfirmDrop = "dialog",
	},
	windows = {
		"Book",
		"Claim",
		"Shop",
		"Trade",
		"Panel",
		"Picker",
		"Confirm",
		"RelicPicker",
		"PlayerPicker",
		"Result",
		"Offer",
		"Renounce",
		"ConfirmDrop",
	},
	menuNames = { "LedgerButton", "PathsButton", "TradeButton", "PartyButton" },
}

-- True when the rectangle is there and every one of its four values is within 1 pixel of `want`.
function m8.near(got, want): boolean
	return type(got) == "table"
		and math.abs(got.x - want.x) <= 1
		and math.abs(got.y - want.y) <= 1
		and math.abs(got.width - want.width) <= 1
		and math.abs(got.height - want.height) <= 1
end

function m8.rectText(rect): string
	if type(rect) ~= "table" then
		return "missing"
	end
	return string.format("(%.0f, %.0f, %.0f x %.0f)", rect.x, rect.y, rect.width, rect.height)
end

-- How many of the objects fail the test.
function m8.countBad(list: { Instance }, passes: (Instance) -> boolean): number
	local bad = 0
	for _, item in list do
		if not passes(item) then
			bad += 1
		end
	end
	return bad
end

-- M8.1 to M8.3: the kit, the layout and the menu row.
function m8.kit(A: Player, B: Player)
	--------------------------------------------------------------------------- M8.1 the kit
	local ui = inspect(A)
	check("M8.1 14 screens are made with the kit", ui.isleGuis == 14, tostring(ui.isleGuis))
	local bordered = ui.bordered or {}
	check("M8.1 no control has a border", #bordered == 0, table.concat(bordered, ", "))
	check("M8.1 the four old open buttons are gone", ui.oldButtons == 0, tostring(ui.oldButtons))
	local menu = ui.menu or {}
	local present = 0
	for _, name in m8.menuNames do
		if menu[name] ~= nil then
			present += 1
		end
	end
	check("M8.1 the menu row has its four buttons", present == 4, `{present} of 4`)

	--------------------------------------------------------------------------- M8.2 the layout
	local l = ui.layoutIn or { width = 0, height = 0, insetY = 0, touch = false }
	local want = HudLayout.compute(l.width, l.height, l.insetY, l.touch)
	for index, name in m8.menuNames do
		check(
			`M8.2 {name} sits where HudLayout puts it`,
			m8.near(menu[name], want.menu[index]),
			`{m8.rectText(menu[name])}, want {m8.rectText(want.menu[index])} on {l.width} x {l.height}, inset {l.insetY}`
		)
	end
	check(
		"M8.2 the ability bar sits where HudLayout puts it",
		m8.near(ui.abilityBar, want.abilityBar),
		`{m8.rectText(ui.abilityBar)}, want {m8.rectText(want.abilityBar)}`
	)
	local mins = ui.windowMins or {}
	for _, name in m8.windows do
		local kind = m8.kinds[name]
		local least = HudLayout.WINDOW_MIN[kind]
		local got = mins[name]
		check(
			`M8.2 the {name} window never gets smaller than the {kind} size`,
			type(got) == "table" and got.x == least.width and got.y == least.height,
			if type(got) == "table" then `{got.x} x {got.y}` else tostring(got)
		)
	end

	--------------------------------------------------------------------------- M8.3 the menu row works
	send(A, "toggleLedger", false)
	send(A, "togglePaths", false)
	task.wait(0.3)
	local r = press(A, "MenuGui/LedgerButton")
	check("M8.3 the Ledger button takes a tap", r.ok == true, tostring(r.ok))
	ui = inspectUntil(A, function(snapshot)
		return snapshot.bookVisible == true
	end)
	check("M8.3 the Ledger book opens", ui.bookVisible == true)
	press(A, "MenuGui/LedgerButton")
	ui = inspectUntil(A, function(snapshot)
		return snapshot.bookVisible == false
	end)
	check("M8.3 the same button closes it", ui.bookVisible == false)

	r = press(A, "MenuGui/PathsButton")
	check("M8.3 the Paths button takes a tap", r.ok == true, tostring(r.ok))
	ui = inspectUntil(A, function(snapshot)
		return snapshot.pathsPanelVisible == true
	end)
	check("M8.3 the Paths panel opens", ui.pathsPanelVisible == true)
	press(A, "MenuGui/PathsButton")
	ui = inspectUntil(A, function(snapshot)
		return snapshot.pathsPanelVisible == false
	end)
	check("M8.3 the same button closes it", ui.pathsPanelVisible == false)

	tradeInvites[B] = nil
	local fromA = mark(A)
	r = press(A, "MenuGui/TradeButton")
	check("M8.3 the Trade button takes a tap", r.ok == true, tostring(r.ok))
	check(
		"M8.3 B is invited to trade",
		waitFor(function()
			return type(tradeInvites[B]) == "table"
		end, 3),
		tostring(tradeInvites[B])
	)
	send(B, "tradeReply", false)
	expectNote("M8.3 B declines: A hears TRADE_DECLINED", A, fromA, "TRADE_DECLINED")
	waitFor(function()
		return tradeInvites[B] == false
	end, 3)

	partyInvites[B] = nil
	r = press(A, "MenuGui/PartyButton")
	check("M8.3 the Party button takes a tap", r.ok == true, tostring(r.ok))
	check(
		"M8.3 B is invited to a party",
		waitFor(function()
			return type(partyInvites[B]) == "table"
		end, 3),
		tostring(partyInvites[B])
	)
	task.wait(0.3)
	send(B, "partyReply", false)
	waitFor(function()
		return partyInvites[B] == false
	end, 3)
	task.wait(0.3)
end

-- M8.4 to M8.6: two taps to unclaim or discard, and a refused request's row coming back.
function m8.ledger(A: Player)
	--------------------------------------------------------------------------- M8.4 two taps to unclaim
	setFree(A, {}, { R001 = true, R002 = true })
	send(A, "toggleLedger", true)
	local wantProgress = `Relics: 2 / {Relics.count}`
	local ui = inspectUntil(A, function(snapshot)
		return snapshot.progress == wantProgress
	end)
	check(
		"M8.4 setup: the book shows two Relics claimed",
		ui.progress == wantProgress,
		tostring(ui.progress)
	)
	local m = mark(A)
	local r = press(A, "LedgerGui/Book/Slots/Slot001")
	check(
		"M8.4 the first tap on a slot asks for another",
		r.ok == true and has(r.text, "Tap again"),
		`ok {tostring(r.ok)}, "{tostring(r.text)}"`
	)
	r = press(A, "LedgerGui/Book/Slots/Slot001")
	check("M8.4 the second tap goes through", r.ok == true, tostring(r.ok))
	local note = expectNote("M8.4 the second tap unclaims: UNCLAIMED", A, m, "UNCLAIMED")
	check(
		"M8.4 the message names the Relic",
		note ~= nil and note.args ~= nil and note.args.name == Relics.byId.R001.name,
		if note ~= nil and note.args ~= nil then tostring(note.args.name) else "no message"
	)
	check("M8.4 the Relic is in A's free slots", hasFree(A, "R001"), freeText(A))

	-- The sync of the unclaim has to reach the book before the next slot is tapped.
	inspectUntil(A, function(snapshot)
		return (snapshot.freeRows or {}).Free1 ~= nil
	end)
	m = mark(A)
	r = press(A, "LedgerGui/Book/Slots/Slot002")
	check(
		"M8.4 a tap on another slot arms that one",
		r.ok == true and has(r.text, "Tap again"),
		`ok {tostring(r.ok)}, "{tostring(r.text)}"`
	)
	task.wait(3.5)
	ui = inspect(A)
	local slotText = (ui.ledgerSlots or {}).Slot002
	check(
		"M8.4 after 3 seconds the slot is back to normal",
		slotText ~= nil and not has(slotText, "Tap again"),
		tostring(slotText)
	)
	check("M8.4 and nothing was unclaimed", noteSince(A, m, "UNCLAIMED") == nil, codesSince(A, m))
	press(A, "LedgerGui/Book/Slots/Slot002")
	expectNoNote("M8.4 a tap after the wait only arms the slot again", A, m, "UNCLAIMED")
	press(A, "LedgerGui/Book/Slots/Slot002")
	expectNote("M8.4 the next tap unclaims: UNCLAIMED", A, m, "UNCLAIMED")

	--------------------------------------------------------------------------- M8.5 two taps to discard
	setFree(A, { "R003" })
	inspectUntil(A, function(snapshot)
		local rows = snapshot.freeRows or {}
		return rows.Free1 ~= nil and rows.Free2 == nil
	end)
	m = mark(A)
	r = press(A, "LedgerGui/Book/FreeCards/Free1/Discard")
	check(
		"M8.5 the first tap on Discard reads Sure?",
		r.ok == true and r.text == "Sure?",
		`ok {tostring(r.ok)}, "{tostring(r.text)}"`
	)
	expectNoNote("M8.5 one tap discards nothing", A, m, "DISCARDED")
	press(A, "LedgerGui/Book/FreeCards/Free1/Discard")
	expectNote("M8.5 the second tap discards: DISCARDED", A, m, "DISCARDED")
	check("M8.5 A's free slots are empty", #freeOf(A) == 0, freeText(A))

	--------------------------------------------------------------------------- M8.6 a refused request's row comes back
	-- The discarded row has to be gone from the book before the next card arrives.
	inspectUntil(A, function(snapshot)
		return (snapshot.freeRows or {}).Free1 == nil
	end)
	setFree(A, { "R004" })
	ui = inspectUntil(A, function(snapshot)
		local row = (snapshot.freeRows or {}).Free1
		return row ~= nil and row.Claim ~= nil
	end)
	check(
		"M8.6 setup: the new card has a Claim button",
		((ui.freeRows or {}).Free1 or {}).Claim ~= nil
	)
	LedgerService.lock(A)
	m = mark(A)
	r = press(A, "LedgerGui/Book/FreeCards/Free1/Claim")
	check(
		"M8.6 a tap on Claim sends the request and dims the row",
		r.ok == true and r.active == false,
		`ok {tostring(r.ok)}, active {tostring(r.active)}`
	)
	expectNote("M8.6 the locked Ledger refuses: LEDGER_LOCKED", A, m, "LEDGER_LOCKED")
	task.wait(1.5)
	ui = inspect(A)
	local claim = ((ui.freeRows or {}).Free1 or {}).Claim
	check(
		"M8.6 with no sync, the row comes back by itself",
		claim ~= nil and claim.active == true,
		if claim ~= nil then tostring(claim.active) else "no Claim button"
	)
	LedgerService.unlock(A)
	m = mark(A)
	press(A, "LedgerGui/Book/FreeCards/Free1/Claim")
	expectNote("M8.6 and the next tap claims: CLAIMED", A, m, "CLAIMED")
	send(A, "toggleLedger", false)
end

-- M8.7 to M8.9: the region banner, the blight tint, and a Coin change reaching an open trade.
function m8.world(A: Player, B: Player)
	--------------------------------------------------------------------------- M8.7 the region banner
	put(A, IN_TOWN, B_TOWN)
	task.wait(1)
	-- An earlier message may still be on screen or waiting behind another.
	waitFor(function()
		return inspect(A).toast == ""
	end, 8)
	LedgerService.notify(A, "EDICT_NOT_NOW")
	local x, z = Geography.place("Thornwood", 290, 0)
	place(A, Vector3.new(x, 3, z), Vector3.zero)
	local hint = Regions.byId.Thornwood.hint
	local ui = inspectUntil(A, function(snapshot)
		return snapshot.regionBanner ~= nil and snapshot.regionBanner ~= ""
	end)
	check(
		"M8.7 entering Thornwood shows its banner",
		ui.regionBanner == "Thornwood: " .. hint,
		tostring(ui.regionBanner)
	)
	check(
		"M8.7 and the message is still on screen beside it",
		ui.toast == Messages.format("EDICT_NOT_NOW"),
		tostring(ui.toast)
	)
	put(A, TRADE_A, TRADE_B)

	--------------------------------------------------------------------------- M8.8 the blight tint
	local island = workspace:FindFirstChild("Island")
	local blight = island and island:FindFirstChild("Blight")
	local hush = Sites.hazardById.HushBlight
	local wanted = #Hazards.overlay(hush, Geography.strips())
	local slabs = if blight ~= nil then blight:GetChildren() else {}
	check(
		"M8.8 Island.Blight has one tint slab for each covered strip piece",
		blight ~= nil and wanted > 0 and #slabs == wanted,
		`{#slabs} slabs, want {wanted}`
	)
	local look = Looks.byName.blight
	check("M8.8 every slab is a Part named BlightTint", m8.countBad(slabs, function(slab)
		return slab:IsA("Part") and slab.Name == "BlightTint"
	end) == 0)
	check("M8.8 every slab is anchored and touches nothing", m8.countBad(slabs, function(slab)
		return slab:IsA("BasePart")
			and slab.Anchored
			and not slab.CanCollide
			and not slab.CanQuery
			and not slab.CanTouch
	end) == 0)
	check("M8.8 every slab has the blight look", m8.countBad(slabs, function(slab)
		return slab:IsA("BasePart")
			and math.round(slab.Color.R * 255) == look.r
			and math.round(slab.Color.G * 255) == look.g
			and math.round(slab.Color.B * 255) == look.b
			and slab.Material.Name == look.material
			and math.abs(slab.Transparency - look.transparency) <= 0.001
	end) == 0, `{look.r}, {look.g}, {look.b} {look.material} {look.transparency}`)
	check("M8.8 no slab is tagged Hazard", m8.countBad(slabs, function(slab)
		return not CollectionService:HasTag(slab, "Hazard")
	end) == 0)
	check("M8.8 every slab lies in the blight", m8.countBad(slabs, function(slab)
		return slab:IsA("BasePart") and Hazards.affects(hush, slab.Position.X, slab.Position.Z)
	end) == 0)

	--------------------------------------------------------------------------- M8.9 a Coin change reaches an open trade
	setCoin(A, 100)
	check("M8.9 setup: A and B open a trade", openTrade(A, B))
	local viewA = tradeViews[A]
	check(
		"M8.9 the trade shows the 100 Coin A holds",
		type(viewA) == "table" and viewA.coinHeld == 100,
		if type(viewA) == "table" then tostring(viewA.coinHeld) else "no view"
	)
	SourceService.addCoin(A, 25)
	local grew = waitFor(function()
		local view = tradeViews[A]
		return type(view) == "table" and view.coinHeld == 125
	end, 3)
	local grownView = tradeViews[A]
	check(
		"M8.9 25 Coin more reach A's open trade within 3 seconds",
		grew,
		if type(grownView) == "table" then tostring(grownView.coinHeld) else "no view"
	)
	check("M8.9 and the trade is still open", TradeService.session(A) ~= nil)
	local m = mark(A)
	send(A, "trade", { kind = "cancel" })
	expectNote("M8.9 A cancels: TRADE_CANCELLED", A, m, "TRADE_CANCELLED")
end

-- M8.10 and M8.11: a new character's health watch, and the party panel's place.
function m8.life(A: Player, B: Player)
	--------------------------------------------------------------------------- M8.10 a new character is watched
	A:LoadCharacter()
	check("M8.10 setup: A's new character spawns", waitAlive(A))
	ProtectionService.endRespawnShield(A)
	put(A, IN_TOWN, B_TOWN)
	heal(A)
	local humanoid = humanoidOf(A)
	if humanoid ~= nil then
		humanoid.Health = 50
	end
	-- Regeneration starts 10 seconds after the loss, at 1 a second.
	task.wait(5)
	check(
		"M8.10 5 seconds after a loss no health has come back",
		health(A) <= 50.01,
		fmt(health(A))
	)
	task.wait(9)
	check("M8.10 14 seconds after it, health is coming back", health(A) >= 52, fmt(health(A)))

	--------------------------------------------------------------------------- M8.11 the party panel
	heal(A)
	put(A, IN_TOWN, B_TOWN)
	put(B, TRADE_B, TRADE_A)
	partyInvites[B] = nil
	send(A, "partyRequest")
	local invited = waitFor(function()
		return type(partyInvites[B]) == "table"
	end, 3)
	task.wait(0.3)
	send(B, "partyReply", true)
	check("M8.11 setup: A and B form a party", invited and waitFor(function()
		return PartyService.party(A) ~= nil and PartyService.party(B) ~= nil
	end, 3))
	local ui = inspectUntil(B, function(snapshot)
		return snapshot.partyVisible == true and #(snapshot.partyRows or {}) == 2
	end)
	local l = ui.layoutIn or { width = 0, height = 0, insetY = 0, touch = false }
	local want = HudLayout.compute(l.width, l.height, l.insetY, l.touch)
	local panel = ui.partyPanel
	check("M8.11 B's party panel is on screen", type(panel) == "table", m8.rectText(panel))
	if type(panel) == "table" then
		local hit = "none"
		for index, rect in want.menu do
			if HudLayout.overlaps(panel, rect) then
				hit = m8.menuNames[index]
			end
		end
		check(
			"M8.11 the panel covers no menu button",
			hit == "none",
			`{m8.rectText(panel)} covers {hit}`
		)
		check(
			"M8.11 the panel does not cover the ability bar",
			not HudLayout.overlaps(panel, want.abilityBar),
			`{m8.rectText(panel)} and {m8.rectText(want.abilityBar)}`
		)
		check(
			"M8.11 its right edge is 12 pixels in from the screen's",
			math.abs(panel.x + panel.width - (l.width - 12)) <= 1,
			`{fmt(panel.x + panel.width)}, want {l.width - 12}`
		)
		check(
			"M8.11 its width is the layout's party width",
			math.abs(panel.width - want.partyWidth) <= 1,
			`{fmt(panel.width)}, want {want.partyWidth}`
		)
	end
	local rowOfA = nil
	local names = {}
	for _, row in ui.partyRows or {} do
		table.insert(names, row.name)
		if row.name == `{A.DisplayName} (leader)` then
			rowOfA = row
		end
	end
	check("M8.11 A's row reads A (leader)", rowOfA ~= nil, table.concat(names, " | "))
	check(
		"M8.11 a long name ends in dots instead of shrinking",
		rowOfA ~= nil and rowOfA.truncate == "AtEnd",
		if rowOfA ~= nil then tostring(rowOfA.truncate) else "no row"
	)
	send(A, "party", { kind = "leave" })
	task.wait(0.5)
end

-- Sets the section up, then runs its parts in order.
local function runM8(A: Player, B: Player)
	waitAlive(A)
	waitAlive(B)
	-- What m8.restore puts back.
	m8.saved = {
		ledger = LedgerService.get(A),
		vault = LedgerService.getVault(A),
		coin = coinOf(A),
	}
	-- Both players may still be Marked, shielded or in the 30-second fight window from earlier
	-- sections, which would refuse trades and parties.
	ProtectionService.endRespawnShield(A)
	ProtectionService.endRespawnShield(B)
	ProtectionService.endMark(A)
	ProtectionService.endMark(B)
	waitNoFight(A)
	waitNoFight(B)
	CreatureService.setActive({})
	heal(A)
	heal(B)
	put(A, TRADE_A, TRADE_B)
	put(B, TRADE_B, TRADE_A)

	m8.kit(A, B)
	m8.ledger(A)
	m8.world(A, B)
	m8.life(A, B)
end

-- Puts back what M8 changed, even when it stopped half way: the Ledger lock, the open windows,
-- any trade or party, A's Ledger, Vault and Coin, and both players alive in town.
function m8.restore(A: Player, B: Player)
	LedgerService.unlock(A)
	send(A, "toggleLedger", false)
	send(A, "togglePaths", false)
	send(A, "trade", { kind = "cancel" })
	send(B, "trade", { kind = "cancel" })
	send(B, "party", { kind = "leave" })
	task.wait(0.4)
	send(A, "party", { kind = "leave" })
	task.wait(0.4)
	waitAlive(A)
	waitAlive(B)
	local saved = m8.saved
	if saved.ledger ~= nil then
		LedgerService.set(A, saved.ledger)
	end
	if saved.vault ~= nil then
		LedgerService.setVault(A, saved.vault)
	end
	if saved.coin ~= nil then
		setCoin(A, saved.coin)
	end
	m8.saved = {}
	heal(A)
	heal(B)
	put(A, IN_TOWN, B_TOWN)
	put(B, B_TOWN, IN_TOWN)
end

-- Logs every prompt event that reaches the server (hold began, hold ended, triggered), with the
-- time, so a failed prompt check shows whether the client sent anything at all. With the
-- agent's prompt traces this tells "nothing left the client" from "the server heard a trigger
-- but no hold".
local function tracePrompts(island: Instance)
	for _, prompt in island:GetDescendants() do
		if prompt:IsA("ProximityPrompt") then
			local where = if prompt.Parent ~= nil and prompt.Parent.Parent ~= nil
				then `{prompt.Parent.Parent.Name}.{prompt.Parent.Name}`
				else prompt:GetFullName()
			local function note(event: string)
				return function(player: Player)
					log(
						string.format(
							"server prompt %s %s by %s at %.2f s",
							where,
							event,
							player.Name,
							os.clock()
						)
					)
				end
			end
			prompt.PromptButtonHoldBegan:Connect(note("hold began"))
			prompt.PromptButtonHoldEnded:Connect(note("hold ended"))
			prompt.Triggered:Connect(note("triggered"))
		end
	end
end

local function run()
	log("waiting for 2 players")
	if not waitFor(function()
		return #Players:GetPlayers() >= 2
	end, 180) then
		log("ABORT fewer than 2 players joined")
		return
	end
	local list = Players:GetPlayers()
	table.sort(list, function(x, y)
		return x.Name < y.Name
	end)
	local A, B = list[1], list[2]
	log(`A = {A.Name} ({A.UserId}), B = {B.Name} ({B.UserId})`)
	-- A stand-in board and badge for the whole run: M1.11 Crowns A, and neither the real data
	-- store nor the real BadgeService may be touched. A round may be in flight, so redraw once
	-- the swap is made. M7 swaps in fresh stand-ins; the restore after M7 puts the real ones back.
	LeaderboardService.setBackend(m7.backend)
	LeaderboardService.refreshNow()
	CrownService.setBadge(4242, function(userId, badgeId)
		table.insert(m7.badgeCalls, { userId, badgeId })
		return true
	end)
	check(
		"both players' data loads",
		waitFor(function()
			return LedgerService.get(A) ~= nil and LedgerService.get(B) ~= nil
		end, 60)
	)
	check("both characters spawn", waitAlive(A) and waitAlive(B))
	-- No creature disturbs M1 to M3: they all stand still until M4 wakes one.
	CreatureService.setActive({})
	check(
		"both agents ready",
		waitFor(function()
			return ready[A] == true and ready[B] == true
		end, 30)
	)
	task.wait(1.5)

	--------------------------------------------------------------------------- world
	local island = workspace:FindFirstChild("Island")
	check("M1.1 island is built", island ~= nil)
	if island ~= nil then
		tracePrompts(island)
	end
	local cacheCount = #CollectionService:GetTagged("Cache")
	check("M1.1 31 caches tagged", cacheCount == 31, tostring(cacheCount))
	local town = island and island:FindFirstChild("Tallyport")
	local spawnPad = town and town:FindFirstChild("Spawn")
	check("M2 spawn gives no default force field", spawnPad ~= nil and spawnPad.Duration == 0)
	check("M2 safe-zone disc exists", town ~= nil and town:FindFirstChild("SafeZone") ~= nil)

	--------------------------------------------------------------------------- W the wide island
	-- The ground and the hazard markers, then one hazard at a time on A. Health is refilled
	-- before each measurement and read with health(), as in the M3 ability checks. Island
	-- damage sets health directly, so A's new-player and respawn shields do not matter here.
	do
		local ground = island and island:FindFirstChild("Ground")
		local groundCount = if ground ~= nil then #ground:GetChildren() else -1
		check("W.1 Island.Ground has 144 parts", groundCount == 144, tostring(groundCount))

		local areaHazards = 0
		for _, hazard in Sites.hazards do
			if hazard.shape.kind ~= "region" then
				areaHazards += 1
			end
		end
		local markers = island and island:FindFirstChild("Hazards")
		local markerList = if markers ~= nil then markers:GetChildren() else {}
		local unnamed = 0
		for _, marker in markerList do
			local hazardId = marker:GetAttribute("HazardId")
			if type(hazardId) ~= "string" or Sites.hazardById[hazardId] == nil then
				unnamed += 1
			end
		end
		check(
			"W.2 Island.Hazards has one marker per area hazard, each naming a hazard",
			markers ~= nil and #markerList == areaHazards and unnamed == 0,
			`{#markerList} markers for {areaHazards} area hazards, {unnamed} not naming a hazard`
		)

		-- A stands 3 studs up (the ground's top is y = 0) looking at the island centre.
		local function stand(x: number, z: number)
			place(A, Vector3.new(x, 3, z), Vector3.zero)
		end
		local function backToTown()
			stand(0, 10)
		end

		-- Lava: 30 damage a second, so 1.5 s in the middle of a pool costs at least 25.
		local pool = Sites.hazardById.CinderPool1.shape
		heal(A)
		local beforeLava = health(A)
		stand(pool.x, pool.z)
		task.wait(1.5)
		check(
			"W.3 lava: 1.5 s at the centre of CinderPool1 costs at least 25 health",
			beforeLava - health(A) >= 25,
			`{fmt(beforeLava)} -> {fmt(health(A))}`
		)

		-- Spring: heals 15 a second, but its centre also lies in the Hush blight (5 a second).
		-- From 40, two seconds should leave A above 50.
		local spring = Sites.hazardById.HushSpring1.shape
		heal(A)
		local humanoid = humanoidOf(A)
		if humanoid ~= nil then
			humanoid.Health = 40
		end
		local beforeSpring = health(A)
		stand(spring.x, spring.z)
		task.wait(2)
		check(
			"W.4 spring: 2 s at the centre of HushSpring1 lifts 40 health above 50",
			health(A) > 50,
			`{fmt(beforeSpring)} -> {fmt(health(A))}`
		)

		-- Bog: half speed. Along 650 of the Fen is in the rotted gap, off the boardwalk.
		local bogX, bogZ = Geography.place("DrownedFen", 650, 0)
		heal(A)
		stand(bogX, bogZ)
		local slowest = lowestWalkSpeed(A, 1)
		check(
			"W.5 bog: WalkSpeed is below 10 within 1 s in the Fen's rotted gap",
			slowest < 10,
			`lowest WalkSpeed {fmt(slowest)}`
		)

		-- Vent: 35 damage once per eruption, not once per tick. An eruption lasts 1 s of a 6 s
		-- cycle, and a window of one period plus 0.5 s could hold two of them if it opened
		-- late in a cycle. So wait in town until the vent has just finished erupting, then
		-- stand in it.
		local ventHazard = Sites.hazardById.CinderVent1
		local vent = ventHazard.shape
		local period = ventHazard.cycle.period
		backToTown()
		waitFor(function()
			local phase, _, elapsed = Hazards.phase(ventHazard, workspace:GetServerTimeNow())
			return phase == "idle" and elapsed < 0.15
		end, period + 1)
		heal(A)
		local beforeVent = health(A)
		stand(vent.x, vent.z)
		task.wait(period + 0.5)
		local ventLoss = beforeVent - health(A)
		check(
			"W.6 vent: a period at the centre of CinderVent1 costs 30 to 59 health (one hit)",
			ventLoss >= 30 and ventLoss < 60,
			`{fmt(beforeVent)} -> {fmt(health(A))}`
		)

		-- Drowning: (-600, -8, 0) is in the west river, where there is no ground.
		heal(A)
		place(A, Vector3.new(-600, -8, 0), Vector3.zero)
		check(
			"W.7 drowning: A is defeated within 3 s in the west river",
			waitFor(function()
				return health(A) <= 0
			end, 3),
			`health {fmt(health(A))}`
		)
		check("W.7 A respawns after drowning", waitAlive(A))

		-- Back in town with full health for the checks that follow.
		heal(A)
		backToTown()
		task.wait(0.6)
	end

	--------------------------------------------------------------------------- M2.1 shields at start
	local now = os.clock()
	local sa = ProtectionService.status(A, now)
	local sb = ProtectionService.status(B, now)
	check("M2.1 A starts with the new-player shield", sa ~= nil and sa.newShield)
	check("M2.1 B starts with the new-player shield", sb ~= nil and sb.newShield)
	check(
		"M2.1 respawn shield runs about 60 s from spawn",
		sa ~= nil and sa.respawnShieldUntil - now > 30 and sa.respawnShieldUntil - now <= 60
	)
	check("M2.1 A has the Shield force field", A.Character:FindFirstChild("Shield") ~= nil)
	local rootA = rootOf(A)
	local spawnAt = if rootA ~= nil then rootA.Position else Vector3.zero
	log(`A spawned at {math.floor(spawnAt.X)}, {math.floor(spawnAt.Y)}, {math.floor(spawnAt.Z)}`)
	check("M2.1 A spawns inside Tallyport", sa ~= nil and sa.inSafeZone, tostring(spawnAt))
	local uiA = inspectForLine(A, "Safe zone")
	check(
		"M2.1 A's HUD shows Safe zone",
		hasLine(uiA, "Safe zone"),
		`{table.concat(uiA.statusLines or {}, "; ")} | client sees root at {uiA.rootPos}, inSafeZone={uiA.clientSafe}`
	)
	check("M2.1 A's HUD shows New-player shield", hasLine(uiA, "New-player shield"))
	check("M2.1 A's HUD shows Respawn shield", hasLine(uiA, "Respawn shield"))
	check("M2.1 A sees the Drop shield button", uiA.dropShieldVisible == true)
	check("M2.1 Strike input is bound", uiA.strikeBound == true)
	check("M1 Ledger UI is mounted", uiA.ledgerGui == true)

	LedgerService.set(A, { claimed = {}, free = {} })
	LedgerService.set(B, { claimed = {}, free = {} })

	--------------------------------------------------------------------------- M3.1 the Calling picker
	do
		for _, who in { A, B } do
			local firstJoin = inspectUntil(who, function(snapshot)
				return snapshot.pickerVisible == true
			end)
			check(
				`M3.1 {who.Name} sees the Calling picker with six Paths`,
				firstJoin.pickerVisible == true and firstJoin.pickerCards == 6,
				`visible={tostring(firstJoin.pickerVisible)}, cards={tostring(firstJoin.pickerCards)}`
			)
		end
		local progressA = PathService.get(A)
		check(
			"M3.1 A has no Calling yet",
			progressA ~= nil and progressA.calling == "",
			if progressA ~= nil then `calling "{progressA.calling}"` else "no data"
		)
		local fresh = inspect(A)
		check("M3.1 the Paths button is on screen", fresh.pathsButton == true)
		check(
			'M3.1 the Paths panel title reads "Choose your Calling"',
			fresh.callingText == "Choose your Calling",
			tostring(fresh.callingText)
		)
		check(
			"M3.1 the ability bar is empty",
			barText(fresh, 1) == EMPTY_BAR and barText(fresh, 4) == EMPTY_BAR,
			barDump(fresh)
		)
		local mNoCalling = mark(A)
		send(A, "cast", 1)
		expectNote("M3.1 casting with no Calling: NO_CALLING", A, mNoCalling, "NO_CALLING")
	end

	--------------------------------------------------------------------------- M3.2 choosing a Calling
	do
		local mPick = mark(A)
		send(A, "pickCalling", "Fang")
		local chosen = expectNote("M3.2 A picks Fang: CALLING_CHOSEN", A, mPick, "CALLING_CHOSEN")
		check(
			"M3.2 the message names Fang",
			chosen ~= nil and chosen.args ~= nil and chosen.args.path == "Fang"
		)
		local progressA = PathService.get(A)
		check(
			"M3.2 Fang is A's Calling",
			progressA ~= nil and progressA.calling == "Fang",
			if progressA ~= nil then `calling "{progressA.calling}"` else "no data"
		)
		check(
			"M3.2 a first Calling starts at level 3",
			levelOf(A, "Fang") == 3,
			`Fang XP {xpOf(A, "Fang")}`
		)
		check(
			"M3.2 the loadout is Lunge in slot 1",
			loadoutText(A) == "{lunge, -, -, -}",
			loadoutText(A)
		)
		local picked = inspectUntil(A, function(snapshot)
			return barText(snapshot, 1) == "Lunge" and snapshot.pickerVisible == false
		end)
		check("M3.2 A's bar shows Lunge in slot 1", barText(picked, 1) == "Lunge", barDump(picked))
		check("M3.2 the picker closes", picked.pickerVisible == false)

		local mPickB = mark(B)
		send(B, "pickCalling", "Mire")
		expectNote("M3.2 B picks Mire: CALLING_CHOSEN", B, mPickB, "CALLING_CHOSEN")
		check(
			"M3.2 B's loadout is Bog Snare in slot 1",
			loadoutText(B) == "{bog_snare, -, -, -}",
			loadoutText(B)
		)
		local pickedB = inspectUntil(B, function(snapshot)
			return barText(snapshot, 1) == "Bog Snare"
		end)
		check(
			"M3.2 B's bar shows Bog Snare in slot 1",
			barText(pickedB, 1) == "Bog Snare",
			barDump(pickedB)
		)
	end

	--------------------------------------------------------------------------- M3.3 the Paths panel
	do
		local rates = {
			Fang = "100%",
			Gale = "80%",
			Ember = "60%",
			Mire = "40%",
			Mend = "60%",
			Bulwark = "80%",
		}
		local panel = inspectUntil(A, function(snapshot)
			return snapshot.callingText == "Calling: Fang"
				and has(rowOf(snapshot, "Mire").detail, "Rate 40%")
		end)
		check(
			'M3.3 the panel title reads "Calling: Fang"',
			panel.callingText == "Calling: Fang",
			tostring(panel.callingText)
		)
		local wrong = {}
		for path, rate in rates do
			local detail = rowOf(panel, path).detail
			if not has(detail, "Rate " .. rate) then
				table.insert(wrong, `{path}: "{detail}"`)
			end
		end
		check(
			"M3.3 learning rates: Fang 100%, Gale and Bulwark 80%, Ember and Mend 60%, Mire 40%",
			#wrong == 0,
			table.concat(wrong, "; ")
		)
		local fangRow = rowOf(panel, "Fang")
		check(
			"M3.3 the Fang row shows Lv 3 (Calling) and XP 0 / 300",
			has(fangRow.header, "Lv 3")
				and has(fangRow.header, "(Calling)")
				and has(fangRow.detail, "XP 0 / 300"),
			`{fangRow.header} | {fangRow.detail}`
		)
		check(
			"M3.3 another Path offers Make Calling (Free)",
			rowOf(panel, "Gale").button == "Make Calling (Free)",
			rowOf(panel, "Gale").button
		)
	end

	--------------------------------------------------------------------------- M2.2 shielded attacker
	faceOff(A, B, OUTSIDE)
	local m = mark(A)
	strike(A)
	expectNote("M2.2 shielded A cannot Strike: SHIELD_SELF", A, m, "SHIELD_SELF")
	check("M2.2 B took no damage", health(B) == 100, tostring(health(B)))

	--------------------------------------------------------------------------- M2.3 drop shield
	m = mark(A)
	send(A, "dropShield")
	expectNote("M2.3 Drop shield: SHIELD_ENDED", A, m, "SHIELD_ENDED")
	local statusA = ProtectionService.status(A, os.clock())
	check("M2.3 A's new-player shield is off", statusA ~= nil and not statusA.newShield)
	task.wait(0.6)
	uiA = inspect(A)
	check("M2.3 Drop shield button hidden after dropping", uiA.dropShieldVisible == false)
	faceOff(A, B, OUTSIDE)
	m = mark(A)
	strike(A)
	expectNote("M2.3 B still shielded: TARGET_SHIELDED", A, m, "TARGET_SHIELDED")

	--------------------------------------------------------------------------- M2.4 shield ends at 3 Relics
	m = mark(B)
	LedgerService.set(B, { claimed = { R001 = true }, free = { "R001" } })
	expectNoNote("M2.4 2 Relics do not end the shield", B, m, "SHIELD_ENDED")
	LedgerService.set(B, { claimed = { R001 = true }, free = { "R001", "R002" } })
	expectNote("M2.4 3 Relics (spares count) end B's shield", B, m, "SHIELD_ENDED")
	task.wait(0.3)
	local statusB = ProtectionService.status(B, os.clock())
	check("M2.4 B's new-player shield is off", statusB ~= nil and not statusB.newShield)

	--------------------------------------------------------------------------- M1 caches and the Ledger
	LedgerService.set(A, { claimed = {}, free = {} })
	local c001 = island:FindFirstChild("C001")
	place(A, Vector3.new(60, 3, 44), Vector3.new(60, 3, 40))
	task.wait(0.6)
	m = mark(A)
	send(A, "prompt", "C001")
	local got = expectNote("M1.3 open a copper cache: GOT_CARD", A, m, "GOT_CARD", 5)
	check(
		"M1.3 message names the Relic",
		got ~= nil and got.args ~= nil and got.args.name == "Tarnished Tally-Coin",
		got and got.args and got.args.name or "no args"
	)
	local openedAt = os.clock()
	check("M1.3 card is in A's free slots", table.find(LedgerService.get(A).free, "R001") ~= nil)
	check("M1.3 cache vanishes", c001 ~= nil and c001.Transparency == 1)
	local prompt001 = c001 and c001:FindFirstChildOfClass("ProximityPrompt")
	check("M1.3 cache prompt disabled", prompt001 ~= nil and prompt001.Enabled == false)

	m = mark(A)
	send(A, "ledger", { kind = "claim", freeIndex = 1, cardId = "R001" })
	expectNote("M1.6 Claim: CLAIMED", A, m, "CLAIMED")
	check("M1.6 R001 claimed", LedgerService.get(A).claimed.R001 == true)
	send(A, "toggleLedger", true)
	task.wait(0.5)
	uiA = inspect(A)
	check(
		"M1.6 book shows Relics: 1 / 50",
		uiA.progress == "Relics: 1 / 50",
		tostring(uiA.progress)
	)
	send(A, "toggleLedger", false)

	m = mark(A)
	send(A, "ledger", { kind = "unclaim", cardId = "R001" })
	expectNote("M1.8 release a claimed slot: UNCLAIMED", A, m, "UNCLAIMED")
	check("M1.8 card back in free slots", LedgerService.get(A).free[1] == "R001")
	m = mark(A)
	send(A, "ledger", { kind = "discard", freeIndex = 1, cardId = "R001" })
	expectNote("M1.9 Discard: DISCARDED", A, m, "DISCARDED")
	check("M1.9 card gone", #LedgerService.get(A).free == 0)

	local full = {}
	for _ = 1, 20 do
		table.insert(full, "R003")
	end
	LedgerService.set(A, { claimed = {}, free = full })
	place(A, Vector3.new(-50, 3, -91), Vector3.new(-50, 3, -95))
	task.wait(0.6)
	m = mark(A)
	send(A, "prompt", "C004")
	expectNote("M1.10 free slots full: FREE_FULL", A, m, "FREE_FULL", 5)
	local c004 = island:FindFirstChild("C004")
	check("M1.10 cache stays", c004 ~= nil and c004.Transparency == 0)

	-- M1.13: both players open one cache at the same moment.
	LedgerService.set(A, { claimed = {}, free = {} })
	LedgerService.set(B, { claimed = { R001 = true }, free = { "R001", "R004" } })
	place(A, Vector3.new(-70, 3, 59), Vector3.new(-70, 3, 55))
	place(B, Vector3.new(-66, 3, 55), Vector3.new(-70, 3, 55))
	task.wait(0.6)
	local ma, mb = mark(A), mark(B)
	send(A, "prompt", "C002")
	send(B, "prompt", "C002")
	task.wait(3)
	local winners = (if noteSince(A, ma, "GOT_CARD") then 1 else 0)
		+ (if noteSince(B, mb, "GOT_CARD") then 1 else 0)
	check("M1.13 race: exactly one player gets the card", winners == 1, tostring(winners))
	check(
		"M1.13 race: one copy exists",
		totals({ A, B }).R002 == 1,
		tostring(totals({ A, B }).R002)
	)

	-- M1.11: completing the Ledger tells everyone.
	local claimed = {}
	local lastRelic = Relics.list[Relics.count].id
	for i = 1, Relics.count - 1 do
		claimed[Relics.list[i].id] = true
	end
	LedgerService.set(A, { claimed = claimed, free = { lastRelic } })
	ma, mb = mark(A), mark(B)
	send(A, "ledger", { kind = "claim", freeIndex = 1, cardId = lastRelic })
	expectNote("M1.11 last claim: LEDGER_COMPLETE to A", A, ma, "LEDGER_COMPLETE")
	local complete = expectNote("M1.11 LEDGER_COMPLETE reaches B too", B, mb, "LEDGER_COMPLETE")
	check(
		"M1.11 message names A",
		complete ~= nil and complete.args ~= nil and complete.args.player == A.DisplayName
	)

	check(
		"M1.4 cache returns after 30 s",
		waitFor(function()
			return c001.Transparency == 0 and prompt001.Enabled
		end, math.max(1, openedAt + 33 - os.clock()))
	)

	--------------------------------------------------------------------------- M2.5 start a fight
	LedgerService.set(A, { claimed = {}, free = { "R004", "R005" } })
	LedgerService.set(B, { claimed = { R001 = true, R002 = true }, free = { "R007", "R008" } })
	ProtectionService.endRespawnShield(B) -- stands in for waiting out B's 60 s
	waitAlive(A)
	waitAlive(B)
	faceOff(A, B, OUTSIDE)
	ma, mb = mark(A), mark(B)
	local fxBefore = hitFx[B] or 0
	strike(A)
	local hb = health(B)
	check("M2.5 Strike takes about a fifth of B's health", hb >= 79 and hb <= 81.5, tostring(hb))
	expectNote("M2.5 A is told: MARKED", A, ma, "MARKED")
	local head = A.Character and A.Character:FindFirstChild("Head")
	check("M2.5 MARKED tag over A", head ~= nil and head:FindFirstChild("MarkedTag") ~= nil)
	check(
		"M2.5 hit flash sent to clients",
		waitFor(function()
			return (hitFx[B] or 0) > fxBefore
		end, 2)
	)
	task.wait(0.6)
	uiA = inspect(A)
	check(
		"M2.5 A's HUD shows MARKED",
		hasLine(uiA, "MARKED"),
		table.concat(uiA.statusLines or {}, "; ")
	)
	check("M2.5 A's respawn shield ended by attacking", not hasLine(uiA, "Respawn shield"))

	--------------------------------------------------------------------------- M2.6 hitting back
	faceOff(B, A, OUTSIDE)
	local ha = health(A)
	mb = mark(B)
	strike(B)
	check("M2.6 B's Strike hurts A", health(A) < ha, `{ha} -> {health(A)}`)
	expectNoNote("M2.6 hitting back does not Mark B", B, mb, "MARKED")

	--------------------------------------------------------------------------- M2.7 safe zone
	faceOff(B, A, IN_TOWN)
	ha = health(A)
	mb = mark(B)
	strike(B)
	check(
		"M2.7 Marked A can be hit in town",
		health(A) < ha,
		`{ha} -> {health(A)} {codesSince(B, mb)}`
	)
	faceOff(A, B, IN_TOWN)
	ma = mark(A)
	strike(A)
	expectNote("M2.7 A cannot hit unmarked B in town: SAFE_ZONE", A, ma, "SAFE_ZONE")

	--------------------------------------------------------------------------- M2.8 defeat and claim
	local before = totals({ A, B })
	local fangBeforeClaim = xpOf(A, "Fang")
	ma, mb = mark(A), mark(B)
	check("M2.8 A defeats B", defeat(A, B, OUTSIDE), tostring(health(B)))
	expectNote("M2.8 A: CLAIM_STARTED", A, ma, "CLAIM_STARTED")
	expectNote("M2.8 B: DEFEATED_BY", B, mb, "DEFEATED_BY")
	check(
		"M3.10 the claim pays A's Calling (Fang) 150 XP",
		waitFor(function()
			return xpOf(A, "Fang") == fangBeforeClaim + 150
		end, 3),
		`{fangBeforeClaim} -> {xpOf(A, "Fang")}`
	)
	check(
		"M2.8 claim screen data reaches A",
		waitFor(function()
			return claimPayload[A] ~= nil
		end, 3)
	)
	check("M2.8 B's Ledger is locked", LedgerService.isLocked(B))
	task.wait(0.5)
	uiA = inspect(A)
	check("M2.8 A's claim screen is open", uiA.claimVisible == true)
	check(
		"M2.8 claim title names B",
		uiA.claimTitle == "Claim on " .. B.DisplayName,
		tostring(uiA.claimTitle)
	)
	check("M2.8 Picks left: 5", uiA.claimPicks == "Picks left: 5", tostring(uiA.claimPicks))

	-- M2.9: the victim cannot dodge.
	mb = mark(B)
	send(B, "ledger", { kind = "discard", freeIndex = 1, cardId = "R007" })
	expectNote("M2.9 B discarding: LEDGER_LOCKED", B, mb, "LEDGER_LOCKED")
	mb = mark(B)
	send(B, "vault", { kind = "add", cardId = "R002" })
	expectNote("M2.9 B vaulting: LEDGER_LOCKED", B, mb, "LEDGER_LOCKED")
	check("M2.9 B's Ledger unchanged", #LedgerService.get(B).free == 2)

	-- M2.10: picks.
	ma = mark(A)
	send(A, "pick", 1)
	local taken = expectNote("M2.10 pick a held slot: CLAIM_TAKEN", A, ma, "CLAIM_TAKEN")
	check("M2.10 names the Relic", taken ~= nil and taken.args.name == "Tarnished Tally-Coin")
	check("M2.10 R001 moved to A", table.find(LedgerService.get(A).free, "R001") ~= nil)
	check("M2.10 B lost R001", LedgerService.get(B).claimed.R001 == nil)
	ma = mark(A)
	send(A, "pick", 3)
	expectNote("M2.10 pick an empty slot: CLAIM_MISS", A, ma, "CLAIM_MISS")
	ma = mark(A)
	send(A, "pick", 1)
	expectNote("M2.10 same slot twice: ALREADY_PICKED", A, ma, "ALREADY_PICKED")
	ma = mark(A)
	send(A, "pick", "x")
	expectNote("M2.10 hostile pick: BAD_SLOT", A, ma, "BAD_SLOT")
	ma = mark(A)
	send(A, "pick", 0 / 0)
	expectNote("M2.10 NaN pick: BAD_SLOT", A, ma, "BAD_SLOT")
	task.wait(0.5)
	check(
		"M2.10 refusals spend no pick",
		claimPayload[A] ~= nil and claimPayload[A].claim.picksLeft == 3,
		claimPayload[A] and tostring(claimPayload[A].claim.picksLeft) or "closed"
	)
	uiA = inspect(A)
	local slot1 = uiA.claimSlots and uiA.claimSlots.Slot001 or ""
	local slot3 = uiA.claimSlots and uiA.claimSlots.Slot003 or ""
	check("M2.10 screen shows Taken!", string.find(slot1, "Taken!", 1, true) ~= nil, slot1)
	check("M2.10 screen shows Nothing", string.find(slot3, "Nothing", 1, true) ~= nil, slot3)

	-- M2.11: the claim ends after 5 picks.
	ma, mb = mark(A), mark(B)
	send(A, "pick", 7)
	task.wait(0.4)
	send(A, "pick", 5)
	task.wait(0.4)
	send(A, "pick", 6)
	expectNote("M2.11 A: CLAIM_OVER", A, ma, "CLAIM_OVER")
	local lost = expectNote("M2.11 B: CLAIM_LOST", B, mb, "CLAIM_LOST")
	check(
		"M2.11 CLAIM_LOST lists both Relics",
		lost ~= nil and lost.args.names == "Tarnished Tally-Coin, Bottled Squall",
		lost and lost.args.names or "none"
	)
	check("M2.11 B unlocked", not LedgerService.isLocked(B))
	check(
		"M2.11 claim screen closed",
		waitFor(function()
			return claimPayload[A] == nil
		end, 3)
	)
	check("RF1 no Relic copied or destroyed by the claim", sameTotals(before, totals({ A, B })))
	mb = mark(B)
	send(B, "ledger", { kind = "discard", freeIndex = 1, cardId = "R008" })
	expectNote("M2.11 B can change their Ledger again", B, mb, "DISCARDED")

	--------------------------------------------------------------------------- M2.12 respawn shield
	check("M2.12 B respawns", waitAlive(B))
	task.wait(0.5)
	statusB = ProtectionService.status(B, os.clock())
	check(
		"M2.12 B has a respawn shield",
		statusB ~= nil and statusB.respawnShieldUntil > os.clock() + 5
	)
	check("M2.12 B has the Shield force field", B.Character:FindFirstChild("Shield") ~= nil)
	faceOff(A, B, OUTSIDE)
	ma = mark(A)
	strike(A)
	expectNote("M2.12 respawn shield protects B: TARGET_SHIELDED", A, ma, "TARGET_SHIELDED")
	check("M2.12 B unhurt", health(B) == 100, tostring(health(B)))

	--------------------------------------------------------------------------- M2.13 one claim per hour
	ProtectionService.endRespawnShield(B)
	task.wait(0.3)
	check(
		"M2.13 Shield force field goes with the respawn shield",
		B.Character:FindFirstChild("Shield") == nil
	)
	local fangBeforeRepeat = xpOf(A, "Fang")
	ma = mark(A)
	check("M2.13 A defeats B again", defeat(A, B, OUTSIDE))
	local cooldown =
		expectNote("M2.13 second defeat within the hour: CLAIM_COOLDOWN", A, ma, "CLAIM_COOLDOWN")
	check("M2.13 names B", cooldown ~= nil and cooldown.args.player == B.DisplayName)
	task.wait(0.5)
	check("M2.13 no claim opened", claimPayload[A] == nil and not LedgerService.isLocked(B))
	check(
		"M3.10 a defeat that opens no claim pays no XP",
		xpOf(A, "Fang") == fangBeforeRepeat,
		`{fangBeforeRepeat} -> {xpOf(A, "Fang")}`
	)

	--------------------------------------------------------------------------- M2.14 the Vault
	check("M2.14 B respawns", waitAlive(B))
	place(B, IN_TOWN, Vector3.zero)
	task.wait(0.6)
	mb = mark(B)
	send(B, "vault", { kind = "add", cardId = "R002" })
	expectNote("M2.14 Vault in town: VAULTED", B, mb, "VAULTED")
	check("M2.14 saved in B's Vault", LedgerService.getVault(B).R002 == true)
	send(B, "toggleLedger", true)
	task.wait(0.6)
	local uiB = inspect(B)
	check(
		"M2.14 slot button reads Vaulted",
		uiB.vaultButtons and uiB.vaultButtons.Slot002 == "Vaulted"
	)
	check(
		"M2.14 book shows Vault: 1 / 3",
		uiB.vaultCount == "Vault: 1 / 3",
		tostring(uiB.vaultCount)
	)
	send(B, "toggleLedger", false)
	place(B, OUTSIDE_2, Vector3.zero)
	task.wait(0.6)
	mb = mark(B)
	send(B, "vault", { kind = "remove", cardId = "R002" })
	expectNote("M2.14 outside town: NOT_IN_SAFE_ZONE", B, mb, "NOT_IN_SAFE_ZONE")
	check("M2.14 still Vaulted", LedgerService.getVault(B).R002 == true)

	-- A Vaulted Relic cannot be taken (B makes a claim on A).
	place(A, IN_TOWN, Vector3.zero)
	task.wait(0.6)
	ma = mark(A)
	send(A, "vault", { kind = "add", cardId = "R001" })
	expectNote("M2.14 A Vaults R001", A, ma, "VAULTED")
	before = totals({ A, B })
	local mireBeforeClaim = xpOf(B, "Mire")
	mb, ma = mark(B), mark(A)
	check("M2.14 B defeats A", defeat(B, A, OUTSIDE))
	expectNote("M2.14 B: CLAIM_STARTED", B, mb, "CLAIM_STARTED")
	check(
		"M3.10 B's claim pays B's Calling (Mire) 150 XP",
		waitFor(function()
			return xpOf(B, "Mire") == mireBeforeClaim + 150
		end, 3),
		`{mireBeforeClaim} -> {xpOf(B, "Mire")}`
	)
	mb = mark(B)
	send(B, "pick", 1)
	expectNote("M2.14 Vaulted Relic: CLAIM_MISS", B, mb, "CLAIM_MISS")
	check("M2.14 A keeps the Vaulted Relic", table.find(LedgerService.get(A).free, "R001") ~= nil)
	mb = mark(B)
	send(B, "pick", 4)
	expectNote("M2.14 unVaulted spare is taken", B, mb, "CLAIM_TAKEN")
	-- Leave the last 3 picks unused: the 30-second timer must end the claim.
	mb = mark(B)
	expectNote("RF1 claim timer ends the claim: CLAIM_OVER", B, mb, "CLAIM_OVER", 35)
	expectNote("M2.11 A: CLAIM_LOST after the timer", A, ma, "CLAIM_LOST", 3)
	check("RF1 A unlocked after the timer", not LedgerService.isLocked(A))
	check("RF1 no Relic copied or destroyed (timer path)", sameTotals(before, totals({ A, B })))

	--------------------------------------------------------------------------- M2.16 sealed caches
	check("M2.16 A respawns", waitAlive(A))
	local c012 = island:FindFirstChild("C012")
	local prompt012 = c012 and c012:FindFirstChildOfClass("ProximityPrompt")
	local pillar012 = c012 and c012:FindFirstChild("Pillar")
	LedgerService.set(A, { claimed = {}, free = { "R012" } })
	LedgerService.set(B, { claimed = {}, free = { "R012" } })
	task.wait(0.5)
	check(
		"M2.16 2 Platinum copies seal the cache",
		prompt012 ~= nil and prompt012.ObjectText == "Sealed cache"
	)
	check(
		"M2.16 sealed pillar stops glowing",
		pillar012 ~= nil and pillar012.Material == Enum.Material.SmoothPlastic
	)
	-- C012 stands in the Bastion Reach keep. A stands 4 studs short of it on the side facing the
	-- island centre, 2 studs up, looking at it.
	local cachePosition = World.cacheById.C012.position
	local cacheSpot = Vector3.new(cachePosition.x, cachePosition.y, cachePosition.z)
	local towardCentre = Vector3.new(-cachePosition.x, 0, -cachePosition.z).Unit
	place(A, cacheSpot + towardCentre * 4 + Vector3.new(0, 2, 0), cacheSpot)
	task.wait(0.6)
	ma = mark(A)
	send(A, "prompt", "C012")
	-- The cache takes 4 s to open and the agent holds its prompt for 4.3 s: wait well past that.
	expectNote("M2.16 opening a sealed cache: SEALED", A, ma, "SEALED", 10)
	LedgerService.set(B, { claimed = {}, free = {} })
	task.wait(0.5)
	check(
		"M2.16 cache unseals when a copy leaves",
		prompt012 ~= nil and prompt012.ObjectText == "Cache"
	)

	--------------------------------------------------------------------------- M3.4 training posts
	do
		place(B, POST4_STAND, POST4_FACE)
		place(A, POST1_STAND, POST1_FACE)
		task.wait(0.6)
		local fang0 = xpOf(A, "Fang")
		send(A, "strike")
		check(
			"M3.4 a Strike at a training post: Fang XP +10",
			waitFor(function()
				return xpOf(A, "Fang") == fang0 + 10
			end, 2),
			`{fang0} -> {xpOf(A, "Fang")}`
		)
		local wantXp = PathView.build(PathService.get(A), 0, os.time()).rows[1].xpText
		local xpPanel = inspectUntil(A, function(snapshot)
			return has(rowOf(snapshot, "Fang").detail, "XP " .. wantXp)
		end)
		check(
			"M3.4 the Paths panel shows the new Fang XP",
			has(rowOf(xpPanel, "Fang").detail, "XP " .. wantXp),
			`want XP {wantXp}, row "{rowOf(xpPanel, "Fang").detail}"`
		)

		-- A Strike, then Lunge past the same post 0.15 s later: two hits inside half a second.
		task.wait(0.9)
		local fang1 = xpOf(A, "Fang")
		local lungeFrom = positionOf(A)
		send(A, "strike")
		task.wait(0.15)
		local lunged = cast(A, 1)
		task.wait(0.5)
		check(
			"M3.4 two hits on one post within 0.5 s pay once",
			xpOf(A, "Fang") == fang1 + 10,
			`{fang1} -> {xpOf(A, "Fang")}, Lunge accepted={tostring(lunged)}`
		)
		local lungeTo = positionOf(A)
		local lungeLength = flatDistance(lungeFrom, lungeTo)
		check(
			"M3.8 Lunge moves A about 12 studs",
			lunged and lungeLength >= 10.5 and lungeLength <= 12.5,
			`{fmt(lungeLength)} studs, {at(lungeFrom)} -> {at(lungeTo)}`
		)
		local lungeEvent = (cooldowns[A] or {})[cooldownCount(A)]
		check(
			"M3.7 the server sends Lunge's 6 s cooldown for slot 1",
			lungeEvent ~= nil and lungeEvent.slot == 1 and lungeEvent.seconds == 6,
			if lungeEvent ~= nil
				then `slot {tostring(lungeEvent.slot)}, {tostring(lungeEvent.seconds)} s`
				else "no AbilityCooldown"
		)
		local counting = inspectUntil(A, function(snapshot)
			return ((snapshot.abilitySeconds or {})[1] or "") ~= ""
		end)
		local secondsShown = (counting.abilitySeconds or {})[1] or ""
		check(
			"M3.7 the bar counts down Lunge's cooldown",
			secondsShown ~= "",
			`seconds "{secondsShown}"`
		)

		-- A second Strike straight after a paid one pays nothing.
		place(A, POST1_STAND, POST1_FACE)
		task.wait(0.6)
		local fang2 = xpOf(A, "Fang")
		send(A, "strike")
		local paid = waitFor(function()
			return xpOf(A, "Fang") == fang2 + 10
		end, 2)
		local afterPaid = xpOf(A, "Fang")
		send(A, "strike")
		task.wait(0.8)
		check(
			"M3.4 a Strike a second later pays again: Fang XP +10",
			paid,
			`{fang2} -> {afterPaid}`
		)
		check(
			"M3.4 a second Strike within 0.5 s pays nothing",
			xpOf(A, "Fang") == fang2 + 10,
			`{fang2} -> {xpOf(A, "Fang")}`
		)

		-- Lunge past the post once Lunge is ready again: it trains its own Path, Fang.
		place(A, POST1_STAND, POST1_FACE)
		task.wait(0.6)
		local fang3 = xpOf(A, "Fang")
		local lungedAgain = cast(A, 1)
		check("M3.4 Lunge past the post: Fang XP +10", lungedAgain and waitFor(function()
			return xpOf(A, "Fang") == fang3 + 10
		end, 2), `accepted={tostring(lungedAgain)}, {fang3} -> {xpOf(A, "Fang")}`)

		-- B's Strike trains B's Calling; XP in the opposite Path comes at 40%.
		local mire0 = xpOf(B, "Mire")
		send(B, "strike")
		check(
			"M3.4 B (Mire) Strikes a post: Mire XP +10",
			waitFor(function()
				return xpOf(B, "Mire") == mire0 + 10
			end, 2),
			`{mire0} -> {xpOf(B, "Mire")}`
		)
		local fangB = xpOf(B, "Fang")
		PathService.grant(B, "Fang", 10)
		check(
			"M3.4 10 Fang XP pays Mire-Calling B only 4 (opposite Path, 40%)",
			xpOf(B, "Fang") == fangB + 4,
			`{fangB} -> {xpOf(B, "Fang")}`
		)
	end

	--------------------------------------------------------------------------- M3.5 levelling up
	do
		-- 5 XP short of Fang level 10 (4500 in total): one more post hit crosses it.
		PathService.get(A).xp.Fang = 4495
		place(A, POST1_STAND, POST1_FACE)
		task.wait(0.6)
		local mLevel = mark(A)
		send(A, "strike")
		local up = expectNote("M3.5 crossing 4500 Fang XP: LEVEL_UP", A, mLevel, "LEVEL_UP")
		check(
			"M3.5 the message says Fang reached level 10",
			up ~= nil and up.args ~= nil and up.args.path == "Fang" and up.args.level == "10",
			if up ~= nil and up.args ~= nil
				then `{tostring(up.args.path)} {tostring(up.args.level)}`
				else "none"
		)
		local learned = expectNote("M3.5 level 10: ABILITY_UNLOCKED", A, mLevel, "ABILITY_UNLOCKED")
		check(
			"M3.5 A learns Rending Flurry",
			learned ~= nil and learned.args ~= nil and learned.args.name == "Rending Flurry",
			if learned ~= nil and learned.args ~= nil then tostring(learned.args.name) else "none"
		)
		check(
			"M3.5 Rending Flurry goes into the empty slot 2 by itself",
			slotHas(A, 2, "rending_flurry"),
			loadoutText(A)
		)
		local levelled = inspectUntil(A, function(snapshot)
			return barText(snapshot, 2) == "Rending Flurry"
				and has(rowOf(snapshot, "Fang").header, "Lv 10")
		end)
		check(
			"M3.5 the bar shows Rending Flurry in slot 2",
			barText(levelled, 2) == "Rending Flurry",
			barDump(levelled)
		)
		check(
			"M3.5 the Fang row shows Lv 10",
			has(rowOf(levelled, "Fang").header, "Lv 10"),
			rowOf(levelled, "Fang").header
		)
	end

	--------------------------------------------------------------------------- M3.6 equipping only in town
	do
		place(A, IN_TOWN, Vector3.zero)
		task.wait(0.6)
		local mClear = mark(A)
		send(A, "loadout", { slot = 1, abilityId = "" })
		expectNote("M3.6 in town, clear slot 1: LOADOUT_CHANGED", A, mClear, "LOADOUT_CHANGED")
		check("M3.6 slot 1 is empty", slotHas(A, 1, ""), loadoutText(A))
		local cleared = inspectUntil(A, function(snapshot)
			return barText(snapshot, 1) == EMPTY_BAR
		end)
		check("M3.6 the bar's slot 1 empties", barText(cleared, 1) == EMPTY_BAR, barDump(cleared))
		local stripSlot = (cleared.loadoutSlots or {})[1] or ""
		check(
			"M3.6 the panel's loadout slot 1 reads 1: Empty",
			stripSlot == "1: Empty",
			`"{stripSlot}"`
		)
		local mLocked = mark(A)
		send(A, "loadout", { slot = 1, abilityId = "final_toll" })
		expectNote("M3.6 Final Toll (Fang 18) at Fang 10: NOT_UNLOCKED", A, mLocked, "NOT_UNLOCKED")
		local mBadLoadout = mark(A)
		send(A, "loadout", { slot = 9, abilityId = "lunge" })
		expectNote(
			"M3.6 hostile loadout request (slot 9): BAD_REQUEST",
			A,
			mBadLoadout,
			"BAD_REQUEST"
		)
		place(A, OUTSIDE, Vector3.zero)
		task.wait(0.6)
		local mOutside = mark(A)
		send(A, "loadout", { slot = 1, abilityId = "lunge" })
		expectNote("M3.6 outside town: LOADOUT_SAFE_ZONE", A, mOutside, "LOADOUT_SAFE_ZONE")
		check("M3.6 slot 1 stays empty", slotHas(A, 1, ""), loadoutText(A))

		----------------------------------------------------------------------- M3.7 hostile casts
		local mEmpty = mark(A)
		send(A, "cast", 1)
		expectNote("M3.7 casting an empty slot: NO_ABILITY", A, mEmpty, "NO_ABILITY")
		for _, bad in { { 0, "0" }, { 5, "5" }, { "x", '"x"' }, { 0 / 0, "NaN" } } do
			local mBadCast = mark(A)
			send(A, "cast", bad[1])
			expectNote(`M3.7 casting slot {bad[2]}: BAD_REQUEST`, A, mBadCast, "BAD_REQUEST")
		end

		place(A, IN_TOWN, Vector3.zero)
		task.wait(0.6)
		local mBack = mark(A)
		send(A, "loadout", { slot = 1, abilityId = "lunge" })
		expectNote("M3.6 back in town, equip Lunge: LOADOUT_CHANGED", A, mBack, "LOADOUT_CHANGED")
		check("M3.6 Lunge is back in slot 1", slotHas(A, 1, "lunge"), loadoutText(A))
	end

	--------------------------------------------------------------------------- M3.8 setup: levels, loadouts
	-- Levels come from PathService.grant (at the learning rate for each player's Calling) in
	-- place of hours at the posts; loadouts are set through the game's own LoadoutAction.
	do
		local mGrant = mark(A)
		PathService.grant(A, "Gale", 5700) -- 80%: 4560 XP, level 10
		PathService.grant(A, "Ember", 700) -- 60%: 420 XP, level 3
		PathService.grant(A, "Mire", 800) -- 40%: 320 XP, level 3
		check(
			"M3.8 setup: A at Gale 10, Ember 3, Mire 3",
			levelOf(A, "Gale") == 10 and levelOf(A, "Ember") == 3 and levelOf(A, "Mire") == 3,
			`Gale {xpOf(A, "Gale")}, Ember {xpOf(A, "Ember")}, Mire {xpOf(A, "Mire")} XP`
		)
		check(
			"M3.8 Gale level 10 teaches A Gust Blade",
			waitFor(function()
				return noteWith(A, mGrant, "ABILITY_UNLOCKED", "name", "Gust Blade") ~= nil
			end, 3),
			`A got {codesSince(A, mGrant)}`
		)
		check(
			"M3.8 new abilities fill the empty slots by themselves",
			loadoutText(A) == "{lunge, rending_flurry, slipstream, gust_blade}",
			loadoutText(A)
		)
		PathService.grant(B, "Mend", 5700) -- 80%: 4560 XP, level 10
		PathService.grant(B, "Bulwark", 26000) -- 60%: 15600 XP, level 18
		PathService.grant(B, "Mire", 15500) -- the Calling, 100%: level 18
		check(
			"M3.8 setup: B at Mend 10, Bulwark 18, Mire 18",
			levelOf(B, "Mend") == 10 and levelOf(B, "Bulwark") == 18 and levelOf(B, "Mire") == 18,
			`Mend {xpOf(B, "Mend")}, Bulwark {xpOf(B, "Bulwark")}, Mire {xpOf(B, "Mire")} XP`
		)

		place(A, IN_TOWN, Vector3.zero)
		place(B, B_TOWN, Vector3.zero)
		task.wait(0.6)
		equip(A, 2, "bog_snare")
		equip(A, 3, "gust_blade")
		equip(A, 4, "cinder_bolt")
		equip(B, 2, "rebuke")
		equip(B, 4, "challenge")
		check(
			"M3.8 setup: A's loadout",
			loadoutText(A) == "{lunge, bog_snare, gust_blade, cinder_bolt}",
			loadoutText(A)
		)
		check(
			"M3.8 setup: B's loadout",
			loadoutText(B) == "{bog_snare, rebuke, ward, challenge}",
			loadoutText(B)
		)
		local newBar = inspectUntil(A, function(snapshot)
			return barText(snapshot, 3) == "Gust Blade" and barText(snapshot, 4) == "Cinder Bolt"
		end)
		check(
			"M3.8 A's bar shows the new loadout",
			barText(newBar, 2) == "Bog Snare"
				and barText(newBar, 3) == "Gust Blade"
				and barText(newBar, 4) == "Cinder Bolt",
			barDump(newBar)
		)
	end

	--------------------------------------------------------------------------- M3.8 abilities against players
	-- Both outside town with every shield down; health is refilled before each measured hit
	-- (the default character script heals 1 health a second, but only a second after a hit).
	do
		ProtectionService.endRespawnShield(A)
		ProtectionService.endRespawnShield(B)

		-- Gust Blade (A, Gale 10): a shot for 18.
		faceOff(A, B, OUTSIDE)
		heal(B)
		local beforeBlade = health(B)
		local mBlade = mark(A)
		local bladeCast = cast(A, 3)
		task.wait(0.3)
		local bladeDamage = beforeBlade - health(B)
		local bladeCodes = codesSince(A, mBlade)
		check(
			"M3.8 Gust Blade hits B for 18",
			bladeCast and bladeDamage >= 17.5 and bladeDamage <= 18.5,
			`accepted={tostring(bladeCast)}, B {beforeBlade} -> {health(B)}; A got {bladeCodes}`
		)
		local beforeRecast = health(B)
		local castsBefore = cooldownCount(A)
		task.wait(0.3) -- past the 0.3 s gap after any cast, well inside Gust Blade's 4 s
		send(A, "cast", 3)
		task.wait(1)
		check(
			"M3.7 Gust Blade again inside its cooldown is refused: no damage",
			health(B) >= beforeRecast and cooldownCount(A) == castsBefore,
			`B {beforeRecast} -> {health(B)}, cooldowns sent {castsBefore} -> {cooldownCount(A)}`
		)

		-- Cinder Bolt (A, Ember 3): 16 damage and a burn of 3 a second for 3 s.
		heal(B)
		local mBolt = mark(A)
		local boltCast = cast(A, 4)
		local burn = StatusService.get(B.UserId)
		local burnLeft = fmt(burn.burnUntil - os.clock())
		local boltCodes = codesSince(A, mBolt)
		check(
			"M3.8 Cinder Bolt sets B burning",
			boltCast and burn.burnUntil > os.clock() and burn.burnBy == A.UserId,
			`accepted={tostring(boltCast)}, burn for {burnLeft} s by {burn.burnBy}; A got {boltCodes}`
		)
		local afterBolt = health(B)
		task.wait(2.4)
		check(
			"M3.8 Cinder Bolt: B's health keeps dropping after the hit",
			health(B) <= afterBolt - 2,
			`{afterBolt} -> {health(B)} over 2.4 s`
		)
		task.wait(1) -- the burn runs out

		-- Bog Snare (B, Mire 3) roots A for 1.5 s; a rooted player cannot dash.
		heal(A)
		faceOff(B, A, OUTSIDE)
		local mSnare = mark(B)
		local snareCast = cast(B, 1)
		local rooted = waitFor(function()
			return walkSpeed(A) == 0
		end, 1)
		local rootedAt = os.clock()
		check(
			"M3.8 Bog Snare roots A: WalkSpeed 0",
			snareCast and rooted,
			`accepted={tostring(snareCast)}, WalkSpeed {walkSpeed(A)}; B got {codesSince(B, mSnare)}`
		)
		local mRooted = mark(A)
		send(A, "cast", 1)
		expectNote("M3.8 a rooted A cannot Lunge: ROOTED", A, mRooted, "ROOTED")
		local freed = waitFor(function()
			return walkSpeed(A) == 16
		end, 3)
		local held = os.clock() - rootedAt
		check(
			"M3.8 A walks again after 1.5 s: WalkSpeed 16",
			rooted and freed and held >= 1 and held <= 2.2,
			`WalkSpeed {walkSpeed(A)} after {fmt(held)} s`
		)

		-- Rebuke (B, Bulwark 10): B still takes a hit; half of it goes back to the attacker.
		faceOff(A, B, OUTSIDE)
		heal(A)
		heal(B)
		waitReady(A, 3)
		local mRebuke = mark(B)
		local rebukeCast = cast(B, 2)
		local aBeforeRebuke, bBeforeRebuke = health(A), health(B)
		local bladeIntoRebuke = cast(A, 3)
		task.wait(0.3)
		local toB, toA = bBeforeRebuke - health(B), aBeforeRebuke - health(A)
		local rebukeCodes = codesSince(B, mRebuke)
		check(
			"M3.8 Rebuke: B still takes the 18-damage Gust Blade",
			rebukeCast and bladeIntoRebuke and toB >= 17.5 and toB <= 18.5,
			`accepted={tostring(rebukeCast)}/{tostring(bladeIntoRebuke)}, B lost {fmt(toB)}; B got {rebukeCodes}`
		)
		check("M3.8 Rebuke reflects 9 back to A", toA >= 8.5 and toA <= 9.5, `A lost {fmt(toA)}`)

		-- Ward (B, Mend 10): a 30-point shield takes all of an 18-damage hit.
		heal(B)
		waitReady(A, 3)
		local mWard = mark(B)
		local wardCast = cast(B, 3)
		local bBeforeWard = health(B)
		local bladeIntoWard = cast(A, 3)
		task.wait(0.3)
		local shieldLeft = StatusService.get(B.UserId).shield
		local wardCodes = codesSince(B, mWard)
		check(
			"M3.8 Ward absorbs an 18-damage Gust Blade: B's health unchanged, shield 30 -> 12",
			wardCast and bladeIntoWard and health(B) >= bBeforeWard and shieldLeft == 12,
			`accepted={tostring(wardCast)}/{tostring(bladeIntoWard)}, B {bBeforeWard} -> {health(B)}, shield left {shieldLeft}; B got {wardCodes}`
		)

		-- Challenge (B, Bulwark 18): a taunted player's Strike can only target B. Untaunted,
		-- A's Strike takes the nearer training post.
		local challengeA = Vector3.new(55, 3, 5) -- post 1 is 5 studs straight ahead
		local challengeB = Vector3.new(59, 3, -1) -- 7.2 studs away, inside A's reach and arc
		place(A, challengeA, Vector3.new(55, 3, 0))
		place(B, challengeB, challengeA)
		task.wait(0.6)
		heal(A)
		heal(B)
		local fangPlain, bPlain = xpOf(A, "Fang"), health(B)
		strike(A)
		check(
			"M3.8 untaunted, A's Strike hits the nearer post, not B",
			xpOf(A, "Fang") == fangPlain + 10 and health(B) >= bPlain,
			`Fang XP {fangPlain} -> {xpOf(A, "Fang")}, B {bPlain} -> {health(B)}`
		)
		local mChallenge = mark(B)
		local challengeCast = cast(B, 4)
		local taunt = StatusService.get(A.UserId)
		local tauntLeft = fmt(taunt.tauntUntil - os.clock())
		local challengeCodes = codesSince(B, mChallenge)
		check(
			"M3.8 Challenge taunts A",
			challengeCast and taunt.tauntBy == B.UserId and taunt.tauntUntil > os.clock(),
			`accepted={tostring(challengeCast)}, taunt by {taunt.tauntBy} for {tauntLeft} s; B got {challengeCodes}`
		)
		-- B's Ward shield from the step above may still be up; clear it so the Strike's full
		-- 20 reaches B's health.
		StatusService.update(B.UserId, function(s, _now)
			local out = table.clone(s)
			out.shield = 0
			out.shieldUntil = 0
			return out
		end)
		local fangTaunted, bTaunted = xpOf(A, "Fang"), health(B)
		send(A, "strike")
		task.wait(0.5)
		check(
			"M3.8 taunted, A's Strike hits B instead of the post",
			health(B) <= bTaunted - 15 and xpOf(A, "Fang") == fangTaunted,
			`B {bTaunted} -> {health(B)}, Fang XP {fangTaunted} -> {xpOf(A, "Fang")}`
		)

		-- Undertow (B, Mire 18): pulls the target to 4 studs in front of B and slows it 30%.
		place(B, B_TOWN, Vector3.zero)
		task.wait(0.6)
		equip(B, 2, "undertow")
		local pullStart = OUTSIDE + Vector3.new(0, 0, -15)
		place(B, OUTSIDE, pullStart)
		place(A, pullStart, OUTSIDE)
		task.wait(0.6)
		heal(A)
		local gapBefore = flatDistance(positionOf(A), positionOf(B))
		local mPull = mark(B)
		local pullCast = cast(B, 2)
		task.wait(0.5)
		local gapAfter = flatDistance(positionOf(A), positionOf(B))
		local pullCodes = codesSince(B, mPull)
		check(
			"M3.8 Undertow pulls A to within about 5 studs of B",
			pullCast and gapAfter >= 2.5 and gapAfter <= 5.5,
			`accepted={tostring(pullCast)}, {fmt(gapBefore)} -> {fmt(gapAfter)} studs; B got {pullCodes}`
		)
		check(
			"M3.8 Undertow slows A by 30%: WalkSpeed 11.2",
			math.abs(walkSpeed(A) - 11.2) < 0.1,
			tostring(walkSpeed(A))
		)

		-- Lunge at a building in Tallyport: the dash stops 2 studs short of the wall.
		local wallStart = Vector3.new(-28, 3, -12) -- Building1's near wall is at z = -21
		place(B, OUTSIDE_2, Vector3.zero)
		place(A, wallStart, Vector3.new(-28, 3, -28))
		task.wait(0.6)
		local wallFrom = positionOf(A)
		local wallCast = cast(A, 1)
		task.wait(0.5)
		local wallTo = positionOf(A)
		local dashed = flatDistance(wallFrom, wallTo)
		check(
			"M3.8 Lunge at a building stops short of the wall",
			wallCast and dashed >= 5 and dashed <= 9 and wallTo.Z > -21,
			`accepted={tostring(wallCast)}, {fmt(dashed)} studs, {at(wallFrom)} -> {at(wallTo)}, wall at z -21`
		)
	end

	--------------------------------------------------------------------------- M3.9 protections still hold
	do
		ProtectionService.endRespawnShield(A)
		ProtectionService.endRespawnShield(B)
		local protectionB = ProtectionService.status(B, os.clock())
		check(
			"M3.9 B is not Marked (A started every fight)",
			protectionB ~= nil and not Protection.isMarked(protectionB, os.clock()),
			if protectionB ~= nil
				then `Marked for {fmt(protectionB.markedUntil - os.clock())} s`
				else "no status"
		)

		-- An unmarked player in Tallyport: A, just outside, casts Bog Snare at B just inside.
		-- The lane runs north-south across the south edge of town, beside the Tally Stone (which
		-- stands on the plaza's south side and would block a lane through it), and clear of the
		-- buildings; the first lane with a clear line is used.
		local insideEdge, outsideEdge = Vector3.new(0, 3, 30), Vector3.new(0, 3, 48)
		local stoneX = World.tallyStone.x
		for _, dx in { 12, -12, 0 } do
			local inside = Vector3.new(stoneX + dx, 3, 30)
			local outside = Vector3.new(stoneX + dx, 3, 48)
			if
				flatDistance(inside, Vector3.zero) < World.townRadius
				and flatDistance(outside, Vector3.zero) > World.townRadius
				and Sight.inSight(outside, inside, nil)
			then
				insideEdge, outsideEdge = inside, outside
				break
			end
		end
		log(`M3.9 town-edge lane: B at {at(insideEdge)}, A at {at(outsideEdge)}`)
		place(B, insideEdge, outsideEdge)
		place(A, outsideEdge, insideEdge)
		task.wait(0.6)
		heal(B)
		local bInTown = health(B)
		local mTown = mark(A)
		local townCast = cast(A, 2)
		expectNote("M3.9 Bog Snare at unmarked B in town: SAFE_ZONE", A, mTown, "SAFE_ZONE")
		local slowestB = lowestWalkSpeed(B, 1)
		check(
			"M3.9 B takes no damage and is not rooted (WalkSpeed stays 16)",
			townCast and health(B) == bInTown and slowestB == 16,
			`accepted={tostring(townCast)}, B {bInTown} -> {health(B)}, lowest WalkSpeed {slowestB}`
		)

		-- A player with the new-player shield: A is made a new player again in the saved data.
		local dataA = DataService.get(A)
		dataA.shieldEnded = false
		faceOff(B, A, OUTSIDE)
		heal(A)
		local aShielded = health(A)
		local mShielded = mark(B)
		local shieldedCast = cast(B, 1)
		expectNote(
			"M3.9 Bog Snare at a new-shielded A: TARGET_SHIELDED",
			B,
			mShielded,
			"TARGET_SHIELDED"
		)
		local slowestA = lowestWalkSpeed(A, 1)
		check(
			"M3.9 A takes no damage and is not rooted (WalkSpeed stays 16)",
			shieldedCast and health(A) == aShielded and slowestA == 16,
			`accepted={tostring(shieldedCast)}, A {aShielded} -> {health(A)}, lowest WalkSpeed {slowestA}`
		)
		dataA.shieldEnded = true
	end

	--------------------------------------------------------------------------- M3.10 a defeat with abilities
	-- A already claimed B this hour (M2.8), so this defeat opens no claim and pays no XP.
	do
		ProtectionService.endRespawnShield(A)
		ProtectionService.endRespawnShield(B)
		waitAlive(B)
		local victim = humanoidOf(B)
		local died = false
		local diedConnection = if victim ~= nil
			then victim.Died:Connect(function()
				died = true
			end)
			else nil
		local fangBefore = xpOf(A, "Fang")
		local mDefeat = mark(A)
		local used = {}
		faceOff(A, B, OUTSIDE)
		local deadline = os.clock() + 45
		while not died and os.clock() < deadline do
			local nextSlot = nil
			for _, candidate in { 3, 4, 2 } do -- Gust Blade, Cinder Bolt, Bog Snare
				if secondsUntilReady(A, candidate) <= 0 then
					nextSlot = candidate
					break
				end
			end
			if nextSlot == nil then
				task.wait(0.2)
			else
				if flatDistance(positionOf(A), positionOf(B)) > 6 then
					faceOff(A, B, OUTSIDE)
				end
				local id = abilityIn(A, nextSlot)
				if cast(A, nextSlot) then
					table.insert(used, id)
				end
			end
		end
		if diedConnection ~= nil then
			diedConnection:Disconnect()
		end
		check(
			"M3.10 A defeats B with abilities",
			died,
			`B at {health(B)} after {table.concat(used, ", ")}; A got {codesSince(A, mDefeat)}`
		)
		local repeatDefeat = expectNote(
			"M3.10 second defeat within the hour: CLAIM_COOLDOWN",
			A,
			mDefeat,
			"CLAIM_COOLDOWN",
			5
		)
		check(
			"M3.10 the ability defeat is credited to A against B",
			repeatDefeat ~= nil
				and repeatDefeat.args ~= nil
				and repeatDefeat.args.player == B.DisplayName
		)
		task.wait(0.5)
		check(
			"M3.10 a defeat that opens no claim pays no XP (abilities)",
			xpOf(A, "Fang") == fangBefore,
			`{fangBefore} -> {xpOf(A, "Fang")}`
		)
	end

	--------------------------------------------------------------------------- M3.11 changing Calling
	-- Last of M3, so nothing after it depends on A's Calling.
	do
		local mAgain = mark(A)
		send(A, "pickCalling", "Mire")
		expectNote(
			"M3.11 choosing a second Calling: CALLING_ALREADY_SET",
			A,
			mAgain,
			"CALLING_ALREADY_SET"
		)
		local mSame = mark(A)
		send(A, "changeCalling", "Fang")
		expectNote("M3.11 changing to the same Path: CALLING_SAME", A, mSame, "CALLING_SAME")
		check(
			"M3.11 A's Calling is still Fang",
			PathService.get(A).calling == "Fang",
			PathService.get(A).calling
		)

		local dataA = DataService.get(A)
		dataA.coin = 1000 -- enough for a paid change, so a charge would show
		local mChange = mark(A)
		send(A, "changeCalling", "Gale")
		local changed = expectNote(
			"M3.11 first change, to Gale: CALLING_CHANGED",
			A,
			mChange,
			"CALLING_CHANGED"
		)
		check(
			"M3.11 the message names Gale",
			changed ~= nil and changed.args ~= nil and changed.args.path == "Gale"
		)
		check(
			"M3.11 Gale is A's Calling",
			PathService.get(A).calling == "Gale",
			PathService.get(A).calling
		)
		check(
			"M3.11 the first change is free: Coin still 1000",
			dataA.coin == 1000,
			tostring(dataA.coin)
		)
		check(
			"M3.11 levels are kept: Fang still level 10",
			levelOf(A, "Fang") == 10,
			`Fang XP {xpOf(A, "Fang")}`
		)
		local changedPanel = inspectUntil(A, function(snapshot)
			return snapshot.callingText == "Calling: Gale"
				and has(rowOf(snapshot, "Fang").button, "days")
		end)
		check(
			'M3.11 the panel title reads "Calling: Gale"',
			changedPanel.callingText == "Calling: Gale",
			tostring(changedPanel.callingText)
		)
		check(
			"M3.11 rates follow the new Calling: Fang 80%, Mend 40%",
			has(rowOf(changedPanel, "Fang").detail, "Rate 80%")
				and has(rowOf(changedPanel, "Mend").detail, "Rate 40%"),
			`Fang "{rowOf(changedPanel, "Fang").detail}", Mend "{rowOf(changedPanel, "Mend").detail}"`
		)
		check(
			"M3.11 other Paths read Make Calling (Available in 7 days)",
			rowOf(changedPanel, "Fang").button == "Make Calling (Available in 7 days)",
			`"{rowOf(changedPanel, "Fang").button}"`
		)

		local mTooSoon = mark(A)
		send(A, "changeCalling", "Fang")
		local tooSoon = expectNote(
			"M3.11 changing again within 7 days: CALLING_COOLDOWN",
			A,
			mTooSoon,
			"CALLING_COOLDOWN"
		)
		check(
			"M3.11 the message says 7 days",
			tooSoon ~= nil and tooSoon.args ~= nil and tooSoon.args.days == "7",
			if tooSoon ~= nil and tooSoon.args ~= nil then tostring(tooSoon.args.days) else "none"
		)
		check(
			"M3.11 still Gale, and no Coin taken",
			PathService.get(A).calling == "Gale" and dataA.coin == 1000,
			`{PathService.get(A).calling}, {dataA.coin} Coin`
		)
	end

	--------------------------------------------------------------------------- M4 creatures and trials
	-- In its own protected call: a failure here is reported and M2.15 still runs.
	local m4Ok, m4Err = xpcall(runM4, debug.traceback, A, B)
	check("M4 section ran to its end", m4Ok, tostring(m4Err))
	CreatureService.setActive({})

	--------------------------------------------------------------------------- M5 Edicts, shop, trading
	-- In its own protected call, like M4.
	local m5Ok, m5Err = xpcall(runM5, debug.traceback, A, B)
	check("M5 section ran to its end", m5Ok, tostring(m5Err))
	-- A failed section must not leave a trade open.
	send(A, "trade", { kind = "cancel" })
	send(B, "trade", { kind = "cancel" })
	ShopService.setRng(math.random)
	EdictService.setRng(math.random)
	TrialService.setClocks(os.clock, os.time)
	waitAlive(A)
	waitAlive(B)

	--------------------------------------------------------------------------- M6 parties
	-- In its own protected call, like M4 and M5.
	local m6Ok, m6Err = xpcall(runM6, debug.traceback, A, B)
	check("M6 section ran to its end", m6Ok, tostring(m6Err))
	-- Put back what M6 changed, even when it stopped half way: the clocks, the creature rolls,
	-- B's new-player shield, and the parties (M2.15 needs A and B in none).
	TrialService.setClocks(os.clock, os.time)
	CreatureService.setActive({})
	CreatureService.setRng(math.random)
	local dataAfterM6 = DataService.get(B)
	if dataAfterM6 ~= nil and m6ShieldEnded ~= nil then
		dataAfterM6.shieldEnded = m6ShieldEnded
	end
	send(B, "party", { kind = "leave" })
	task.wait(0.4)
	send(A, "party", { kind = "leave" })
	task.wait(0.4)
	waitAlive(A)
	waitAlive(B)

	--------------------------------------------------------------------------- M7 the endgame
	-- In its own protected call, like M4 to M6.
	local m7Ok, m7Err = xpcall(runM7, debug.traceback, A, B)
	check("M7 section ran to its end", m7Ok, tostring(m7Err))
	-- Put back what M7 changed, even when it stopped half way: the board and badge stand-ins,
	-- the clocks, the creature rolls, B's new-player shield, and any trade or party (M2.15
	-- needs A and B in none).
	m7.fake.failing = false
	LeaderboardService.setBackend(nil)
	LeaderboardService.refreshNow()
	CrownService.setBadge(LaunchConfig.CROWNED_BADGE_ID, nil)
	CrownService.setClock(os.clock)
	TrialService.setClocks(os.clock, os.time)
	CreatureService.setActive({})
	CreatureService.setRng(math.random)
	local dataAfterM7 = DataService.get(B)
	if dataAfterM7 ~= nil and m7.shieldEnded ~= nil then
		dataAfterM7.shieldEnded = m7.shieldEnded
	end
	ProtectionService.endMark(B)
	send(A, "trade", { kind = "cancel" })
	send(B, "trade", { kind = "cancel" })
	send(B, "party", { kind = "leave" })
	task.wait(0.4)
	send(A, "party", { kind = "leave" })
	task.wait(0.4)
	waitAlive(A)
	waitAlive(B)
	put(A, IN_TOWN, B_TOWN)
	put(B, B_TOWN, IN_TOWN)

	--------------------------------------------------------------------------- M8 launch polish
	-- In its own protected call, like M4 to M7.
	local m8Ok, m8Err = xpcall(runM8, debug.traceback, A, B)
	check("M8 section ran to its end", m8Ok, tostring(m8Err))
	m8.restore(A, B)

	--------------------------------------------------------------------------- M2.15 combat log (ends B)
	waitAlive(A)
	waitAlive(B)
	ProtectionService.endRespawnShield(A)
	ProtectionService.endRespawnShield(B)
	faceOff(A, B, OUTSIDE)
	local hbBefore = health(B)
	strike(A)
	check("M2.15 A hits B", health(B) < hbBefore, `{hbBefore} -> {health(B)}`)
	ma = mark(A)
	B:Kick("Play test: leaving during a fight")
	local logged =
		expectNote("M2.15 leaving after a hit counts as a defeat", A, ma, "CLAIM_COOLDOWN", 5)
	check("M2.15 credited to A against B", logged ~= nil and logged.args.player == B.DisplayName)

	if #agentErrors > 0 then
		check("agents reported no errors", false, table.concat(agentErrors, "; "))
	end
	if #renderNotes > 0 then
		log("RENDER during the run: " .. table.concat(renderNotes, " | "))
	end
	log(`DONE passed={passed} failed={failed}`)
	if failed > 0 then
		log("FAILED: " .. table.concat(failures, " | "))
	end
end

task.spawn(function()
	local ok, err = xpcall(run, debug.traceback)
	if not ok then
		log("CRASH " .. tostring(err))
		log(`DONE passed={passed} failed={failed + 1}`)
	end
end)
