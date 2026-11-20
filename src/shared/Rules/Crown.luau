--!strict
-- The Crown (spec 3.15): one per run for a complete Ledger, the saved record, the title and
-- the lines shown for it. Pure. Every check is written so that NaN refuses.
local Ledger = require("./Ledger")
local Types = require("../Types")

type CrownRecord = Types.CrownRecord
type Ledger = Types.Ledger

local Crown = {}

Crown.MAX = 1000000
Crown.MAX_GEMS = 6
Crown.RENOUNCE_HINT = "You may Renounce at the Tally Stone in Tallyport."

local function isWhole(n: any): boolean
	return type(n) == "number" and n > -math.huge and n < math.huge and n == math.floor(n)
end

function Crown.newRecord(): CrownRecord
	return { crowns = 0, stars = 0, boardCrowns = 0, badgeAwarded = false }
end

-- Turns arbitrary saved data into a valid record. Never errors. A damaged star count reads
-- as "Crowned this run" (crowns - 1) so a bad save can never hand out a free Crown.
function Crown.sanitize(raw: any): CrownRecord
	if type(raw) ~= "table" then
		return Crown.newRecord()
	end
	local crowns = 0
	if isWhole(raw.crowns) and raw.crowns >= 0 and raw.crowns <= Crown.MAX then
		crowns = raw.crowns
	end
	local low = math.max(0, crowns - 1)
	local stars = low
	if isWhole(raw.stars) then
		stars = math.clamp(raw.stars, low, crowns)
	end
	local boardCrowns = 0
	if isWhole(raw.boardCrowns) then
		boardCrowns = math.clamp(raw.boardCrowns, 0, crowns)
	end
	return {
		crowns = crowns,
		stars = stars,
		boardCrowns = boardCrowns,
		badgeAwarded = raw.badgeAwarded == true,
	}
end

function Crown.crownedThisRun(record: CrownRecord): boolean
	return record.crowns > record.stars
end

function Crown.canCrown(record: CrownRecord, ledger: Ledger): boolean
	return Ledger.isComplete(ledger) and record.crowns == record.stars and record.crowns < Crown.MAX
end

-- Only the record is known here, so the Ledger check stays with canCrown; this adds the
-- Crown when this run has not yet given one.
function Crown.crown(record: CrownRecord): CrownRecord
	local out = table.clone(record)
	if record.crowns == record.stars and record.crowns < Crown.MAX then
		out.crowns = record.crowns + 1
	end
	return out
end

function Crown.title(crowns: any, stars: any): string
	if not isWhole(crowns) or crowns < 1 or crowns > Crown.MAX then
		return ""
	end
	local text = "Crowned"
	if crowns == 2 then
		text = "Crowned twice"
	elseif crowns > 2 then
		text = `Crowned {crowns} times`
	end
	if isWhole(stars) and stars >= 1 then
		text ..= ` ★{math.min(stars, crowns)}`
	end
	return text
end

function Crown.bookLine(crowns: any, stars: any, complete: boolean): string
	local title = Crown.title(crowns, stars)
	if title ~= "" and complete and isWhole(stars) and crowns > stars then
		return title .. ". " .. Crown.RENOUNCE_HINT
	end
	return title
end

function Crown.ceremonyLines(name: string, crowns: any): { string }
	local first = `{name} is Crowned!`
	if isWhole(crowns) and crowns >= 2 then
		first = `{name} is Crowned again: {crowns} Crowns!`
	end
	return { first, "Every Relic of the Ledger is claimed." }
end

function Crown.gems(stars: any): number
	if isWhole(stars) then
		return math.clamp(stars, 0, Crown.MAX_GEMS)
	end
	return 0
end

function Crown.wantsBadge(record: CrownRecord, badgeId: any): boolean
	return isWhole(badgeId) and badgeId >= 1 and record.crowns >= 1 and not record.badgeAwarded
end

return Crown
