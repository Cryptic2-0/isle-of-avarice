--!strict
local Types = require("../Types")

type Tier = Types.Tier

export type TierInfo = {
	serverCap: number?,
	cacheRespawnSeconds: number,
	color: { r: number, g: number, b: number },
}

local order: { Tier } = { "Copper", "Silver", "Gold", "Platinum", "Crown" }

local info: { [Tier]: TierInfo } = {
	Copper = { serverCap = nil, cacheRespawnSeconds = 30, color = { r = 184, g = 115, b = 51 } },
	Silver = { serverCap = 8, cacheRespawnSeconds = 120, color = { r = 192, g = 192, b = 192 } },
	Gold = { serverCap = 4, cacheRespawnSeconds = 300, color = { r = 255, g = 200, b = 40 } },
	Platinum = { serverCap = 2, cacheRespawnSeconds = 600, color = { r = 210, g = 230, b = 235 } },
	Crown = { serverCap = 1, cacheRespawnSeconds = 900, color = { r = 150, g = 60, b = 200 } },
}

return {
	order = order,
	info = info,
}
