--!strict
-- The banner every player sees when someone is Crowned. It only shows the lines the Crown
-- rules make from what the server sent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crown = require(Shared:WaitForChild("Rules"):WaitForChild("Crown"))

local SHOW_SECONDS = 6

local TEXT_LIGHT = Color3.fromRGB(245, 235, 210)
local TEXT_GOLD = Color3.fromRGB(255, 215, 90)
local BACKGROUND = Color3.fromRGB(25, 22, 30)

local CeremonyUI = {}

local banner: Frame? = nil
local line1: TextLabel? = nil
local line2: TextLabel? = nil
-- Bumped on every show, so an old banner's timer cannot hide a newer one.
local token = 0

local function limitText(parent: Instance, minSize: number, maxSize: number)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minSize
	constraint.MaxTextSize = maxSize
	constraint.Parent = parent
end

local function makeLine(
	name: string,
	size: UDim2,
	position: UDim2,
	color: Color3,
	font: Enum.Font,
	maxText: number
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = font
	label.Text = ""
	limitText(label, 9, maxText)
	return label
end

function CeremonyUI.mount(playerGui: PlayerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "CeremonyGui"
	gui.ResetOnSpawn = false
	-- Above the status HUD (15) and messages (20), below the Renounce window (26).
	gui.DisplayOrder = 25

	local frame = Instance.new("Frame")
	frame.Name = "Banner"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.fromScale(0.5, 0.2)
	frame.Size = UDim2.fromScale(0.6, 0.14)
	frame.BackgroundColor3 = BACKGROUND
	frame.BackgroundTransparency = 0.2
	frame.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame
	local minimum = Instance.new("UISizeConstraint")
	minimum.MinSize = Vector2.new(280, 70)
	minimum.Parent = frame

	local first = makeLine(
		"Line1",
		UDim2.fromScale(0.94, 0.58),
		UDim2.fromScale(0.03, 0),
		TEXT_GOLD,
		Enum.Font.GothamBold,
		30
	)
	first.Parent = frame
	line1 = first

	local second = makeLine(
		"Line2",
		UDim2.fromScale(0.94, 0.36),
		UDim2.fromScale(0.03, 0.62),
		TEXT_LIGHT,
		Enum.Font.GothamMedium,
		20
	)
	second.Parent = frame
	line2 = second

	frame.Parent = gui
	banner = frame
	gui.Parent = playerGui
end

function CeremonyUI.show(ceremony: { userId: number, name: string, crowns: number })
	local frame = banner
	local top = line1
	local bottom = line2
	if frame == nil or top == nil or bottom == nil then
		return
	end
	local lines = Crown.ceremonyLines(ceremony.name, ceremony.crowns)
	top.Text = lines[1] or ""
	bottom.Text = lines[2] or ""
	frame.Visible = true
	token += 1
	local mine = token
	task.delay(SHOW_SECONDS, function()
		if token == mine then
			frame.Visible = false
		end
	end)
end

return CeremonyUI
