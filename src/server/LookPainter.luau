--!strict
-- Paints a part from a named look in the Looks catalog.
--   LookPainter.paint(part, look)
--       Sets the part's colour, material and transparency. A look the catalog does not have,
--       or one whose material is not an Enum.Material item, paints opaque grey SmoothPlastic
--       instead, so a typo shows on the island rather than breaking the build.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Looks = require(ReplicatedStorage.Shared.Catalog.Looks)

local FALLBACK_COLOR = Color3.fromRGB(128, 128, 128)

local LookPainter = {}

-- The Enum.Material item with this name, or nil. Indexing an Enum with a name it does not
-- have raises, and a name such as "GetEnumItems" finds a method, so both are screened out.
local function materialNamed(name: string): Enum.Material?
	local ok, item = pcall(function(): any
		return (Enum.Material :: any)[name]
	end)
	if ok and typeof(item) == "EnumItem" and item.EnumType == Enum.Material then
		return item
	end
	return nil
end

function LookPainter.paint(part: BasePart, look: string)
	local spec = Looks.byName[look]
	if spec ~= nil then
		local material = materialNamed(spec.material)
		if material ~= nil then
			part.Color = Color3.fromRGB(spec.r, spec.g, spec.b)
			part.Material = material
			part.Transparency = spec.transparency
			return
		end
	end
	part.Color = FALLBACK_COLOR
	part.Material = Enum.Material.SmoothPlastic
	part.Transparency = 0
end

return LookPainter
