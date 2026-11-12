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
	{
		id = "R013",
		slot = 13,
		name = "Low-Tide Tally Stick",
		tier = "Silver",
		description = "Notched at every low tide, when the Hoarder walked the shore counting what the sea gave back.",
	},
	{
		id = "R014",
		slot = 14,
		name = "Gull-Perch Spyglass",
		tier = "Silver",
		description = "From the cliff tops the Hoarder watched every ship that still owed them money.",
	},
	{
		id = "R015",
		slot = 15,
		name = "Unopened Salt Letter",
		tier = "Silver",
		description = "A demand for payment, sealed in salt wax and never delivered until now.",
	},
	{
		id = "R016",
		slot = 16,
		name = "Brinehound Collar",
		tier = "Silver",
		description = "Brass-studded and far too heavy for a pet; the Hoarder's hounds wore it to collect debts.",
	},
	{
		id = "R017",
		slot = 17,
		name = "Rook's-Nest Purse",
		tier = "Silver",
		description = "Stuffed with coins and hidden where only the gulls could reach it.",
	},
	{
		id = "R018",
		slot = 18,
		name = "Cliffside Tithe Box",
		tier = "Silver",
		description = "Fishers paid their dues into it, and the climb kept thieves away.",
	},
	{
		id = "R019",
		slot = 19,
		name = "Brine-Fang Charm",
		tier = "Gold",
		description = "A hound's tooth set in gold, worn by the Hoarder's chief collector.",
	},
	{
		id = "R020",
		slot = 20,
		name = "Gilded Carapace Plate",
		tier = "Gold",
		description = "The Hoarder had their shellbacks gilded, so even the beasts would be worth something.",
	},
	{
		id = "R021",
		slot = 21,
		name = "Bog Pearl",
		tier = "Gold",
		description = "Spat up from the mud, it shines like interest on a loan nobody repaid.",
	},
	{
		id = "R022",
		slot = 22,
		name = "Colossus Heartstone",
		tier = "Gold",
		description = "The ballast that kept the Brine Colossus bound to the Hoarder's will.",
	},
	{
		id = "R023",
		slot = 23,
		name = "Drowned Treasury Key",
		tier = "Gold",
		description = "It opens the sea vault where the Hoarder kept what they could not count.",
	},
	{
		id = "R024",
		slot = 24,
		name = "Shellbreaker's Mallet",
		tier = "Gold",
		description = "Bought to crack shellbacks open, and billed to their owners afterwards.",
	},
	{
		id = "R025",
		slot = 25,
		name = "Tallyman's Abacus",
		tier = "Gold",
		description = "The Drowned Tallyman still counts on it, though every bead is a debt unpaid.",
	},
	{
		id = "R026",
		slot = 26,
		name = "Lookout's Gilded Horn",
		tier = "Gold",
		description = "Blown from the island's peak whenever a debtor tried to sail away.",
	},
	{
		id = "R027",
		slot = 27,
		name = "Writ of the Unpaid Debt",
		tier = "Platinum",
		description = "The Hoarder's last demand, signed in platinum ink and finally settled.",
	},
	{
		id = "R028",
		slot = 28,
		name = "Chipped Salt Cellar",
		tier = "Copper",
		description = "The Hoarder salted every meal to make it last, and charged guests for the pinch.",
	},
	{
		id = "R029",
		slot = 29,
		name = "Rusted Debtor's Link",
		tier = "Copper",
		description = "One link from the chain that kept small debtors working the docks.",
	},
	{
		id = "R030",
		slot = 30,
		name = "Waterlogged IOU",
		tier = "Copper",
		description = "The ink has run, but the Hoarder still expects it paid.",
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
