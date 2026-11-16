--!strict
-- Keep modal windows inside the ScreenGui's inset-adjusted canvas.
local DialogLayout = {}

export type Placement = { object: GuiObject, position: UDim2, size: UDim2, parent: GuiObject? }

local EDGE = 8

function DialogLayout.bind(gui: ScreenGui, frame: Frame, minimum: Vector2, compact: { Placement }?)
	local preferred = frame.Size
	local desktop: { Placement } = {}
	for _, placement in compact or {} do
		local object = placement.object
		table.insert(desktop, {
			object = object,
			position = object.Position,
			size = object.Size,
			parent = if placement.parent then object.Parent :: GuiObject else nil,
		})
	end

	local wasCompact = false
	local function fit()
		local canvas = gui.AbsoluteSize
		if canvas.X <= 0 or canvas.Y <= 0 then
			return
		end
		local preferredWidth = canvas.X * preferred.X.Scale
		local preferredHeight = canvas.Y * preferred.Y.Scale
		local width =
			math.max(1, math.min(math.max(preferredWidth, minimum.X), canvas.X - 2 * EDGE))
		local height =
			math.max(1, math.min(math.max(preferredHeight, minimum.Y), canvas.Y - 2 * EDGE))
		frame.Size = if width == preferredWidth and height == preferredHeight
			then preferred
			else UDim2.fromOffset(width, height)

		local isCompact = compact ~= nil and (width < 600 or height < 420)
		if isCompact == wasCompact then
			return
		end
		wasCompact = isCompact
		for _, placement in (if isCompact then compact else desktop) or {} do
			placement.object.Position = placement.position
			placement.object.Size = placement.size
			if placement.parent then
				placement.object.Parent = placement.parent
			end
		end
	end

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
end

return DialogLayout
