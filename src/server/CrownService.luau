--!strict
-- Crowning (spec 3.15): a complete Ledger earns one Crown per run. This service gives the
-- Crown, tells the island, lights the sky, and keeps the title, the circlet and the badge.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Crown = require(ReplicatedStorage.Shared.Rules.Crown)
local Ledger = require(ReplicatedStorage.Shared.Rules.Ledger)
local Net = require(ReplicatedStorage.Shared.Net)
local Protection = require(ReplicatedStorage.Shared.Rules.Protection)
local RateLimiter = require(ReplicatedStorage.Shared.Rules.RateLimiter)
local Renounce = require(ReplicatedStorage.Shared.Rules.Renounce)
local ClaimService = require(script.Parent.ClaimService)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local Fighters = require(script.Parent.Fighters)
local Fx = require(script.Parent.Fx)
local LaunchConfig = require(script.Parent.LaunchConfig)
local LedgerService = require(script.Parent.LedgerService)
local ProtectionService = require(script.Parent.ProtectionService)
local TradeService = require(script.Parent.TradeService)
local TrialService = require(script.Parent.TrialService)

local STONE_TAG = "TallyStone"
local PROMPT_NAME = "RenouncePrompt"
local BUCKET_CAPACITY = 10
local BUCKET_REFILL_PER_SECOND = 5
local TAG_NAME = "CrownTag"
local CIRCLET_NAME = "GiltCirclet"
local GOLD = Color3.fromRGB(255, 215, 90)
local CIRCLET_GOLD = Color3.fromRGB(235, 190, 60)
local GEM_COLOR = Color3.fromRGB(150, 60, 200)
local LIGHT_SECONDS = 6
local SIXTY = math.rad(60)

local CrownService = {}

local ceremony: RemoteEvent
local tried: { [Player]: boolean } = {}
local badgeId: number = LaunchConfig.CROWNED_BADGE_ID
local awardFn: ((userId: number, badgeId: number) -> boolean)? = nil
local offerRemote: RemoteEvent
-- The open Renounce offer per player, and the shared rate-limit buckets for prompt and remote.
local offers: { [Player]: Renounce.Offer } = {}
local buckets: { [Player]: RateLimiter.Bucket } = {}
local clock: () -> number = os.clock
local connected: { [Instance]: boolean } = {}

local function realAward(userId: number, id: number): boolean
	return game:GetService("BadgeService"):AwardBadge(userId, id)
end

-- Removes only our own tag and circlet: the MARKED tag and party markers stay.
local function undress(character: Model, head: Instance?)
	if head ~= nil then
		for _, child in head:GetChildren() do
			if child.Name == TAG_NAME then
				child:Destroy()
			end
		end
	end
	for _, child in character:GetChildren() do
		if child.Name == CIRCLET_NAME then
			child:Destroy()
		end
	end
end

local function circletPart(
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Massless = true
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

local function buildTag(head: BasePart, title: string)
	local tag = Instance.new("BillboardGui")
	tag.Name = TAG_NAME
	tag.Adornee = head
	tag.AlwaysOnTop = true
	tag.MaxDistance = 150
	tag.Size = UDim2.fromOffset(180, 28)
	tag.StudsOffset = Vector3.new(0, 5.5, 0)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = title
	label.TextColor3 = GOLD
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = tag

	tag.Parent = head
end

local function buildCirclet(character: Model, head: BasePart, stars: number)
	local circlet = Instance.new("Model")
	circlet.Name = CIRCLET_NAME
	-- In the character first, so each weld sees both parts in the world.
	circlet.Parent = character
	local h = head.Size.Y / 2

	local function place(angle: number, radius: number, lift: number): CFrame
		return head.CFrame * CFrame.Angles(0, angle, 0) * CFrame.new(0, lift, -radius)
	end

	local function attach(part: BasePart, cframe: CFrame)
		part.CFrame = cframe
		part.Parent = circlet
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = part
		weld.Parent = part
	end

	for k = 0, 5 do
		local point = circletPart(
			"CircletPoint",
			Vector3.new(0.3, 0.6, 0.3),
			CIRCLET_GOLD,
			Enum.Material.Metal
		)
		attach(point, place(k * SIXTY, 0.75, h + 0.15))
		local band = circletPart(
			"CircletBand",
			Vector3.new(0.78, 0.18, 0.18),
			CIRCLET_GOLD,
			Enum.Material.Metal
		)
		attach(band, place((k + 0.5) * SIXTY, 0.65, h - 0.05))
	end
	for k = 0, Crown.gems(stars) - 1 do
		local gem =
			circletPart("CircletGem", Vector3.new(0.28, 0.28, 0.28), GEM_COLOR, Enum.Material.Neon)
		gem.Shape = Enum.PartType.Ball
		attach(gem, place(k * SIXTY, 0.8, h - 0.05))
	end
end

-- Rebuilds the title tag and circlet from saved data. No yield.
local function dress(player: Player, character: Model?)
	if character == nil then
		return
	end
	local head = character:FindFirstChild("Head")
	undress(character, head)
	local data = DataService.get(player)
	if data == nil or head == nil or not head:IsA("BasePart") then
		return
	end
	local title = Crown.title(data.crown.crowns, data.crown.stars)
	if title == "" then
		return
	end
	buildTag(head, title)
	buildCirclet(character, head, data.crown.stars)
end

-- Attributes, tag and circlet from saved data. Does nothing without loaded data.
function CrownService.refresh(player: Player)
	local data = DataService.get(player)
	if data == nil then
		return
	end
	player:SetAttribute("Crowns", data.crown.crowns)
	player:SetAttribute("Stars", data.crown.stars)
	dress(player, player.Character)
end

local function checkBadge(player: Player)
	local data = DataService.get(player)
	local id = badgeId
	if data == nil or not Crown.wantsBadge(data.crown, id) or tried[player] then
		return
	end
	tried[player] = true
	local award = awardFn
	task.spawn(function()
		local given = false
		if award ~= nil then
			local ok, result = pcall(award, player.UserId, id)
			given = ok and result == true
		else
			local ok, result = pcall(realAward, player.UserId, id)
			given = ok and result == true
			if not given then
				-- Already owning the badge counts as awarded.
				local badgeService = game:GetService("BadgeService")
				local ok2, has =
					pcall(badgeService.UserHasBadgeAsync, badgeService, player.UserId, id)
				given = ok2 and has == true
			end
		end
		-- The calls above may have outlasted the data: read it again.
		local fresh = DataService.get(player)
		if given and fresh ~= nil then
			fresh.crown.badgeAwarded = true
		end
	end)
end

local function playLight(player: Player)
	local _, root = Fighters.body(player.UserId)
	if root == nil then
		return
	end
	local part = Instance.new("Part")
	part.Name = "CrownLight"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(200, 8, 8)
	part.CFrame = CFrame.new(root.Position + Vector3.new(0, 100, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	part.Material = Enum.Material.Neon
	part.Color = GOLD
	part.Transparency = 0.3
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = Fx.folder()
	TweenService:Create(part, TweenInfo.new(LIGHT_SECONDS), { Transparency = 1 }):Play()
	task.delay(LIGHT_SECONDS + 0.5, part.Destroy, part)
	Fx.ring(root.Position, 20, GOLD)
end

-- No yielding call in here: the Crown record is read and written in one go.
local function tryCrown(player: Player)
	local data = DataService.get(player)
	if data == nil then
		return
	end
	if not Crown.canCrown(data.crown, data.ledger) then
		return
	end
	data.crown = Crown.crown(data.crown, data.ledger)
	local crowns = data.crown.crowns
	CrownService.refresh(player)
	LedgerService.notifyAll("LEDGER_COMPLETE", { player = player.DisplayName })
	LedgerService.notify(player, "CROWNED_YOU", { title = Crown.title(crowns, data.crown.stars) })
	ceremony:FireAllClients({ userId = player.UserId, name = player.DisplayName, crowns = crowns })
	playLight(player)
	checkBadge(player)
end

-- Play-test seam: award nil means the real BadgeService. Forgets who was already tried.
function CrownService.setBadge(id: number, award: ((userId: number, badgeId: number) -> boolean)?)
	badgeId = id
	awardFn = award
	table.clear(tried)
end

-- True if the player has a token left in their rate-limit bucket (takes one).
local function allowed(player: Player): boolean
	local now = os.clock()
	local bucket = buckets[player]
	if bucket == nil then
		bucket = RateLimiter.new(BUCKET_CAPACITY, now)
		buckets[player] = bucket
	end
	return RateLimiter.allow(bucket, now, BUCKET_CAPACITY, BUCKET_REFILL_PER_SECOND)
end

-- The facts Renounce.check needs, read fresh each time. No yield.
local function state(player: Player, now: number): Renounce.State
	local data = DataService.get(player)
	local _, root = Fighters.body(player.UserId)
	local status = ProtectionService.status(player, now)
	return {
		loaded = data ~= nil,
		complete = data ~= nil and Ledger.isComplete(data.ledger),
		crowns = if data ~= nil then data.crown.crowns else 0,
		stars = if data ~= nil then data.crown.stars else 0,
		alive = root ~= nil,
		locked = LedgerService.isLocked(player),
		claiming = ClaimService.isClaiming(player),
		-- Only an open session counts; a pending invite is not a trade.
		trading = TradeService.session(player) ~= nil,
		inTrial = TrialService.run(player) ~= nil,
		inTown = status ~= nil and status.inSafeZone,
		marked = status ~= nil and Protection.isMarked(status, now),
		lastFightAt = CombatService.lastFightAt(player),
	}
end

local function closeOffer(player: Player)
	offers[player] = nil
	offerRemote:FireClient(player, nil)
end

-- The Tally Stone prompt: checks, then opens the offer window on the player's screen.
-- Returns the message code (also the play-test seam's result).
function CrownService.beginRenounce(player: Player): string
	if player.Parent ~= Players or not allowed(player) then
		return "SLOW_DOWN"
	end
	local ok, code = Renounce.check(state(player, os.clock()), os.clock())
	if not ok then
		LedgerService.notify(player, code)
		return code
	end
	local data = DataService.get(player)
	if data == nil then
		LedgerService.notify(player, "DATA_NOT_LOADED")
		return "DATA_NOT_LOADED"
	end
	offers[player] = Renounce.offer(clock())
	offerRemote:FireClient(player, {
		lines = Renounce.offerLines(data.crown),
		seconds = Renounce.OFFER_SECONDS,
	})
	return "RENOUNCE_OFFER"
end

-- Play-test seam: the player's open offer, if any.
function CrownService.offer(player: Player): Renounce.Offer?
	return offers[player]
end

-- Play-test seam: the offer clock (default os.clock).
function CrownService.setClock(newClock: () -> number)
	clock = newClock
end

local function handleAction(player: Player, raw: any)
	if player.Parent ~= Players or not allowed(player) then
		return
	end
	local request = Renounce.parse(raw)
	if request == nil then
		LedgerService.notify(player, "BAD_REQUEST")
		return
	end
	if request.kind == "cancel" then
		if offers[player] ~= nil then
			closeOffer(player)
			LedgerService.notify(player, "RENOUNCE_CANCELLED")
		else
			LedgerService.notify(player, "RENOUNCE_NO_OFFER")
		end
		return
	end

	local word = request.word or ""
	local confirmed, confirmCode = Renounce.confirm(offers[player], word, clock())
	if not confirmed then
		LedgerService.notify(player, confirmCode)
		-- A wrong word keeps the offer open; an expired offer closes.
		if confirmCode == "RENOUNCE_EXPIRED" then
			closeOffer(player)
		end
		return
	end
	-- The world may have changed since the offer: check again with fresh facts.
	local ok, code = Renounce.check(state(player, os.clock()), os.clock())
	if not ok then
		closeOffer(player)
		LedgerService.notify(player, code)
		return
	end

	-- No yielding call from here to the last write: all five parts change, or none.
	local data = DataService.get(player)
	if data == nil then
		closeOffer(player)
		LedgerService.notify(player, "DATA_NOT_LOADED")
		return
	end
	local out = Renounce.apply({
		ledger = data.ledger,
		vault = data.vault,
		crown = data.crown,
		trials = data.trials,
		rounds = data.rounds,
	})
	if not LedgerService.set(player, out.ledger) then
		-- The data went away; drop the offer, and tell the client if it is still there.
		if player.Parent == Players then
			closeOffer(player)
		else
			offers[player] = nil
		end
		LedgerService.notify(player, "DATA_NOT_LOADED")
		return
	end
	LedgerService.setVault(player, out.vault)
	data.crown = out.crown
	data.trials = out.trials
	data.rounds = out.rounds
	offers[player] = nil

	offerRemote:FireClient(player, nil)
	LedgerService.notify(player, "RENOUNCE_DONE")
	LedgerService.notifyAll("RENOUNCED", { player = player.DisplayName })
	CrownService.refresh(player)
	TrialService.resync(player)
end

local function hookStone(stone: Instance)
	local prompt = stone:FindFirstChild(PROMPT_NAME)
	if prompt == nil or not prompt:IsA("ProximityPrompt") or connected[prompt] then
		return
	end
	connected[prompt] = true
	prompt.Triggered:Connect(function(player: Player)
		CrownService.beginRenounce(player)
	end)
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(function()
			local head = character:WaitForChild("Head", 5)
			if head ~= nil then
				dress(player, character)
			end
		end)
	end)
	local character = player.Character
	if character ~= nil then
		task.spawn(dress, player, character)
	end
end

function CrownService.start()
	ceremony = LedgerService.makeRemote(Net.Ceremony)
	offerRemote = LedgerService.makeRemote(Net.RenounceOffer)
	LedgerService.makeRemote(Net.RenounceAction).OnServerEvent:Connect(handleAction)

	for _, stone in CollectionService:GetTagged(STONE_TAG) do
		hookStone(stone)
	end
	CollectionService:GetInstanceAddedSignal(STONE_TAG):Connect(hookStone)

	LedgerService.onChanged(function(player)
		tryCrown(player)
	end)
	DataService.onLoaded(function(player)
		CrownService.refresh(player)
		tryCrown(player)
		checkBadge(player)
	end)

	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		tried[player] = nil
		offers[player] = nil
		buckets[player] = nil
	end)
end

return CrownService
