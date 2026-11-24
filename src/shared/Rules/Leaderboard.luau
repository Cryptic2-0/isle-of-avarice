--!strict
-- The all-time board of the Crowned: parsing stored rows, merging them with this server's players,
-- and the text shown. Pure. Every check is written so that NaN refuses.
local Crown = require("./Crown")

export type Entry = { userId: number, crowns: number }
export type View = { title: string, subtitle: string, rows: { string } }

local Leaderboard = {}

Leaderboard.ROWS = 10
Leaderboard.REFRESH_SECONDS = 120
Leaderboard.RETRY_SECONDS = 60

local function isWhole(n: any): boolean
	return type(n) == "number" and n > -math.huge and n < math.huge and n == math.floor(n)
end

-- Turns the store's page into entries. Keeps only well-formed rows, never errors.
function Leaderboard.fromPage(raw: any): { Entry }
	local out: { Entry } = {}
	if type(raw) ~= "table" then
		return out
	end
	for _, item in raw :: { any } do
		if #out >= Leaderboard.ROWS then
			break
		end
		if type(item) ~= "table" then
			continue
		end
		local key, value = item.key, item.value
		if type(key) ~= "string" or #key > 19 or string.match(key, "^%d+$") == nil then
			continue
		end
		local userId = tonumber(key)
		if userId == nil or not (userId >= 1) then
			continue
		end
		if not isWhole(value) or not (value >= 1 and value <= Crown.MAX) then
			continue
		end
		table.insert(out, { userId = userId, crowns = value })
	end
	return out
end

-- One entry per player with the higher count, best first, ties to the lower id.
function Leaderboard.merge(stored: { Entry }, live: { Entry }): { Entry }
	local best: { [number]: number } = {}
	for _, list in { stored, live } do
		for _, entry in list do
			if entry.crowns >= 1 then
				local old = best[entry.userId]
				if old == nil or entry.crowns > old then
					best[entry.userId] = entry.crowns
				end
			end
		end
	end
	local out: { Entry } = {}
	for userId, crowns in best do
		table.insert(out, { userId = userId, crowns = crowns })
	end
	table.sort(out, function(a, b)
		if a.crowns ~= b.crowns then
			return a.crowns > b.crowns
		end
		return a.userId < b.userId
	end)
	while #out > Leaderboard.ROWS do
		table.remove(out)
	end
	return out
end

function Leaderboard.view(entries: { Entry }, names: { [string]: string }, online: boolean): View
	local rows: { string } = {}
	for rank, entry in entries do
		local name = names[tostring(entry.userId)] or `Claimant {entry.userId}`
		table.insert(rows, `{rank}. {name}: {Crown.title(entry.crowns, 0)}`)
	end
	if #rows == 0 then
		rows = { "Nobody has been Crowned yet." }
	end
	return {
		title = "The Crowned",
		subtitle = if online
			then "All time, every server"
			else "This server only: the all-time records cannot be reached",
		rows = rows,
	}
end

-- Write only a higher count, and not within a minute of a failed write.
function Leaderboard.shouldWrite(
	crowns: number,
	boardCrowns: number,
	lastFailAt: number?,
	now: number
): boolean
	if not (crowns > boardCrowns) then
		return false
	end
	return lastFailAt == nil or now - lastFailAt >= Leaderboard.RETRY_SECONDS
end

-- UpdateAsync's transform: a write never lowers the stored count.
function Leaderboard.keep(old: any, crowns: number): number
	if isWhole(old) and old >= 0 and old <= Crown.MAX then
		return math.max(old, crowns)
	end
	return crowns
end

return Leaderboard
