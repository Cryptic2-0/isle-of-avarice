--!strict
-- Fades the fog to the colour and range of the region the player is in.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Regions = require(Shared:WaitForChild("Catalog"):WaitForChild("Regions"))

local FADE_SECONDS = 1.5

local Atmosphere = {}

-- The fade in progress, so a new region can replace it.
local current: Tween? = nil

-- An unknown region id changes nothing.
function Atmosphere.set(regionId: string)
	local region = Regions.byId[regionId]
	if region == nil then
		return
	end
	local fog = region.fog
	local previous = current
	if previous ~= nil then
		previous:Cancel()
	end
	local tween = TweenService:Create(Lighting, TweenInfo.new(FADE_SECONDS), {
		FogColor = Color3.fromRGB(fog.r, fog.g, fog.b),
		FogStart = fog.start,
		FogEnd = fog.finish,
	})
	current = tween
	tween:Play()
end

return Atmosphere
