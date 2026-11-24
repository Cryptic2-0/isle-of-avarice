--!strict
-- Creatures on this client: the hit flash, and hiding the Drowned Tallyman of someone else's
-- duel. The server already keeps a champion from touching anyone but its duellist; here it
-- is only made invisible and walk-through for everyone else.
local CollectionService = game:GetService("CollectionService")

local TAG = "Creature"
local FLASH_SECONDS = 0.15

local CreatureFx = {}

-- Champions this client does not draw.
local hidden: { [Instance]: boolean } = {}

local function hidePart(instance: Instance)
	if instance:IsA("BasePart") then
		instance.LocalTransparencyModifier = 1
		instance.CanCollide = false
	elseif instance:IsA("BillboardGui") then
		instance.Enabled = false
	end
end

local function watch(model: Instance, localUserId: number)
	local owner = model:GetAttribute("OwnerUserId")
	if type(owner) ~= "number" or owner == 0 or owner == localUserId then
		return
	end
	hidden[model] = true
	for _, descendant in model:GetDescendants() do
		hidePart(descendant)
	end
	model.DescendantAdded:Connect(hidePart)
end

-- Hides champions owned by another player, now and as they appear.
function CreatureFx.start(localPlayer: Player)
	local localUserId = localPlayer.UserId
	for _, model in CollectionService:GetTagged(TAG) do
		watch(model, localUserId)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model)
		watch(model, localUserId)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
		hidden[model] = nil
	end)
end

-- True when this client draws the creature model (play-test seam).
function CreatureFx.isShown(model: Instance): boolean
	return hidden[model] ~= true
end

-- A brief white flash on the creature with that id. A hidden champion does not flash.
function CreatureFx.flash(id: number)
	for _, model in CollectionService:GetTagged(TAG) do
		if model:GetAttribute("CreatureId") == id then
			if hidden[model] then
				return
			end
			local highlight = Instance.new("Highlight")
			highlight.Name = "HitFlash"
			highlight.FillColor = Color3.new(1, 1, 1)
			highlight.FillTransparency = 0.3
			highlight.OutlineColor = Color3.new(1, 1, 1)
			highlight.OutlineTransparency = 0
			highlight.Adornee = model
			highlight.Parent = model
			task.delay(FLASH_SECONDS, function()
				highlight:Destroy()
			end)
			return
		end
	end
end

return CreatureFx
