--!strict
local Ledger = require("./Ledger")
local Relics = require("../Catalog/Relics")
local Types = require("../Types")

type CardId = Types.CardId
type Tier = Types.Tier
type Ledger = Types.Ledger

export type SlotView = {
	slot: number,
	label: string,
	cardId: CardId,
	name: string,
	tier: Tier,
	claimed: boolean,
	spares: number,
}
export type FreeView = { index: number, cardId: CardId, name: string, tier: Tier, canClaim: boolean }
export type View = {
	progressText: string,
	freeText: string,
	complete: boolean,
	slots: { SlotView },
	free: { FreeView },
}

local LedgerView = {}

-- Turns a Ledger into display data. Pure: the client renders this and nothing else.
function LedgerView.build(ledger: Ledger): View
	local spares: { [CardId]: number } = {}
	for _, cardId in ledger.free do
		spares[cardId] = (spares[cardId] or 0) + 1
	end

	local slots: { SlotView } = {}
	for _, relic in Relics.list do
		table.insert(slots, {
			slot = relic.slot,
			label = string.format("%03d", relic.slot),
			cardId = relic.id,
			name = relic.name,
			tier = relic.tier,
			claimed = ledger.claimed[relic.id] == true,
			spares = spares[relic.id] or 0,
		})
	end

	local free: { FreeView } = {}
	for index, cardId in ledger.free do
		local relic = Relics.byId[cardId]
		if relic ~= nil then
			table.insert(free, {
				index = index,
				cardId = cardId,
				name = relic.name,
				tier = relic.tier,
				canClaim = ledger.claimed[cardId] ~= true,
			})
		end
	end

	return {
		progressText = `{Ledger.claimedCount(ledger)} / {Relics.count}`,
		freeText = `{#ledger.free} / {Ledger.FREE_SLOTS}`,
		complete = Ledger.isComplete(ledger),
		slots = slots,
		free = free,
	}
end

return LedgerView
