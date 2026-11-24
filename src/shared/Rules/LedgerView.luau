--!strict
local Ledger = require("./Ledger")
local Relics = require("../Catalog/Relics")
local Vault = require("./Vault")
local Types = require("../Types")

type CardId = Types.CardId
type Tier = Types.Tier
type Ledger = Types.Ledger
type Vault = Types.Vault

export type SlotView = {
	slot: number,
	label: string,
	cardId: CardId,
	name: string,
	tier: Tier,
	claimed: boolean,
	spares: number,
	vaulted: boolean,
	canVault: boolean,
}
export type FreeView =
	{ index: number, cardId: CardId, name: string, tier: Tier, canClaim: boolean }
export type View = {
	progressText: string,
	freeText: string,
	vaultText: string,
	complete: boolean,
	slots: { SlotView },
	free: { FreeView },
}

local LedgerView = {}

-- Turns a Ledger into display data. Pure: the client renders this and nothing else.
function LedgerView.build(ledger: Ledger, vault: Vault?): View
	local vaulted: Vault = vault or {}
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
			vaulted = vaulted[relic.id] == true,
			canVault = Ledger.count(ledger, relic.id) > 0
				and relic.tier ~= "Crown"
				and vaulted[relic.id] ~= true,
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
		vaultText = `{Vault.size(vaulted)} / {Vault.MAX}`,
		complete = Ledger.isComplete(ledger),
		slots = slots,
		free = free,
	}
end

return LedgerView
