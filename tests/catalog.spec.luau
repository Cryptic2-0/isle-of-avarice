--!strict
local T = require("./harness")
local Messages = require("../src/shared/Catalog/Messages")
local Relics = require("../src/shared/Catalog/Relics")
local Tiers = require("../src/shared/Catalog/Tiers")

T.test("30 relics, slots 1..30, ids match slots", function()
	T.eq(Relics.count, 30)
	for i, relic in Relics.list do
		T.eq(relic.slot, i)
		T.eq(relic.id, string.format("R%03d", i))
		T.eq(Relics.byId[relic.id], relic)
		T.truthy(Tiers.info[relic.tier], relic.id .. " tier")
		T.truthy(#relic.description > 0, relic.id .. " description")
	end
end)

T.test("relics 13 to 30 have the spec tiers", function()
	local expected: { [number]: string } = {}
	for i = 13, 18 do
		expected[i] = "Silver"
	end
	for i = 19, 26 do
		expected[i] = "Gold"
	end
	expected[27] = "Platinum"
	for i = 28, 30 do
		expected[i] = "Copper"
	end
	for i = 13, 30 do
		T.eq(Relics.list[i].tier, expected[i], Relics.list[i].id)
	end
end)

T.test("relic names are unique and non-empty", function()
	local seen: { [string]: boolean } = {}
	for _, relic in Relics.list do
		T.truthy(#relic.name > 0, relic.id .. " name")
		T.falsy(seen[relic.name], relic.id .. " duplicate name")
		seen[relic.name] = true
	end
end)

T.test("new relic names", function()
	T.eq(Relics.byId.R013.name, "Low-Tide Tally Stick")
	T.eq(Relics.byId.R021.name, "Bog Pearl")
	T.eq(Relics.byId.R027.name, "Writ of the Unpaid Debt")
	T.eq(Relics.byId.R030.name, "Waterlogged IOU")
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
