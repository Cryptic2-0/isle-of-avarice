--!strict
-- Hazard visuals and the one hazard effect the client applies itself: the gust push on the
-- local character. The server decides every hazard's damage, healing, slow and drowning.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = Shared:WaitForChild("Catalog")
local Hazards = require(Shared:WaitForChild("Rules"):WaitForChild("Hazards"))
local Looks = require(Catalog:WaitForChild("Looks"))
local Sites = require(Catalog:WaitForChild("Sites"))
local Types = require(Shared:WaitForChild("Types"))

local MARKER_TAG = "Hazard"
local VISUAL_SECONDS = 0.1
local WARN_BRIGHT = 0.35
local WARN_DIM = 0.6
local ACTIVE_TRANSPARENCY = 0.05
-- The warning flips between bright and dim this many times a second.
local WARN_FLIPS_PER_SECOND = 4

local HazardController = {}

-- What a marker looked like before the controller touched it.
type Rest = { cframe: CFrame, transparency: number }

-- The rest is kept on the marker itself, in client-local attributes. A table keyed by the part
-- can lose its entry when the part's Lua wrapper is collected, and a marker that is lifted at
-- that moment would then be taken for its resting self and lifted again, pass after pass.
-- Both values are written together, on the first pass, before anything has moved the marker.
local function restOf(marker: BasePart, hazard: Types.Hazard): Rest
	local cframe = marker:GetAttribute("RestCFrame")
	local transparency = marker:GetAttribute("RestTransparency")
	if typeof(cframe) == "CFrame" and type(transparency) == "number" then
		return { cframe = cframe, transparency = transparency }
	end
	local look = Looks.byName[hazard.look]
	local rest: Rest = {
		cframe = marker.CFrame,
		transparency = if look ~= nil then look.transparency else marker.Transparency,
	}
	marker:SetAttribute("RestCFrame", rest.cframe)
	marker:SetAttribute("RestTransparency", rest.transparency)
	return rest
end

-- Idle markers sit at rest, a warning flashes, and an active hazard is nearly solid. A
-- marker with a Rise attribute (the tide) lifts by that much as the hazard goes active.
local function showMarker(marker: BasePart, hazard: Types.Hazard, now: number)
	local rest = restOf(marker, hazard)
	local phase, _, elapsed = Hazards.phase(hazard, now)
	local lift = 0
	if phase == "idle" then
		marker.Transparency = rest.transparency
	elseif phase == "warn" then
		local bright = math.floor(now * WARN_FLIPS_PER_SECOND) % 2 == 0
		marker.Transparency = if bright then WARN_BRIGHT else WARN_DIM
		lift = elapsed
	else
		marker.Transparency = ACTIVE_TRANSPARENCY
		lift = 1
	end
	local rise = marker:GetAttribute("Rise")
	if type(rise) == "number" then
		marker.CFrame = rest.cframe + Vector3.new(0, rise * lift, 0)
	end
end

-- Read the tagged list afresh each pass: a marker may appear after this runs.
local function showMarkers(now: number)
	for _, instance in CollectionService:GetTagged(MARKER_TAG) do
		if instance:IsA("BasePart") then
			local id = instance:GetAttribute("HazardId")
			local hazard = if type(id) == "string" then Sites.hazardById[id] else nil
			-- A hazard without a cycle has nothing to count down to; leave its marker alone.
			if hazard ~= nil and hazard.cycle ~= nil then
				showMarker(instance, hazard, now)
			end
		end
	end
end

-- Moves the local character along any gust it stands in, while it is alive.
local function pushLocalCharacter(dt: number, now: number)
	local character = Players.LocalPlayer.Character
	if character == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return
	end
	local position = root.Position
	local sample = Hazards.sample(Sites.hazards, position.X, position.Z, now)
	if sample.pushX ~= 0 or sample.pushZ ~= 0 then
		root.CFrame += Vector3.new(sample.pushX, 0, sample.pushZ) * dt
	end
end

function HazardController.start()
	local sinceVisuals = 0
	RunService.RenderStepped:Connect(function(dt)
		local now = workspace:GetServerTimeNow()
		pushLocalCharacter(dt, now)
		sinceVisuals += dt
		if sinceVisuals >= VISUAL_SECONDS then
			sinceVisuals = 0
			showMarkers(now)
		end
	end)
end

return HazardController
