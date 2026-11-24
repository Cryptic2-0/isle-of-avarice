--!strict
local Abilities = require("../Catalog/Abilities")
local Combat = require("./Combat")
local PathProgress = require("./PathProgress")
local Targeting = require("./Targeting")
local Types = require("../Types")

type Vec3 = Types.Vec3
type Ability = Types.Ability
type PathProgress = Types.PathProgress
type Fighter = Combat.Fighter

export type CastState = { cooldowns: { [string]: number }, lastCast: number } -- ability id -> time it is ready
export type Hit = { targetId: number, damage: number }
export type Zone = { center: Vec3, radius: number, duration: number, dps: number, slow: number? }
export type Plan = {
	hits: { Hit },
	waves: number,
	interval: number,
	moveTo: Vec3?,
	pullTo: Vec3?,
	knockbackTo: Vec3?,
	zone: Zone?,
}

local Casting = {}

Casting.GLOBAL_GAP = 0.3

function Casting.new(): CastState
	return { cooldowns = {}, lastCast = -math.huge }
end

function Casting.canCast(
	state: CastState,
	progress: PathProgress,
	rawSlot: any,
	now: number,
	rooted: boolean
): (string?, string)
	if
		type(rawSlot) ~= "number"
		or rawSlot ~= rawSlot
		or rawSlot ~= math.floor(rawSlot)
		or rawSlot < 1
		or rawSlot > 4
	then
		return nil, "BAD_REQUEST"
	end
	local id = progress.loadout[rawSlot :: number]
	if id == nil or id == "" then
		return nil, "NO_ABILITY"
	end
	local ability = Abilities.byId[id]
	if ability == nil or table.find(PathProgress.unlocked(progress), id) == nil then
		return nil, "NOT_UNLOCKED"
	end
	-- Written so NaN fails safe: only a clearly elapsed time passes.
	local readyAt = state.cooldowns[id] or -math.huge
	if not (now >= readyAt) or not (now - state.lastCast >= Casting.GLOBAL_GAP) then
		return nil, "ON_COOLDOWN"
	end
	if rooted and ability.kind == "dash" then
		return nil, "ROOTED"
	end
	return id, "OK"
end

function Casting.commit(state: CastState, abilityId: string, now: number): CastState
	local cooldowns = table.clone(state.cooldowns)
	local ability = Abilities.byId[abilityId]
	if ability ~= nil then
		cooldowns[abilityId] = now + ability.cooldown
	end
	return { cooldowns = cooldowns, lastCast = now }
end

local function fighterById(others: { Fighter }, id: number): Fighter?
	for _, other in others do
		if other.id == id then
			return other
		end
	end
	return nil
end

local function emptyPlan(): Plan
	return { hits = {}, waves = 1, interval = 0 }
end

local function planMelee(
	ability: Ability,
	caster: Fighter,
	others: { Fighter },
	taunter: number?
): Plan
	local plan = emptyPlan()
	plan.waves = ability.hits or 1
	plan.interval = ability.interval or 0
	local targetId = Combat.pickTarget(caster, others, ability.range, taunter)
	if targetId == nil then
		return plan
	end
	local target = fighterById(others, targetId)
	local damage = ability.damage or 0
	if
		target ~= nil
		and target.health ~= nil
		and ability.executeBelow ~= nil
		and ability.executeDamage ~= nil
		and target.health <= ability.executeBelow
	then
		damage = ability.executeDamage
	end
	table.insert(plan.hits, { targetId = targetId, damage = damage })
	if target ~= nil and ability.knockback ~= nil then
		local lx, lz = caster.look.x, caster.look.z
		local length = math.sqrt(lx * lx + lz * lz)
		if length > 0 and length < math.huge then
			plan.knockbackTo = {
				x = target.position.x + lx / length * ability.knockback,
				y = target.position.y,
				z = target.position.z + lz / length * ability.knockback,
			}
		end
	end
	return plan
end

local function planShot(
	ability: Ability,
	caster: Fighter,
	others: { Fighter },
	taunter: number?
): Plan
	local plan = emptyPlan()
	local shots = ability.shots or 1
	local spread = ability.spread or 0
	for i = 1, shots do
		local angle = 0
		if shots > 1 then
			angle = -spread / 2 + spread * (i - 1) / (shots - 1)
		end
		local targetId = Targeting.shot(caster, others, ability.range or 0, angle, taunter)
		if targetId ~= nil then
			table.insert(plan.hits, { targetId = targetId, damage = ability.damage or 0 })
		end
	end
	if ability.pull ~= nil then
		plan.pullTo = Targeting.ahead(caster, ability.pull)
	end
	return plan
end

function Casting.plan(
	ability: Ability,
	caster: Fighter,
	others: { Fighter },
	taunter: number?
): Plan
	local kind = ability.kind
	if kind == "melee" then
		return planMelee(ability, caster, others, taunter)
	elseif kind == "shot" then
		return planShot(ability, caster, others, taunter)
	end
	local plan = emptyPlan()
	if kind == "dash" then
		local distance = ability.distance or 0
		plan.moveTo = Targeting.ahead(caster, distance)
		local targetId = Targeting.dashHit(caster, others, distance)
		if targetId ~= nil then
			table.insert(plan.hits, { targetId = targetId, damage = ability.damage or 0 })
		end
	elseif kind == "zone" and ability.zone ~= nil then
		local z = ability.zone
		plan.zone = {
			center = Targeting.ahead(caster, z.ahead),
			radius = z.radius,
			duration = z.duration,
			dps = z.dps,
			slow = z.slow,
		}
	elseif kind == "burst" then
		for _, id in Targeting.inRadius(caster.position, others, ability.radius or 0, caster.id) do
			table.insert(plan.hits, { targetId = id, damage = ability.damage or 0 })
		end
	end
	return plan
end

return Casting
