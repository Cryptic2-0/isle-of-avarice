--!strict
local BlindClaim = require("./BlindClaim")
local Relics = require("../Catalog/Relics")
local Types = require("../Types")

type Tier = Types.Tier

export type SlotView = {
	slot: number,
	label: string,
	name: string,
	tier: Tier,
	state: "open" | "taken" | "miss" | "locked",
}
export type View = {
	title: string,
	picksText: string,
	secondsLeft: number,
	open: boolean,
	slots: { SlotView },
}

local ClaimView = {}

-- Turns a claim into display data. Pure: slot contents stay hidden, only outcomes show.
function ClaimView.build(victimName: string, claim: BlindClaim.Claim, now: number): View
	local open = BlindClaim.isOpen(claim, now)
	local slots: { SlotView } = {}
	for _, relic in Relics.list do
		local outcome = claim.picked[tostring(relic.slot)]
		local state: "open" | "taken" | "miss" | "locked"
		if outcome == "TAKEN" then
			state = "taken"
		elseif outcome == "MISS" then
			state = "miss"
		elseif
			not open
			or (claim.taken[relic.tier] or 0) >= (BlindClaim.TIER_LIMIT[relic.tier] or 0)
		then
			state = "locked"
		else
			state = "open"
		end
		table.insert(slots, {
			slot = relic.slot,
			label = string.format("%03d", relic.slot),
			name = relic.name,
			tier = relic.tier,
			state = state,
		})
	end
	return {
		title = `Claim on {victimName}`,
		picksText = `Picks left: {claim.picksLeft}`,
		secondsLeft = math.max(0, math.ceil(claim.expiresAt - now)),
		open = open,
		slots = slots,
	}
end

return ClaimView
