--!strict
-- The banner every player sees when someone is Crowned. It only shows the lines the Crown
-- rules make from what the server sent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Crown = require(Shared:WaitForChild("Rules"):WaitForChild("Crown"))
local UiKit = require(script.Parent.UiKit)

local SHOW_SECONDS = 6

local TEXT_GOLD = Color3.fromRGB(255, 215, 90)
local BACKGROUND = Color3.fromRGB(25, 22, 30)

local CeremonyUI = {}

local banner: Frame? = nil
local line1: TextLabel? = nil
local line2: TextLabel? = nil
-- Bumped on every show, so an old banner's timer cannot hide a newer one.
local token = 0

function CeremonyUI.mount(playerGui: PlayerGui)
	-- Above the status HUD (15) and messages (20), below the Renounce window (26).
	local gui = UiKit.screen("CeremonyGui", 25)

	local frame = Instance.new("Frame")
	frame.Name = "Banner"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.fromScale(0.5, 0.2)
	frame.Size = UDim2.fromScale(0.6, 0.14)
	frame.BackgroundColor3 = BACKGROUND
	frame.BackgroundTransparency = 0.2
	frame.Visible = false
	UiKit.corner(frame, 12)
	local minimum = Instance.new("UISizeConstraint")
	minimum.MinSize = Vector2.new(280, 70)
	minimum.Parent = frame

	local first = UiKit.label("Line1", "", UDim2.fromScale(0.94, 0.58), UDim2.fromScale(0.03, 0), {
		color = TEXT_GOLD,
		font = Enum.Font.GothamBold,
		max = 30,
		align = Enum.TextXAlignment.Center,
	})
	first.Parent = frame
	line1 = first

	local second = UiKit.label(
		"Line2",
		"",
		UDim2.fromScale(0.94, 0.36),
		UDim2.fromScale(0.03, 0.62),
		{ max = 20, align = Enum.TextXAlignment.Center }
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
