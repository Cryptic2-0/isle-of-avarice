--!strict
-- Who is paid when a creature is defeated, which Path gets the XP, and which Relics drop.
local Paths = require("../Catalog/Paths")
local Scarcity = require("./Scarcity")
local Types = require("../Types")

-- Damage dealt to one creature, per attacker. Key: tostring(attacker id). lastAt is the last hit
-- or assist; hitAt is the last real hit only (nil for a helper who never hit).
export type Tally = {
	[string]: {
		lastAt: number,
		hitAt: number?,
		total: number,
		byPath: { [string]: number },
		assist: string?,
	},
}
-- room: free slots the player can still fill (0 when their Ledger is locked).
export type Recipient = { calling: string, room: number }
export type Award = {
	userId: number,
	coin: number,
	xpPath: string,
	xp: number,
	relics: { string },
	sealed: { string },
	lost: { string },
}
export type Reward = { coin: number, xp: number, drops: { Types.Drop } }

local Rewards = {}

Rewards.CONTRIBUTOR_SECONDS = 30
Rewards.STRIKE = "Strike"

-- Adds one hit. An amount that is not a positive finite number changes nothing.
function Rewards.record(
	tally: Tally,
	attackerId: number,
	path: string,
	amount: number,
	now: number
): Tally
	if not (amount > 0 and amount < math.huge) then
		return tally
	end
	local key = tostring(attackerId)
	local old = tally[key]
	local byPath = if old ~= nil then table.clone(old.byPath) else {}
	byPath[path] = (byPath[path] or 0) + amount
	local out = table.clone(tally)
	out[key] = {
		lastAt = now,
		hitAt = now,
		total = (if old ~= nil then old.total else 0) + amount,
		byPath = byPath,
	}
	return out
end

-- Support that reaches someone who hit the creature in the last 30 seconds makes the helper a
-- contributor too, with no damage. An assist never sets or changes hitAt. Anything else (self, no contributor reached, not a Path, NaN time) changes nothing.
function Rewards.assist(
	tally: Tally,
	helperId: number,
	helpedIds: { number },
	path: string,
	now: number
): Tally
	if not Paths.isPath(path) then
		return tally
	end
	local reached = false
	for _, id in helpedIds do
		local entry = tally[tostring(id)]
		-- Written positively so a NaN time helps nobody.
		if
			id ~= helperId
			and entry ~= nil
			and entry.hitAt ~= nil
			and now - entry.hitAt <= Rewards.CONTRIBUTOR_SECONDS
		then
			reached = true
			break
		end
	end
	if not reached then
		return tally
	end
	local key = tostring(helperId)
	local old = tally[key]
	local out = table.clone(tally)
	out[key] = {
		lastAt = now,
		hitAt = if old ~= nil then old.hitAt else nil,
		total = if old ~= nil then old.total else 0,
		byPath = if old ~= nil then table.clone(old.byPath) else {},
		assist = path,
	}
	return out
end

-- Everyone who hit within the last 30 seconds: most damage first, ties to the lower id.
function Rewards.contributors(tally: Tally, now: number): { number }
	local rows: { { id: number, total: number } } = {}
	for key, entry in tally do
		local id = tonumber(key)
		-- Written positively so a NaN time makes nobody a contributor.
		if id ~= nil and now - entry.lastAt <= Rewards.CONTRIBUTOR_SECONDS then
			table.insert(rows, { id = id, total = entry.total })
		end
	end
	table.sort(rows, function(a, b)
		if a.total ~= b.total then
			return a.total > b.total
		end
		return a.id < b.id
	end)
	local ids: { number } = {}
	for _, row in rows do
		table.insert(ids, row.id)
	end
	return ids
end

-- The Path the XP goes to: the one that dealt the most damage. The Strike counts as the
-- Calling; a tie with the Calling goes to the Calling, other ties to the earlier Path of the
-- hexagon. "" without a Calling. Keys that are not Paths are ignored.
function Rewards.xpPath(byPath: { [string]: number }, calling: string): string
	if calling == "" then
		return ""
	end
	local best, bestDamage = calling, -1
	for _, path in Paths.order do
		local damage = byPath[path] or 0
		if path == calling then
			damage += byPath[Rewards.STRIKE] or 0
		end
		if damage > bestDamage or (damage == bestDamage and path == calling) then
			best, bestDamage = path, damage
		end
	end
	return best
end

-- One Award per contributor found in `recipients`, in contributors() order (by damage, so an
-- assist-only contributor is served last). Each contributor rolls every drop once, in drop
-- order; a roll below the chance wins. A won Relic is sealed when the server already holds
-- its cap (`held` plus the copies given earlier in this call), else lost when the contributor
-- has no room left, else given.
function Rewards.awards(
	reward: Reward,
	tally: Tally,
	recipients: { [string]: Recipient },
	held: { [string]: number },
	now: number,
	rng: () -> number
): { Award }
	local given: { [string]: number } = {}
	local awards: { Award } = {}
	for _, id in Rewards.contributors(tally, now) do
		local recipient = recipients[tostring(id)]
		if recipient == nil then
			continue
		end
		local entry = tally[tostring(id)]
		local xpPath
		if entry.total == 0 and entry.assist ~= nil then
			-- Support only: paid in the Path of the support, but never without a Calling.
			xpPath = if recipient.calling == "" then "" else entry.assist
		else
			xpPath = Rewards.xpPath(entry.byPath, recipient.calling)
		end
		local award: Award = {
			userId = id,
			coin = reward.coin,
			xpPath = xpPath,
			xp = if xpPath == "" then 0 else reward.xp,
			relics = {},
			sealed = {},
			lost = {},
		}
		for _, drop in reward.drops do
			if rng() < drop.chance then
				local relicId = drop.relicId
				local copies = (held[relicId] or 0) + (given[relicId] or 0)
				if Scarcity.isSealed(relicId, copies) then
					table.insert(award.sealed, relicId)
				elseif #award.relics >= recipient.room then
					table.insert(award.lost, relicId)
				else
					table.insert(award.relics, relicId)
					given[relicId] = (given[relicId] or 0) + 1
				end
			end
		end
		table.insert(awards, award)
	end
	return awards
end

return Rewards
