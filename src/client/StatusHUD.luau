--!strict
-- Top-left status lines (region, safe zone, shields, Marked, hazards) and the "Drop shield" button.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatusView = require(Shared:WaitForChild("Rules"):WaitForChild("StatusView"))

local StatusHUD = {}

local TEXT_LIGHT = Color3.fromRGB(245, 235, 210)
local BACKGROUND = Color3.fromRGB(25, 22, 30)
local BUTTON_COLOR = Color3.fromRGB(70, 60, 90)
local KIND_COLORS: { [string]: Color3 } = {
	region = Color3.fromRGB(245, 235, 210),
	hazard = Color3.fromRGB(255, 170, 60),
	safe = Color3.fromRGB(90, 200, 110),
	shield = Color3.fromRGB(110, 170, 255),
	marked = Color3.fromRGB(235, 70, 70),
}

local column: Frame? = nil
local dropButton: TextButton? = nil
local confirm: Frame? = nil
-- Text of the lines on screen, so an unchanged render does nothing.
local shownKey = ""

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function limitText(parent: Instance, minSize: number, maxSize: number)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minSize
	constraint.MaxTextSize = maxSize
	constraint.Parent = parent
end

local function makeButton(name: string, text: string, size: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.BackgroundColor3 = BUTTON_COLOR
	button.TextColor3 = TEXT_LIGHT
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Text = text
	addCorner(button, 8)
	limitText(button, 10, 20)
	return button
end

local function buildConfirm(gui: ScreenGui, onDropShield: () -> ()): Frame
	local frame = Instance.new("Frame")
	frame.Name = "ConfirmDrop"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.4, 0.22)
	frame.BackgroundColor3 = BACKGROUND
	frame.Visible = false
	addCorner(frame, 12)

	local question = Instance.new("TextLabel")
	question.Name = "Question"
	question.BackgroundTransparency = 1
	question.Position = UDim2.fromScale(0.05, 0.08)
	question.Size = UDim2.fromScale(0.9, 0.5)
	question.TextColor3 = TEXT_LIGHT
	question.TextScaled = true
	question.TextWrapped = true
	question.Font = Enum.Font.GothamMedium
	question.Text = "Other players will be able to attack you. Drop it?"
	limitText(question, 10, 24)
	question.Parent = frame

	local yes = makeButton("Yes", "Yes", UDim2.fromScale(0.35, 0.25))
	yes.Position = UDim2.fromScale(0.1, 0.65)
	yes.Activated:Connect(function()
		frame.Visible = false
		onDropShield()
	end)
	yes.Parent = frame

	local no = makeButton("No", "No", UDim2.fromScale(0.35, 0.25))
	no.Position = UDim2.fromScale(0.55, 0.65)
	no.Activated:Connect(function()
		frame.Visible = false
	end)
	no.Parent = frame

	frame.Parent = gui
	return frame
end

function StatusHUD.mount(playerGui: PlayerGui, onDropShield: () -> ())
	local gui = Instance.new("ScreenGui")
	gui.Name = "StatusGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15

	local list = Instance.new("Frame")
	list.Name = "Lines"
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0, 12, 0, 12)
	list.Size = UDim2.new(0, 230, 0, 160)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	list.Parent = gui
	column = list

	local drop = makeButton("DropShield", "Drop shield", UDim2.new(0, 150, 0, 32))
	drop.Position = UDim2.new(0, 12, 0, 176)
	drop.Visible = false
	drop.Parent = gui
	dropButton = drop

	local dialog = buildConfirm(gui, onDropShield)
	confirm = dialog
	drop.Activated:Connect(function()
		dialog.Visible = true
	end)

	gui.Parent = playerGui
end

function StatusHUD.render(lines: { StatusView.Line }, showDropShield: boolean)
	local drop = dropButton
	if drop ~= nil then
		drop.Visible = showDropShield
	end
	local dialog = confirm
	if dialog ~= nil and not showDropShield then
		dialog.Visible = false
	end

	local list = column
	if list == nil then
		return
	end
	local parts: { string } = {}
	for _, line in lines do
		table.insert(parts, line.kind .. ":" .. line.text)
	end
	local key = table.concat(parts, "|")
	if key == shownKey then
		return
	end
	shownKey = key

	for _, child in list:GetChildren() do
		if not child:IsA("UIComponent") then
			child:Destroy()
		end
	end
	for index, line in lines do
		local label = Instance.new("TextLabel")
		label.Name = "Line" .. index
		label.LayoutOrder = index
		label.Size = UDim2.new(1, 0, 0, 28)
		label.BackgroundColor3 = BACKGROUND
		label.BackgroundTransparency = 0.3
		label.TextColor3 = KIND_COLORS[line.kind] or TEXT_LIGHT
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Font = Enum.Font.GothamBold
		label.Text = line.text
		addCorner(label, 6)
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 8)
		padding.PaddingTop = UDim.new(0, 4)
		padding.PaddingBottom = UDim.new(0, 4)
		padding.Parent = label
		limitText(label, 10, 20)
		label.Parent = list
	end
end

return StatusHUD
