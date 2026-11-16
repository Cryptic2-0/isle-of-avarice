--!strict
-- The Hoarder's old laws: single-use cards kept in free slots (spec 3.6 and 3.13).
local Types = require("../Types")

type Edict = Types.Edict

-- `weight`: the chance, in percent, that one card of a pack is this Edict.
-- `needs`: what the player must name to use it: a "relic", a "player", or "" for nothing.
local list: { Edict } = {
	{
		id = "E001",
		key = "summons",
		name = "Summons",
		description = "Name a Relic and see who on this server holds it.",
		weight = 25,
		needs = "relic",
	},
	{
		id = "E002",
		key = "audit",
		name = "Audit",
		description = "Look inside the Ledger of the nearest player within 20 studs.",
		weight = 20,
		needs = "",
	},
	{
		id = "E003",
		key = "veil",
		name = "Veil",
		description = "Hide from Summons and Audit for 10 minutes.",
		weight = 20,
		needs = "",
	},
	{
		id = "E004",
		key = "passage",
		name = "Passage",
		description = "Appear beside a player you have met this session.",
		weight = 15,
		needs = "player",
	},
	{
		id = "E005",
		key = "homecoming",
		name = "Homecoming",
		description = "Appear in Tallyport.",
		weight = 20,
		needs = "",
	},
}

local byId: { [string]: Edict } = {}
local byKey: { [string]: Edict } = {}
for _, edict in list do
	byId[edict.id] = edict
	byKey[edict.key] = edict
end

return {
	list = list,
	byId = byId,
	byKey = byKey,
}
