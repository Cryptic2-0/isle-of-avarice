--!strict
local Types = require("../Types")

type PathId = Types.PathId

local order: { PathId } = { "Fang", "Gale", "Ember", "Mire", "Mend", "Bulwark" }

local info: { [PathId]: { name: string, style: string, color: { r: number, g: number, b: number } } } =
	{
		Fang = {
			name = "Fang",
			style = "Close-range burst damage",
			color = { r = 200, g = 50, b = 50 },
		},
		Gale = { name = "Gale", style = "Speed and evasion", color = { r = 120, g = 210, b = 230 } },
		Ember = {
			name = "Ember",
			style = "Ranged and area damage",
			color = { r = 240, g = 140, b = 40 },
		},
		Mire = { name = "Mire", style = "Control", color = { r = 100, g = 140, b = 60 } },
		Mend = {
			name = "Mend",
			style = "Healing and support",
			color = { r = 240, g = 230, b = 150 },
		},
		Bulwark = {
			name = "Bulwark",
			style = "Defence and counter",
			color = { r = 90, g = 100, b = 180 },
		},
	}

local function isPath(value: any): boolean
	if type(value) ~= "string" then
		return false
	end
	for _, path in order do
		if path == value then
			return true
		end
	end
	return false
end

return {
	order = order,
	info = info,
	isPath = isPath,
}
