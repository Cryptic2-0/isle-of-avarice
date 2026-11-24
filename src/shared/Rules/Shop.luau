--!strict
-- The Edict Hall: buying a pack, buying a Copper Relic, selling a free-slot card, and the
-- shop window's display data (spec 3.13). Pure: the server checks where the player stands
-- and writes the result.
local Cards = require("../Catalog/Cards")
local Edicts = require("../Catalog/Edicts")
local Ledger = require("./Ledger")
local ShopCatalog = require("../Catalog/Shop")
local Types = require("../Types")

type Ledger = Types.Ledger

export type StockRow = { relicId: string, name: string, priceText: string, canBuy: boolean }
export type SellRow = { index: number, cardId: string, name: string, priceText: string }
export type View = {
	coinText: string,
	packText: string,
	oddsText: string,
	canBuyPack: boolean,
	stock: { StockRow },
	sell: { SellRow },
}

local MAX_CARD_ID_LENGTH = 16

local Shop = {}

-- Written positively so Coin that is not a real, non-negative number affords nothing.
local function affords(coin: number, price: number): boolean
	return coin >= price and coin < math.huge
end

-- The Edicts of one pack: one roll per card, each on its own, by the catalog's weights.
-- A roll outside 0..1 still gives a card.
function Shop.drawPack(rng: () -> number): { string }
	local total = 0
	for _, edict in Edicts.list do
		total += edict.weight
	end
	local cards: { string } = {}
	for _ = 1, ShopCatalog.PACK_SIZE do
		local roll = rng()
		if not (roll >= 0) then
			roll = 0
		end
		local mark = roll * total
		local picked = Edicts.list[#Edicts.list].id
		local sum = 0
		for _, edict in Edicts.list do
			sum += edict.weight
			if mark < sum then
				picked = edict.id
				break
			end
		end
		table.insert(cards, picked)
	end
	return cards
end

local function buyPack(
	ledger: Ledger,
	coin: number,
	rng: () -> number
): (Ledger?, number, string, { [string]: string }?)
	local price = ShopCatalog.PACK_PRICE
	if not affords(coin, price) then
		return nil, coin, "NOT_ENOUGH_COIN", { cost = tostring(price) }
	end
	if Ledger.room(ledger) < ShopCatalog.PACK_SIZE then
		return nil, coin, "SHOP_NO_ROOM", { count = tostring(ShopCatalog.PACK_SIZE) }
	end
	local cards = Shop.drawPack(rng)
	local free = table.clone(ledger.free)
	for _, id in cards do
		table.insert(free, id)
	end
	return { claimed = table.clone(ledger.claimed), free = free },
		coin - price,
		"SHOP_PACK",
		{ names = Cards.names(cards) }
end

local function buyRelic(
	ledger: Ledger,
	coin: number,
	relicId: any
): (Ledger?, number, string, { [string]: string }?)
	if type(relicId) ~= "string" or table.find(ShopCatalog.stock, relicId) == nil then
		return nil, coin, "NOT_FOR_SALE", nil
	end
	local price = ShopCatalog.RELIC_PRICE
	if not affords(coin, price) then
		return nil, coin, "NOT_ENOUGH_COIN", { cost = tostring(price) }
	end
	local result, err = Ledger.add(ledger, relicId)
	if result == nil then
		return nil, coin, err or "FREE_FULL", nil
	end
	return result, coin - price, "SHOP_BOUGHT", { name = Cards.name(relicId) }
end

-- The request carries the card the player saw on that row; if the free list has shifted (a
-- double click) the card there differs and nothing is sold.
local function sell(
	ledger: Ledger,
	coin: number,
	raw: any
): (Ledger?, number, string, { [string]: string }?)
	local freeIndex, cardId = raw.freeIndex, raw.cardId
	if type(freeIndex) ~= "number" then
		return nil, coin, "BAD_REQUEST", nil
	end
	if type(cardId) ~= "string" or #cardId > MAX_CARD_ID_LENGTH then
		return nil, coin, "BAD_REQUEST", nil
	end
	if freeIndex ~= math.floor(freeIndex) or ledger.free[freeIndex] ~= cardId then
		return nil, coin, "BAD_INDEX", nil
	end
	local price = ShopCatalog.sellPrice(cardId)
	if price == nil then
		return nil, coin, "NOT_FOR_SALE", nil
	end
	local result, err = Ledger.discard(ledger, freeIndex)
	if result == nil then
		return nil, coin, err or "BAD_INDEX", nil
	end
	local paid = if coin >= 0 and coin < math.huge then coin + price else coin
	return result, paid, "SHOP_SOLD", { name = Cards.name(cardId), coin = tostring(price) }
end

-- Validates a raw client request and applies it. Request shapes:
--   { kind = "pack" } | { kind = "relic", relicId = string }
--   | { kind = "sell", freeIndex = number, cardId = string }
-- Success: the new Ledger, the new Coin, a message code and its arguments.
-- Failure: nil, the same Coin, an error code (and arguments). Never errors on hostile input.
function Shop.apply(
	ledger: Ledger?,
	coin: number,
	raw: any,
	rng: () -> number
): (Ledger?, number, string, { [string]: string }?)
	if ledger == nil then
		return nil, coin, "DATA_NOT_LOADED", nil
	end
	if type(raw) ~= "table" then
		return nil, coin, "BAD_REQUEST", nil
	end
	local kind = raw.kind
	if kind == "pack" then
		return buyPack(ledger, coin, rng)
	elseif kind == "relic" then
		return buyRelic(ledger, coin, raw.relicId)
	elseif kind == "sell" then
		return sell(ledger, coin, raw)
	end
	return nil, coin, "BAD_REQUEST", nil
end

-- What the shop window shows for this player.
function Shop.view(ledger: Ledger, coin: number): View
	local held = if coin >= 0 and coin < math.huge then math.floor(coin) else 0
	local room = Ledger.room(ledger)
	local stock: { StockRow } = {}
	for _, relicId in ShopCatalog.stock do
		table.insert(stock, {
			relicId = relicId,
			name = Cards.name(relicId),
			priceText = `{ShopCatalog.RELIC_PRICE} Coin`,
			canBuy = held >= ShopCatalog.RELIC_PRICE and room >= 1,
		})
	end
	local sellRows: { SellRow } = {}
	for index, cardId in ledger.free do
		local price = ShopCatalog.sellPrice(cardId)
		if price ~= nil then
			table.insert(sellRows, {
				index = index,
				cardId = cardId,
				name = Cards.name(cardId),
				priceText = `+{price} Coin`,
			})
		end
	end
	return {
		coinText = `Coin: {held}`,
		packText = `Edict pack: {ShopCatalog.PACK_SIZE} Edicts for {ShopCatalog.PACK_PRICE} Coin`,
		oddsText = ShopCatalog.oddsText,
		canBuyPack = held >= ShopCatalog.PACK_PRICE and room >= ShopCatalog.PACK_SIZE,
		stock = stock,
		sell = sellRows,
	}
end

return Shop
