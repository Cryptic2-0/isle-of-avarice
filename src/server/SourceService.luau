--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Relics = require(ReplicatedStorage.Shared.Catalog.Relics)
local World = require(ReplicatedStorage.Shared.Catalog.World)
local Sources = require(ReplicatedStorage.Shared.Rules.Sources)
local LedgerService = require(script.Parent.LedgerService)

local SourceService = {}

local function setVisible(part: BasePart, visible: boolean)
	local transparency = if visible then 0 else 1
	part.Transparency = transparency
	part.CanCollide = visible
	local pillar = part:FindFirstChild("Pillar")
	if pillar ~= nil and pillar:IsA("BasePart") then
		pillar.Transparency = transparency
		pillar.CanCollide = visible
	end
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if prompt ~= nil then
		prompt.Enabled = visible
	end
end

local function distanceToPlayer(player: Player, part: BasePart): number
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return math.huge
	end
	return (root.Position - part.Position).Magnitude
end

function SourceService.start()
	local state = Sources.new(World.caches)

	local function connect(part: Instance)
		if not part:IsA("BasePart") then
			return
		end
		local prompt = part:FindFirstChildOfClass("ProximityPrompt")
		if prompt == nil then
			return
		end
		prompt.Triggered:Connect(function(player: Player)
			local cacheId = part:GetAttribute("CacheId")
			local cache = if type(cacheId) == "string" then World.cacheById[cacheId] else nil
			if cache == nil then
				return
			end

			-- No yielding call between tryCollect and storing the new state.
			local now = os.clock()
			local newState, newLedger, code, availableAt = Sources.tryCollect(
				state,
				LedgerService.get(player),
				cache,
				now,
				distanceToPlayer(player, part),
				false,
				false
			)
			if newLedger == nil or availableAt == nil then
				LedgerService.notify(player, code)
				return
			end
			if not LedgerService.set(player, newLedger) then
				-- The data went away; the cache stays as it was.
				LedgerService.notify(player, "DATA_NOT_LOADED")
				return
			end
			state = newState
			local relic = Relics.byId[cache.relicId]
			LedgerService.notify(player, code, { name = if relic ~= nil then relic.name else "" })

			setVisible(part, false)
			task.delay(availableAt - now, setVisible, part, true)
		end)
	end

	for _, instance in CollectionService:GetTagged("Cache") do
		connect(instance)
	end
end

return SourceService
