--!strict
local T = require("./harness")
local Abilities = require("../src/shared/Catalog/Abilities")
local Paths = require("../src/shared/Catalog/Paths")

T.test("six paths in hexagon order", function()
	T.eq(Paths.order, { "Fang", "Gale", "Ember", "Mire", "Mend", "Bulwark" })
	local colors: { [string]: boolean } = {}
	for _, path in Paths.order do
		local info = Paths.info[path]
		T.truthy(info.name == path and #info.style > 0, path)
		local key = info.color.r .. "," .. info.color.g .. "," .. info.color.b
		T.falsy(colors[key], path .. " color is unique")
		colors[key] = true
	end
end)

T.test("18 abilities, three per path at levels 3, 10, 18", function()
	T.eq(#Abilities.list, 18)
	for _, path in Paths.order do
		local mine = Abilities.forPath(path)
		T.eq(#mine, 3, path)
		T.eq({ mine[1].unlockLevel, mine[2].unlockLevel, mine[3].unlockLevel }, { 3, 10, 18 }, path)
	end
end)

T.test("ids and names are unique and well formed", function()
	local names: { [string]: boolean } = {}
	local count = 0
	for _, ability in Abilities.list do
		T.truthy(#ability.id <= 16, ability.id)
		T.eq(Abilities.byId[ability.id], ability, ability.id)
		T.falsy(names[ability.name], ability.name)
		names[ability.name] = true
		T.truthy(#ability.description > 0, ability.id .. " description")
		count += 1
	end
	local byIdCount = 0
	for _ in Abilities.byId do
		byIdCount += 1
	end
	T.eq(byIdCount, count)
end)

T.test("list is ordered by path then unlock level", function()
	local i = 1
	for _, path in Paths.order do
		for _, ability in Abilities.forPath(path) do
			T.eq(Abilities.list[i], ability)
			i += 1
		end
	end
end)

T.test("spot checks of ability numbers", function()
	T.eq(Abilities.byId.lunge.distance, 12)
	T.eq(Abilities.byId.lunge.damage, 22)
	T.eq(Abilities.byId.lunge.cooldown, 6)
	T.eq(Abilities.byId.cinder_bolt.burn, { dps = 3, duration = 3 })
	T.eq(Abilities.byId.cinder_bolt.cooldown, 3.5)
	T.eq(
		Abilities.byId.sinking_field.zone,
		{ radius = 10, duration = 4, dps = 3, slow = 0.5, ahead = 0 }
	)
	T.eq(Abilities.byId.shield_bash.reduction, { factor = 0.6, duration = 2 })
	T.eq(Abilities.byId.challenge.taunt, 3)
	T.eq(Abilities.byId.renewal.allyRadius, 15)
end)

T.test("Paths.isPath", function()
	T.truthy(Paths.isPath("Mire"))
	T.falsy(Paths.isPath("mire"))
	T.falsy(Paths.isPath(nil))
	T.falsy(Paths.isPath(4))
end)
