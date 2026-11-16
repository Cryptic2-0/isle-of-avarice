--!strict
-- The Edict Hall's prices and stock (spec 3.13). Starting values for play tests.
local Edicts = require("./Edicts")
local Relics = require("./Relics")

local PACK_PRICE = 60
local PACK_SIZE = 3
local RELIC_PRICE = 40
local EDICT_SELL = 3
-- How close to the clerk a player must stand to buy or sell.
local REACH = 15

-- The Copper Relics of the Counting Fields.
local stock: { string } = { "R001", "R002", "R003", "R004", "R005", "R006" }

-- What the clerk pays for a spare Relic. A tier that is missing cannot be sold.
local sellByTier: { [string]: number } = {
	Copper = 1,
	Silver = 15,
	Gold = 50,
	Platinum = 150,
}

-- What the clerk pays for the card, or nil when it is not a card or cannot be sold.
local function sellPrice(cardId: any): number?
	if type(cardId) ~= "string" then
		return nil
	end
	local relic = Relics.byId[cardId]
	if relic ~= nil then
		return sellByTier[relic.tier]
	end
	if Edicts.byId[cardId] ~= nil then
		return EDICT_SELL
	end
	return nil
end

local odds: { string } = {}
for _, edict in Edicts.list do
	table.insert(odds, `{edict.name} {edict.weight}%`)
end

return {
	PACK_PRICE = PACK_PRICE,
	PACK_SIZE = PACK_SIZE,
	RELIC_PRICE = RELIC_PRICE,
	EDICT_SELL = EDICT_SELL,
	REACH = REACH,
	stock = stock,
	sellByTier = sellByTier,
	sellPrice = sellPrice,
	-- Shown in the shop window: the odds of a pack must be visible.
	oddsText = "Each card: " .. table.concat(odds, ", "),
}
