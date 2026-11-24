--!strict
local Ledger = require("./Ledger")
local Relics = require("../Catalog/Relics")
local Tiers = require("../Catalog/Tiers")
local Types = require("../Types")

type CardId = Types.CardId
type Ledger = Types.Ledger

local Scarcity = {}

-- Copies of one Relic held across the given ledgers, claimed and spare alike.
function Scarcity.countHeld(ledgers: { Ledger }, relicId: CardId): number
	local total = 0
	for _, ledger in ledgers do
		total += Ledger.count(ledger, relicId)
	end
	return total
end

-- A cache is sealed once the server holds as many copies as the tier cap.
-- Tiers without a cap, and unknown ids, are never sealed.
function Scarcity.isSealed(relicId: CardId, held: number): boolean
	local relic = Relics.byId[relicId]
	if relic == nil then
		return false
	end
	local cap = Tiers.info[relic.tier].serverCap
	return cap ~= nil and held >= cap
end

return Scarcity
