--!strict
-- What a creature does each tick: wander near its den, chase a player, attack, or walk home.
-- Pure: the server passes in what the creature can see and applies the decision.
local Combat = require("./Combat")
local Geography = require("./Geography")
local Types = require("../Types")
local World = require("../Catalog/World")

type Vec3 = Types.Vec3
type CreatureKind = Types.CreatureKind

export type Brain = {
	mode: "wander" | "chase" | "return",
	targetId: number,
	nextAttackAt: number,
	nextLungeAt: number,
	nextWanderAt: number,
	wanderTo: Vec3?,
	-- Return mode only: when it last made progress towards the den, and its closest distance so far.
	returnSince: number?,
	returnBest: number?,
}
-- valid: alive, outside the safe zone, no respawn shield (the server decides).
-- visible: clear line of sight from the creature.
export type Seen = { id: number, position: Vec3, visible: boolean, valid: boolean }
export type Body = { position: Vec3, den: Vec3, rooted: boolean }
export type Action = { kind: "attack" | "lunge", targetId: number }
export type Decision = {
	brain: Brain,
	moveTo: Vec3?,
	faceTo: Vec3?,
	action: Action?,
	home: boolean,
	-- Home because it could not walk there in time: the server moves it to its den.
	snapHome: boolean,
}

local CreatureBrain = {}

CreatureBrain.TICK_SECONDS = 0.1
CreatureBrain.WANDER_RADIUS = 12
CreatureBrain.LEASH = 60
CreatureBrain.HOME_RADIUS = 3
CreatureBrain.TOWN_MARGIN = 4
CreatureBrain.STOP_FRACTION = 0.6
-- A creature returning for this long without getting closer is sent home.
CreatureBrain.RETURN_TIMEOUT = 8
-- How much closer to the den counts as progress.
CreatureBrain.RETURN_PROGRESS = 0.5

local WANDER_MIN_SECONDS = 3
local WANDER_EXTRA_SECONDS = 3
-- How far ahead of its feet a creature checks for land before it steps.
local LOOK_AHEAD = 6

local function flat(a: Vec3, b: Vec3): number
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

function CreatureBrain.new(): Brain
	return { mode = "wander", targetId = 0, nextAttackAt = 0, nextLungeAt = 0, nextWanderAt = 0 }
end

-- A point inside Tallyport or its margin is pushed out along its bearing from the centre
-- (+x for the centre itself). Height is kept.
function CreatureBrain.outsideTown(point: Vec3): Vec3
	local limit = World.townRadius + CreatureBrain.TOWN_MARGIN
	local distance = math.sqrt(point.x * point.x + point.z * point.z)
	-- Written positively so a NaN point is pushed out too.
	if distance >= limit then
		return point
	end
	if not (distance > 0) then
		return { x = limit, y = point.y, z = 0 }
	end
	return { x = point.x / distance * limit, y = point.y, z = point.z / distance * limit }
end

-- The one entry of `seen` with this id that is a target: valid and within the leash of the den.
local function targetOf(seen: { Seen }, id: number?, den: Vec3): Seen?
	if id == nil then
		return nil
	end
	for _, other in seen do
		if other.id == id then
			if other.valid and flat(other.position, den) <= CreatureBrain.LEASH then
				return other
			end
			return nil
		end
	end
	return nil
end

-- The step towards `goal`, or nil when it would leave the land (a Sluice or the sea) or the
-- creature is already there. Every step ends outside Tallyport.
local function step(from: Vec3, goal: Vec3?): Vec3?
	if goal == nil then
		return nil
	end
	local to = CreatureBrain.outsideTown(goal)
	local distance = flat(from, to)
	if distance > 0 then
		local reach = math.min(distance, LOOK_AHEAD)
		local x = from.x + (to.x - from.x) / distance * reach
		local z = from.z + (to.z - from.z) / distance * reach
		if not Geography.isLand(x, z) then
			return nil
		end
	end
	return to
end

function CreatureBrain.tick(
	kind: CreatureKind,
	brain: Brain,
	body: Body,
	seen: { Seen },
	taunter: number?,
	provoker: number?,
	now: number,
	rng: () -> number
): Decision
	local next: Brain = table.clone(brain)
	local position, den = body.position, body.den

	if next.mode == "return" then
		if flat(position, den) <= CreatureBrain.HOME_RADIUS then
			next.mode = "wander"
			next.targetId = 0
			next.nextWanderAt = now
			next.wanderTo = nil
			next.returnSince = nil
			next.returnBest = nil
			return {
				brain = next,
				moveTo = nil,
				faceTo = nil,
				action = nil,
				home = true,
				snapHome = false,
			}
		end
		-- Progress restarts the clock; a creature that cannot get closer is sent home.
		local distance = flat(position, den)
		local since = next.returnSince or now
		local best = next.returnBest
		if best == nil or distance < best - CreatureBrain.RETURN_PROGRESS then
			best = distance
			since = now
		end
		if now - since >= CreatureBrain.RETURN_TIMEOUT then
			next.mode = "wander"
			next.targetId = 0
			next.nextWanderAt = now
			next.wanderTo = nil
			next.returnSince = nil
			next.returnBest = nil
			return {
				brain = next,
				moveTo = nil,
				faceTo = nil,
				action = nil,
				home = true,
				snapHome = true,
			}
		end
		next.returnSince = since
		next.returnBest = best
		return {
			brain = next,
			moveTo = step(position, den),
			faceTo = nil,
			action = nil,
			home = false,
			snapHome = false,
		}
	end

	local target: Seen? = nil
	if next.mode == "chase" then
		target = targetOf(seen, next.targetId, den)
		if target == nil then
			next.mode = "return"
			next.targetId = 0
			next.wanderTo = nil
			return {
				brain = next,
				moveTo = step(position, den),
				faceTo = nil,
				action = nil,
				home = false,
				snapHome = false,
			}
		end
		-- Only a taunt pulls a chasing creature off its target; a hit from someone else does not.
		local forced = targetOf(seen, taunter, den)
		if forced ~= nil then
			target = forced
		end
	else
		target = targetOf(seen, taunter, den) or targetOf(seen, provoker, den)
		if target == nil then
			local best = math.huge
			for _, other in seen do
				if
					other.valid
					and other.visible
					and flat(other.position, den) <= CreatureBrain.LEASH
				then
					local distance = flat(other.position, position)
					if distance <= kind.sight and distance < best then
						best = distance
						target = other
					end
				end
			end
		end
		if target == nil then
			if now >= next.nextWanderAt then
				local angle = rng() * 2 * math.pi
				local radius = rng() * CreatureBrain.WANDER_RADIUS
				next.wanderTo = {
					x = den.x + math.cos(angle) * radius,
					y = den.y,
					z = den.z + math.sin(angle) * radius,
				}
				next.nextWanderAt = now + WANDER_MIN_SECONDS + rng() * WANDER_EXTRA_SECONDS
			end
			return {
				brain = next,
				moveTo = step(position, next.wanderTo),
				faceTo = nil,
				action = nil,
				home = false,
				snapHome = false,
			}
		end
		next.mode = "chase"
		next.wanderTo = nil
	end

	local chased = target :: Seen
	next.targetId = chased.id
	local goal = chased.position
	local distance = flat(position, goal)
	local attack = kind.attack

	local moveTo: Vec3? = nil
	local keepAway = kind.keepAway
	if keepAway ~= nil and distance < keepAway then
		-- Back off to keepAway from the target, on the line through the creature.
		local dx, dz = position.x - goal.x, position.z - goal.z
		if not (distance > 0) then
			dx, dz, distance = 1, 0, 1
		end
		moveTo = {
			x = goal.x + dx / distance * keepAway,
			y = position.y,
			z = goal.z + dz / distance * keepAway,
		}
		distance = flat(position, goal)
	elseif keepAway ~= nil and distance <= attack.range then
		moveTo = nil
	elseif distance > attack.range * CreatureBrain.STOP_FRACTION then
		moveTo = goal
	end

	local action: Action? = nil
	local lunge = kind.lunge
	if
		distance <= attack.range
		and math.abs(goal.y - position.y) <= Combat.STRIKE_MAX_HEIGHT
		and now >= next.nextAttackAt
	then
		action = { kind = "attack", targetId = chased.id }
		next.nextAttackAt = now + attack.interval
	elseif
		lunge ~= nil
		and not body.rooted
		and now >= next.nextLungeAt
		and distance > attack.range
		and distance <= lunge.distance
	then
		action = { kind = "lunge", targetId = chased.id }
		next.nextLungeAt = now + lunge.interval
	end

	return {
		brain = next,
		moveTo = step(position, moveTo),
		faceTo = goal,
		action = action,
		home = false,
		snapHome = false,
	}
end

return CreatureBrain
