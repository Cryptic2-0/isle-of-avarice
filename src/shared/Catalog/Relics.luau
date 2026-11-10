--!strict
local Types = require("../Types")

type Relic = Types.Relic

local list: { Relic } = {
	{
		id = "R001",
		slot = 1,
		name = "Tarnished Tally-Coin",
		tier = "Copper",
		description = "The Hoarder's first earning, rubbed dull by a lifetime of being counted.",
	},
	{
		id = "R002",
		slot = 2,
		name = "Dockhand's Knot",
		tier = "Copper",
		description = "A knot the Hoarder never untied, kept in case the debt came due.",
	},
	{
		id = "R003",
		slot = 3,
		name = "Gull-Feather Quill",
		tier = "Copper",
		description = "Every entry in the Hoarder's accounts was written with this scratchy plume.",
	},
	{
		id = "R004",
		slot = 4,
		name = "Salt-Cracked Lantern",
		tier = "Copper",
		description = "The Hoarder counted coins by its light long after the oil ran out.",
	},
	{
		id = "R005",
		slot = 5,
		name = "Moneylender's Scale",
		tier = "Copper",
		description = "One pan hangs lower than the other, and the Hoarder never fixed it.",
	},
	{
		id = "R006",
		slot = 6,
		name = "Barnacle Key",
		tier = "Copper",
		description = "It opens nothing on the isle now, yet the Hoarder refused to throw it back.",
	},
	{
		id = "R007",
		slot = 7,
		name = "Bottled Squall",
		tier = "Silver",
		description = "A small storm corked tight, saved for the day a rival's ship sailed too close.",
	},
	{
		id = "R008",
		slot = 8,
		name = "Ledger-Moth Wing",
		tier = "Silver",
		description = "Pale and papery, it came from the creature that ate the Hoarder's oldest debts.",
	},
	{
		id = "R009",
		slot = 9,
		name = "Debt-Collector's Bell",
		tier = "Silver",
		description = "The Hoarder rang it at every door, and no one ever answered kindly.",
	},
	{
		id = "R010",
		slot = 10,
		name = "Gilded Anchor Link",
		tier = "Gold",
		description = "One golden link from the chain that kept the Hoarder's fortune from drifting away.",
	},
	{
		id = "R011",
		slot = 11,
		name = "Weeping Strongbox",
		tier = "Gold",
		description = "It drips seawater from every seam, as if mourning what it was made to hold.",
	},
	{
		id = "R012",
		slot = 12,
		name = "The Hoarder's Thumbprint",
		tier = "Platinum",
		description = "A single pressed mark in solid platinum, the Hoarder's seal on everything they owned.",
	},
}

local byId: { [Types.CardId]: Relic } = {}
for _, relic in list do
	byId[relic.id] = relic
end

return {
	list = list,
	byId = byId,
	count = #list,
}
