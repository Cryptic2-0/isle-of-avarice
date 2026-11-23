--!strict
-- Messages at the top of the screen, one at a time. A message stays 3 seconds, or 1.5 when
-- another is waiting. At most 4 wait; a fifth pushes out the one that has waited longest.
-- The region banner (name and hint on entering a region) has its own line just under it and
-- never goes through the message queue.
local UiKit = require(script.Parent.UiKit)

local SHOW_SECONDS = 3
local SHORT_SECONDS = 1.5
local MAX_WAITING = 4
local STEP_SECONDS = 0.1
local REGION_SECONDS = 3
local REGION_COLOR = Color3.fromRGB(255, 215, 150)

local Toast = {}

local label: TextLabel? = nil
local regionLabel: TextLabel? = nil
local waiting: { string } = {}
local showing = false
-- Counts region calls: a banner hides itself only if no newer one came.
local regionToken = 0

function Toast.mount(playerGui: PlayerGui)
	local gui = UiKit.screen("ToastGui", 20, true)

	local text = Instance.new("TextLabel")
	text.Name = "Message"
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = UDim2.fromScale(0.5, 0.04)
	text.Size = UDim2.fromScale(0.6, 0.07)
	text.BackgroundColor3 = Color3.fromRGB(25, 22, 30)
	text.BackgroundTransparency = 0.15
	text.TextColor3 = UiKit.TEXT_LIGHT
	text.TextScaled = true
	text.Font = Enum.Font.GothamMedium
	text.Text = ""
	text.Visible = false

	UiKit.corner(text, 10)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = text
	UiKit.limitText(text, 12, 28)

	text.Parent = gui
	label = text

	local region = Instance.new("TextLabel")
	region.Name = "Region"
	region.AnchorPoint = Vector2.new(0.5, 0)
	region.Position = UDim2.fromScale(0.5, 0.12)
	region.Size = UDim2.fromScale(0.45, 0.05)
	region.BackgroundColor3 = Color3.fromRGB(25, 22, 30)
	region.BackgroundTransparency = 0.35
	region.TextColor3 = REGION_COLOR
	region.TextScaled = true
	region.TextWrapped = true
	region.Font = Enum.Font.GothamMedium
	region.Text = ""
	region.Visible = false
	local minimum = Instance.new("UISizeConstraint")
	minimum.MinSize = Vector2.new(240, 22)
	minimum.Parent = region
	UiKit.corner(region, 8)
	UiKit.limitText(region, 10, 20)
	region.Parent = gui
	regionLabel = region

	gui.Parent = playerGui
end

-- Shows `first`, then everything that queues up behind it, then hides the label.
local function run(current: TextLabel, first: string)
	local text: string? = first
	while text ~= nil do
		current.Text = text
		current.Visible = true
		local shownFor = 0
		while shownFor < SHOW_SECONDS and not (#waiting > 0 and shownFor >= SHORT_SECONDS) do
			shownFor += task.wait(STEP_SECONDS)
		end
		text = table.remove(waiting, 1)
	end
	current.Visible = false
	showing = false
end

function Toast.show(text: string)
	local current = label
	if current == nil then
		return
	end
	if showing then
		if #waiting >= MAX_WAITING then
			table.remove(waiting, 1)
		end
		table.insert(waiting, text)
		return
	end
	showing = true
	task.spawn(run, current, text)
end

-- The region banner: shows the text for 3 seconds, or until a newer region replaces it.
function Toast.region(text: string)
	local banner = regionLabel
	if banner == nil then
		return
	end
	regionToken += 1
	local token = regionToken
	banner.Text = text
	banner.Visible = true
	task.delay(REGION_SECONDS, function()
		if token == regionToken then
			banner.Visible = false
		end
	end)
end

-- The message on screen and those waiting, oldest first (play-test seam).
function Toast.pending(): { string }
	local list = table.clone(waiting)
	local current = label
	if showing and current ~= nil then
		table.insert(list, 1, current.Text)
	end
	return list
end

-- The banner's text while it shows, else "" (play-test seam).
function Toast.regionText(): string
	local banner = regionLabel
	if banner ~= nil and banner.Visible then
		return banner.Text
	end
	return ""
end

return Toast
