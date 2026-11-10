--!strict
-- One message at the top of the screen. A new message replaces the old one.
local SHOW_SECONDS = 3

local Toast = {}

local label: TextLabel? = nil
local generation = 0

function Toast.mount(playerGui: PlayerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ToastGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20

	local text = Instance.new("TextLabel")
	text.Name = "Message"
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = UDim2.fromScale(0.5, 0.04)
	text.Size = UDim2.fromScale(0.6, 0.07)
	text.BackgroundColor3 = Color3.fromRGB(25, 22, 30)
	text.BackgroundTransparency = 0.15
	text.TextColor3 = Color3.fromRGB(245, 235, 210)
	text.TextScaled = true
	text.Font = Enum.Font.GothamMedium
	text.Text = ""
	text.Visible = false

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = text
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = text
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 12
	constraint.MaxTextSize = 28
	constraint.Parent = text

	text.Parent = gui
	label = text
	gui.Parent = playerGui
end

function Toast.show(text: string)
	local current = label
	if current == nil then
		return
	end
	generation += 1
	local mine = generation
	current.Text = text
	current.Visible = true
	task.delay(SHOW_SECONDS, function()
		-- A newer message owns the label now.
		if generation == mine then
			current.Visible = false
		end
	end)
end

return Toast
