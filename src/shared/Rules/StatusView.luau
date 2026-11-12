--!strict
-- Status lines for the HUD. Pure: the client renders this and nothing else.

export type Line = { text: string, kind: "region" | "safe" | "shield" | "marked" | "hazard" }
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
	place: { name: string, hazards: { string } }?
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
	if place ~= nil then
		for _, name in place.hazards do
			table.insert(lines, { text = name, kind = "hazard" })
		end
	end
	return lines
end

return StatusView
