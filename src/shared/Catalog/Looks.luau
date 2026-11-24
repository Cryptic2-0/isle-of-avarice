--!strict
export type Look = { r: number, g: number, b: number, material: string, transparency: number }

-- material is the name of an Enum.Material item.
local function look(r: number, g: number, b: number, material: string, transparency: number?): Look
	return { r = r, g = g, b = b, material = material, transparency = transparency or 0 }
end

local byName: { [string]: Look } = {
	grass = look(86, 140, 60, "Grass"),
	thorngrass = look(52, 92, 48, "Grass"),
	slate = look(128, 136, 148, "Slate"),
	ash = look(58, 52, 50, "Basalt"),
	mud = look(84, 92, 62, "Mud"),
	shale = look(96, 104, 112, "Slate"),
	palegrass = look(150, 160, 120, "Grass"),
	gravel = look(140, 132, 120, "Pebble"),
	hedge = look(38, 84, 42, "Grass"),
	pillar = look(150, 156, 168, "Slate"),
	wall = look(120, 112, 104, "Brick"),
	roof = look(96, 84, 72, "WoodPlanks"),
	wood = look(139, 100, 60, "WoodPlanks"),
	road = look(150, 146, 140, "Cobblestone"),
	sign = look(139, 100, 60, "Wood"),
	rock = look(110, 110, 112, "Slate"),
	trunk = look(92, 64, 40, "Wood"),
	leaf = look(60, 120, 50, "Grass"),
	deadwood = look(120, 110, 100, "Wood"),
	basalt = look(40, 38, 42, "Basalt"),
	rubble = look(130, 124, 116, "Slate"),
	flower = look(200, 150, 200, "Grass"),
	reed = look(120, 130, 70, "Grass"),
	briar = look(70, 48, 60, "Grass", 0.2),
	lava = look(255, 110, 20, "Neon", 0.1),
	vent = look(255, 170, 60, "Neon", 0.6),
	bog = look(60, 70, 40, "Mud", 0.2),
	tide = look(60, 120, 200, "Glass", 0.5),
	spring = look(90, 200, 255, "Neon", 0.4),
	gust = look(220, 240, 255, "Neon", 0.85),
	rockfall = look(255, 90, 60, "Neon", 0.7),
	none = look(0, 0, 0, "SmoothPlastic", 1),
}

return {
	byName = byName,
}
