--!strict
local T = require("./harness")
local Cards = require("../src/shared/Catalog/Cards")
local Edicts = require("../src/shared/Catalog/Edicts")
local Relics = require("../src/shared/Catalog/Relics")
local Shop = require("../src/shared/Catalog/Shop")

T.test("five Edicts, as spec 3.13 lists them", function()
	local rows = {}
	for i, edict in Edicts.list do
		T.eq(edict.id, string.format("E%03d", i))
		T.eq(Edicts.byId[edict.id], edict)
		T.eq(Edicts.byKey[edict.key], edict)
		T.truthy(#edict.description > 0, edict.id)
		table.insert(rows, { edict.key, edict.name, edict.weight, edict.needs })
	end
	T.eq(
		rows,
		{
			{ "summons", "Summons", 25, "relic" },
			{ "audit", "Audit", 20, "" },
			{ "veil", "Veil", 20, "" },
			{ "passage", "Passage", 15, "player" },
			{ "homecoming", "Homecoming", 20, "" },
		} :: { any }
	)
	local total = 0
	for _, edict in Edicts.list do
		total += edict.weight
	end
	T.eq(total, 100, "weights are percentages")
	-- No Edict id is a Relic id, and no name is shared.
	local names: { [string]: boolean } = {}
	for _, relic in Relics.list do
		names[relic.name] = true
	end
	for _, edict in Edicts.list do
		T.eq(Relics.byId[edict.id], nil)
		T.falsy(names[edict.name], edict.name)
	end
end)

T.test("Cards tells a Relic from an Edict", function()
	T.eq(
		Cards.info("R007"),
		{ id = "R007", name = "Bottled Squall", kind = "relic", tier = "Silver" }
	)
	T.eq(Cards.info("E003"), { id = "E003", name = "Veil", kind = "edict" })
	T.eq(
		{ Cards.isRelic("R001"), Cards.isRelic("E001"), Cards.isRelic("X") },
		{ true, false, false }
	)
	T.eq(
		{ Cards.isEdict("E005"), Cards.isEdict("R001"), Cards.isEdict("E006") },
		{ true, false, false }
	)
	for _, bad in { "", "R999", "E000", 5, {}, true } :: { any } do
		T.eq(Cards.info(bad), nil)
		T.falsy(Cards.isRelic(bad))
		T.falsy(Cards.isEdict(bad))
	end
	T.eq(Cards.info(nil), nil)
	T.eq(Cards.name("E001"), "Summons")
	T.eq(Cards.name("R001"), "Tarnished Tally-Coin")
	T.eq(Cards.name("nope"), "")
	T.eq(Cards.names({ "E001", "R001", "nope" }), "Summons, Tarnished Tally-Coin")
end)

T.test("shop prices and stock", function()
	T.eq({ Shop.PACK_PRICE, Shop.PACK_SIZE, Shop.RELIC_PRICE, Shop.REACH }, { 60, 3, 40, 15 })
	T.eq(Shop.stock, { "R001", "R002", "R003", "R004", "R005", "R006" })
	for _, relicId in Shop.stock do
		T.eq(Relics.byId[relicId].tier, "Copper")
	end
	T.eq({
		Shop.sellPrice("R001"),
		Shop.sellPrice("R007"),
		Shop.sellPrice("R010"),
		Shop.sellPrice("R012"),
		Shop.sellPrice("E002"),
	}, { 1, 15, 50, 150, 3 })
	T.eq(Shop.sellPrice("nope"), nil)
	T.eq(Shop.sellByTier.Crown, nil, "a Crown Relic cannot be sold")
	-- Buying at the shop and selling back always loses Coin.
	T.truthy((Shop.sellPrice("R001") or 0) < Shop.RELIC_PRICE)
	T.truthy(Shop.EDICT_SELL * Shop.PACK_SIZE < Shop.PACK_PRICE)
	T.eq(Shop.oddsText, "Each card: Summons 25%, Audit 20%, Veil 20%, Passage 15%, Homecoming 20%")
end)
