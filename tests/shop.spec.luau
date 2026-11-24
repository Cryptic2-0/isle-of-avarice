--!strict
local T = require("./harness")
local Ledger = require("../src/shared/Rules/Ledger")
local Shop = require("../src/shared/Rules/Shop")
local Types = require("../src/shared/Types")

local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = copy(v)
	end
	return out
end

-- Returns the given values in turn, then 0.
local function seq(...: number): () -> number
	local values = { ... }
	local i = 0
	return function()
		i += 1
		return values[i] or 0
	end
end

local function filled(count: number): Types.Ledger
	return { claimed = {}, free = table.create(count, "R001") }
end

T.test("a pack draws three Edicts, each on its own, by the shown odds", function()
	-- Summons 0-25, Audit 25-45, Veil 45-65, Passage 65-80, Homecoming 80-100.
	T.eq(Shop.drawPack(seq(0, 0.2499, 0.25)), { "E001", "E001", "E002" })
	T.eq(Shop.drawPack(seq(0.45, 0.65, 0.8)), { "E003", "E004", "E005" })
	T.eq(Shop.drawPack(seq(0.9999, 0.6499, 0.7999)), { "E005", "E003", "E004" })
	-- A roll that is not in 0..1 still gives a card.
	T.eq(Shop.drawPack(seq(1, 0 / 0, -2)), { "E005", "E001", "E001" })
	local counts: { [string]: number } = {}
	for _ = 1, 400 do
		for _, id in Shop.drawPack(math.random) do
			counts[id] = (counts[id] or 0) + 1
		end
	end
	for _, id in { "E001", "E002", "E003", "E004", "E005" } do
		T.truthy((counts[id] or 0) > 60, id .. " turns up")
	end
end)

T.test("buying a pack", function()
	local ledger, coin, code, args =
		Shop.apply(Ledger.new(), 100, { kind = "pack" }, seq(0, 0.5, 0.9))
	T.eq(
		{ ledger, coin, code, args },
		{
			{ claimed = {}, free = { "E001", "E003", "E005" } },
			40,
			"SHOP_PACK",
			{ names = "Summons, Veil, Homecoming" },
		} :: { any }
	)
	T.eq(
		{ Shop.apply(Ledger.new(), 59, { kind = "pack" }, seq()) },
		{ nil, 59, "NOT_ENOUGH_COIN", { cost = "60" } } :: { any }
	)
	T.eq(
		{ Shop.apply(filled(18), 100, { kind = "pack" }, seq()) },
		{ nil, 100, "SHOP_NO_ROOM", { count = "3" } } :: { any }
	)
	T.eq(select(3, Shop.apply(filled(17), 60, { kind = "pack" }, seq())), "SHOP_PACK")
	-- No roll is drawn for a refused purchase.
	local drawn = 0
	Shop.apply(Ledger.new(), 0, { kind = "pack" }, function()
		drawn += 1
		return 0
	end)
	T.eq(drawn, 0)
	for _, bad in { 0 / 0, -5, math.huge } do
		local result, kept = Shop.apply(Ledger.new(), bad, { kind = "pack" }, seq())
		T.eq(result, nil, "Coin " .. tostring(bad))
		T.eq(kept, bad)
	end
end)

T.test("buying a Copper Relic", function()
	T.eq(
		{ Shop.apply(Ledger.new(), 45, { kind = "relic", relicId = "R003" }, seq()) },
		{ { claimed = {}, free = { "R003" } }, 5, "SHOP_BOUGHT", { name = "Gull-Feather Quill" } } :: { any }
	)
	T.eq(
		{ Shop.apply(Ledger.new(), 39, { kind = "relic", relicId = "R003" }, seq()) },
		{ nil, 39, "NOT_ENOUGH_COIN", { cost = "40" } } :: { any }
	)
	T.eq(
		select(3, Shop.apply(filled(20), 100, { kind = "relic", relicId = "R003" }, seq())),
		"FREE_FULL"
	)
	for _, notSold in { "R007", "R012", "R028", "E001", "nope", "", 5, {} } :: { any } do
		T.eq(
			{ Shop.apply(Ledger.new(), 999, { kind = "relic", relicId = notSold }, seq()) },
			{ nil, 999, "NOT_FOR_SALE" } :: { any }
		)
	end
end)

T.test("selling a free-slot card", function()
	local ledger: Types.Ledger =
		{ claimed = { R007 = true }, free = { "R001", "R007", "E002", "R010" } }
	T.eq(
		{ Shop.apply(ledger, 10, { kind = "sell", freeIndex = 2, cardId = "R007" }, seq()) },
		{
			{ claimed = { R007 = true }, free = { "R001", "E002", "R010" } },
			25,
			"SHOP_SOLD",
			{ name = "Bottled Squall", coin = "15" },
		} :: { any }
	)
	T.eq(
		select(2, Shop.apply(ledger, 10, { kind = "sell", freeIndex = 1, cardId = "R001" }, seq())),
		11
	)
	T.eq(
		select(2, Shop.apply(ledger, 10, { kind = "sell", freeIndex = 3, cardId = "E002" }, seq())),
		13
	)
	T.eq(
		select(2, Shop.apply(ledger, 10, { kind = "sell", freeIndex = 4, cardId = "R010" }, seq())),
		60
	)
	-- The row moved, or never existed: nothing is sold.
	for _, index in { 1, 0, 5, 1.5, 0 / 0 } do
		T.eq(
			{ Shop.apply(ledger, 10, { kind = "sell", freeIndex = index, cardId = "R007" }, seq()) },
			{ nil, 10, "BAD_INDEX" } :: { any }
		)
	end
	for _, raw in
		{
			{ kind = "sell", freeIndex = "2", cardId = "R007" },
			{ kind = "sell", freeIndex = 2 },
			{ kind = "sell", cardId = "R007" },
			{ kind = "sell", freeIndex = 2, cardId = string.rep("R", 40) },
		} :: { any }
	do
		T.eq({ Shop.apply(ledger, 10, raw, seq()) }, { nil, 10, "BAD_REQUEST" } :: { any })
	end
end)

T.test("apply refuses junk and unloaded data", function()
	T.eq(
		{ Shop.apply(nil, 100, { kind = "pack" }, seq()) },
		{ nil, 100, "DATA_NOT_LOADED" } :: { any }
	)
	for _, raw in { "pack", 5, true, {}, { kind = "steal" }, { kind = 3 } } :: { any } do
		T.eq({ Shop.apply(Ledger.new(), 100, raw, seq()) }, { nil, 100, "BAD_REQUEST" } :: { any })
	end
	T.eq({ Shop.apply(Ledger.new(), 100, nil, seq()) }, { nil, 100, "BAD_REQUEST" } :: { any })
	local ledger: Types.Ledger = { claimed = {}, free = { "R001", "E002" } }
	local before = copy(ledger)
	Shop.apply(ledger, 100, { kind = "pack" }, seq())
	Shop.apply(ledger, 100, { kind = "relic", relicId = "R001" }, seq())
	Shop.apply(ledger, 100, { kind = "sell", freeIndex = 1, cardId = "R001" }, seq())
	T.eq(ledger, before, "the ledger is not changed in place")
end)

T.test("view: what the shop window shows", function()
	local view = Shop.view({ claimed = {}, free = { "R007", "E002", "R001" } }, 45)
	T.eq(view.coinText, "Coin: 45")
	T.eq(view.packText, "Edict pack: 3 Edicts for 60 Coin")
	T.eq(view.oddsText, "Each card: Summons 25%, Audit 20%, Veil 20%, Passage 15%, Homecoming 20%")
	T.eq(view.canBuyPack, false)
	T.eq(#view.stock, 6)
	T.eq(
		view.stock[1],
		{ relicId = "R001", name = "Tarnished Tally-Coin", priceText = "40 Coin", canBuy = true }
	)
	T.eq(view.sell, {
		{ index = 1, cardId = "R007", name = "Bottled Squall", priceText = "+15 Coin" },
		{ index = 2, cardId = "E002", name = "Audit", priceText = "+3 Coin" },
		{ index = 3, cardId = "R001", name = "Tarnished Tally-Coin", priceText = "+1 Coin" },
	})
	local rich = Shop.view(filled(18), 500)
	T.eq(
		{ rich.canBuyPack, rich.stock[1].canBuy },
		{ false, true },
		"a pack needs three free slots"
	)
	local full = Shop.view(filled(20), 500)
	T.eq(full.stock[1].canBuy, false)
	T.eq(Shop.view(Ledger.new(), 60).canBuyPack, true)
	T.eq(Shop.view(Ledger.new(), 39).stock[1].canBuy, false)
	T.eq(Shop.view(Ledger.new(), 0 / 0).coinText, "Coin: 0")
end)
