--!strict
-- Status lines for the HUD. Pure: the client renders this and nothing else.

export type Line =
	{ text: string, kind: "region" | "safe" | "shield" | "marked" | "veil" | "hazard" }
export type Status = { newShield: boolean, respawnShieldSeconds: number, markedSeconds: number }

local StatusView = {}

-- Written so NaN and negative values read as "not running".
local function running(seconds: number): boolean
	return seconds > 0 and seconds < math.huge
end

-- The region comes first, then safe zone and status effects, then the hazards in effect.
-- Without a place there are no region or hazard lines.
function StatusView.build(
	status: Status?,
	inSafeZone: boolean,
	place: { name: string, hazards: { string } }?,
	veilSeconds: number?
): { Line }
	local lines: { Line } = {}
	if place ~= nil then
		table.insert(lines, { text = place.name, kind = "region" })
	end
	if inSafeZone then
		table.insert(lines, { text = "Safe zone", kind = "safe" })
	end
	if status ~= nil then
		if status.newShield then
			table.insert(lines, { text = "New-player shield", kind = "shield" })
		end
		if running(status.respawnShieldSeconds) then
			local seconds = math.ceil(status.respawnShieldSeconds)
			table.insert(lines, { text = `Respawn shield: {seconds}s`, kind = "shield" })
		end
		if running(status.markedSeconds) then
			local total = math.ceil(status.markedSeconds)
			local text = string.format("MARKED %d:%02d", total // 60, total % 60)
			table.insert(lines, { text = text, kind = "marked" })
		end
	end
	-- The Veil is an Edict effect, not part of the status, so it has its own input.
	if veilSeconds ~= nil and running(veilSeconds) then
		local total = math.ceil(veilSeconds)
		local text = string.format("Veiled %d:%02d", total // 60, total % 60)
		table.insert(lines, { text = text, kind = "veil" })
	end
	if place ~= nil then
		for _, name in place.hazards do
			table.insert(lines, { text = name, kind = "hazard" })
		end
	end
	return lines
end

-- Which kinds survive a short column first: marked and hazards, then the Veil and shields, then
-- the safe zone; the region goes first (the banner already names it).
local KEEP_RANK = { marked = 6, hazard = 5, veil = 4, shield = 3, safe = 2, region = 1 }

-- At most `count` lines, the most urgent kept and the order unchanged.
function StatusView.fit(lines: { Line }, count: number): { Line }
	if #lines <= count then
		return table.clone(lines)
	end
	local order: { number } = {}
	for index in lines do
		table.insert(order, index)
	end
	table.sort(order, function(a: number, b: number): boolean
		local rankA, rankB = KEEP_RANK[lines[a].kind], KEEP_RANK[lines[b].kind]
		if rankA ~= rankB then
			return rankA > rankB
		end
		return a < b
	end)
	local kept: { number } = {}
	for i = 1, math.max(0, count) do
		table.insert(kept, order[i])
	end
	table.sort(kept)
	local result: { Line } = {}
	for _, index in kept do
		table.insert(result, lines[index])
	end
	return result
end

return StatusView
