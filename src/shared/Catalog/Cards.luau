--!strict
-- A card is a Relic or an Edict. This answers "what is this id" for both.
local Edicts = require("./Edicts")
local Relics = require("./Relics")
local Types = require("../Types")

export type Info = { id: string, name: string, kind: "relic" | "edict", tier: Types.Tier? }

local Cards = {}

function Cards.isRelic(id: any): boolean
	return type(id) == "string" and Relics.byId[id] ~= nil
end

function Cards.isEdict(id: any): boolean
	return type(id) == "string" and Edicts.byId[id] ~= nil
end

-- Nil for anything that is not a known card id. Never errors.
function Cards.info(id: any): Info?
	if type(id) ~= "string" then
		return nil
	end
	local relic = Relics.byId[id]
	if relic ~= nil then
		return { id = relic.id, name = relic.name, kind = "relic", tier = relic.tier }
	end
	local edict = Edicts.byId[id]
	if edict ~= nil then
		return { id = edict.id, name = edict.name, kind = "edict" }
	end
	return nil
end

-- The card's name, or "" when it is not a card.
function Cards.name(id: any): string
	local info = Cards.info(id)
	return if info ~= nil then info.name else ""
end

-- "Veil, Bottled Squall": the names of the known cards, in order.
function Cards.names(ids: { string }): string
	local names: { string } = {}
	for _, id in ids do
		local info = Cards.info(id)
		if info ~= nil then
			table.insert(names, info.name)
		end
	end
	return table.concat(names, ", ")
end

return Cards
