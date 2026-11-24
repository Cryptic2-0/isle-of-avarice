--!strict
-- Server-side world rays shared by AbilityService and CombatService.
--   Sight.rayParams(): RaycastParams
--       Rays pass through every player's character, workspace.Effects, workspace.Creatures
--       and anything a character could walk through (non-colliding parts, water).
--   Sight.obstruction(from, to, target?): Vector3?
--       Where the straight line from `from` to `to` is first blocked, or nil when clear.
--       Pass the target's model (Fighters.model): a first hit on it or one of its
--       descendants is not a block. A NaN or infinite line counts as blocked.
--   Sight.inSight(from, to, target?): boolean
--       True when nothing solid stands between the two points.
--   Sight.move(humanoid, root, target): number
--       Moves a character or creature towards a point (dash, pull, knockback, lunge),
--       stopping short of walls. Returns the level distance travelled.
--   Sight.filter(from, fighters): { Fighter }
--       The fighters the point `from` has a clear line to, in order. Used before choosing
--       a nearest target, so one behind a corner never takes the hit.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Rules.Combat)
local Types = require(ReplicatedStorage.Shared.Types)
local Fighters = require(script.Parent.Fighters)

type Fighter = Combat.Fighter

local R6_LEG_HEIGHT = 2

local Sight = {}

Sight.WALL_MARGIN = 2 -- a move stops this many studs short of anything in its way
Sight.GROUND_PROBE = 50 -- how far below a move's end point to look for ground

function Sight.rayParams(): RaycastParams
	local exclude: { Instance } = {}
	for _, name in { "Effects", "Creatures" } do
		local folder = workspace:FindFirstChild(name)
		if folder ~= nil then
			table.insert(exclude, folder)
		end
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

function Sight.obstruction(from: Vector3, to: Vector3, target: Instance?): Vector3?
	local delta = to - from
	-- Written so a NaN or infinite line counts as blocked.
	if not (delta.Magnitude < math.huge) then
		return from
	end
	local result = workspace:Raycast(from, delta, Sight.rayParams())
	if result == nil then
		return nil
	end
	if target ~= nil and (result.Instance == target or result.Instance:IsDescendantOf(target)) then
		return nil
	end
	return result.Position
end

function Sight.inSight(from: Vector3, to: Vector3, target: Instance?): boolean
	return Sight.obstruction(from, to, target) == nil
end

function Sight.filter(from: Vector3, fighters: { Fighter }): { Fighter }
	local kept: { Fighter } = {}
	for _, fighter in fighters do
		local p = fighter.position
		if Sight.inSight(from, Vector3.new(p.x, p.y, p.z), Fighters.model(fighter.id)) then
			table.insert(kept, fighter)
		end
	end
	return kept
end

-- Height of the root's centre above the feet of a standing character.
function Sight.standHeight(humanoid: Humanoid, root: BasePart): number
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		return humanoid.HipHeight + root.Size.Y / 2
	end
	return R6_LEG_HEIGHT + root.Size.Y / 2
end

-- Moves a character towards `target` using only the server's own geometry. `target` always
-- comes from a server plan, never from a client. A level ray from the root towards the
-- target's x and z stops WALL_MARGIN short of anything in the way; a ray down from there
-- stands the character on the ground, or keeps its current height if there is none. The
-- facing is kept and the velocity zeroed. Returns the level distance actually travelled
-- (0 when nothing moved).
function Sight.move(humanoid: Humanoid, root: BasePart, target: Types.Vec3): number
	local from = root.Position
	local dx = target.x - from.X
	local dz = target.z - from.Z
	local distance = math.sqrt(dx * dx + dz * dz)
	-- Written so NaN or infinite targets move nobody.
	if not (distance > 0 and distance < math.huge) then
		return 0
	end
	local direction = Vector3.new(dx / distance, 0, dz / distance)
	local params = Sight.rayParams()
	local travel = distance
	local blocked = workspace:Raycast(from, direction * distance, params)
	if blocked ~= nil then
		travel = math.max(0, blocked.Distance - Sight.WALL_MARGIN)
	end
	local stop = from + direction * travel
	local y = from.Y
	local ground = workspace:Raycast(stop, Vector3.new(0, -Sight.GROUND_PROBE, 0), params)
	if ground ~= nil then
		y = ground.Position.Y + Sight.standHeight(humanoid, root)
	end
	root.CFrame = CFrame.new(stop.X, y, stop.Z) * root.CFrame.Rotation
	root.AssemblyLinearVelocity = Vector3.zero
	return travel
end

return Sight
