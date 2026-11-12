--!strict
-- Server-side world rays shared by AbilityService and CombatService.
--   Sight.rayParams(): RaycastParams
--       Rays pass through every player's character, workspace.Effects and anything a
--       character could walk through (non-colliding parts, water).
--   Sight.obstruction(from, to, postId?): Vector3?
--       Where the straight line from `from` to `to` is first blocked, or nil when clear.
--       When the target is a training post, pass its id: the ray ending on that post's own
--       surface is not a block. A NaN or infinite line counts as blocked.
--   Sight.inSight(from, to, postId?): boolean
--       True when nothing solid stands between the two points.
--   Sight.filter(from, fighters): { Fighter }
--       The fighters (players and posts) the point `from` has a clear line to, in order.
--       Used before choosing a nearest target, so one behind a corner never takes the hit.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Rules.Combat)
local World = require(ReplicatedStorage.Shared.Catalog.World)

type Fighter = Combat.Fighter

local Sight = {}

function Sight.rayParams(): RaycastParams
	local exclude: { Instance } = {}
	local effects = workspace:FindFirstChild("Effects")
	if effects ~= nil then
		table.insert(exclude, effects)
	end
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if character ~= nil then
			table.insert(exclude, character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	params.IgnoreWater = true
	return params
end

function Sight.obstruction(from: Vector3, to: Vector3, postId: number?): Vector3?
	local delta = to - from
	-- Written so a NaN or infinite line counts as blocked.
	if not (delta.Magnitude < math.huge) then
		return from
	end
	local result = workspace:Raycast(from, delta, Sight.rayParams())
	if result == nil then
		return nil
	end
	if postId ~= nil and result.Instance:GetAttribute("PostId") == postId then
		return nil
	end
	return result.Position
end

function Sight.inSight(from: Vector3, to: Vector3, postId: number?): boolean
	return Sight.obstruction(from, to, postId) == nil
end

function Sight.filter(from: Vector3, fighters: { Fighter }): { Fighter }
	local kept: { Fighter } = {}
	for _, fighter in fighters do
		local p = fighter.position
		local postId = if World.postIndex(fighter.id) ~= nil then fighter.id else nil
		if Sight.inSight(from, Vector3.new(p.x, p.y, p.z), postId) then
			table.insert(kept, fighter)
		end
	end
	return kept
end

return Sight
