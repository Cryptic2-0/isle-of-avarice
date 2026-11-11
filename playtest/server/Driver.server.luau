--!nonstrict
-- Automated two-player play test. Only in the play-test build (playtest.project.json),
-- never in dist. Start a local server with 2 players; this script walks through the M1,
-- M2 and M3 checklists, driving each player through their Agent, and prints one line per
-- check: "[PLAYTEST] PASS ..." or "[PLAYTEST] FAIL ...", then a DONE summary.
--
-- Player moves are teleports, and a few waits are skipped on purpose (the 60-second
-- respawn shield is ended early with ProtectionService.endRespawnShield, and Relics are
-- handed out with LedgerService.set where the checklist would walk to caches for minutes).
-- For M3, Path XP is handed out with PathService.grant (or written into the saved data)
-- where the checklist would hit training posts for hours, and health is refilled before
-- each measured ability hit.
--
-- Order: M1 and M2, with M3.1 to M3.3 (first join, choosing a Calling) right after M2.1.
-- A can claim B only once an hour and M2 makes that claim (and B's on A), so M2.8, M2.13
-- and M2.14 also check the Calling's defeat XP (M3.10). Then the rest of M3, and M2.15,
-- which ends B's session, last of all.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local DataService = require(Server:WaitForChild("DataService"))
local LedgerService = require(Server:WaitForChild("LedgerService"))
local PathService = require(Server:WaitForChild("PathService"))
local ProtectionService = require(Server:WaitForChild("ProtectionService"))
local StatusService = require(Server:WaitForChild("StatusService"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rules = Shared:WaitForChild("Rules")
local Ledger = require(Rules:WaitForChild("Ledger"))
local PathProgress = require(Rules:WaitForChild("PathProgress"))
local PathView = require(Rules:WaitForChild("PathView"))
local Protection = require(Rules:WaitForChild("Protection"))
local Relics = require(Shared:WaitForChild("Catalog"):WaitForChild("Relics"))

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
local agentErrors = {}

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
	elseif kind == "hitfx" then
		hitFx[player] = (hitFx[player] or 0) + 1
	elseif kind == "ui" then
		uiReport[player] = a
	elseif kind == "error" then
		table.insert(agentErrors, player.Name .. ": " .. tostring(a))
		log("agent error from " .. player.Name .. ": " .. tostring(a))
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
	check(
		"both players' data loads",
		waitFor(function()
			return LedgerService.get(A) ~= nil and LedgerService.get(B) ~= nil
		end, 60)
	)
	check("both characters spawn", waitAlive(A) and waitAlive(B))
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
	check("M1.1 12 caches tagged", #CollectionService:GetTagged("Cache") == 12)
	local town = island and island:FindFirstChild("Tallyport")
	local spawnPad = town and town:FindFirstChild("Spawn")
	check("M2 spawn gives no default force field", spawnPad ~= nil and spawnPad.Duration == 0)
	check("M2 safe-zone disc exists", town ~= nil and town:FindFirstChild("SafeZone") ~= nil)

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
		"M1.6 book shows Relics: 1 / 12",
		uiA.progress == "Relics: 1 / 12",
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
	for i = 1, 11 do
		claimed[string.format("R%03d", i)] = true
	end
	LedgerService.set(A, { claimed = claimed, free = { "R012" } })
	ma, mb = mark(A), mark(B)
	send(A, "ledger", { kind = "claim", freeIndex = 1, cardId = "R012" })
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
	place(A, Vector3.new(-40, 3, 366), Vector3.new(-40, 3, 370))
	task.wait(0.6)
	ma = mark(A)
	send(A, "prompt", "C012")
	expectNote("M2.16 opening a sealed cache: SEALED", A, ma, "SEALED", 5)
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
		local burn = StatusService.get(B)
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
		local shieldLeft = StatusService.get(B).shield
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
		local taunt = StatusService.get(A)
		local tauntLeft = fmt(taunt.tauntUntil - os.clock())
		local challengeCodes = codesSince(B, mChallenge)
		check(
			"M3.8 Challenge taunts A",
			challengeCast and taunt.tauntBy == B.UserId and taunt.tauntUntil > os.clock(),
			`accepted={tostring(challengeCast)}, taunt by {taunt.tauntBy} for {tauntLeft} s; B got {challengeCodes}`
		)
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
		local insideEdge = Vector3.new(0, 3, 30)
		local outsideEdge = Vector3.new(0, 3, 48)
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
