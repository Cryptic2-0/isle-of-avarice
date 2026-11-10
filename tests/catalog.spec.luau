--!strict
local T = require("./harness")
local Messages = require("../src/shared/Catalog/Messages")
local Relics = require("../src/shared/Catalog/Relics")
local Tiers = require("../src/shared/Catalog/Tiers")

T.test("12 relics, slots 1..12, ids match slots", function()
	T.eq(Relics.count, 12)
	for i, relic in Relics.list do
		T.eq(relic.slot, i)
		T.eq(relic.id, string.format("R%03d", i))
		T.eq(Relics.byId[relic.id], relic)
		T.truthy(Tiers.info[relic.tier], relic.id .. " tier")
		T.truthy(#relic.description > 0, relic.id .. " description")
	end
end)

T.test("tier table", function()
	T.eq(Tiers.order, { "Copper", "Silver", "Gold", "Platinum", "Crown" })
	T.eq(Tiers.info.Copper.serverCap, nil)
	T.eq(Tiers.info.Silver.serverCap, 8)
	T.eq(Tiers.info.Crown.serverCap, 1)
	T.eq(Tiers.info.Gold.cacheRespawnSeconds, 300)
	T.eq(Tiers.info.Copper.color, { r = 184, g = 115, b = 51 })
end)

T.test("messages", function()
	T.eq(Messages.format("GOT_CARD", { name = "Barnacle Key" }), "You found Barnacle Key!")
	T.eq(Messages.format("FREE_FULL"), "Your free slots are full.")
	T.eq(Messages.format("NOPE"), "NOPE")
	T.eq(Messages.format("GOT_CARD"), "You found {name}!")
end)
