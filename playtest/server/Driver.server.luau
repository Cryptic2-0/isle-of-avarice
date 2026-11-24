--!nonstrict
-- Automated two-player play test. Only in the play-test build (playtest.project.json),
-- never in dist. Start a local server with 2 players; this script walks through the M1
-- and M2 checklists, driving each player through their Agent, and prints one line per
-- check: "[PLAYTEST] PASS ..." or "[PLAYTEST] FAIL ...", then a DONE summary.
--
-- Player moves are teleports, and a few waits are skipped on purpose (the 60-second
-- respawn shield is ended early with ProtectionService.endRespawnShield, and Relics are
-- handed out with LedgerService.set where the checklist would walk to caches for minutes).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local LedgerService = require(Server:WaitForChild("LedgerService"))
local ProtectionService = require(Server:WaitForChild("ProtectionService"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ledger = require(Shared:WaitForChild("Rules"):WaitForChild("Ledger"))
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
local agentErrors = {}

report.OnServerEvent:Connect(function(player, kind, a, b)
	if kind == "ready" then
		ready[player] = true
	elseif kind == "notify" then
		notes[player] = notes[player] or {}
		table.insert(notes[player], { code = a, args = b })
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
	ma, mb = mark(A), mark(B)
	check("M2.8 A defeats B", defeat(A, B, OUTSIDE), tostring(health(B)))
	expectNote("M2.8 A: CLAIM_STARTED", A, ma, "CLAIM_STARTED")
	expectNote("M2.8 B: DEFEATED_BY", B, mb, "DEFEATED_BY")
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
	ma = mark(A)
	check("M2.13 A defeats B again", defeat(A, B, OUTSIDE))
	local cooldown =
		expectNote("M2.13 second defeat within the hour: CLAIM_COOLDOWN", A, ma, "CLAIM_COOLDOWN")
	check("M2.13 names B", cooldown ~= nil and cooldown.args.player == B.DisplayName)
	task.wait(0.5)
	check("M2.13 no claim opened", claimPayload[A] == nil and not LedgerService.isLocked(B))

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
	mb, ma = mark(B), mark(A)
	check("M2.14 B defeats A", defeat(B, A, OUTSIDE))
	expectNote("M2.14 B: CLAIM_STARTED", B, mb, "CLAIM_STARTED")
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
