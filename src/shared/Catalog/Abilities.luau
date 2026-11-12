--!strict
local Types = require("../Types")

type Ability = Types.Ability
type PathId = Types.PathId

-- Ordered by Path (hexagon order), then unlock level.
local list: { Ability } = {
	-- Fang
	{
		id = "lunge",
		name = "Lunge",
		path = "Fang",
		unlockLevel = 3,
		cooldown = 6,
		kind = "dash",
		distance = 12,
		damage = 22,
		description = "Dash 12 studs; the first enemy you pass takes 22 damage.",
	},
	{
		id = "rending_flurry",
		name = "Rending Flurry",
		path = "Fang",
		unlockLevel = 10,
		cooldown = 8,
		kind = "melee",
		range = 8,
		damage = 10,
		hits = 3,
		interval = 0.25,
		description = "Strike the nearest enemy in front of you three times for 10 damage each.",
	},
	{
		id = "final_toll",
		name = "Final Toll",
		path = "Fang",
		unlockLevel = 18,
		cooldown = 14,
		kind = "melee",
		range = 8,
		damage = 12,
		executeBelow = 35,
		executeDamage = 40,
		description = "Strike for 12 damage, or 40 if the enemy has 35 health or less.",
	},
	-- Gale
	{
		id = "slipstream",
		name = "Slipstream",
		path = "Gale",
		unlockLevel = 3,
		cooldown = 5,
		kind = "dash",
		distance = 20,
		damage = 10,
		description = "Dash 20 studs; the first enemy you pass takes 10 damage.",
	},
	{
		id = "gust_blade",
		name = "Gust Blade",
		path = "Gale",
		unlockLevel = 10,
		cooldown = 4,
		kind = "shot",
		range = 35,
		damage = 18,
		description = "Fire a blade of wind up to 35 studs that deals 18 damage.",
	},
	{
		id = "afterimage",
		name = "Afterimage",
		path = "Gale",
		unlockLevel = 18,
		cooldown = 16,
		kind = "self",
		immune = 1.5,
		empower = { bonus = 20, duration = 4 },
		description = "For 1.5 seconds nothing can hurt or affect you; your next hit within 4 seconds deals 20 extra damage.",
	},
	-- Ember
	{
		id = "cinder_bolt",
		name = "Cinder Bolt",
		path = "Ember",
		unlockLevel = 3,
		cooldown = 3.5,
		kind = "shot",
		range = 50,
		damage = 16,
		burn = { dps = 3, duration = 3 },
		description = "Fire a bolt up to 50 studs that deals 16 damage and burns for 3 damage a second for 3 seconds.",
	},
	{
		id = "scattershot",
		name = "Scattershot",
		path = "Ember",
		unlockLevel = 10,
		cooldown = 7,
		kind = "shot",
		range = 30,
		damage = 8,
		shots = 5,
		spread = 40,
		description = "Fire five sparks in a 40 degree fan, each dealing 8 damage up to 30 studs.",
	},
	{
		id = "ashfield",
		name = "Ashfield",
		path = "Ember",
		unlockLevel = 18,
		cooldown = 15,
		kind = "zone",
		zone = { radius = 8, duration = 5, dps = 7, ahead = 25 },
		description = "Scorch the ground 25 studs ahead; enemies inside take 7 damage a second for 5 seconds.",
	},
	-- Mire
	{
		id = "bog_snare",
		name = "Bog Snare",
		path = "Mire",
		unlockLevel = 3,
		cooldown = 9,
		kind = "shot",
		range = 30,
		damage = 6,
		root = 1.5,
		description = "Fire a snare up to 30 studs that deals 6 damage and roots the target for 1.5 seconds.",
	},
	{
		id = "sinking_field",
		name = "Sinking Field",
		path = "Mire",
		unlockLevel = 10,
		cooldown = 14,
		kind = "zone",
		zone = { radius = 10, duration = 4, dps = 3, slow = 0.5, ahead = 0 },
		description = "Turn the ground around you to mud for 4 seconds, slowing enemies by half and dealing 3 damage a second.",
	},
	{
		id = "undertow",
		name = "Undertow",
		path = "Mire",
		unlockLevel = 18,
		cooldown = 12,
		kind = "shot",
		range = 25,
		damage = 10,
		pull = 4,
		slow = { factor = 0.7, duration = 2 },
		description = "Hit an enemy up to 25 studs for 10 damage, pull them to 4 studs in front of you and slow them for 2 seconds.",
	},
	-- Mend
	{
		id = "siphon",
		name = "Siphon",
		path = "Mend",
		unlockLevel = 3,
		cooldown = 6,
		kind = "melee",
		range = 8,
		damage = 14,
		heal = 14,
		healOnHit = true,
		description = "Strike for 14 damage and heal 14 health if it hits.",
	},
	{
		id = "ward",
		name = "Ward",
		path = "Mend",
		unlockLevel = 10,
		cooldown = 14,
		kind = "self",
		shield = { amount = 30, duration = 6 },
		allyRadius = 15,
		description = "Shield yourself and allies within 15 studs against 30 damage for 6 seconds.",
	},
	{
		id = "renewal",
		name = "Renewal",
		path = "Mend",
		unlockLevel = 18,
		cooldown = 18,
		kind = "self",
		heal = 35,
		cleanse = true,
		allyRadius = 15,
		description = "Heal yourself and allies within 15 studs for 35 health and remove slow, root and burn.",
	},
	-- Bulwark
	{
		id = "shield_bash",
		name = "Shield Bash",
		path = "Bulwark",
		unlockLevel = 3,
		cooldown = 7,
		kind = "melee",
		range = 8,
		damage = 14,
		knockback = 10,
		reduction = { factor = 0.6, duration = 2 },
		description = "Strike for 14 damage, knock the enemy back 10 studs and take 40% less damage for 2 seconds.",
	},
	{
		id = "rebuke",
		name = "Rebuke",
		path = "Bulwark",
		unlockLevel = 10,
		cooldown = 14,
		kind = "self",
		reflect = { factor = 0.5, duration = 2 },
		description = "For 2 seconds, reflect half of the damage you take back to the attacker.",
	},
	{
		id = "challenge",
		name = "Challenge",
		path = "Bulwark",
		unlockLevel = 18,
		cooldown = 16,
		kind = "burst",
		radius = 12,
		damage = 12,
		taunt = 3,
		description = "Enemies within 12 studs take 12 damage and are forced to target you for 3 seconds.",
	},
}

local byId: { [string]: Ability } = {}
for _, ability in list do
	byId[ability.id] = ability
end

local function forPath(path: PathId): { Ability }
	local result: { Ability } = {}
	for _, ability in list do
		if ability.path == path then
			table.insert(result, ability)
		end
	end
	return result
end

return {
	list = list,
	byId = byId,
	forPath = forPath,
}
