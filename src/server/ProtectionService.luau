--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Protection = require(ReplicatedStorage.Shared.Rules.Protection)
local Types = require(ReplicatedStorage.Shared.Types)
local DataService = require(script.Parent.DataService)
local LedgerService = require(script.Parent.LedgerService)

type Ledger = Types.Ledger
type Status = Protection.Status

local SHIELD_NAME = "Shield"
local MARKED_TAG_NAME = "MarkedTag"
local MARKED_COLOR = Color3.fromRGB(230, 40, 40)

local ProtectionService = {}

-- Per-player timers, on the os.clock() clock. The new-player shield lives in saved data.
type Timers = { respawnShieldUntil: number, markedUntil: number }
local timers: { [Player]: Timers } = {}

local statusSync: RemoteEvent

-- Read-only defaults for a player with no entry. Never written to.
local NO_TIMERS: Timers = { respawnShieldUntil = 0, markedUntil = 0 }

-- The player's timers, created on first use. Only for players still in the game.
local function timersFor(player: Player): Timers
	local t = timers[player]
	if t == nil then
		t = { respawnShieldUntil = 0, markedUntil = 0 }
		timers[player] = t
	end
	return t
end

-- Reads the player's timers without creating an entry (safe for players who left).
local function peekTimers(player: Player): Timers
	return timers[player] or NO_TIMERS
end

-- True while the player's data is loaded and the new-player shield has not ended.
local function hasNewShield(player: Player): boolean
	local data = DataService.get(player)
	return data ~= nil and not data.shieldEnded
end

-- The HumanoidRootPart of a living character, or nil.
local function livingRoot(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root
end

local function sendStatus(player: Player)
	if player.Parent ~= Players then
		return
	end
	local now = os.clock()
	local t = peekTimers(player)
	statusSync:FireClient(player, {
		newShield = hasNewShield(player),
		respawnShieldSeconds = math.max(0, t.respawnShieldUntil - now),
		markedSeconds = math.max(0, t.markedUntil - now),
	})
end

-- Adds or removes the visible Shield force field so it matches the player's shields.
local function updateForceField(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local shielded = hasNewShield(player) or os.clock() < peekTimers(player).respawnShieldUntil
	local existing = character:FindFirstChild(SHIELD_NAME)
	if shielded and existing == nil then
		local field = Instance.new("ForceField")
		field.Name = SHIELD_NAME
		field.Visible = true
		field.Parent = character
	elseif not shielded and existing ~= nil then
		existing:Destroy()
	end
end

local function removeMarkedTag(character: Model)
	for _, child in character:GetDescendants() do
		if child.Name == MARKED_TAG_NAME and child:IsA("BillboardGui") then
			child:Destroy()
		end
	end
end

local function addMarkedTag(character: Model)
	removeMarkedTag(character)
	local anchor = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	if anchor == nil or not anchor:IsA("BasePart") then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = MARKED_TAG_NAME
	tag.Adornee = anchor
	tag.AlwaysOnTop = true
	tag.MaxDistance = 200
	tag.Size = UDim2.fromOffset(120, 30)
	tag.StudsOffset = Vector3.new(0, 2.5, 0)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "MARKED"
	label.TextColor3 = MARKED_COLOR
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = tag

	tag.Parent = anchor
end

-- Removes the Marked tag once the Marked time has run out (a later mark extends it).
local function scheduleUnmark(player: Player, after: number)
	task.delay(after, function()
		local t = timers[player]
		if t == nil or os.clock() < t.markedUntil then
			return
		end
		local character = player.Character
		if character ~= nil then
			removeMarkedTag(character)
		end
		sendStatus(player)
	end)
end

-- Ends the new-player shield for good.
local function endNewShield(player: Player)
	local data = DataService.get(player)
	if data == nil or data.shieldEnded then
		return
	end
	data.shieldEnded = true
	if player.Parent == Players then
		LedgerService.notify(player, "SHIELD_ENDED")
	end
	updateForceField(player)
	sendStatus(player)
end

local function checkShieldEnd(player: Player, ledger: Ledger)
	if Protection.shouldEndShield(ledger) then
		endNewShield(player)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local now = os.clock()
	local t = timersFor(player)
	t.respawnShieldUntil = now + Protection.RESPAWN_SHIELD_SECONDS
	updateForceField(player)
	if now < t.markedUntil then
		addMarkedTag(character)
	end
	sendStatus(player)

	task.delay(Protection.RESPAWN_SHIELD_SECONDS, function()
		if player.Character == character then
			updateForceField(player)
			sendStatus(player)
		end
	end)
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	local character = player.Character
	if character ~= nil then
		task.spawn(onCharacterAdded, player, character)
	end
end

-- The player's protection status, or nil without loaded data or a living character.
function ProtectionService.status(player: Player, _now: number): Status?
	if DataService.get(player) == nil then
		return nil
	end
	local root = livingRoot(player)
	if root == nil then
		return nil
	end
	local t = peekTimers(player)
	local p = root.Position
	return {
		inSafeZone = Protection.inSafeZone({ x = p.X, y = p.Y, z = p.Z }),
		newShield = hasNewShield(player),
		respawnShieldUntil = t.respawnShieldUntil,
		markedUntil = t.markedUntil,
	}
end

-- Marks the player for MARKED_SECONDS from now. A player already Marked has the time extended.
function ProtectionService.mark(player: Player, now: number)
	if player.Parent ~= Players then
		return
	end
	local t = timersFor(player)
	local wasMarked = now < t.markedUntil
	t.markedUntil = now + Protection.MARKED_SECONDS
	if not wasMarked then
		LedgerService.notify(player, "MARKED")
		local character = player.Character
		if character ~= nil then
			addMarkedTag(character)
		end
	end
	sendStatus(player)
	scheduleUnmark(player, Protection.MARKED_SECONDS)
end

-- Ends the respawn shield early (the player attacked someone).
function ProtectionService.endRespawnShield(player: Player)
	local t = timers[player]
	if t == nil or t.respawnShieldUntil == 0 then
		return
	end
	t.respawnShieldUntil = 0
	updateForceField(player)
	sendStatus(player)
end

function ProtectionService.start()
	statusSync = LedgerService.makeRemote(Net.StatusSync)
	local shieldDrop = LedgerService.makeRemote(Net.ShieldDrop)

	shieldDrop.OnServerEvent:Connect(function(player)
		if player.Parent ~= Players then
			return
		end
		endNewShield(player)
	end)

	LedgerService.onChanged(checkShieldEnd)
	DataService.onLoaded(function(player, data)
		checkShieldEnd(player, data.ledger)
		updateForceField(player)
		sendStatus(player)
	end)

	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		timers[player] = nil
	end)
end

return ProtectionService
